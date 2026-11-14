import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TRUST = (MACOS / 'Shared/HelperTrust.m').read_text()
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

    def test_service_keeps_protected_identity_and_core(self):
        payload = TRUST.split('NSString *FCPayloadTrust(NSString *bundle) {', 1)[1]
        self.assertIn('FCCheckStatic(bundle, FCServiceIdentifier)', payload)
        self.assertNotIn('FCCheckStatic(bundle, FCClientIdentifier)', payload)
        self.assertIn('FCProtectedTree(bundle, YES)', payload)
        for role in ('FCHelperLabel', 'FCMaintenanceIdentifier', '@"com.layoute.flash.core"'):
            self.assertIn(role, payload)
        self.assertIn('[self.bundle stringByAppendingPathComponent:@"Contents/MacOS/FlClashCore"]', SUPERVISOR)
        self.assertIn('FCReadCompatibility(FCGUIBundle)', SUPERVISOR)
        self.assertIn('gui:(FCGUIMessageValidator *)gui', SUPERVISOR)
        self.assertIn('NSString *guiRequirement = FCSplitGUIRequirement()', SUPERVISOR)

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

    def test_bridge_separates_gui_and_service(self):
        gate = BRIDGE.split('- (NSString *)gate {', 1)[1].split('- (NSString *)installationStatus', 1)[0]
        self.assertIn('@available(macOS 14.0, *)', gate)
        self.assertIn('FCGUIBundleTrust(NSBundle.mainBundle.bundlePath)', gate)
        self.assertIn('FCBundleTrust(FCInstalledBundle)', gate)
        self.assertIn('errno == ENOENT ? @"installerRequired"', gate)
        self.assertNotIn('FCSHA256([NSBundle.mainBundle.bundlePath', BRIDGE)
        self.assertIn('FCCompatibilityVersion(service[@"CallerPolicy"], 2)', gate)
        self.assertIn('@"updateRequired"', gate)
        self.assertIn('self.negotiatedCoreHash.UTF8String', BRIDGE)
        self.assertIn('"coreHash"', BRIDGE)


if __name__ == '__main__':
    unittest.main()
