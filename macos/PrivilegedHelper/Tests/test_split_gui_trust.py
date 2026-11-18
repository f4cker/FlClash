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

    def test_gui_full_check_once_per_connection_then_kernel_per_message(self):
        gui = TRUST.split('@implementation FCGUIMessageValidator', 1)[1].split('\n@end\n', 1)[0]
        check = gui.split('- (BOOL)check:(xpc_object_t)message {', 1)[1].split('\n}\n', 1)[0]
        kernel = gui.split('- (NSString *)kernelCheck:', 1)[1].split('\n}\n', 1)[0]
        full = gui.split('- (NSString *)fullCheck:', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('@available(macOS 14.0, *)', check)
        # Same standard as before for the full validation: pinned requirement (strict), exact path, entitlements,
        # the whole bundle statically incl. nested code, and running cdhash == bundle cdhash.
        order = ['SecCodeCreateWithXPCMessage(message', 'SecCodeCheckValidity(code, kSecCSStrictValidate, requirement)',
                 'FCExecutableMatches(info, FCInstalledExecutable(FCClientIdentifier))', 'FCValidGUIHash(runningHash)',
                 'FCGUIEntitlementsAllowed', 'fileURLWithPath:FCGUIBundle', 'FCCheckGUIStatic(diskCode)',
                 'FCValidGUIHash(diskHash)', '[diskHash isEqualToData:runningHash]',
                 '[self kernelCheck:token hash:runningHash]', 'self.verifiedHash = runningHash']
        positions = [full.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))
        # The fast path: same pid and pid version, unchanged bundle, kernel status and cached cdhash.
        order = ['FCGUIRequirement()', 'FCMessageAuditToken(message, &token)', 'FCGUIBundleFingerprint()',
                 'self.verifiedHash', 'self.verifiedPid', 'self.verifiedPidVersion',
                 '[bundle isEqualToData:self.verifiedBundle]', '[self kernelCheck:&token hash:self.verifiedHash]',
                 '[self fullCheck:message requirement:text token:&token]']
        positions = [check.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))
        for item in ('FCCodeOpsStatus', 'FCCoreRequiredStatus', 'FCHelperForbiddenStatus', 'FCCodeOpsCDHash',
                     'isEqualToData:expected'):
            self.assertIn(item, kernel)
        self.assertNotIn('SecCode', kernel)
        self.assertNotIn('FCProtectedTree', gui)

    def test_copy_replies_are_checked_by_the_kernel_only(self):
        # The launcher's copy is unreadable for the app: no Security call about the running code on that path.
        copy = TRUST.split('- (BOOL)checkCopy:(xpc_object_t)message {', 1)[1].split('\n}\n', 1)[0]
        guest = TRUST.split('NSString *FCHelperGuestCheck(', 1)[1].split('\n}\n', 1)[0]
        for body in (copy, guest):
            self.assertNotIn('SecCode', body)
            self.assertNotIn('SecStaticCodeCreateWithPath', body)
        order = ['FCMessageAuditToken(message, &token)', 'FCHelperGuestCheck(&token, self.executable, &runningHash)',
                 'FCStaticCodeHash(self.sealedExecutable, self.identifier)', 'FCCompareRunningHash(runningHash, sealedHash)']
        positions = [copy.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))
        steps = ['FCCodeOpsStatus', 'FCCoreRequiredStatus', 'FCHelperForbiddenStatus', 'FCCodeOpsCDHash',
                 'FCProcPath(pid', 'failed:pid-reused', '[running isEqualToString:expectedPath]']
        positions = [guest.index(item) for item in steps]
        self.assertEqual(positions, sorted(positions))
        validator = TRUST.split('@implementation FCMessageValidator', 1)[1].split('\n@end\n', 1)[0]
        check = validator.split('- (BOOL)check:(xpc_object_t)message {', 1)[1].split('\n}\n', 1)[0]
        self.assertLess(check.index('[self checkCopy:message]'), check.index('SecCodeCreateWithXPCMessage'))
        # The bridge keeps the XPC-level pin and reports the failed step instead of a bare "unavailable".
        self.assertIn('xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)', BRIDGE)
        self.assertIn('validator.failure', BRIDGE)
        self.assertIn('os_log_create("com.layoute.flash", "bridge")', BRIDGE)
        self.assertIn('os_log_create("com.layoute.flash", "helper")', SUPERVISOR)

    def test_bridge_gates_on_app_trust_and_bundled_daemon(self):
        gate = BRIDGE.split('- (NSString *)gate {', 1)[1].split('- (NSString *)currentHelperHash', 1)[0]
        app = BRIDGE.split('- (NSString *)appGate {', 1)[1].split('- (NSString *)gate {', 1)[0]
        self.assertIn('@available(macOS 14.0, *)', app)
        self.assertIn('FCGUIBundleTrust(NSBundle.mainBundle.bundlePath)', app)
        self.assertLess(gate.index('[self appGate]'), gate.index('FCBundledDaemonPresent(FCGUIBundle)'))
        # The gate's notFound is the bundle's daemon files only (reinstall); it goes out with source: bundle. SMAppService's
        # own notFound for a bundle that passed this gate is the separate serviceNotFound (source: service).
        self.assertIn('return @"notFound"', gate)
        self.assertIn('@"source": @"bundle"', BRIDGE)
        registration = BRIDGE.split('- (NSDictionary *)registrationStatus {', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('return FCGateAnswer(gate);', registration)
        self.assertLess(registration.index('[self gate]'), registration.index('case SMAppServiceStatusNotFound:'))
        self.assertIn('@"code": @"serviceNotFound", @"source": @"service"', registration)
        self.assertNotIn('@{@"code": @"notFound"}', BRIDGE)
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
