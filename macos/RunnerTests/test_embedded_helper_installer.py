from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
BRIDGE = (ROOT / 'macos/Runner/ManagedHelperBridge.m').read_text()
TRUST = (ROOT / 'macos/Shared/HelperTrust.m').read_text()


class EmbeddedHelperInstallerSourceTests(unittest.TestCase):
    def test_fixed_json_manifest_and_only_install_package_are_sealed(self):
        payload = BRIDGE.split('- (NSData *)validatedInstallerCodeHash')[1].split('- (NSString *)installerScript:')[0]
        for token in ('Contents/Resources/HelperInstaller', 'manifest.json',
                      'Flash-helper-install.pkg', '[packages count] != 1', 'packages[@"install"]',
                      'Contents/_CodeSignature/CodeResources', 'seal[@"files2"]',
                      'entry[@"hash2"]', 'entry[@"optional"]',
                      'S_ISREG(state.st_mode)', 'state.st_nlink != 1', 'realpath(',
                      'NSJSONSerialization', 'manifest[@"schema"], 1',
                      'manifest[@"packages"]', 'package[@"file"]',
                      'FCCoreHashValid(package[@"sha256"])', 'FCSHA256(',
                      '[self validatedInstallerCodeHash]', 'installerResources:', 'FCPolicyDigest(cd, 20)',
                      'offset - 3 * 32', 'FCPolicyDigest(resources, 32)', 'FCPolicyDigest(data, 32)',
                      '[self installerDigestHex:entry[@"hash2"]]'):
            self.assertIn(token, payload)
        validation = payload.split('- (BOOL)installerResources:')[0]
        self.assertLess(validation.index('SecStaticCodeCheckValidity(code,'),
                        validation.index('SecCodeCopySigningInformation(code,'))
        self.assertIn('kSecCodeInfoUnique', validation)
        self.assertNotIn('manifest.plist', payload)
        self.assertNotIn('Flash-helper-repair.pkg', BRIDGE)
        self.assertNotIn('@"repair"', BRIDGE)
        self.assertIn('FCGUIBundleTrust(NSBundle.mainBundle.bundlePath)', BRIDGE)
        self.assertIn('kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode', TRUST)

    def test_new_install_does_not_require_installed_service(self):
        gate = BRIDGE.split('- (NSString *)installerGate')[1].split('- (NSData *)validatedInstallerCodeHash')[0]
        self.assertIn('[self effectsAllowed]', gate)
        self.assertIn('@available(macOS 14.0, *)', gate)
        self.assertNotIn('FCInstalledBundle', gate)
        self.assertNotIn('[self gate]', gate)
        install = BRIDGE.split('- (void)installWithArguments:')[1].split('- (void)openApprovalSettings:')[0]
        self.assertLess(install.index('consentRequired'), install.index('self.installInFlight = YES'))
        self.assertLess(install.index('isEqualToString:@"enabled"'), install.index('[self installerPayload:'))
        self.assertIn('[@[@"installerRequired", @"off", @"updateRequired", @"incompatible"]', install)
        self.assertNotIn('@"repairRequired"', install)
        self.assertIn('[self installerPayload:@"install"]', install)

    def test_existing_install_transaction_supports_replacement_not_recovery(self):
        preinstall = (ROOT / 'macos/packaging/installer/install/preinstall').read_text()
        postinstall = (ROOT / 'macos/packaging/installer/install/postinstall').read_text()
        maintenance = (ROOT / 'macos/PrivilegedHelper/Maintenance.m').read_text()
        begin = maintenance.split('static BOOL FCBegin(BOOL repair)')[1].split('static BOOL FCStageReady')[0]
        self.assertIn('"$guard" beginInstall', preinstall)
        self.assertNotIn('beginRepair', preinstall)
        self.assertIn('if ([action isEqual:@"beginInstall"]) return FCResult(FCBegin(NO)', maintenance)
        self.assertIn('FCAbsent(FCLock())', begin)
        self.assertIn('!FCLegacyPlistTrustedForMaintenance()', begin)
        self.assertIn('NSDictionary *state = repair ? FCTransaction() : nil', begin)
        self.assertIn('if (!repair || !FCFirstInstallPlistRecoveryAllowed', begin)
        self.assertLess(postinstall.index('" prepare'), postinstall.index('/bin/launchctl bootout'))
        self.assertLess(postinstall.index('"$guard" quiescent'), postinstall.index('"$guard" commitInstall'))

    def test_system_authorization_uses_verified_private_snapshot(self):
        script = BRIDGE.split('- (NSString *)installerScript:')[1].split('- (NSString *)installerOutcomeForAnswer:')[0]
        for token in ('with administrator privileges', 'stringByReplacingOccurrencesOfString',
                      'umask 077', '/usr/bin/mktemp -d /private/tmp/com.layoute.flash.helper.XXXXXXXX',
                      '/bin/cp', '/usr/bin/shasum -a 256', 'exit 65',
                      '/usr/sbin/installer -pkg', '-target /', 'trap ', '/usr/bin/env -i'):
            self.assertIn(token, script)
        self.assertLess(script.index('/bin/cp'), script.index('/usr/bin/shasum'))
        self.assertLess(script.index('exit 65'), script.index('/usr/sbin/installer'))
        self.assertNotIn('password', BRIDGE.lower())
        self.assertNotIn('user name', BRIDGE.lower())
        self.assertNotIn('NSLog', BRIDGE)
        self.assertNotIn('localizedDescription', BRIDGE)

    def test_recheck_is_authenticated_and_unknown_is_never_repaired(self):
        status = BRIDGE.split('- (void)status:')[1].split('- (void)request:')[0]
        self.assertIn('[self request:@"hello"', status)
        self.assertIn('[answer[@"code"] isEqual:@"ok"] ? @"enabled"', status)
        install = BRIDGE.split('- (void)installWithArguments:')[1].split('- (void)openApprovalSettings:')[0]
        self.assertLess(install.index('self.installationUncertain ||'), install.index('[self installerPayload:'))
        self.assertIn('self.connection = nil; self.connectionTrusted = NO; self.negotiatedCoreHash = nil;', install)
        self.assertIn('[self status:^(NSDictionary *after)', install)
        invoke = BRIDGE.split('- (void)invoke:')[1]
        self.assertIn('self.installInFlight', invoke)
        self.assertIn('installInProgress', invoke)
        self.assertIn('self.installationUncertain', invoke)
        self.assertIn('@"installationStatus": code', invoke)
        self.assertNotIn('dispatch_after', install)

    def test_wrapper_minimum_only_refines_authenticated_enabled_status(self):
        status = BRIDGE.split('- (void)status:')[1].split('- (void)request:')[0]
        self.assertLess(status.index('[self installationStatus]'), status.index('[self request:@"hello"'))
        self.assertLess(status.index('[self request:@"hello"'), status.index('[self serviceBuildStatus]'))
        self.assertIn('if ([code isEqualToString:@"enabled"]) code = [self serviceBuildStatus]', status)
        minimum = BRIDGE.split('- (NSString *)serviceBuildStatus {')[1].split('- (void)status:')[0]
        self.assertIn('NSBundle.mainBundle.infoDictionary[@"FlashMinimumServiceBuild"]', minimum)
        self.assertIn('[FCInstalledBundle stringByAppendingPathComponent:@"Contents/Info.plist"]', minimum)
        self.assertIn('installed:service[@"CFBundleVersion"]', minimum)
        gate = BRIDGE.split('- (NSString *)gate {')[1].split('- (NSString *)installationStatus')[0]
        self.assertLess(gate.index('FCBundleTrust(FCInstalledBundle)'), gate.index('FCReadCompatibility'))
        self.assertIn('FCCompatibilityVersion(service[@"CallerPolicy"], 2)', gate)
        self.assertNotIn('serviceBuildStatus', gate)
        invoke = BRIDGE.split('- (void)invoke:')[1]
        handshake = invoke.split('[self request:@"hello" arguments:@{}')[1]
        self.assertLess(handshake.index('if (![answer[@"code"] isEqual:@"ok"])'),
                        handshake.index('[self serviceBuildStatus]'))
        self.assertLess(handshake.index('[self serviceBuildStatus]'),
                        handshake.index('[self request:method'))
        self.assertIn('else [self request:method arguments:arguments completion:completion]', invoke)

    def test_pending_marker_precedes_auth_and_survives_bridge_recreation(self):
        self.assertIn('_installationUncertain = [self installerPending]', BRIDGE)
        persistence = BRIDGE.split('- (BOOL)installerPending')[1].split('- (BOOL)effectsAllowed')[0]
        self.assertIn('FlashHelperInstallerPending', persistence)
        self.assertIn('[defaults synchronize]', persistence)
        self.assertIn('self.installationUncertain = pending || !saved', persistence)
        install = BRIDGE.split('- (void)installWithArguments:')[1].split('- (void)openApprovalSettings:')[0]
        self.assertLess(install.index('if (![self recordInstallerPending:YES])'),
                        install.index('[self authorizeInstaller:'))
        self.assertIn('@[@"authorizationCancelled", @"authorizationDenied", @"installationFailed"]', install)
        self.assertIn('if ([status isEqualToString:@"enabled"]) [self recordInstallerPending:NO]', install)
        self.assertNotIn('installationUncertain = NO', BRIDGE)

    def test_approval_is_explicit_and_no_service_migration_is_added(self):
        approval = BRIDGE.split('- (void)openApprovalSettings:')[1].split('- (void)invoke:')[0]
        self.assertIn('isEqualToString:@"approvalRequired"', approval)
        self.assertIn('[SMAppService openSystemSettingsLoginItems]', approval)
        for token in ('SMJobBless', 'AuthorizationExecuteWithPrivileges',
                      'SMAppService daemonService', 'launchctl', 'NSTask',
                      'NSURLSession', 'curl ', 'FlashMaintenance'):
            self.assertNotIn(token, BRIDGE)


if __name__ == '__main__':
    unittest.main()
