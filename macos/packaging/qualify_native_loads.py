#!/usr/bin/python3
"""Exact-artifact native-load evidence. Never run a probe without human approval.

Verify mode never launches GUI code. Evidence is a cooperative local observation,
not an attestation against its owner. Stop other writers and freeze all inputs.
"""
import argparse
import base64
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import selectors
import subprocess
import sys
import tempfile
import time
import types
import xml.etree.ElementTree as ET

ROOT = Path('/Users/layoute/SideWork/FlClash/.airbuild/worktree/exit-cleanup')
PACKAGING = ROOT / 'macos/packaging'
SCRATCH_ROOT = ROOT / '.airbuild/native-load-scratch'
EVIDENCE_ROOT = ROOT / '.airbuild/evidence/native-load-qualification'
REAL_HOME = Path('/Users/layoute')
DYLD_BOOTSTRAP_PROFILE = Path('/System/Library/Sandbox/Profiles/dyld-support.sb')
PROBES = {'flutter_pixel', 'rust_utf8', 'objective_c_string', 'sqlite_memory'}
PREFIX = 'FLASH_NATIVE_LOADS '
TIMEOUT = 25
OUTPUT_LIMIT = 65536
CAVEATS = [
    'OS-managed Cocoa/Flutter/WindowServer/GPU caches or preferences may still be affected.',
    'No helper installation, authorization, XPC, TUN, reboot, recovery, or installer acceptance.',
    'Local cooperative evidence is not protected against a hostile same-UID writer.',
    'Build metadata declares provenance; compiled defines are not independently recovered.',
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def driver():
    path = PACKAGING / 'sign_fixed_payload.py'
    module = types.ModuleType('_qualification_signer')
    module.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), 'exec'), module.__dict__)
    return module


def canonical(value):
    path = Path(value)
    if not path.is_absolute() or str(path) != value or path.resolve(strict=True) != path:
        raise ValueError('Expected canonical, existing, absolute path without links')
    return path


def protected_json(path, signer):
    signer.require_no_acl(path)
    data = signer.read_regular(path)
    result = json.loads(data)
    if not isinstance(result, dict):
        raise ValueError('Expected JSON object')
    return result, digest(data)


def host():
    info = os.uname()
    if info.sysname != 'Darwin' or info.machine not in {'arm64', 'x86_64'}:
        raise ValueError('Only native macOS arm64/x86_64 qualification is supported')
    version = plistlib.loads(Path('/System/Library/CoreServices/SystemVersion.plist').read_bytes())
    bootstrap_policy = DYLD_BOOTSTRAP_PROFILE.read_bytes()
    if re.search(rb'\(\s*(?:import|include)\b', bootstrap_policy):
        raise ValueError('Review nested dyld sandbox policy dependencies before qualification')
    return {'system': info.sysname, 'release': info.release, 'version': info.version,
            'architecture': info.machine, 'product_version': version['ProductVersion'],
            'product_build': version['ProductBuildVersion'],
            'dyld_bootstrap_profile_sha256': digest(bootstrap_policy)}


def make_scratch():
    if not SCRATCH_ROOT.exists():
        SCRATCH_ROOT.mkdir(mode=0o700)
    signer = driver()
    canonical(str(SCRATCH_ROOT))
    signer.check_directory(SCRATCH_ROOT)
    return tempfile.TemporaryDirectory(prefix='session-', dir=SCRATCH_ROOT)


