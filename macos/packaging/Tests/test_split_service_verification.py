import copy
import importlib.util
import json
from pathlib import Path
import plistlib
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
        for name, path in {'ROOT': self.root, 'PACKAGING': self.root / 'macos/packaging',
                           'GUI': self.root / 'gui/Flash.app', 'SERVICE': self.root / 'service/Flash.app',
                           'WORK': self.root / 'compile', 'METADATA': self.root / 'metadata.json',
                           'EVIDENCE': self.root / 'evidence.json', 'DELTA': self.root / 'delta.json'}.items():
            self.patch(name, path)
        self.patch('read', lambda path: path.read_bytes())

    def patch(self, name, value):
        replacement = patch.object(GATE, name, value)
        replacement.start()
        self.addCleanup(replacement.stop)
        return value

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(0o600)

    def save(self, path, data):
        self.write(path, json.dumps(data, sort_keys=True).encode())
        return GATE.digest(path.read_bytes())

    def fixture(self):
        self.write(GATE.GUI / GATE.CORE, b'exact signed core')
        self.write(GATE.SERVICE / GATE.CORE, b'exact signed core')
        self.write(GATE.SERVICE / 'Contents/Info.plist', plistlib.dumps({'LSMinimumSystemVersion': '14.0'}))
        before = {GATE.CORE: {'sha256': GATE.digest(b'exact signed core')}}
        outputs, commands = {}, []
        for role, binary in GATE.BINARIES.items():
            path = GATE.WORK / role
            self.write(path, ('unsigned-' + role).encode())
            self.write(GATE.SERVICE / binary, ('signed-' + role).encode())
            before[binary] = {'sha256': GATE.record(path)['sha256']}
            argv = GATE.compile_argv(role, '/compiler', '/sdk', GATE.GUI_CDHASH, path)
            outputs[role] = {'path': str(path), **GATE.record(path), 'clang_argv': argv}
            commands.append({'argv': GATE.SANDBOX + argv, 'returncode': 0})
        after = copy.deepcopy(before)
        for binary in GATE.BINARIES.values():
            after[binary]['sha256'] = GATE.digest((GATE.SERVICE / binary).read_bytes())
        self.sources = {'native.c': {'sha256': 'frozen'}}
        self.delta = {'files': {GATE.COMPILER_DRIVER: {'after': {'sha256': 'compiler-driver'}},
                               'macos/packaging/stage_split_payload.py': {'after': {'sha256': 'stage'}}}}
        self.delta_hash = 'd' * 64
        self.compiled = {'schema': 'flash-split-service-compile-v1', 'completed': True,
                         'driver_sha256': 'compiler-driver', 'signer_sha256': GATE.SIGNER_SHA256,
                         'tooling_delta_sha256': self.delta_hash, 'gui_report_sha256': GATE.GUI_REPORT_SHA256,
                         'gui_cdhash': GATE.GUI_CDHASH, 'gui_signed_tree_sha256': GATE.GUI_TREE,
                         'qualification_sha256': GATE.EVIDENCE_SHA256, 'build_metadata_sha256': GATE.METADATA_SHA256,
                         'source_freeze_sha256': GATE.FREEZE_SHA256, 'source_inputs': self.sources,
                         'native_qualification': False, 'installation_accepted': False,
                         'staged_unsigned_entries': before, 'outputs': outputs,
                         'toolchain': {'compiler': '/compiler', 'sdk': '/sdk'}, 'commands': commands,
                         'gui_signed_core_sha256': before[GATE.CORE]['sha256']}
        self.targets = [{'role': role, 'binary': binary, 'path': binary} for role, binary in
                        [('core', GATE.CORE), *GATE.BINARIES.items()]]
        self.targets[-1]['role'] = 'service'
        self.signed_targets = [dict(target, verified_slices={'arm64': 'verified'}, cdhash='cd') for target in self.targets]
        tree = lambda entries: GATE.digest(json.dumps(entries, sort_keys=True).encode())
        self.fixed = types.SimpleNamespace(read_regular=lambda path: path.read_bytes(),
            inventory=Mock(return_value=after), tree_digest=tree, trusted_verifier=lambda: object(),
            verify_target=Mock(return_value={'arm64': 'verified'}), check_signing_delta=Mock(), run_tool=Mock())
        self.constraint = types.SimpleNamespace(inspect_slice=Mock(), cdhash=lambda data: bytes.fromhex('cd'))
        self.signer = types.SimpleNamespace(dependencies=lambda: (self.fixed, self.constraint),
            native_constraint_review=lambda fixed: {'review': 'unchanged'},
            signing_targets=lambda *args: copy.deepcopy(self.targets), audit=Mock())
        self.signed = {'schema': 1, 'phase': 'service', 'app': str(GATE.SERVICE), 'static_verification': True,
                       'inputs': {'signer': 'pinned'}, 'pins': {'cert': 'same'},
                       'gui_receipt_sha256': GATE.GUI_REPORT_SHA256, 'gui_cdhash': GATE.GUI_CDHASH,
                       'actualGUIloads': False, 'native_qualification': False, 'packaging_accepted': False,
                       'runtime_gate_changed': False, 'before': {'tree_sha256': tree(before), 'entries': before},
                       'after': {'tree_sha256': tree(after), 'entries': after}, 'targets': self.signed_targets,
                       'native_constraint_review': {'review': 'unchanged'}}
        self.compile_path = GATE.WORK / 'servicecompile-receipt.json'
        self.sign_path = GATE.SERVICE.parent / 'Flash.service-signing-static.json'
        self.patch('GUI_REPORT_SHA256', self.save(GATE.GUI.parent / 'Flash.gui-signing-static.json',
                                                 {'inputs': self.signed['inputs'], 'pins': self.signed['pins']}))
        self.signed['gui_receipt_sha256'] = GATE.GUI_REPORT_SHA256
        self.compiled['gui_report_sha256'] = GATE.GUI_REPORT_SHA256
        self.patch('tooling_state', Mock(return_value=(self.delta, {}, self.sources)))
        self.patch('source_snapshot', Mock(return_value=self.sources))
        self.patch('verify_gui', Mock(return_value={'qualified': True}))
        self.patch('module', lambda name, pin: self.signer if name == 'sign_split_payload' else
                   types.SimpleNamespace(check_layout=Mock()))

    def verify(self):
        compile_hash = self.save(self.compile_path, self.compiled)
        sign_hash = self.save(self.sign_path, self.signed)
        return GATE.verify(GATE.GUI, GATE.SERVICE, GATE.EVIDENCE, GATE.METADATA,
                           self.compile_path, compile_hash, self.sign_path, sign_hash, GATE.DELTA, self.delta_hash)

    def test_static_gate_verifies_all_four_signatures_and_allowed_delta(self):
        self.fixture()
        result = self.verify()
        self.assertTrue(result['service_static_verified'])
        self.assertFalse(result['service_runtime_accepted'])
        self.assertFalse(result['installer_accepted'])
        self.assertEqual(self.fixed.verify_target.call_count, 4)
        mutable = self.fixed.check_signing_delta.call_args.args[2]
        self.assertNotIn('core', [target['role'] for target in mutable])
        self.assertEqual(GATE.verify_gui.call_count, 2)
        self.assertIn('--verify', self.fixed.run_tool.call_args.args[0])
        self.assertNotIn('--sign', self.fixed.run_tool.call_args.args[0])

    def test_signature_failure_never_accepts_service(self):
        self.fixture()
        self.fixed.verify_target.side_effect = ValueError('invalid signature')
        with self.assertRaisesRegex(ValueError, 'invalid signature'):
            self.verify()

    def test_signing_delta_failure_never_accepts_service(self):
        self.fixture()
        self.fixed.check_signing_delta.side_effect = ValueError('illegal mutation')
        with self.assertRaisesRegex(ValueError, 'illegal mutation'):
            self.verify()

    def test_stale_gui_native_evidence_never_accepts_service(self):
        self.fixture()
        GATE.verify_gui.side_effect = ValueError('stale GUI evidence')
        with self.assertRaisesRegex(ValueError, 'stale GUI evidence'):
            self.verify()
        self.fixed.verify_target.assert_not_called()

    def test_provenance_changes_fail_closed(self):
        self.fixture()
        for field in ('gui_cdhash', 'qualification_sha256', 'build_metadata_sha256', 'driver_sha256',
                      'gui_report_sha256', 'gui_signed_tree_sha256', 'source_freeze_sha256', 'tooling_delta_sha256'):
            original = self.compiled[field]
            self.compiled[field] = 'stale'
            with self.assertRaisesRegex(ValueError, 'provenance'):
                self.verify()
            self.compiled[field] = original
        self.compiled['source_inputs'] = {'native.c': {'sha256': 'changed'}}
        with self.assertRaisesRegex(ValueError, 'provenance'):
            self.verify()

    def test_changed_unsigned_helper_and_command_pin_rejected(self):
        self.fixture()
        self.write(GATE.WORK / 'helper', b'other binary')
        with self.assertRaisesRegex(ValueError, 'Compiler output'):
            self.verify()
        self.write(GATE.WORK / 'helper', b'unsigned-helper')
        self.compiled['outputs']['helper']['clang_argv'].append('-DUNREVIEWED=1')
        with self.assertRaisesRegex(ValueError, 'Compiler output'):
            self.verify()

    def test_changed_service_core_and_old_floor_rejected(self):
        self.fixture()
        self.compiled['gui_signed_core_sha256'] = 'other core'
        with self.assertRaisesRegex(ValueError, 'Core differs'):
            self.verify()
        self.compiled['gui_signed_core_sha256'] = GATE.digest(b'exact signed core')
        self.write(GATE.SERVICE / 'Contents/Info.plist', plistlib.dumps({'LSMinimumSystemVersion': '13.0'}))
        with self.assertRaisesRegex(ValueError, 'macOS 14'):
            self.verify()

    def test_static_gui_sets_restrictive_umask_before_certificate_extraction(self):
        events = []
        qualifier = types.SimpleNamespace(verify=lambda *args: events.append('verify') or {
            'before': {'tree_sha256': GATE.GUI_TREE, 'library_constraint': {'cdhash': GATE.GUI_CDHASH}},
        })
        with patch.object(GATE.os, 'umask', side_effect=lambda value: events.append(value)), \
                patch.object(GATE, 'pinned_bytes', return_value=b'pinned'), \
                patch.object(GATE, 'module', return_value=qualifier):
            GATE.verify_gui(GATE.GUI, GATE.METADATA, GATE.EVIDENCE)
        self.assertEqual(events, [0o077, 'verify'])

    def test_bad_pin_rejected_without_loading_modules(self):
        path = self.root / 'pinned.json'
        self.write(path, b'{}')
        for pin in (None, 'TBD', '0' * 64):
            with self.assertRaises(ValueError):
                GATE.pinned_json(path, pin)

    def test_tooling_delta_cannot_allow_native_source_changes(self):
        delta = {'schema': 'flash-service-tooling-delta-v1', 'source_freeze_sha256': GATE.FREEZE_SHA256,
                 'prior_gui_tooling_delta_sha256': GATE.PRIOR_DELTA_SHA256,
                 'files': {name: {} for name in GATE.ALLOWED_TOOLING}}
        delta['files']['macos/Shared/HelperTrust.m'] = {}
        with patch.object(GATE, 'pinned_json', side_effect=[delta, {'source_inputs': {}}, {}]), \
                patch.object(GATE, 'pinned_bytes', return_value=b'{}'):
            with self.assertRaisesRegex(ValueError, 'Unexpected downstream source delta'):
                GATE.tooling_state(GATE.DELTA, 'a' * 64)

    def test_recursive_native_policy_must_remain_original_frozen_bytes(self):
        supervisor = GATE.ROOT / 'macos/PrivilegedHelper/Supervisor.m'
        policy = supervisor.with_name('Policy.h')
        approved = {}
        def record(path):
            name = str(path.relative_to(GATE.ROOT))
            if path == policy:
                return {'sha256': 'changed-policy'}
            approved[name] = {'sha256': 'frozen'}
            return approved[name]
        def read(path):
            return b'#include "Policy.h"' if path == supervisor else b''
        self.write(policy, b'changed-policy')
        self.write(supervisor, b'#include "Policy.h"')
        approved[str(policy.relative_to(GATE.ROOT))] = {'sha256': 'frozen'}
        with patch.object(GATE, 'record', side_effect=record), patch.object(GATE, 'read', side_effect=read):
            with self.assertRaisesRegex(ValueError, 'Source differs'):
                GATE.source_snapshot(approved)


if __name__ == '__main__':
    unittest.main()
