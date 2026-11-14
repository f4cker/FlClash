import hashlib
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
        self.released_core = self.binary(self.root / 'released-core')
        self.core_sha256 = hashlib.sha256(self.released_core.read_bytes()).hexdigest()
        self.write(self.source / SPLIT.ICON, b'icns' + (16).to_bytes(4, 'big') + b'icondata')
        self.binary(self.source / SPLIT.HELPER)
        self.binary(self.source / SPLIT.MAINTENANCE)
        self.write(self.source / SPLIT.DAEMON, b'old embedded daemon')
        self.write(self.source / 'Contents/Info.plist', plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleExecutable': 'Flash',
            'CFBundleVersion': '2026111408', 'CFBundleShortVersionString': '0.9.5',
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
        SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        inputs = [self.binary(self.root / name) for name in ('stub', 'new-helper', 'new-maintenance')]
        SPLIT.stage_service(self.gui, *inputs, self.service, 'test-core-1', 'test-core-revision',
                            released_core=self.released_core, core_sha256=self.core_sha256)

    def test_gui_keeps_fresh_ui_and_removes_service_before_signing(self):
        before = SPLIT.inventory(self.source)
        SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        self.assertEqual(SPLIT.inventory(self.source), before)
        self.assertEqual((self.gui / self.ui).read_bytes(), (self.source / self.ui).read_bytes())
        self.assertFalse((self.gui / 'Contents/Library').exists())
        self.assertFalse((self.gui / 'Contents/_CodeSignature').exists())
        self.assertEqual(len(SPLIT.signing_targets('gui')), 6)
        self.assertEqual(self.verifier.FIXED_EXECUTABLES, ())
        self.audit.assert_called_once_with(self.gui, mutate=True)

    def test_service_has_four_targets_and_identical_signed_core(self):
        self.stage_pair()
        self.assertEqual(len(SPLIT.signing_targets('service')), 4)
        self.assertFalse((self.gui / SPLIT.CORE).exists())
        self.assertEqual((self.service / SPLIT.CORE).read_bytes(), self.released_core.read_bytes())
        self.assertEqual((self.service / SPLIT.ICON).read_bytes(), (self.gui / SPLIT.ICON).read_bytes())
        self.assertFalse((self.service / 'Contents/Frameworks').exists())
        self.assertFalse((self.service / self.ui).exists())
        info = plistlib.loads((self.service / 'Contents/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleIdentifier'], 'com.layoute.flash.service')
        self.assertEqual(info['CFBundleExecutable'], 'Flash')
        self.assertTrue(info['LSBackgroundOnly'])
        self.assertEqual(info['CFBundleIconFile'], 'AppIcon.icns')
        self.assertEqual(info['CFBundleVersion'], '2026111408')
        self.assertEqual(info['LSMinimumSystemVersion'], '14.0')

    def test_unsigned_gui_modes_follow_macho_bytes_before_and_after_audit(self):
        target = self.source / 'Contents/Frameworks/App.framework/Versions/A/App'
        target.chmod(0o644)
        (self.source / self.ui).chmod(0o755)
        def changed_mode(app, mutate):
            (app / 'Contents/MacOS/Flash').chmod(0o644)
        self.audit.side_effect = changed_mode
        SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        self.assertEqual((self.gui / 'Contents/MacOS/Flash').stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.gui / target.relative_to(self.source)).stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.gui / self.ui).stat().st_mode & 0o777, 0o644)
        self.assertEqual(target.stat().st_mode & 0o777, 0o644)

    @unittest.skipUnless(hasattr(os, 'lchmod'), 'Requires symlink mode support')
    def test_symlink_mode_normalization_does_not_follow_file_or_directory_targets(self):
        app = self.root / 'links'
        app.mkdir()
        target_file = self.root / 'untouched-file'
        target_file.write_bytes(b'unchanged target')
        target_file.chmod(0o600)
        target_directory = self.root / 'untouched-directory'
        target_directory.mkdir(mode=0o700)
        links = (app / 'file-link', app / 'directory-link')
        for link, target in zip(links, (target_file, target_directory)):
            link.symlink_to(target)
            os.lchmod(link, 0o700)
        targets = [os.readlink(link) for link in links]
        with patch.object(SPLIT.os, 'lchmod', wraps=os.lchmod) as lchmod:
            SPLIT.normalize_modes(app)
        self.assertEqual({call.args for call in lchmod.call_args_list}, {(link, 0o755) for link in links})
        self.assertEqual([link.lstat().st_mode & 0o777 for link in links], [0o755, 0o755])
        self.assertEqual([os.readlink(link) for link in links], targets)
        self.assertEqual(target_file.stat().st_mode & 0o777, 0o600)
        self.assertEqual(target_directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual(target_file.read_bytes(), b'unchanged target')

    @unittest.skipUnless(hasattr(os, 'lchmod'), 'Requires symlink mode support')
    def test_restrictive_umask_stages_readable_symlinks_before_inventory(self):
        for directory, directories, files in os.walk(self.source, followlinks=False):
            for name in directories + files:
                path = Path(directory) / name
                if path.is_symlink():
                    os.lchmod(path, 0o700)
        before = SPLIT.inventory(self.source)
        previous_umask = os.umask(0o077)
        try:
            SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        finally:
            os.umask(previous_umask)
        staged = SPLIT.inventory(self.gui)
        links = {name: entry for name, entry in staged.items() if entry['kind'] == 'link'}
        self.assertEqual(len(links), 2 * len(SPLIT.FRAMEWORKS))
        self.assertTrue(all(entry['mode'] == 0o755 for entry in links.values()))
        self.assertEqual(SPLIT.inventory(self.source), before)
        copied = self.root / 'readable-copy/Flash.app'
        shutil.copytree(self.gui, copied, symlinks=True)
        for name in links:
            os.lchmod(copied / name, 0o755)
        SPLIT.verify_copy(self.gui, copied, 'gui')
        os.lchmod(copied / next(iter(links)), 0o700)
        with self.assertRaisesRegex(ValueError, 'Copied payload differs'):
            SPLIT.verify_copy(self.gui, copied, 'gui')

    def test_existing_output_never_overwrites_ui_fixes(self):
        SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        before = SPLIT.inventory(self.gui)
        with self.assertRaisesRegex(ValueError, 'never overlay'):
            SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
        self.assertEqual(before, SPLIT.inventory(self.gui))

    def test_nested_destination_and_external_link_rejected(self):
        with self.assertRaisesRegex(ValueError, 'outside every input'):
            SPLIT.stage_gui(self.source, self.source / 'nested/Flash.app', self.released_core, self.core_sha256)
        (self.source / 'external').symlink_to(self.root)
        with self.assertRaisesRegex(ValueError, 'Escaping bundle link'):
            SPLIT.stage_gui(self.source, self.gui, self.released_core, self.core_sha256)
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

    def test_release_verifier_receives_independent_artifact_receipt_pins(self):
        self.stage_pair()
        gate = SPLIT.load_local('verify_split_service')
        with patch.object(gate, 'verify', return_value={'functional_acceptance': 'UNTESTED'}) as verify:
            original = SPLIT.load_local
            with patch.object(SPLIT, 'load_local', side_effect=lambda name: gate if name == 'verify_split_service' else original(name)):
                SPLIT.verify_release(self.gui, self.service, self.root / 'gui.json', 'a' * 64,
                                     self.root / 'service.json', 'b' * 64)
        verify.assert_called_once_with(self.gui, self.service, self.root / 'gui.json', 'a' * 64,
                                       self.root / 'service.json', 'b' * 64, None, None)

    def test_core_finalization_cannot_mutate_released_service(self):
        self.stage_pair()
        before = SPLIT.inventory(self.service)
        SPLIT.finalize_core_copy(self.gui, self.service, released_core=self.released_core,
                                 core_sha256=self.core_sha256)
        self.released_core.write_bytes(self.released_core.read_bytes() + b'new-core')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            SPLIT.finalize_core_copy(self.gui, self.service, released_core=self.released_core,
                                     core_sha256=self.core_sha256)
        new_hash = hashlib.sha256(self.released_core.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'immutable'):
            SPLIT.finalize_core_copy(self.gui, self.service, released_core=self.released_core,
                                     core_sha256=new_hash)
        self.assertEqual(before, SPLIT.inventory(self.service))

    def test_different_core_fails_before_receipt_loading(self):
        self.stage_pair()
        core = self.service / SPLIT.CORE
        core.write_bytes(core.read_bytes() + b'resigned')
        with self.assertRaisesRegex(ValueError, 'sealed compatibility'):
            SPLIT.verify_release(self.gui, self.service, self.root / 'missing', 'a' * 64,
                                 self.root / 'missing', 'b' * 64)

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

    def test_packager_gui_only_exits_after_styled_dmg_before_any_pkg_build(self):
        source = (SPLIT.PACKAGING / 'build_split_packages.sh').read_text()
        self.assertLess(source.index('umask 077'), source.index('\nverify_evidence\n'))
        self.assertLess(source.index('\nverify_evidence\n'), source.index('/bin/mkdir -m 0700'))
        styled = source.index('tool/macos/make_styled_dmg.sh')
        gui_only = source.index('if [[ "$mode" == gui-only ]]', styled)
        self.assertLess(styled, gui_only)
        self.assertLess(source.index('exit 0', gui_only), source.index('/usr/bin/pkgbuild'))
        self.assertIn('APPS_NAME=应用程序', source)
        self.assertIn('background@2x.png', source)
        self.assertNotIn('hdiutil create', source)
        self.assertNotIn('qualify_native_loads.py', source)
        self.assertIn('/bin/chmod 0755 "$scripts/"*', source)
        self.assertIn('--compression=none', source)
        self.assertIn('raw_package verify "$final_raw"', source)
        self.assertIn('--gui-sha256', source)
        self.assertIn('--service-sha256', source)
        self.assertIn('--compile-sha256', source)

    def test_two_gui_releases_reuse_core_and_leave_service_byte_identical(self):
        self.stage_pair()
        released = self.service / SPLIT.CORE
        digest = hashlib.sha256(released.read_bytes()).hexdigest()
        service_before = SPLIT.inventory(self.service)
        for revision in ('gui-first', 'gui-second'):
            (self.source / self.ui).write_bytes(revision.encode())
            destination = self.root / revision / 'Flash.app'
            SPLIT.stage_gui(self.source, destination, released, digest)
            self.assertFalse((destination / SPLIT.CORE).exists())
            self.assertEqual(SPLIT.compatible_pair(destination, self.service)['CoreSHA256'], digest)
            self.assertEqual(SPLIT.inventory(self.service), service_before)
            self.assertEqual((destination / self.ui).read_bytes(), revision.encode())

    def test_gui_metadata_may_accept_multiple_service_cores_without_bundled_core(self):
        self.stage_pair()
        service_hash = hashlib.sha256((self.service / SPLIT.CORE).read_bytes()).hexdigest()
        self.assertFalse((self.gui / SPLIT.CORE).exists())
        own_hash = hashlib.sha256(b'other-approved-core').hexdigest()
        SPLIT.seal_compatibility(self.gui, 'gui', {
            **SPLIT.COMPATIBILITY_VERSIONS, 'AcceptedCoreSHA256': [own_hash, service_hash],
        })
        self.assertEqual(SPLIT.compatible_pair(self.gui, self.service)['CoreSHA256'], service_hash)
        SPLIT.seal_compatibility(self.gui, 'gui', {
            **SPLIT.COMPATIBILITY_VERSIONS, 'AcceptedCoreSHA256': [own_hash],
        })
        with self.assertRaisesRegex(ValueError, 'does not accept'):
            SPLIT.compatible_pair(self.gui, self.service)

    def test_bad_released_core_pin_leaves_source_and_service_unchanged(self):
        self.stage_pair()
        before = SPLIT.inventory(self.service)
        destination = self.root / 'wrong-pin/Flash.app'
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            SPLIT.stage_gui(self.source, destination, self.service / SPLIT.CORE, '0' * 64)
        self.assertFalse(destination.exists())
        self.assertEqual(before, SPLIT.inventory(self.service))

    def test_compatibility_types_versions_hash_bounds_and_legacy_fail_closed(self):
        good = {**SPLIT.COMPATIBILITY_VERSIONS, 'AcceptedCoreSHA256': ['a' * 64]}
        for key, value in [('CallerPolicy', True), ('CallerPolicy', 1), ('ServiceAPI', 1.0),
                           ('CoreAPI', 2), ('AcceptedCoreSHA256', []),
                           ('AcceptedCoreSHA256', ['A' * 64]),
                           ('AcceptedCoreSHA256', ['a' * 64] * 2),
                           ('AcceptedCoreSHA256', [f'{i:064x}' for i in range(17)])]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                SPLIT.validate_compatibility(dict(good, **{key: value}), 'gui')
        with self.assertRaises(ValueError):
            SPLIT.read_compatibility(self.source, 'gui')
        self.stage_pair()
        self.write(self.service / 'Contents/_CodeSignature/CodeResources', b'sealed')
        with self.assertRaisesRegex(ValueError, 'precede outer signing'):
            SPLIT.seal_compatibility(self.service, 'service', SPLIT.read_compatibility(self.service, 'service'))

    def test_gui_rejects_any_loose_core_including_non_macho_and_dangling_link(self):
        self.stage_pair()
        core = self.gui / SPLIT.CORE
        for data in (b'placeholder', self.released_core.read_bytes()):
            self.write(core, data)
            with self.assertRaisesRegex(ValueError, 'loose Core'):
                SPLIT.check_layout(self.gui, 'gui')
            core.unlink()
        core.symlink_to('absent-core')
        with self.assertRaisesRegex(ValueError, 'loose Core'):
            SPLIT.check_layout(self.gui, 'gui')

    def test_service_staging_requires_explicit_matching_released_core_and_icon(self):
        self.stage_pair()
        inputs = [self.root / name for name in ('stub', 'new-helper', 'new-maintenance')]
        target = self.root / 'new-service/Flash.app'
        with self.assertRaises(TypeError):
            SPLIT.stage_service(self.gui, *inputs, target, 'version', 'revision')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            SPLIT.stage_service(self.gui, *inputs, target, 'version', 'revision',
                                released_core=self.released_core, core_sha256='0' * 64)
        self.assertFalse(target.exists())
        (self.gui / SPLIT.ICON).unlink()
        with self.assertRaises(OSError):
            SPLIT.stage_service(self.gui, *inputs, target, 'version', 'revision',
                                released_core=self.released_core, core_sha256=self.core_sha256)
        self.assertFalse(target.exists())

    def test_service_icon_exact_shape_and_old_iconless_service(self):
        self.stage_pair()
        icon = self.service / SPLIT.ICON
        original = icon.read_bytes()
        for bad in (b'not-an-icon', b'icns' + (999).to_bytes(4, 'big') + b'contents'):
            icon.write_bytes(bad)
            with self.assertRaisesRegex(ValueError, 'icon header or length'):
                SPLIT.check_layout(self.service, 'service')
        icon.write_bytes(original)
        icon.chmod(0o755)
        with self.assertRaisesRegex(ValueError, 'mode 0644'):
            SPLIT.check_layout(self.service, 'service')
        icon.chmod(0o644)
        extra = icon.parent / 'Other.icns'
        self.write(extra, original)
        with self.assertRaisesRegex(ValueError, 'extra files'):
            SPLIT.check_layout(self.service, 'service')
        extra.unlink()
        icon.unlink()
        with self.assertRaisesRegex(ValueError, 'metadata must match'):
            SPLIT.check_layout(self.service, 'service')
        icon.parent.rmdir()
        info_path = self.service / 'Contents/Info.plist'
        info = plistlib.loads(info_path.read_bytes())
        del info['CFBundleIconFile']
        info_path.write_bytes(plistlib.dumps(info))
        SPLIT.check_layout(self.service, 'service')
        self.write(icon, original)
        with self.assertRaisesRegex(ValueError, 'metadata must match'):
            SPLIT.check_layout(self.service, 'service')

    def test_minimum_service_build_rejects_old_wrapper_but_legacy_gui_is_unchanged(self):
        self.stage_pair()
        gui_info_path = self.gui / 'Contents/Info.plist'
        service_info_path = self.service / 'Contents/Info.plist'
        gui_info = plistlib.loads(gui_info_path.read_bytes())
        service_info = plistlib.loads(service_info_path.read_bytes())
        self.assertEqual(gui_info[SPLIT.MINIMUM_SERVICE_BUILD_KEY], '2026111408')
        service_info['CFBundleVersion'] = '2026111402'
        service_info_path.write_bytes(plistlib.dumps(service_info))
        with self.assertRaisesRegex(ValueError, 'below the GUI minimum'):
            SPLIT.compatible_pair(self.gui, self.service)
        for minimum in (True, 2026111408, '', 'not-a-build', '2026111408.1', '0202611408', '0000000000'):
            gui_info[SPLIT.MINIMUM_SERVICE_BUILD_KEY] = minimum
            gui_info_path.write_bytes(plistlib.dumps(gui_info))
            with self.subTest(minimum=minimum), self.assertRaisesRegex(ValueError, 'minimum service build'):
                SPLIT.compatible_pair(self.gui, self.service)
        gui_info[SPLIT.MINIMUM_SERVICE_BUILD_KEY] = '2026111408'
        gui_info_path.write_bytes(plistlib.dumps(gui_info))
        for version in ('0202611408', '0000000000'):
            service_info['CFBundleVersion'] = version
            service_info_path.write_bytes(plistlib.dumps(service_info))
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'below the GUI minimum'):
                SPLIT.compatible_pair(self.gui, self.service)
        service_info['CFBundleVersion'] = '2026111402'
        service_info_path.write_bytes(plistlib.dumps(service_info))
        del gui_info[SPLIT.MINIMUM_SERVICE_BUILD_KEY]
        gui_info_path.write_bytes(plistlib.dumps(gui_info))
        SPLIT.compatible_pair(self.gui, self.service)

    def test_stub_has_no_gui_or_service_side_effects(self):
        stub = (SPLIT.PACKAGING.parent / 'PrivilegedHelper/ServiceStub.c').read_text()
        self.assertEqual(stub.strip(), 'int main(void) {\n    return 0;\n}')


if __name__ == '__main__':
    unittest.main()