def frozen_state(app, metadata_path, signer, scratch):
    app = signer.staging_path(str(app))
    static_path = app.parent / 'Flash.signing-static.json'
    report, report_hash = protected_json(static_path, signer)
    metadata, metadata_hash = protected_json(metadata_path, signer)
    verifier = signer.trusted_verifier()
    entries = signer.inventory(app, verifier)
    verifier.audit(app)
    targets = signer.signing_targets(app, entries)
    pins = {'certificate_sha1': signer.CERTIFICATE_SHA1, 'certificate_sha256': signer.CERTIFICATE_SHA256}
    if (report.get('schema') != 1 or report.get('static_verification') is not True or
            report.get('actualGUIloads') is not False or report.get('packaging_accepted') is not False or
            report.get('app') != str(app) or report.get('pins') != pins or
            report.get('after') != {'tree_sha256': signer.tree_digest(entries), 'entries': entries}):
        raise ValueError('Static report does not match the complete current signed artifact')
    source_hashes = {name: digest(signer.read_regular(PACKAGING / name)) for name in (
        'sign_fixed_payload.py', 'stage_managed_payload.py', 'FixedGUI.entitlements', 'qualify_native_loads.py',
    )}
    if report.get('inputs') != {
            'driver_sha256': source_hashes['sign_fixed_payload.py'],
            'verifier_sha256': source_hashes['stage_managed_payload.py'],
            'gui_entitlements_sha256': source_hashes['FixedGUI.entitlements']}:
        raise ValueError('Static signing source provenance changed')
    candidate_defines = {'MACOS_MANAGED_HELPER': True,
                        'FC_PINNED_CERTIFICATE_SHA1': signer.CERTIFICATE_SHA1,
                        'FC_MANAGED_CANDIDATE_ENABLED': 1}
    if report.get('defines', {}).get('intended_static_candidate') != candidate_defines:
        raise ValueError('Static report must declare an unqualified enabled candidate')
    info = plistlib.loads(signer.read_regular(app / 'Contents/Info.plist'))
    defines = metadata.get('defines', {})
    if (metadata.get('certificate_sha1') != signer.CERTIFICATE_SHA1 or metadata.get('apple_team') != '' or
            metadata.get('runtime_acceptance') is not False or
            metadata.get('actualGUIloads') is not False or metadata.get('packaging_accepted') is not False or
            metadata.get('version') != info.get('CFBundleShortVersionString') or
            metadata.get('build_number') != info.get('CFBundleVersion') or
            defines.get('APP_ENV') != 'stable' or
            defines.get('MACOS_MANAGED_HELPER') is not True or
            type(defines.get('FC_MANAGED_CANDIDATE_ENABLED')) is not int or
            defines.get('FC_MANAGED_CANDIDATE_ENABLED') != 1):
        raise ValueError('Missing or inconsistent candidate build metadata')
    dart_defines = [base64.b64decode(value, validate=True).decode('utf-8')
                    for value in info.get('FlashDartDefines', '').split(',') if value]
    managed = [value for value in dart_defines if value.startswith('MACOS_MANAGED_HELPER=')]
    if managed != ['MACOS_MANAGED_HELPER=true']:
        raise ValueError('Sealed Dart build metadata must enable the managed candidate')
    architectures = None
    for index, target in enumerate(targets):
        target['architectures'] = sorted(verifier.load_commands(app / target['binary']))
        if architectures is None:
            architectures = target['architectures']
        if target['architectures'] != architectures:
            raise ValueError('Nonuniform candidate architectures')
        work = scratch / str(index)
        work.mkdir(mode=0o700)
        target['verified_slices'] = signer.verify_target(app, target, work)
    signer.run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--all-architectures', str(app)])
    if targets != report.get('targets'):
        raise ValueError('Static target observations changed')
    if signer.inventory(app, verifier) != entries:
        raise ValueError('Artifact changed during static verification')
    if host()['architecture'] not in architectures:
        raise ValueError('Native host architecture missing from candidate')
    return {'app': str(app), 'static_report': str(static_path), 'static_report_sha256': report_hash,
            'build_metadata': str(metadata_path), 'build_metadata_sha256': metadata_hash,
            'source_sha256': source_hashes, 'inventory': entries,
            'tree_sha256': signer.tree_digest(entries), 'targets': targets, 'pins': pins,
            'build': {'version': metadata['version'], 'build_number': metadata['build_number'],
                      'declared_defines': defines}, 'host': host()}


