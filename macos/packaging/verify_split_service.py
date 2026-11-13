#!/usr/bin/python3
"""Static downstream gate. Never execute GUI, helper, Core, installers, or signing."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import tempfile
import types

ROOT = Path('/Users/layoute/SideWork/FlClash/.airbuild/worktree/exit-cleanup')
PACKAGING = ROOT / 'macos/packaging'
BASE = ROOT / '.airbuild/artifacts/split-2026111303-retry01'
GUI = BASE / 'gui/Flash.app'
SERVICE = BASE / 'service/Flash.app'
WORK = BASE / 'service-compile'
BUILD = ROOT / '.airbuild/buildcandidate/split-2026111303'
METADATA = BUILD / 'continuation-04/build-metadata.json'
FREEZE = BUILD / 'input-freeze.json'
DELTA = BUILD / 'service-continuation-01/tooling-delta-02.json'
PRIOR_DELTA = BUILD / 'signing-continuation-02/tooling-delta.json'
EVIDENCE = ROOT / '.airbuild/evidence/split-native-load-qualification/split-2026111303-retry01-user2903.json'
SIGNER_SHA256 = '9023fbb047381d8b5a46802e6718eb449b49701557beb6b4e177da15e25f9a59'
QUALIFIER_SHA256 = '70f06cc6caa2deecdcc62d8f01b52c2e07526a01daa4b9207bab0ff55295c8a1'
METADATA_SHA256 = '0327f163c9707bcfe43c6feee6b657a572535c05d4b94fa4da2b701a4bcd4fd9'
FREEZE_SHA256 = 'd756cb259a694520d7571dcda37866bc3f6fe9d54df520565f131701a8c66a87'
PRIOR_DELTA_SHA256 = '1ba61f11ca530e276389b09177c2c9e92e316f2d5c8e143aa27cba4b5f32b4bf'
PRIOR_APPROVAL_SHA256 = '932020557f40f1f3cd925689301e8be257eaede4faac7c9e9517f3cdb37c35ad'
EVIDENCE_SHA256 = '8bf8dda07892ea638ec255910aced1247a6c0c8f97c7f81ee0c8586814aafb65'
GUI_REPORT_SHA256 = 'd4ea487370bbc7dab5e3560d3ba6c575acf52e70fae8494c64c8b79cb4856497'
GUI_CDHASH = '6c18f204b4be7c147a825d8e27e7485c6e1f4721'
GUI_TREE = '9dee9f1847e81e773dc0130ee0ad43899255d26c9a85933f03c4512b11c9166d'
COMPILER_DRIVER = '.airbuild/tools/split-service-compile-2026111303.py'
COMPILER_TEST = '.airbuild/tools/test_split_service_compile_2026111303.py'
ALLOWED_TOOLING = frozenset((
    'macos/packaging/stage_split_payload.py', 'macos/packaging/build_split_packages.sh',
    'macos/packaging/Tests/test_split_payload.py', 'macos/packaging/verify_split_service.py',
    'macos/packaging/Tests/test_split_service_verification.py', COMPILER_DRIVER, COMPILER_TEST,
))
PREPARED_BEFORE = {
    COMPILER_DRIVER: '682f48551f7f80a9e534162c954a695ef86e58e7f84b48b11aff8afffee405c1',
    COMPILER_TEST: 'afbdcf1a67560a421d30cc1f7a4c2ea2710eeb27a5178b601aa59e545fbe160e',
}
SOURCES = {
    'helper': ('macos/Shared/HelperTrust.m', 'macos/PrivilegedHelper/Supervisor.m', 'macos/PrivilegedHelper/Spawn.c'),
    'maintenance': ('macos/Shared/HelperTrust.m', 'macos/PrivilegedHelper/Maintenance.m'),
    'stub': ('macos/PrivilegedHelper/ServiceStub.c',),
}
BINARIES = {'helper': 'Contents/Library/HelperTools/FlashHelper',
            'maintenance': 'Contents/Library/HelperTools/FlashMaintenance', 'stub': 'Contents/MacOS/Flash'}
CORE = 'Contents/MacOS/FlClashCore'
SANDBOX = ['/usr/bin/sandbox-exec', '-p', '(version 1) (allow default) (deny network*)']


def read(path):
    if path.resolve(strict=True) != path:
        raise ValueError('Noncanonical source/evidence path')
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('Expected single-link regular source/evidence')
        return stream.read()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def record(path):
    data = read(path)
    return {'sha256': digest(data), 'bytes': len(data), 'mode': stat.S_IMODE(path.stat().st_mode)}


def pinned_bytes(path, expected):
    if not re.fullmatch('[0-9a-f]{64}', expected or ''):
        raise ValueError('Explicit exact SHA256 pin required')
    data = read(path)
    if digest(data) != expected:
        raise ValueError('Pinned input changed: ' + str(path))
    return data


def pinned_json(path, expected):
    return json.loads(pinned_bytes(path, expected))


def module(name, expected):
    path = PACKAGING / (name + '.py')
    source = pinned_bytes(path, expected)
    loaded = types.ModuleType('_downstream_' + name)
    loaded.__file__ = str(path)
    exec(compile(source, str(path), 'exec'), loaded.__dict__)
    return loaded


def tooling_state(path, expected):
    if path != DELTA:
        raise ValueError('Only the append-only downstream tooling delta is permitted')
    delta = pinned_json(path, expected)
    frozen = pinned_json(FREEZE, FREEZE_SHA256)
    prior = pinned_json(PRIOR_DELTA, PRIOR_DELTA_SHA256)
    pinned_bytes(BUILD / 'signing-continuation-02/approved-pins.json', PRIOR_APPROVAL_SHA256)
    if (delta.get('schema') != 'flash-service-tooling-delta-v1' or
            delta.get('source_freeze_sha256') != FREEZE_SHA256 or
            delta.get('prior_gui_tooling_delta_sha256') != PRIOR_DELTA_SHA256 or
            set(delta.get('files', {})) != ALLOWED_TOOLING):
        raise ValueError('Unexpected downstream source delta')
    approved = dict(frozen['source_inputs'])
    for name, change in prior['state']['allowed_source_delta'].items():
        if change['before'] != frozen['source_inputs'].get(name) or record(ROOT / name) != change['after']:
            raise ValueError('Frozen GUI tooling delta changed')
        approved[name] = change['after']
    for name, change in delta['files'].items():
        if name in PREPARED_BEFORE:
            if (change.get('before') or {}).get('sha256') != PREPARED_BEFORE[name]:
                raise ValueError('Wrong prepared compiler baseline')
        elif change.get('before') != frozen['source_inputs'].get(name):
            raise ValueError('Downstream before state differs from original freeze')
        if record(ROOT / name) != change.get('after'):
            raise ValueError('Downstream tooling bytes changed')
        approved[name] = change['after']
    return delta, frozen, approved


def source_snapshot(approved):
    pending = {name for group in SOURCES.values() for name in group}
    pending |= {'macos/Shared/HelperIdentity.h', 'macos/PrivilegedHelper/com.layoute.flash.helper.plist',
                'macos/packaging/stage_managed_helper.sh', 'macos/packaging/stage_split_payload.py',
                'macos/packaging/sign_split_payload.py', 'macos/packaging/sign_fixed_payload.py',
                'macos/packaging/stage_managed_payload.py', 'macos/packaging/library_constraint.py',
                'macos/packaging/qualify_split_loads.py', 'macos/packaging/verify_split_service.py',
                'macos/packaging/FixedGUI.entitlements', 'macos/packaging/normalize_package_info.py',
                'macos/packaging/pin_component_policy.py'}
    pending |= {str(path.relative_to(ROOT)) for path in (PACKAGING / 'installer').glob('*/*')}
    result = {}
    while pending:
        name = pending.pop()
        if name in result:
            continue
        path = ROOT / name
        actual = record(path)
        if actual != approved.get(name):
            raise ValueError('Source differs from original freeze or bounded tooling delta: ' + name)
        result[name] = actual
        if path.suffix in ('.m', '.c', '.h'):
            for include in re.findall(r'^\s*#\s*(?:include|import)\s*"([^"\n]+)"', read(path).decode(), re.M):
                dependency = (path.parent / include).resolve(strict=True)
                if not dependency.is_relative_to(ROOT):
                    raise ValueError('Native include escapes frozen source root')
                pending.add(str(dependency.relative_to(ROOT)))
    return dict(sorted(result.items()))


def compile_argv(role, compiler, sdk, cdhash, output):
    if cdhash != GUI_CDHASH:
        raise ValueError('Only exact qualified GUI CDHash accepted')
    args = [str(compiler), '-arch', 'arm64', '-mmacosx-version-min=14.0', '-isysroot', str(sdk)]
    if role != 'stub':
        args += ['-fobjc-arc', '-fblocks', '-DFC_MANAGED_CANDIDATE_ENABLED=1',
                 '-DFC_SPLIT_GUI_CDHASH="' + cdhash + '"', '-Wno-deprecated-declarations',
                 '-framework', 'Foundation', '-framework', 'Security']
        if role == 'maintenance':
            args += ['-framework', 'ServiceManagement']
    return args + [str(ROOT / source) for source in SOURCES[role]] + ['-o', str(output)]


def verify_gui(gui, metadata, evidence):
    os.umask(0o077)
    if (gui, metadata, evidence) != (GUI, METADATA, EVIDENCE):
        raise ValueError('Only the exact qualified retry01 GUI inputs are permitted')
    pinned_bytes(metadata, METADATA_SHA256)
    pinned_bytes(evidence, EVIDENCE_SHA256)
    pinned_bytes(gui.parent / 'Flash.gui-signing-static.json', GUI_REPORT_SHA256)
    qualifier = module('qualify_split_loads', QUALIFIER_SHA256)
    result = qualifier.verify(gui, metadata, evidence)
    if (result['before']['tree_sha256'] != GUI_TREE or
            result['before']['library_constraint']['cdhash'] != GUI_CDHASH):
        raise ValueError('Qualified GUI tree/CDHash changed')
    pinned_bytes(evidence, EVIDENCE_SHA256)
    return result


def validate_compile_receipt(compiled, signed, delta, delta_hash, sources, fixed):
    if (compiled.get('schema') != 'flash-split-service-compile-v1' or compiled.get('completed') is not True or
            compiled.get('driver_sha256') != delta['files'][COMPILER_DRIVER]['after']['sha256'] or
            compiled.get('signer_sha256') != SIGNER_SHA256 or
            compiled.get('tooling_delta_sha256') != delta_hash or
            compiled.get('gui_report_sha256') != GUI_REPORT_SHA256 or
            compiled.get('gui_cdhash') != GUI_CDHASH or compiled.get('gui_signed_tree_sha256') != GUI_TREE or
            compiled.get('qualification_sha256') != EVIDENCE_SHA256 or
            compiled.get('build_metadata_sha256') != METADATA_SHA256 or
            compiled.get('source_freeze_sha256') != FREEZE_SHA256 or compiled.get('source_inputs') != sources or
            compiled.get('native_qualification') is not False or compiled.get('installation_accepted') is not False or
            compiled.get('staged_unsigned_entries') != signed['before']['entries']):
        raise ValueError('Service compiler provenance does not bind exact unsigned signing inputs')
    if set(compiled['outputs']) != set(BINARIES):
        raise ValueError('Unexpected compiler outputs')
    for role, binary in BINARIES.items():
        output = compiled['outputs'][role]
        path = WORK / role
        expected_argv = compile_argv(role, compiled['toolchain']['compiler'], compiled['toolchain']['sdk'], GUI_CDHASH, path)
        if (output['path'] != str(path) or output['clang_argv'] != expected_argv or
                {key: output[key] for key in ('sha256', 'bytes', 'mode')} != record(path) or
                output['sha256'] != signed['before']['entries'][binary]['sha256'] or
                not any(command.get('argv') == SANDBOX + expected_argv and command.get('returncode') == 0
                        for command in compiled['commands'])):
            raise ValueError('Compiler output/argv differs from service unsigned bytes')
    core_hash = digest(fixed.read_regular(GUI / CORE))
    if any(value != core_hash for value in (compiled['gui_signed_core_sha256'],
            signed['before']['entries'][CORE]['sha256'], signed['after']['entries'][CORE]['sha256'])):
        raise ValueError('Service Core differs from qualified signed GUI Core')


def verify(gui, service, evidence, metadata, compile_receipt, compile_sha256,
           signing_receipt, signing_sha256, tooling_delta, tooling_sha256):
    if service != SERVICE or compile_receipt != WORK / 'servicecompile-receipt.json' or signing_receipt != service.parent / 'Flash.service-signing-static.json':
        raise ValueError('Only fixed new service receipt paths are permitted')
    delta, _, approved = tooling_state(tooling_delta, tooling_sha256)
    sources = source_snapshot(approved)
    verify_gui(gui, metadata, evidence)
    signer = module('sign_split_payload', SIGNER_SHA256)
    fixed, constraint = signer.dependencies()
    verifier = fixed.trusted_verifier()
    stage = module('stage_split_payload', delta['files']['macos/packaging/stage_split_payload.py']['after']['sha256'])
    stage.check_layout(service, 'service')
    info = plistlib.loads(fixed.read_regular(service / 'Contents/Info.plist'))
    if info.get('LSMinimumSystemVersion') != '14.0':
        raise ValueError('Service requires the macOS 14 floor')
    signed = pinned_json(signing_receipt, signing_sha256)
    compiled = pinned_json(compile_receipt, compile_sha256)
    entries = fixed.inventory(service, verifier)
    gui_report = pinned_json(gui.parent / 'Flash.gui-signing-static.json', GUI_REPORT_SHA256)
    if (signed.get('schema') != 1 or signed.get('phase') != 'service' or signed.get('app') != str(service) or
            signed.get('static_verification') is not True or signed.get('inputs') != gui_report['inputs'] or
            signed.get('pins') != gui_report['pins'] or signed.get('gui_receipt_sha256') != GUI_REPORT_SHA256 or
            signed.get('gui_cdhash') != GUI_CDHASH or
            any(signed.get(key) is not False for key in ('actualGUIloads', 'native_qualification', 'packaging_accepted', 'runtime_gate_changed')) or
            signed.get('after') != {'tree_sha256': fixed.tree_digest(entries), 'entries': entries} or
            signed.get('native_constraint_review') != signer.native_constraint_review(fixed) or
            signed['before']['tree_sha256'] != fixed.tree_digest(signed['before']['entries'])):
        raise ValueError('Service signing receipt differs from exact current artifact/policy')
    validate_compile_receipt(compiled, signed, delta, tooling_sha256, sources, fixed)
    targets = signer.signing_targets(service, entries, 'service', fixed)
    if len(targets) != 4:
        raise ValueError('Expected four service signature targets')
    signer.audit(service, 'service', fixed, verifier, targets)
    with tempfile.TemporaryDirectory(prefix='split-service-static-') as temporary:
        for index, target in enumerate(targets):
            work = Path(temporary) / str(index)
            work.mkdir(mode=0o700)
            constraint.inspect_slice(fixed.read_regular(service / target['binary']))
            target['verified_slices'] = fixed.verify_target(service, target, work)
            target['cdhash'] = constraint.cdhash(fixed.read_regular(service / target['binary'])).hex()
    if targets != signed['targets']:
        raise ValueError('Service target signatures differ from receipt')
    fixed.check_signing_delta(signed['before']['entries'], entries, [target for target in targets if target['role'] != 'core'])
    fixed.run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--all-architectures', str(service)])
    if fixed.read_regular(service / CORE) != fixed.read_regular(gui / CORE) or fixed.inventory(service, verifier) != entries:
        raise ValueError('Service or signed Core changed during static verification')
    pinned_bytes(signing_receipt, signing_sha256)
    pinned_bytes(compile_receipt, compile_sha256)
    tooling_state(tooling_delta, tooling_sha256)
    if source_snapshot(approved) != sources:
        raise ValueError('Service compile inputs changed during static verification')
    verify_gui(gui, metadata, evidence)
    return {'gui_native_qualified': True, 'service_static_verified': True,
            'service_runtime_accepted': False, 'installer_accepted': False}
