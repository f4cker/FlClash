import hashlib
import importlib.util
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MACOS = Path(__file__).resolve().parents[2]
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()


def method(source, declaration):
    start = source.index(declaration)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class CompatibilityTests(unittest.TestCase):
    def test_bundle_contract_hello_and_relay_gating(self):
        source = r'''
#import "HelperCompatibility.h"
#import <assert.h>
static NSString * const FCGUIBundle = @"/fixture-gui";
static NSDictionary *contract;
static NSUInteger reads;
static NSDictionary *FixtureRead(NSString *bundle) {
    assert([bundle isEqual:FCGUIBundle]);
    reads++;
    return contract;
}
#define FCReadCompatibility FixtureRead
@interface SupervisorFixture : NSObject
@property NSDictionary *contract;
@end
@implementation SupervisorFixture
'''
        source += method(SUPERVISOR, '- (NSString *)validateCompatibility')
        source += r'''
@end
@interface BridgeFixture : NSObject
@property dispatch_queue_t queue;
@property BOOL connectionTrusted;
@property BOOL operationInFlight;
@property NSMutableArray *calls;
@property NSString *registration;
@property NSString *helloCode;
@property NSString *helperHash;
@property NSUInteger gates;
@end
@implementation BridgeFixture
- (BOOL)effectsAllowed { return YES; }
- (NSDictionary *)registrationStatus { self.gates++; return @{@"code": self.registration}; }
- (NSString *)currentHelperHash { return @"cdhash-current"; }
- (void)status:(void (^)(NSDictionary *))completion { completion(@{@"code": self.registration}); }
- (void)migrateWithArguments:(NSDictionary *)a completion:(void (^)(NSDictionary *))c { [self.calls addObject:@"migrate"]; c(@{@"code": @"ok"}); }
- (void)registerWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"register"]; c(@{@"code": @"ok"}); }
- (void)unregisterWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"unregister"]; c(@{@"code": @"ok"}); }
- (void)repairWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"repair"]; c(@{@"code": @"ok"}); }
- (void)openApprovalSettings:(void (^)(NSDictionary *))c { [self.calls addObject:@"settings"]; c(@{@"code": @"ok"}); }
- (void)request:(NSString *)method arguments:(NSDictionary *)args completion:(void (^)(NSDictionary *))completion {
    [self.calls addObject:method];
    if ([method isEqual:@"hello"]) completion(@{@"code": self.helloCode, @"helperCDHash": self.helperHash});
    else completion(@{@"code": @"ok"});
}
'''
        source += method(BRIDGE, '- (void)invoke:')
        source += r'''
@end
static NSDictionary *Contract(void) {
    return @{@"CallerPolicy": @3, @"ServiceAPI": @1, @"CoreAPI": @1,
        @"CoreSHA256": @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        @"CoreVersion": @"1", @"CoreRevision": @"revision"};
}
static NSString *Invoke(BridgeFixture *bridge, NSString *method, NSDictionary *arguments) {
    __block NSString *code;
    [bridge invoke:method arguments:arguments completion:^(NSDictionary *reply) { code = reply[@"code"]; }];
    dispatch_sync(bridge.queue, ^{});
    assert(code);
    return code;
}
int main(void) {
    @autoreleasepool {
        NSDictionary *own = Contract();
        assert(FCBundleCompatibilityValid(own));
        assert(FCCompatibilityHelloMatches(own, own));
        assert(!FCCompatibilityHelloMatches(own, nil));
        assert(!FCCompatibilityHelloMatches(nil, own));
        for (NSString *key in own) {
            NSMutableDictionary *changed = own.mutableCopy;
            [changed removeObjectForKey:key];
            assert(!FCBundleCompatibilityValid(changed));
            assert(!FCCompatibilityHelloMatches(own, changed));
            changed[key] = @YES;
            assert(!FCCompatibilityHelloMatches(own, changed));
            changed[key] = @99;
            assert(!FCCompatibilityHelloMatches(own, changed));
        }
        for (NSString *key in @[@"CoreVersion", @"CoreRevision", @"CoreSHA256"]) {
            NSMutableDictionary *changed = own.mutableCopy;
            changed[key] = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            assert(!FCCompatibilityHelloMatches(own, changed));
        }
        // The legacy split contracts (CallerPolicy 2, AcceptedCoreSHA256) are no longer accepted.
        NSMutableDictionary *legacy = own.mutableCopy;
        legacy[@"CallerPolicy"] = @2;
        assert(!FCBundleCompatibilityValid(legacy));
        NSMutableDictionary *extra = own.mutableCopy;
        extra[@"AcceptedCoreSHA256"] = @[own[@"CoreSHA256"]];
        assert(!FCBundleCompatibilityValid(extra));
        NSMutableDictionary *upper = own.mutableCopy;
        upper[@"CoreSHA256"] = [own[@"CoreSHA256"] uppercaseString];
        assert(!FCBundleCompatibilityValid(upper));
        assert(!FCCompatibilityVersion(@3.0, 3));
        assert(!FCCompatibilityVersion(@YES, 1));
        SupervisorFixture *supervisor = [SupervisorFixture new];
        contract = own;
        assert([[supervisor validateCompatibility] isEqual:@"ok"] && [supervisor.contract isEqual:own]);
        contract = legacy;
        assert([[supervisor validateCompatibility] isEqual:@"incompatible"] && !supervisor.contract);
        contract = nil;
        assert([[supervisor validateCompatibility] isEqual:@"incompatible"]);

        BridgeFixture *bridge = [BridgeFixture new];
        bridge.queue = dispatch_queue_create("fixture-only", DISPATCH_QUEUE_SERIAL);
        bridge.calls = [NSMutableArray array];
        bridge.helloCode = @"ok";
        bridge.helperHash = @"cdhash-current";
        for (NSString *state in @[@"migrationRequired", @"requiresApproval", @"notRegistered", @"notFound", @"signingRequired"]) {
            bridge.registration = state;
            assert([Invoke(bridge, @"start", @{}) isEqual:state]);
            assert(bridge.calls.count == 0);
        }
        bridge.registration = @"enabled";
        assert([Invoke(bridge, @"start", @{}) isEqual:@"ok"]);
        assert(([bridge.calls isEqual:@[@"hello", @"start"]]));
        [bridge.calls removeAllObjects];
        bridge.helperHash = @"cdhash-previous-build";
        assert([Invoke(bridge, @"start", @{}) isEqual:@"staleHelper"]);
        assert(([bridge.calls isEqual:@[@"hello"]]));
        [bridge.calls removeAllObjects];
        bridge.helperHash = @"cdhash-current";
        bridge.helloCode = @"incompatible";
        assert([Invoke(bridge, @"start", @{}) isEqual:@"incompatible"]);
        assert(([bridge.calls isEqual:@[@"hello"]]));
        bridge.connectionTrusted = YES;
        bridge.registration = @"notRegistered";
        NSUInteger gates = bridge.gates;
        assert([Invoke(bridge, @"stop", @{}) isEqual:@"ok"]);
        assert([bridge.calls.lastObject isEqual:@"stop"] && bridge.gates == gates);
        assert([Invoke(bridge, @"enable", @{@"x": @1}) isEqual:@"invalidRequest"]);
        assert([Invoke(bridge, @"bogus", @{}) isEqual:@"invalidRequest"]);
        assert([Invoke(bridge, @"installerInstructions", @{}) isEqual:@"invalidRequest"]);
        assert([Invoke(bridge, @"coreIdentity", @{}) isEqual:@"invalidRequest"]);
        for (NSString *name in @[@"migrate", @"enable", @"disable", @"repair", @"openApprovalSettings"]) {
            [bridge.calls removeAllObjects];
            Invoke(bridge, name, @{});
            assert(bridge.calls.count == 1);
        }
        bridge.operationInFlight = YES;
        assert([Invoke(bridge, @"enable", @{}) isEqual:@"operationInProgress"]);
        assert([Invoke(bridge, @"stop", @{}) isEqual:@"ok"]);
        puts("Bundle contract, hello negotiation and relay gating mocks passed; no daemon/Core execution");
    }
}
'''
        with tempfile.TemporaryDirectory(prefix='flash-compat-unit-') as directory:
            root = Path(directory)
            (root / 'compat.m').write_text(source)
            result = subprocess.run([
                'clang', '-fobjc-arc', '-fblocks', '-Werror', '-I', str(MACOS / 'Shared'),
                str(root / 'compat.m'), '-framework', 'Foundation', '-o', str(root / 'compat'),
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(root / 'compat')], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def compile_and_run(self, source, *arguments):
        with tempfile.TemporaryDirectory(prefix='flash-compat-unit-') as directory:
            root = Path(directory)
            (root / 'fixture.m').write_text(source)
            result = subprocess.run([
                'clang', '-fobjc-arc', '-fblocks', '-Werror', '-I', str(MACOS / 'Shared'),
                str(root / 'fixture.m'), '-framework', 'Foundation', '-o', str(root / 'fixture'),
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(root / 'fixture'), *map(str, arguments)],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

    def test_packaging_sealed_contract_is_what_the_native_readers_accept(self):
        # The tracked packaging step writes the contract; the real FCReadCompatibility/FCBundleCompatibilityValid
        # must accept exactly that Info.plist and fail closed when the key is missing or malformed.
        spec = importlib.util.spec_from_file_location('compat_stage', MACOS / 'packaging/stage_bundle_payload.py')
        stage = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(stage)
        source = r'''
#import "HelperCompatibility.h"
#import <stdio.h>
int main(int argc, char **argv) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *bundle = @(argv[i] + 1);
            BOOL expected = argv[i][0] == '+';
            NSDictionary *contract = FCReadCompatibility(bundle);
            if (FCBundleCompatibilityValid(contract) != expected) {
                fprintf(stderr, "unexpected verdict for %s\n", argv[i]);
                return 1;
            }
            if (expected) printf("%s\n", [contract[@"CoreSHA256"] UTF8String]);
        }
    }
    return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix='flash-compat-bundles-') as directory:
            root = Path(directory).resolve()
            macho = bytes.fromhex('cffaedfe') + b'synthetic-never-execute'

            def bundle(name, info, binary=False):
                app = root / name / 'Flash.app'
                for relative, data, mode in (
                        (stage.CORE, macho, 0o755),
                        (stage.HELPER, macho + plistlib.dumps({'CFBundleIdentifier': stage.HELPER_ID}), 0o755),
                        (stage.DAEMON_PLIST, plistlib.dumps(stage.DAEMON_SCHEMA), 0o644),
                        ('Contents/Info.plist', plistlib.dumps(
                            info, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML), 0o644)):
                    path = app / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(data)
                    path.chmod(mode)
                return app

            base = {'CFBundleIdentifier': 'com.layoute.flash'}
            sealed, sealed_binary = bundle('xml', base), bundle('binary', base, binary=True)
            verified = lambda *args: subprocess.CompletedProcess(args, 0, b'', b'')
            with patch.object(stage, 'codesign', side_effect=verified):
                for app in (sealed, sealed_binary):
                    stage.seal_compatibility(app, 'v1.19.34', '13e00727c64d2cc4d0bb20e293732d02c3ed0382')
            contract = stage.read_contract(sealed)
            missing = bundle('missing', base)
            wrong_type = bundle('wrong-type', dict(base, FlashHelperCompatibility=['not', 'a', 'dict']))
            legacy = bundle('legacy', dict(base, FlashHelperCompatibility=dict(contract, CallerPolicy=2)))
            boolean = bundle('boolean', dict(base, FlashHelperCompatibility=dict(contract, ServiceAPI=True)))
            no_info = root / 'no-info/Flash.app'
            no_info.mkdir(parents=True)
            output = self.compile_and_run(
                source, '+' + str(sealed), '+' + str(sealed_binary), '-' + str(missing), '-' + str(wrong_type),
                '-' + str(legacy), '-' + str(boolean), '-' + str(no_info))
            self.assertEqual(output.split(), [hashlib.sha256(macho).hexdigest()] * 2)

    def test_start_fails_closed_without_contract_before_staging_or_spawning_core(self):
        source = r'''
#import "HelperCompatibility.h"
#import <xpc/xpc.h>
#import <assert.h>
static NSString * const FCGUIBundle = @"/fixture-gui";
static NSString * const FCRuntimeDirectory = @"/fixture-runtime";
static NSString * const FCCoreRelativePath = @"Contents/MacOS/FlClashCore";
static NSString * const FCCoreIdentifier = @"com.layoute.flash.core";
static NSDictionary *contract;
static NSMutableArray *effects;
static NSDictionary *FixtureRead(NSString *bundle) { assert([bundle isEqual:FCGUIBundle]); return contract; }
#define FCReadCompatibility FixtureRead
static uid_t FixtureEuid(xpc_connection_t c) { return 501; }
static gid_t FixtureEgid(xpc_connection_t c) { return 20; }
static const char *FixtureString(xpc_object_t o, const char *key) { [effects addObject:@"coreHash"]; return "x"; }
#define xpc_connection_get_euid FixtureEuid
#define xpc_connection_get_egid FixtureEgid
#define xpc_dictionary_get_string FixtureString
static BOOL FCPrepareRuntimeDirectory(NSString *d) { [effects addObject:@"prepare"]; return YES; }
static void FCRemoveStagedCores(NSString *d) { [effects addObject:@"remove"]; }
static NSString *FCStageCore(NSString *s, NSString *d, NSString *e) { [effects addObject:@"stage"]; return nil; }
static BOOL FCCheckStatic(NSString *p, NSString *i) { [effects addObject:@"check"]; return NO; }
static pid_t FCSpawnCore(const char *c, const char *s, uid_t u, gid_t g) { [effects addObject:@"spawn"]; return 0; }
@interface SupervisorFixture : NSObject
@property NSDictionary *contract;
@property BOOL ownershipUncertain;
@property BOOL journalOwned;
@property pid_t child;
@property xpc_connection_t owner;
@property NSString *session;
@property uid_t uid;
@property NSString *coreHash;
@property NSString *corePath;
@property NSString *socketPath;
@end
@implementation SupervisorFixture
- (BOOL)selfCheck { return YES; }
- (BOOL)openRelay { [effects addObject:@"relay"]; return NO; }
- (void)closeRelay {}
- (BOOL)syncRuntime { return YES; }
- (BOOL)acceptCore { return NO; }
- (BOOL)stop { return YES; }
'''
        source += method(SUPERVISOR, '- (NSString *)validateCompatibility')
        source += method(SUPERVISOR, '- (NSString *)start:')
        source += r'''
@end
int main(void) {
    @autoreleasepool {
        effects = [NSMutableArray array];
        SupervisorFixture *supervisor = [SupervisorFixture new];
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        xpc_connection_t connection = nil;  // never resumed: the fixture only reads euid/egid through stubs
        NSDictionary *valid = @{@"CallerPolicy": @3, @"ServiceAPI": @1, @"CoreAPI": @1,
            @"CoreSHA256": @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            @"CoreVersion": @"v1.19.34", @"CoreRevision": @"13e00727"};
        NSMutableDictionary *legacy = valid.mutableCopy;
        legacy[@"CallerPolicy"] = @2;
        NSMutableDictionary *partial = valid.mutableCopy;
        [partial removeObjectForKey:@"CoreSHA256"];
        for (id candidate in @[[NSNull null], legacy, partial]) {
            contract = candidate == [NSNull null] ? nil : candidate;
            supervisor.contract = valid;
            assert([[supervisor start:request connection:connection session:@"s"] isEqual:@"incompatible"]);
            assert(supervisor.contract == nil && supervisor.child == 0 && !supervisor.session);
            assert(effects.count == 0);
        }
        // With a valid sealed contract start proceeds to the Core hash check (and only then to staging).
        contract = valid;
        assert([[supervisor start:request connection:connection session:@"s"] isEqual:@"incompatible"]);
        assert([supervisor.contract isEqual:valid] && [effects isEqual:@[@"coreHash"]]);
        puts("Missing/invalid contract fails closed before Core staging or spawn");
    }
}
'''
        self.assertIn('Missing/invalid contract fails closed', self.compile_and_run(source))

    def test_core_identity_checks_off_the_bridge_queue(self):
        identity = method(BRIDGE, '- (NSString *)coreIdentity')
        on_queue = method(identity, 'dispatch_sync(self.queue, ^')
        for check in ('FCCoreGuestCheck', 'FCBundledCoreHash'):
            self.assertNotIn(check, on_queue)
            self.assertEqual(BRIDGE.count(check + '('), 1, check)
        self.assertLess(identity.index('self.hashSession != session'), identity.index('FCBundledCoreHash()'))

    def test_authentication_precedes_capabilities_and_only_hello_negotiates(self):
        request = method(BRIDGE, '- (void)request:')
        self.assertLess(request.index('[self.validator check:reply]'), request.index('FCCompatibilityHelloMatches'))
        self.assertLess(request.index('FCCompatibilityHelloMatches'), request.index('self.connectionTrusted = YES'))
        self.assertIn('self.negotiatedCoreHash = nil', request)
        self.assertNotIn('FCSHA256', request)
        self.assertIn('self.negotiatedCoreHash.UTF8String', request)
        self.assertIn('[method isEqualToString:@"hello"] && [answer[@"code"] isEqual:@"ok"]', request)
        start = method(SUPERVISOR, '- (NSString *)start:')
        self.assertLess(start.index('[self selfCheck]'), start.index('[self validateCompatibility]'))
        self.assertLess(start.index('[self validateCompatibility]'), start.index('FCStageCore('))
        self.assertLess(start.index('FCStageCore('), start.index('FCCheckStatic(staged, FCCoreIdentifier)'))
        self.assertLess(start.index('FCCheckStatic(staged, FCCoreIdentifier)'), start.index('FCSpawnCore('))
        self.assertIn('FCSpawnCore(staged.fileSystemRepresentation', start)
        self.assertIn('[@(expected) isEqualToString:self.contract[@"CoreSHA256"]]', start)
        stop = method(SUPERVISOR, '- (BOOL)stop')
        self.assertNotIn('Compatibility', stop)


if __name__ == '__main__':
    unittest.main()
