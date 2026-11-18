#!/usr/bin/python3
"""Bundled SMAppService daemon layout: one Flash.app carries Core, helper and plist.

Static checks only. Nothing here signs, installs, registers or launches code; the
daemon is registered by the signed app itself through SMAppService.daemon.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys

GUI_ID = 'com.layoute.flash'
# Registration name of the daemon (launchd label, Mach service, plist file name); see macos/Shared/HelperTrust.h.
LABEL = 'com.layoute.flash.helperd'
# The name used up to 0.9.15-mitm.3. Its plist rides along only so the app can unregister it; never registered.
RETIRED_LABEL = 'com.layoute.flash.daemon'
LEGACY_LABEL = 'com.layoute.flash.helper'
CORE = 'Contents/MacOS/FlClashCore'
HELPER = 'Contents/Library/HelperTools/FlashHelper'
HELPER_ID = 'com.layoute.flash.helper'
DAEMON_PLIST = 'Contents/Library/LaunchDaemons/' + LABEL + '.plist'
RETIRED_DAEMON_PLIST = 'Contents/Library/LaunchDaemons/' + RETIRED_LABEL + '.plist'
# Signing is strictly inside-out: nested code first, then frameworks, then the app
# seal that covers the daemon plist in CodeResources files2. The compatibility
# contract is written into Info.plist right after Core is signed (it pins the signed
# Core bytes) and before any outer signature, so the app seal covers it.
SIGNING_ORDER = ('core', 'contract', 'helper', 'framework', 'gui')
CORE_ID = 'com.layoute.flash.core'
# Info.plist FlashHelperCompatibility: read by HelperTrust.m (FCBundleCompatibilityValid)
# and the daemon Supervisor. Exactly these six keys; see macos/Shared/HelperCompatibility.h.
CONTRACT_KEY = 'FlashHelperCompatibility'
CONTRACT_POLICY = {'CallerPolicy': 3, 'ServiceAPI': 1, 'CoreAPI': 1}
CONTRACT_KEYS = frozenset(CONTRACT_POLICY) | {'CoreSHA256', 'CoreVersion', 'CoreRevision'}
def daemon_schema(label):
    return {
        'Label': label,
        'BundleProgram': HELPER,  # relative to the .app root, as SMAppService expects
        'MachServices': {label: True},
        'AssociatedBundleIdentifiers': [GUI_ID],
        'ProcessType': 'Interactive',
    }


DAEMON_SCHEMA = daemon_schema(LABEL)
RETIRED_DAEMON_SCHEMA = daemon_schema(RETIRED_LABEL)
FORBIDDEN = (
    'Contents/Library/HelperTools/FlashMaintenance',
    'Contents/Library/LaunchDaemons/' + LEGACY_LABEL + '.plist',
    'Contents/Resources/HelperInstaller',
)
FORBIDDEN_INFO_KEYS = ('FlashMinimumServiceBuild', 'SMPrivilegedExecutables')
MACH_MAGIC = {bytes.fromhex(v) for v in ('feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca')}
CODESIGN = '/usr/bin/codesign'
CERTIFICATE_SHA1 = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def regular(path):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, 'Expected a single-link regular file: ' + str(path))
    return path.read_bytes()


def sha256(path):
    return hashlib.sha256(regular(path)).hexdigest()


def daemon_plist(app, relative=DAEMON_PLIST, schema=DAEMON_SCHEMA):
    data = plistlib.loads(regular(app / relative))
    require(isinstance(data, dict), 'Daemon plist must be a dictionary')
    require('Program' not in data and 'ProgramArguments' not in data,
            'Daemon plist must use BundleProgram only (no Program/ProgramArguments)')
    require(data == schema, 'Daemon plist differs from the exact bundled schema: ' + relative)
    require(data['Label'] != LEGACY_LABEL, 'Daemon label must differ from the legacy helper label')
    return data


def embedded_info_plist(binary):
    """Return the __TEXT,__info_plist of a thin or fat Mach-O (first match is enough)."""
    data = regular(binary)
    start = data.find(b'<?xml')
    end = data.find(b'</plist>', start)
    require(start >= 0 and end > start, 'Helper lacks an embedded __info_plist')
    return plistlib.loads(data[start:end + len(b'</plist>')])


def contract_string(value):
    return isinstance(value, str) and 0 < len(value) <= 128


def validate_contract(contract):
    """Python mirror of FCBundleCompatibilityValid (fail closed on any drift)."""
    require(isinstance(contract, dict) and set(contract) == CONTRACT_KEYS,
            CONTRACT_KEY + ' must have exactly ' + ', '.join(sorted(CONTRACT_KEYS)))
    for key, expected in CONTRACT_POLICY.items():
        value = contract[key]
        require(type(value) is int and value == expected, CONTRACT_KEY + ' ' + key + ' must be integer ' + str(expected))
    digest = contract['CoreSHA256']
    require(isinstance(digest, str) and len(digest) == 64 and set(digest) <= set('0123456789abcdef'),
            CONTRACT_KEY + ' CoreSHA256 must be 64 lowercase hex characters')
    for key in ('CoreVersion', 'CoreRevision'):
        require(contract_string(contract[key]), CONTRACT_KEY + ' ' + key + ' must be a 1-128 character string')
    return contract


def compatibility_inputs(core_version, core_revision):
    """The release-bound part of the contract; CoreSHA256 is added only after Core signing."""
    inputs = dict(CONTRACT_POLICY, CoreVersion=core_version, CoreRevision=core_revision)
    validate_contract(dict(inputs, CoreSHA256='0' * 64))
    return inputs


def read_contract(app):
    return plistlib.loads(regular(Path(app) / 'Contents/Info.plist')).get(CONTRACT_KEY)


def seal_compatibility(app, core_version, core_revision):
    """Write the contract after Core is signed and before helper/framework/app signing.

    CoreSHA256 is the sha256 of the signed Core bytes the daemon later copies and hashes.
    Refuses an already sealed contract, an unsigned/foreign Core and an already sealed app.
    """
    app = Path(app)
    check_layout(app)
    require(not (app / 'Contents/_CodeSignature').exists(), 'Contract must be written before the app seal')
    codesign('--verify', '--strict', '--all-architectures', '-R=' + requirement(CORE_ID), str(app / CORE))
    path = app / 'Contents/Info.plist'
    data = regular(path)
    info = plistlib.loads(data)
    require(CONTRACT_KEY not in info, CONTRACT_KEY + ' is already present')
    contract = validate_contract(dict(compatibility_inputs(core_version, core_revision),
                                      CoreSHA256=sha256(app / CORE)))
    info[CONTRACT_KEY] = contract
    binary = data.startswith(b'bplist00')
    output = plistlib.dumps(info, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML, sort_keys=True)
    temporary = path.with_name('.Info.plist.contract')
    mode = stat.S_IMODE(path.lstat().st_mode)
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(descriptor, 'wb') as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(output)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    require(read_contract(app) == contract, 'Sealed contract did not round-trip')
    return contract


def check_layout(app):
    """Validate an unsigned or signed bundled-daemon Flash.app."""
    app = Path(app)
    require(app.name == 'Flash.app' and app.is_dir() and not app.is_symlink(), 'Expected Flash.app directory')
    info = plistlib.loads(regular(app / 'Contents/Info.plist'))
    require(info.get('CFBundleIdentifier') == GUI_ID, 'Unexpected GUI identifier')
    for key in FORBIDDEN_INFO_KEYS:
        require(key not in info, 'Legacy helper metadata in Info.plist: ' + key)
    if CONTRACT_KEY in info:
        validate_contract(info[CONTRACT_KEY])
    for relative in FORBIDDEN:
        path = app / relative
        require(not path.exists() and not path.is_symlink(), 'Legacy helper artifact present: ' + relative)
    plist = daemon_plist(app)
    for relative in (CORE, plist['BundleProgram']):
        path = app / relative
        require(path.resolve(strict=True) == path, 'Nested code must not be reached through symlinks: ' + relative)
        data = regular(path)
        require(data[:4] in MACH_MAGIC, 'Expected Mach-O code: ' + relative)
        require(path.stat().st_mode & stat.S_IXUSR and not path.stat().st_mode & 0o022,
                'Nested code must be owner-executable and not group/other writable: ' + relative)
    helper_info = embedded_info_plist(app / HELPER)
    require(helper_info.get('CFBundleIdentifier') == HELPER_ID, 'Helper __info_plist identifier differs')
    launch = app / 'Contents/Library/LaunchDaemons'
    require(sorted(p.name for p in launch.iterdir()) == sorted([LABEL + '.plist', RETIRED_LABEL + '.plist']),
            'Unexpected LaunchDaemons content')
    daemon_plist(app, RETIRED_DAEMON_PLIST, RETIRED_DAEMON_SCHEMA)
    tools = app / 'Contents/Library/HelperTools'
    require(sorted(p.name for p in tools.iterdir()) == ['FlashHelper'], 'Unexpected HelperTools content')
    return {'core_sha256': sha256(app / CORE), 'helper_sha256': sha256(app / HELPER),
            'daemon_plist_sha256': sha256(app / DAEMON_PLIST),
            'retired_daemon_plist_sha256': sha256(app / RETIRED_DAEMON_PLIST)}


def inventory(app):
    app = Path(app)
    entries = {}
    for directory, names, files in os.walk(app, followlinks=False):
        for name in sorted(names + files):
            path = Path(directory) / name
            info = path.lstat()
            relative = str(path.relative_to(app))
            if stat.S_ISLNK(info.st_mode):
                entries[relative] = {'kind': 'symlink', 'target': os.readlink(path)}
            elif stat.S_ISDIR(info.st_mode):
                entries[relative] = {'kind': 'directory', 'mode': oct(stat.S_IMODE(info.st_mode))}
            elif stat.S_ISREG(info.st_mode):
                entries[relative] = {'kind': 'file', 'mode': oct(stat.S_IMODE(info.st_mode)),
                                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            else:
                raise ValueError('Special file in bundle: ' + relative)
    return entries


def stage(source, destination):
    """Copy a fresh unsigned build into a new private location and validate it."""
    source, destination = Path(source), Path(destination)
    require(not destination.exists() and not destination.is_symlink(), 'Refusing to overwrite staged app')
    check_layout(source)
    require(read_contract(source) is None, CONTRACT_KEY + ' must only be sealed after Core signing')
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    subprocess.run(['/usr/bin/ditto', '--norsrc', '--noextattr', '--noacl', str(source), str(destination)],
                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(inventory(source) == inventory(destination), 'Staged copy differs from fresh build')
    return check_layout(destination)


def verify_copy(original, copied):
    require(inventory(original) == inventory(copied), 'Copied bundle differs from signed input')


def requirement(identifier):
    return (f'anchor H"{CERTIFICATE_SHA1}" and '
            f'certificate leaf = H"{CERTIFICATE_SHA1}" and identifier "{identifier}"')


def codesign(*arguments):
    return subprocess.run([CODESIGN, *arguments], check=True, stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          env={'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}, timeout=120)


def cdhash(path):
    output = codesign('-d', '--verbose=4', str(path)).stderr.decode('utf-8', errors='strict')
    hashes = [line.split('=', 1)[1] for line in output.splitlines() if line.startswith('CDHash=')]
    require(len(hashes) == 1, 'Expected one CDHash for ' + str(path))
    return hashes[0]


def verify_signed(app):
    """Static verification of the signed bundle; never launches or registers anything."""
    app = Path(app)
    facts = check_layout(app)
    for relative, identifier in ((CORE, CORE_ID), (HELPER, HELPER_ID), ('.', GUI_ID)):
        codesign('--verify', '--strict', '--all-architectures', '-R=' + requirement(identifier),
                 str(app / relative))
    codesign('--verify', '--deep', '--strict', '--all-architectures', str(app))
    resources = plistlib.loads(regular(app / 'Contents/_CodeSignature/CodeResources'))
    sealed = resources.get('files2', {})
    for plist in (DAEMON_PLIST, RETIRED_DAEMON_PLIST):
        require(plist[len('Contents/'):] in sealed, 'Daemon plist is not sealed in CodeResources files2: ' + plist)
    require(HELPER[len('Contents/'):] in sealed and CORE[len('Contents/'):] in sealed,
            'Nested helper/Core must be sealed by the app signature')
    contract = read_contract(app)
    require(contract is not None, 'Signed app lacks the ' + CONTRACT_KEY + ' contract in Info.plist')
    validate_contract(contract)
    require(contract['CoreSHA256'] == facts['core_sha256'],
            CONTRACT_KEY + ' CoreSHA256 differs from the signed bundled Core')
    facts['compatibility'] = contract
    facts['helper_cdhash'] = cdhash(app / HELPER)
    facts['core_cdhash'] = cdhash(app / CORE)
    return facts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('mode', choices=('check', 'seal-compatibility', 'verify-signed'))
    parser.add_argument('app')
    parser.add_argument('--core-version')
    parser.add_argument('--core-revision')
    args = parser.parse_args(argv)
    inputs = (args.core_version, args.core_revision)
    sealing = args.mode == 'seal-compatibility'
    if not (all(v is not None for v in inputs) if sealing else all(v is None for v in inputs)):
        parser.error('--core-version and --core-revision are required for (and only for) seal-compatibility')
    try:
        if args.mode == 'check':
            result = check_layout(args.app)
        elif args.mode == 'seal-compatibility':
            result = seal_compatibility(args.app, args.core_version, args.core_revision)
        else:
            result = verify_signed(args.app)
    except (ValueError, OSError, KeyError, plistlib.InvalidFileException, subprocess.SubprocessError) as error:
        print('Bundled daemon layout check failed: ' + str(error), file=sys.stderr)
        return 1
    for key, value in sorted(result.items()):
        print(key + '=' + (json.dumps(value, sort_keys=True) if isinstance(value, dict) else str(value)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
