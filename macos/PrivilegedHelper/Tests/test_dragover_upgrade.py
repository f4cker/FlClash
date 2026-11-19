"""Pre-release check: a drag-over install from any older shipped version brings the helper up.

SIMULATED, not a real Mac: SMAppService, BTM and launchd are modelled by small fakes (status per plist name, what
register/unregister do to it, launchd's view of the job, which helper build answers hello). The bridge code under test
is the real source of ManagedHelperBridge.m (gate, registrationStatus, retired-name handling, registerWithCompletion,
recoverySequence, awaitNewHelper), compiled into a fixture. The app-side policy loop below mirrors
lib/core/desktop/macos_helper_maintenance.dart (registrationStale/retiredRegistration -> recover, at most 2 by
itself; serviceNotFound -> one `enable` per launch; staleHelper -> wait for the old helper's idle exit); its Dart
counterpart is covered by test/core/desktop/macos_helper_recovery_test.dart.

Every scenario must end at "registered" (enabled) or "approval requested" (requiresApproval / notRegistered, the
approval card), and then reach enabled once the user allows Flash; never notFound / reinstall. Nothing here runs
launchctl, SMAppService, sfltool or the app.
"""
import subprocess
import tempfile
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()


def method(prefix):
    start = BRIDGE.index(prefix)
    opening = BRIDGE.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (BRIDGE[end] == '{') - (BRIDGE[end] == '}')
        end += 1
    return BRIDGE[start:end]


SM_DOMAINS = '\n'.join(line for line in BRIDGE.splitlines()
                       if line.startswith(('static NSString * const FCSMAppServiceErrorDomain',
                                           'static NSString * const FCSMFrameworkErrorDomain')))

FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
#import <errno.h>
enum { kSMErrorAlreadyRegistered = 2, kSMErrorJobNotFound = 6, kSMErrorLaunchDeniedByUser = 11 };
typedef NS_ENUM(NSInteger, SMAppServiceStatus) { SMAppServiceStatusNotRegistered = 0, SMAppServiceStatusEnabled = 1,
    SMAppServiceStatusRequiresApproval = 2, SMAppServiceStatusNotFound = 3 };
typedef NSUInteger FCLegacyResidue;
static FCLegacyResidue FCDetectLegacyResidue(void) { return 0; }
static NSString * const FCGUIBundle = @"/Applications/Flash.app";
static NSString * const FCHelperIdentifier = @"com.layoute.flash.helper";
static NSString * const FCRetiredHelperLabel = @"com.layoute.flash.daemon";
static NSString * const FCRetiredAttemptDefault = @"FlashRetiredUnregisterAttemptedBuild";
static NSString * const FCRegisteredHelperDefault = @"FlashDaemonRegisteredHelperCDHash";
static NSString * const FCApprovedDefault = @"FlashDaemonApproved";
''' + SM_DOMAINS + r'''
// In-memory defaults: the fixture never writes the user's real preferences.
@interface FakeDefaults : NSObject
@property NSMutableDictionary *values;
@end
@implementation FakeDefaults
+ (instancetype)standardUserDefaults { static FakeDefaults *d; if (!d) d = [FakeDefaults new]; return d; }
- (instancetype)init { if ((self = [super init])) _values = [NSMutableDictionary dictionary]; return self; }
- (NSString *)stringForKey:(NSString *)key { id v = self.values[key]; return [v isKindOfClass:NSString.class] ? v : nil; }
- (BOOL)boolForKey:(NSString *)key { return [self.values[key] boolValue]; }
- (void)setBool:(BOOL)value forKey:(NSString *)key { self.values[key] = @(value); }
- (void)setObject:(id)value forKey:(NSString *)key { self.values[key] = value; }
- (void)removeObjectForKey:(NSString *)key { [self.values removeObjectForKey:key]; }
@end
#define NSUserDefaults FakeDefaults