def denied_paths():
    paths = [REAL_HOME / 'Library/Application Support/Flash Signing',
             REAL_HOME / 'Library/Keychains', Path('/Library/Keychains'),
             Path('/Library/Application Support/Flash'), EVIDENCE_ROOT.parent]
    for identifier in ('com.layoute.flash', 'com.follow.clash', 'com.follow.clash.debug'):
        paths.extend(REAL_HOME / relative for relative in (
            f'Library/Application Support/{identifier}', f'Library/Caches/{identifier}',
            f'Library/Preferences/{identifier}.plist', f'Library/Saved Application State/{identifier}.savedState',
        ))
    paths.extend(REAL_HOME / relative for relative in (
        'Library/Containers', 'Library/Group Containers', '.config/FlClash', '.config/flclash',
        'Library/Application Support/FlClash', 'Library/Application Support/Flash',
    ))
    return paths


def sandbox_profile(app, scratch):
    quote = lambda path: json.dumps(str(path), ensure_ascii=True)
    gui = app / 'Contents/MacOS/Flash'
    # The installed OS policy grants dyld's signature/linking syscalls; executable
    # mappings alone are insufficient even for /usr/bin/true. Its bytes are bound
    # into host evidence, and explicit denials below override imported allowances.
    rules = ['(version 1)', '(deny default)', '(import "dyld-support.sb")',
             '(deny network*)', '(deny process-fork)', '(deny sysctl-write)',
             '(deny file-write* (require-not (subpath ' + quote(scratch) + ')))',
             '(allow process-exec (literal "/usr/bin/arch") (literal ' + quote(gui) + '))',
             '(allow file-read-metadata)',
             '(allow file-read* (literal ' + quote(gui) + '))',
             '(allow file-map-executable (literal ' + quote(gui) + ') (literal "/usr/bin/arch")',
             ' (subpath ' + quote(app) + ') (subpath "/System") (subpath "/usr/lib"))',
             '(allow file-read* (subpath ' + quote(app) + ') (subpath ' + quote(scratch) + '))',
             '(allow file-write* (subpath ' + quote(scratch) + '))',
             '(allow file-read* (subpath "/System") (subpath "/usr/lib") (subpath "/usr/share")',
             ' (subpath "/Library/Apple/System") (subpath "/Library/Fonts")',
             ' (subpath "/private/var/db/dyld") (literal "/dev/null")',
             ' (literal "/dev/urandom") (literal "/dev/random") (literal "/usr/bin/arch"))',
             '(allow sysctl-read)',
             '(allow mach-lookup (global-name "com.apple.windowserver.active")',
             ' (global-name "com.apple.CARenderServer") (global-name "com.apple.MTLCompilerService"))',
             '(deny mach-lookup (global-name "com.layoute.flash.helper"))']
    for path in denied_paths():
        rules.append('(deny file-read* (subpath ' + quote(path) + '))')
    return '\n'.join(rules) + '\n'


def parse_protocol(stdout, challenge):
    if not re.fullmatch(r'[A-Za-z0-9_-]{16,64}', challenge):
        raise ValueError('Invalid challenge')
    lines = stdout.decode('utf-8', errors='strict').splitlines()
    matches = [line for line in lines if line.startswith(PREFIX)]
    if len(matches) != 1:
        raise ValueError('Expected exactly one diagnostic protocol record')
    result = json.loads(matches[0][len(PREFIX):])
    if (set(result) != {'schema', 'challenge', 'ok', 'code', 'probes'} or
            type(result['schema']) is not int or result['schema'] != 1 or
            result['challenge'] != challenge or result['ok'] is not True or result['code'] != 'ok' or
            not isinstance(result['probes'], dict) or set(result['probes']) != PROBES or
            any(value is not True for value in result['probes'].values())):
        raise ValueError('Challenge-bound diagnostic did not pass all four probes')
    return result


def executable_for_pid(pid):
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    library.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    library.proc_pidpath.restype = ctypes.c_int
    buffer = ctypes.create_string_buffer(4096)
    count = library.proc_pidpath(pid, buffer, len(buffer))
    return os.fsdecode(buffer.value) if count > 0 else None


