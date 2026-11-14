#!/usr/bin/python3
"""Split GUI-only qualification; --run-approved requires a NEW human approval.

Verification is static. No service/helper execution or installer acceptance is
implied. Keep the exact inputs frozen against concurrent same-UID writers.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import stat
import subprocess
import sys
import tempfile
import types

ROOT = Path('/Users/layoute/SideWork/FlClash/.airbuild/worktree/exit-cleanup')
PACKAGING = ROOT / 'macos/packaging'
GUI_APP = ROOT / '.airbuild/artifacts/split-2026111303-retry01/gui/Flash.app'
EVIDENCE_ROOT = ROOT / '.airbuild/evidence/split-native-load-qualification'
SCHEMA = 'flash-split-native-loads-v1'
STATE_SCHEMA = 'flash-split-frozen-state-v1'
NATIVE_SHA256 = '053311e347049f0ee4ba7745b7120817617600e27fc0014bf2f8bf389377b1bc'
CONSTRAINT_SHA256 = 'b1a402989ca8fd4375b081c68df5d974cf5be635389f399ff9f4ba17e7b2d7de'
DRIVER_SHA256 = '32c94cae90ce997482611ab074eade2cef7d3aed8d0446ed51480ff68cb423e3'
BUILD_ROOT = ROOT / '.airbuild/buildcandidate/split-2026111303'
BUILD_METADATA = BUILD_ROOT / 'continuation-04/build-metadata.json'
BUILD_METADATA_SHA256 = '0327f163c9707bcfe43c6feee6b657a572535c05d4b94fa4da2b701a4bcd4fd9'
FRAMEWORKS = ('App', 'FlutterMacOS', 'objective_c', 'rust_api', 'sqlite3')
PRESERVED_CAPTURE_MODES = {
    'continuation-01/FlashFlutterEngine-object-disassembly.txt': 0o660,
    'continuation-01/FlashFlutterEngine-object-objc.txt': 0o660,
    'continuation-01/commands.jsonl': 0o660,
    'continuation-01/continuation.started': 0o660,
    'continuation-01/core-buildinfo.txt': 0o660,
    'continuation-01/effective-xcode-settings.json': 0o660,
    'continuation-01/effective-xcode-settings.stderr.txt': 0o660,
    'continuation-01/failure-traceback.txt': 0o660,
    'continuation-01/setup-hook.log': 0o660,
    'continuation-01/stage-gui.log': 0o660,
    'continuation-01/stage-mode-failure-inventory.json': 0o660,
    'continuation-01/xcode-Logs/Build/LogStoreManifest.plist': 0o660,
    'continuation-01/xcode-Logs/Package/LogStoreManifest.plist': 0o660,
    'continuation-02/continuation.started': 0o660,
    'continuation-02/failure-traceback.txt': 0o660,
    'continuation-02/static-audit-commands.jsonl': 0o660,
    'prepared-checks.json': 0o660,
}

PRESERVED_LOG_ALIAS = 'continuation-01/flutter-build.log'
PRESERVED_CAPTURE_DIRECTORIES = frozenset({
    'continuation-01', 'continuation-01/xcode-Logs',
    'continuation-01/xcode-Logs/Build', 'continuation-01/xcode-Logs/Package',
    'continuation-02',
})


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or
                info.st_uid != os.getuid() or info.st_mode & 0o7022):
            raise ValueError('Unsafe pinned source file')
        return stream.read()


def pinned_module(name, expected):
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('Source pin requires parent review: ' + name)
    path = PACKAGING / name
    source = read_regular(path)
    if digest(source) != expected:
        raise ValueError('Pinned source changed: ' + name)
    module = types.ModuleType('_split_qualification_' + name.replace('.', '_'))
    module.__file__ = str(path)
    exec(compile(source, str(path), 'exec'), module.__dict__)
    return module


def native():
    return pinned_module('qualify_native_loads.py', NATIVE_SHA256)


def driver():
    return pinned_module('sign_split_payload.py', DRIVER_SHA256)


def make_scratch(fixed, legacy):
    root = legacy.SCRATCH_ROOT
    if not root.exists():
        root.mkdir(mode=0o700)
    legacy.canonical(str(root))
    fixed.check_directory(root)
    return tempfile.TemporaryDirectory(prefix='session-', dir=root)


def validate_metadata(metadata, info, fixed):
    defines = metadata.get('defines', {})
    if (metadata.get('schema') != 'flash-split-build-v1' or
            metadata.get('build_configuration') != 'Release' or
            metadata.get('version') != '0.9.7' or metadata.get('build_number') != '2026111303' or
            info.get('CFBundleShortVersionString') != '0.9.7' or
            info.get('CFBundleVersion') != '2026111303' or
            metadata.get('startup_hardened') is not True or
            metadata.get('certificate_sha1') != fixed.CERTIFICATE_SHA1 or
            metadata.get('apple_team') != '' or
            any(metadata.get(key) is not False for key in
                ('runtime_acceptance', 'actualGUIloads', 'packaging_accepted')) or
            defines.get('APP_ENV') != 'stable' or defines.get('MACOS_MANAGED_HELPER') is not True or
            type(defines.get('FC_MANAGED_CANDIDATE_ENABLED')) is not int or
            defines.get('FC_MANAGED_CANDIDATE_ENABLED') != 1 or
            defines.get('FC_PINNED_CERTIFICATE_SHA1') != fixed.CERTIFICATE_SHA1):
        raise ValueError('Missing fresh Release split build/startup metadata')
    values = [base64.b64decode(value, validate=True).decode('utf-8')
              for value in info.get('FlashDartDefines', '').split(',') if value]
    managed = [value for value in values if value.startswith('MACOS_MANAGED_HELPER=')]
    if managed != ['MACOS_MANAGED_HELPER=true']:
        raise ValueError('Sealed Dart metadata must enable the managed build')


def check_capture_ancestors(path, fixed):
    # Data-only compatibility, never executable trust. Outside .airbuild, depend
    # on the parent guard's reviewed deny-only ACL policy and frozen ancestors.
    for node in path.parents:
        info = node.lstat()
        preserved = (node.is_relative_to(BUILD_ROOT) and
                     str(node.relative_to(BUILD_ROOT)) in PRESERVED_CAPTURE_DIRECTORIES)
        mode_ok = (info.st_uid == 501 and stat.S_IMODE(info.st_mode) == 0o770
                   if preserved else not info.st_mode & 0o7022)
        if (not stat.S_ISDIR(info.st_mode) or info.st_uid not in {0, os.getuid()} or
                not mode_ok):
            raise ValueError('Unsafe preserved capture ancestor: ' + str(node))
        if node == ROOT / '.airbuild' or node.is_relative_to(ROOT / '.airbuild'):
            fixed.require_no_acl(node)


def read_build_evidence(path, expected, fixed):
    relative = str(path.relative_to(BUILD_ROOT))
    if relative == PRESERVED_LOG_ALIAS:
        target = BUILD_ROOT / 'flutter-build.log'
        before = path.lstat()
        if (path.parent.resolve(strict=True) != path.parent or
                not stat.S_ISLNK(before.st_mode) or before.st_uid != 501 or
                before.st_gid != 20 or before.st_nlink != 1 or
                stat.S_IMODE(before.st_mode) != 0o770 or os.readlink(path) != str(target) or
                target.resolve(strict=True) != target):
            raise ValueError('Unexpected preserved log alias')
        check_capture_ancestors(path, fixed)
        fixed.require_no_acl(path)
        fixed.require_no_acl(target)
        data = fixed.read_regular(target)
        fixed.require_no_acl(path)
        fields = ('st_dev', 'st_ino', 'st_uid', 'st_gid', 'st_mode', 'st_nlink',
                  'st_size', 'st_mtime_ns', 'st_ctime_ns', 'st_flags')
        after = path.lstat()
        if (any(getattr(before, key, None) != getattr(after, key, None) for key in fields) or
                os.readlink(path) != str(target) or path.resolve(strict=True) != target):
            raise ValueError('Preserved log alias changed while reading')
    elif relative not in PRESERVED_CAPTURE_MODES:
        data = fixed.read_regular(path)
    else:
        if path.resolve(strict=True) != path:
            raise ValueError('Preserved capture has a noncanonical path')
        check_capture_ancestors(path, fixed)
        fixed.require_no_acl(path)
        fields = ('st_dev', 'st_ino', 'st_uid', 'st_gid', 'st_mode', 'st_nlink',
                  'st_size', 'st_mtime_ns', 'st_ctime_ns', 'st_flags')
        identity = lambda info: tuple(getattr(info, key, None) for key in fields)
        before = path.lstat()
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, 'rb') as stream:
            opened = os.fstat(stream.fileno())
            if (identity(before) != identity(opened) or not stat.S_ISREG(opened.st_mode) or
                    opened.st_uid != 501 or opened.st_nlink != 1 or
                    stat.S_IMODE(opened.st_mode) != PRESERVED_CAPTURE_MODES[relative] or
                    opened.st_mode & 0o7002):
                raise ValueError('Unsafe preserved capture identity/mode')
            data = stream.read()
            if identity(opened) != identity(os.fstat(stream.fileno())):
                raise ValueError('Preserved capture changed while reading')
        fixed.require_no_acl(path)
        if identity(before) != identity(path.lstat()) or path.resolve(strict=True) != path:
            raise ValueError('Preserved capture path identity changed')
    if digest(data) != expected:
        raise ValueError('Frozen build evidence changed: ' + relative)
    return data


def build_provenance(metadata_path, metadata, metadata_hash, report, targets, fixed):
    if metadata_path != BUILD_METADATA or metadata_hash != BUILD_METADATA_SHA256:
        raise ValueError('Expected the unchanged final continuation-04 build metadata')
    if (metadata.get('architectures') != ['arm64'] or metadata.get('macho_count') != 6 or
            any(metadata.get(key) is not True for key in (
                'flutter_release_compile_succeeded', 'fresh_core_built', 'fresh_gui_aot_built',
                'static_stage_audit_passed', 'original_failures_preserved')) or
            any(metadata.get(key) is not False for key in (
                'signing_performed', 'production_components_executed', 'rebuild_performed'))):
        raise ValueError('Fresh unsigned build provenance is incomplete')
    hashes, documents = {}, {}
    json_documents = {'input-freeze.json'} | {
        f'continuation-{index:02d}/continuation-provenance.json' for index in range(1, 5)
    } | {'continuation-04/' + name for name in (
        'stage-inventory-after-audit.json', 'candidate-file-manifest.json', 'macho-inventory.json')}
    for base, group in ((BUILD_ROOT, 'compile_evidence'), (metadata_path.parent, 'stage_evidence')):
        for relative, expected in metadata[group].items():
            path = base / relative
            if (Path(relative).is_absolute() or '..' in Path(relative).parts or
                    (path.resolve(strict=True) != path and path != BUILD_ROOT / PRESERVED_LOG_ALIAS) or
                    not re.fullmatch(r'[0-9a-f]{64}', expected)):
                raise ValueError('Noncanonical build evidence reference')
            fixed.require_no_acl(path)
            data = read_build_evidence(path, expected, fixed)
            key = str(path.relative_to(BUILD_ROOT))
            hashes[key] = expected
            if key in json_documents:
                documents[key] = json.loads(data)
    freeze_hash = hashes['input-freeze.json']
    freeze = documents['input-freeze.json']
    if (freeze_hash != metadata['source_freeze_sha256'] or
            freeze['source_head'] != metadata['source_head'] or freeze['sdk'] != metadata['sdk']):
        raise ValueError('Original source/SDK freeze differs from final build provenance')
    continuations = metadata['evidence_continuations']
    if len(continuations) != 4:
        raise ValueError('All four preserved build continuations are required')
    for index, continuation in enumerate(continuations, 1):
        relative = f'continuation-{index:02d}/continuation-provenance.json'
        if (continuation['path'] != str(BUILD_ROOT / relative) or
                continuation['sha256'] != hashes[relative]):
            raise ValueError('Continuation provenance binding mismatch')
        document = documents[relative]
        if document.get('freeze_sha256', document.get('source_freeze_sha256')) != freeze_hash:
            raise ValueError('Continuation does not preserve the original source freeze')
    prefix = 'continuation-04/'
    if any(hashes[prefix + name] != hashes['continuation-03/' + name] for name in (
            'stage-inventory-after-audit.json', 'candidate-file-manifest.json', 'macho-inventory.json')):
        raise ValueError('Pristine retry differs from the original frozen unsigned GUI')
    inventory = documents[prefix + 'stage-inventory-after-audit.json']
    manifest = documents[prefix + 'candidate-file-manifest.json']
    macho = documents[prefix + 'macho-inventory.json']
    binaries = {target['binary'] for target in targets}
    if (len(macho) != 6 or {item['path'] for item in macho} != binaries or
            any(item['architectures'] != ['arm64'] or
                item['sha256'] != inventory[item['path']]['sha256'] for item in macho)):
        raise ValueError('Frozen unsigned Mach-O inventory differs from the six GUI targets')
    before, projected = {}, {}
    if inventory.get('.') != {'directory': True, 'mode': 0o755}:
        raise ValueError('Unexpected frozen unsigned bundle root')
    for relative, item in inventory.items():
        if relative == '.':
            continue
        entry = {'mode': oct(item['mode'])}
        staged = {'mode': item['mode']}
        if item.get('directory') is True:
            entry['kind'] = staged['kind'] = 'directory'
        elif 'symlink' in item:
            entry.update(kind='symlink', target=item['symlink'])
            staged.update(kind='link', target=item['symlink'])
        else:
            entry.update(kind='file', sha256=item['sha256'], size=item['bytes'], macho=relative in binaries)
            staged.update(kind='file', sha256=item['sha256'])
        before[relative], projected[relative] = entry, staged
    if projected != manifest or report.get('before') != {
            'tree_sha256': fixed.tree_digest(before), 'entries': before}:
        raise ValueError('Signing did not start from the exact frozen fresh unsigned GUI')
    fixed.check_signing_delta(before, report['after']['entries'], targets)
    return {'metadata_sha256': metadata_hash, 'source_freeze_sha256': freeze_hash,
            'evidence_sha256': hashes, 'unsigned_tree_sha256': fixed.tree_digest(before)}


def frozen_state(app, metadata_path, signer, scratch):
    legacy = native()
    fixed, constraint = signer.dependencies()
    if signer.CONSTRAINT_SHA256 != CONSTRAINT_SHA256:
        raise ValueError('Unreviewed constraint inspector')
    app = fixed.staging_path(str(app))
    if (app != GUI_APP or (app / 'Contents/Library').exists() or
            (app / 'Contents/MacOS/FlClashCore').exists() or (app / 'Contents/MacOS/FlClashCore').is_symlink()):
        raise ValueError('Only the new GUI-only split stage may be qualified')
    metadata_path = legacy.canonical(str(metadata_path))
    report_path = app.parent / 'Flash.gui-signing-static.json'
    report, report_hash = legacy.protected_json(report_path, fixed)
    metadata, metadata_hash = legacy.protected_json(metadata_path, fixed)
    source_names = ('sign_split_payload.py', 'sign_fixed_payload.py', 'stage_managed_payload.py',
                    'library_constraint.py', 'FixedGUI.entitlements', 'stage_split_payload.py', 'qualify_native_loads.py',
                    'qualify_split_loads.py')
    sources = {name: digest(fixed.read_regular(PACKAGING / name)) for name in source_names}
    expected_sources = {'sign_split_payload.py': DRIVER_SHA256,
                        'sign_fixed_payload.py': signer.FIXED_SIGNER_SHA256,
                        'stage_managed_payload.py': fixed.VERIFIER_SHA256,
                        'stage_split_payload.py': signer.STAGING_SHA256,
                        'library_constraint.py': CONSTRAINT_SHA256,
                        'qualify_native_loads.py': NATIVE_SHA256}
    if any(sources[name] != expected for name, expected in expected_sources.items()):
        raise ValueError('Qualification source changed')
    pins = {'certificate_sha1': fixed.CERTIFICATE_SHA1,
            'certificate_sha256': fixed.CERTIFICATE_SHA256}
    expected_inputs = {'driver_sha256': sources['sign_split_payload.py'],
                       'fixed_signer_sha256': sources['sign_fixed_payload.py'],
                       'constraint_sha256': sources['library_constraint.py'],
                       'verifier_sha256': sources['stage_managed_payload.py'],
                       'staging_sha256': sources['stage_split_payload.py'],
                       'gui_entitlements_sha256': sources['FixedGUI.entitlements']}
    verifier = fixed.trusted_verifier()
    entries = fixed.inventory(app, verifier)
    tree = fixed.tree_digest(entries)
    if (type(report.get('schema')) is not int or report['schema'] != 1 or
            report.get('phase') != 'gui' or report.get('app') != str(app) or
            report.get('static_verification') is not True or
            any(report.get(key) is not False for key in
                ('actualGUIloads', 'native_qualification', 'packaging_accepted', 'runtime_gate_changed')) or
            report.get('pins') != pins or report.get('inputs') != expected_inputs or
            report.get('after') != {'tree_sha256': tree, 'entries': entries}):
        raise ValueError('Split signing receipt does not match the exact GUI artifact')
    review = signer.native_constraint_review(fixed)
    if report.get('native_constraint_review') != review:
        raise ValueError('Signing receipt native constraint review differs from current host/evidence')
    info = plistlib.loads(fixed.read_regular(app / 'Contents/Info.plist'))
    validate_metadata(metadata, info, fixed)
    stage = signer.frozen_module('stage_split_payload.py', signer.STAGING_SHA256)
    compatibility = stage.validate_compatibility(info.get('FlashHelperCompatibility'), 'gui')
    if (report.get('compatibility') != compatibility or
            report.get('accepted_service_core_sha256') not in compatibility['AcceptedCoreSHA256'] or
            'reused_signed_core_sha256' in report):
        raise ValueError('GUI service Core acceptance receipt differs from sealed metadata')
    targets = signer.signing_targets(app, entries, 'gui', fixed)
    expected_binaries = {'Contents/MacOS/Flash'} | {
        f'Contents/Frameworks/{name}.framework/Versions/A/{name}' for name in FRAMEWORKS}
    if len(targets) != 6 or {target['binary'] for target in targets} != expected_binaries:
        raise ValueError('Expected exactly five frameworks and GUI; no loose Core or helper')
    provenance = build_provenance(metadata_path, metadata, metadata_hash, report, targets, fixed)
    signer.audit(app, 'gui', fixed, verifier, targets)
    hashes = []
    for index, target in enumerate(targets):
        if target['architectures'] != ['arm64']:
            raise ValueError('Only the reviewed native arm64 split is supported')
        work = scratch / str(index)
        work.mkdir(mode=0o700)
        target['verified_slices'] = fixed.verify_target(app, target, work)
        target['cdhash'] = constraint.cdhash(fixed.read_regular(app / target['binary'])).hex()
        if target['role'] == 'framework':
            hashes.append(bytes.fromhex(target['cdhash']))
    binding = constraint.verify_library_constraint(
        fixed.read_regular(app / 'Contents/MacOS/Flash'), hashes)
    if targets != report.get('targets') or binding != report.get('library_constraint'):
        raise ValueError('Split target signatures or actual DER constraint changed')
    fixed.run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict',
                    '--all-architectures', str(app)])
    if fixed.inventory(app, verifier) != entries:
        raise ValueError('GUI changed during static inspection')
    for path, expected in ((report_path, report_hash), (metadata_path, metadata_hash)):
        if legacy.protected_json(path, fixed)[1] != expected:
            raise ValueError('Receipt or metadata changed during static inspection')
    host = legacy.host()
    if host['architecture'] != 'arm64':
        raise ValueError('Native arm64 host required')
    return {'schema': STATE_SCHEMA, 'scope': 'gui-only', 'app': str(app),
            'static_report': str(report_path), 'static_report_sha256': report_hash,
            'build_metadata': str(metadata_path), 'build_metadata_sha256': metadata_hash,
            'source_sha256': sources, 'inventory': entries, 'tree_sha256': tree,
            'targets': targets, 'library_constraint': binding, 'pins': pins,
            'build': metadata, 'build_provenance': provenance,
            'native_constraint_review': review, 'host': host}


def validate_evidence(evidence, current, app):
    if (evidence.get('schema') != SCHEMA or evidence.get('scope') != 'gui-only' or
            evidence.get('qualified') is not True or evidence.get('actualGUIloads') is not True or
            evidence.get('packaging_accepted') is not False or
            evidence.get('before') != current or evidence.get('after') != current or
            current.get('schema') != STATE_SCHEMA):
        raise ValueError('Missing, legacy, failed, or stale split GUI qualification')
    protocol = native().validate_execution(evidence.get('execution', {}), app,
                                           current['host']['architecture'])
    if protocol != evidence.get('protocol'):
        raise ValueError('Stored protocol differs from challenge-bound child output')


def evidence_location(path, legacy, fixed):
    path = Path(path)
    if (not path.is_absolute() or path.parent != EVIDENCE_ROOT or
            path.suffix != '.json' or '..' in path.parts):
        raise ValueError('Use a fresh JSON file in the split evidence directory')
    legacy.canonical(str(EVIDENCE_ROOT))
    fixed.check_directory(EVIDENCE_ROOT)
    return path


def run_approved(app, metadata, evidence_path):
    signer, legacy = driver(), native()
    fixed, _ = signer.dependencies()
    evidence_path = evidence_location(evidence_path, legacy, fixed)
    with make_scratch(fixed, legacy) as temporary:
        scratch = Path(temporary)
        before_dir = scratch / 'before'
        before_dir.mkdir(mode=0o700)
        before = frozen_state(app, metadata, signer, before_dir)
        evidence = {'schema': SCHEMA, 'scope': 'gui-only', 'qualified': False,
                    'actualGUIloads': False, 'packaging_accepted': False,
                    'before': before, 'limitations': legacy.CAVEATS}
        descriptor = os.open(evidence_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            legacy.save(stream, evidence)
            try:
                execution = legacy.supervise(app, scratch, secrets.token_urlsafe(24),
                                             before['host']['architecture'])
                evidence['execution'] = execution
                after_dir = scratch / 'after'
                after_dir.mkdir(mode=0o700)
                evidence['after'] = frozen_state(app, metadata, signer, after_dir)
                evidence['protocol'] = legacy.validate_execution(execution, app, before['host']['architecture'])
                if evidence['after'] != before:
                    raise ValueError('Frozen split inputs changed during the diagnostic')
                evidence['qualified'] = True
                evidence['actualGUIloads'] = True
            except BaseException as error:
                evidence['failure'] = type(error).__name__
                legacy.save(stream, evidence)
                raise
            legacy.save(stream, evidence)
    return evidence


def verify(app, metadata, evidence):
    signer, legacy = driver(), native()
    fixed, _ = signer.dependencies()
    app = legacy.canonical(str(app))
    metadata = legacy.canonical(str(metadata))
    path = legacy.canonical(str(evidence_location(evidence, legacy, fixed)))
    report, report_hash = legacy.protected_json(path, fixed)
    with make_scratch(fixed, legacy) as temporary:
        current = frozen_state(app, metadata, signer, Path(temporary))
        validate_evidence(report, current, app)
        if legacy.protected_json(path, fixed)[1] != report_hash:
            raise ValueError('Qualification evidence changed during verification')
    return report


def main():
    if not (sys.flags.isolated and sys.flags.no_site and sys.dont_write_bytecode) or os.getuid() == 0:
        print('Use non-root /usr/bin/python3 -I -S -B.', file=sys.stderr)
        return 1
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--run-approved', action='store_true')
    mode.add_argument('--verify-evidence', action='store_true')
    parser.add_argument('--app', required=True)
    parser.add_argument('--build-metadata', required=True)
    parser.add_argument('--evidence', required=True)
    args = parser.parse_args()
    try:
        legacy = native()
        app = legacy.canonical(args.app)
        metadata = legacy.canonical(args.build_metadata)
        path = Path(args.evidence)
        if str(path) != args.evidence:
            raise ValueError('Noncanonical evidence path')
        if args.run_approved:
            run_approved(app, metadata, path)
        else:
            verify(app, metadata, path)
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('Split qualification failed closed: ' + type(error).__name__, file=sys.stderr)
        return 1
    print('Exact split GUI evidence verified; service/helper/installer acceptance remains unverified.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