// --- simulated system ---------------------------------------------------------------------------------------------
static BOOL appInApplications = YES;
static BOOL daemonFilesPresent = YES;
static NSString *FCGUIBundleTrustFake(void) { return appInApplications ? @"trusted" : @"moveRequired"; }
static BOOL FCBundledDaemonPresent(NSString *bundle) { return daemonFilesPresent; }
static NSString *FCInstalledExecutable(NSString *identifier) { return @"/Applications/Flash.app/Contents/Library/HelperTools/FlashHelper"; }
static BOOL FCCheckStatic(NSString *path, NSString *identifier) { return YES; }
static NSDictionary *FCReadCompatibility(NSString *bundle) { return @{}; }
static BOOL FCBundleCompatibilityValid(NSDictionary *contract) { return YES; }

// One SMAppService (one plist name) as BTM + smd present it to the app.
@interface Service : NSObject
@property SMAppServiceStatus status;
@property BOOL approvedByUser;     // the user allowed the BTM item (a new item starts disallowed)
@property BOOL registerKeepsNotFound;
@property NSMutableArray<NSString *> *log;
@property NSString *name;
@end
@implementation Service
- (BOOL)registerAndReturnError:(NSError **)error {
    [self.log addObject:[@"register " stringByAppendingString:self.name]];
    if (self.registerKeepsNotFound) {
        if (error) *error = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:3 userInfo:nil];
        return NO;
    }
    if (self.status == SMAppServiceStatusEnabled) {
        if (error) *error = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:kSMErrorAlreadyRegistered userInfo:nil];
        return NO;
    }
    if (self.approvedByUser) { self.status = SMAppServiceStatusEnabled; return YES; }
    // As on the trial Macs: a re-added daemon needs the user's approval; register reports error 1.
    self.status = SMAppServiceStatusRequiresApproval;
    if (error) *error = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1
        userInfo:@{NSLocalizedDescriptionKey: @"Operation not permitted"}];
    return NO;
}
- (NSError *)unregister {
    [self.log addObject:[@"unregister " stringByAppendingString:self.name]];
    if (self.status == SMAppServiceStatusNotFound || self.status == SMAppServiceStatusNotRegistered)
        return [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:kSMErrorJobNotFound userInfo:nil];
    self.status = SMAppServiceStatusNotRegistered;
    self.approvedByUser = NO;
    return nil;
}
@end

