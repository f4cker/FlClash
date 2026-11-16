#!/usr/bin/python3
"""Fixed staging-only signer; run only through the separately reviewed signing guard.

The guard must freeze this driver and inputs, exclude concurrent writers, sanitize
Python startup (use -I -S -B), validate ancestor ACLs, and own keychain unlock/lock.
This program never unlocks, enumerates, or changes a keychain. Static evidence is
not GUI load acceptance and cannot establish the defines embedded by a compiler.
"""
import argparse
import base64
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import types

WORKTREE = Path('/Users/lavas/Library/Application Support/plus.yellow.AirBuild/environment/a6604af9-17b7-4c44-9d33-261a665bd547/projects/770e9d36-b2a0-45c9-a3a3-dd6b6836c72f')
KEYCHAIN = '/Users/lavas/Library/Application Support/Flash Signing/FlashSigning.keychain-db'
CERTIFICATE_SHA1 = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'
CERTIFICATE_SHA256 = 'E8346770F4BF2ABC94F755A136677CDA84B821A668B0983E7FBEF21F8A646E95'
VERIFIER_SHA256 = '006b6d11b10d0875654fab009e7b6a231ebfb83f12cbb0a8c77ec0c463d65829'
PACKAGING = WORKTREE / 'macos/packaging'
GUI_ENTITLEMENTS = {
    'com.apple.security.files.user-selected.read-write': True,
    'com.apple.security.personal-information.location': True,
    'com.apple.security.cs.disable-library-validation': True,
}
FRAMEWORKS = {
    'App': 'io.flutter.flutter.app',
    'FlutterMacOS': 'io.flutter.flutter-macos',
    'objective_c': 'io.flutter.flutter.native-assets.objective-c',
    'rust_api': 'io.flutter.flutter.native-assets.rust-api',
    'sqlite3': 'io.flutter.flutter.native-assets.sqlite3',
}
FIXED = (
    ('core', 'Contents/MacOS/FlClashCore', 'com.layoute.flash.core'),
    ('helper', 'Contents/Library/HelperTools/FlashHelper', 'com.layoute.flash.helper'),
    ('maintenance', 'Contents/Library/HelperTools/FlashMaintenance', 'com.layoute.flash.maintenance'),
)
ENVIRONMENT = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
TOOLS = {'/usr/bin/codesign', '/usr/bin/otool', '/usr/bin/lipo'}
MACH_MAGIC = {bytes.fromhex(value) for value in (
    'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
    'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca',
)}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def run_tool(arguments):
    if not arguments or arguments[0] not in TOOLS:
        raise ValueError('Tool outside fixed allowlist')
    return subprocess.run(
        arguments, check=True, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env=dict(ENVIRONMENT), cwd='/', timeout=120,
    )


def verifier_output(arguments, text=False):
    if arguments[0] not in {'/usr/bin/otool', '/usr/bin/lipo'}:
        raise ValueError('Verifier may only inspect load commands and architectures')
    output = run_tool(arguments).stdout
    return output.decode('utf-8', errors='strict') if text else output


def trusted_verifier():
    path = PACKAGING / 'stage_managed_payload.py'
    source = read_regular(path)
    if sha256(source) != VERIFIER_SHA256:
        raise ValueError('Staging verifier changed; review and repin before signing')
    module = types.ModuleType('_fixed_staging_verifier')
    exec(compile(source, str(path), 'exec'), module.__dict__)
    module.subprocess = types.SimpleNamespace(check_output=verifier_output)
    return module


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            raise ValueError(f'Expected single-link regular file: {path}')
        if metadata.st_uid != os.getuid() or metadata.st_mode & 0o7022:
            raise ValueError(f'Unsafe file owner/mode: {path}')
        return stream.read()


