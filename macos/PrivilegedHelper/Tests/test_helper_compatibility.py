import subprocess
import tempfile
import unittest
from pathlib import Path

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
