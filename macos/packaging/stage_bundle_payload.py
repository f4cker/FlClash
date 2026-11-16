#!/usr/bin/python3
"""Bundled SMAppService daemon layout: one Flash.app carries Core, helper and plist.

Static checks only. Nothing here signs, installs, registers or launches code; the
daemon is registered by the signed app itself through SMAppService.daemon.
"""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys

GUI_ID = 'com.layoute.flash'
LABEL = 'com.layoute.flash.daemon'
LEGACY_LABEL = 'com.layoute.flash.helper'
CORE = 'Contents/MacOS/FlClashCore'
HELPER = 'Contents/Library/HelperTools/FlashHelper'
HELPER_ID = 'com.layoute.flash.helper'
DAEMON_PLIST = 'Contents/Library/LaunchDaemons/' + LABEL + '.plist'
# Signing is strictly inside-out: nested code first, then frameworks, then the app
# seal that covers the daemon plist in CodeResources files2.
SIGNING_ORDER = ('core', 'helper', 'framework', 'gui')
DAEMON_SCHEMA = {
    'Label': LABEL,
    'BundleProgram': HELPER,  # relative to the .app root, as SMAppService expects
    'MachServices': {LABEL: True},
    'AssociatedBundleIdentifiers': [GUI_ID],
    'ProcessType': 'Interactive',
}
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


def daemon_plist(app):
    data = plistlib.loads(regular(app / DAEMON_PLIST))
    require(isinstance(data, dict), 'Daemon plist must be a dictionary')
    require('Program' not in data and 'ProgramArguments' not in data,
            'Daemon plist must use BundleProgram only (no Program/ProgramArguments)')
    require(data == DAEMON_SCHEMA, 'Daemon plist differs from the exact bundled schema')
    require(data['Label'] != LEGACY_LABEL, 'Daemon label must differ from the legacy helper label')
    return data


def embedded_info_plist(binary):
    """Return the __TEXT,__info_plist of a thin or fat Mach-O (first match is enough)."""
    data = regular(binary)
    start = data.find(b'<?xml')
    end = data.find(b'</plist>', start)
    require(start >= 0 and end > start, 'Helper lacks an embedded __info_plist')
    return plistlib.loads(data[start:end + len(b'</plist>')])


def check_layout(app):
    """Validate an unsigned or signed bundled-daemon Flash.app."""
    app = Path(app)
    require(app.name == 'Flash.app' and app.is_dir() and not app.is_symlink(), 'Expected Flash.app directory')
    info = plistlib.loads(regular(app / 'Contents/Info.plist'))
    require(info.get('CFBundleIdentifier') == GUI_ID, 'Unexpected GUI identifier')
    for key in FORBIDDEN_INFO_KEYS:
        require(key not in info, 'Legacy helper metadata in Info.plist: ' + key)
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
    require(sorted(p.name for p in launch.iterdir()) == [LABEL + '.plist'], 'Unexpected LaunchDaemons content')
    tools = app / 'Contents/Library/HelperTools'
    require(sorted(p.name for p in tools.iterdir()) == ['FlashHelper'], 'Unexpected HelperTools content')
    return {'core_sha256': sha256(app / CORE), 'helper_sha256': sha256(app / HELPER),
            'daemon_plist_sha256': sha256(app / DAEMON_PLIST)}


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
    for relative, identifier in ((CORE, 'com.layoute.flash.core'), (HELPER, HELPER_ID), ('.', GUI_ID)):
        codesign('--verify', '--strict', '--all-architectures', '-R=' + requirement(identifier),
                 str(app / relative))
    codesign('--verify', '--deep', '--strict', '--all-architectures', str(app))
    resources = plistlib.loads(regular(app / 'Contents/_CodeSignature/CodeResources'))
    sealed = resources.get('files2', {})
    key = DAEMON_PLIST[len('Contents/'):]
    require(key in sealed, 'Daemon plist is not sealed in CodeResources files2')
    require(HELPER[len('Contents/'):] in sealed and CORE[len('Contents/'):] in sealed,
            'Nested helper/Core must be sealed by the app signature')
    facts['helper_cdhash'] = cdhash(app / HELPER)
    facts['core_cdhash'] = cdhash(app / CORE)
    return facts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('mode', choices=('check', 'verify-signed'))
    parser.add_argument('app')
    args = parser.parse_args(argv)
    try:
        result = check_layout(args.app) if args.mode == 'check' else verify_signed(args.app)
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print('Bundled daemon layout check failed: ' + str(error), file=sys.stderr)
        return 1
    for key, value in sorted(result.items()):
        print(key + '=' + value)
    return 0


if __name__ == '__main__':
    sys.exit(main())
