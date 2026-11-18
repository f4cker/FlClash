"""Stale-registration recovery after an app update (pure fixtures: launchctl, SMAppService and the daemon are
simulated; nothing here runs launchctl, registers or unregisters anything).

Covers: parsing of `launchctl print system/com.layoute.flash.helperd` (running, needs LWCR update + spawn failed,
job not found); every branch of the recovery sequence; the move from the retired registration name
(com.layoute.flash.daemon) to the new one; registration errors that only mean "allow it in System Settings";
status reporting a stale registration without sending hello.
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


def compile_and_run(test, source):
    with tempfile.TemporaryDirectory(prefix='flash-recovery-') as directory:
        root = Path(directory)
        (root / 'fixture.m').write_text(source)
        compiled = subprocess.run(
            ['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-unused-function', '-mmacosx-version-min=14.0',
             '-I', str(MACOS / 'Shared'), str(root / 'fixture.m'), '-framework', 'Foundation',
             '-o', str(root / 'fixture')], capture_output=True, text=True, timeout=60)
        test.assertEqual(compiled.returncode, 0, compiled.stderr)
        result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=20)
        test.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return result.stdout


RUNNING = r'''system/com.layoute.flash.helperd = {
	active count = 1
	path = (submitted by smd.412)
	type = LaunchDaemon
	state = running

	program identifier = Contents/Library/HelperTools/FlashHelper (mode: 2)
	parent bundle identifier = com.layoute.flash
	parent bundle version = 2026111710
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.x/Listeners
	}

	domain = system
	runs = 1
	pid = 812
	immediate reason = ipc (mach)
	last exit code = (never exited)

	endpoints = {
		"com.layoute.flash.helperd" = {
			port = 0x6b03
			active = 1
		}
	}

	properties = inferred program | managed LWCR
}
'''

BROKEN = r'''system/com.layoute.flash.helperd = {
	active count = 0
	path = (submitted by smd.412)
	type = LaunchDaemon
	state = spawn failed

	program identifier = Contents/Library/HelperTools/FlashHelper (mode: 2)
	parent bundle identifier = com.layoute.flash
	parent bundle version = 2026111704

	domain = system
	runs = 117
	last exit code = 78: EX_CONFIG
	spawn type = daemon (3)
	jetsam priority = 40

	endpoints = {
		"com.layoute.flash.helperd" = {
			port = 0x2a03
			active = 0
		}
	}

	properties = inferred program | managed LWCR | needs LWCR update
}
'''

MISSING = 'Bad request.\nCould not find service "com.layoute.flash.helperd" in domain for system\n'


def objc_string(text):
    return '@"' + text.replace('\\', '\\\\').replace('"', '\\"').replace('\t', '\\t').replace('\n', '\\n') + '"'


class LaunchdParseTests(unittest.TestCase):
    def test_three_samples(self):
        source = r'''
#import "LaunchdProbe.h"
#import <assert.h>
int main(void) { @autoreleasepool {
    NSDictionary *running = FCParseLaunchdPrint(''' + objc_string(RUNNING) + r''', 0, @"2026111710");
    assert([running[@"state"] isEqual:@"running"] && [running[@"pid"] isEqual:@812]);
    assert([running[@"needsLWCR"] isEqual:@NO] && [running[@"versionStale"] isEqual:@NO]);
    // The nested endpoint's "active = 1" and environment lines do not leak into the job's fields.
    assert([running[@"lastExit"] isEqual:@0]);
    // An update replaced the app while launchd still runs the previous build's helper.
    assert([FCParseLaunchdPrint(''' + objc_string(RUNNING) + r''', 0, @"2026111711")[@"versionStale"] isEqual:@YES]);

    NSDictionary *broken = FCParseLaunchdPrint(''' + objc_string(BROKEN) + r''', 0, @"2026111710");
    assert([broken[@"state"] isEqual:@"broken"] && [broken[@"pid"] isEqual:@0]);
    assert([broken[@"spawnFailed"] isEqual:@YES] && [broken[@"needsLWCR"] isEqual:@YES]);
    assert([broken[@"lastExit"] isEqual:@78] && [broken[@"versionStale"] isEqual:@YES]);
    assert([broken[@"summary"] containsString:@"needsLWCR=yes"] && [broken[@"summary"] containsString:@"2026111704"]);

    NSDictionary *missing = FCParseLaunchdPrint(''' + objc_string(MISSING) + r''', 113, @"2026111710");
    assert([missing[@"state"] isEqual:@"missing"]);

    // Anything else is unknown, never "healthy" and never "missing".
    assert([FCParseLaunchdPrint(@"", 0, @"1")[@"state"] isEqual:@"unknown"]);
    assert([FCParseLaunchdPrint(@"Operation not permitted\n", 1, @"1")[@"state"] isEqual:@"unknown"]);
    assert([FCParseLaunchdPrint(@"system/x = {\n\tstate = running\n", 0, @"1")[@"state"] isEqual:@"unknown"]);
    // A loaded on-demand job that is simply not running is not broken.
    assert([FCParseLaunchdPrint(@"system/x = {\n\tstate = not running\n\tlast exit code = 0\n}\n", 0, @"1")[@"state"]
        isEqual:@"idle"]);
    // A last exit code alone never means the registration is stale: 78 is idle; 79 (the helper refused) and 81–87
    // (the launcher stopped) are refusals, also when launchd calls the start "spawn failed".
    NSDictionary *exit78 = FCParseLaunchdPrint(@"system/x = {\n\tstate = not running\n\tlast exit code = 78: EX_CONFIG\n}\n", 0, @"1");
    assert([exit78[@"state"] isEqual:@"idle"] && [exit78[@"refused"] isEqual:@NO] && [exit78[@"lastExit"] isEqual:@78]);
    for (NSNumber *code in @[@79, @81, @82, @83, @84, @85, @86, @87]) {
        for (NSString *jobState in @[@"not running", @"spawn failed"]) {
            NSString *text = [NSString stringWithFormat:@"system/x = {\n\tstate = %@\n\tlast exit code = %@\n}\n", jobState, code];
            NSDictionary *job = FCParseLaunchdPrint(text, 0, @"1");
            assert([job[@"state"] isEqual:@"idle"] && [job[@"refused"] isEqual:@YES] && [job[@"lastExit"] isEqual:code]);
        }
    }
    for (NSNumber *code in @[@0, @78, @80, @88]) assert(!FCRefusalExit(code.integerValue));
    // launchd's own word: spawn failed (without a refusal code) or needs LWCR update.
    assert([FCParseLaunchdPrint(@"system/x = {\n\tstate = spawn failed\n\tlast exit code = 78\n}\n", 0, @"1")[@"state"]
        isEqual:@"broken"]);
    assert([FCParseLaunchdPrint(@"system/x = {\n\tstate = not running\n\tlast exit code = 84\n\tproperties = needs LWCR update\n}\n",
        0, @"1")[@"state"] isEqual:@"broken"]);
    // A running job is never refused or broken, whatever its last exit was.
    NSDictionary *again = FCParseLaunchdPrint(@"system/x = {\n\tstate = running\n\tpid = 9\n\tlast exit code = 79\n}\n", 0, @"1");
    assert([again[@"state"] isEqual:@"running"] && [again[@"refused"] isEqual:@NO]);
    puts("parsed");
} }
'''
        self.assertIn('parsed', compile_and_run(self, source))

    def test_probe_is_read_only_and_bounded(self):
        probe = (MACOS / 'Shared/LaunchdProbe.h').read_text()
        self.assertIn('@[@"print", [@"system/" stringByAppendingString:label]]', probe)
        self.assertIn('/bin/launchctl', probe)
        for verb in ('bootout', 'bootstrap', 'kickstart', 'enable', 'disable', 'kill', 'remove', 'load'):
            self.assertNotIn(f'@"{verb}"', probe)
        self.assertIn('FCLaunchdSnapshot(FCHelperLabel, [self bundleVersion], 2)', BRIDGE)


# The SMAppService error domains exactly as the bridge declares them.
SM_DOMAINS = '\n'.join(line for line in BRIDGE.splitlines()
                       if line.startswith(('static NSString * const FCSMAppServiceErrorDomain',
                                           'static NSString * const FCSMFrameworkErrorDomain')))

SEQUENCE_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
#import <errno.h>
enum { kSMErrorJobNotFound = 6, kSMErrorLaunchDeniedByUser = 11 };
static NSString * const FCRetiredHelperLabel = @"com.layoute.flash.daemon";
static NSString * const FCRetiredAttemptDefault = @"FlashRetiredUnregisterAttemptedBuild";
''' + SM_DOMAINS + r'''
''' + method('static NSString *FCErrorText') + '\n' + method('static BOOL FCApprovalError') + '\n' + method('static BOOL FCAlreadyUnregistered') + r'''
@interface FakeDefaults : NSObject
@property NSMutableDictionary *values;
@end
@implementation FakeDefaults
- (instancetype)init { if ((self = [super init])) _values = [NSMutableDictionary dictionary]; return self; }
- (NSString *)stringForKey:(NSString *)key { id v = self.values[key]; return [v isKindOfClass:NSString.class] ? v : nil; }
- (void)setObject:(id)value forKey:(NSString *)key { self.values[key] = value; }
@end
@interface Fixture : NSObject
@property NSMutableArray<NSString *> *calls;
@property NSMutableArray<NSDictionary *> *jobs;      // launchctl answers, in order; the last one repeats
@property NSMutableArray *registrations;             // NSError or NSNull per register call
@property NSMutableArray<NSString *> *statuses;      // SMAppService.status after each register
@property NSMutableArray<NSDictionary *> *hellos;    // hello answers; the last one repeats
@property BOOL unregisterTimesOut;
@property NSTimeInterval clock;
@property NSMutableArray<NSString *> *retiredStatuses;  // retired name's status, in order; the last one repeats
@property id retiredUnregister;                         // NSError, NSNull (ok) or @"timeout"
@property BOOL retiredSettled;
@property BOOL serviceWasNotFound;      // set by recoverWithArguments: from SMAppService.status before the user's recovery
@property FakeDefaults *store;           // stands in for the user defaults; shared by "launches" of one build
@property NSString *build;
@end
@implementation Fixture
- (instancetype)init {
    if ((self = [super init])) {
        _calls = [NSMutableArray array]; _hellos = [@[@{@"code": @"ok", @"helperCDHash": @"new"}] mutableCopy];
        _retiredStatuses = [@[@"notRegistered"] mutableCopy]; _retiredUnregister = NSNull.null;
        _store = [FakeDefaults new]; _build = @"2026111712";
    }
    return self;
}
static id Next(NSMutableArray *queue) { id value = queue.firstObject; if (queue.count > 1) [queue removeObjectAtIndex:0]; return value; }
- (NSDictionary *)launchdSnapshot { [self.calls addObject:@"launchd"]; return Next(self.jobs); }
- (NSError *)unregisterDaemonWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    [self.calls addObject:@"unregister"]; *timedOut = self.unregisterTimesOut;
    if (self.unregisterTimesOut) self.clock += timeout;
    return nil;
}
- (NSError *)registerDaemon {
    [self.calls addObject:@"register"];
    id value = Next(self.registrations);
    return value == NSNull.null ? nil : value;
}
- (NSString *)serviceStatusCode { [self.calls addObject:@"status"]; return Next(self.statuses); }
- (NSString *)retiredStatusCode { [self.calls addObject:@"retiredStatus"]; return Next(self.retiredStatuses); }
- (NSError *)unregisterRetiredWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    [self.calls addObject:@"retiredUnregister"];
    *timedOut = [self.retiredUnregister isEqual:@"timeout"];
    if (*timedOut) { self.clock += timeout; return nil; }
    return self.retiredUnregister == NSNull.null ? nil : self.retiredUnregister;
}
- (NSDictionary *)helloFromRepairQueue {
    [self.calls addObject:@"hello"];
    NSDictionary *answer = Next(self.hellos);
    if ([answer[@"code"] isEqual:@"timeout"]) self.clock += 8;
    return answer;
}
- (NSString *)currentHelperHash { return @"new"; }
- (void)pause:(NSTimeInterval)seconds { [self.calls addObject:[NSString stringWithFormat:@"pause %.2f", seconds]]; self.clock += seconds; }
- (NSTimeInterval)uptime { return self.clock; }
- (NSString *)bundleVersion { return self.build; }
- (NSUserDefaults *)preferences { return (NSUserDefaults *)(id)self.store; }
''' + method('- (BOOL)retiredAttemptedThisBuild') + '\n' + method('- (void)recordRetiredAttempt') + '\n' + method('- (NSDictionary *)retiredRegistration') + '\n' + method('- (NSString *)retireOldRegistration:') + '\n' + method('- (NSDictionary *)recoverySequence') + '\n' + method('- (NSDictionary *)awaitNewHelper:') + r'''
@end
static NSDictionary *Job(NSString *state) { return @{@"state": state, @"summary": [@"job " stringByAppendingString:state]}; }
static NSError *Denied(void) {
    return [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1
        userInfo:@{NSLocalizedDescriptionKey: @"Operation not permitted", @"smd": @"Job is not allowed to bootstrap"}];
}
static Fixture *New(NSArray *jobs, NSArray *registrations, NSArray *statuses) {
    Fixture *f = [Fixture new];
    f.jobs = [jobs mutableCopy]; f.registrations = [registrations mutableCopy]; f.statuses = [statuses mutableCopy];
    return f;
}
static NSUInteger Index(Fixture *f, NSString *call) { return [f.calls indexOfObject:call]; }
'''


class RecoverySequenceTests(unittest.TestCase):
    def run_main(self, body):
        return compile_and_run(self, SEQUENCE_FIXTURE + 'int main(void) { @autoreleasepool {\n' + body + '\n} }\n')

    def test_stale_job_is_replaced_and_the_new_helper_answers(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"broken"), Job(@"broken"), Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"] && [r[@"protocol"] isEqual:@1]);
    // unregister → launchd until the job is gone → ≥ 1 s → register → status → hello; no hello before.
    assert(Index(f, @"unregister") < Index(f, @"register") && Index(f, @"register") < Index(f, @"status"));
    assert(Index(f, @"status") < Index(f, @"hello"));
    assert([f.calls containsObject:@"pause 1.00"] && Index(f, @"pause 1.00") < Index(f, @"register"));
    NSArray *before = [f.calls subarrayWithRange:NSMakeRange(0, Index(f, @"register"))];
    assert(![before containsObject:@"hello"]);
    assert([r[@"detail"] containsString:@"launchd after unregister: job missing"]);
    assert([r[@"detail"] containsString:@"new helper answered"]);
    puts("ok");
''')

    def test_job_already_gone_skips_unregister(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"] && ![f.calls containsObject:@"unregister"]);
''')

    def test_unregister_without_completion_still_asks_the_system(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"broken"), Job(@"broken")], @[Denied()], @[@"requiresApproval"]);
    f.unregisterTimesOut = YES;
    NSDictionary *r = [f recoverySequence];
    assert([r[@"detail"] containsString:@"unregister: no completion within 15 s"]);
    // The job did not disappear within 5 s: the wait is bounded and the system is asked anyway.
    assert([r[@"code"] isEqual:@"requiresApproval"] && [f.calls containsObject:@"status"]);
''')

    def test_operation_not_permitted_means_allow_in_settings(self):
        self.run_main(r'''
    // As seen on the trial Mac: register fails with EPERM because the re-added item is disabled.
    Fixture *f = New(@[Job(@"broken"), Job(@"missing")], @[Denied()], @[@"requiresApproval"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"requiresApproval"] && ![f.calls containsObject:@"hello"]);
    assert([r[@"domain"] isEqual:@"SMAppServiceErrorDomain"] && [r[@"error"] isEqual:@1]);
    // The full error, userInfo included, goes into the details.
    assert([r[@"detail"] containsString:@"code=1"] && [r[@"detail"] containsString:@"Job is not allowed to bootstrap"]);
    assert([r[@"serviceStatus"] isEqual:@"requiresApproval"]);
    // EPERM while the system still says notRegistered (mitm.3 -> new name): the same, and the status is handed on.
    f = New(@[Job(@"missing")], @[Denied()], @[@"notRegistered"]);
    r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"requiresApproval"] && [r[@"serviceStatus"] isEqual:@"notRegistered"]);
    NSUInteger registers = 0; for (NSString *c in f.calls) registers += [c isEqual:@"register"];
    assert(registers == 1);
    // The same error with a status that is neither requiresApproval nor notRegistered is a failure.
    f = New(@[Job(@"missing")], @[[NSError errorWithDomain:@"SMAppServiceErrorDomain" code:11 userInfo:nil]], @[@"unknown"]);
    assert([[f recoverySequence][@"code"] isEqual:@"registrationFailed"]);
    NSError *posix = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil];
    for (NSString *status in @[@"requiresApproval", @"notRegistered"]) {
        assert(FCApprovalError(posix, status));
        assert(FCApprovalError(Denied(), status));
        assert(FCApprovalError([NSError errorWithDomain:@"SMAppServiceErrorDomain" code:kSMErrorLaunchDeniedByUser userInfo:nil], status));
        assert(FCApprovalError([NSError errorWithDomain:@"kSMErrorDomainFramework" code:EPERM userInfo:nil], status));
        // Code 1 from any other domain is not "allow it in Settings"; neither is POSIX 11 (EDEADLK).
        for (NSString *domain in @[NSCocoaErrorDomain, NSOSStatusErrorDomain, @"x", @"FlashBridge"])
            assert(!FCApprovalError([NSError errorWithDomain:domain code:1 userInfo:nil], status));
        assert(!FCApprovalError([NSError errorWithDomain:NSPOSIXErrorDomain code:kSMErrorLaunchDeniedByUser userInfo:nil], status));
        assert(!FCApprovalError([NSError errorWithDomain:@"SMAppServiceErrorDomain" code:3 userInfo:nil], status));
    }
    for (NSString *status in @[@"enabled", @"notFound", @"unknown"]) assert(!FCApprovalError(posix, status) && !FCApprovalError(Denied(), status));
    assert(!FCApprovalError(nil, @"requiresApproval"));
    // A code-1 error of another domain during recovery: registrationFailed, the raw error in the details.
    f = New(@[Job(@"missing")], @[[NSError errorWithDomain:NSCocoaErrorDomain code:1 userInfo:@{@"why": @"other"}]], @[@"notRegistered"]);
    r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"registrationFailed"] && [r[@"domain"] isEqual:NSCocoaErrorDomain]);
    assert([r[@"detail"] containsString:@"why = other"]);
''')

    def test_not_registered_registers_once_more(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[[NSError errorWithDomain:@"x" code:2 userInfo:nil], NSNull.null],
        @[@"notRegistered", @"enabled"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"]);
    NSUInteger registers = 0; for (NSString *c in f.calls) registers += [c isEqual:@"register"];
    assert(registers == 2);
    f = New(@[Job(@"missing")], @[[NSError errorWithDomain:@"x" code:2 userInfo:nil]], @[@"notRegistered"]);
    r = [f recoverySequence];
    registers = 0; for (NSString *c in f.calls) registers += [c isEqual:@"register"];
    assert([r[@"code"] isEqual:@"registrationFailed"] && registers == 2 && [r[@"domain"] isEqual:@"x"]);
''')

    def test_not_found_is_reported(self):
        self.run_main(r'''
    // Still notFound after a fresh register: its own failure (serviceNotFound after repair), with the register
    // error and status in the details; one register only, no hello, no second round.
    Fixture *f = New(@[Job(@"missing")], @[[NSError errorWithDomain:@"x" code:5 userInfo:nil]], @[@"notFound"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"serviceNotFound"] && ![f.calls containsObject:@"hello"]);
    assert([r[@"afterRepair"] isEqual:@YES] && [r[@"source"] isEqual:@"service"]);
    assert([r[@"domain"] isEqual:@"x"] && [r[@"error"] isEqual:@5] && [r[@"serviceStatus"] isEqual:@"notFound"]);
    assert([r[@"detail"] containsString:@"code=5"] && [r[@"detail"] containsString:@"status: notFound"]);
    NSUInteger registers = 0; for (NSString *c in f.calls) registers += [c isEqual:@"register"];
    assert(registers == 1);
''')

    def test_service_not_found_unregisters_then_registers(self):
        self.run_main(r'''
    // The user's repair from serviceNotFound: launchd has no job, but the system's record is unregistered first
    // anyway (its "not found" error tolerated), then registered; approval needed afterwards is not a failure.
    Fixture *f = New(@[Job(@"missing"), Job(@"missing")], @[Denied()], @[@"requiresApproval"]);
    f.serviceWasNotFound = YES;
    NSDictionary *r = [f recoverySequence];
    assert([f.calls containsObject:@"unregister"] && Index(f, @"unregister") < Index(f, @"register"));
    assert([r[@"code"] isEqual:@"requiresApproval"] && ![f.calls containsObject:@"hello"]);
    assert([r[@"detail"] containsString:@"service status before: notFound"]);
    // Enabled after the register: the new helper's hello completes it.
    f = New(@[Job(@"missing"), Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.serviceWasNotFound = YES;
    r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"]);
    assert(Index(f, @"unregister") < Index(f, @"register") && Index(f, @"register") < Index(f, @"hello"));
    // Without it (a stale registration), a missing job still skips the unregister as before.
    f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"] && ![f.calls containsObject:@"unregister"]);
''')

    def test_enabled_but_launch_constraint_not_refreshed(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle"), Job(@"broken")], @[NSNull.null], @[@"enabled"]);
    f.hellos = [@[@{@"code": @"timeout"}] mutableCopy];
    NSDictionary *r = [f recoverySequence];
    // Recorded and handed back; the sequence itself never unregisters a second time.
    assert([r[@"code"] isEqual:@"registrationStale"]);
    assert([r[@"detail"] containsString:@"launch constraint not refreshed"]);
    NSUInteger unregisters = 0; for (NSString *c in f.calls) unregisters += [c isEqual:@"unregister"];
    assert(unregisters == 0);
''')

    def test_new_helper_never_answers(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.hellos = [@[@{@"code": @"timeout"}] mutableCopy];
    NSTimeInterval start = f.clock;
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"helperNotReady"] && f.clock - start <= 1 + 15 + 9);
    // An answer from the previous build is not taken as the new helper.
    f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.hellos = [@[@{@"code": @"ok", @"helperCDHash": @"old"}] mutableCopy];
    assert([[f recoverySequence][@"code"] isEqual:@"helperNotReady"]);
    // The new helper's own refusal is final (its Core ownership is still being settled).
    f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.hellos = [@[@{@"code": @"exitUnconfirmed"}] mutableCopy];
    assert([[f recoverySequence][@"code"] isEqual:@"exitUnconfirmed"]);
    // mitm.4 on the field Mac: the helper answered but the app could not verify the reply. One hello, then stop
    // with the reason; no 15 s hello loop (that was ~15 replies the helper answered for nothing).
    f = New(@[Job(@"missing"), Job(@"running")], @[NSNull.null], @[@"enabled"]);
    f.hellos = [@[@{@"code": @"untrustedReply", @"detail": @"helper reply rejected by the app's verification: x"}] mutableCopy];
    NSDictionary *untrusted = [f recoverySequence];
    NSUInteger hellos = 0; for (NSString *c in f.calls) hellos += [c isEqual:@"hello"];
    assert([untrusted[@"code"] isEqual:@"untrustedReply"] && hellos == 1);
    assert([untrusted[@"detail"] containsString:@"hello: untrustedReply — helper reply rejected"]);
''')

    def test_untrusted_reply_is_its_own_code_and_never_re_registers(self):
        request = BRIDGE.split('- (void)request:(NSString *)method', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('untrusted = !transient;', request)
        self.assertLess(request.index('[validator check:reply]'), request.index('untrusted = !transient;'))
        # A kernel read that failed (the helper exited right after replying) is "not answering", asked again; only
        # what the kernel answered and the app refused is untrustedReply.
        self.assertLess(request.index('[validator check:reply]'), request.index('transient = validator.transientFailure;'))
        self.assertLess(request.index('transient = validator.transientFailure;'), request.index('untrusted = !transient;'))
        self.assertIn('stale ? @"staleHelper" : untrusted ? @"untrustedReply" : @"unavailable"', request)
        # The card code passes through status unchanged, and status only maps "unavailable"/"timeout" to the
        # launcher's report; nothing in status re-registers.
        self.assertIn('@"timeout", @"untrustedReply"])', BRIDGE)
        status = BRIDGE.split('- (void)status:(void (^)(NSDictionary *))completion {', 1)[1].split('\n}\n', 1)[0]
        for call in ('recoverySequence', 'registerDaemon', 'unregisterDaemon'):
            self.assertNotIn(call, status)


class RetiredNameTests(unittest.TestCase):
    """The move from com.layoute.flash.daemon (mitm.1-3) to com.layoute.flash.helperd."""

    def run_main(self, body):
        return compile_and_run(self, SEQUENCE_FIXTURE + 'int main(void) { @autoreleasepool {\n' + body + '\n} }\n')

    def test_retired_name_is_unregistered_first_then_the_new_name_registered(self):
        self.run_main(r'''
    // mitm.3 on the trial Mac: the old name is enabled (its job cannot spawn), the new name was never registered.
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[Denied()], @[@"requiresApproval"]);
    f.retiredStatuses = [@[@"enabled", @"notRegistered"] mutableCopy];
    NSDictionary *r = [f recoverySequence];
    // The retired unregister completes (its completion ran) before anything touches the new name.
    assert(Index(f, @"retiredUnregister") < Index(f, @"launchd") && Index(f, @"retiredUnregister") < Index(f, @"register"));
    // The new name had no job: nothing of it is unregistered; register error 1 means "allow it", not a failure.
    assert(![f.calls containsObject:@"unregister"]);
    assert([r[@"code"] isEqual:@"requiresApproval"] && [r[@"retiredUnregister"] isEqual:@"ok"]);
    assert([r[@"detail"] containsString:@"retired com.layoute.flash.daemon (enabled): unregister: ok; status: notRegistered"]);
    assert(f.retiredSettled && ![f.calls containsObject:@"hello"]);
    puts("ok");
''')

    def test_no_retired_name_goes_straight_to_the_new_name(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"] && !r[@"retiredUnregister"]);
    assert(![f.calls containsObject:@"retiredUnregister"] && [f.calls containsObject:@"register"]);
    assert(f.retiredSettled && ![r[@"detail"] containsString:@"retired"]);
    f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"notFound"] mutableCopy];
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"] && ![f.calls containsObject:@"retiredUnregister"]);
''')

    def test_retired_unregister_timeout_or_failure_does_not_block_the_new_name(self):
        self.run_main(r'''
    Fixture *f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"requiresApproval"] mutableCopy];
    f.retiredUnregister = @"timeout";
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"] && [r[@"retiredUnregister"] isEqual:@"timeout"]);
    assert([r[@"detail"] containsString:@"unregister: no completion within 15 s; status: requiresApproval"]);
    assert([f.calls containsObject:@"register"] && f.retiredSettled);

    f = New(@[Job(@"missing"), Job(@"idle")], @[Denied()], @[@"requiresApproval"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    f.retiredUnregister = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1 userInfo:@{@"why": @"denied"}];
    r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"requiresApproval"] && [r[@"retiredUnregister"] isEqual:@"failed"]);
    assert([r[@"detail"] containsString:@"why = denied"] && [f.calls containsObject:@"register"]);

    // Already gone by the time it is unregistered: done, not a failure.
    f = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled", @"notRegistered"] mutableCopy];
    f.retiredUnregister = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:kSMErrorJobNotFound userInfo:nil];
    assert([[f recoverySequence][@"retiredUnregister"] isEqual:@"ok"]);
''')

    def test_healthy_new_registration_is_kept_while_only_the_retired_name_goes(self):
        self.run_main(r'''
    // A later launch after a retired unregister that failed: the new name is enabled and its helper runs.
    Fixture *f = New(@[Job(@"running")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"] && [f.calls containsObject:@"retiredUnregister"]);
    assert(![f.calls containsObject:@"unregister"] && ![f.calls containsObject:@"register"]);
    // The retired unregister failed, launchd's parent bundle version lags (every update until the next login) and
    // the new job is idle: still healthy, nothing of the new name is touched.
    f = New(@[@{@"state": @"idle", @"versionStale": @YES, @"summary": @"idle stale version"}], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    f.retiredUnregister = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1 userInfo:nil];
    r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"enabled"] && [r[@"retiredUnregister"] isEqual:@"failed"]);
    assert(![f.calls containsObject:@"unregister"] && ![f.calls containsObject:@"register"]);
    // Nor when launchctl could not be read.
    f = New(@[Job(@"unknown")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    f.retiredUnregister = @"timeout";
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"]);
    assert(![f.calls containsObject:@"unregister"] && ![f.calls containsObject:@"register"]);
    // But a broken new job is still replaced.
    f = New(@[Job(@"broken"), Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"]);
    assert([f.calls containsObject:@"unregister"] && [f.calls containsObject:@"register"]);
''')

    def test_retired_unregister_is_tried_once_per_build_across_launches(self):
        self.run_main(r'''
    // First launch of this build: the retired name is still registered; one unregister, which fails.
    Fixture *first = New(@[Job(@"running")], @[NSNull.null], @[@"enabled"]);
    first.retiredStatuses = [@[@"enabled"] mutableCopy];
    first.retiredUnregister = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1 userInfo:nil];
    assert([[first retiredRegistration][@"code"] isEqual:@"retiredRegistration"]);
    NSDictionary *r = [first recoverySequence];
    assert([r[@"retiredUnregister"] isEqual:@"failed"] && [r[@"code"] isEqual:@"enabled"]);
    assert([first.store.values[FCRetiredAttemptDefault] isEqual:@"2026111712"]);
    // A later launch (new process, same defaults) of the same build: no second attempt, and status no longer
    // reports the retired name (it is a detail now), so nothing starts a recovery for it.
    Fixture *second = New(@[Job(@"running")], @[NSNull.null], @[@"enabled"]);
    second.store = first.store;
    second.retiredStatuses = [@[@"enabled"] mutableCopy];
    assert(![second retiredRegistration] && second.retiredSettled);
    second.retiredSettled = NO;
    r = [second recoverySequence];
    assert(!r[@"retiredUnregister"] && ![second.calls containsObject:@"retiredUnregister"]);
    assert(![second.calls containsObject:@"retiredStatus"]);
    // The next build tries once again.
    Fixture *next = New(@[Job(@"running")], @[NSNull.null], @[@"enabled"]);
    next.store = first.store; next.build = @"2026111713";
    next.retiredStatuses = [@[@"enabled"] mutableCopy];
    assert([[next retiredRegistration][@"code"] isEqual:@"retiredRegistration"]);
    [next recoverySequence];
    assert([next.calls containsObject:@"retiredUnregister"]);
    assert([next.store.values[FCRetiredAttemptDefault] isEqual:@"2026111713"]);
    // Seen absent: not an attempt, nothing recorded.
    Fixture *clean = New(@[Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    [clean recoverySequence];
    assert(!clean.store.values[FCRetiredAttemptDefault] && clean.retiredSettled);
    puts("once-per-build");
''')

    def test_status_reports_the_retired_name_once_and_never_registers_it(self):
        retired = method('- (NSDictionary *)retiredRegistration')
        self.assertIn('if (self.retiredSettled) return nil;', retired)
        self.assertIn('@"retiredRegistration"', retired)
        registration = method('- (NSDictionary *)registrationStatus')
        self.assertLess(registration.index('[self legacyResidue]'), registration.index('[self retiredRegistration]'))
        self.assertLess(registration.index('[self retiredRegistration]'), registration.index('[self daemon].status'))
        # The retired service is only ever asked for its status and unregistered.
        self.assertEqual(BRIDGE.count('[self retiredDaemon]'), 2)  # .status and FCUnregisterWithin
        self.assertNotIn('[[self retiredDaemon] register', BRIDGE)
        self.assertIn('FCUnregisterWithin([self retiredDaemon]', BRIDGE)
        unregister = BRIDGE[BRIDGE.index('static NSError *FCUnregisterWithin'):]
        unregister = unregister[:unregister.index('\n}\n')]
        self.assertIn('unregisterWithCompletionHandler', unregister)
        self.assertIn('dispatch_semaphore_wait', unregister)


STATUS_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
enum { SMAppServiceStatusNotRegistered = 0, SMAppServiceStatusEnabled = 1, SMAppServiceStatusRequiresApproval = 2,
    SMAppServiceStatusNotFound = 3 };
typedef NSUInteger FCLegacyResidue;
static NSString * const FCGUIBundle = @"/Applications/Flash.app";
static NSString * const FCHelperIdentifier = @"com.layoute.flash.helper";
static NSString * const FCApprovedDefault = @"FlashDaemonApproved";
static BOOL daemonFilesPresent = YES;
static BOOL FCBundledDaemonPresent(NSString *bundle) { return daemonFilesPresent; }
static NSString *FCInstalledExecutable(NSString *identifier) { return @"/fixture/FlashHelper"; }
static BOOL FCCheckStatic(NSString *path, NSString *identifier) { return YES; }
static NSDictionary *FCReadCompatibility(NSString *bundle) { return @{}; }
static BOOL FCBundleCompatibilityValid(NSDictionary *contract) { return YES; }
''' + method('static NSDictionary *FCGateAnswer') + r'''
@interface FakeService : NSObject
@property NSInteger status;
@end
@implementation FakeService
@end
@interface Bridge : NSObject
@property FakeService *service;
@property BOOL migrationAttempted;
@end
@implementation Bridge
- (NSString *)appGate { return @"trusted"; }
- (FakeService *)daemon { return self.service; }
- (FCLegacyResidue)legacyResidue { return 0; }
- (NSDictionary *)retiredRegistration { return nil; }
- (NSDictionary *)residueAnswer:(FCLegacyResidue)residue code:(NSString *)code { return @{@"code": code}; }
''' + method('- (NSString *)gate {') + '\n' + method('- (NSDictionary *)registrationStatus') + r'''
@end
'''


class FieldCase1711Tests(unittest.TestCase):
    """User log 2026-11-18 17:11: BTM holds only the retired item (FlashHelper, 16.com.layoute.flash.daemon,
    [disabled, allowed, not notified], no launchd job); there is no BTM item for com.layoute.flash.helperd at all,
    and the app showed notFound. Fixture only: SMAppService answers are simulated."""

    def run_main(self, body):
        return compile_and_run(self, SEQUENCE_FIXTURE + 'int main(void) { @autoreleasepool {\n' + body + '\n} }\n')

    def test_retired_item_only_routes_to_user_repair_of_the_new_name(self):
        self.run_main(r'''
    // The disabled retired item reads notRegistered or notFound: it is not reported (no retiredRegistration card)
    // and never surfaces as notFound itself; the notFound the user saw is the never-registered helperd.
    for (NSString *retired in @[@"notRegistered", @"notFound"]) {
        Fixture *f = New(@[Job(@"missing")], @[NSNull.null], @[@"enabled"]);
        f.retiredStatuses = [@[retired] mutableCopy];
        assert(![f retiredRegistration] && f.retiredSettled);
    }
    // The user's repair from serviceNotFound: the retired name is already gone (not touched), helperd is
    // unregistered (tolerated) and registered; the new item then waits for approval in System Settings.
    Fixture *f = New(@[Job(@"missing"), Job(@"missing")], @[Denied()], @[@"requiresApproval"]);
    f.retiredStatuses = [@[@"notRegistered"] mutableCopy];
    f.serviceWasNotFound = YES;
    NSDictionary *r = [f recoverySequence];
    assert(![f.calls containsObject:@"retiredUnregister"]);
    assert(Index(f, @"unregister") < Index(f, @"register"));
    assert([r[@"code"] isEqual:@"requiresApproval"] && ![f.calls containsObject:@"hello"]);
    // If the system still reads the retired item as registered (e.g. requiresApproval for the disabled item), the
    // same repair first cleans it up (once per build), then unregisters and registers helperd.
    f = New(@[Job(@"missing"), Job(@"missing")], @[Denied()], @[@"requiresApproval"]);
    f.retiredStatuses = [@[@"requiresApproval", @"notRegistered"] mutableCopy];
    f.serviceWasNotFound = YES;
    r = [f recoverySequence];
    assert(Index(f, @"retiredUnregister") < Index(f, @"unregister") && Index(f, @"unregister") < Index(f, @"register"));
    assert([r[@"code"] isEqual:@"requiresApproval"] && [r[@"retiredUnregister"] isEqual:@"ok"]);
    puts("ok");
''')


class StatusSourceTests(unittest.TestCase):
    def test_service_not_found_is_split_from_missing_bundle_files(self):
        compile_and_run(self, STATUS_FIXTURE + r'''
int main(void) { @autoreleasepool {
    Bridge *bridge = [Bridge new];
    bridge.service = [FakeService new];
    // Intact, trusted bundle; SMAppService says notFound: the system's record, which the user can re-register.
    bridge.service.status = SMAppServiceStatusNotFound;
    NSDictionary *r = [bridge registrationStatus];
    assert([r[@"code"] isEqual:@"serviceNotFound"] && [r[@"source"] isEqual:@"service"]);
    assert([r[@"detail"] containsString:@"source: service"]);
    // 17:11 field case: only the retired item exists (settled, so retiredRegistration is nil) and helperd was never
    // registered, which SMAppService reports as notFound: serviceNotFound, never the reinstall card.
    assert([[bridge registrationStatus][@"code"] isEqual:@"serviceNotFound"]);
    // A bundled daemon file missing: still notFound (reinstall), whatever SMAppService would say.
    daemonFilesPresent = NO;
    r = [bridge registrationStatus];
    assert([r[@"code"] isEqual:@"notFound"] && [r[@"source"] isEqual:@"bundle"]);
    assert([r[@"detail"] containsString:@"source: bundle"]);
    bridge.service.status = SMAppServiceStatusEnabled;
    assert([[bridge registrationStatus][@"code"] isEqual:@"notFound"]);
    daemonFilesPresent = YES;
    bridge.service.status = SMAppServiceStatusNotRegistered;
    assert([[bridge registrationStatus][@"code"] isEqual:@"notRegistered"]);
    puts("ok");
} }
''')

    def test_user_recovery_reads_the_service_status_and_status_never_recovers(self):
        recover = method('- (void)recoverWithArguments:')
        self.assertLess(recover.index('[self gate]'), recover.index('self.serviceWasNotFound = [[self serviceStatusCode] isEqual:@"notFound"]'))
        self.assertLess(recover.index('self.serviceWasNotFound ='), recover.index('dispatch_async(self.repairQueue'))
        sequence = method('- (NSDictionary *)recoverySequence')
        self.assertIn('if (self.serviceWasNotFound || ![job[@"state"] isEqual:@"missing"])', sequence)
        self.assertIn('done(@"serviceNotFound", fields)', sequence)
        status = method('- (void)status:')
        for call in ('recoverySequence', 'registerDaemon', 'unregisterDaemon', 'serviceWasNotFound'):
            self.assertNotIn(call, status)
        registration = method('- (NSDictionary *)registrationStatus')
        for call in ('register', 'unregister'):
            self.assertNotIn(f'[[self daemon] {call}', registration)


class RecoveryEntryTests(unittest.TestCase):
    def test_entry_points(self):
        recover = method('- (void)recoverWithArguments:')
        # Explicit evidence that the app wrote its repair record; nothing else starts it.
        self.assertIn('arguments.count != 1', recover)
        self.assertIn('CFBooleanGetTypeID()', recover)
        self.assertLess(recover.index('self.operationInFlight) {'), recover.index('self.operationInFlight = YES'))
        self.assertLess(recover.index('[self gate]'), recover.index('self.operationInFlight = YES'))
        self.assertIn('[self resetConnection]', recover)
        self.assertIn('dispatch_async(self.repairQueue', recover)
        status = method('- (void)status:')
        # During a recovery status answers without hello, so nothing reconnects; a stale job skips hello too.
        self.assertLess(status.index('repairInProgress'), status.index('[self request:@"hello"'))
        self.assertLess(status.index('@"registrationStale"'), status.index('[self request:@"hello"'))
        for operation in ('registerAndReturnError', 'unregister', 'registerDaemon'):
            self.assertNotIn(operation, status)
        # launchd's parent bundle version lags after every update: it never decides anything for the new name.
        self.assertNotIn('versionStale', BRIDGE)
        invoke = method('- (void)invoke:')
        self.assertIn('@"retireCores"', invoke)
        self.assertNotIn('repairExplicit', BRIDGE)
        self.assertNotIn('repairRegisterOnly', BRIDGE)
        enable = method('- (void)registerWithCompletion:')
        self.assertIn('FCApprovalError(error, statusName) ? @"requiresApproval" : @"registrationFailed"', enable)
        self.assertIn('NSString *statusName = FCServiceStatusName(status);', enable)
        self.assertIn('@"serviceStatus": statusName', enable)
        # The domains are SMAppService's own values (SMAppServiceErrorDomain / kSMErrorDomainFramework).
        self.assertIn('FCSMAppServiceErrorDomain = @"SMAppServiceErrorDomain";', BRIDGE)
        self.assertIn('FCSMFrameworkErrorDomain = @"kSMErrorDomainFramework";', BRIDGE)


if __name__ == '__main__':
    unittest.main()
