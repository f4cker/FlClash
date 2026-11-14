import base64
import copy
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch

SPEC = importlib.util.spec_from_file_location(
    'split_qualification', Path(__file__).parents[1] / 'qualify_split_loads.py')
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)
Q.PACKAGING = Path(__file__).resolve().parents[1]


class QualificationPinsTests(unittest.TestCase):
    def test_retry_stage_and_shared_adapter_pins(self):
        self.assertEqual(Q.GUI_APP, Q.ROOT / '.airbuild/artifacts/split-2026111303-retry01/gui/Flash.app')
        with patch.object(subprocess, 'Popen', side_effect=AssertionError('No child')):
            signer = Q.driver()
            _, constraint = signer.dependencies()
        self.assertEqual(signer.CONSTRAINT_SHA256, Q.CONSTRAINT_SHA256)
        self.assertTrue(callable(constraint.inspect_slice))


class SplitQualificationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.app = self.root / 'gui/Flash.app'
        self.app.mkdir(parents=True)
        self.metadata_path = self.root / 'metadata.json'
        self.metadata_path.write_text('{}')
        self.evidence_root = self.root / 'evidence'
        self.evidence_root.mkdir()
        self.evidence_path = self.evidence_root / 'fresh.json'
        self.scratch_root = self.root / 'scratch'
        self.scratch_root.mkdir()
        self.legacy = Q.native()
        self.legacy.SCRATCH_ROOT = self.scratch_root
        self.fixed = MagicMock()
        self.fixed.CERTIFICATE_SHA1 = 'fixed-certificate'
        self.fixed.CERTIFICATE_SHA256 = 'fixed-sha256'
        self.fixed.staging_path.side_effect = lambda value: Path(value)
        self.fixed.tree_digest.return_value = 'tree'
        self.constraint = MagicMock()
        self.constraint.cdhash.side_effect = lambda data: Q.hashlib.sha256(data).digest()[:20]
        self.binding = {'special_slot': 11, 'constraint_sha256': 'bound', 'native_qualification': False}
        self.constraint.verify_library_constraint.return_value = self.binding
        self.signer = MagicMock()
        self.signer.dependencies.return_value = (self.fixed, self.constraint)
        self.signer.CONSTRAINT_SHA256 = Q.CONSTRAINT_SHA256
        self.signer.native_constraint_review.return_value = {
            'scope': 'replace-sign-time-validator-only', 'original_suite_passed': False,
            'native_observation_review_accepted': True, 'production_gui_qualified': False,
            'host': {'architecture': 'arm64', 'system': 'fixture'}}
        self.info = {'CFBundleShortVersionString': '0.9.7', 'CFBundleVersion': '2026111303',
                     'FlashDartDefines': base64.b64encode(b'MACOS_MANAGED_HELPER=true').decode()}
        self.metadata = {'schema': 'flash-split-build-v1', 'build_configuration': 'Release',
                         'version': '0.9.7', 'build_number': '2026111303', 'startup_hardened': True,
                         'certificate_sha1': self.fixed.CERTIFICATE_SHA1, 'apple_team': '',
                         'runtime_acceptance': False, 'actualGUIloads': False, 'packaging_accepted': False,
                         'defines': {'APP_ENV': 'stable', 'MACOS_MANAGED_HELPER': True,
                                     'FC_MANAGED_CANDIDATE_ENABLED': 1,
                                     'FC_PINNED_CERTIFICATE_SHA1': self.fixed.CERTIFICATE_SHA1}}
        self.targets = [
            {'role': 'framework', 'binary': f'Contents/Frameworks/{name}.framework/Versions/A/{name}'}
            for name in Q.FRAMEWORKS] + [{'role': 'gui', 'binary': 'Contents/MacOS/Flash'}]
        for target in self.targets:
            target['architectures'] = ['arm64']
        self.signer.signing_targets.side_effect = lambda *args: copy.deepcopy(self.targets)
        self.fixed.verify_target.return_value = {'arm64': {'certificate': 'fixed'}}
        self.entries = {'Contents/MacOS/Flash': {'sha256': 'gui-bytes'}}
        self.fixed.inventory.return_value = self.entries
        self.sources = {name: (Q.PACKAGING / name).read_bytes() for name in (
            'sign_split_payload.py', 'sign_fixed_payload.py', 'stage_managed_payload.py',
            'library_constraint.py', 'FixedGUI.entitlements', 'stage_split_payload.py', 'qualify_native_loads.py',
            'qualify_split_loads.py')}
        self.signer.STAGING_SHA256 = Q.digest(self.sources['stage_split_payload.py'])
        self.contract = {'CallerPolicy': 2, 'ServiceAPI': 1, 'CoreAPI': 1, 'AcceptedCoreSHA256': ['a' * 64]}
        self.info['FlashHelperCompatibility'] = self.contract
        stage_spec = importlib.util.spec_from_file_location('qualification_stage', Q.PACKAGING / 'stage_split_payload.py')
        stage = importlib.util.module_from_spec(stage_spec)
        stage_spec.loader.exec_module(stage)
        self.signer.frozen_module.return_value = stage
        self.signer.FIXED_SIGNER_SHA256 = Q.digest(self.sources['sign_fixed_payload.py'])
        self.fixed.VERIFIER_SHA256 = Q.digest(self.sources['stage_managed_payload.py'])
        self.fixed.read_regular.side_effect = self.read
        inputs = {key: Q.digest(self.sources[name]) for key, name in (
            ('driver_sha256', 'sign_split_payload.py'), ('fixed_signer_sha256', 'sign_fixed_payload.py'),
            ('constraint_sha256', 'library_constraint.py'), ('verifier_sha256', 'stage_managed_payload.py'),
            ('gui_entitlements_sha256', 'FixedGUI.entitlements'), ('staging_sha256', 'stage_split_payload.py'))}
        targets = copy.deepcopy(self.targets)
        for target in targets:
            target['verified_slices'] = self.fixed.verify_target.return_value
            target['cdhash'] = Q.hashlib.sha256(target['binary'].encode()).digest()[:20].hex()
        self.report = {'schema': 1, 'phase': 'gui', 'compatibility': self.contract,
                       'accepted_service_core_sha256': 'a' * 64, 'app': str(self.app), 'static_verification': True,
                       'actualGUIloads': False, 'native_qualification': False, 'packaging_accepted': False,
                       'runtime_gate_changed': False, 'inputs': inputs,
                       'pins': {'certificate_sha1': self.fixed.CERTIFICATE_SHA1,
                                'certificate_sha256': self.fixed.CERTIFICATE_SHA256},
                       'after': {'tree_sha256': 'tree', 'entries': self.entries},
                       'targets': targets, 'library_constraint': self.binding,
                       'native_constraint_review': self.signer.native_constraint_review.return_value}
        for owner, name, value in ((Q, 'GUI_APP', self.app), (Q, 'EVIDENCE_ROOT', self.evidence_root),
                                   (Q, 'DRIVER_SHA256', inputs['driver_sha256'])):
            self.replace(owner, name, value)
        self.replace(Q, 'native', lambda: self.legacy)
        self.replace(Q, 'driver', lambda: self.signer)
        self.replace(Q, 'build_provenance', MagicMock(return_value={'metadata_sha256': 'fixture'}))
        self.replace(self.legacy, 'host', lambda: {'architecture': 'arm64', 'system': 'fixture'})
        self.replace(subprocess, 'Popen', MagicMock(side_effect=AssertionError('No real child permitted')))
        self.replace(subprocess, 'run', MagicMock(side_effect=AssertionError('No real tool permitted')))

    def replace(self, owner, name, value):
        replacement = patch.object(owner, name, value)
        replacement.start()
        self.addCleanup(replacement.stop)

    def read(self, path):
        if path.parent == Q.PACKAGING:
            return self.sources[path.name]
        if path == self.metadata_path:
            return json.dumps(self.metadata).encode()
        if path.name == 'Flash.gui-signing-static.json':
            return json.dumps(self.report).encode()
        if path == self.app / 'Contents/Info.plist':
            return plistlib.dumps(self.info)
        if path == self.evidence_path:
            return path.read_bytes()
        return str(path.relative_to(self.app)).encode()

    def freeze(self):
        work = Path(tempfile.mkdtemp(dir=self.root))
        return Q.frozen_state(self.app, self.metadata_path, self.signer, work)

    def execution(self, scratch=None):
        challenge = 'fresh_split_challenge_12345'
        protocol = {'schema': 1, 'challenge': challenge, 'ok': True, 'code': 'ok',
                    'probes': {name: True for name in self.legacy.PROBES}}
        stdout = (self.legacy.PREFIX + json.dumps(protocol) + '\n').encode()
        scratch = scratch or self.scratch_root / 'session-fixture'
        gui = str(self.app / 'Contents/MacOS/Flash')
        record = {'pid': 1234, 'owned': True, 'returncode': 0, 'timeout': False,
                  'output_overflow': False, 'terminated_by_harness': False,
                  'observed_executable': gui, 'architecture': 'arm64', 'duration_seconds': 0.5,
                  'challenge': challenge, 'sandbox_sha256': Q.digest(
                      self.legacy.sandbox_profile(self.app, scratch).encode()),
                  'argv': ['/usr/bin/sandbox-exec', '-f', str(scratch / 'diagnostic.sb'),
                           '/usr/bin/arch', '-arm64', gui, '--flash-verify-native-loads',
                           '--challenge=' + challenge],
                  'stdout_base64': base64.b64encode(stdout).decode(), 'stdout_sha256': Q.digest(stdout),
                  'stderr_base64': '', 'stderr_sha256': Q.digest(b'')}
        return record, protocol

    def evidence(self, state):
        execution, protocol = self.execution()
        return {'schema': Q.SCHEMA, 'scope': 'gui-only', 'qualified': True, 'actualGUIloads': True,
                'packaging_accepted': False, 'before': state, 'after': state,
                'execution': execution, 'protocol': protocol}

    def test_frozen_gui_has_exact_six_signatures_and_actual_constraint_binding(self):
        state = self.freeze()
        self.assertEqual(state['schema'], Q.STATE_SCHEMA)
        self.assertEqual(state['build_metadata_sha256'], Q.digest(self.read(self.metadata_path)))
        self.assertEqual(len(state['targets']), 6)
        self.assertEqual(self.fixed.verify_target.call_count, 6)
        self.assertEqual(self.constraint.cdhash.call_count, 6)
        self.assertEqual(len(self.constraint.verify_library_constraint.call_args.args[1]), 5)
        self.fixed.run_tool.assert_called_once_with([
            '/usr/bin/codesign', '--verify', '--deep', '--strict', '--all-architectures', str(self.app)])
        self.assertEqual(self.metadata['actualGUIloads'], False)

    def test_metadata_exact_release_and_fresh_startup_required(self):
        for key, value in (('version', '27.2'), ('build_number', '2026111302'),
                           ('build_configuration', 'Debug'), ('startup_hardened', False),
                           ('startup_hardened', 1), ('actualGUIloads', True), ('schema', 1)):
            changed = copy.deepcopy(self.metadata)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_metadata(changed, self.info, self.fixed)
        for key, value in (('MACOS_MANAGED_HELPER', 1), ('FC_MANAGED_CANDIDATE_ENABLED', True),
                           ('FC_PINNED_CERTIFICATE_SHA1', 'other')):
            changed = copy.deepcopy(self.metadata)
            changed['defines'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_metadata(changed, self.info, self.fixed)

    def test_bad_receipt_targets_constraint_or_source_fail_closed(self):
        original = copy.deepcopy(self.report)
        for key, value in (('schema', True), ('phase', 'service'), ('actualGUIloads', True),
                           ('static_verification', False), ('after', {}), ('inputs', {}),
                           ('targets', []), ('library_constraint', {}), ('native_constraint_review', {})):
            self.report = copy.deepcopy(original)
            self.report[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.freeze()
        self.report = original
        self.constraint.verify_library_constraint.side_effect = ValueError('DER slot unbound')
        with self.assertRaises(ValueError):
            self.freeze()
        self.constraint.verify_library_constraint.side_effect = None
        self.sources['qualify_native_loads.py'] += b'\n'
        with self.assertRaises(ValueError):
            self.freeze()

    def test_native_review_must_revalidate_host_and_preserve_failed_automation(self):
        state = self.freeze()
        self.signer.native_constraint_review.assert_called_once_with(self.fixed)
        self.assertFalse(state['native_constraint_review']['original_suite_passed'])
        self.assertFalse(state['native_constraint_review']['production_gui_qualified'])
        review = self.report.pop('native_constraint_review')
        with self.assertRaisesRegex(ValueError, 'constraint review differs'):
            self.freeze()
        self.report['native_constraint_review'] = copy.deepcopy(review)
        self.report['native_constraint_review']['original_suite_passed'] = True
        with self.assertRaisesRegex(ValueError, 'constraint review differs'):
            self.freeze()
        self.report['native_constraint_review'] = review
        self.signer.native_constraint_review.side_effect = ValueError('host/evidence changed')
        with self.assertRaisesRegex(ValueError, 'host/evidence changed'):
            self.freeze()

    def test_old_partial_gui_stage_is_rejected_before_receipt_inspection(self):
        old = Q.ROOT / '.airbuild/artifacts/split-2026111303/gui/Flash.app'
        with self.assertRaisesRegex(ValueError, 'Only the new GUI-only split stage'):
            Q.frozen_state(old, self.metadata_path, self.signer, self.root)
        self.fixed.inventory.assert_not_called()

    def test_no_service_or_helper_and_no_target_shortcut(self):
        with self.assertRaises(ValueError):
            Q.frozen_state(self.root / 'service/Flash.app', self.metadata_path, self.signer, self.root)
        self.targets.pop()
        with self.assertRaises(ValueError):
            self.freeze()
        (self.app / 'Contents/Library').mkdir(parents=True)
        with self.assertRaises(ValueError):
            self.freeze()

    def test_legacy_evidence_and_asserted_success_cannot_qualify(self):
        state = self.freeze()
        evidence = self.evidence(state)
        Q.validate_evidence(evidence, state, self.app)
        for key, value in (('schema', 1), ('scope', 'service'), ('actualGUIloads', 1),
                           ('execution', {}), ('protocol', {}), ('after', {})):
            changed = copy.deepcopy(evidence)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_evidence(changed, state, self.app)
        for key, value in (('returncode', 70), ('challenge', 'wrong_challenge_12345'),
                           ('sandbox_sha256', 'broader'), ('owned', False)):
            changed = copy.deepcopy(evidence)
            changed['execution'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_evidence(changed, state, self.app)

    def test_verify_is_static_and_never_changes_metadata(self):
        self.evidence_path.write_text(json.dumps(self.evidence(self.freeze())))
        original = self.metadata_path.read_bytes()
        with patch.object(self.legacy, 'supervise', side_effect=AssertionError('No probe')):
            result = Q.verify(self.app, self.metadata_path, self.evidence_path)
        self.assertTrue(result['actualGUIloads'])
        self.assertEqual(self.metadata_path.read_bytes(), original)
        subprocess.Popen.assert_not_called()

    def test_mock_approved_run_is_once_initially_false_and_never_overwrites(self):
        def supervise(app, scratch, challenge, architecture):
            initial = json.loads(self.evidence_path.read_text())
            self.assertFalse(initial['actualGUIloads'])
            self.assertFalse(initial['qualified'])
            record, _ = self.execution(scratch)
            return record
        with patch.object(self.legacy, 'supervise', side_effect=supervise) as launch:
            result = Q.run_approved(self.app, self.metadata_path, self.evidence_path)
            self.assertTrue(result['actualGUIloads'])
            launch.assert_called_once()
            with self.assertRaises(FileExistsError):
                Q.run_approved(self.app, self.metadata_path, self.evidence_path)
            launch.assert_called_once()
        self.assertFalse(self.metadata['actualGUIloads'])

    def test_failed_child_or_changed_after_preserves_false_evidence_without_retry(self):
        state = self.freeze()
        changed = copy.deepcopy(state)
        changed['tree_sha256'] = 'changed'
        with patch.object(Q, 'frozen_state', side_effect=[state, changed]):
            with patch.object(self.legacy, 'supervise', return_value=self.execution()[0]) as launch:
                with self.assertRaises(ValueError):
                    Q.run_approved(self.app, self.metadata_path, self.evidence_path)
                launch.assert_called_once()
        result = json.loads(self.evidence_path.read_text())
        self.assertFalse(result['actualGUIloads'])
        self.assertFalse(result['qualified'])
        self.assertIn('failure', result)

    def test_source_loader_hashes_and_executes_same_read_bytes(self):
        source = b'value = 7\n'
        with patch.object(Q, 'read_regular', return_value=source) as read:
            module = Q.pinned_module('fixture.py', Q.digest(source))
            self.assertEqual(module.value, 7)
            read.assert_called_once()
            with self.assertRaises(ValueError):
                Q.pinned_module('fixture.py', '0' * 64)
            with self.assertRaises(ValueError):
                Q.pinned_module('fixture.py', 'TBD_PARENT_REVIEW_REQUIRED')

    def test_packaging_requires_independent_service_provenance(self):
        stage = self.signer.frozen_module.return_value
        gate = MagicMock()
        service = self.root / 'service/Flash.app'
        with patch.object(stage, 'check_layout'), patch.object(stage, 'compatible_pair'), \
                patch.object(stage, 'load_local', return_value=gate):
            stage.verify_release(self.app, service, self.root / 'gui.json', 'a' * 64,
                                 self.root / 'service.json', 'b' * 64)
        gate.verify.assert_called_once_with(self.app, service, self.root / 'gui.json', 'a' * 64,
                                            self.root / 'service.json', 'b' * 64, None, None)

    def test_qualification_rejects_loose_core_even_without_macho_magic(self):
        core = self.app / 'Contents/MacOS/FlClashCore'
        core.parent.mkdir(parents=True)
        core.write_bytes(b'placeholder')
        with self.assertRaisesRegex(ValueError, 'GUI-only split stage'):
            self.freeze()

    def test_old_profile_is_reused_byte_for_byte_and_old_module_unchanged(self):
        old = Q.pinned_module('qualify_native_loads.py', Q.NATIVE_SHA256)
        self.assertEqual(self.legacy.sandbox_profile(self.app, self.root),
                         old.sandbox_profile(self.app, self.root))
        self.assertEqual(Q.digest((Q.PACKAGING / 'qualify_native_loads.py').read_bytes()), Q.NATIVE_SHA256)
        self.assertEqual(set(self.legacy.PROBES),
                         {'flutter_pixel', 'rust_utf8', 'objective_c_string', 'sqlite_memory'})
        self.assertEqual(self.legacy.supervise.__code__.co_code, old.supervise.__code__.co_code)


class BuildProvenanceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.path = self.root / 'continuation-04/build-metadata.json'
        self.fixed = MagicMock()
        original = Q.pinned_module('sign_fixed_payload.py',
                                  '2574d8356c2ac9ad50cb94bc476a11463f6ee8f30d24fab97fbe7432c880771a')
        self.fixed.tree_digest.side_effect = original.tree_digest
        self.fixed.check_signing_delta.side_effect = original.check_signing_delta
        self.fixed.read_regular.side_effect = lambda path: path.read_bytes()
        self.targets = [
            {'role': 'framework', 'binary': f'Contents/Frameworks/{name}.framework/Versions/A/{name}',
             'path': f'Contents/Frameworks/{name}.framework'} for name in Q.FRAMEWORKS] + [
            {'role': 'gui', 'binary': 'Contents/MacOS/Flash', 'path': '.'}]
        self.metadata = {'architectures': ['arm64'], 'macho_count': 6, 'source_head': 'fixture', 'sdk': {},
                         'compile_evidence': {}, 'stage_evidence': {}, 'evidence_continuations': []}
        for key in ('flutter_release_compile_succeeded', 'fresh_core_built', 'fresh_gui_aot_built',
                    'static_stage_audit_passed', 'original_failures_preserved'):
            self.metadata[key] = True
        for key in ('signing_performed', 'production_components_executed', 'rebuild_performed'):
            self.metadata[key] = False
        freeze_hash = self.document('input-freeze.json', {'source_head': 'fixture', 'sdk': {}})
        self.metadata['source_freeze_sha256'] = freeze_hash
        for index in range(1, 5):
            relative = f'continuation-{index:02d}/continuation-provenance.json'
            sha = self.document(relative, {'source_freeze_sha256': freeze_hash}, stage=index == 4)
            self.metadata['evidence_continuations'].append({'path': str(self.root / relative), 'sha256': sha})
        self.inventory = {'.': {'directory': True, 'mode': 0o755},
                          'Contents': {'directory': True, 'mode': 0o755},
                          'link': {'symlink': 'Contents', 'mode': 0o755},
                          'resource': {'bytes': 5, 'mode': 0o644, 'sha256': Q.digest(b'fresh')}}
        self.before = {'Contents': {'kind': 'directory', 'mode': '0o755'},
                       'link': {'kind': 'symlink', 'mode': '0o755', 'target': 'Contents'},
                       'resource': {'kind': 'file', 'mode': '0o644', 'sha256': Q.digest(b'fresh'),
                                    'size': 5, 'macho': False}}
        manifest = {'Contents': {'kind': 'directory', 'mode': 0o755},
                    'link': {'kind': 'link', 'mode': 0o755, 'target': 'Contents'},
                    'resource': {'kind': 'file', 'mode': 0o644, 'sha256': Q.digest(b'fresh')}}
        macho = []
        for target in self.targets:
            relative = target['binary']
            sha = Q.digest(relative.encode())
            self.inventory[relative] = {'bytes': 10, 'mode': 0o755, 'sha256': sha}
            self.before[relative] = {'kind': 'file', 'mode': '0o755', 'sha256': sha, 'size': 10, 'macho': True}
            manifest[relative] = {'kind': 'file', 'mode': 0o755, 'sha256': sha}
            macho.append({'path': relative, 'sha256': sha, 'architectures': ['arm64']})
        for name, value in (('stage-inventory-after-audit.json', self.inventory),
                            ('candidate-file-manifest.json', manifest), ('macho-inventory.json', macho)):
            self.document('continuation-03/' + name, value)
            self.document('continuation-04/' + name, value, stage=True)
        self.report = {'before': {'tree_sha256': original.tree_digest(self.before), 'entries': self.before},
                       'after': {'entries': copy.deepcopy(self.before)}}
        for target in self.targets:
            self.report['after']['entries'][target['binary']]['sha256'] = Q.digest(b'signed')
        self.path.write_text(json.dumps(self.metadata))
        self.metadata_hash = Q.digest(self.path.read_bytes())
        for name, value in (('BUILD_ROOT', self.root), ('BUILD_METADATA', self.path),
                            ('BUILD_METADATA_SHA256', self.metadata_hash)):
            replacement = patch.object(Q, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)

    def document(self, relative, value, stage=False):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))
        sha = Q.digest(path.read_bytes())
        self.metadata['stage_evidence' if stage else 'compile_evidence'][
            path.name if stage else relative] = sha
        return sha

    def verify(self):
        return Q.build_provenance(self.path, self.metadata, self.metadata_hash, self.report,
                                  self.targets, self.fixed)

    def test_binds_original_freeze_four_continuations_and_exact_unsigned_signing_input(self):
        original = self.path.read_bytes()
        proof = self.verify()
        self.assertEqual(proof['source_freeze_sha256'], self.metadata['source_freeze_sha256'])
        self.assertEqual(proof['unsigned_tree_sha256'], self.report['before']['tree_sha256'])
        self.fixed.check_signing_delta.assert_called_once()
        self.assertEqual(self.path.read_bytes(), original)

    def test_preserved_failed_json_capture_is_hashed_without_reinterpreting_failure(self):
        path = self.root / 'effective-xcode-settings.json'
        path.write_bytes(b'preserved stderr warning\n{"settings": []}')
        self.metadata['compile_evidence'][path.name] = Q.digest(path.read_bytes())
        self.verify()
        self.assertTrue(path.read_bytes().startswith(b'preserved stderr warning'))

    def test_rejects_old_metadata_and_nonpristine_retry(self):
        with self.assertRaisesRegex(ValueError, 'continuation-04'):
            Q.build_provenance(self.root / 'continuation-03/build-metadata.json', self.metadata,
                               self.metadata_hash, self.report, self.targets, self.fixed)
        changed = copy.deepcopy(self.inventory)
        changed['resource']['sha256'] = Q.digest(b'different')
        self.document('continuation-04/stage-inventory-after-audit.json', changed, stage=True)
        with self.assertRaisesRegex(ValueError, 'Pristine retry differs'):
            self.verify()

    def test_rejects_replaced_metadata_or_preserved_evidence(self):
        with self.assertRaises(ValueError):
            Q.build_provenance(self.path, self.metadata, '0' * 64, self.report, self.targets, self.fixed)
        (self.root / 'input-freeze.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'evidence changed'):
            self.verify()

    def test_rejects_same_label_but_different_unsigned_code_or_resource_delta(self):
        self.report['before']['entries'] = copy.deepcopy(self.before)
        self.report['before']['entries']['Contents/MacOS/Flash']['sha256'] = Q.digest(b'old GUI')
        with self.assertRaisesRegex(ValueError, 'exact frozen fresh unsigned GUI'):
            self.verify()
        self.report['before']['entries'] = self.before
        self.report['after']['entries']['resource']['sha256'] = Q.digest(b'changed')
        with self.assertRaisesRegex(ValueError, 'Non-signature payload mutation'):
            self.verify()

    def test_rejects_missing_continuation_or_wrong_original_freeze(self):
        original = copy.deepcopy(self.metadata['evidence_continuations'])
        self.metadata['evidence_continuations'].pop()
        with self.assertRaisesRegex(ValueError, 'four preserved'):
            self.verify()
        self.metadata['evidence_continuations'] = original
        self.metadata['source_freeze_sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'source/SDK freeze'):
            self.verify()

    def test_rejects_escaping_evidence_and_rebuilt_or_executed_components(self):
        self.metadata['production_components_executed'] = True
        with self.assertRaises(ValueError):
            self.verify()
        self.metadata['production_components_executed'] = False
        self.metadata['compile_evidence']['../outside.json'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'Noncanonical'):
            self.verify()


class PreservedCaptureReaderTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.worktree = Path(temporary.name).resolve()
        self.root = self.worktree / '.airbuild/buildcandidate/split'
        self.root.mkdir(parents=True)
        for node in (self.root, *self.root.parents):
            if node == self.worktree or node.is_relative_to(self.worktree):
                node.chmod(0o750)
        root_patch = patch.object(Q, 'ROOT', self.worktree)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        replacement = patch.object(Q, 'BUILD_ROOT', self.root)
        replacement.start()
        self.addCleanup(replacement.stop)
        self.fixed = MagicMock()
        self.fixed.read_regular.side_effect = Q.read_regular
        self.data = b'original preserved capture\n'
        self.sha = Q.digest(self.data)

    def capture(self, relative='continuation-01/FlashFlutterEngine-object-disassembly.txt', mode=0o660):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        for node in path.parents:
            if node.is_relative_to(self.root):
                relative = str(node.relative_to(self.root))
                node.chmod(0o770 if relative in Q.PRESERVED_CAPTURE_DIRECTORIES else 0o750)
        path.write_bytes(self.data)
        path.chmod(mode)
        return path

    def test_exact_seventeen_regular_capture_modes_are_preserved(self):
        self.assertEqual(len(Q.PRESERVED_CAPTURE_MODES), 17)
        self.assertEqual(set(Q.PRESERVED_CAPTURE_MODES.values()), {0o660})
        for relative, mode in Q.PRESERVED_CAPTURE_MODES.items():
            path = self.capture(relative, mode)
            before = path.stat()
            self.assertEqual(Q.read_build_evidence(path, self.sha, self.fixed), self.data)
            after = path.stat()
            self.assertEqual((before.st_ino, before.st_mode, before.st_mtime_ns, before.st_ctime_ns),
                             (after.st_ino, after.st_mode, after.st_mtime_ns, after.st_ctime_ns))
        self.fixed.read_regular.assert_not_called()

    def log_alias(self):
        target = self.capture('flutter-build.log', 0o644)
        alias = self.root / Q.PRESERVED_LOG_ALIAS
        alias.parent.mkdir(mode=0o770, exist_ok=True)
        alias.parent.chmod(0o770)
        alias.symlink_to(target)
        os.lchmod(alias, 0o770)
        return alias, target

    def test_only_exact_original_log_alias_reads_strict_canonical_target(self):
        alias, target = self.log_alias()
        before = alias.lstat()
        self.assertEqual(Q.read_build_evidence(alias, self.sha, self.fixed), self.data)
        self.assertEqual(before, alias.lstat())
        self.assertEqual(os.readlink(alias), str(target))
        self.fixed.read_regular.assert_called_once_with(target)
        with self.assertRaisesRegex(ValueError, 'evidence changed'):
            Q.read_build_evidence(alias, '0' * 64, self.fixed)
        target.chmod(0o660)
        with self.assertRaises(ValueError):
            Q.read_build_evidence(alias, self.sha, self.fixed)

    def test_alias_rejects_relative_outside_chain_and_wrong_mode(self):
        alias, target = self.log_alias()
        for destination in ('../flutter-build.log', str(self.worktree / 'outside')):
            alias.unlink()
            alias.symlink_to(destination)
            os.lchmod(alias, 0o770)
            with self.assertRaisesRegex(ValueError, 'Unexpected preserved log alias'):
                Q.read_build_evidence(alias, self.sha, self.fixed)
        alias.unlink()
        alias.symlink_to(target)
        os.lchmod(alias, 0o750)
        with self.assertRaisesRegex(ValueError, 'Unexpected preserved log alias'):
            Q.read_build_evidence(alias, self.sha, self.fixed)
        os.lchmod(alias, 0o770)
        other = self.capture('other.log', 0o644)
        target.unlink()
        target.symlink_to(other)
        with self.assertRaisesRegex(ValueError, 'Unexpected preserved log alias'):
            Q.read_build_evidence(alias, self.sha, self.fixed)

    def test_acl_boundary_includes_airbuild_and_excludes_external_guard_ancestors(self):
        path = self.capture()
        Q.read_build_evidence(path, self.sha, self.fixed)
        checked = [call.args[0] for call in self.fixed.require_no_acl.call_args_list]
        self.assertIn(self.worktree / '.airbuild', checked)
        self.assertNotIn(self.worktree, checked)
        for ancestor in path.parents:
            if ancestor.is_relative_to(self.worktree / '.airbuild'):
                self.assertIn(ancestor, checked)
        self.fixed.require_no_acl.side_effect = lambda node: (_ for _ in ()).throw(
            ValueError('ACL rejected')) if node == self.worktree / '.airbuild' else None
        with self.assertRaisesRegex(ValueError, 'ACL rejected'):
            Q.read_build_evidence(path, self.sha, self.fixed)

    def test_group_world_write_or_special_ancestor_modes_fail(self):
        path = self.capture()
        for mode in (0o770, 0o752, 0o1750, 0o2750, 0o4750):
            self.root.chmod(mode)
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'Unsafe preserved capture ancestor'):
                Q.read_build_evidence(path, self.sha, self.fixed)

    def test_five_historical_directories_require_exact_mode_and_no_acl(self):
        self.assertEqual(Q.PRESERVED_CAPTURE_DIRECTORIES, {
            'continuation-01', 'continuation-01/xcode-Logs',
            'continuation-01/xcode-Logs/Build', 'continuation-01/xcode-Logs/Package',
            'continuation-02'})
        for relative in Q.PRESERVED_CAPTURE_MODES:
            path = self.capture(relative)
            self.assertEqual(Q.read_build_evidence(path, self.sha, self.fixed), self.data)
        path = self.capture()
        for mode in (0o750, 0o772, 0o1770, 0o2770, 0o4770):
            path.parent.chmod(mode)
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'Unsafe preserved capture ancestor'):
                Q.read_build_evidence(path, self.sha, self.fixed)
        path.parent.chmod(0o770)
        self.fixed.require_no_acl.side_effect = lambda node: (_ for _ in ()).throw(
            ValueError('ACL rejected')) if node == path.parent else None
        with self.assertRaisesRegex(ValueError, 'ACL rejected'):
            Q.read_build_evidence(path, self.sha, self.fixed)

    def test_modified_content_unexpected_path_and_unexpected_modes_fail(self):
        path = self.capture()
        with self.assertRaisesRegex(ValueError, 'evidence changed'):
            Q.read_build_evidence(path, '0' * 64, self.fixed)
        for mode in (0o600, 0o664, 0o666, 0o1660, 0o2660, 0o4660):
            path.chmod(mode)
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'identity/mode'):
                Q.read_build_evidence(path, self.sha, self.fixed)
        unexpected = self.capture('continuation-04/unreviewed.log')
        with self.assertRaises(ValueError):
            Q.read_build_evidence(unexpected, self.sha, self.fixed)

    def test_symlink_hardlink_ancestor_link_and_acl_fail(self):
        path = self.capture()
        other = self.root / 'other'
        os.link(path, other)
        with self.assertRaisesRegex(ValueError, 'identity/mode'):
            Q.read_build_evidence(path, self.sha, self.fixed)
        other.unlink()
        path.rename(other)
        path.symlink_to(other)
        with self.assertRaisesRegex(ValueError, 'noncanonical'):
            Q.read_build_evidence(path, self.sha, self.fixed)
        path.unlink()
        other.rename(path)
        actual = self.root / 'actual'
        path.parent.rename(actual)
        path.parent.symlink_to(actual, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'noncanonical'):
            Q.read_build_evidence(path, self.sha, self.fixed)
        path.parent.unlink()
        actual.rename(path.parent)
        self.fixed.require_no_acl.side_effect = ValueError('ACL rejected')
        with self.assertRaisesRegex(ValueError, 'ACL rejected'):
            Q.read_build_evidence(path, self.sha, self.fixed)

    def test_descriptor_metadata_change_is_rejected(self):
        path = self.capture()
        real_fstat = os.fstat
        calls = 0
        def changing_fstat(descriptor):
            nonlocal calls
            calls += 1
            value = real_fstat(descriptor)
            if calls == 2:
                changed = types.SimpleNamespace(**{key: getattr(value, key) for key in dir(value)
                                                   if key.startswith('st_')})
                changed.st_size += 1
                return changed
            return value
        with patch.object(Q.os, 'fstat', side_effect=changing_fstat):
            with self.assertRaisesRegex(ValueError, 'changed while reading'):
                Q.read_build_evidence(path, self.sha, self.fixed)

    def test_final_path_replacement_is_rejected_even_with_identical_bytes(self):
        path = self.capture()
        visits = 0
        def check_acl(node):
            nonlocal visits
            if node == path:
                visits += 1
                if visits == 2:
                    path.rename(path.with_suffix('.old'))
                    path.write_bytes(self.data)
                    path.chmod(0o660)
        self.fixed.require_no_acl.side_effect = check_acl
        with self.assertRaisesRegex(ValueError, 'path identity changed'):
            Q.read_build_evidence(path, self.sha, self.fixed)

    def test_source_metadata_and_nonallowlisted_readers_remain_strict(self):
        for relative in ('qualify_native_loads.py', 'continuation-03/build-metadata.json'):
            path = self.capture(relative)
            with self.assertRaises(ValueError):
                Q.read_regular(path)
            with self.assertRaises(ValueError):
                Q.read_build_evidence(path, self.sha, self.fixed)


if __name__ == '__main__':
    unittest.main()
