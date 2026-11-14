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
    def test_sealed_contract_hello_actual_core_and_owned_stop(self):
        source = r'''
#import "HelperCompatibility.h"
#import <assert.h>
#import <sys/stat.h>
static NSString * const FCGUIBundle = @"/fixture-gui";
static NSString * const serviceBundle = @"/fixture-service";
static NSString * const FCInstalledBundle = @"/fixture-service";
static NSString *trust, *actualHash;
static NSDictionary *gui, *service;
static NSUInteger reads, hashReads;
static NSString *FCBundleTrust(NSString *bundle) { return trust; }
static NSString *FCGUIBundleTrust(NSString *bundle) { return @"trusted"; }
static int FixtureStat(const char *path, struct stat *st) { return 0; }
#define lstat FixtureStat
static NSDictionary *FixtureRead(NSString *bundle) {
    reads++;
    return [bundle isEqual:FCGUIBundle] ? gui : service;
}
static NSString *FCSHA256(NSString *path) {
    assert([path isEqual:@"/fixture-service/Contents/MacOS/FlClashCore"]);
    hashReads++;
    return actualHash;
}
#define FCReadCompatibility FixtureRead
@interface SupervisorFixture : NSObject
@property NSString *bundle;
@property NSString *coreHash;
@property NSDictionary *serviceContract;
@end
@implementation SupervisorFixture
'''
        source += method(SUPERVISOR, '- (NSString *)validateCompatibility')
        source += r'''
@end
@interface BridgeFixture : NSObject
@property dispatch_queue_t queue;
@property BOOL connectionTrusted;
@property NSMutableArray *calls;
@property NSString *gateCode;
@property NSString *helloCode;
@property NSUInteger gates;
@end
@implementation BridgeFixture
- (BOOL)effectsAllowed { return YES; }
- (NSString *)gate { self.gates++; return self.gateCode; }
- (NSString *)installationStatus { return @"enabled"; }
- (void)status:(void (^)(NSDictionary *))completion { completion(@{@"code": self.gateCode}); }
- (void)request:(NSString *)method arguments:(NSDictionary *)args completion:(void (^)(NSDictionary *))completion {
    [self.calls addObject:method];
    completion(@{@"code": [method isEqual:@"hello"] ? self.helloCode : @"ok"});
}
'''
        source += method(BRIDGE, '- (void)invoke:')
        source += r'''
@end
@interface GateFixture : NSObject
@end
@implementation GateFixture
- (BOOL)effectsAllowed { return YES; }
'''
        source += method(BRIDGE, '- (NSString *)gate')
        source += r'''
@end
static NSDictionary *Service(void) {
    return @{@"CallerPolicy": @2, @"ServiceAPI": @1, @"CoreAPI": @1,
        @"CoreSHA256": @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        @"CoreVersion": @"1", @"CoreRevision": @"revision"};
}
static NSString *Invoke(BridgeFixture *bridge, NSString *method) {
    __block NSString *code;
    [bridge invoke:method arguments:@{} completion:^(NSDictionary *reply) { code = reply[@"code"]; }];
    dispatch_sync(bridge.queue, ^{});
    assert(code);
    return code;
}
int main(void) {
    @autoreleasepool {
        service = Service();
        actualHash = service[@"CoreSHA256"];
        gui = @{@"CallerPolicy": @2, @"ServiceAPI": @1, @"CoreAPI": @1,
            @"AcceptedCoreSHA256": @[actualHash]};
        assert(FCCompatibilityAccepts(gui, service));
        assert(FCCompatibilityHelloMatches(gui, service, service));
        assert(!FCCompatibilityHelloMatches(gui, service, nil));
        assert(!FCCompatibilityAccepts(gui, @{}));
        for (NSString *key in service) {
            NSMutableDictionary *changed = service.mutableCopy;
            [changed removeObjectForKey:key];
            assert(!FCCompatibilityHelloMatches(gui, service, changed));
            changed[key] = @YES;
            assert(!FCCompatibilityHelloMatches(gui, service, changed));
            changed[key] = @99;
            assert(!FCCompatibilityHelloMatches(gui, service, changed));
        }
        for (NSString *key in @[@"CoreVersion", @"CoreRevision", @"CoreSHA256"]) {
            NSMutableDictionary *changed = service.mutableCopy;
            changed[key] = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            assert(!FCCompatibilityHelloMatches(gui, service, changed));
        }
        for (id bad in @[@[], @[actualHash, actualHash], @[@"bad"], @YES]) {
            NSMutableDictionary *changed = gui.mutableCopy;
            changed[@"AcceptedCoreSHA256"] = bad;
            assert(!FCCompatibilityAccepts(changed, service));
        }
        assert(!FCCompatibilityVersion(@2.0, 2));
        SupervisorFixture *supervisor = [SupervisorFixture new];
        supervisor.bundle = serviceBundle;
        trust = @"trusted";
        assert([[supervisor validateCompatibility] isEqual:@"ok"]);
        assert([supervisor.coreHash isEqual:actualHash] && supervisor.serviceContract);
        actualHash = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        assert([[supervisor validateCompatibility] isEqual:@"incompatible"]);
        assert(!supervisor.serviceContract);
        actualHash = service[@"CoreSHA256"];
        trust = @"signingRequired";
        NSUInteger beforeReads = reads, beforeHashes = hashReads;
        assert([[supervisor validateCompatibility] isEqual:@"signingRequired"]);
        assert(reads == beforeReads && hashReads == beforeHashes);
        trust = @"trusted";
        service = @{};
        assert([[supervisor validateCompatibility] isEqual:@"incompatible"]);
        assert(hashReads == beforeHashes);
        GateFixture *gate = [GateFixture new];
        assert([[gate gate] isEqual:@"updateRequired"]);
        service = Service();
        assert([[gate gate] isEqual:@"trusted"]);
        NSMutableDictionary *newer = service.mutableCopy;
        newer[@"ServiceAPI"] = @2;
        service = newer;
        assert([[gate gate] isEqual:@"incompatible"]);
        service = Service();
        BridgeFixture *bridge = [BridgeFixture new];
        bridge.queue = dispatch_queue_create("fixture-only", DISPATCH_QUEUE_SERIAL);
        bridge.calls = [NSMutableArray array];
        bridge.gateCode = @"updateRequired";
        bridge.helloCode = @"ok";
        assert([Invoke(bridge, @"start") isEqual:@"updateRequired"]);
        assert(bridge.calls.count == 0);
        bridge.gateCode = @"trusted";
        assert([Invoke(bridge, @"start") isEqual:@"ok"]);
        assert(([bridge.calls isEqual:@[@"hello", @"start"]]));
        [bridge.calls removeAllObjects];
        bridge.helloCode = @"incompatible";
        assert([Invoke(bridge, @"start") isEqual:@"incompatible"]);
        assert(([bridge.calls isEqual:@[@"hello"]]));
        bridge.connectionTrusted = YES;
        bridge.gateCode = @"incompatible";
        NSUInteger gates = bridge.gates;
        assert([Invoke(bridge, @"stop") isEqual:@"ok"]);
        assert([bridge.calls.lastObject isEqual:@"stop"] && bridge.gates == gates);
        puts("Compatibility, protected Core hash and owned-stop mocks passed; no service/Core execution");
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
        self.assertLess(start.index('[self validateCompatibility]'), start.index('FCSpawnCore('))
        self.assertIn('[hash isEqualToString:@(expected)]', start)
        stop = method(SUPERVISOR, '- (BOOL)stop')
        self.assertNotIn('Compatibility', stop)


if __name__ == '__main__':
    unittest.main()
