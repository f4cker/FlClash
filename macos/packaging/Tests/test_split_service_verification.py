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

    def test_historical_v1_requires_its_own_entries_and_completion_fields(self):
        compiled = {'schema': 'flash-1305-service-compile-v1', 'completed': True,
                    'compile_completed': True, 'staging_completed': True,
                    'entries': self.entries, 'core_sha256': self.core_hash,
                    'outputs': {role: {'sha256': self.entries[binary]['sha256']}
                                for role, binary in GATE.BINARIES.items()}}
        path = self.root / 'historical-v1.json'
        pin = self.save(path, compiled)
        self.assertEqual(GATE.verify_historical_compile_receipt(path, pin, self.receipt), compiled)
        for key in ('completed', 'compile_completed', 'staging_completed', 'entries'):
            invalid = copy.deepcopy(compiled)
            del invalid[key]
            invalid['staged_unsigned_entries'] = self.entries
            pin = self.save(path, invalid)
            with self.subTest(missing=key), self.assertRaises(ValueError):
                GATE.verify_historical_compile_receipt(path, pin, self.receipt)

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

    def test_wrapper_signing_scope_allows_only_outer_signature_delta(self):
        self.receipt['signing_scope'] = 'service-wrapper-only'
        self.receipt['wrapper_derivation'] = {'path': str(self.root / 'derivation.json'), 'sha256': 'a' * 64}
        with patch.object(GATE, 'verify_wrapper_derivation') as verify_derivation:
            self.verify()
        self.assertEqual([target['role'] for target in self.fixed.check_signing_delta.call_args.args[2]], ['service'])
        verify_derivation.assert_called_once_with(self.root / 'derivation.json', 'a' * 64, self.app,
            self.signer, self.stage, unsigned_entries=self.receipt['before']['entries'])
        self.receipt['signing_scope'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'Unknown signing scope'):
            self.verify()

    def test_gui_receipt_binds_accepted_service_core_without_reading_absent_gui_core(self):
        (self.app / GATE.CORE).unlink()
        self.compatibility = {'CallerPolicy': 2, 'ServiceAPI': 1, 'CoreAPI': 1,
                              'AcceptedCoreSHA256': [self.core_hash]}
        self.stage.read_compatibility.return_value = self.compatibility
        self.receipt.update(phase='gui', compatibility=self.compatibility, accepted_service_core_sha256=self.core_hash)
        del self.receipt['reused_signed_core_sha256']
        self.targets = []
        self.receipt['targets'] = []
        pin = self.save(self.receipt_path, self.receipt)
        GATE.verify_bundle(self.app, 'gui', self.receipt_path, pin, self.signer, self.stage)
        self.receipt['accepted_service_core_sha256'] = '0' * 64
        pin = self.save(self.receipt_path, self.receipt)
        with self.assertRaisesRegex(ValueError, 'artifact/compatibility'):
            GATE.verify_bundle(self.app, 'gui', self.receipt_path, pin, self.signer, self.stage)
        self.receipt['accepted_service_core_sha256'] = self.core_hash
        self.receipt['reused_signed_core_sha256'] = self.core_hash
        pin = self.save(self.receipt_path, self.receipt)
        with self.assertRaisesRegex(ValueError, 'artifact/compatibility'):
            GATE.verify_bundle(self.app, 'gui', self.receipt_path, pin, self.signer, self.stage)

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


