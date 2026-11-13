import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'split_payload', Path(__file__).parents[1] / 'stage_split_payload.py',
)
SPLIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SPLIT)


class SplitPayloadTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / 'fresh/Flash.app'
        self.gui = self.root / 'gui/Flash.app'
        self.service = self.root / 'service/Flash.app'
        self.binary(self.source / 'Contents/MacOS/Flash')
        self.binary(self.source / SPLIT.CORE)
        self.binary(self.source / SPLIT.HELPER)
        self.binary(self.source / SPLIT.MAINTENANCE)
        self.write(self.source / SPLIT.DAEMON, b'old embedded daemon')
        self.write(self.source / 'Contents/Info.plist', plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleExecutable': 'Flash',
            'CFBundleVersion': '42', 'CFBundleShortVersionString': '0.9.5',
        }))
        for name in SPLIT.FRAMEWORKS:
            framework = self.source / f'Contents/Frameworks/{name}.framework'
            self.binary(framework / f'Versions/A/{name}')
            (framework / 'Versions/Current').symlink_to('A')
            (framework / name).symlink_to(f'Versions/Current/{name}')
        self.ui = 'Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/ui-fixes.bin'
        self.write(self.source / self.ui, b'fresh UI fixes must survive staging')
        self.write(self.source / 'Contents/_CodeSignature/CodeResources', b'old outer seal')
        self.verifier = SPLIT.load_local('stage_managed_payload')
        self.audit = patch.object(self.verifier, 'audit').start()
        self.addCleanup(patch.stopall)
        original_loader = SPLIT.load_local
        patch.object(SPLIT, 'load_local', side_effect=lambda name: self.verifier
                     if name == 'stage_managed_payload' else original_loader(name)).start()
        patch.object(self.verifier.subprocess, 'run', side_effect=AssertionError('No native commands')).start()
        patch.object(self.verifier.subprocess, 'check_output', side_effect=AssertionError('No native commands')).start()

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(0o644)

    def binary(self, path):
        self.write(path, bytes.fromhex('cffaedfe') + b'synthetic-never-execute')
        path.chmod(0o755)
        return path

    def stage_pair(self):
        SPLIT.stage_gui(self.source, self.gui)
        core = self.gui / SPLIT.CORE
        core.write_bytes(core.read_bytes() + b'exact-signed-core-fixture')
        inputs = [self.binary(self.root / name) for name in ('stub', 'new-helper', 'new-maintenance')]
        SPLIT.stage_service(self.gui, *inputs, self.service)

    def test_gui_keeps_fresh_ui_and_removes_service_before_signing(self):
        before = SPLIT.inventory(self.source)
        SPLIT.stage_gui(self.source, self.gui)
        self.assertEqual(SPLIT.inventory(self.source), before)
        self.assertEqual((self.gui / self.ui).read_bytes(), (self.source / self.ui).read_bytes())
        self.assertFalse((self.gui / 'Contents/Library').exists())
        self.assertFalse((self.gui / 'Contents/_CodeSignature').exists())
        self.assertEqual(len(SPLIT.signing_targets('gui')), 7)
        self.assertEqual(self.verifier.FIXED_EXECUTABLES, (SPLIT.CORE,))
        self.audit.assert_called_once_with(self.gui, mutate=True)

    def test_service_has_four_targets_and_identical_signed_core(self):
        self.stage_pair()
        self.assertEqual(len(SPLIT.signing_targets('service')), 4)
        self.assertEqual((self.service / SPLIT.CORE).read_bytes(), (self.gui / SPLIT.CORE).read_bytes())
        self.assertFalse((self.service / 'Contents/Frameworks').exists())
        self.assertFalse((self.service / self.ui).exists())
        info = plistlib.loads((self.service / 'Contents/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleIdentifier'], 'com.layoute.flash.service')
        self.assertEqual(info['CFBundleExecutable'], 'Flash')
        self.assertTrue(info['LSBackgroundOnly'])
        self.assertEqual(info['CFBundleVersion'], '42')
        self.assertEqual(info['LSMinimumSystemVersion'], '14.0')

    def test_unsigned_gui_modes_follow_macho_bytes_before_and_after_audit(self):
        target = self.source / 'Contents/Frameworks/App.framework/Versions/A/App'
        target.chmod(0o644)
        (self.source / self.ui).chmod(0o755)
        def changed_mode(app, mutate):
            (app / 'Contents/MacOS/Flash').chmod(0o644)
        self.audit.side_effect = changed_mode
        SPLIT.stage_gui(self.source, self.gui)
        self.assertEqual((self.gui / 'Contents/MacOS/Flash').stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.gui / target.relative_to(self.source)).stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.gui / self.ui).stat().st_mode & 0o777, 0o644)
        self.assertEqual(target.stat().st_mode & 0o777, 0o644)

    def test_existing_output_never_overwrites_ui_fixes(self):
        SPLIT.stage_gui(self.source, self.gui)
        before = SPLIT.inventory(self.gui)
        with self.assertRaisesRegex(ValueError, 'never overlay'):
            SPLIT.stage_gui(self.source, self.gui)
        self.assertEqual(before, SPLIT.inventory(self.gui))

    def test_nested_destination_and_external_link_rejected(self):
        with self.assertRaisesRegex(ValueError, 'outside every input'):
            SPLIT.stage_gui(self.source, self.source / 'nested/Flash.app')
        (self.source / 'external').symlink_to(self.root)
        with self.assertRaisesRegex(ValueError, 'Escaping bundle link'):
            SPLIT.stage_gui(self.source, self.gui)
        self.assertFalse(self.gui.exists())

    def test_service_rejects_gui_assets_and_unknown_code(self):
        self.stage_pair()
        self.write(self.service / 'Contents/Resources/flutter_assets/data', b'forbidden')
        with self.assertRaisesRegex(ValueError, 'GUI resources'):
            SPLIT.check_layout(self.service, 'service')
        self.binary(self.gui / 'Contents/MacOS/unexpected')
        with self.assertRaisesRegex(ValueError, 'Mach-O target'):
            SPLIT.check_layout(self.gui, 'gui')

    def test_exact_copy_detects_changed_ui(self):
        self.stage_pair()
        copied = self.root / 'copied/Flash.app'
        shutil.copytree(self.gui, copied, symlinks=True)
        SPLIT.verify_copy(self.gui, copied, 'gui')
        (copied / self.ui).write_bytes(b'old UI artifact')
        with self.assertRaisesRegex(ValueError, 'differs'):
            SPLIT.verify_copy(self.gui, copied, 'gui')

    def test_old_evidence_and_new_labels_cannot_unlock_packaging(self):
        self.stage_pair()
        evidence, metadata = self.root / 'evidence.json', self.root / 'metadata.json'
        for schema, message in ((1, 'Explicit service'), (SPLIT.EVIDENCE_SCHEMA, 'Explicit service')):
            metadata.write_text(json.dumps({'schema': 'flash-split-build-v1'}))
            evidence.write_text(json.dumps({'schema': schema, 'qualified': True, 'actualGUIloads': True,
                                            'binding': SPLIT.qualification_binding(self.gui, self.service, metadata)}))
            with self.assertRaisesRegex(ValueError, message):
                SPLIT.require_split_qualification(self.gui, self.service, evidence, metadata)

    def test_finalize_core_copy_changes_only_unsigned_service_core(self):
        self.stage_pair()
        before = SPLIT.inventory(self.service)
        core = self.gui / SPLIT.CORE
        core.write_bytes(core.read_bytes() + b'final-gui-signature')
        SPLIT.finalize_core_copy(self.gui, self.service)
        after = SPLIT.inventory(self.service)
        self.assertEqual({key for key in before if before[key] != after[key]}, {SPLIT.CORE})
        self.assertEqual((self.service / SPLIT.CORE).read_bytes(), core.read_bytes())
        self.write(self.service / 'Contents/_CodeSignature/CodeResources', b'service signed')
        with self.assertRaisesRegex(ValueError, 'precede'):
            SPLIT.finalize_core_copy(self.gui, self.service)

    def test_binding_changes_with_ui_or_metadata_and_rejects_unbound_evidence(self):
        self.stage_pair()
        metadata = self.root / 'metadata.json'
        metadata.write_text(json.dumps({'schema': 'flash-split-build-v1'}))
        binding = SPLIT.qualification_binding(self.gui, self.service, metadata)
        (self.gui / self.ui).write_bytes(b'changed UI')
        self.assertNotEqual(binding, SPLIT.qualification_binding(self.gui, self.service, metadata))
        evidence = self.root / 'evidence.json'
        evidence.write_text(json.dumps({'schema': SPLIT.EVIDENCE_SCHEMA, 'binding': binding}))
        with self.assertRaisesRegex(ValueError, 'Explicit service'):
            SPLIT.require_split_qualification(self.gui, self.service, evidence, metadata)

    def test_different_core_fails_before_evidence(self):
        self.stage_pair()
        core = self.service / SPLIT.CORE
        core.write_bytes(core.read_bytes() + b'resigned')
        with self.assertRaisesRegex(ValueError, 'Core bytes differ'):
            SPLIT.require_split_qualification(self.gui, self.service, self.root / 'missing', self.root / 'missing')

    def test_package_scripts_need_0755_and_no_payload_for_remove(self):
        self.stage_pair()
        expanded = self.root / 'expanded'
        self.write(expanded / 'PackageInfo', b'<pkg-info identifier="com.layoute.flash.managed.remove" install-location="/"><scripts><preinstall file="./preinstall"/><postinstall file="./postinstall"/></scripts></pkg-info>')
        originals = SPLIT.PACKAGING / 'installer/remove'
        for source in originals.iterdir():
            self.write(expanded / 'Scripts' / source.name, source.read_bytes())
        self.write(expanded / 'Scripts/FlashMaintenance', (self.service / SPLIT.MAINTENANCE).read_bytes())
        for path in (expanded / 'Scripts').iterdir():
            path.chmod(0o755)
        SPLIT.verify_expanded(self.service, expanded, 'remove')
        (expanded / 'Scripts/preinstall').chmod(0o700)
        with self.assertRaisesRegex(ValueError, '0755'):
            SPLIT.verify_expanded(self.service, expanded, 'remove')
        (expanded / 'Scripts/preinstall').chmod(0o755)
        (expanded / 'Payload').mkdir()
        with self.assertRaisesRegex(ValueError, 'must not have a payload'):
            SPLIT.verify_expanded(self.service, expanded, 'remove')

    def test_packager_gates_before_output_and_makes_actual_drag_dmg(self):
        source = (SPLIT.PACKAGING / 'build_split_packages.sh').read_text()
        self.assertLess(source.index('umask 077'), source.index('\nverify_evidence\n'))
        self.assertLess(source.index('\nverify_evidence\n'), source.index('/bin/mkdir -m 0700'))
        self.assertIn('/usr/bin/ditto "$gui" "$dmg_root/Flash.app"', source)
        self.assertIn('/bin/ln -s /Applications "$dmg_root/Applications"', source)
        self.assertIn('-srcfolder "$dmg_root"', source)
        self.assertNotIn('qualify_native_loads.py', source)
        self.assertIn('/bin/chmod 0755 "$scripts/"*', source)
        self.assertIn('--compression=none', source)
        self.assertIn('raw_package verify "$final_raw"', source)
        for flag in ('--service-compile-receipt', '--service-compile-sha256',
                     '--service-signing-receipt', '--service-signing-sha256',
                     '--tooling-delta', '--tooling-delta-sha256'):
            self.assertIn(flag, source)

    def test_service_verifier_hash_is_checked_before_import(self):
        delta = self.root / 'delta.json'
        delta.write_text('{}')
        delta.chmod(0o600)
        with self.assertRaisesRegex(ValueError, 'delta pin mismatch'):
            SPLIT.load_service_gate(delta, '0' * 64)
        fake = self.root / 'packaging/verify_split_service.py'
        self.write(fake, b'raise AssertionError("untrusted module executed")')
        delta.write_text(json.dumps({'files': {'macos/packaging/verify_split_service.py': {
            'after': {'sha256': '0' * 64, 'bytes': 0, 'mode': 0o644},
        }}}))
        with patch.object(SPLIT, 'PACKAGING', fake.parent):
            with self.assertRaisesRegex(ValueError, 'before import'):
                SPLIT.load_service_gate(delta, SPLIT.hashlib.sha256(delta.read_bytes()).hexdigest())

    def test_stub_has_no_gui_or_service_side_effects(self):
        stub = (SPLIT.PACKAGING.parent / 'PrivilegedHelper/ServiceStub.c').read_text()
        self.assertEqual(stub.strip(), 'int main(void) {\n    return 0;\n}')


if __name__ == '__main__':
    unittest.main()
