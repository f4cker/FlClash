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


SEQUENCE_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
#import <errno.h>
enum { kSMErrorJobNotFound = 6, kSMErrorLaunchDeniedByUser = 11 };
static NSString * const FCRetiredHelperLabel = @"com.layoute.flash.daemon";
''' + method('static NSString *FCErrorText') + '\n' + method('static BOOL FCApprovalError') + '\n' + method('static BOOL FCAlreadyUnregistered') + r'''
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
@end
@implementation Fixture
- (instancetype)init {
    if ((self = [super init])) {
        _calls = [NSMutableArray array]; _hellos = [@[@{@"code": @"ok", @"helperCDHash": @"new"}] mutableCopy];
        _retiredStatuses = [@[@"notRegistered"] mutableCopy]; _retiredUnregister = NSNull.null;
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
''' + method('- (NSString *)retireOldRegistration:') + '\n' + method('- (NSDictionary *)recoverySequence') + '\n' + method('- (NSDictionary *)awaitNewHelper:') + r'''
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
    // A status that cannot be read with the same error is still not a failure.
    f = New(@[Job(@"missing")], @[[NSError errorWithDomain:@"SMAppServiceErrorDomain" code:11 userInfo:nil]], @[@"unknown"]);
    assert([[f recoverySequence][@"code"] isEqual:@"requiresApproval"]);
    assert(FCApprovalError([NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:nil]));
    assert(!FCApprovalError([NSError errorWithDomain:@"SMAppServiceErrorDomain" code:3 userInfo:nil]) && !FCApprovalError(nil));
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
    Fixture *f = New(@[Job(@"missing")], @[[NSError errorWithDomain:@"x" code:5 userInfo:nil]], @[@"notFound"]);
    NSDictionary *r = [f recoverySequence];
    assert([r[@"code"] isEqual:@"notFound"] && ![f.calls containsObject:@"hello"]);
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
''')


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
    // But a broken new job is still replaced.
    f = New(@[Job(@"broken"), Job(@"missing"), Job(@"idle")], @[NSNull.null], @[@"enabled"]);
    f.retiredStatuses = [@[@"enabled"] mutableCopy];
    assert([[f recoverySequence][@"code"] isEqual:@"enabled"]);
    assert([f.calls containsObject:@"unregister"] && [f.calls containsObject:@"register"]);
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
        invoke = method('- (void)invoke:')
        self.assertIn('@"retireCores"', invoke)
        self.assertNotIn('repairExplicit', BRIDGE)
        self.assertNotIn('repairRegisterOnly', BRIDGE)
        enable = method('- (void)registerWithCompletion:')
        self.assertIn('FCApprovalError(error) ? @"requiresApproval" : @"registrationFailed"', enable)


if __name__ == '__main__':
    unittest.main()
