#import "../Runner/ManagedHelperBridge.h"
#import <assert.h>
#import "../Shared/LibraryConstraintPolicy.h"

static BOOL MockPending;
static BOOL MockWriteFails;

@interface FCManagedHelperBridge (InstallerTests)
@property dispatch_queue_t queue;
@property BOOL connectionTrusted;
- (BOOL)effectsAllowed;
- (BOOL)installerPending;
- (BOOL)writeInstallerPending:(BOOL)pending;
- (NSDictionary *)installerPayloadFromResources:(NSData *)resources manifest:(NSData *)data
    packageHashes:(NSDictionary *)hashes codeDirectory:(NSData *)directory validatedHash:(NSData *)validatedHash
    operation:(NSString *)operation;
- (NSString *)installerGate;
- (NSString *)installationStatus;
- (NSString *)serviceBuildStatus;
- (NSString *)serviceBuildStatusForMinimum:(id)minimum installed:(id)installed;
- (NSDictionary *)installerPayload:(NSString *)operation;
- (NSString *)installerScript:(NSDictionary *)payload;
- (NSString *)installerOutcomeForAnswer:(NSAppleEventDescriptor *)answer error:(NSDictionary *)error;
- (void)authorizeInstaller:(NSDictionary *)payload completion:(void (^)(NSString *))completion;
- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion;
@end

@interface InstallerMock : FCManagedHelperBridge
@property BOOL allowed;
@property NSString *trust;
@property NSString *state;
@property NSString *after;
@property NSString *hello;
@property NSString *outcome;
@property NSString *operation;
@property NSUInteger authorizations;
@property NSUInteger hellos;
@property NSUInteger starts;
@property NSUInteger relays;
@property NSUInteger buildChecks;
@property id minimumBuild;
@property id installedBuild;
@property id afterBuild;
@property BOOL invalidPayload;
@property BOOL hold;
@property(copy) void (^held)(NSString *);
@end

@implementation InstallerMock
- (instancetype)init {
    if ((self = [super init])) {
        _allowed = YES; _trust = @"trusted"; _state = @"installerRequired";
        _after = @"enabled"; _hello = @"ok"; _outcome = @"ok";
    }
    return self;
}
- (BOOL)installerPending { return MockPending; }
- (BOOL)writeInstallerPending:(BOOL)pending {
    if (MockWriteFails) return NO;
    MockPending = pending;
    return YES;
}
- (BOOL)effectsAllowed { return self.allowed; }
- (NSString *)gate { return self.trust; }
- (NSString *)installerGate { return self.allowed ? self.trust : @"disabled"; }
- (NSString *)installationStatus { return self.state; }
- (NSString *)serviceBuildStatus {
    self.buildChecks++;
    return [self serviceBuildStatusForMinimum:self.minimumBuild installed:self.installedBuild];
}
- (NSDictionary *)installerPayload:(NSString *)operation {
    self.operation = operation;
    return self.invalidPayload ? nil : @{};
}
- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    if ([method isEqualToString:@"hello"]) {
        self.hellos++;
        completion(@{@"code": self.hello});
    } else {
        if ([method isEqualToString:@"start"]) self.starts++;
        else {
            assert(([@[@"stop", @"send", @"receive"] containsObject:method]));
            self.relays++;
        }
        completion(@{@"code": @"ok"});
    }
}
- (void)authorizeInstaller:(NSDictionary *)payload completion:(void (^)(NSString *))completion {
    assert(MockPending);
    self.authorizations++;
    self.state = self.after;
    if (self.afterBuild) self.installedBuild = self.afterBuild;
    if (self.hold) self.held = completion;
    else completion(self.outcome);
}
@end

static InstallerMock *FreshMock(void) {
    MockPending = NO; MockWriteFails = NO;
    return [InstallerMock new];
}

@interface RetainedPayloadMock : InstallerMock
@property NSData *resources;
@property NSData *manifest;
@property NSDictionary *hashes;
@property NSData *directory;
@property NSData *validatedHash;
@end

