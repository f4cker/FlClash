import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('load_policy', Path(__file__).parents[1] / 'stage_managed_payload.py')
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class LoadPolicyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / 'Flash.app'
        self.gui = self.app / 'Contents/MacOS/Flash'
        self.gui.parent.mkdir(parents=True)
        self.gui.write_bytes(b'fixture-not-executable')
        for name in POLICY.ASSETS.values():
            framework = self.app / f'Contents/Frameworks/{name}.framework'
            version = framework / 'Versions/A'
            version.mkdir(parents=True)
            (version / name).write_bytes(b'fixture-not-executable')
            (framework / 'Versions/Current').symlink_to('A')
            (framework / name).symlink_to(f'Versions/Current/{name}')
        self.manifest = {'format-version': [1, 0, 0], 'native-assets': {
            'macos_arm64': {key: ['absolute', f'{name}.framework/{name}'] for key, name in POLICY.ASSETS.items()},
        }}

    def test_manifest_anchors_every_known_asset(self):
        result = POLICY.rewrite_manifest(self.manifest, self.app)
        for key, name in POLICY.ASSETS.items():
            self.assertEqual(result['native-assets']['macos_arm64'][key],
                             ['absolute', f'@executable_path/../Frameworks/{name}.framework/{name}'])

    def test_manifest_rejects_external_bare_or_relaxed_types(self):
        key = next(iter(POLICY.ASSETS))
        for value in (['absolute', '/tmp/external.dylib'], ['system', 'objective_c'], ['process'],
                      ['relative', 'objective_c.framework/objective_c']):
            data = copy.deepcopy(self.manifest)
            data['native-assets']['macos_arm64'][key] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                POLICY.rewrite_manifest(data, self.app)

    def test_manifest_rejects_unknown_missing_platform_and_schema(self):
        for change in ('unknown', 'missing', 'platform', 'schema'):
            data = copy.deepcopy(self.manifest)
            if change == 'unknown':
                data['native-assets']['macos_arm64']['injected'] = ['process']
            elif change == 'missing':
                data['native-assets']['macos_arm64'].pop(next(iter(POLICY.ASSETS)))
            elif change == 'platform':
                data['native-assets']['linux_x64'] = {}
            else:
                data['format-version'] = [2, 0, 0]
            with self.subTest(change=change), self.assertRaises(ValueError):
                POLICY.rewrite_manifest(data, self.app)

    def test_framework_links_stay_in_their_own_framework(self):
        POLICY.validate_links(self.app)
        current = self.app / 'Contents/Frameworks/objective_c.framework/Versions/Current'
        current.unlink()
        current.symlink_to('../../../sqlite3.framework/Versions/A')
        with self.assertRaises((ValueError, OSError)):
            POLICY.validate_links(self.app)

    def test_manifest_requires_canonical_existing_framework_target(self):
        link = self.app / 'Contents/Frameworks/objective_c.framework/objective_c'
        link.unlink()
        outside = Path(self.directory.name) / 'outside'
        outside.write_bytes(b'not-executable')
        link.symlink_to(outside)
        with self.assertRaises(ValueError):
            POLICY.rewrite_manifest(self.manifest, self.app)

    def test_only_system_or_bundle_anchored_rpaths(self):
        allowed = POLICY.check_rpath('@executable_path/../Frameworks', self.gui, self.gui, self.app)
        self.assertEqual(allowed, (self.app / 'Contents/Frameworks').resolve())
        self.assertIsNone(POLICY.check_rpath('/usr/lib/', self.gui, self.gui, self.app))
        for value in ('/usr/local/lib/.', '/tmp', '.', '@rpath/foo', '/usr/lib/../../tmp'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                POLICY.check_rpath(value, self.gui, self.gui, self.app)

    def test_dependencies_require_actual_anchored_targets(self):
        frameworks = (self.app / 'Contents/Frameworks').resolve()
        for value in ('@rpath/objective_c.framework/objective_c',
                      '@executable_path/../Frameworks/sqlite3.framework/sqlite3', '/usr/lib/libSystem.B.dylib'):
            with patch.object(POLICY, 'load_commands', return_value={'arm64': ([], [])}):
                POLICY.check_dependency(value, self.gui, self.gui, self.app, [frameworks])
        for value in ('objective_c.framework/objective_c', '/tmp/injected', '@rpath/missing.dylib',
                      '@rpath/../../outside', '@executable_path/../../../outside'):
            with self.subTest(value=value), self.assertRaises((ValueError, OSError)):
                POLICY.check_dependency(value, self.gui, self.gui, self.app, [frameworks])

    def test_all_slices_are_named_independently(self):
        commands = f'''{self.gui} (architecture x86_64):
Load command 0
          cmd LC_RPATH
         path @executable_path/../Frameworks (offset 12)
{self.gui} (architecture arm64):
Load command 0
          cmd LC_RPATH
         path /usr/local/lib/. (offset 12)
'''
        with patch.object(POLICY.subprocess, 'check_output', side_effect=[commands, 'arm64 x86_64']):
            slices = POLICY.load_commands(self.gui)
        self.assertEqual(slices['arm64'][0], ['/usr/local/lib/.'])
        self.assertEqual(slices['x86_64'][0], ['@executable_path/../Frameworks'])

    def test_uninspected_slice_fails_closed(self):
        with patch.object(POLICY.subprocess, 'check_output', side_effect=[f'{self.gui}:\n', 'arm64 x86_64']):
            with self.assertRaises(ValueError):
                POLICY.load_commands(self.gui)

    def test_dynamic_loader_environment_commands_rejected(self):
        commands = f'{self.gui}:\ncmd LC_DYLD_ENVIRONMENT\nname DYLD_INSERT_LIBRARIES=x (offset 12)\n'
        with patch.object(POLICY.subprocess, 'check_output', return_value=commands):
            with self.assertRaises(ValueError):
                POLICY.load_commands(self.gui)

    def test_installer_freezes_before_atomic_swap_and_preserves_old_payload(self):
        base = Path(__file__).parents[1]
        preinstall = (base / 'installer/install/preinstall').read_text()
        postinstall = (base / 'installer/install/postinstall').read_text()
        self.assertNotIn('/bin/rm', preinstall)
        self.assertLess(postinstall.index('"$guard" stageReady'), postinstall.index('"$guard" arm'))
        self.assertLess(postinstall.index('" prepare'), postinstall.index('/bin/launchctl bootout'))
        self.assertLess(postinstall.index('"$guard" quiescent'), postinstall.index('"$guard" commitInstall'))
        native = (base.parent / 'PrivilegedHelper/Maintenance.m').read_text()
        self.assertIn('RENAME_SWAP', native)
        self.assertIn('FCTransactionResumeAllowed', native)
        self.assertNotIn('trap ', preinstall)

    def test_fresh_disable_does_not_create_an_install_lock(self):
        base = Path(__file__).parents[1]
        disabled = (base / 'installer/disable/preinstall').read_text()
        self.assertLess(disabled.index('[[ "$status" != 10 ]] || exit 0'), disabled.index('/bin/mkdir -m 0700 "$lock"'))
        removed = (base / 'installer/remove/preinstall').read_text()
        self.assertNotIn('/bin/mkdir', removed)
        native = (base.parent / 'PrivilegedHelper/Maintenance.m').read_text()
        begin = native[native.index('static int FCBeginRemoval'):native.index('static BOOL FCBegin(BOOL repair)')]
        self.assertLess(begin.index('return 10;'), begin.index('mkdir('))

    def test_repair_is_explicit_not_an_automatic_install_retry(self):
        base = Path(__file__).parents[1] / 'installer'
        self.assertIn('beginInstall', (base / 'install/preinstall').read_text())
        self.assertIn('beginRepair', (base / 'repair/preinstall').read_text())

    def test_durable_transaction_freeze_outlives_runtime_directory(self):
        base = Path(__file__).parents[2] / 'PrivilegedHelper'
        supervisor = (base / 'Supervisor.m').read_text()
        self.assertIn('FCTransactionPending()', supervisor)
        self.assertIn('@".installer-lock"', supervisor)
        postinstall = (Path(__file__).parents[1] / 'installer/install/postinstall').read_text()
        self.assertLess(postinstall.index('"$guard" finishInstall'), postinstall.index('"$guard" disarm'))
        self.assertLess(postinstall.index('"$guard" disarm'), postinstall.rindex('/bin/launchctl bootstrap'))

    def test_explicit_empty_lock_repair_does_not_release_unknown_children(self):
        native = (Path(__file__).parents[2] / 'PrivilegedHelper/Maintenance.m').read_text()
        begin = native[native.index('static BOOL FCBegin'):native.index('static BOOL FCStageReady')]
        self.assertIn('FCEmptyLockRecoveryAllowed', begin)
        self.assertNotIn('disarm', begin)
        self.assertNotIn('child-owned', begin)
        self.assertNotIn('unlink(', begin)

    def test_disable_is_not_uninstall(self):
        base = Path(__file__).parents[1] / 'installer'
        disabled = (base / 'disable/preinstall').read_text()
        removed = (base / 'remove/preinstall').read_text()
        self.assertNotIn('/bin/rm ', disabled)
        self.assertIn('"$guard" beginRemove', removed)
        self.assertIn('"$guard" finishRemove', removed)
        self.assertNotIn('/bin/rm', removed)

    def test_removal_records_handoff_and_retirement_before_destructive_cleanup(self):
        base = Path(__file__).parents[1]
        native = (base.parent / 'PrivilegedHelper/Maintenance.m').read_text()
        self.assertIn('completed && accepted && FCRecordRemovalHandoff()', native)
        handoff = native[native.index('static BOOL FCRecordRemovalHandoff(void) {'):native.index('static BOOL FCFinishRemoval')]
        self.assertIn('FCWriteTransaction(@"remove-stopped"', handoff)
        finish = native[native.index('static BOOL FCFinishRemoval'):native.index('static int FCBeginRemoval')]
        self.assertLess(finish.index('FCWriteTransaction(@"remove-ready"'), finish.index('renamex_np('))
        self.assertIn('RENAME_EXCL', finish)
        self.assertLess(finish.index('renamex_np('), finish.index('FCWriteTransaction(@"remove-retired"'))
        self.assertLess(finish.index('FCWriteTransaction(@"remove-cleaning"'), finish.index('unlink(FCLegacyPlist'))
        self.assertLess(finish.index('FCRemoveFixedTree(FCRetiredBundle())'), finish.index('FCWriteTransaction(@"remove-cleaned"'))
        self.assertLess(finish.index('FCRemovalState(FCTransaction())'), finish.index('unlink(marker'))
        self.assertLess(finish.index('rmdir(FCRuntimeDirectory'), finish.index('unlink(file'))
        self.assertNotIn('child-owned', finish)
        removed = (base / 'installer/remove/preinstall').read_text()
        handoff_start = removed.index('if [[ "$status" == 0 ]]; then')
        handoff_end = removed.index('\nfi\n', handoff_start)
        self.assertIn('"$tool" prepare', removed[handoff_start:handoff_end])
        self.assertGreater(removed.index('"$guard" finishRemove'), handoff_end)
        self.assertNotIn('disarm', removed)

    def test_repair_recognizes_only_recorded_removal_before_staging(self):
        native = (Path(__file__).parents[2] / 'PrivilegedHelper/Maintenance.m').read_text()
        begin = native[native.index('static BOOL FCBegin(BOOL repair)'):native.index('static BOOL FCStageReady')]
        self.assertIn('repair ? FCTransaction() : nil', begin)
        self.assertLess(begin.index('FCRemovalState(removal)'), begin.index('FCFinishRemoval()'))
        self.assertLess(begin.index('action == FCRemovalReject'), begin.index('FCFinishRemoval()'))
        self.assertLess(begin.index('!FCAbsent(FCRetiredBundle())'), begin.index('FCWriteTransaction(@"staging"'))


if __name__ == '__main__':
    unittest.main()