def require_no_acl(path):
    if sys.platform != 'darwin':
        raise ValueError('Signing requires macOS ACL inspection')
    before = path.lstat()
    if stat.S_IFMT(before.st_mode) not in {stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK} or before.st_nlink < 1:
        raise ValueError(f'Cannot inspect ACL of unknown node type/link metadata: {path}')
    library = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
    library.acl_init.argtypes = [ctypes.c_int]
    library.acl_init.restype = ctypes.c_void_p
    library.acl_get_link_np.argtypes = [ctypes.c_char_p, ctypes.c_int]
    library.acl_get_link_np.restype = ctypes.c_void_p
    library.acl_size.argtypes = [ctypes.c_void_p]
    library.acl_size.restype = ctypes.c_ssize_t
    library.acl_valid.argtypes = [ctypes.c_void_p]
    library.acl_valid.restype = ctypes.c_int
    library.acl_free.argtypes = [ctypes.c_void_p]
    library.acl_free.restype = ctypes.c_int
    empty = library.acl_init(0)
    ctypes.set_errno(0)
    acl = library.acl_get_link_np(os.fsencode(path), 0x100)
    error = ctypes.get_errno()
    try:
        after = path.lstat()
        fields = ('st_dev', 'st_ino', 'st_mode', 'st_uid', 'st_gid', 'st_nlink', 'st_flags', 'st_ctime_ns')
        if any(getattr(before, field) != getattr(after, field) for field in fields):
            raise ValueError(f'ACL node metadata changed during inspection: {path}')
        if not empty:
            raise ValueError(f'Cannot allocate empty ACL baseline: {path}')
        baseline = library.acl_size(empty)
        if baseline <= 0:
            raise ValueError(f'Cannot inspect empty ACL baseline: {path}')
        # Darwin reports ENOENT for an existing unchanged node with no ACL.
        if not acl:
            if error != errno.ENOENT:
                raise ValueError(f'Cannot inspect extended ACL: {path}')
            return
        if library.acl_valid(acl) != 0 or library.acl_size(acl) != baseline:
            raise ValueError(f'Extended ACLs are not allowed: {path}')
    finally:
        if acl:
            library.acl_free(acl)
        if empty:
            library.acl_free(empty)


def check_directory(path):
    require_no_acl(path)
    metadata = path.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise ValueError(f'Expected owned real directory: {path}')
    if metadata.st_mode & 0o7022:
        raise ValueError(f'Unsafe directory mode: {path}')


def staging_path(value):
    path = Path(value)
    staging = WORKTREE / '.airbuild'
    if not path.is_absolute() or str(path) != value or '..' in path.parts:
        raise ValueError('App path must be absolute and canonical')
    if path.name != 'Flash.app' or not path.is_relative_to(staging):
        raise ValueError('Only Flash.app staged inside this worktree/.airbuild is allowed')
    if path.resolve(strict=True) != path or WORKTREE.resolve(strict=True) != WORKTREE:
        raise ValueError('Staging ancestors must not contain symlinks')
    for parent in reversed((path, *path.parents)):
        if parent == staging or parent.is_relative_to(staging):
            check_directory(parent)
    return path


def inventory(app, verifier):
    check_directory(app)
    verifier.validate_links(app)
    entries = {}
    for directory, names, files in os.walk(app, followlinks=False):
        for name in sorted(names + files):
            path = Path(directory) / name
            relative = str(path.relative_to(app))
            metadata = path.lstat()
            require_no_acl(path)
            if metadata.st_uid != os.getuid() or (
                    not stat.S_ISLNK(metadata.st_mode) and metadata.st_mode & 0o7022):
                raise ValueError(f'Unsafe payload owner/mode: {relative}')
            entry = {'mode': oct(stat.S_IMODE(metadata.st_mode))}
            if stat.S_ISLNK(metadata.st_mode):
                entry.update(kind='symlink', target=os.readlink(path))
            elif stat.S_ISDIR(metadata.st_mode):
                entry['kind'] = 'directory'
            elif stat.S_ISREG(metadata.st_mode):
                data = read_regular(path)
                entry.update(kind='file', sha256=sha256(data), size=len(data),
                             macho=data[:4] in MACH_MAGIC)
                if metadata.st_mode & 0o111 and not entry['macho']:
                    raise ValueError(f'Unexpected executable resource: {relative}')
            else:
                raise ValueError(f'Special file in payload: {relative}')
            entries[relative] = entry
    return entries


