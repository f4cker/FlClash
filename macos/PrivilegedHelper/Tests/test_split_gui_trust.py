import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TRUST = (MACOS / 'Shared/HelperTrust.m').read_text()
TRUST_HEADER = (MACOS / 'Shared/HelperTrust.h').read_text()
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()


class SplitGUITrustTests(unittest.TestCase):
    def test_pure_policy_and_per_message_validation(self):
        with tempfile.TemporaryDirectory(prefix='flash-split-policy-') as scratch:
            executable = str(Path(scratch) / 'policy')
            for pin in ('BBA7F8529FD271B9848EC03A2CE3F4780F585556', '', 'A' * 40, 'bad'):
                with self.subTest(pin=pin):
                    subprocess.run([
                        'clang', '-fobjc-arc', '-fblocks', '-Werror',
                        '-Wno-deprecated-declarations',
                        f'-DFC_PINNED_CERTIFICATE_SHA1="{pin}"',
                        str(MACOS / 'PrivilegedHelper/Tests/SplitGUITrustPolicyTests.m'),
                        '-framework', 'Foundation', '-framework', 'Security',
                        '-o', executable,
                    ], check=True, capture_output=True, text=True)
                    subprocess.run([executable], check=True, capture_output=True, text=True)

    def test_daemon_and_core_live_in_the_sealed_app(self):
        self.assertIn('FCHelperLabel = @FC_HELPER_LABEL;', TRUST)
        self.assertIn('#define FC_HELPER_LABEL "com.layoute.flash.helperd"', TRUST_HEADER)
        self.assertIn('FCHelperRelativePath = @"Contents/Library/HelperTools/FlashHelper"', TRUST)
        self.assertIn('FCCoreRelativePath = @"Contents/MacOS/FlClashCore"', TRUST)
        for removed in ('FCPayloadTrust', 'FCBundleTrust', 'FCInstalledBundle', 'FCMaintenanceIdentifier',
                        'FCServiceIdentifier', 'FCLegacyPlistTrusted'):
            self.assertNotIn(removed, TRUST)
        self.assertIn('FCLauncherRelativePath = @"Contents/Library/HelperTools/FlashHelperLauncher"', TRUST)
        self.assertIn('FCHelperCopyPath = @"/Library/Application Support/com.layoute.flash.helperd/FlashHelper"', TRUST)
        self.check = TRUST.split('NSString *FCHelperSelfCheck(NSString *runningExecutable, NSString *bundle) {', 1)[1]
        self.check = self.check.split('\n}\n', 1)[0]
        order = ['[runningExecutable isEqualToString:FCHelperCopyPath]', '[bundle isEqualToString:FCGUIBundle]',
                 'realpath(bundle.fileSystemRepresentation', 'SecCodeCopySelf',
                 'SecCodeCheckValidity(me, kSecCSStrictValidate, requirement)',
                 'FCExecutableMatches(info, FCHelperCopyPath)', 'FCCodeEntitlementsAllowed',
                 'FCStaticCodeHash(FCHelperCopyPath, FCHelperIdentifier)', '[diskHash isEqualToData:runningHash]',
                 'FCStaticCodeHash([bundle stringByAppendingPathComponent:FCHelperRelativePath], FCHelperIdentifier)',
                 '[bundledHash isEqualToData:runningHash]', 'FCGUIBundleTrust(bundle)', 'FCBundledDaemonPresent(bundle)',
                 'return @"ok"']
        positions = [self.check.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn('FCInstalledExecutable', self.check)
        # Every path the helper derives from the app comes from the checked --flash-bundle argument.
        self.assertNotIn('FCGUIBundle', SUPERVISOR)
        self.assertIn('FCReadCompatibility(self.bundle)', SUPERVISOR)
        self.assertIn('FCHelperSelfCheck(FCRunningExecutable(), self.bundle)', SUPERVISOR)
        for directory in ('com.layoute.flash.helperd', 'FCLauncherStateDirectory', 'FCLauncherStatusDirectory'):
            self.assertNotIn(directory, SUPERVISOR)
        self.assertIn('gui:(FCGUIMessageValidator *)gui', SUPERVISOR)
        self.assertIn('NSString *requirement = FCGUIRequirement()', SUPERVISOR)
        self.assertIn('xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)', SUPERVISOR)

    def test_no_gui_seal_cache_or_root_requirement(self):
        gui = TRUST.split('@implementation FCGUIMessageValidator', 1)[1].split('@end', 1)[0]
        self.assertIn('@available(macOS 14.0, *)', gui)
        self.assertIn('SecCodeCreateWithXPCMessage(message', gui)
        self.assertIn('fileURLWithPath:FCGUIBundle', gui)
        self.assertIn('FCCheckGUIStatic(diskCode)', gui)
        self.assertIn('FCValidGUIHash(runningHash)', gui)
        self.assertIn('FCValidGUIHash(diskHash)', gui)
        self.assertIn('[diskHash isEqualToData:runningHash]', gui)
        self.assertNotIn('sealed', gui)
        self.assertNotIn('FCProtectedTree', gui)

    def test_bridge_gates_on_app_trust_and_bundled_daemon(self):
        gate = BRIDGE.split('- (NSString *)gate {', 1)[1].split('- (NSString *)currentHelperHash', 1)[0]
        app = BRIDGE.split('- (NSString *)appGate {', 1)[1].split('- (NSString *)gate {', 1)[0]
        self.assertIn('@available(macOS 14.0, *)', app)
        self.assertIn('FCGUIBundleTrust(NSBundle.mainBundle.bundlePath)', app)
        self.assertLess(gate.index('[self appGate]'), gate.index('FCBundledDaemonPresent(FCGUIBundle)'))
        self.assertIn('return @"notFound"', gate)
        self.assertIn('FCCheckStatic(FCInstalledExecutable(FCHelperIdentifier), FCHelperIdentifier)', gate)
        # The daemon runs as the launcher's copy; its cdhash is compared with the helper sealed in the app.
        self.assertIn('executable:FCHelperCopyPath sealedExecutable:FCInstalledExecutable(FCHelperIdentifier)', BRIDGE)
        self.assertNotIn('executable:FCInstalledExecutable(FCHelperIdentifier)]', BRIDGE)
        self.assertIn('FCBundleCompatibilityValid(FCReadCompatibility(FCGUIBundle))', gate)
        self.assertNotIn('FCSHA256([NSBundle.mainBundle.bundlePath', BRIDGE)
        for removed in ('installerPayload', 'FlashMinimumServiceBuild', 'Flash-helper-install.pkg', '/usr/sbin/installer'):
            self.assertNotIn(removed, BRIDGE)
        self.assertIn('daemonServiceWithPlistName:FCDaemonPlistName', BRIDGE)
        self.assertIn('self.negotiatedCoreHash.UTF8String', BRIDGE)
        self.assertIn('"coreHash"', BRIDGE)


if __name__ == '__main__':
    unittest.main()