@implementation RetainedPayloadMock
- (NSDictionary *)installerPayload:(NSString *)operation {
    return [self installerPayloadFromResources:self.resources manifest:self.manifest packageHashes:self.hashes
        codeDirectory:self.directory validatedHash:self.validatedHash operation:operation];
}
@end

static void Put32(NSMutableData *data, NSUInteger offset, uint32_t value) {
    uint8_t *bytes = data.mutableBytes;
    for (NSUInteger index = 0; index < 4; index++) bytes[offset + index] = value >> (24 - index * 8);
}

static NSDictionary *RetainedFixture(NSString *packageText, BOOL extraPackage) {
    NSData *package = [packageText dataUsingEncoding:NSUTF8StringEncoding];
    NSData *digest = FCPolicyDigest(package, 32);
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger index = 0; index < digest.length; index++)
        [hex appendFormat:@"%02x", ((const uint8_t *)digest.bytes)[index]];
    NSMutableDictionary *packages = [NSMutableDictionary dictionary];
    NSMutableDictionary *hashes = [NSMutableDictionary dictionary];
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"install"]) {
        NSString *name = [NSString stringWithFormat:@"Flash-helper-%@.pkg", key];
        packages[key] = @{@"file": name, @"sha256": hex}; hashes[name] = hex;
        files[[@"Resources/HelperInstaller" stringByAppendingPathComponent:name]] = @{@"hash2": digest};
    }
    if (extraPackage) packages[@"repair"] = packages[@"install"];
    NSData *manifest = [NSJSONSerialization dataWithJSONObject:@{@"schema": @1, @"packages": packages} options:0 error:nil];
    files[@"Resources/HelperInstaller/manifest.json"] = @{@"hash2": FCPolicyDigest(manifest, 32)};
    NSData *resources = [NSPropertyListSerialization dataWithPropertyList:@{@"files2": files}
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    NSMutableData *cd = [NSMutableData dataWithLength:184];
    Put32(cd, 0, 0xfade0c02); Put32(cd, 4, 184); Put32(cd, 8, 0x20400);
    Put32(cd, 16, 184); Put32(cd, 24, 3);
    ((uint8_t *)cd.mutableBytes)[36] = 32; ((uint8_t *)cd.mutableBytes)[37] = 2;
    [cd replaceBytesInRange:NSMakeRange(88, 32) withBytes:FCPolicyDigest(resources, 32).bytes];
    return @{@"resources": resources, @"manifest": manifest, @"hashes": hashes,
        @"directory": cd, @"validatedHash": FCPolicyDigest(cd, 20)};
}

static RetainedPayloadMock *RetainedMock(NSDictionary *fixture) {
    MockPending = NO; MockWriteFails = NO;
    RetainedPayloadMock *bridge = [RetainedPayloadMock new];
    bridge.resources = fixture[@"resources"]; bridge.manifest = fixture[@"manifest"];
    bridge.hashes = fixture[@"hashes"]; bridge.directory = fixture[@"directory"];
    bridge.validatedHash = fixture[@"validatedHash"];
    return bridge;
}

static NSDictionary *Invoke(InstallerMock *bridge, NSString *method, NSDictionary *arguments) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSDictionary *answer;
    [bridge invoke:method arguments:arguments completion:^(NSDictionary *value) {
        answer = value;
        dispatch_semaphore_signal(done);
    }];
    assert(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0);
    return answer;
}

static NSString *Install(InstallerMock *bridge) {
    return Invoke(bridge, @"installerInstructions", @{@"confirmed": @YES})[@"code"];
}

