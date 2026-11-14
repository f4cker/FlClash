#!/usr/bin/env python3
"""Split staging only: no build, signing, runtime qualification, or installation."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import sys

PACKAGING = Path(__file__).resolve().parent
GUI_PATH = '/Applications/Flash.app'
SERVICE_PATH = '/Library/Application Support/Flash/Flash.app'
SERVICE_ID = 'com.layoute.flash.service'
CERTIFICATE_SHA1 = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'
CERTIFICATE_SHA256 = 'E8346770F4BF2ABC94F755A136677CDA84B821A668B0983E7FBEF21F8A646E95'
FRAMEWORKS = ('App', 'FlutterMacOS', 'objective_c', 'rust_api', 'sqlite3')
CORE = 'Contents/MacOS/FlClashCore'
HELPER = 'Contents/Library/HelperTools/FlashHelper'
MAINTENANCE = 'Contents/Library/HelperTools/FlashMaintenance'
DAEMON = 'Contents/Library/LaunchDaemons/com.layoute.flash.helper.plist'
OPERATIONS = ('install', 'repair', 'disable', 'remove')
EVIDENCE_SCHEMA = 'flash-split-native-loads-v1'
COMPATIBILITY_KEY = 'FlashHelperCompatibility'
COMPATIBILITY_VERSIONS = {'CallerPolicy': 2, 'ServiceAPI': 1, 'CoreAPI': 1}


def load_local(name):
    spec = importlib.util.spec_from_file_location('_split_' + name, PACKAGING / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inventory(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Expected a real bundle directory')
    entries = {}
    for directory, names, files in os.walk(root, followlinks=False):
        for name in sorted(names + files):
            path = Path(directory) / name
            mode = path.lstat().st_mode
            entry = {'mode': stat.S_IMODE(mode)}
            if stat.S_ISLNK(mode):
                if not path.resolve(strict=True).is_relative_to(root.resolve(strict=True)):
                    raise ValueError('Escaping bundle link')
                entry.update(kind='link', target=os.readlink(path))
            elif stat.S_ISREG(mode):
                if path.stat().st_nlink != 1:
                    raise ValueError('Hardlinked payload file')
                entry.update(kind='file', sha256=hashlib.sha256(path.read_bytes()).hexdigest())
            elif stat.S_ISDIR(mode):
                entry['kind'] = 'directory'
            else:
                raise ValueError('Special payload file')
            entries[str(path.relative_to(root))] = entry
    return entries


def new_destination(destination, sources):
    if destination.name != 'Flash.app' or destination.exists() or destination.is_symlink():
        raise ValueError('Destination must be a new Flash.app; never overlay a previous build')
    for source in sources:
        if destination.resolve().is_relative_to(source.resolve(strict=True)):
            raise ValueError('Destination must be outside every input')
    destination.parent.mkdir(parents=True, exist_ok=True)


def signing_targets(kind):
    if kind == 'gui':
        return (CORE, *(f'Contents/Frameworks/{name}.framework' for name in FRAMEWORKS), '.')
    if kind == 'service':
        return (CORE, HELPER, MAINTENANCE, '.')
    raise ValueError('Unknown split payload role')


def check_layout(app, kind):
    verifier = load_local('stage_managed_payload')
    entries = inventory(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    identifier = 'com.layoute.flash' if kind == 'gui' else SERVICE_ID
    if info.get('CFBundleIdentifier') != identifier or info.get('CFBundleExecutable') != 'Flash':
        raise ValueError('Unexpected split bundle identity')
    expected = {CORE, 'Contents/MacOS/Flash'}
    if kind == 'gui':
        if (app / 'Contents/Library').exists():
            raise ValueError('GUI must not embed service tools or launch daemons')
        frameworks = app / 'Contents/Frameworks'
        if {path.name for path in frameworks.iterdir()} != {name + '.framework' for name in FRAMEWORKS}:
            raise ValueError('Expected exactly five fresh GUI frameworks')
        verifier.validate_links(app)
        expected |= {f'Contents/Frameworks/{name}.framework/Versions/A/{name}' for name in FRAMEWORKS}
    else:
        expected |= {HELPER, MAINTENANCE}
        allowed_files = expected | {DAEMON, 'Contents/Info.plist', 'Contents/_CodeSignature/CodeResources'}
        allowed_dirs = {str(parent) for item in allowed_files for parent in Path(item).parents if str(parent) != '.'}
        for relative, entry in entries.items():
            if not ((entry['kind'] == 'file' and relative in allowed_files) or
                    (entry['kind'] == 'directory' and relative in allowed_dirs)):
                raise ValueError('Service contains GUI resources, frameworks, links, or extra files')
        if (app / DAEMON).read_bytes() != (PACKAGING.parent / 'PrivilegedHelper/com.layoute.flash.helper.plist').read_bytes():
            raise ValueError('Service launch daemon differs from reviewed source')
    actual = {relative for relative, entry in entries.items() if entry['kind'] == 'file'
              and (app / relative).read_bytes()[:4] in verifier.MACH_MAGIC}
    if actual != expected:
        raise ValueError('Unknown or missing split Mach-O target')
    for relative in expected:
        if entries[relative]['mode'] != 0o755:
            raise ValueError('Split executable must have mode 0755')
    return entries


def normalize_modes(app):
    magic = load_local('stage_managed_payload').MACH_MAGIC
    for directory, _, files in os.walk(app, followlinks=False):
        Path(directory).chmod(0o755)
        for name in files:
            path = Path(directory) / name
            if not path.is_symlink():
                with path.open('rb') as stream:
                    executable = stream.read(4) in magic
                path.chmod(0o755 if executable else 0o644)


def validate_compatibility(contract, kind):
    if not isinstance(contract, dict) or any(
            type(contract.get(key)) is not int or contract[key] != value
            for key, value in COMPATIBILITY_VERSIONS.items()):
        raise ValueError('Unsupported helper compatibility version')
    def valid_hash(value):
        return isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value) is not None
    if kind == 'gui':
        hashes = contract.get('AcceptedCoreSHA256')
        if (not isinstance(hashes, list) or not 1 <= len(hashes) <= 16 or
                not all(valid_hash(value) for value in hashes) or len(set(hashes)) != len(hashes)):
            raise ValueError('Invalid accepted Core hash list')
    elif kind == 'service':
        if not valid_hash(contract.get('CoreSHA256')) or any(
                not isinstance(contract.get(key), str) or not 1 <= len(contract[key].encode('utf-16-le')) // 2 <= 128
                for key in ('CoreVersion', 'CoreRevision')):
            raise ValueError('Invalid service Core compatibility metadata')
    else:
        raise ValueError('Unknown compatibility role')
    return contract


def read_compatibility(app, kind):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    contract = validate_compatibility(info.get(COMPATIBILITY_KEY), kind)
    core_hash = hashlib.sha256((app / CORE).read_bytes()).hexdigest()
    expected = contract['AcceptedCoreSHA256'] if kind == 'gui' else [contract['CoreSHA256']]
    if core_hash not in expected:
        raise ValueError('Bundled Core differs from sealed compatibility metadata')
    return contract


def compatible_pair(gui, service):
    caller = read_compatibility(gui, 'gui')
    installed = read_compatibility(service, 'service')
    if installed['CoreSHA256'] not in caller['AcceptedCoreSHA256']:
        raise ValueError('GUI does not accept this service Core')
    return installed


def seal_compatibility(app, kind, contract):
    if (app / 'Contents/_CodeSignature').exists():
        raise ValueError('Compatibility metadata must precede outer signing')
    validate_compatibility(contract, kind)
    path = app / 'Contents/Info.plist'
    info = plistlib.loads(path.read_bytes())
    info[COMPATIBILITY_KEY] = contract
    path.write_bytes(plistlib.dumps(info))
    read_compatibility(app, kind)


def released_core_bytes(path, expected_sha256):
    if not re.fullmatch(r'[0-9a-f]{64}', expected_sha256 or ''):
        raise ValueError('Explicit released signed Core SHA256 required')
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('Released Core must be a real single-link file')
        data = stream.read()
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise ValueError('Released signed Core hash mismatch')
    return data


def stage_gui(source, destination, released_core=None, core_sha256=None, accepted_core_sha256=None):
    inventory(source)
    sources = [source]
    if released_core is not None:
        core = released_core_bytes(released_core, core_sha256)
        sources.append(released_core)
    elif core_sha256 is not None:
        raise ValueError('Released Core source required')
    new_destination(destination, sources)
    shutil.copytree(source, destination, symlinks=True)
    library = destination / 'Contents/Library'
    if library.exists():
        shutil.rmtree(library)
    signature = destination / 'Contents/_CodeSignature'
    if signature.exists():
        shutil.rmtree(signature)
    normalize_modes(destination)
    check_layout(destination, 'gui')
    verifier = load_local('stage_managed_payload')
    verifier.FIXED_EXECUTABLES = (CORE,)
    verifier.audit(destination, mutate=True)
    if released_core is not None:
        (destination / CORE).write_bytes(core)
        if released_core_bytes(released_core, core_sha256) != core:
            raise ValueError('Released Core changed during staging')
        verifier.audit(destination, mutate=False)
        seal_compatibility(destination, 'gui', {
            **COMPATIBILITY_VERSIONS,
            'AcceptedCoreSHA256': accepted_core_sha256 if accepted_core_sha256 is not None else [core_sha256],
        })
    normalize_modes(destination)
    check_layout(destination, 'gui')


def stage_service(gui, stub, helper, maintenance, destination, core_version, core_revision):
    check_layout(gui, 'gui')
    read_compatibility(gui, 'gui')
    compatibility = validate_compatibility({
        **COMPATIBILITY_VERSIONS,
        'CoreSHA256': hashlib.sha256((gui / CORE).read_bytes()).hexdigest(),
        'CoreVersion': core_version, 'CoreRevision': core_revision,
    }, 'service')
    sources = [gui, stub, helper, maintenance]
    for path in sources[1:]:
        if path.is_symlink() or not path.is_file() or path.stat().st_nlink != 1:
            raise ValueError('Service inputs must be real single-link files')
    new_destination(destination, sources)
    mapping = {CORE: gui / CORE, 'Contents/MacOS/Flash': stub, HELPER: helper,
               MAINTENANCE: maintenance,
               DAEMON: PACKAGING.parent / 'PrivilegedHelper/com.layoute.flash.helper.plist'}
    for relative, source in mapping.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o644 if relative == DAEMON else 0o755)
    source_info = plistlib.loads((gui / 'Contents/Info.plist').read_bytes())
    info = {key: source_info[key] for key in ('CFBundleVersion', 'CFBundleShortVersionString') if key in source_info}
    info.update(CFBundleIdentifier=SERVICE_ID, CFBundleExecutable='Flash',
                CFBundleName='Flash Service', CFBundlePackageType='APPL',
                LSBackgroundOnly=True, LSMinimumSystemVersion='14.0')
    info[COMPATIBILITY_KEY] = compatibility
    (destination / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    (destination / 'Contents/Info.plist').chmod(0o644)
    for directory, _, _ in os.walk(destination):
        Path(directory).chmod(0o755)
    check_layout(destination, 'service')
    if (destination / CORE).read_bytes() != (gui / CORE).read_bytes():
        raise ValueError('Service must reuse the exact signed GUI Core bytes')


def verify_copy(original, copied, kind):
    if check_layout(original, kind) != check_layout(copied, kind):
        raise ValueError('Copied payload differs from exact input')


def verify_split_gui(app):
    entries = check_layout(app, 'gui')
    verifier = load_local('stage_managed_payload')
    verifier.FIXED_EXECUTABLES = (CORE,)
    verifier.audit(app, mutate=False)
    return entries


def verify_split_service(app, gui=None):
    entries = check_layout(app, 'service')
    verifier = load_local('stage_managed_payload')
    binaries = [app / relative for relative in (CORE, HELPER, MAINTENANCE, 'Contents/MacOS/Flash')]
    commands = {binary: verifier.load_commands(binary) for binary in binaries}
    required = set(commands[binaries[0]])
    for binary, slices in commands.items():
        if set(slices) != required:
            raise ValueError('Service architecture coverage differs')
        for architecture, (paths, dependencies) in slices.items():
            rpaths = [verifier.check_rpath(path, binary, binary, app) for path in paths]
            for dependency in dependencies:
                verifier.check_dependency(dependency, binary, binary, app, rpaths, architecture, commands)
    read_compatibility(app, 'service')
    if gui is not None:
        compatible_pair(gui, app)
    return entries


def finalize_core_copy(gui, service):
    check_layout(gui, 'gui')
    check_layout(service, 'service')
    compatible_pair(gui, service)
    if (service / CORE).read_bytes() != (gui / CORE).read_bytes():
        raise ValueError('Released Core is immutable; stage a new service for a Core change')


def qualification_binding(gui, service, metadata):
    def descriptor(app, kind):
        entries = check_layout(app, kind)
        encoded = json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()
        return {'path': str(app.resolve(strict=True)),
                'inventory_sha256': hashlib.sha256(encoded).hexdigest()}
    return {'gui': descriptor(gui, 'gui'), 'service': descriptor(service, 'service'),
            'build_metadata_sha256': hashlib.sha256(metadata.read_bytes()).hexdigest(),
            'certificate_sha1': CERTIFICATE_SHA1, 'certificate_sha256': CERTIFICATE_SHA256,
            'gui_install_path': GUI_PATH, 'service_install_path': SERVICE_PATH,
            'service_identifier': SERVICE_ID}


def verify_release(gui, service, gui_receipt, gui_sha256, service_receipt, service_sha256,
                   compile_receipt=None, compile_sha256=None):
    check_layout(gui, 'gui')
    check_layout(service, 'service')
    compatible_pair(gui, service)
    return load_local('verify_split_service').verify(
        gui, service, gui_receipt, gui_sha256, service_receipt, service_sha256,
        compile_receipt, compile_sha256,
    )


def verify_expanded(service, expanded, operation):
    normalizer = load_local('normalize_package_info')
    data = (expanded / 'PackageInfo').read_bytes()
    if normalizer.normalize_info(data, operation) != data:
        raise ValueError('Expanded PackageInfo still has a hook timeout')
    scripts = expanded / 'Scripts'
    originals = PACKAGING / 'installer' / operation
    expected = {path.name: path.read_bytes() for path in originals.iterdir()}
    expected['FlashMaintenance'] = (service / MAINTENANCE).read_bytes()
    if {path.name for path in scripts.iterdir()} != set(expected):
        raise ValueError('Unexpected package scripts')
    for name, content in expected.items():
        path = scripts / name
        if path.is_symlink() or not path.is_file() or path.read_bytes() != content or stat.S_IMODE(path.stat().st_mode) != 0o755:
            raise ValueError('Package scripts must preserve reviewed bytes and mode 0755')
    payload = expanded / 'Payload'
    if operation in ('disable', 'remove'):
        if payload.exists():
            raise ValueError('Maintenance-only package must not have a payload')
        return
    app = payload / 'Library/Application Support/Flash/.incoming/Flash.app'
    verify_copy(service, app, 'service')
    for directory, names, files in os.walk(payload, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            if not path.is_relative_to(app) and path not in app.parents:
                raise ValueError('Unexpected package payload outside fixed service path')


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    commands = parser.add_subparsers(dest='command', required=True)
    gui = commands.add_parser('gui', allow_abbrev=False)
    gui.add_argument('--fresh-build-app', required=True, type=Path)
    gui.add_argument('--output', required=True, type=Path)
    gui.add_argument('--released-core', required=True, type=Path)
    gui.add_argument('--core-sha256', required=True)
    gui.add_argument('--accepted-core-sha256', action='append')
    service = commands.add_parser('service', allow_abbrev=False)
    service.add_argument('--signed-gui', required=True, type=Path)
    service.add_argument('--core-version', required=True)
    service.add_argument('--core-revision', required=True)
    for name in ('stub', 'helper', 'maintenance', 'output'):
        service.add_argument('--' + name, required=True, type=Path)
    refresh = commands.add_parser('finalize-core-copy', allow_abbrev=False)
    for name in ('gui', 'service'):
        refresh.add_argument('--' + name, required=True, type=Path)
    gate = commands.add_parser('verify-release', allow_abbrev=False)
    for name in ('gui', 'service', 'gui-receipt', 'service-receipt'):
        gate.add_argument('--' + name, required=True, type=Path)
    for name in ('gui-sha256', 'service-sha256'):
        gate.add_argument('--' + name, required=True)
    gate.add_argument('--compile-receipt', type=Path)
    gate.add_argument('--compile-sha256')
    copied = commands.add_parser('verify-copy', allow_abbrev=False)
    copied.add_argument('--kind', required=True, choices=('gui', 'service'))
    for name in ('original', 'copy'):
        copied.add_argument('--' + name, required=True, type=Path)
    expanded = commands.add_parser('verify-expanded', allow_abbrev=False)
    expanded.add_argument('--operation', required=True, choices=OPERATIONS)
    for name in ('service', 'expanded'):
        expanded.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'gui':
            stage_gui(args.fresh_build_app, args.output, args.released_core, args.core_sha256, args.accepted_core_sha256)
        elif args.command == 'service':
            stage_service(args.signed_gui, args.stub, args.helper, args.maintenance, args.output,
                          args.core_version, args.core_revision)
        elif args.command == 'finalize-core-copy':
            finalize_core_copy(args.gui, args.service)
        elif args.command == 'verify-release':
            verify_release(args.gui, args.service, args.gui_receipt, args.gui_sha256,
                           args.service_receipt, args.service_sha256,
                           args.compile_receipt, args.compile_sha256)
        elif args.command == 'verify-copy':
            verify_copy(args.original, args.copy, args.kind)
        else:
            verify_expanded(args.service, args.expanded, args.operation)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'Split staging failed closed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
