import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ROOT = Path(__file__).parents[1]
D = load('split_signer', ROOT / 'sign_split_payload.py')
OLD = load('fixed_tests', Path(__file__).with_name('test_fixed_signing.py'))
C = load('constraint', ROOT / 'library_constraint.py')


class SplitSigningTests(unittest.TestCase):
    def setUp(self):
        self.fixture = OLD.SigningPolicyTests('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixed = OLD.DRIVER
        self.app = self.fixture.app
        shutil.rmtree(self.app / 'Contents/Library')
        manifest = next(self.app.rglob('NativeAssetsManifest.json'))
        data = json.loads(manifest.read_text())
        data['native-assets'] = {k: v for k, v in data['native-assets'].items() if 'arm64' in k}
        manifest.write_text(json.dumps(data))
        self.calls = []
        self.native_review = {'scope': 'replace-sign-time-validator-only',
                              'original_suite_passed': False,
                              'native_observation_review_accepted': True,
                              'production_gui_qualified': False}
        self.constraint = types.SimpleNamespace(
            inspect_slice=lambda binary: binary,
            cdhash=lambda binary: hashlib.sha256(binary).digest()[:20],
            constraint_plist=C.constraint_plist,
            verify_library_constraint=lambda binary, hashes: {
                'cdhash': hashlib.sha256(binary).digest()[:20].hex(),
                'framework_cdhashes': sorted(h.hex() for h in hashes),
                'native_qualification': False,
            },
        )
        for obj, name, value in ((D, 'dependencies', lambda: (self.fixed, self.constraint)),
                                 (D, 'native_constraint_review', lambda fixed: dict(self.native_review)),
                                 (D, 'CERTIFICATE_SHA1', self.fixture.pin1),
                                 (D, 'CERTIFICATE_SHA256', self.fixture.pin256),
                                 (self.fixed, 'run_tool', self.tool)):
            p = patch.object(obj, name, value)
            p.start()
            self.addCleanup(p.stop)

    def tool(self, args):
        self.calls.append(args)
        if args[0] == '/usr/bin/lipo':
            return subprocess.CompletedProcess(args, 0, b'arm64', b'')
        if args[0] == '/usr/bin/otool':
            return subprocess.CompletedProcess(args, 0, (args[-1] + ' (architecture arm64):').encode(), b'')
        if '--sign' in args:
            target = next(t for t in self.targets() if str(self.app / t['path']) == args[-1])
            binary = self.app / target['binary']
            binary.write_bytes(binary.read_bytes() + target['identifier'].encode())
            if target['role'] == 'gui':
                self.assertNotIn('--enforce-constraint-validity', args)
                self.assertEqual(args[args.index('--options') + 1], 'runtime')
                constraint_file = Path(args[args.index('--library-constraint') + 1])
                self.assertEqual(len(plistlib.loads(constraint_file.read_bytes())['cdhash']['$in']), 5)
        if '--verbose=4' in args:
            target = next(t for t in self.targets() if str(self.app / t['path']) == args[-1])
            stderr = (f'Identifier={target["identifier"]}\n'
                      'CodeDirectory v=20500 size=1 flags=0x10000(runtime) hashes=1+1\n'
                      'TeamIdentifier=not set\n').encode()
            return subprocess.CompletedProcess(args, 0, b'', stderr)
        return self.fixture.tool(args)

    def targets(self):
        return D.signing_targets(self.app, self.fixed.inventory(self.app, self.fixture.verifier),
                                 getattr(self, 'phase', 'gui'), self.fixed)

    def execute(self):
        return D.execute('gui', str(self.app), D.KEYCHAIN, self.fixture.pin1)

    def test_seven_gui_targets_nested_first_receipt_and_gates(self):
        report = json.loads(self.execute().read_text())
        self.assertTrue(report['static_verification'])
        self.assertEqual(len(report['targets']), 7)
        for gate in ('actualGUIloads', 'native_qualification', 'packaging_accepted', 'runtime_gate_changed'):
            self.assertIs(report[gate], False)
        signing = [args for args in self.calls if '--sign' in args]
        self.assertEqual(len(signing), 7)
        self.assertEqual(signing[-1][-1], str(self.app))
        self.assertTrue(all('--deep' not in args for args in signing))
        self.assertTrue(all('--library-constraint' not in args for args in signing[:-1]))
        self.assertEqual(report['targets'][-1]['entitlements'], self.fixed.GUI_ENTITLEMENTS)
        self.assertEqual(report['native_constraint_review'], self.native_review)
        self.assertTrue(all('--enforce-constraint-validity' not in args for args in signing))

    def test_signing_failure_no_retry_or_acceptance(self):
        original = self.tool
        def tool(args):
            if '--library-constraint' in args:
                self.calls.append(args)
                raise subprocess.CalledProcessError(1, args, stderr=b'Mock codesign failure')
            return original(args)
        with patch.object(self.fixed, 'run_tool', tool), self.assertRaises(subprocess.CalledProcessError):
            self.execute()
        report = json.loads((self.app.parent / 'Flash.gui-signing-static.json').read_text())
        self.assertFalse(report['static_verification'])
        self.assertIn('failure_inventory', report)
        self.assertEqual(sum('--library-constraint' in args for args in self.calls), 1)

    def test_all_seven_container_preflights_finish_before_first_codesign(self):
        inspections = []
        original = self.tool
        def inspect(binary):
            inspections.append(binary)
            return binary
        def tool(args):
            if args[0] == '/usr/bin/codesign':
                self.assertEqual(len(inspections), 7)
            return original(args)
        with patch.object(self.constraint, 'inspect_slice', side_effect=inspect):
            with patch.object(self.fixed, 'run_tool', tool):
                self.execute()
        self.assertEqual(len(inspections), 7)

    def test_invalid_container_at_any_position_prevents_all_codesign_calls(self):
        for position in range(7):
            effects = [b'slice'] * position + [ValueError('Malformed FAT container')]
            with self.subTest(position=position):
                self.calls.clear()
                with patch.object(self.constraint, 'inspect_slice', side_effect=effects):
                    with self.assertRaises(ValueError):
                        self.execute()
                self.assertFalse(any(args[0] == '/usr/bin/codesign' for args in self.calls))

    def test_unreviewed_evidence_stops_before_any_tool_or_signature(self):
        with patch.object(D, 'native_constraint_review', side_effect=ValueError('Unreviewed evidence')):
            with self.assertRaises(ValueError):
                self.execute()
        self.assertEqual(self.calls, [])

    def test_actual_der_binding_failure_is_fatal_after_strict_signature_verification(self):
        with patch.object(self.constraint, 'verify_library_constraint', side_effect=ValueError('Bad slot11 binding')):
            with self.assertRaises(ValueError):
                self.execute()
        self.assertTrue(any('--verify' in args and '--strict' in args
                            and args[-1] == str(self.app) for args in self.calls))
        report = json.loads((self.app.parent / 'Flash.gui-signing-static.json').read_text())
        self.assertFalse(report['static_verification'])
        self.assertFalse(report['native_qualification'])

    def test_strict_signature_failure_is_not_replaced_by_der_check(self):
        original = self.tool
        def tool(args):
            if '--verify' in args and '--strict' in args and args[-1] == str(self.app):
                raise subprocess.CalledProcessError(1, args)
            return original(args)
        with patch.object(self.fixed, 'run_tool', tool):
            with self.assertRaises(subprocess.CalledProcessError):
                self.execute()
        report = json.loads((self.app.parent / 'Flash.gui-signing-static.json').read_text())
        self.assertFalse(report['static_verification'])

    def test_changed_review_after_signing_is_fatal(self):
        with patch.object(D, 'native_constraint_review', side_effect=[self.native_review, {}]):
            with self.assertRaises(ValueError):
                self.execute()
        report = json.loads((self.app.parent / 'Flash.gui-signing-static.json').read_text())
        self.assertFalse(report['static_verification'])

    def test_reject_helper_in_gui_and_extra_macho(self):
        for name in ('Contents/Library/HelperTools/FlashHelper', 'Contents/MacOS/Unknown'):
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(bytes.fromhex('cffaedfe') + b'never executed')
            path.chmod(0o755)
            with self.assertRaises(ValueError):
                self.targets()
            path.unlink()

    def test_non_signature_mutation_is_fatal(self):
        original = self.tool
        def tool(args):
            result = original(args)
            if '--library-constraint' in args:
                (self.app / 'Contents/Info.plist').write_bytes(
                    (self.app / 'Contents/Info.plist').read_bytes() + b'\n')
            return result
        with patch.object(self.fixed, 'run_tool', tool), self.assertRaises(ValueError):
            self.execute()

    def test_service_has_four_targets_and_no_frameworks(self):
        shutil.rmtree(self.app / 'Contents/Frameworks')
        for _, relative, _ in self.fixed.FIXED[1:]:
            self.fixture.binary(relative)
        self.fixture.write('Contents/Info.plist', plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash.service', 'CFBundleExecutable': 'Flash'}))
        entries = self.fixed.inventory(self.app, self.fixture.verifier)
        targets = D.signing_targets(self.app, entries, 'service', self.fixed)
        self.assertEqual(len(targets), 4)
        self.assertEqual(targets[-1]['identifier'], 'com.layoute.flash.service')
        self.assertTrue(all(target['entitlements'] == {} for target in targets))
        (self.app / 'Contents/Frameworks').mkdir()
        with self.assertRaises(ValueError):
            D.signing_targets(self.app, entries, 'service', self.fixed)

    def test_service_requires_pinned_gui_receipt(self):
        with self.assertRaises(ValueError):
            D.execute('service', str(self.app), D.KEYCHAIN, self.fixture.pin1)

    def test_gui_receipt_requires_unchanged_tree_and_current_driver(self):
        report_path = self.execute()
        digest = self.fixed.sha256(report_path.read_bytes())
        receipt = D.gui_receipt(self.app, digest, self.fixed, self.constraint, self.fixture.verifier)
        self.assertEqual(receipt['phase'], 'gui')
        (self.app / 'Contents/changed').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            D.gui_receipt(self.app, digest, self.fixed, self.constraint, self.fixture.verifier)

    def prepare_service(self):
        report = self.execute()
        gui = self.app
        digest = self.fixed.sha256(report.read_bytes())
        service = gui.parent.parent / 'service/Flash.app'
        shutil.copytree(gui, service, symlinks=True)
        shutil.rmtree(service / 'Contents/Frameworks')
        (service / 'Contents/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash.service', 'CFBundleExecutable': 'Flash'}))
        for _, relative, _ in self.fixed.FIXED[1:]:
            path = service / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(bytes.fromhex('cffaedfe') + b'mock-helper-never-execute')
            path.chmod(0o755)
        self.app, self.phase = service, 'service'
        self.calls.clear()
        return gui, digest

    def test_complete_service_verifies_four_but_signs_only_three_preserving_core(self):
        gui, digest = self.prepare_service()
        core = (gui / 'Contents/MacOS/FlClashCore').read_bytes()
        report_path = D.execute('service', str(self.app), D.KEYCHAIN, self.fixture.pin1,
                                str(gui), digest)
        report = json.loads(report_path.read_text())
        self.assertTrue(report['static_verification'])
        self.assertEqual(len(report['targets']), 4)
        signing = [args for args in self.calls if '--sign' in args]
        self.assertEqual(len(signing), 3)
        self.assertTrue(all('FlClashCore' not in args[-1] for args in signing))
        self.assertTrue(all('--library-constraint' not in args for args in signing))
        self.assertEqual((self.app / 'Contents/MacOS/FlClashCore').read_bytes(), core)
        self.assertEqual(report['gui_receipt_sha256'], digest)
        self.assertFalse(report['native_qualification'])

    def test_service_rejects_nonidentical_core_before_signing(self):
        gui, digest = self.prepare_service()
        (self.app / 'Contents/MacOS/FlClashCore').write_bytes(b'\xcf\xfa\xed\xfechanged')
        with self.assertRaises(ValueError):
            D.execute('service', str(self.app), D.KEYCHAIN, self.fixture.pin1, str(gui), digest)
        self.assertFalse(any('--sign' in args for args in self.calls))

    def test_service_rejects_core_mutation_during_signing(self):
        gui, digest = self.prepare_service()
        original = self.tool
        def tool(args):
            result = original(args)
            if '--sign' in args:
                path = self.app / 'Contents/MacOS/FlClashCore'
                path.write_bytes(path.read_bytes() + b'changed')
            return result
        with patch.object(self.fixed, 'run_tool', tool), self.assertRaises(ValueError):
            D.execute('service', str(self.app), D.KEYCHAIN, self.fixture.pin1, str(gui), digest)

    def test_frozen_modules_and_identity(self):
        with self.assertRaises(ValueError):
            D.frozen_module('library_constraint.py', '0' * 64)
        self.assertEqual(D.frozen_module('library_constraint.py', D.CONSTRAINT_SHA256).__name__,
                         '_split_library_constraint_py')


class NativeConstraintReviewTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.documents = {
            'original': {'suite_passed': False, 'native_qualification': False,
                         'before_sha256': {'fixture': 'frozen'}, 'after_sha256': {'fixture': 'frozen'},
                         'pre_constraint_receipt': {'special_slot': 11, 'native_qualification': False}},
            'supplemental': {'original_suite_passed': False, 'fixture_executed_again': False,
                             'input_hashes_equal_before_after_now': True,
                             'post_constraint_receipt': {'special_slot': 11, 'native_qualification': False}},
            'review': {'native_observation_review_accepted': True, 'automated_suite_passed': False},
        }
        self.pins = {}
        for role in ('original', 'supplemental', 'review'):
            if role != 'original':
                self.documents[role]['original_result_sha256'] = self.pins['original'][1]
            if role == 'review':
                self.documents[role]['supplemental_static_sha256'] = self.pins['supplemental'][1]
            self.save(role)
        for name, value in (('EVIDENCE', self.root), ('NATIVE_REVIEW_FILES', self.pins),
                            ('current_host', lambda: dict(D.REVIEWED_HOST))):
            p = patch.object(D, name, value)
            p.start()
            self.addCleanup(p.stop)
        p = patch.object(D.subprocess, 'run', side_effect=AssertionError('No actual tools'))
        p.start()
        self.addCleanup(p.stop)

    def save(self, role):
        source = json.dumps(self.documents[role], sort_keys=True).encode()
        path = self.root / (role + '.json')
        path.write_bytes(source)
        path.chmod(0o600)
        self.pins[role] = (path.name, hashlib.sha256(source).hexdigest())

    def test_separate_review_keeps_original_failed_and_production_unqualified(self):
        result = D.native_constraint_review(OLD.DRIVER)
        self.assertFalse(result['original_suite_passed'])
        self.assertTrue(result['native_observation_review_accepted'])
        self.assertFalse(result['production_gui_qualified'])
        self.assertEqual(result['evidence_sha256'], {role: value[1] for role, value in self.pins.items()})

    def test_every_evidence_file_is_hash_pinned(self):
        for role, (name, _) in self.pins.items():
            path = self.root / name
            source = path.read_bytes()
            path.write_bytes(source + b'\n')
            with self.subTest(role=role), self.assertRaises(ValueError):
                D.native_constraint_review(OLD.DRIVER)
            path.write_bytes(source)

    def test_host_arch_os_build_and_codesign_are_exact(self):
        for key in D.REVIEWED_HOST:
            different = dict(D.REVIEWED_HOST, **{key: 'different'})
            with self.subTest(key=key), patch.object(D, 'current_host', return_value=different):
                with self.assertRaises(ValueError):
                    D.native_constraint_review(OLD.DRIVER)

    def test_no_manufactured_automation_success_or_missing_review(self):
        for key, value in (('automated_suite_passed', True), ('native_observation_review_accepted', False)):
            original = self.documents['review'][key]
            self.documents['review'][key] = value
            self.save('review')
            with self.subTest(key=key), self.assertRaises(ValueError):
                D.native_constraint_review(OLD.DRIVER)
            self.documents['review'][key] = original
            self.save('review')

    def test_missing_evidence_fails_closed(self):
        (self.root / self.pins['supplemental'][0]).unlink()
        with self.assertRaises(OSError):
            D.native_constraint_review(OLD.DRIVER)

    def test_changed_evidence_link_is_rejected_even_if_document_is_repinned(self):
        self.documents['review']['original_result_sha256'] = '0' * 64
        self.save('review')
        with self.assertRaises(ValueError):
            D.native_constraint_review(OLD.DRIVER)


if __name__ == '__main__':
    unittest.main()