@interface Bridge : NSObject
@property Service *helperd;
@property Service *retired;
@property NSMutableArray<NSString *> *log;
@property BOOL launchConstraintStale;  // launchd: "needs LWCR update" until helperd is re-registered
@property BOOL oldHelperRunning;       // a helper of the previous build still answers (idle exit after 30 s)
@property NSTimeInterval clock;
@property BOOL migrationAttempted;
@property (atomic) BOOL retiredSettled;
@property BOOL serviceWasNotFound;
@property BOOL operationInFlight;
@end
@implementation Bridge
- (instancetype)init {
    if ((self = [super init])) {
        _log = [NSMutableArray array];
        _helperd = [Service new]; _helperd.name = @"helperd"; _helperd.log = _log;
        _retired = [Service new]; _retired.name = @"daemon"; _retired.log = _log;
        _helperd.status = SMAppServiceStatusNotFound; _retired.status = SMAppServiceStatusNotFound;
    }
    return self;
}
- (BOOL)effectsAllowed { return YES; }
- (NSString *)appGate { return FCGUIBundleTrustFake(); }
- (Service *)daemon { return self.helperd; }
- (Service *)retiredDaemon { return self.retired; }
- (FCLegacyResidue)legacyResidue { return 0; }
- (NSDictionary *)residueAnswer:(FCLegacyResidue)residue code:(NSString *)code { return @{@"code": code}; }
- (NSString *)bundleVersion { return @"2026111806"; }
- (FakeDefaults *)preferences { return FakeDefaults.standardUserDefaults; }
- (NSString *)currentHelperHash { return @"new"; }
- (BOOL)isBundledHelperHash:(id)reported { return [reported isEqual:[self currentHelperHash]]; }
- (void)pause:(NSTimeInterval)seconds { self.clock += seconds; }
- (NSTimeInterval)uptime { return self.clock; }
- (NSDictionary *)launchdSnapshot {
    NSString *state = self.helperd.status != SMAppServiceStatusEnabled ? @"missing" :
        self.launchConstraintStale ? @"broken" : @"idle";
    return @{@"state": state, @"summary": [@"job " stringByAppendingString:state]};
}
- (NSError *)unregisterDaemonWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    *timedOut = NO;
    NSError *error = [self.helperd unregister];
    self.launchConstraintStale = NO;  // the job (and its launch constraint record) is gone with the registration
    return error;
}
- (NSError *)unregisterRetiredWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    *timedOut = NO;
    return [self.retired unregister];
}
- (NSDictionary *)helloFromRepairQueue {
    if (self.helperd.status != SMAppServiceStatusEnabled || self.launchConstraintStale) return @{@"code": @"timeout"};
    return @{@"code": @"ok", @"helperCDHash": self.oldHelperRunning ? @"old" : @"new", @"pid": @0, @"protocol": @1};
}
// The real status: also asks launchd and the helper; this mirrors its outcomes (see -status: in the bridge).
- (void)status:(void (^)(NSDictionary *))completion {
    NSDictionary *registration = [self registrationStatus];
    if (![registration[@"code"] isEqual:@"enabled"]) { completion(registration); return; }
    if (self.launchConstraintStale) { completion(@{@"code": @"registrationStale"}); return; }
    NSDictionary *hello = [self helloFromRepairQueue];
    if (![hello[@"code"] isEqual:@"ok"]) { completion(@{@"code": @"unavailable"}); return; }
    completion(@{@"code": [hello[@"helperCDHash"] isEqual:@"new"] ? @"enabled" : @"staleHelper"});
}
''' + '\n'.join(method(m) for m in (
    'static NSString *FCErrorText', 'static BOOL FCApprovalError', 'static BOOL FCAlreadyUnregistered',
    'static NSDictionary *FCGateAnswer', 'static NSString *FCServiceStatusName',
    '- (NSString *)retiredStatusCode', '- (BOOL)retiredAttemptedThisBuild', '- (void)recordRetiredAttempt',
    '- (NSDictionary *)retiredRegistration', '- (NSString *)gate {', '- (NSDictionary *)registrationStatus',
    '- (NSString *)serviceStatusCode', '- (NSString *)retireOldRegistration:', '- (NSError *)registerDaemon',
    '- (NSDictionary *)recoverySequence', '- (NSDictionary *)awaitNewHelper:',
    '- (void)registerWithCompletion:',
)) + r'''
- (NSDictionary *)call:(NSString *)name {
    __block NSDictionary *answer;
    if ([name isEqual:@"status"]) [self status:^(NSDictionary *a) { answer = a; }];
    else if ([name isEqual:@"enable"]) [self registerWithCompletion:^(NSDictionary *a) { answer = a; }];
    else if ([name isEqual:@"recover"]) {
        // recoverWithArguments: after the full gate (the app stopped its Core and wrote its record first).
        NSString *gate = [self gate];
        if (![gate isEqualToString:@"trusted"]) return FCGateAnswer(gate);
        self.serviceWasNotFound = [[self serviceStatusCode] isEqual:@"notFound"];
        answer = [self recoverySequence];
    }
    assert(answer);
    [self.log addObject:[NSString stringWithFormat:@"%@ -> %@", name, answer[@"code"]]];
    return answer;
}
@end

// --- app policy (mirrors MacHelperMaintenance) ---------------------------------------------------------------------
static NSString *Card(NSDictionary *answer) {
    NSString *code = answer[@"code"];
    if ([code isEqual:@"serviceNotFound"] && [answer[@"afterRepair"] isEqual:@YES]) return @"serviceRepairFailed";
    if ([@[@"registrationStale", @"retiredRegistration"] containsObject:code]) return @"registrationStale";
    if ([@[@"notFound", @"incompatible"] containsObject:code]) return @"reinstall";
    if ([@[@"registrationFailed", @"migrationFailed", @"migrationIncomplete"] containsObject:code]) return @"updateFailed";
    return code;
}

