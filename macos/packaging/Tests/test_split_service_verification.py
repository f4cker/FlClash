import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location('service_gate', Path(__file__).parents[1] / 'verify_split_service.py')
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class ServiceGateTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.app = self.root / 'service/Flash.app'
        core = self.app / GATE.CORE
        core.parent.mkdir(parents=True)
        core.write_bytes(b'released-signed-core-never-executed')
        self.core_hash = GATE.digest(core.read_bytes())
        self.entries = {GATE.CORE: {'sha256': self.core_hash}}
        self.targets = [{'role': 'core', 'path': GATE.CORE, 'binary': GATE.CORE}]
        for role, binary in GATE.BINARIES.items():
            target = self.app / binary
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(role.encode())
            self.entries[binary] = {'sha256': GATE.digest(target.read_bytes())}
            self.targets.append({'role': 'service' if role == 'stub' else role, 'path': binary, 'binary': binary})
        self.compatibility = {'CallerPolicy': 2, 'ServiceAPI': 1, 'CoreAPI': 1,
                              'CoreSHA256': self.core_hash, 'CoreVersion': 'test-1', 'CoreRevision': 'revision'}
        tree = lambda entries: GATE.digest(json.dumps(entries, sort_keys=True).encode())
        self.fixed = types.SimpleNamespace(inventory=Mock(return_value=self.entries),
            tree_digest=tree, trusted_verifier=lambda: object(), read_regular=lambda path: path.read_bytes(),
            verify_target=Mock(return_value={'arm64': 'verified'}), check_signing_delta=Mock(), run_tool=Mock())
        self.constraint = types.SimpleNamespace(inspect_slice=Mock(), cdhash=lambda data: bytes.fromhex('cd'))
        self.signer = types.SimpleNamespace(dependencies=lambda: (self.fixed, self.constraint),
            CERTIFICATE_SHA1='same-cert-1', CERTIFICATE_SHA256='same-cert-256',
            signing_targets=lambda *args: copy.deepcopy(self.targets), audit=Mock())
        self.stage = types.SimpleNamespace(check_layout=Mock(), read_compatibility=Mock(return_value=self.compatibility))
        self.receipt = {'schema': 1, 'phase': 'service', 'app': str(self.app), 'static_verification': True,
                        'pins': {'certificate_sha1': 'same-cert-1', 'certificate_sha256': 'same-cert-256'},
                        'compatibility': self.compatibility, 'reused_signed_core_sha256': self.core_hash,
                        'before': {'entries': self.entries, 'tree_sha256': tree(self.entries)},
                        'after': {'entries': self.entries, 'tree_sha256': tree(self.entries)},
                        'targets': [dict(target, verified_slices={'arm64': 'verified'}, cdhash='cd') for target in self.targets]}
        self.receipt_path = self.root / 'service-signing.json'

    def save(self, path, data):
        path.write_text(json.dumps(data, sort_keys=True))
        return GATE.digest(path.read_bytes())

    def verify(self):
        pin = self.save(self.receipt_path, self.receipt)
        return GATE.verify_bundle(self.app, 'service', self.receipt_path, pin, self.signer, self.stage)

    def test_static_gate_verifies_four_signatures_without_gui_pin(self):
        self.verify()
        self.assertEqual(self.fixed.verify_target.call_count, 4)
        self.assertNotIn('core', [target['role'] for target in self.fixed.check_signing_delta.call_args.args[2]])
        self.assertIn('--strict', self.fixed.run_tool.call_args.args[0])
        self.assertNotIn('--sign', self.fixed.run_tool.call_args.args[0])
        self.assertNotIn('gui_cdhash', self.receipt)

    def test_receipt_identity_compatibility_core_or_artifact_changes_fail(self):
        for key, value in [('pins', {}), ('compatibility', {}), ('static_verification', False),
                           ('app', '/other/Flash.app'), ('reused_signed_core_sha256', '0' * 64), ('after', {})]:
            original = self.receipt[key]
            self.receipt[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.verify()
            self.receipt[key] = original
        self.fixed.verify_target.assert_not_called()

    def test_signature_or_delta_failure_is_fatal(self):
        self.fixed.verify_target.side_effect = ValueError('invalid signature')
        with self.assertRaisesRegex(ValueError, 'invalid signature'):
            self.verify()
        self.fixed.verify_target.side_effect = None
        self.fixed.check_signing_delta.side_effect = ValueError('illegal mutation')
        with self.assertRaisesRegex(ValueError, 'illegal mutation'):
            self.verify()

    def test_receipt_pin_required_and_changed_bytes_rejected(self):
        pin = self.save(self.receipt_path, self.receipt)
        for bad in (None, 'TBD', '0' * 64):
            with self.assertRaises(ValueError):
                GATE.pinned_json(self.receipt_path, bad)
        self.receipt_path.write_bytes(self.receipt_path.read_bytes() + b'\n')
        with self.assertRaises(ValueError):
            GATE.pinned_json(self.receipt_path, pin)

    def test_helper_compilation_has_no_gui_hash_argument_or_macro(self):
        for role in GATE.BINARIES:
            argv = GATE.compile_argv(role, '/compiler', '/sdk', self.root / role)
            self.assertNotIn('FC_SPLIT_GUI_CDHASH', ' '.join(argv))
            self.assertIn('-mmacosx-version-min=14.0', argv)
            self.assertEqual(argv[-2:], ['-o', str(self.root / role)])

    def test_gui_only_releases_use_same_service_receipt_without_recompilation(self):
        before = {p: p.read_bytes() for p in self.app.rglob('*') if p.is_file()}
        self.stage.compatible_pair = Mock(return_value=self.compatibility)
        signed_gui = {'targets': [{'cdhash': 'first-gui'}]}
        signed_service = {'targets': [{'cdhash': 'unchanged-service'}]}
        with patch.object(GATE, 'module', side_effect=lambda name: self.signer if name == 'sign_split_payload' else self.stage), \
                patch.object(GATE, 'verify_bundle', side_effect=lambda app, role, *args: signed_gui if role == 'gui' else signed_service), \
                patch.object(GATE, 'verify_compile_receipt', side_effect=AssertionError('No helper compile for GUI-only')):
            for gui_hash in ('first-gui', 'second-gui'):
                signed_gui['targets'][0]['cdhash'] = gui_hash
                result = GATE.verify(self.root / gui_hash, self.app, self.root / 'gui.json', 'a' * 64,
                                     self.receipt_path, 'b' * 64)
                self.assertEqual(result['delivery_mode'], 'gui-only')
                self.assertEqual(result['gui_cdhash'], gui_hash)
                self.assertEqual(result['service_cdhash'], 'unchanged-service')
                self.assertEqual(result['functional_acceptance'], 'UNTESTED')
                self.assertEqual({p: p.read_bytes() for p in self.app.rglob('*') if p.is_file()}, before)

    def test_legacy_or_incompatible_service_cannot_pass_as_gui_only(self):
        self.stage.compatible_pair = Mock(side_effect=ValueError('legacy or incompatible'))
        with patch.object(GATE, 'module', side_effect=lambda name: self.signer if name == 'sign_split_payload' else self.stage), \
                patch.object(GATE, 'verify_bundle', return_value={'targets': [{'cdhash': 'signed'}]}):
            with self.assertRaisesRegex(ValueError, 'legacy or incompatible'):
                GATE.verify(self.root / 'gui', self.app, self.root / 'gui.json', 'a' * 64,
                            self.receipt_path, 'b' * 64)

    def test_migration_compile_receipt_binds_sources_commands_and_unsigned_bytes(self):
        source_record = {'sha256': 'a' * 64, 'bytes': 1, 'mode': 0o644}
        sources = {name: source_record for group in GATE.SOURCES.values() for name in group}
        outputs, commands = {}, []
        for role, binary in GATE.BINARIES.items():
            output = self.app / binary
            argv = GATE.compile_argv(role, '/compiler', '/sdk', output)
            outputs[role] = {'path': str(output), **GATE.record(output), 'clang_argv': argv}
            commands.append({'argv': GATE.SANDBOX + argv, 'returncode': 0})
        compiled = {'schema': 'flash-stable-service-compile-v2', 'completed': True,
                    'staged_unsigned_entries': self.entries, 'core_sha256': self.core_hash,
                    'source_inputs': sources, 'outputs': outputs, 'commands': commands,
                    'toolchain': {'compiler': '/compiler', 'sdk': '/sdk'}}
        path = self.root / 'compile.json'
        original_read, original_record = GATE.read, GATE.record
        with patch.object(GATE, 'read', side_effect=lambda p: b'' if p.is_relative_to(GATE.ROOT) else original_read(p)), \
                patch.object(GATE, 'record', side_effect=lambda p: source_record if p.is_relative_to(GATE.ROOT) else original_record(p)):
            pin = self.save(path, compiled)
            self.assertEqual(GATE.verify_compile_receipt(path, pin, self.receipt), compiled)
            outputs['helper']['clang_argv'].append('-DFC_SPLIT_GUI_CDHASH="old-gui"')
            pin = self.save(path, compiled)
            with self.assertRaisesRegex(ValueError, 'Compiler output/argv'):
                GATE.verify_compile_receipt(path, pin, self.receipt)
            outputs['helper']['clang_argv'].pop()
            sources[next(iter(sources))] = {'sha256': 'wrong'}
            pin = self.save(path, compiled)
            with self.assertRaisesRegex(ValueError, 'Service source'):
                GATE.verify_compile_receipt(path, pin, self.receipt)

    def test_compile_receipt_requires_new_schema_exact_inputs_and_core(self):
        path = self.root / 'compile.json'
        for value in ({}, {'schema': 'flash-split-service-compile-v1', 'completed': True},
                      {'schema': 'flash-stable-service-compile-v2', 'completed': True,
                       'staged_unsigned_entries': self.entries, 'core_sha256': '0' * 64}):
            pin = self.save(path, value)
            with self.assertRaisesRegex(ValueError, 'Compiler provenance'):
                GATE.verify_compile_receipt(path, pin, self.receipt)


if __name__ == '__main__':
    unittest.main()