static void TestServiceBuildMinimum(void) {
    NSString *minimum = @"2026111408";
    for (NSString *build in @[@"2026111402", minimum, @"2026111409", @"9999999999"]) {
        InstallerMock *bridge = FreshMock();
        bridge.state = @"enabled"; bridge.minimumBuild = minimum; bridge.installedBuild = build;
        NSString *expected = [build isEqual:@"2026111402"] ? @"updateRequired" : @"enabled";
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:expected]);
        assert(bridge.hellos == 1 && bridge.buildChecks == 1 && bridge.authorizations == 0);
        assert([Invoke(bridge, @"installerInstructions", @{})[@"code"] isEqual:@"consentRequired"]);
        assert(bridge.authorizations == 0);
        bridge.afterBuild = minimum;
        assert([Install(bridge) isEqual:@"enabled"]);
        assert(bridge.authorizations == ([expected isEqual:@"updateRequired"] ? 1 : 0));
    }
    InstallerMock *legacy = FreshMock(); legacy.state = @"enabled"; legacy.installedBuild = @"2026111402";
    assert([Invoke(legacy, @"status", @{})[@"code"] isEqual:@"enabled"]);
    assert([Install(legacy) isEqual:@"enabled"] && legacy.authorizations == 0);
    NSArray *invalid = @[@"", @"202611408", @"02026111408", @"0202611408", @"2026111408.0",
        @"202611140x", @"+026111408", @" 026111408", @"２０２６１１１４０８", @2026111408, @YES,
        NSNull.null, @[], @{}, [@"9" stringByPaddingToLength:4096 withString:@"9" startingAtIndex:0]];
    InstallerMock *bridge = FreshMock();
    assert([[bridge serviceBuildStatusForMinimum:nil installed:nil] isEqual:@"enabled"]);
    assert([[bridge serviceBuildStatusForMinimum:minimum installed:nil] isEqual:@"repairRequired"]);
    for (id bad in invalid) {
        assert([[bridge serviceBuildStatusForMinimum:nil installed:bad] isEqual:@"enabled"]);
        bridge = FreshMock(); bridge.state = @"enabled"; bridge.minimumBuild = bad; bridge.installedBuild = minimum;
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:@"signingRequired"]);
        assert([Install(bridge) isEqual:@"signingRequired"] && bridge.authorizations == 0);
        bridge.minimumBuild = minimum; bridge.installedBuild = bad;
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:@"repairRequired"]);
        assert([Install(bridge) isEqual:@"repairRequired"] && bridge.authorizations == 0);
    }
    for (NSString *state in @[@"signingRequired", @"protectedInstallationRequired", @"repairRequired",
            @"approvalRequired", @"installationUnknown", @"unsupported", @"incompatible", @"updateRequired"]) {
        bridge = FreshMock(); bridge.state = state; bridge.minimumBuild = minimum; bridge.installedBuild = @"2026111402";
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:state]);
        bridge.minimumBuild = NSNull.null;
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:state]);
        assert(bridge.buildChecks == 0 && bridge.hellos == 0 && bridge.authorizations == 0);
    }
    for (NSString *hello in @[@"maintenance", @"exitUnconfirmed", @"incompatible", @"unavailable"]) {
        bridge = FreshMock(); bridge.state = @"enabled"; bridge.minimumBuild = minimum;
        bridge.installedBuild = @"2026111402"; bridge.hello = hello;
        NSString *expected = [hello isEqual:@"maintenance"] ? @"exitUnconfirmed" : hello;
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:expected]);
        assert(bridge.buildChecks == 0 && bridge.authorizations == 0);
    }
    MockPending = YES;
    bridge = [InstallerMock new]; bridge.state = @"enabled";
    bridge.minimumBuild = minimum; bridge.installedBuild = @"2026111402";
    NSDictionary *pending = Invoke(bridge, @"status", @{});
    assert([pending[@"code"] isEqual:@"installationUnknown"]);
    assert([pending[@"installationStatus"] isEqual:@"updateRequired"] && MockPending);
    assert([Install(bridge) isEqual:@"installationUnknown"] && bridge.authorizations == 0);
    MockPending = NO;
}