def plist_identifier(path, identifier, executable):
    data = plistlib.loads(read_regular(path.resolve(strict=True)))
    if data.get('CFBundleIdentifier') != identifier or data.get('CFBundleExecutable') != executable:
        raise ValueError(f'Unexpected bundle identity: {path}')


def signing_targets(app, entries):
    plist_identifier(app / 'Contents/Info.plist', 'com.layoute.flash', 'Flash')
    targets = []
    for role, relative, identifier in FIXED:
        targets.append(dict(role=role, path=relative, binary=relative, identifier=identifier))
    framework_root = app / 'Contents/Frameworks'
    if {path.name for path in framework_root.iterdir()} != {f'{name}.framework' for name in FRAMEWORKS}:
        raise ValueError('Unknown or missing nested framework')
    for name, identifier in sorted(FRAMEWORKS.items()):
        framework = framework_root / f'{name}.framework'
        check_directory(framework)
        binary = (framework / name).resolve(strict=True)
        if binary != framework / f'Versions/A/{name}':
            raise ValueError('Only fixed Versions/A frameworks are allowed')
        plist_identifier(framework / 'Resources/Info.plist', identifier, name)
        targets.append(dict(role='framework', path=str(framework.relative_to(app)),
                            binary=str(binary.relative_to(app)), identifier=identifier))
    targets.append(dict(role='gui', path='.', binary='Contents/MacOS/Flash', identifier='com.layoute.flash'))
    expected = {target['binary'] for target in targets}
    actual = {path for path, entry in entries.items() if entry.get('macho')}
    if actual != expected:
        raise ValueError(f'Unknown or missing Mach-O code: {sorted(actual ^ expected)}')
    for binary in expected:
        path = app / binary
        if not path.stat().st_mode & stat.S_IXUSR or path.is_symlink():
            raise ValueError(f'Code must be a real owner-executable file: {binary}')
    for target in targets:
        target['entitlements'] = dict(GUI_ENTITLEMENTS) if target['role'] == 'gui' else {}
        target['designated_requirement'] = requirement(target['identifier'])
    return targets


def requirement(identifier):
    return (f'anchor H"{CERTIFICATE_SHA1}" and '
            f'certificate leaf = H"{CERTIFICATE_SHA1}" and identifier "{identifier}"')


def sign_arguments(app, target, entitlement_file):
    return ['/usr/bin/codesign', '--force', '--sign', CERTIFICATE_SHA1,
            '--keychain', KEYCHAIN, '--timestamp=none', '--options', 'runtime',
            '--identifier', target['identifier'], '--requirements',
            '=designated => ' + requirement(target['identifier']),
            '--entitlements', str(entitlement_file), str(app / target['path'])]


def displayed_entitlements(output):
    if not output.strip():
        return {}
    result = plistlib.loads(output)
    if not isinstance(result, dict):
        raise ValueError('Malformed entitlement dictionary')
    return result


def verify_target(app, target, scratch):
    path = str(app / target['path'])
    run_tool(['/usr/bin/codesign', '--verify', '--strict', '--all-architectures',
              '-R', '=' + requirement(target['identifier']), path])
    slices = {}
    for architecture in target['architectures']:
        detail = run_tool(['/usr/bin/codesign', '--display', '--verbose=4',
                           '--arch', architecture, path]).stderr.decode('utf-8', errors='strict')
        flags = re.search(r'^CodeDirectory .*? flags=(0x[0-9a-fA-F]+)\(([^\n]*)\)', detail, re.M)
        if not flags or int(flags.group(1), 16) != 0x10000 or flags.group(2) != 'runtime':
            raise ValueError('Expected only hardened runtime signature flags')
        if f'Identifier={target["identifier"]}\n' not in detail or 'Signature=adhoc' in detail:
            raise ValueError('Signature identifier/identity mismatch')
        if 'TeamIdentifier=not set\n' not in detail or 'Timestamp=' in detail:
            raise ValueError('Expected fixed no-Team, no-timestamp identity')
        entitlements = displayed_entitlements(run_tool([
            '/usr/bin/codesign', '--display', '--arch', architecture,
            '--entitlements', ':-', path,
        ]).stdout)
        if entitlements != target['entitlements']:
            raise ValueError('Unexpected signed entitlements')
        prefix = scratch / f'{target["role"]}-{architecture}-cert-'
        run_tool(['/usr/bin/codesign', '--display', '--arch', architecture,
                  '--extract-certificates=' + str(prefix), path])
        certificate = read_regular(Path(str(prefix) + '0'))
        if (hashlib.sha1(certificate).hexdigest().upper() != CERTIFICATE_SHA1 or
                sha256(certificate).upper() != CERTIFICATE_SHA256):
            raise ValueError('Extracted leaf certificate pin mismatch')
        slices[architecture] = {'flags': '0x10000(runtime)', 'entitlements': entitlements,
                                'certificate_sha1': CERTIFICATE_SHA1,
                                'certificate_sha256': CERTIFICATE_SHA256,
                                'display_sha256': sha256(detail.encode())}
    return slices


