from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[2]
WINDOW = (ROOT / 'macos/Runner/MainFlutterWindow.swift').read_text()
BRIDGE = WINDOW[WINDOW.index('private enum MainAppLoginItem'):]
LAUNCH = (ROOT / 'lib/common/launch.dart').read_text()


class LoginItemSourceTests(unittest.TestCase):
    def test_main_app_route_is_available_only_on_macos_13(self):
        self.assertIn('import ServiceManagement', WINDOW)
        # Upstream dropped the LaunchAtLogin package; macOS 12 has no route.
        self.assertNotIn('import LaunchAtLogin', WINDOW)
        self.assertLess(BRIDGE.index('guard #available(macOS 13, *)'),
                        BRIDGE.index('let service = SMAppService.mainApp'))
        self.assertIn('handleLegacy(call, result: result)', BRIDGE)

    def test_getter_distinguishes_enabled_unregistered_and_errors(self):
        getter = BRIDGE.split('if call.method == "launchAtStartupIsEnabled"')[1]
        getter = getter.split('guard let arguments')[0]
        self.assertIn('case .enabled: result(true)', getter)
        self.assertIn('case .notRegistered: result(false)', getter)
        self.assertIn('default: result(statusError(service.status', getter)
        self.assertNotIn('LegacyLoginItemState.read()', getter)

    def test_enabled_is_idempotent_without_unregister_register_retry(self):
        enabled_case = BRIDGE.split('switch before {')[1].split('case .requiresApproval:')[0]
        self.assertIn('if !enabled { try service.unregister() }', enabled_case)
        self.assertNotIn('service.register()', enabled_case)
        self.assertNotIn('try?', BRIDGE)

    def test_requires_approval_is_not_automatically_retried(self):
        approval_case = BRIDGE.split('switch before {')[1].split('case .requiresApproval:')[1]
        approval_case = approval_case.split('case .notRegistered:')[0]
        self.assertIn('statusError(before, operation: "enable")', approval_case)
        self.assertNotIn('service.register()', approval_case)
        self.assertIn('try service.unregister()', approval_case)
        self.assertIn('login_item_requires_approval', BRIDGE)
        self.assertIn('login_item_not_found', BRIDGE)

    def test_native_failures_keep_error_and_status_details(self):
        caught = BRIDGE.split('} catch {')[1].split('let after')[0]
        for value in ('login_item_operation_failed', 'native.localizedDescription',
                      'native.domain', 'native.code', 'statusName(service.status)', 'return'):
            self.assertIn(value, caught)
        self.assertNotIn('result(nil)', caught)

    def test_success_requires_verified_requested_status(self):
        postcondition = 'guard enabled ? after == .enabled : after == .notRegistered else'
        self.assertIn(postcondition, BRIDGE)
        self.assertLess(BRIDGE.index(postcondition), BRIDGE.rindex('result(nil)'))

    def test_no_legacy_queries_or_migration_are_introduced(self):
        for forbidden in ('SMCopyAllJobDictionaries', 'SMLoginItemSetEnabled',
                          'LegacyLoginItemState', 'migrateIfNeeded',
                          'SMAppService.loginItem',
                          'launchctl', 'osascript', 'openSystemSettings'):
            self.assertNotIn(forbidden, BRIDGE)

    def test_mac_bootstrap_and_observer_do_not_reconcile_login_item(self):
        self.assertIn('if (kDebugMode || Platform.isMacOS)', LAUNCH)
        manager = (ROOT / 'lib/manager/window_manager.dart').read_text()
        self.assertIn('if (prev != next && !system.isMacOS)', manager)
        startup = WINDOW[WINDOW.index('func configureFlutter()'):]
        startup = startup.split('private func makeProject()')[0]
        self.assertNotIn('LegacyLoginItemState.read()', startup)
        self.assertNotIn('SMAppService.mainApp', startup)

    def test_legacy_compatibility_is_idempotent_and_verified(self):
        legacy = BRIDGE.split('private static func handleLegacy')[1]
        legacy = legacy.split('@available(macOS 13, *)')[0]
        # macOS 12: reads off, a disable succeeds, an enable is refused with
        # a login_item_* code rather than reported as applied.
        self.assertIn('result(false)', legacy)
        self.assertLess(legacy.index('if !enabled {'), legacy.index('login_item_operation_failed'))
        self.assertIn('"status": "unsupported"', legacy)
        self.assertNotIn('LaunchAtLogin', legacy)
        self.assertNotIn('nativeCode', legacy)
        self.assertNotIn('SMAppService', legacy)

    def test_startup_refresh_only_publishes_verified_reads(self):
        bootstrap = (ROOT / 'lib/bootstrap.dart').read_text()
        mac = bootstrap.split('if (system.isMacOS) {')[1].split('} else {')[0]
        self.assertIn('globalState.safeRun', mac)
        self.assertIn('autoLaunch?.refreshStatus', mac)
        self.assertIn('state.copyWith(autoLaunch: enabled)', mac)
        self.assertNotIn('updateStatus', mac)
        refresh = LAUNCH.split('Future<void> refreshStatus')[1].split('Future<bool> enable')[0]
        self.assertIn('onVerified(await isEnable)', refresh)
        self.assertNotIn('catch', refresh)
        self.assertNotIn('disable()', refresh)

    def test_only_explicit_settings_toggle_saves_after_success(self):
        settings = (ROOT / 'lib/views/config/general.dart').read_text()
        toggle = settings.split('title: (l) => l.autoLaunch,')[1]
        toggle = toggle.split('title: (l) => l.silentLaunch,')[0]
        self.assertIn('await globalState.safeRun', toggle)
        self.assertLess(toggle.index('await launcher.enable()'),
                        toggle.index('state.copyWith(autoLaunch: value)'))
        self.assertLess(toggle.index('await launcher.disable()'),
                        toggle.index('state.copyWith(autoLaunch: value)'))

    def test_localized_login_errors_hide_native_messages_and_details(self):
        localization = (ROOT / 'lib/common/app_localizations.dart').read_text()
        helper = localization.split('String? loginItemErrorMessage(')[1]
        helper = helper.split('String userFacingErrorMessage(')[0]
        for code in ('requires_approval', 'not_found', 'unexpected_status', 'missing_status'):
            self.assertIn('login_item_' + code, helper)
        self.assertIn("code.startsWith('login_item_')", helper)
        self.assertNotIn('error.message', helper)
        self.assertNotIn('error.details', helper)
        self.assertNotIn('toString()', helper)
        self.assertIn('return loginItemErrorMessage(error, appLocalizations) ??', localization)

    def test_approved_login_copy_and_locale_keys_are_preserved(self):
        expected = {
            'loginItemRequiresApproval': ('Allow Flash to open at login in System Settings.', '需要在系统设置中允许 Flash 登录时打开。'),
            'loginItemNotFound': ('macOS couldn’t find the current Flash app to set it to open at login.', 'macOS 找不到当前的 Flash，无法设置登录时打开。'),
            'loginItemUnexpectedStatus': ('Couldn’t confirm that Open at Login was updated as requested.', '无法确认登录时打开是否已按所选设置更新。'),
            'loginItemMissingStatus': ('Couldn’t read the Open at Login status.', '无法读取登录时打开的状态。'),
            'loginItemOperationFailed': ('Couldn’t change the Open at Login setting.', '无法更改登录时打开设置。'),
        }
        reference = json.loads((ROOT / 'arb/intl_en.arb').read_text())
        for path in (ROOT / 'arb').glob('intl_*.arb'):
            data = json.loads(path.read_text())
            self.assertEqual({key for key in data if not key.startswith('@')},
                             {key for key in reference if not key.startswith('@')})
            generated = (ROOT / 'lib/l10n' / ('l10n_' + path.stem[5:] + '.dart')).read_text()
            for key, values in expected.items():
                self.assertEqual(data[key], values[path.stem == 'intl_zh'])
                self.assertIn(key, generated)

    def test_channel_contract_uses_validated_arguments_not_force_cast(self):
        self.assertIn('MainAppLoginItem.handle(call, result: result)', WINDOW)
        self.assertIn('arguments["setEnabledValue"] as? Bool', BRIDGE)
        self.assertNotIn('as!', BRIDGE)
        adapter = LAUNCH.split('class MacOSLoginItemEntry')[1]
        self.assertIn("MethodChannel('launch_at_startup')", adapter)
        setter = adapter.split('Future<bool> setEnabled')[1].split('class AutoLaunch')[0]
        self.assertNotIn('isEnabled()', setter)
        self.assertNotIn('catch', setter)


if __name__ == '__main__':
    unittest.main()