static void TestServiceBuildInvoke(void) {
    for (NSString *method in @[@"hello", @"start"]) {
        for (NSArray *values in @[@[@"2026111408", @"2026111402", @"updateRequired"],
                @[@"bad", @"2026111408", @"signingRequired"],
                @[@"2026111408", @"bad", @"repairRequired"],
                @[@"2026111408", @"2026111408", @"ok"],
                @[@"2026111408", @"2026111409", @"ok"]]) {
            InstallerMock *bridge = FreshMock(); bridge.state = @"enabled";
            bridge.minimumBuild = values[0]; bridge.installedBuild = values[1];
            assert([Invoke(bridge, method, @{})[@"code"] isEqual:values[2]]);
            assert(bridge.hellos == 1 && bridge.buildChecks == 1 && bridge.authorizations == 0);
            assert(bridge.starts == ([method isEqual:@"start"] && [values[2] isEqual:@"ok"] ? 1 : 0));
        }
        for (NSString *state in @[@"approvalRequired", @"installationUnknown", @"repairRequired"]) {
            InstallerMock *bridge = FreshMock(); bridge.state = state; bridge.minimumBuild = @"bad";
            assert([Invoke(bridge, method, @{})[@"code"] isEqual:state]);
            assert(bridge.hellos == 0 && bridge.buildChecks == 0 && bridge.starts == 0);
        }
        for (NSString *hello in @[@"maintenance", @"exitUnconfirmed", @"incompatible", @"unavailable"]) {
            InstallerMock *bridge = FreshMock(); bridge.state = @"enabled";
            bridge.minimumBuild = @"bad"; bridge.hello = hello;
            assert([Invoke(bridge, method, @{})[@"code"] isEqual:hello]);
            assert(bridge.hellos == 1 && bridge.buildChecks == 0 && bridge.starts == 0);
        }
        InstallerMock *bridge = FreshMock(); bridge.state = @"enabled";
        bridge.trust = @"protectedInstallationRequired"; bridge.minimumBuild = @"bad";
        assert([Invoke(bridge, method, @{})[@"code"] isEqual:bridge.trust]);
        assert(bridge.hellos == 0 && bridge.buildChecks == 0 && bridge.starts == 0);
        bridge = FreshMock(); bridge.state = @"enabled"; bridge.installedBuild = @"2026111402";
        assert([Invoke(bridge, method, @{})[@"code"] isEqual:@"ok"]);
    }
    InstallerMock *bridge = FreshMock(); bridge.state = @"enabled"; bridge.minimumBuild = @"bad";
    bridge.trust = @"signingRequired"; bridge.connectionTrusted = YES;
    for (NSString *method in @[@"stop", @"send", @"receive"])
        assert([Invoke(bridge, method, @{})[@"code"] isEqual:@"ok"]);
    assert(bridge.relays == 3 && bridge.hellos == 0 && bridge.buildChecks == 0);
}