def supervise(app, scratch, challenge, architecture):
    home = scratch / 'home'
    temporary = scratch / 'tmp'
    home.mkdir(mode=0o700)
    temporary.mkdir(mode=0o700)
    profile = sandbox_profile(app, scratch)
    profile_path = scratch / 'diagnostic.sb'
    profile_path.write_text(profile)
    gui = str(app / 'Contents/MacOS/Flash')
    arguments = ['/usr/bin/sandbox-exec', '-f', str(profile_path), '/usr/bin/arch',
                 '-' + architecture, gui, '--flash-verify-native-loads', '--challenge=' + challenge]
    environment = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'HOME': str(home),
                   'CFFIXED_USER_HOME': str(home), 'TMPDIR': str(temporary),
                   'XDG_CONFIG_HOME': str(home / '.config'), 'XDG_CACHE_HOME': str(home / '.cache')}
    started = time.monotonic()
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, cwd=scratch, env=environment, start_new_session=True)
    record = {'pid': process.pid, 'owned': True, 'argv': arguments, 'challenge': challenge,
              'architecture': architecture, 'timeout': False, 'output_overflow': False,
              'terminated_by_harness': False, 'observed_executable': None,
              'sandbox_sha256': digest(profile.encode()), 'returncode': None}
    output = {'stdout': bytearray(), 'stderr': bytearray()}
    try:
        with selectors.DefaultSelector() as selector:
            for name in output:
                stream = getattr(process, name)
                os.set_blocking(stream.fileno(), False)
                selector.register(stream, selectors.EVENT_READ, name)
            while selector.get_map():
                if time.monotonic() - started >= TIMEOUT:
                    record['timeout'] = True
                    break
                if executable_for_pid(process.pid) == gui:
                    record['observed_executable'] = gui
                for key, _ in selector.select(timeout=0.05):
                    data = os.read(key.fileobj.fileno(), 8192)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    output[key.data].extend(data)
                    if len(output[key.data]) > OUTPUT_LIMIT:
                        record['output_overflow'] = True
                if record['output_overflow']:
                    break
            if process.poll() is None and not record['timeout'] and not record['output_overflow']:
                try:
                    process.wait(timeout=max(0.01, TIMEOUT - (time.monotonic() - started)))
                except subprocess.TimeoutExpired:
                    record['timeout'] = True
    finally:
        if process.poll() is None:
            record['terminated_by_harness'] = True
            process.kill()
        record['returncode'] = process.wait(timeout=3)
        for name in output:
            getattr(process, name).close()
    record['duration_seconds'] = time.monotonic() - started
    for name, data in output.items():
        data = bytes(data[:OUTPUT_LIMIT])
        record[name + '_base64'] = base64.b64encode(data).decode('ascii')
        record[name + '_sha256'] = digest(data)
    return record


def validate_execution(record, app, architecture):
    if (type(record.get('pid')) is not int or record['pid'] <= 0 or record.get('owned') is not True or
            type(record.get('returncode')) is not int or record['returncode'] != 0 or
            record.get('timeout') is not False or record.get('output_overflow') is not False or
            record.get('terminated_by_harness') is not False or record.get('architecture') != architecture or
            record.get('observed_executable') != str(app / 'Contents/MacOS/Flash') or
            not 0 < record.get('duration_seconds', 0) <= TIMEOUT + 3):
        raise ValueError('Owned diagnostic process did not exit normally within bounds')
    argv = record.get('argv', [])
    if not isinstance(argv, list) or len(argv) != 8:
        raise ValueError('Missing exact sandboxed diagnostic command')
    profile = Path(argv[2])
    scratch = profile.parent
    if (not scratch.is_relative_to(SCRATCH_ROOT) or scratch.parent != SCRATCH_ROOT or
            profile.name != 'diagnostic.sb' or
            argv != ['/usr/bin/sandbox-exec', '-f', str(profile), '/usr/bin/arch',
                     '-' + architecture, str(app / 'Contents/MacOS/Flash'),
                     '--flash-verify-native-loads', '--challenge=' + record.get('challenge', '')] or
            record.get('sandbox_sha256') != digest(sandbox_profile(app, scratch).encode())):
        raise ValueError('Diagnostic sandbox/command binding mismatch')
    for name in ('stdout', 'stderr'):
        data = base64.b64decode(record[name + '_base64'], validate=True)
        if len(data) > OUTPUT_LIMIT or digest(data) != record[name + '_sha256']:
            raise ValueError('Diagnostic output bound/hash mismatch')
    return parse_protocol(base64.b64decode(record['stdout_base64'], validate=True), record['challenge'])


