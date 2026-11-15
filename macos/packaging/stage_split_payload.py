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
ICON = 'Contents/Resources/AppIcon.icns'
MINIMUM_SERVICE_BUILD_KEY = 'FlashMinimumServiceBuild'
SERVICE_WRAPPER_BUILD = '2026111408'
CURRENT_SERVICE_BUILD = '2026111503'
HELPER_BINARY_BUILD = '2026111402'
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
        return (*(f'Contents/Frameworks/{name}.framework' for name in FRAMEWORKS), '.')
    if kind == 'service':
        return (CORE, HELPER, MAINTENANCE, '.')
    raise ValueError('Unknown split payload role')


def icon_bytes(path):
    metadata = path.lstat()
    if path.resolve(strict=True) != path:
        raise ValueError('Service icon must have a canonical path')
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1 or stat.S_IMODE(metadata.st_mode) != 0o644:
        raise ValueError('Service icon must be a single-link regular file with mode 0644')
    data = path.read_bytes()
    if len(data) <= 8 or data[:4] != b'icns' or int.from_bytes(data[4:8], 'big') != len(data):
        raise ValueError('Invalid service icon header or length')
    return data


def check_layout(app, kind):
    if kind not in ('gui', 'service'):
        raise ValueError('Unknown split payload role')
    if kind == 'gui' and ((app / CORE).exists() or (app / CORE).is_symlink()):
        raise ValueError('GUI must not contain a loose Core')
    verifier = load_local('stage_managed_payload')
    entries = inventory(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    identifier = 'com.layoute.flash' if kind == 'gui' else SERVICE_ID
    if info.get('CFBundleIdentifier') != identifier or info.get('CFBundleExecutable') != 'Flash':
        raise ValueError('Unexpected split bundle identity')
    expected = {'Contents/MacOS/Flash'}
    if kind == 'gui':
        if (app / 'Contents/Library').exists():
            raise ValueError('GUI must not embed service tools or launch daemons')
        frameworks = app / 'Contents/Frameworks'
        if {path.name for path in frameworks.iterdir()} != {name + '.framework' for name in FRAMEWORKS}:
            raise ValueError('Expected exactly five fresh GUI frameworks')
        verifier.validate_links(app)
        expected |= {f'Contents/Frameworks/{name}.framework/Versions/A/{name}' for name in FRAMEWORKS}
    else:
        expected |= {CORE, HELPER, MAINTENANCE}
        icon_present = ICON in entries
        if icon_present != ('CFBundleIconFile' in info) or (icon_present and info['CFBundleIconFile'] != 'AppIcon.icns'):
            raise ValueError('Service icon resource and metadata must match exactly')
        if icon_present:
            icon_bytes(app / ICON)
        allowed_files = expected | {DAEMON, 'Contents/Info.plist', 'Contents/_CodeSignature/CodeResources'}
        if icon_present:
            allowed_files.add(ICON)
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
    for directory, directories, files in os.walk(app, followlinks=False):
        Path(directory).chmod(0o755)
        for name in directories + files:
            path = Path(directory) / name
            if path.is_symlink():
                os.lchmod(path, 0o755)
            elif path.is_file():
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
    if kind == 'gui' and MINIMUM_SERVICE_BUILD_KEY in info:
        minimum = info[MINIMUM_SERVICE_BUILD_KEY]
        if not isinstance(minimum, str) or re.fullmatch(r'[1-9][0-9]{9}', minimum) is None:
            raise ValueError('Invalid minimum service build')
    if kind == 'service' and hashlib.sha256((app / CORE).read_bytes()).hexdigest() != contract['CoreSHA256']:
        raise ValueError('Bundled Core differs from sealed compatibility metadata')
    return contract


def compatible_pair(gui, service):
    caller = read_compatibility(gui, 'gui')
    installed = read_compatibility(service, 'service')
    minimum = plistlib.loads((gui / 'Contents/Info.plist').read_bytes()).get(MINIMUM_SERVICE_BUILD_KEY)
    if minimum is not None:
        version = plistlib.loads((service / 'Contents/Info.plist').read_bytes()).get('CFBundleVersion')
        if not isinstance(version, str) or re.fullmatch(r'[1-9][0-9]{9}', version) is None or int(version) < int(minimum):
            raise ValueError('Service wrapper build is below the GUI minimum')
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
    if released_core is None:
        raise ValueError('Released Core source required')
    core = released_core_bytes(released_core, core_sha256)
    contract = validate_compatibility({
        **COMPATIBILITY_VERSIONS,
        'AcceptedCoreSHA256': accepted_core_sha256 if accepted_core_sha256 is not None else [core_sha256],
    }, 'gui')
    if core_sha256 not in contract['AcceptedCoreSHA256']:
        raise ValueError('GUI must accept the verified released Core')
    new_destination(destination, [source, released_core])
    shutil.copytree(source, destination, symlinks=True)
    library = destination / 'Contents/Library'
    if library.exists():
        shutil.rmtree(library)
    signature = destination / 'Contents/_CodeSignature'
    if signature.exists():
        shutil.rmtree(signature)
    loose_core = destination / CORE
    if loose_core.exists() or loose_core.is_symlink():
        loose_core.unlink()
    normalize_modes(destination)
    check_layout(destination, 'gui')
    verifier = load_local('stage_managed_payload')
    verifier.FIXED_EXECUTABLES = ()
    verifier.audit(destination, mutate=True)
    if released_core_bytes(released_core, core_sha256) != core:
        raise ValueError('Released Core changed during staging')
    info_path = destination / 'Contents/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info[MINIMUM_SERVICE_BUILD_KEY] = CURRENT_SERVICE_BUILD
    info_path.write_bytes(plistlib.dumps(info))
    seal_compatibility(destination, 'gui', contract)
    normalize_modes(destination)
    check_layout(destination, 'gui')


def stage_service(gui, stub, helper, maintenance, destination, core_version, core_revision, *, released_core, core_sha256,
                  service_version=None, service_build=None):
    check_layout(gui, 'gui')
    caller = read_compatibility(gui, 'gui')
    core = released_core_bytes(released_core, core_sha256)
    metadata_only = service_version is not None or service_build is not None
    if metadata_only:
        if (not isinstance(service_version, str) or re.fullmatch(r'\d+\.\d+\.\d+', service_version) is None or
                not isinstance(service_build, str) or re.fullmatch(r'[1-9][0-9]{9}', service_build) is None):
            raise ValueError('Explicit service version and build are both required for a metadata-only GUI source')
    elif core_sha256 not in caller['AcceptedCoreSHA256']:
        raise ValueError('GUI does not accept this service Core')
    icon = icon_bytes(gui / ICON)
    compatibility = validate_compatibility({
        **COMPATIBILITY_VERSIONS,
        'CoreSHA256': core_sha256,
        'CoreVersion': core_version, 'CoreRevision': core_revision,
    }, 'service')
    sources = [gui, stub, helper, maintenance, released_core]
    for path in sources[1:]:
        if path.is_symlink() or not path.is_file() or path.stat().st_nlink != 1:
            raise ValueError('Service inputs must be real single-link files')
    new_destination(destination, sources)
    mapping = {CORE: released_core, ICON: gui / ICON, 'Contents/MacOS/Flash': stub, HELPER: helper,
               MAINTENANCE: maintenance,
               DAEMON: PACKAGING.parent / 'PrivilegedHelper/com.layoute.flash.helper.plist'}
    for relative, source in mapping.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o644 if relative in (DAEMON, ICON) else 0o755)
    source_info = plistlib.loads((gui / 'Contents/Info.plist').read_bytes())
    info = {key: source_info[key] for key in ('CFBundleVersion', 'CFBundleShortVersionString') if key in source_info}
    if metadata_only:
        info.update(CFBundleVersion=service_build, CFBundleShortVersionString=service_version)
    info.update(CFBundleIdentifier=SERVICE_ID, CFBundleExecutable='Flash',
                CFBundleName='Flash Service', CFBundlePackageType='APPL',
                LSBackgroundOnly=True, LSMinimumSystemVersion='14.0', CFBundleIconFile='AppIcon.icns')
    info[COMPATIBILITY_KEY] = compatibility
    (destination / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    (destination / 'Contents/Info.plist').chmod(0o644)
    for directory, _, _ in os.walk(destination):
        Path(directory).chmod(0o755)
    check_layout(destination, 'service')
    if (destination / ICON).read_bytes() != icon or icon_bytes(gui / ICON) != icon:
        raise ValueError('Service icon changed during staging')
    if (destination / CORE).read_bytes() != core or released_core_bytes(released_core, core_sha256) != core:
        raise ValueError('Service must reuse the exact released signed Core bytes')


def derive_service_wrapper(source, gui, destination, *, source_receipt, source_receipt_sha256,
                           source_compile_receipt, source_compile_sha256):
    gate = load_local('verify_split_service')
    signer = load_local('sign_split_payload')
    stage = load_local('stage_split_payload')
    signed = gate.verify_bundle(source, 'service', source_receipt, source_receipt_sha256, signer, stage)
    gate.verify_historical_compile_receipt(source_compile_receipt, source_compile_sha256, signed)
    source_info = plistlib.loads((source / 'Contents/Info.plist').read_bytes())
    if (source_receipt_sha256 != gate.WRAPPER_SOURCE_RECEIPT_SHA256 or
            source_info.get('CFBundleVersion') != HELPER_BINARY_BUILD or
            'CFBundleIconFile' in source_info or (source / ICON).exists() or
            signed['reused_signed_core_sha256'] != gate.WRAPPER_CORE_SHA256):
        raise ValueError('Wrapper derivation requires the exact released iconless 1402 service')
    source_entries = inventory(source)
    icon = icon_bytes(gui / ICON)
    new_destination(destination, [source, gui])
    shutil.copytree(source, destination, symlinks=True)
    signature = destination / 'Contents/_CodeSignature'
    if signature.exists():
        shutil.rmtree(signature)
    target = destination / ICON
    target.parent.mkdir(mode=0o755)
    target.parent.chmod(0o755)
    target.write_bytes(icon)
    target.chmod(0o644)
    info = dict(source_info, CFBundleIconFile='AppIcon.icns', CFBundleVersion=SERVICE_WRAPPER_BUILD)
    (destination / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    check_layout(destination, 'service')
    if inventory(source) != source_entries or icon_bytes(gui / ICON) != icon:
        raise ValueError('Wrapper derivation inputs changed')
    return {
        'schema': 'flash-service-wrapper-derivation-v1', 'compiled': False,
        'helper_binary_build': HELPER_BINARY_BUILD, 'service_wrapper_build': SERVICE_WRAPPER_BUILD,
        'source': str(source.resolve(strict=True)), 'app': str(destination.resolve(strict=True)),
        'gui': str(gui.resolve(strict=True)), 'source_receipt': str(source_receipt),
        'source_receipt_sha256': source_receipt_sha256,
        'source_compile_receipt': str(source_compile_receipt),
        'source_compile_receipt_sha256': source_compile_sha256,
        'source_entries': source_entries, 'unsigned_entries': inventory(destination),
        'metadata_delta': {
            'CFBundleIconFile': {'before': None, 'after': 'AppIcon.icns'},
            'CFBundleVersion': {'before': HELPER_BINARY_BUILD, 'after': SERVICE_WRAPPER_BUILD}},
        'gui_icon_sha256': hashlib.sha256(icon).hexdigest(),
        'preserved_code_sha256': {relative: source_entries[relative]['sha256']
                                  for relative in (CORE, HELPER, MAINTENANCE, 'Contents/MacOS/Flash')},
    }


def verify_copy(original, copied, kind):
    if check_layout(original, kind) != check_layout(copied, kind):
        raise ValueError('Copied payload differs from exact input')


def verify_split_gui(app):
    entries = check_layout(app, 'gui')
    verifier = load_local('stage_managed_payload')
    verifier.FIXED_EXECUTABLES = ()
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


def finalize_core_copy(gui, service, *, released_core, core_sha256):
    check_layout(gui, 'gui')
    check_layout(service, 'service')
    compatible_pair(gui, service)
    if (service / CORE).read_bytes() != released_core_bytes(released_core, core_sha256):
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
    service.add_argument('--released-core', required=True, type=Path)
    service.add_argument('--core-sha256', required=True)
    service.add_argument('--core-version', required=True)
    service.add_argument('--core-revision', required=True)
    service.add_argument('--service-version', help='Use GUI only as a metadata/icon source; requires --service-build')
    service.add_argument('--service-build', help='Explicit service build, not the source GUI build')
    for name in ('stub', 'helper', 'maintenance', 'output'):
        service.add_argument('--' + name, required=True, type=Path)
    refresh = commands.add_parser('finalize-core-copy', allow_abbrev=False)
    refresh.add_argument('--released-core', required=True, type=Path)
    refresh.add_argument('--core-sha256', required=True)
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
                          args.core_version, args.core_revision, released_core=args.released_core, core_sha256=args.core_sha256,
                          service_version=args.service_version, service_build=args.service_build)
        elif args.command == 'finalize-core-copy':
            finalize_core_copy(args.gui, args.service, released_core=args.released_core, core_sha256=args.core_sha256)
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
