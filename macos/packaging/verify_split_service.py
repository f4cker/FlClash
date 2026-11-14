#!/usr/bin/python3
"""Static artifact/compatibility verification; never run delivered code or sign."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PACKAGING = ROOT / 'macos/packaging'
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


def pinned_json(path, expected):
    if not re.fullmatch('[0-9a-f]{64}', expected or ''):
        raise ValueError('Explicit exact SHA256 pin required')
    data = read(path)
    if digest(data) != expected:
        raise ValueError('Pinned receipt changed: ' + str(path))
    return json.loads(data)


def module(name):
    path = PACKAGING / (name + '.py')
    spec = importlib.util.spec_from_file_location('_release_' + name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def compile_argv(role, compiler, sdk, output):
    args = [str(compiler), '-arch', 'arm64', '-mmacosx-version-min=14.0', '-isysroot', str(sdk)]
    if role != 'stub':
        args += ['-fobjc-arc', '-fblocks', '-DFC_MANAGED_CANDIDATE_ENABLED=1',
                 '-Wno-deprecated-declarations', '-framework', 'Foundation', '-framework', 'Security']
        if role == 'maintenance':
            args += ['-framework', 'ServiceManagement']
    return args + [str(ROOT / source) for source in SOURCES[role]] + ['-o', str(output)]


def verify_bundle(app, phase, receipt_path, receipt_sha256, signer, stage):
    receipt = pinned_json(receipt_path, receipt_sha256)
    fixed, constraint = signer.dependencies()
    verifier = fixed.trusted_verifier()
    stage.check_layout(app, phase)
    compatibility = stage.read_compatibility(app, phase)
    entries = fixed.inventory(app, verifier)
    if (receipt.get('schema') != 1 or receipt.get('phase') != phase or receipt.get('app') != str(app) or
            receipt.get('static_verification') is not True or receipt.get('pins') != {
                'certificate_sha1': signer.CERTIFICATE_SHA1, 'certificate_sha256': signer.CERTIFICATE_SHA256} or
            receipt.get('compatibility') != compatibility or
            receipt.get('after') != {'tree_sha256': fixed.tree_digest(entries), 'entries': entries} or
            receipt.get('reused_signed_core_sha256') != digest(read(app / CORE))):
        raise ValueError('Signing receipt differs from exact artifact/compatibility')
    before = receipt['before']['entries']
    if receipt['before']['tree_sha256'] != fixed.tree_digest(before):
        raise ValueError('Unsigned artifact inventory changed')
    targets = signer.signing_targets(app, entries, phase, fixed)
    signer.audit(app, phase, fixed, verifier, targets)
    hashes = []
    with tempfile.TemporaryDirectory(prefix='split-artifact-static-') as temporary:
        for index, target in enumerate(targets):
            work = Path(temporary) / str(index)
            work.mkdir(mode=0o700)
            binary = fixed.read_regular(app / target['binary'])
            constraint.inspect_slice(binary)
            target['verified_slices'] = fixed.verify_target(app, target, work)
            target['cdhash'] = constraint.cdhash(binary).hex()
            if target['role'] == 'framework':
                hashes.append(bytes.fromhex(target['cdhash']))
            if target['role'] == 'gui':
                if constraint.verify_library_constraint(binary, hashes) != receipt.get('library_constraint'):
                    raise ValueError('GUI five-framework constraint changed')
    if targets != receipt['targets']:
        raise ValueError('Artifact signatures differ from receipt')
    fixed.check_signing_delta(before, entries, [target for target in targets if target['role'] != 'core'])
    fixed.run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--all-architectures', str(app)])
    if fixed.inventory(app, verifier) != entries or pinned_json(receipt_path, receipt_sha256) != receipt:
        raise ValueError('Artifact or receipt changed during verification')
    return receipt


def verify_compile_receipt(path, expected, signed):
    compiled = pinned_json(path, expected)
    if (compiled.get('schema') != 'flash-stable-service-compile-v2' or compiled.get('completed') is not True or
            compiled.get('staged_unsigned_entries') != signed['before']['entries'] or
            compiled.get('core_sha256') != signed['reused_signed_core_sha256'] or
            set(compiled.get('outputs', {})) != set(BINARIES)):
        raise ValueError('Compiler provenance differs from unsigned service')
    sources = compiled.get('source_inputs', {})
    pending = {name for group in SOURCES.values() for name in group}
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        source = ROOT / name
        if record(source) != sources.get(name):
            raise ValueError('Service source differs from compile receipt: ' + name)
        for include in re.findall(r'^\s*#\s*(?:include|import)\s*"([^"\n]+)"', read(source).decode(), re.M):
            dependency = (source.parent / include).resolve(strict=True)
            if not dependency.is_relative_to(ROOT):
                raise ValueError('Native include escapes source root')
            pending.add(str(dependency.relative_to(ROOT)))
    for role, binary in BINARIES.items():
        output = compiled['outputs'][role]
        output_path = Path(output['path'])
        argv = compile_argv(role, compiled['toolchain']['compiler'], compiled['toolchain']['sdk'], output_path)
        if (output.get('clang_argv') != argv or
                {key: output[key] for key in ('sha256', 'bytes', 'mode')} != record(output_path) or
                output['sha256'] != signed['before']['entries'][binary]['sha256'] or
                not any(command.get('argv') == SANDBOX + argv and command.get('returncode') == 0
                        for command in compiled['commands'])):
            raise ValueError('Compiler output/argv differs from service signing inputs')
    return compiled


def verify(gui, service, gui_receipt, gui_sha256, service_receipt, service_sha256,
           compile_receipt=None, compile_sha256=None):
    os.umask(0o077)
    signer, stage = module('sign_split_payload'), module('stage_split_payload')
    caller = verify_bundle(gui, 'gui', gui_receipt, gui_sha256, signer, stage)
    installed = verify_bundle(service, 'service', service_receipt, service_sha256, signer, stage)
    compatibility = stage.compatible_pair(gui, service)
    if bool(compile_receipt) != bool(compile_sha256):
        raise ValueError('Compiler provenance requires receipt and SHA256')
    if compile_receipt is not None:
        verify_compile_receipt(compile_receipt, compile_sha256, installed)
    return {'gui_static_verified': True, 'service_static_verified': True,
            'compatibility': compatibility, 'gui_cdhash': caller['targets'][-1]['cdhash'],
            'service_cdhash': installed['targets'][-1]['cdhash'],
            'delivery_mode': 'helper-update' if compile_receipt is not None else 'gui-only',
            'functional_acceptance': 'UNTESTED', 'service_runtime_accepted': False, 'installer_accepted': False}