// One app launch: check, with the automatic steps of that launch. Returns the card state it ends on.
static NSString *Launch(Bridge *bridge) {
    int autoRecoveries = 0; BOOL autoRegisterTried = NO;
    for (int round = 0; round < 6; round++) {
        NSDictionary *answer = [bridge call:@"status"];
        NSString *card = Card(answer);
        while ([card isEqual:@"registrationStale"] && autoRecoveries < 2) {
            autoRecoveries++;
            answer = [bridge call:@"recover"];
            card = Card(answer);
        }
        if ([card isEqual:@"serviceNotFound"] && !autoRegisterTried) {
            autoRegisterTried = YES;
            answer = [bridge call:@"enable"];
            card = Card(answer);
            if ([card isEqual:@"updateFailed"] && [answer[@"serviceStatus"] isEqual:@"notFound"]) card = @"serviceNotFound";
        }
        if ([card isEqual:@"staleHelper"]) {  // the old helper's idle exit (30 s), then the bridge asks again
            bridge.clock += 40; bridge.oldHelperRunning = NO; continue;
        }
        return card;
    }
    return @"unsettled";
}

static void Expect(NSString *scenario, Bridge *bridge, NSArray *accepted) {
    NSString *card = Launch(bridge);
    if (![accepted containsObject:card]) {
        fprintf(stderr, "%s: ended at %s\n%s\n", scenario.UTF8String, card.UTF8String,
            [bridge.log componentsJoinedByString:@"\n"].UTF8String);
        exit(1);
    }
    assert(![card isEqual:@"reinstall"]);
    // Approval requested: the user allows Flash once (the approval card's button registers a notRegistered daemon
    // first), then the next check reads enabled.
    if (![card isEqual:@"enabled"] && ![card isEqual:@"moveRequired"]) {
        bridge.helperd.approvedByUser = YES;
        if ([card isEqual:@"notRegistered"]) [bridge call:@"enable"];
        else if (bridge.helperd.status == SMAppServiceStatusRequiresApproval) bridge.helperd.status = SMAppServiceStatusEnabled;
        NSString *after = Card([bridge call:@"status"]);
        if (![after isEqual:@"enabled"]) {
            fprintf(stderr, "%s: after approval %s\n%s\n", scenario.UTF8String, after.UTF8String,
                [bridge.log componentsJoinedByString:@"\n"].UTF8String);
            exit(1);
        }
    }
    printf("%s: %s\n", scenario.UTF8String, card.UTF8String);
    [FakeDefaults.standardUserDefaults.values removeAllObjects];
}

