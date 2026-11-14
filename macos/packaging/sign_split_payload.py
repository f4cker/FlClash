#!/usr/bin/python3
"""Two separately guarded signing phases; never compile or manage a keychain here.

The parent guard must freeze this file, all pinned imports, inputs and ancestors,
exclude same-UID writers, and lock the keychain between GUI and service phases.
GUI receipt hashes are provenance only; released Core bytes are never re-signed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
import types

WORKTREE = Path(__file__).resolve().parents[2]
PACKAGING = WORKTREE / 'macos/packaging'
FIXED_SIGNER_SHA256 = '2574d8356c2ac9ad50cb94bc476a11463f6ee8f30d24fab97fbe7432c880771a'
STAGING_SHA256 = '98f16a7e23fb747ff8cc8a395b6395ac0fb165f5ca05b14f32f322c399760bdc'
CONSTRAINT_SHA256 = 'b1a402989ca8fd4375b081c68df5d974cf5be635389f399ff9f4ba17e7b2d7de'
KEYCHAIN = '/Users/layoute/Library/Application Support/Flash Signing/FlashSigning.keychain-db'
CERTIFICATE_SHA1 = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'
CERTIFICATE_SHA256 = 'E8346770F4BF2ABC94F755A136677CDA84B821A668B0983E7FBEF21F8A646E95'
EVIDENCE = WORKTREE / '.airbuild/evidence'
NATIVE_REVIEW_FILES = {
    'review': ('split-constraint-runtime-2026111303-attempt02-independent-review.json',
               'd31226e0b7235f8e2ca745c1470adeafafc5af12aad6da76148ffd91b24c312c'),
    'supplemental': ('split-constraint-runtime-2026111303-attempt02-supplemental-static.json',
                     '85cf3d406d282e8820f02a19480d13f0b8549c3f35f8d0305a03fca1f1720ea8'),
    'original': ('split-constraint-runtime-2026111303-attempt02/runtime-result.json',
                 '97a0314f8e02b006c09bf96afe5d15aeaf5cb5857a863cb664069e05ed1bf96d'),
}
REVIEWED_HOST = {
    'system': 'darwin', 'architecture': 'arm64', 'product_version': '27.0.1',
    'product_build': '26A434',
    'codesign_sha256': 'd517c9be608ffd266ec106c685e880cda71abc94001450e36d2476016406dd1e',
}


def current_host():
    def read_system(path):
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, 'rb') as stream:
            metadata = os.fstat(stream.fileno())
            if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
                    or metadata.st_mode & 0o7022):
                raise ValueError('Unsafe system identity input')
            return stream.read()
    version = plistlib.loads(read_system('/System/Library/CoreServices/SystemVersion.plist'))
    return {'system': sys.platform, 'architecture': os.uname().machine,
            'product_version': version.get('ProductVersion'),
            'product_build': version.get('ProductBuildVersion'),
            'codesign_sha256': hashlib.sha256(read_system('/usr/bin/codesign')).hexdigest()}


def native_constraint_review(fixed):
    host = current_host()
    if host != REVIEWED_HOST:
        raise ValueError('Sign-time validator replacement is reviewed for this exact host/tool only')
    documents = {}
    for role, (relative, digest) in NATIVE_REVIEW_FILES.items():
        source = fixed.read_regular(EVIDENCE / relative)
        if fixed.sha256(source) != digest:
            raise ValueError('Native constraint evidence changed: ' + role)
        documents[role] = json.loads(source)
    review, supplemental, original = (documents[role] for role in ('review', 'supplemental', 'original'))
    if (review.get('native_observation_review_accepted') is not True
            or review.get('automated_suite_passed') is not False
            or original.get('suite_passed') is not False
            or original.get('native_qualification') is not False
            or supplemental.get('original_suite_passed') is not False
            or supplemental.get('fixture_executed_again') is not False
            or supplemental.get('input_hashes_equal_before_after_now') is not True
            or review.get('original_result_sha256') != NATIVE_REVIEW_FILES['original'][1]
            or supplemental.get('original_result_sha256') != NATIVE_REVIEW_FILES['original'][1]
            or review.get('supplemental_static_sha256') != NATIVE_REVIEW_FILES['supplemental'][1]
            or original.get('before_sha256') != original.get('after_sha256')
            or supplemental.get('post_constraint_receipt') != original.get('pre_constraint_receipt')):
        raise ValueError('Native review must preserve failed automation and separate accepted observations')
    return {'scope': 'replace-sign-time-validator-only', 'host': host,
            'evidence_sha256': {role: entry[1] for role, entry in NATIVE_REVIEW_FILES.items()},
            'original_suite_passed': False, 'native_observation_review_accepted': True,
            'production_gui_qualified': False}


def frozen_module(name, digest):
    path = PACKAGING / name
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    import stat
    with os.fdopen(descriptor, 'rb') as stream:
        metadata = os.fstat(stream.fileno())
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1
                or metadata.st_uid != os.getuid() or metadata.st_mode & 0o7022):
            raise ValueError('Unsafe frozen import')
        source = stream.read()
    if hashlib.sha256(source).hexdigest() != digest:
        raise ValueError('Frozen dependency changed: ' + name)
    module = types.ModuleType('_split_' + name.replace('.', '_'))
    module.__file__ = str(path)
    exec(compile(source, str(path), 'exec'), module.__dict__)
    return module


def dependencies():
    fixed = frozen_module('sign_fixed_payload.py', FIXED_SIGNER_SHA256)
    constraint = frozen_module('library_constraint.py', CONSTRAINT_SHA256)
    if (fixed.KEYCHAIN != KEYCHAIN or fixed.CERTIFICATE_SHA1 != CERTIFICATE_SHA1
            or fixed.CERTIFICATE_SHA256 != CERTIFICATE_SHA256):
        raise ValueError('Fixed identity mismatch')
    return fixed, constraint


def signing_targets(app, entries, phase, fixed):
    if phase == 'gui':
        original = fixed.FIXED
        try:
            fixed.FIXED = original[:1]
            targets = fixed.signing_targets(app, entries)
        finally:
            fixed.FIXED = original
        if (app / 'Contents/Library/HelperTools').exists():
            raise ValueError('GUI may not contain HelperTools')
        return targets
    if phase != 'service':
        raise ValueError('Unknown signing phase')
    fixed.plist_identifier(app / 'Contents/Info.plist', 'com.layoute.flash.service', 'Flash')
    if (app / 'Contents/Frameworks').exists():
        raise ValueError('Service may not contain GUI frameworks')
    targets = [dict(role=role, path=relative, binary=relative, identifier=identifier)
               for role, relative, identifier in fixed.FIXED]
    targets.append(dict(role='service', path='.', binary='Contents/MacOS/Flash',
                        identifier='com.layoute.flash.service'))
    actual = {path for path, entry in entries.items() if entry.get('macho')}
    if actual != {target['binary'] for target in targets}:
        raise ValueError('Unknown or missing service executable')
    for target in targets:
        path = app / target['binary']
        if path.is_symlink() or not path.stat().st_mode & 0o100:
            raise ValueError('Service code must be real owner-executable files')
        target['entitlements'] = {}
        target['designated_requirement'] = fixed.requirement(target['identifier'])
    return targets


def audit(app, phase, fixed, verifier, targets):
    if phase == 'gui':
        original = verifier.FIXED_EXECUTABLES
        try:
            verifier.FIXED_EXECUTABLES = ('Contents/MacOS/FlClashCore',)
            verifier.audit(app)
        finally:
            verifier.FIXED_EXECUTABLES = original
    else:
        verifier.validate_links(app)
        for target in targets:
            binary = app / target['binary']
            for paths, libraries in verifier.load_commands(binary).values():
                if paths:
                    raise ValueError('Service code may not have rpaths')
                for library in libraries:
                    if ('..' in Path(library).parts or not (
                            library.startswith('/usr/lib/') or library.startswith('/System/Library/'))):
                        raise ValueError('Service may only load system libraries')
    for target in targets:
        target['architectures'] = sorted(verifier.load_commands(app / target['binary']))
        if target['architectures'] != ['arm64']:
            raise ValueError('Split signing currently supports arm64 only')


def gui_receipt(gui, digest, fixed, constraint, verifier):
    path = gui.parent / 'Flash.gui-signing-static.json'
    source = fixed.read_regular(path)
    if fixed.sha256(source) != digest:
        raise ValueError('GUI receipt pin mismatch')
    receipt = json.loads(source)
    if (receipt.get('phase') != 'gui' or receipt.get('app') != str(gui)
            or receipt.get('static_verification') is not True
            or receipt.get('inputs', {}).get('driver_sha256') != fixed.sha256(fixed.read_regular(Path(__file__)))
            or receipt.get('inputs', {}).get('constraint_sha256') != CONSTRAINT_SHA256
            or receipt.get('pins', {}).get('certificate_sha256') != CERTIFICATE_SHA256):
        raise ValueError('Not a current split GUI receipt')
    entries = fixed.inventory(gui, verifier)
    if entries != receipt['after']['entries'] or fixed.tree_digest(entries) != receipt['after']['tree_sha256']:
        raise ValueError('Signed GUI changed since phase one')
    hashes = [bytes.fromhex(value) for value in receipt['library_constraint']['framework_cdhashes']]
    observed = constraint.verify_library_constraint(fixed.read_regular(gui / 'Contents/MacOS/Flash'), hashes)
    if observed != receipt['library_constraint']:
        raise ValueError('GUI constraint receipt mismatch')
    return receipt


def sign_arguments(app, target, entitlement_file, fixed, constraint_file=None):
    args = fixed.sign_arguments(app, target, entitlement_file)
    if target['role'] == 'gui':
        if constraint_file is None:
            raise ValueError('GUI requires an exact library constraint')
        args[-1:-1] = ['--library-constraint', str(constraint_file)]
    elif constraint_file is not None:
        raise ValueError('Only GUI receives a library constraint')
    return args


def execute(phase, app_value, keychain, certificate, gui_app=None, gui_report_sha256=None, core_sha256=None):
    if keychain != KEYCHAIN or certificate != CERTIFICATE_SHA1 or os.getuid() == 0:
        raise ValueError('Only fixed identity/keychain and non-root caller allowed')
    if Path(__file__).absolute() != PACKAGING / 'sign_split_payload.py':
        raise ValueError('Driver must run from reviewed worktree')
    if phase not in ('gui', 'service'):
        raise ValueError('Unknown phase')
    if phase == 'gui' and (gui_app is not None or gui_report_sha256 is not None):
        raise ValueError('GUI phase does not consume a prior receipt')
    if bool(gui_app) != bool(gui_report_sha256):
        raise ValueError('GUI provenance requires both bundle and receipt SHA256')
    if not isinstance(core_sha256, str) or len(core_sha256) != 64 or any(c not in '0123456789abcdef' for c in core_sha256):
        raise ValueError('Explicit released signed Core SHA256 required')
    fixed, constraint = dependencies()
    reviewed_constraint = native_constraint_review(fixed)
    app = fixed.staging_path(app_value)
    verifier = fixed.trusted_verifier()
    stage = frozen_module('stage_split_payload.py', STAGING_SHA256)
    compatibility = stage.read_compatibility(app, phase)
    before = fixed.inventory(app, verifier)
    if fixed.sha256(fixed.read_regular(app / 'Contents/MacOS/FlClashCore')) != core_sha256:
        raise ValueError('Released Core differs before signing')
    targets = signing_targets(app, before, phase, fixed)
    for target in targets:
        constraint.inspect_slice(fixed.read_regular(app / target['binary']))
    audit(app, phase, fixed, verifier, targets)
    entitlement_source = fixed.read_regular(PACKAGING / 'FixedGUI.entitlements')
    if plistlib.loads(entitlement_source) != fixed.GUI_ENTITLEMENTS:
        raise ValueError('GUI entitlement policy changed')
    gui = None
    if phase == 'service' and gui_app:
        gui = fixed.staging_path(gui_app)
        if app == gui or app.is_relative_to(gui) or gui.is_relative_to(app):
            raise ValueError('Service and GUI stages must be disjoint')
        receipt = gui_receipt(gui, gui_report_sha256, fixed, constraint, verifier)
        stage.compatible_pair(gui, app)
    if fixed.inventory(app, verifier) != before:
        raise ValueError('Stage changed during preflight')
    report = {'schema': 1, 'phase': phase, 'app': str(app), 'static_verification': False,
              'actualGUIloads': False, 'native_qualification': False, 'packaging_accepted': False,
              'runtime_gate_changed': False, 'native_constraint_review': reviewed_constraint,
              'pins': {'certificate_sha1': CERTIFICATE_SHA1, 'certificate_sha256': CERTIFICATE_SHA256},
              'inputs': {'driver_sha256': fixed.sha256(fixed.read_regular(Path(__file__))),
                         'fixed_signer_sha256': FIXED_SIGNER_SHA256,
                         'constraint_sha256': CONSTRAINT_SHA256,
                         'staging_sha256': STAGING_SHA256,
                         'verifier_sha256': fixed.VERIFIER_SHA256,
                         'gui_entitlements_sha256': fixed.sha256(entitlement_source)},
              'before': {'tree_sha256': fixed.tree_digest(before), 'entries': before}, 'targets': targets,
              'reused_signed_core_sha256': core_sha256, 'compatibility': compatibility}
    if gui is not None:
        report['gui_receipt_sha256'] = gui_report_sha256
        report['gui_cdhash'] = receipt['library_constraint']['cdhash']
    report_path = app.parent / ('Flash.' + phase + '-signing-static.json')
    descriptor = os.open(report_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        def save():
            stream.seek(0)
            json.dump(report, stream, indent=2, sort_keys=True)
            stream.write('\n')
            stream.truncate()
            stream.flush()
            os.fsync(stream.fileno())
        save()
        try:
            with tempfile.TemporaryDirectory(prefix='.split-sign-', dir=app.parent) as temporary:
                scratch = Path(temporary)
                entitlements = scratch / 'gui.plist'
                entitlements.write_bytes(entitlement_source)
                empty = scratch / 'empty.plist'
                empty.write_bytes(plistlib.dumps({}))
                hashes = []
                for index, target in enumerate(targets):
                    constraint_file = None
                    if target['role'] == 'gui':
                        constraint_file = scratch / 'library.plist'
                        constraint_file.write_bytes(constraint.constraint_plist(hashes))
                    if target['role'] != 'core':
                        fixed.run_tool(sign_arguments(app, target,
                            entitlements if target['role'] == 'gui' else empty, fixed, constraint_file))
                    certificates = scratch / str(index)
                    certificates.mkdir(mode=0o700)
                    target['verified_slices'] = fixed.verify_target(app, target, certificates)
                    binary = fixed.read_regular(app / target['binary'])
                    target['cdhash'] = constraint.cdhash(binary).hex()
                    if target['role'] == 'framework':
                        hashes.append(bytes.fromhex(target['cdhash']))
                    if target['role'] == 'gui':
                        report['library_constraint'] = constraint.verify_library_constraint(binary, hashes)
                fixed.run_tool(['/usr/bin/codesign', '--verify', '--deep', '--strict',
                                '--all-architectures', str(app)])
                audit(app, phase, fixed, verifier, targets)
                after = fixed.inventory(app, verifier)
                signing_targets(app, after, phase, fixed)
                mutable = [target for target in targets if target['role'] != 'core']
                fixed.check_signing_delta(before, after, mutable)
                if fixed.sha256(fixed.read_regular(app / 'Contents/MacOS/FlClashCore')) != core_sha256:
                    raise ValueError('Released Core changed during signing')
                if gui is not None:
                    gui_receipt(gui, gui_report_sha256, fixed, constraint, verifier)
                    stage.compatible_pair(gui, app)
                if native_constraint_review(fixed) != reviewed_constraint:
                    raise ValueError('Native constraint review changed during signing')
                report['after'] = {'tree_sha256': fixed.tree_digest(after), 'entries': after}
                report['static_verification'] = True
        except BaseException as error:
            report['failure'] = type(error).__name__
            if isinstance(error, (subprocess.CalledProcessError, subprocess.TimeoutExpired)):
                report['failure_details'] = fixed.tool_failure_details(error, app, targets)
            try:
                after = fixed.inventory(app, verifier)
                report['failure_inventory'] = {'tree_sha256': fixed.tree_digest(after), 'entries': after}
            except (ValueError, OSError):
                report['failure_inventory_unavailable'] = True
            save()
            raise
        save()
    return report_path


def main():
    if not (sys.flags.isolated and sys.flags.no_site and sys.dont_write_bytecode):
        print('Guard must invoke /usr/bin/python3 -I -S -B.', file=sys.stderr)
        return 1
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--phase', choices=('gui', 'service'), required=True)
    parser.add_argument('--app', required=True)
    parser.add_argument('--gui-app')
    parser.add_argument('--gui-report-sha256')
    parser.add_argument('--core-sha256', required=True)
    parser.add_argument('--keychain', required=True)
    parser.add_argument('--certificate', required=True)
    args = parser.parse_args()
    try:
        result = execute(args.phase, args.app, args.keychain, args.certificate,
                         args.gui_app, args.gui_report_sha256, args.core_sha256)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print('Split signing failed closed: ' + type(error).__name__, file=sys.stderr)
        return 1
    print(str(result) + '; native qualification and package acceptance remain false')
    return 0


if __name__ == '__main__':
    sys.exit(main())