def check_signing_delta(before, after, targets):
    mutable = {target['binary'] for target in targets}
    signature_directories = {'Contents/_CodeSignature'} | {
        target['path'] + '/Versions/A/_CodeSignature'
        for target in targets if target['role'] == 'framework'
    }
    mutable |= signature_directories | {path + '/CodeResources' for path in signature_directories}
    for path in before.keys() | after.keys():
        if before.get(path) != after.get(path) and path not in mutable:
            raise ValueError(f'Non-signature payload mutation: {path}')


def tree_digest(entries):
    return sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode())


def tool_failure_details(error, app, targets):
    command = error.cmd
    if not isinstance(command, (list, tuple)) or not command or command[0] not in TOOLS:
        return {'details_omitted': 'Command outside fixed tool allowlist'}
    action = {'/usr/bin/lipo': 'inspect-architectures', '/usr/bin/otool': 'inspect-load-commands'}.get(command[0])
    if command[0] == '/usr/bin/codesign':
        options = {argument.split('=', 1)[0] for argument in command[1:] if isinstance(argument, str)}
        action = next((name for flag, name in (
            ('--sign', 'sign'), ('--verify', 'verify'), ('--extract-certificates', 'display-certificates'),
            ('--entitlements', 'display-entitlements'), ('--display', 'display'),
        ) if flag in options), 'unrecognized')
        if action == 'verify' and '--deep' in command:
            action = 'verify-deep'
    target = next((target for target in targets if command[-1] in {
        str(app / target['path']), str(app / target['binary']),
    }), None)
    details = {'tool': command[0], 'action': action,
               'target': {key: target[key] for key in ('role', 'path', 'identifier')} if target else None,
               'returncode': error.returncode if isinstance(error, subprocess.CalledProcessError) else None}
    if isinstance(error, subprocess.TimeoutExpired):
        details['timeout_seconds'] = error.timeout
    for name in ('stdout', 'stderr'):
        data = getattr(error, name, None) or b''
        if isinstance(data, str):
            data = data.encode('utf-8')
        retained = data[:4096]
        details[name] = {'text': retained.decode('utf-8', errors='replace'),
                         'base64': base64.b64encode(retained).decode('ascii'),
                         'captured_bytes': len(data), 'retained_bytes': len(retained),
                         'truncated': len(data) > len(retained)}
    return details