class WrapperDerivationTests(unittest.TestCase):
    def setUp(self):
        fixture_spec = importlib.util.spec_from_file_location('wrapper_fixtures', Path(__file__).with_name('test_split_payload.py'))
        fixtures = importlib.util.module_from_spec(fixture_spec)
        fixture_spec.loader.exec_module(fixtures)
        self.fixture = fixtures.SplitPayloadTests('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.stage_pair()
        self.stage = fixtures.SPLIT
        self.source, self.gui, self.root = self.fixture.service, self.fixture.gui, self.fixture.root
        icon = self.source / self.stage.ICON
        icon.unlink()
        icon.parent.rmdir()
        info_path = self.source / 'Contents/Info.plist'
        info = GATE.plistlib.loads(info_path.read_bytes())
        del info['CFBundleIconFile']
        info['CFBundleVersion'] = '2026111402'
        info_path.write_bytes(GATE.plistlib.dumps(info))
        self.fixture.write(self.source / 'Contents/_CodeSignature/CodeResources', b'old-outer-seal')
        self.destination = self.root / 'wrapper/Flash.app'
        self.source_receipt = self.root / 'source-receipt.json'
        self.source_receipt.write_text('{}')
        self.source_pin = GATE.digest(self.source_receipt.read_bytes())
        self.source_entries = self.stage.inventory(self.source)
        self.signed = {'before': {'entries': self.source_entries},
                       'reused_signed_core_sha256': self.fixture.core_sha256}
        compiled = {'schema': 'flash-stable-service-compile-v2', 'completed': True,
                    'staged_unsigned_entries': self.source_entries, 'core_sha256': self.fixture.core_sha256,
                    'outputs': {role: {'sha256': self.source_entries[name]['sha256']}
                                for role, name in GATE.BINARIES.items()}}
        self.compiled = self.root / 'historical-compile.json'
        self.compiled.write_text(json.dumps(compiled))
        self.compile_pin = GATE.digest(self.compiled.read_bytes())
        self.signer = object()
        self.source_gate = patch.object(GATE, 'verify_bundle', return_value=self.signed).start()
        patch.object(GATE, 'WRAPPER_SOURCE_RECEIPT_SHA256', self.source_pin).start()
        patch.object(GATE, 'WRAPPER_CORE_SHA256', self.fixture.core_sha256).start()
        original_loader = self.stage.load_local
        def load(name):
            if name == 'verify_split_service': return GATE
            if name == 'sign_split_payload': return self.signer
            if name == 'stage_split_payload': return self.stage
            return original_loader(name)
        patch.object(self.stage, 'load_local', side_effect=load).start()
        self.addCleanup(patch.stopall)
        self.receipt = self.root / 'derivation.json'

    def derive(self):
        return self.stage.derive_service_wrapper(self.source, self.gui, self.destination,
            source_receipt=self.source_receipt, source_receipt_sha256=self.source_pin,
            source_compile_receipt=self.compiled, source_compile_sha256=self.compile_pin)

    def verify(self, data, **kwargs):
        self.receipt.write_text(json.dumps(data))
        return GATE.verify_wrapper_derivation(self.receipt, GATE.digest(self.receipt.read_bytes()),
                                              self.destination, self.signer, self.stage, **kwargs)

    def test_derivation_changes_only_icon_metadata_and_removes_outer_seal(self):
        data = self.derive()
        self.assertEqual(self.verify(data), data)
        self.assertEqual(self.stage.inventory(self.source), self.source_entries)
        self.assertIs(data['compiled'], False)
        self.assertEqual(data['helper_binary_build'], '2026111402')
        self.assertEqual(data['service_wrapper_build'], '2026111408')
        self.assertFalse((self.destination / 'Contents/_CodeSignature').exists())
        for name in data['preserved_code_sha256']:
            self.assertEqual((self.source / name).read_bytes(), (self.destination / name).read_bytes())
        fixed_entries = {name: dict(entry, mode=oct(entry['mode'])) for name, entry in data['unsigned_entries'].items()}
        self.assertEqual(self.verify(data, unsigned_entries=fixed_entries), data)
        self.source_gate.assert_called_with(self.source, 'service', self.source_receipt, self.source_pin,
                                            self.signer, self.stage)

    def test_derivation_rejects_unapproved_metadata_resources_or_code(self):
        data = self.derive()
        for name in (self.stage.CORE, self.stage.HELPER, self.stage.MAINTENANCE, 'Contents/MacOS/Flash', 'Contents/Info.plist'):
            path = self.destination / name
            original = path.read_bytes()
            if name == 'Contents/Info.plist':
                info = GATE.plistlib.loads(original)
                info['CFBundleName'] = 'Unapproved'
                path.write_bytes(GATE.plistlib.dumps(info))
            else:
                path.write_bytes(original + b'changed')
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(data)
            path.write_bytes(original)
        self.fixture.write(self.destination / 'Contents/Resources/extra', b'extra')
        with self.assertRaisesRegex(ValueError, 'extra files'):
            self.verify(data)

    def test_fabricated_compile_delta_or_preserved_hash_is_rejected(self):
        data = self.derive()
        for key, value in (('compiled', True), ('service_wrapper_build', '2026111409'),
                           ('source_receipt_sha256', '0' * 64), ('metadata_delta', {}),
                           ('preserved_code_sha256', {}), ('gui_icon_sha256', '0' * 64),
                           ('unsigned_entries', {})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.verify(dict(data, **{key: value}))
        self.compiled.write_bytes(self.compiled.read_bytes() + b' ')
        with self.assertRaisesRegex(ValueError, 'Pinned receipt changed'):
            self.verify(data)

    def test_new_output_and_original_release_pin_are_required(self):
        self.derive()
        with self.assertRaisesRegex(ValueError, 'never overlay'):
            self.derive()
        self.source_pin = '0' * 64
        with self.assertRaisesRegex(ValueError, 'exact released iconless'):
            self.derive()


class PreservedHistoricalCompileReceiptTests(unittest.TestCase):
    evidence = Path(__file__).parents[3] / '.airbuild/stable-helper-3332'
    compile_path = evidence / 'service-compile/receipt.json'
    source_path = evidence / 'current-static-verification/service-current-schema.json'
    compile_pin = 'bdd93c859d94c4e8a50a457251175d937ab118c160bd0925d20ac81f8e58890b'

    def setUp(self):
        if not self.compile_path.exists() or not self.source_path.exists():
            self.skipTest('Preserved private historical receipts not present')
        self.signed = GATE.pinned_json(self.source_path, GATE.WRAPPER_SOURCE_RECEIPT_SHA256)
        self.compiled = GATE.pinned_json(self.compile_path, self.compile_pin)

    def test_real_receipts_are_read_only_and_provenance_matches(self):
        self.assertEqual(self.compiled['schema'], 'flash-1305-service-compile-v1')
        self.assertEqual(GATE.verify_historical_compile_receipt(
            self.compile_path, self.compile_pin, self.signed), self.compiled)
        self.assertEqual(GATE.digest(self.compile_path.read_bytes()), self.compile_pin)
        self.assertEqual(GATE.digest(self.source_path.read_bytes()), GATE.WRAPPER_SOURCE_RECEIPT_SHA256)
        with self.assertRaises(ValueError):
            GATE.verify_historical_compile_receipt(self.compile_path, '0' * 64, self.signed)

    def test_real_receipt_mutations_cannot_bypass_provenance(self):
        mutations = [
            ('schema', 'flash-unknown-service-compile-v1'),
            ('schema', 'flash-stable-service-compile-v2'),
            ('completed', False), ('compile_completed', False), ('staging_completed', False),
            ('entries', {}), ('core_sha256', '0' * 64), ('outputs', {}),
        ]
        outputs = copy.deepcopy(self.compiled['outputs'])
        outputs['helper']['sha256'] = '0' * 64
        mutations.append(('outputs', outputs))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'mutated-copy.json'
            for key, value in mutations:
                invalid = copy.deepcopy(self.compiled)
                invalid[key] = value
                path.write_text(json.dumps(invalid, sort_keys=True))
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    GATE.verify_historical_compile_receipt(path, GATE.digest(path.read_bytes()), self.signed)
        self.assertEqual(GATE.digest(self.compile_path.read_bytes()), self.compile_pin)
        self.assertEqual(GATE.digest(self.source_path.read_bytes()), GATE.WRAPPER_SOURCE_RECEIPT_SHA256)


if __name__ == '__main__':
    unittest.main()