def validate_evidence(evidence, current, app):
    if (evidence.get('schema') != 1 or evidence.get('qualified') is not True or
            evidence.get('actualGUIloads') is not True or evidence.get('packaging_accepted') is not False or
            evidence.get('before') != current or evidence.get('after') != current):
        raise ValueError('Absent, failed, stale, or different-artifact qualification')
    protocol = validate_execution(evidence.get('execution', {}), app, current['host']['architecture'])
    if protocol != evidence.get('protocol'):
        raise ValueError('Stored protocol does not match bounded captured output')


def save(stream, evidence):
    stream.seek(0)
    json.dump(evidence, stream, indent=2, sort_keys=True)
    stream.write('\n')
    stream.truncate()
    stream.flush()
    os.fsync(stream.fileno())


def run_approved(app, metadata, evidence_path):
    signer = driver()
    if evidence_path.parent != EVIDENCE_ROOT or evidence_path.suffix != '.json' or '..' in evidence_path.parts:
        raise ValueError('Use a new .json file in the dedicated qualification evidence directory')
    canonical(str(EVIDENCE_ROOT))
    signer.check_directory(EVIDENCE_ROOT)
    with make_scratch() as temporary:
        scratch = Path(temporary)
        before_dir = scratch / 'before'
        before_dir.mkdir(mode=0o700)
        before = frozen_state(app, metadata, signer, before_dir)
        evidence = {'schema': 1, 'qualified': False, 'actualGUIloads': False,
                    'packaging_accepted': False, 'before': before, 'limitations': CAVEATS}
        descriptor = os.open(evidence_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            save(stream, evidence)
            try:
                execution = supervise(app, scratch, secrets.token_urlsafe(24), before['host']['architecture'])
                evidence['execution'] = execution
                after_dir = scratch / 'after'
                after_dir.mkdir(mode=0o700)
                evidence['after'] = frozen_state(app, metadata, signer, after_dir)
                evidence['protocol'] = validate_execution(execution, app, before['host']['architecture'])
                if evidence['after'] != before:
                    raise ValueError('Frozen inputs changed during diagnostic')
                evidence['qualified'] = True
                evidence['actualGUIloads'] = True
            except BaseException as error:
                evidence['failure'] = type(error).__name__
                save(stream, evidence)
                raise
            save(stream, evidence)
    return evidence


def check_copy(copy, expected, signer):
    if signer.inventory(copy, signer.trusted_verifier()) != expected['inventory']:
        raise ValueError('Copied or expanded signed bundle differs from qualified input')


def check_expanded(expanded, operation, expected, signer):
    info = ET.fromstring(signer.read_regular(expanded / 'PackageInfo'))
    if (info.tag != 'pkg-info' or
            info.attrib.get('identifier') != 'com.layoute.flash.managed.' + operation or
            info.attrib.get('install-location') != '/'):
        raise ValueError('Expanded package identity/install location mismatch')
    declarations = list(info.iter('scripts'))
    expected_hooks = {'preinstall', 'postinstall'}
    if (len(declarations) != 1 or declarations[0] not in list(info) or declarations[0].attrib or
            len(declarations[0]) != 2 or {node.tag for node in declarations[0]} != expected_hooks or
            any(node.attrib != {'file': './' + node.tag} or len(node) or (node.text or '').strip()
                for node in declarations[0])):
        raise ValueError('Expanded package execution declarations differ from reviewed hooks')
    relocation = list(info.iter('relocate'))
    if (len(relocation) > 1 or any(node not in list(info) or node.attrib or len(node) or
                                 (node.text or '').strip() for node in relocation)):
        raise ValueError('Expanded package must not relocate its fixed-root payload')
    maintenance = signer.read_regular(expanded / 'Scripts/FlashMaintenance')
    if digest(maintenance) != expected['inventory']['Contents/Library/HelperTools/FlashMaintenance']['sha256']:
        raise ValueError('Expanded maintenance signature bytes differ from qualified input')
    scripts = expanded / 'Scripts'
    originals = PACKAGING / 'installer' / operation
    expected_scripts = {path.name for path in originals.iterdir()} | {'FlashMaintenance'}
    if {path.name for path in scripts.iterdir()} != expected_scripts:
        raise ValueError('Unexpected or missing expanded installer script')
    for original in originals.iterdir():
        if signer.read_regular(scripts / original.name) != signer.read_regular(original):
            raise ValueError('Expanded installer script differs from reviewed source')
    apps = list(expanded.rglob('Flash.app'))
    required = expanded / 'Payload/Library/Application Support/Flash/.incoming/Flash.app'
    if operation in {'install', 'repair'}:
        if apps != [required]:
            raise ValueError('Unexpected expanded package payload location/count')
        allowed_parents = set(required.parents)
        for directory, names, files in os.walk(expanded / 'Payload', followlinks=False):
            for name in names + files:
                path = Path(directory) / name
                if not path.is_relative_to(required) and path not in allowed_parents:
                    raise ValueError('Unexpected additional package payload')
        check_copy(required, expected, signer)
    elif apps or (expanded / 'Payload').exists():
        raise ValueError('Nonpayload operation unexpectedly contains a payload')


def verify(app, metadata, evidence_path, copied=None, expanded=None, operation=None):
    signer = driver()
    evidence, _ = protected_json(evidence_path, signer)
    with make_scratch() as temporary:
        current = frozen_state(app, metadata, signer, Path(temporary))
        validate_evidence(evidence, current, app)
        if copied:
            check_copy(copied, current, signer)
        if expanded:
            check_expanded(expanded, operation, current, signer)
    return evidence


def main():
    if not (sys.flags.isolated and sys.flags.no_site and sys.dont_write_bytecode) or os.getuid() == 0:
        print('Use non-root /usr/bin/python3 -I -S -B.', file=sys.stderr)
        return 1
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--run-approved-probe', action='store_true')
    mode.add_argument('--verify-evidence', action='store_true')
    parser.add_argument('--app', required=True)
    parser.add_argument('--build-metadata', required=True)
    parser.add_argument('--evidence', required=True)
    parser.add_argument('--verify-copy')
    parser.add_argument('--verify-expanded-package')
    parser.add_argument('--package-operation', choices=('install', 'repair', 'disable', 'remove'))
    args = parser.parse_args()
    try:
        app = canonical(args.app)
        metadata = canonical(args.build_metadata)
        evidence_path = Path(args.evidence)
        if not evidence_path.is_absolute() or str(evidence_path) != args.evidence:
            raise ValueError('Evidence must use a canonical absolute path')
        if args.run_approved_probe:
            if args.verify_copy or args.verify_expanded_package or args.package_operation:
                raise ValueError('Probe and packaging verification cannot be combined')
            run_approved(app, metadata, evidence_path)
        else:
            if bool(args.verify_expanded_package) != bool(args.package_operation):
                raise ValueError('Expanded package verification requires its operation')
            verify(app, metadata, canonical(str(evidence_path)),
                   canonical(args.verify_copy) if args.verify_copy else None,
                   canonical(args.verify_expanded_package) if args.verify_expanded_package else None,
                   args.package_operation)
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'Native-load qualification failed closed: {type(error).__name__}', file=sys.stderr)
        return 1
    print('Exact-artifact native-load evidence verified; helper/installer acceptance remains unverified.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