int main(void) {
    @autoreleasepool {
        TestServiceBuildMinimum();
        TestServiceBuildInvoke();
        InstallerMock *bridge = FreshMock();
        assert([Invoke(bridge, @"installerInstructions", @{})[@"code"] isEqual:@"consentRequired"]);
        assert([Invoke(bridge, @"installerInstructions", @{@"confirmed": @1})[@"code"] isEqual:@"consentRequired"]);
        assert([Invoke(bridge, @"installerInstructions", @{@"confirmed": @YES, @"path": @"/tmp/evil"})[@"code"] isEqual:@"invalidRequest"]);
        assert(bridge.authorizations == 0);
        for (NSString *gate in @[@"unsupported", @"signingRequired", @"protectedInstallationRequired"]) {
            bridge.trust = gate;
            assert([Install(bridge) isEqual:gate]);
            assert(bridge.authorizations == 0);
        }
        bridge.allowed = NO;
        assert([Install(bridge) isEqual:@"disabled"]);
        bridge.allowed = YES; bridge.trust = @"trusted";
        bridge.state = @"enabled";
        assert([Install(bridge) isEqual:@"enabled"]);
        assert(bridge.authorizations == 0 && bridge.hellos == 1 && !bridge.operation);
        bridge.state = @"approvalRequired";
        assert([Install(bridge) isEqual:@"approvalRequired"]);
        assert(bridge.authorizations == 0);

        for (NSString *state in @[@"installerRequired", @"off", @"updateRequired", @"incompatible"]) {
            bridge = FreshMock(); bridge.state = state;
            assert([Install(bridge) isEqual:@"enabled"]);
            assert([bridge.operation isEqual:@"install"]);
            assert(bridge.authorizations == 1 && bridge.hellos == 1);
        }
        bridge = FreshMock(); bridge.state = @"repairRequired";
        assert([Install(bridge) isEqual:@"repairRequired"]);
        assert(bridge.authorizations == 0 && !bridge.operation && !MockPending);
        bridge = FreshMock(); bridge.invalidPayload = YES;
        assert([Install(bridge) isEqual:@"installerPayloadInvalid"]);
        assert(bridge.authorizations == 0);
        for (NSString *outcome in @[@"authorizationCancelled", @"authorizationDenied", @"installationFailed", @"installationUnknown"]) {
            bridge = FreshMock(); bridge.outcome = outcome; bridge.after = @"installerRequired";
            NSDictionary *answer = Invoke(bridge, @"installerInstructions", @{@"confirmed": @YES});
            assert([answer[@"code"] isEqual:outcome]);
            assert([answer[@"installationStatus"] isEqual:@"installerRequired"]);
            assert(bridge.authorizations == 1);
            if ([outcome isEqual:@"installationUnknown"]) {
                assert([Install(bridge) isEqual:@"installationUnknown"]);
                assert(bridge.authorizations == 1);
            }
        }
        bridge = FreshMock(); bridge.hello = @"exitUnconfirmed";
        assert([Install(bridge) isEqual:@"installationUnknown"]);
        assert(bridge.authorizations == 1);
        bridge.state = @"installerRequired";
        NSDictionary *unknown = Invoke(bridge, @"status", @{});
        assert([unknown[@"code"] isEqual:@"installationUnknown"]);
        assert([unknown[@"installationStatus"] isEqual:@"installerRequired"]);
        assert([Install(bridge) isEqual:@"installationUnknown"]);
        assert(bridge.authorizations == 1);
        bridge.state = @"enabled"; bridge.hello = @"ok";
        assert([Install(bridge) isEqual:@"enabled"]);
        assert(bridge.authorizations == 1);
        bridge = FreshMock(); bridge.state = @"enabled"; bridge.hello = @"unavailable";
        assert([Install(bridge) isEqual:@"installationUnknown"]);
        assert(bridge.authorizations == 0);
        bridge = FreshMock(); bridge.after = @"approvalRequired";
        assert([Install(bridge) isEqual:@"approvalRequired"]);
        assert(bridge.authorizations == 1 && bridge.hellos == 0);

        bridge = FreshMock(); bridge.hold = YES;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        [bridge invoke:@"installerInstructions" arguments:@{@"confirmed": @YES} completion:^(NSDictionary *answer) {
            assert([answer[@"code"] isEqual:@"enabled"]);
            dispatch_semaphore_signal(finished);
        }];
        assert([Install(bridge) isEqual:@"installInProgress"]);
        assert([Invoke(bridge, @"start", @{})[@"code"] isEqual:@"installInProgress"]);
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:@"installInProgress"]);
        assert(bridge.authorizations == 1);
        dispatch_async(bridge.queue, ^{ bridge.held(@"ok"); bridge.held = nil; });
        assert(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0);

        bridge = FreshMock(); bridge.outcome = @"installationUnknown"; bridge.after = @"installerRequired";
        assert([Install(bridge) isEqual:@"installationUnknown"] && MockPending);
        InstallerMock *recreated = [InstallerMock new];
        assert([Invoke(recreated, @"status", @{})[@"code"] isEqual:@"installationUnknown"]);
        assert([Install(recreated) isEqual:@"installationUnknown"] && recreated.authorizations == 0);
        recreated.state = @"enabled";
        assert([Invoke(recreated, @"status", @{})[@"code"] isEqual:@"enabled"] && !MockPending);
        recreated = [InstallerMock new];
        assert([Install(recreated) isEqual:@"enabled"] && recreated.authorizations == 1);
        bridge = FreshMock(); bridge.hold = YES;
        [bridge invoke:@"installerInstructions" arguments:@{@"confirmed": @YES} completion:^(NSDictionary *answer) {}];
        assert([Invoke(bridge, @"status", @{})[@"code"] isEqual:@"installInProgress"] && MockPending);
        recreated = [InstallerMock new];
        assert([Install(recreated) isEqual:@"installationUnknown"] && recreated.authorizations == 0);
        dispatch_sync(bridge.queue, ^{ bridge.held(@"authorizationCancelled"); bridge.held = nil; });
        assert(!MockPending);
        for (NSString *terminal in @[@"authorizationCancelled", @"authorizationDenied", @"installationFailed"]) {
            bridge = FreshMock(); bridge.outcome = terminal; bridge.after = @"installerRequired";
            assert([Install(bridge) isEqual:terminal] && !MockPending);
            recreated = [InstallerMock new];
            assert([Install(recreated) isEqual:@"enabled"] && recreated.authorizations == 1);
        }
        bridge = FreshMock(); bridge.after = @"approvalRequired";
        assert([Install(bridge) isEqual:@"approvalRequired"] && MockPending);
        recreated = [InstallerMock new]; recreated.state = @"approvalRequired";
        assert([Install(recreated) isEqual:@"approvalRequired"] && recreated.authorizations == 0 && MockPending);
        recreated.state = @"off";
        assert([Install(recreated) isEqual:@"installationUnknown"] && recreated.authorizations == 0);
        bridge = FreshMock(); MockWriteFails = YES;
        assert([Install(bridge) isEqual:@"installationUnknown"] && bridge.authorizations == 0);
        MockWriteFails = NO;
        NSDictionary *original = RetainedFixture(@"signed package bytes", NO);
        NSDictionary *substituted = RetainedFixture(@"attacker package bytes", NO);
        RetainedPayloadMock *retained = RetainedMock(original);
        assert([Install(retained) isEqual:@"enabled"] && retained.authorizations == 1);
        retained = RetainedMock(RetainedFixture(@"signed package bytes", YES));
        assert([Install(retained) isEqual:@"installerPayloadInvalid"] && retained.authorizations == 0);
        for (NSArray *replaced in @[@[@"hashes"], @[@"manifest", @"hashes"],
                @[@"resources", @"manifest", @"hashes"], @[@"resources", @"manifest", @"hashes", @"directory"]]) {
            NSMutableDictionary *swapped = [original mutableCopy];
            for (NSString *key in replaced) swapped[key] = substituted[key];
            retained = RetainedMock(swapped);
            assert([Install(retained) isEqual:@"installerPayloadInvalid"]);
            assert(retained.authorizations == 0 && !MockPending);
        }

        FCManagedHelperBridge *real = FreshMock();
        NSDictionary *errors = @{@(-128): @"authorizationCancelled", @(-60006): @"authorizationCancelled",
            @(-60005): @"authorizationDenied", @(-1743): @"authorizationDenied", @1: @"installationFailed",
            @65: @"installationFailed", @(-1712): @"installationUnknown", @0: @"installationUnknown"};
        for (NSNumber *number in errors) {
            assert([[real installerOutcomeForAnswer:nil error:@{NSAppleScriptErrorNumber: number}] isEqual:errors[number]]);
        }
        assert([[real installerOutcomeForAnswer:nil error:nil] isEqual:@"installationUnknown"]);
        assert([[real installerOutcomeForAnswer:[NSAppleEventDescriptor descriptorWithString:@""] error:nil] isEqual:@"ok"]);
        NSString *source = [real installerScript:@{@"path": @"/Applications/Flash.app/Contents/Resources/HelperInstaller/Flash-helper-install.pkg", @"sha256": [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]}];
        assert([source containsString:@"with administrator privileges"]);
        assert([source containsString:@"${actual%% *}"]);
        assert([source containsString:@"/usr/sbin/installer -pkg"]);
        assert([source containsString:@"/private/tmp/com.layoute.flash.helper.XXXXXXXX"]);
        assert(![source containsString:@"password"]);
        puts("ManagedHelperInstallerTests: PASS (mock-only; native authorization runtime UNTESTED)");
    }
    return 0;
}