def execute(app_value, keychain, certificate):
    if keychain != KEYCHAIN or certificate != CERTIFICATE_SHA1 or os.getuid() == 0:
        raise ValueError('Only the fixed identity/keychain and non-root caller are allowed')
    if Path(__file__).absolute() != PACKAGING / 'sign_fixed_payload.py':
        raise ValueError('Driver must run from the reviewed worktree')
    app = staging_path(app_value)
    verifier = trusted_verifier()
    before = inventory(app, verifier)
    targets = signing_targets(app, before)
    verifier.audit(app)
    for target in targets:
        target['architectures'] = sorted(verifier.load_commands(app / target['binary']))
    if any(target['architectures'] != targets[-1]['architectures'] for target in targets):
        raise ValueError('Every nested code object must exactly match GUI architectures')
    entitlement_source = read_regular(PACKAGING / 'FixedGUI.entitlements')
    if plistlib.loads(entitlement_source) != GUI_ENTITLEMENTS:
        raise ValueError('Dedicated GUI entitlements changed')
    if inventory(app, verifier) != before:
        raise ValueError('Payload changed during preflight')
    report_path = app.parent / 'Flash.signing-static.json'
    report = {
        'schema': 1, 'app': str(app), 'static_verification': False, 'actualGUIloads': False,
        'packaging_accepted': False, 'runtime_gate_changed': False,
        'pins': {'certificate_sha1': CERTIFICATE_SHA1, 'certificate_sha256': CERTIFICATE_SHA256},
        'inputs': {'driver_sha256': sha256(read_regular(Path(__file__))),
                   'verifier_sha256': VERIFIER_SHA256, 'gui_entitlements_sha256': sha256(entitlement_source)},
        'defines': {'artifact_values': 'not established by static signing',
                    'intended_static_candidate': {
                        'MACOS_MANAGED_HELPER': True,
                        'FC_PINNED_CERTIFICATE_SHA1': CERTIFICATE_SHA1,
                        'FC_MANAGED_CANDIDATE_ENABLED': 1,
                    },
                    'FC_MANAGED_CANDIDATE_ENABLED': 'not modified or asserted',
                    'FC_PINNED_CERTIFICATE_SHA1': 'not modified or asserted',
                    'MACOS_MANAGED_HELPER': 'not modified or asserted'},
        'limitations': ['No code execution, GUI loading, install, or package acceptance.',
                        'Guard must freeze inputs, exclude writers, and validate ancestor ACLs.',
                        'Mode/owner/link checks do not defend against a hostile same-UID writer.',
                        'Trusted system Python/stdlib startup and fixed Apple tools are prerequisites.',
                        'codesign child authorization UI cannot be guaranteed quiet.',
                        'No automatic retry; failures may leave a partially signed stage.'],
        'before': {'tree_sha256': tree_digest(before), 'entries': before}, 'targets': targets,
    }
    descriptor = os.open(report_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        def save_report():
            stream.seek(0)
            json.dump(report, stream, indent=2, sort_keys=True)
            stream.write('\n')
            stream.truncate()
            stream.flush()
            os.fsync(stream.fileno())
        save_report()
        try:
            with tempfile.TemporaryDirectory(prefix='.fixed-sign-', dir=app.parent) as temporary:
                scratch = Path(temporary)
                gui_entitlements = scratch / 'gui.plist'
                gui_entitlements.write_bytes(entitlement_source)
                empty_entitlements = scratch / 'empty.plist'
                empty_entitlements.write_bytes(plistlib.dumps({}))
                for target in targets:
                    entitlement_file = gui_entitlements if target['role'] == 'gui' else empty_entitlements
                    run_tool(sign_arguments(app, target, entitlement_file))
                for index, target in enumerate(targets):
                    certificates = scratch / str(index)
                    certificates.mkdir(mode=0o700)
                    target['verified_slices'] = verify_target(app, target, certificates)
                run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict',
                          '--all-architectures', str(app)])
                verifier.audit(app)
                after = inventory(app, verifier)
                signing_targets(app, after)
                check_signing_delta(before, after, targets)
                report['after'] = {'tree_sha256': tree_digest(after), 'entries': after}
                report['static_verification'] = True
        except BaseException as error:
            report['failure'] = type(error).__name__
            if isinstance(error, (subprocess.CalledProcessError, subprocess.TimeoutExpired)):
                report['failure_details'] = tool_failure_details(error, app, targets)
            save_report()
            raise
        save_report()
    return report_path


def main():
    if not (sys.flags.isolated and sys.flags.no_site and sys.dont_write_bytecode):
        print('Guard must invoke /usr/bin/python3 -I -S -B.', file=sys.stderr)
        return 1
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--app', required=True)
    parser.add_argument('--keychain', required=True)
    parser.add_argument('--certificate', required=True)
    arguments = parser.parse_args()
    try:
        result = execute(arguments.app, arguments.keychain, arguments.certificate)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'Fixed signing failed closed: {type(error).__name__}', file=sys.stderr)
        return 1
    print(f'Static report: {result}; actualGUIloads=false; packaging acceptance remains gated.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