int main(void) { @autoreleasepool {
    NSArray *registeredOrApproval = @[@"enabled", @"requiresApproval", @"notRegistered"];
    Bridge *b;

    // 17:11 field log (mitm.6/7 -> mitm.7/8): BTM holds only the retired item, disabled; helperd never registered.
    for (NSNumber *retired in @[@(SMAppServiceStatusNotRegistered), @(SMAppServiceStatusNotFound)]) {
        b = [Bridge new]; b.retired.status = retired.integerValue;
        Expect([NSString stringWithFormat:@"retired item disabled (reads %ld), helperd never registered", (long)retired.integerValue],
            b, registeredOrApproval);
        assert([b.log containsObject:@"register helperd"] && ![b.log containsObject:@"enable -> notFound"]);
    }
    // The disabled retired item reads requiresApproval: the existing migration unregisters it, then registers helperd.
    b = [Bridge new]; b.retired.status = SMAppServiceStatusRequiresApproval;
    Expect(@"retired item disabled (reads requiresApproval), helperd never registered", b, registeredOrApproval);
    assert([b.log indexOfObject:@"unregister daemon"] < [b.log indexOfObject:@"register helperd"]);
    // mitm.1-3 -> now: the retired name is enabled (its job may not spawn), helperd never registered.
    b = [Bridge new]; b.retired.status = SMAppServiceStatusEnabled; b.retired.approvedByUser = YES;
    Expect(@"retired item enabled, helperd never registered (notFound)", b, registeredOrApproval);
    b = [Bridge new]; b.retired.status = SMAppServiceStatusEnabled; b.helperd.status = SMAppServiceStatusNotRegistered;
    Expect(@"retired item enabled, helperd never registered (notRegistered)", b, registeredOrApproval);
    // Fresh name, nothing old: helperd reads notRegistered or notFound.
    b = [Bridge new]; b.helperd.status = SMAppServiceStatusNotRegistered;
    Expect(@"helperd never registered (notRegistered)", b, registeredOrApproval);
    b = [Bridge new];
    Expect(@"helperd never registered (notFound)", b, registeredOrApproval);
    // mitm.4-8 -> now: helperd enabled, the previous build's helper still answers (old cdhash) until its idle exit.
    b = [Bridge new]; b.helperd.status = SMAppServiceStatusEnabled; b.helperd.approvedByUser = YES; b.oldHelperRunning = YES;
    Expect(@"helperd enabled, old-cdhash helper running", b, @[@"enabled"]);
    assert(![b.log containsObject:@"unregister helperd"] && ![b.log containsObject:@"register helperd"]);
    // helperd enabled but launchd cannot spawn it (launch constraint not refreshed): the stale-registration recovery.
    b = [Bridge new]; b.helperd.status = SMAppServiceStatusEnabled; b.helperd.approvedByUser = YES; b.launchConstraintStale = YES;
    Expect(@"helperd enabled, launch constraint stale", b, registeredOrApproval);
    // helperd waiting for approval (switched off, or never allowed).
    b = [Bridge new]; b.helperd.status = SMAppServiceStatusRequiresApproval;
    Expect(@"helperd requiresApproval", b, @[@"requiresApproval"]);
    // A mounted dmg copy took the BTM match: the /Applications copy reads notFound (as the field case); and the
    // dmg copy itself, if opened, asks to be moved (never reinstall).
    b = [Bridge new]; b.retired.status = SMAppServiceStatusNotRegistered;
    Expect(@"mounted dmg duplicate, /Applications copy reads notFound", b, registeredOrApproval);
    appInApplications = NO;
    b = [Bridge new];
    Expect(@"running from the mounted dmg", b, @[@"moveRequired"]);
    appInApplications = YES;
    // Register keeps reading notFound: the Repair card (user-triggered), never reinstall, and no loop.
    b = [Bridge new]; b.helperd.registerKeepsNotFound = YES;
    NSString *card = Launch(b);
    assert([card isEqual:@"serviceNotFound"]);
    NSUInteger registers = 0; for (NSString *line in b.log) registers += [line isEqual:@"register helperd"];
    assert(registers == 1);
    printf("register keeps notFound: %s (one automatic register)\n", card.UTF8String);
    // Bundle files really missing: reinstall stays reinstall (source: bundle), and nothing is registered.
    daemonFilesPresent = NO;
    b = [Bridge new];
    assert([Launch(b) isEqual:@"reinstall"] && ![b.log containsObject:@"register helperd"]);
    puts("ok");
} }
'''


class DragOverUpgradeTests(unittest.TestCase):
    def test_every_older_version_state_ends_registered_or_approval_requested(self):
        with tempfile.TemporaryDirectory(prefix='flash-dragover-') as directory:
            root = Path(directory)
            (root / 'fixture.m').write_text(FIXTURE)
            compiled = subprocess.run(
                ['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-unused-function', '-mmacosx-version-min=14.0',
                 str(root / 'fixture.m'), '-framework', 'Foundation', '-o', str(root / 'fixture')],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn('ok', result.stdout)
            print(result.stdout)


if __name__ == '__main__':
    unittest.main()
