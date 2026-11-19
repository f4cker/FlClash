"""Recovery after a helper update or a lost connection (pure fixtures; no daemon, launchd or SMAppService use).

Covers: request timeouts are `timeout`, not `exitUnconfirmed`; `stop` from a later connection of the same
user naming the session; uncertain ownership is retried on hello/start; a previous build's daemon is reported
as `staleHelper` and retired; status must not change service registration.
"""
import re
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


def compile_and_run(test, source, *, extra=(), frameworks=('Foundation',)):
    with tempfile.TemporaryDirectory(prefix='flash-update-recovery-') as directory:
        root = Path(directory)
        (root / 'fixture.m').write_text(source)
        flags = [arg for name in frameworks for arg in ('-framework', name)]
        result = subprocess.run([
            'clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
            '-mmacosx-version-min=14.0', '-I', str(MACOS / 'Shared'), '-I', str(MACOS / 'PrivilegedHelper'),
            str(root / 'fixture.m'), *map(str, extra), *flags, '-o', str(root / 'fixture'),
        ], capture_output=True, text=True, timeout=60)
        test.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=20)
        test.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return result.stdout


# The helper's refusal exit status, exactly as HelperTrust.h defines it.
REFUSED_EXIT = next(line for line in (MACOS / 'Shared/HelperTrust.h').read_text().splitlines()
                    if line.startswith('#define FC_HELPER_REFUSED_EXIT '))

SUPERVISOR_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <sysexits.h>
#import <sys/wait.h>
#import <os/log.h>
#import "SessionPolicy.h"
static os_log_t FCHelperLog(void) { return OS_LOG_DEFAULT; }
''' + REFUSED_EXIT + r'''
static NSString * const FCRuntimeDirectory = @"/fixture-runtime";
static const size_t FCMaxFrame = 1024;
static BOOL reapSucceeds, syncSucceeds = YES;
static int unlinkErrno, reaps, unlinks, staged, waits;
static NSMutableArray *replies;
static NSDictionary *FixtureRetire(pid_t keep) {
    assert(keep == 0); reaps++;
    return @{@"outcome": reapSucceeds ? @"none" : @"unconfirmed", @"stopped": @0, @"reason": @""};
}
static void FixtureRemoveStaged(NSString *d) { staged++; }
static int FixtureUnlink(const char *path) {
    unlinks++;
    if (!strcmp(path, "/fixture-runtime/child-owned") && unlinkErrno) { errno = unlinkErrno; return -1; }
    return 0;
}
static pid_t FixtureWait(pid_t pid, int *status, int options) { assert(pid > 0); waits++; return pid; }
static NSMutableDictionary<NSValue *, NSNumber *> *euids;
static uid_t FixtureEuid(xpc_connection_t c) { return euids[[NSValue valueWithPointer:(__bridge void *)c]].unsignedIntValue; }
static void FixtureCancel(xpc_connection_t c) { [replies addObject:@"cancelled"]; }
#define FCRetireFlashCores FixtureRetire
#define FCRemoveStagedCores FixtureRemoveStaged
#define unlink FixtureUnlink
#define waitpid FixtureWait
#define xpc_connection_get_euid FixtureEuid
#define xpc_connection_cancel FixtureCancel
static BOOL FCRepliesWithCoreToken(NSString *action, NSString *code) { return NO; }

@interface FCGUIMessageValidator : NSObject
@property NSString *failure;
@end
@implementation FCGUIMessageValidator
- (BOOL)check:(xpc_object_t)message { return YES; }
@end

@interface SupervisorFixture : NSObject
@property dispatch_queue_t queue;
@property xpc_connection_t owner;
@property NSString *session;
@property NSString *corePath;
@property NSData *coreToken;
@property uid_t uid;
@property pid_t child;
@property BOOL ownershipUncertain;
@property BOOL journalOwned;
@property NSDictionary *lastSweep;
@property int stops, starts, relayCloses;
@end
@implementation SupervisorFixture
- (void)armIdle {}
- (BOOL)syncRuntime { return syncSucceeds; }
- (void)closeRelay { self.relayCloses++; }
- (NSString *)validateCompatibility { return @"ok"; }
- (BOOL)stop {
    self.stops++;
    if (self.ownershipUncertain) return NO;
    self.child = 0;
    return YES;
}
- (NSString *)start:(xpc_object_t)request connection:(xpc_connection_t)connection session:(NSString *)session {
    self.starts++;
    if (self.ownershipUncertain) return @"exitUnconfirmed";
    self.owner = connection; self.session = session; self.uid = FixtureEuid(connection); self.child = 42;
    return @"ok";
}
- (NSArray<NSData *> *)receive:(uint64_t)ack base:(uint64_t *)base code:(NSString **)code { *code = @"ok"; return @[]; }
- (NSString *)retireCores:(NSDictionary **)sweep { return @"noStaleCore"; }
- (NSString *)send:(NSData *)frame seq:(uint64_t)seq { return @"ok"; }
// Adoption by the same app process is covered by test_supervisor_stop; connections here are other processes.
- (BOOL)adopt:(xpc_object_t)request connection:(xpc_connection_t)connection session:(NSString *)session { return NO; }
- (void)ownerLost:(xpc_connection_t)connection { if (self.owner == connection) [self stop]; }
- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frames:(NSArray<NSData *> *)frames base:(uint64_t)base coreToken:(NSData *)token sweep:(NSDictionary *)sweep {
    [replies addObject:@{@"code": code, @"pid": @(pid), @"exitConfirmed": @(self.child == 0 && !self.ownershipUncertain)}];
}
'''


class SupervisorRecoveryTests(unittest.TestCase):
    def fixture(self, main):
        source = SUPERVISOR_FIXTURE
        source += method(SUPERVISOR, '- (BOOL)recoverOwnership') + '\n'
        source += method(SUPERVISOR, '- (void)handle:') + '\n@end\n'
        source += r'''
static NSDictionary *Send(SupervisorFixture *s, xpc_connection_t c, const char *name, const char *session) {
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(request, "method", name);
    xpc_dictionary_set_int64(request, "protocol", 1);
    if (session) xpc_dictionary_set_string(request, "session", session);
    [replies removeAllObjects];
    [s handle:request connection:c gui:[FCGUIMessageValidator new]];
    return replies.lastObject;
}
static xpc_connection_t Connection(uid_t uid) {
    xpc_connection_t c = (xpc_connection_t)(id)[NSObject new];
    euids[[NSValue valueWithPointer:(__bridge void *)c]] = @(uid);
    return c;
}
int main(void) {
    @autoreleasepool {
        replies = [NSMutableArray array];
        euids = [NSMutableDictionary dictionary];
        SupervisorFixture *s = [SupervisorFixture new];
        s.queue = dispatch_queue_create("fixture-only", DISPATCH_QUEUE_SERIAL);
''' + main + r'''
    }
}
'''
        return compile_and_run(self, source)

    def test_stop_from_a_later_connection_of_the_same_user(self):
        self.fixture(r'''
        const char *session = "0123456789abcdef0123456789abcdef";
        xpc_connection_t first = Connection(501), later = Connection(501), stranger = Connection(502);
        assert([Send(s, first, "start", session)[@"code"] isEqual:@"ok"] && s.child == 42);
        // Relay traffic stays bound to the owning connection.
        assert([Send(s, later, "receive", session)[@"code"] isEqual:@"wrongOwner"]);
        assert([Send(s, later, "send", session)[@"code"] isEqual:@"wrongOwner"]);
        // Another user, or another session id, may not stop it.
        assert([Send(s, stranger, "stop", session)[@"code"] isEqual:@"wrongOwner"] && s.child == 42);
        assert([Send(s, later, "stop", "0123456789abcdef0123456789abcde0")[@"code"] isEqual:@"wrongOwner"]);
        assert([Send(s, later, "stop", NULL)[@"code"] isEqual:@"wrongOwner"] && s.stops == 0);
        // The same user's new connection naming the session stops the Core (the old one timed out).
        NSDictionary *stopped = Send(s, later, "stop", session);
        assert([stopped[@"code"] isEqual:@"ok"] && [stopped[@"exitConfirmed"] isEqual:@YES] && s.child == 0);
        // A daemon that never owned this session answers wrongOwner, but says it owns no Core.
        SupervisorFixture *fresh = [SupervisorFixture new];
        NSDictionary *unknown = Send(fresh, later, "stop", session);
        assert([unknown[@"code"] isEqual:@"wrongOwner"] && [unknown[@"pid"] isEqual:@0] &&
            [unknown[@"exitConfirmed"] isEqual:@YES]);
        puts("stop-from-new-connection");
''')

    def test_uncertain_ownership_is_retried_on_hello_and_start(self):
        out = self.fixture(r'''
        const char *session = "0123456789abcdef0123456789abcdef";
        xpc_connection_t c = Connection(501);
        // A previous daemon left its journal and a Core could not be reaped at launch.
        s.ownershipUncertain = YES; s.child = -1;
        reapSucceeds = NO;
        NSDictionary *hello = Send(s, c, "hello", NULL);
        assert([hello[@"code"] isEqual:@"exitUnconfirmed"] && [hello[@"exitConfirmed"] isEqual:@NO]);
        assert(reaps == 1 && s.ownershipUncertain && s.child == -1 && waits == 0);
        assert([Send(s, c, "start", session)[@"code"] isEqual:@"exitUnconfirmed"] && reaps == 2);
        // Relay traffic does not trigger the (blocking) reap.
        Send(s, c, "receive", session);
        assert(reaps == 2);
        // The journal cannot be released: still uncertain.
        reapSucceeds = YES; unlinkErrno = EACCES;
        assert([Send(s, c, "hello", NULL)[@"code"] isEqual:@"exitUnconfirmed"] && s.ownershipUncertain);
        // Released but not synced: still uncertain.
        unlinkErrno = 0; syncSucceeds = NO;
        assert([Send(s, c, "hello", NULL)[@"code"] isEqual:@"exitUnconfirmed"] && s.ownershipUncertain);
        // No surviving Core and the journal is gone: the next hello clears the flag and serves again.
        syncSucceeds = YES;
        hello = Send(s, c, "hello", NULL);
        assert([hello[@"code"] isEqual:@"ok"] && [hello[@"exitConfirmed"] isEqual:@YES] && [hello[@"pid"] isEqual:@0]);
        assert(!s.ownershipUncertain && s.child == 0 && !s.journalOwned && staged == 1 && waits == 0);
        int before = reaps;
        assert([Send(s, c, "start", session)[@"code"] isEqual:@"ok"] && reaps == before);
        // A runtime uncertainty about a real child (waitpid lost it) recovers the same way on start.
        SupervisorFixture *t = [SupervisorFixture new];
        t.ownershipUncertain = YES; t.child = 77; t.journalOwned = YES; t.corePath = @"/fixture-runtime/core-x";
        unlinkErrno = ENOENT;
        assert([Send(t, c, "start", session)[@"code"] isEqual:@"ok"]);
        assert(waits == 1 && !t.ownershipUncertain && t.relayCloses == 1);
        puts("uncertain-ownership-retried");
''')
        self.assertIn('uncertain-ownership-retried', out)

    def test_refusals_exit_with_their_own_status(self):
        # 79: neither EX_CONFIG (78) nor one of FlashHelperLauncher's 81–87.
        self.assertEqual(REFUSED_EXIT.split()[2], '79')
        trust = (MACOS / 'Shared/HelperTrust.h').read_text()
        self.assertIn('#define FC_LAUNCHER_EXIT_FIRST 81', trust)
        self.assertIn('#define FC_LAUNCHER_EXIT_LAST 87', trust)
        handle = method(SUPERVISOR, '- (void)handle:')
        self.assertIn('int status = [code isEqualToString:@"ok"] ? 0 : FC_HELPER_REFUSED_EXIT;', handle)
        main = method(SUPERVISOR, 'int main(int argc, const char *argv[])')
        for marker in ('launch-refused', 'self-check-failed'):
            after = main[main.index(marker):]
            self.assertTrue(after[after.index('return '):].startswith('return FC_HELPER_REFUSED_EXIT;'), marker)

    def test_idle_and_termination_retry_recovery(self):
        idle = method(SUPERVISOR, '- (void)armIdle')
        self.assertLess(idle.index('[self recoverOwnership]'), idle.index('exit(0)'))
        main = method(SUPERVISOR, 'int main(int argc, const char *argv[])')
        self.assertIn('[supervisor recoverOwnership] && [supervisor stop]', main)
        handle = method(SUPERVISOR, '- (void)handle:')
        # Per-message caller validation still comes first.
        self.assertLess(handle.index('[gui check:request]'), handle.index('[self recoverOwnership]'))
        self.assertLess(handle.index('[gui check:request]'), handle.index('FCMayStopSession('))


BRIDGE_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <assert.h>
#import "LauncherStatus.h"
#import "LaunchdProbe.h"
#import <os/log.h>
static os_log_t FCBridgeLog(void) { return OS_LOG_DEFAULT; }
'''


# After every app update launchd reports the previous parent bundle version until the next login. With that (and with
# any refusal exit code, or 78) status keeps waiting or shows a card; only launchd's own "broken" is a stale
# registration. Appended to the fixture's main (b: BridgeFixture).
STALE_VERSION_MAIN = r'''
        NSDictionary *(^Job)(NSString *, NSInteger) = ^NSDictionary *(NSString *state, NSInteger exitCode) {
            BOOL refused = [state isEqual:@"idle"] && FCRefusalExit(exitCode);
            return @{@"state": state, @"versionStale": @YES, @"lastExit": @(exitCode), @"refused": @(refused),
                @"summary": [NSString stringWithFormat:@"%@ lastExit=%ld parentVersion=old", state, (long)exitCode]};
        };
        b.launcher = nil;
        // The old helper copy is still idling: staleHelper, retried after the cooldown, never registrationStale.
        b.jobs = [@[Job(@"running", 0)] mutableCopy];
        b.oldDaemon = YES; b.oldDaemonBusy = YES; b.staleRetryAfter = nil;
        [b.calls removeAllObjects];
        assert([Run(b, NO)[@"code"] isEqual:@"staleHelper"]);
        assert(b.staleRetryAfter && [b.staleRetryAfter timeIntervalSinceNow] > 30);
        assert([Run(b, NO)[@"code"] isEqual:@"staleHelper"]);
        b.oldDaemon = NO; b.staleRetryAfter = [NSDate distantPast];
        assert([Run(b, NO)[@"code"] isEqual:@"enabled"]);
        // A slow first start (copy + signature check): a wait, not a stale registration.
        b.jobs = [@[Job(@"idle", 0), Job(@"running", 0)] mutableCopy];
        b.slow = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"timeout"]);
        // Last exit 78 is not a registration problem either.
        b.jobs = [@[Job(@"idle", 78)] mutableCopy];
        b.slow = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"timeout"]);
        // The helper refused (79): a definite card with the exit code in the details.
        b.jobs = [@[Job(@"idle", 79)] mutableCopy];
        b.slow = YES;
        NSDictionary *refusal = Run(b, NO);
        assert([refusal[@"code"] isEqual:@"launcherCheckFailed"] && [refusal[@"detail"] containsString:@"last exit code: 79"]);
        // Launcher exit codes without a (fresh) status file map by themselves.
        NSDictionary *cards = @{@81: @"launcherFailed", @82: @"launcherCheckFailed", @83: @"launcherFailed",
            @84: @"launcherCheckFailed", @85: @"launcherCheckFailed", @86: @"launcherDowngrade", @87: @"launcherFailed"};
        for (NSNumber *code in cards) {
            b.jobs = [@[Job(@"idle", code.integerValue)] mutableCopy];
            b.slow = YES;
            NSDictionary *card = Run(b, NO);
            assert([card[@"code"] isEqual:cards[code]]);
            NSString *line = [NSString stringWithFormat:@"last exit code: %@", code];
            assert([card[@"detail"] containsString:line]);
        }
        // The launcher status, when it has one, names the step; the exit code is added to it.
        b.launcher = @{@"code": @"launcherDowngrade", @"detail": @"launcher result: downgrade"};
        b.jobs = [@[Job(@"idle", 86)] mutableCopy];
        b.slow = YES;
        NSDictionary *both = Run(b, NO);
        assert([both[@"code"] isEqual:@"launcherDowngrade"] && [both[@"detail"] containsString:@"launcher result: downgrade"]);
        assert([both[@"detail"] containsString:@"last exit code: 86"]);
        b.launcher = nil;
        // Only launchd's own word makes it stale: before hello, or for the start hello caused.
        b.jobs = [@[Job(@"broken", 78)] mutableCopy];
        assert([Run(b, NO)[@"code"] isEqual:@"registrationStale"]);
        b.jobs = [@[Job(@"idle", 0), Job(@"broken", 0)] mutableCopy];
        b.slow = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"registrationStale"]);
        assert(![b.calls containsObject:@"unregister"] && ![b.calls containsObject:@"register"] &&
               ![b.calls containsObject:@"exit"]);
        b.jobs = nil;
        puts("stale-version-waits");
'''


# Asking the previous build's helper to exit (appended to the fixture's main; b: BridgeFixture).
RETIRE_CONSTANTS = '\n'.join(line for line in BRIDGE.splitlines()
                             if line.startswith(('static const NSUInteger FCMaxRetireAttempts',
                                                 'static const NSTimeInterval FCStaleRecheckSeconds',
                                                 'static const NSTimeInterval FCExitSettleSeconds'))) + '\n'
RETIRE_MAIN = r'''
        // Simulation: an in-app update left the old helper running (no Core); its hello reply is refused for its
        // cdhash only. Status sends one exit, says a switch is under way and asks again after ~1 s.
        b.launcher = nil; b.jobs = nil; b.slow = NO; b.sessionActive = NO; b.operationInFlight = NO;
        b.oldDaemon = YES; b.oldDaemonBusy = NO; b.hashRefusal = YES; b.otherRefusal = NO; b.exitReplies = YES;
        b.staleRetryAfter = nil; b.retireAttempts = 0; b.retireHash = nil; b.clock = 100;
        [b.calls removeAllObjects];
        NSDictionary *swap = Run(b, NO);
        assert([swap[@"code"] isEqual:@"staleHelper"] && [swap[@"retiring"] isEqual:@YES]);
        assert(([b.calls isEqual:@[@"hello", @"exit", @"reset"]]) && !b.oldDaemon);
        assert([b.staleRetryAfter timeIntervalSinceNow] <= FCStaleRecheckSeconds);
        // Within the second: the cached answer, still "switching", nothing sent.
        dispatch_sync(b.queue, ^{});  // the reply to the exit
        NSDictionary *cached = Run(b, NO);
        assert([cached[@"code"] isEqual:@"staleHelper"] && [cached[@"retiring"] isEqual:@YES]);
        assert(b.calls.count == 3 && !b.exitInFlight && b.exitAnswered);
        // The next status reaches the bundled helper (launchd ran the launcher): ready, no registration touched.
        b.staleRetryAfter = [NSDate distantPast]; b.clock += 2;
        assert([Run(b, NO)[@"code"] isEqual:@"enabled"] && !b.staleRetryAfter && !b.staleRetiring);
        assert(([b.calls isEqual:@[@"hello", @"exit", @"reset", @"hello"]]));

        // An exit still without reply (slow validation in the old helper): no second one, still a switch.
        b.oldDaemon = YES; b.oldDaemonBusy = YES; b.exitReplies = NO;
        b.retireHash = nil; b.exitAnswered = NO; b.exitInFlight = NO; b.staleRetryAfter = nil;
        [b.calls removeAllObjects];
        for (int i = 0; i < 4; i++) {
            assert([Run(b, NO)[@"retiring"] isEqual:@YES]);
            b.staleRetryAfter = [NSDate distantPast]; b.clock += 2;
        }
        NSUInteger exits = 0;
        for (NSString *call in b.calls) exits += [call isEqual:@"exit"];
        assert(exits == 1 && b.exitInFlight && b.retireAttempts == 1);
        // Its reply came (sessionBusy: it owns a Core). Within FCExitSettleSeconds: still nothing new.
        [b exitSettled:YES];
        assert([Run(b, NO)[@"retiring"] isEqual:@YES] && b.retireAttempts == 1);
        // It still answers after that: refused. No more exits, the passive 40 s wait.
        b.staleRetryAfter = [NSDate distantPast]; b.clock += 2;
        NSDictionary *refusedExit = Run(b, NO);
        assert([refusedExit[@"retiring"] isEqual:@NO] && [b.staleRetryAfter timeIntervalSinceNow] > 30);
        assert(b.retireAttempts == 1);
        // A user's "check again" (native repair) grants exactly one more, never a re-registration.
        NSDictionary *again = Run(b, YES);
        assert([again[@"retiring"] isEqual:@YES] && b.retireAttempts == 2);
        // An exit that ended in an error (no reply), then the helper still answers: tried again, at most 3 sent.
        [b exitSettled:NO]; b.clock += 2; b.staleRetryAfter = nil;
        assert([Run(b, NO)[@"retiring"] isEqual:@YES] && b.retireAttempts == 3);
        [b exitSettled:NO]; b.clock += 2; b.staleRetryAfter = nil;
        assert([Run(b, NO)[@"retiring"] isEqual:@NO] && b.retireAttempts == 3);
        // A new bundled helper (another update) starts a new count.
        b.retireHash = @"cdhash-older"; b.staleRetryAfter = nil;
        assert([Run(b, NO)[@"retiring"] isEqual:@YES] && b.retireAttempts == 1);
        [b exitSettled:NO]; b.clock += 2;

        // Nothing could be sent (pinned requirement unavailable): not counted, and no switch is claimed.
        b.retireAttempts = 0; b.staleRetryAfter = nil; b.requirementMissing = YES;
        [b.calls removeAllObjects];
        assert([Run(b, NO)[@"retiring"] isEqual:@NO] && b.retireAttempts == 0 && !b.exitInFlight);
        assert([b.staleRetryAfter timeIntervalSinceNow] > 30);
        b.requirementMissing = NO;
        // Never while this app's Core session runs through it, or while a recovery owns the registration.
        b.staleRetryAfter = nil; b.sessionActive = YES;
        assert([Run(b, NO)[@"retiring"] isEqual:@NO]);
        b.sessionActive = NO; b.staleRetryAfter = nil; b.operationInFlight = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"repairInProgress"]);
        __block BOOL during = YES;
        dispatch_sync(b.queue, ^{ during = [b retireStaleHelper]; });
        assert(!during && b.retireAttempts == 0);
        b.operationInFlight = NO;
        // Never for a reply refused for anything but its cdhash, or a stale hash only the helper itself reported.
        b.staleRetryAfter = nil; b.otherRefusal = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"untrustedReply"]);
        b.otherRefusal = NO; b.hashRefusal = NO; b.staleRetryAfter = nil;
        assert([Run(b, NO)[@"retiring"] isEqual:@NO]);
        assert(![b.calls containsObject:@"exit"] && b.retireAttempts == 0);
        assert(![b.calls containsObject:@"unregister"] && ![b.calls containsObject:@"register"]);
        puts("stale-helper-retired");
'''


class BridgeRecoveryTests(unittest.TestCase):
    def test_timeouts_are_their_own_code_and_start_waits_longer(self):
        source = BRIDGE_FIXTURE + method(BRIDGE, 'static int64_t FCRequestTimeoutSeconds') + '\n'
        source += method(BRIDGE, 'static NSString *FCStatusForHello') + '\n'
        source += r'''
int main(void) {
    assert(FCRequestTimeoutSeconds(@"start") == 30);
    for (NSString *m in @[@"hello", @"stop", @"send", @"receive", @"exit"]) assert(FCRequestTimeoutSeconds(m) == 8);
    assert([FCStatusForHello(@"ok") isEqual:@"enabled"]);
    assert([FCStatusForHello(@"timeout") isEqual:@"timeout"]);
    assert([FCStatusForHello(@"staleHelper") isEqual:@"staleHelper"]);
    assert([FCStatusForHello(@"exitUnconfirmed") isEqual:@"exitUnconfirmed"]);
    assert([FCStatusForHello(@"incompatible") isEqual:@"incompatible"]);
    assert([FCStatusForHello(@"unavailable") isEqual:@"unavailable"]);
    assert([FCStatusForHello(nil) isEqual:@"unavailable"]);
    puts("timeouts");
}
'''
        compile_and_run(self, source)
        request = method(BRIDGE, '- (void)request:')
        timer = request[request.index('FCRequestTimeoutSeconds(method)'):]
        self.assertIn('finish(@{@"code": @"timeout", @"detail":', timer)
        self.assertNotIn('exitUnconfirmed', request)
        # A stale reply is recognised only after the validator rejected it; nothing else of it is read.
        rejected = request[request.index('[validator check:reply]'):request.index('const char *code')]
        self.assertIn('validator.runningCodeStale', rejected)
        self.assertIn('finish(stale ? @{@"code": @"staleHelper", @"detail": refusal, @"runningCodeStale": @YES} :', rejected)
        self.assertIn('@{@"code": untrusted ? @"untrustedReply" : @"unavailable", @"detail": refusal}', rejected)

    def test_running_hash_verdict(self):
        source = r'''
#import "HelperTrust.h"
#import <assert.h>
int main(void) {
    @autoreleasepool {
        NSMutableData *a = [NSMutableData dataWithLength:20], *b = [NSMutableData dataWithLength:20];
        ((uint8_t *)b.mutableBytes)[0] = 1;
        assert(FCCompareRunningHash(a, [a copy]) == FCRunningHashCurrent);
        // dev.6 daemon still running, mitm.1 helper on disk.
        assert(FCCompareRunningHash(a, b) == FCRunningHashStale);
        // Without a valid bundled hash, or a malformed running one, nothing is stale: it is rejected.
        assert(FCCompareRunningHash(a, nil) == FCRunningHashInvalid);
        assert(FCCompareRunningHash(nil, b) == FCRunningHashInvalid);
        assert(FCCompareRunningHash([NSData dataWithBytes:"x" length:1], b) == FCRunningHashInvalid);
        puts("verdict");
    }
}
'''
        compile_and_run(self, source, extra=[MACOS / 'Shared/HelperTrust.m'], frameworks=('Foundation', 'Security'))
        trust = (MACOS / 'Shared/HelperTrust.m').read_text()
        check = trust.split('@implementation FCMessageValidator', 1)[1].split('@end', 1)[0]
        # The flag is reset per message and set only from the first, full check (identity, path, policy passed).
        self.assertLess(check.index('self.runningCodeStale = NO;'), check.index('SecCodeCreateWithXPCMessage'))
        self.assertIn('valid = verdict == FCRunningHashCurrent;', check)
        for condition in ('SecCodeCreateWithXPCMessage', 'SecCodeCheckValidity', 'FCPinnedRequirement',
                          'FCExecutableMatches', 'FCPinnedCodePolicy', 'FCStaticCodeHash'):
            self.assertIn(condition, check)
        # Only a test compiles in another requirement or policy; the app and the daemon get the pinned ones.
        self.assertIn('#ifndef FCPinnedRequirement\n#define FCPinnedRequirement FCSigningRequirement\n', trust)
        self.assertIn('#ifndef FCPinnedCodePolicy\n#define FCPinnedCodePolicy FCCodeEntitlementsAllowed\n', trust)
        for build in [MACOS / 'Runner.xcodeproj/project.pbxproj', *MACOS.glob('PrivilegedHelper/*.sh'),
                      *MACOS.glob('**/*.xcconfig')]:
            if build.exists():
                self.assertNotIn('FCPinned', build.read_text(errors='ignore'), build)

    def test_running_hash_of_another_slice_of_the_bundled_helper_is_current(self):
        # An app under Rosetta reads the x86_64 slice's cdhash by default while launchd runs the arm64 slice: equal to
        # a validated slice of the same bundled binary is current; anything else stays stale.
        peer = 'com.layoute.flash.test.peer'
        with tempfile.TemporaryDirectory(prefix='flash-slices-') as directory:
            root = Path(directory)
            universal, thin = root / 'universal', root / 'thin'
            for binary, archs in ((universal, ['-arch', 'arm64', '-arch', 'x86_64']), (thin, ['-arch', 'arm64'])):
                built = subprocess.run(['clang', *archs, str(MACOS / 'PrivilegedHelper/Tests/UnreadablePeer.c'),
                                        '-o', str(binary)], capture_output=True, text=True)
                if built.returncode:
                    self.skipTest('cannot build a universal binary here: ' + built.stderr[:200])
                subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--identifier', peer,
                                str(binary)], check=True, capture_output=True, text=True)
            def slice_hash(arch):
                shown = subprocess.run(['codesign', '-d', '-vvv', '-a', arch, str(universal)],
                                       capture_output=True, text=True)
                return next(line.split('=', 1)[1] for line in shown.stderr.splitlines() if line.startswith('CDHash='))
            arm, intel = slice_hash('arm64'), slice_hash('x86_64')
            self.assertNotEqual(arm, intel)
            source = r"""
#import "HelperTrust.h"
#import <assert.h>
NSString *TestPinnedRequirement(NSString *identifier) {
    return [identifier isEqualToString:@"PEER"] ? @"identifier \"PEER\"" : nil;
}
BOOL TestPinnedCodePolicy(NSDictionary *entitlements, uint32_t flags) { return (flags & kSecCodeSignatureRuntime) != 0; }
static NSData *Hex(const char *text) {
    NSMutableData *data = [NSMutableData data];
    for (size_t i = 0; text[i] && text[i + 1]; i += 2) {
        unsigned value; sscanf(text + i, "%2x", &value); uint8_t byte = value; [data appendBytes:&byte length:1];
    }
    return data;
}
int main(void) {
    @autoreleasepool {
        NSArray<NSData *> *slices = FCStaticCodeSliceHashes(@"UNIVERSAL", @"PEER");
        assert(slices.count == 2 && [slices containsObject:Hex("ARM")] && [slices containsObject:Hex("INTEL")]);
        NSData *bundled = FCStaticCodeHash(@"UNIVERSAL", @"PEER");
        assert([slices containsObject:bundled]);
        for (NSData *running in @[Hex("ARM"), Hex("INTEL")])
            assert(FCCompareRunningToBundled(running, bundled, @"UNIVERSAL", @"PEER") == FCRunningHashCurrent);
        NSMutableData *other = [Hex("ARM") mutableCopy];
        ((uint8_t *)other.mutableBytes)[0] ^= 1;
        assert(FCCompareRunningToBundled(other, bundled, @"UNIVERSAL", @"PEER") == FCRunningHashStale);
        // A slice must pass the pinned requirement: another identifier gives nothing to match.
        assert(FCStaticCodeSliceHashes(@"UNIVERSAL", @"other") == nil);
        assert(FCCompareRunningToBundled(Hex("INTEL"), Hex("ARM"), @"UNIVERSAL", @"other") == FCRunningHashInvalid);
        assert(FCCompareRunningToBundled(nil, bundled, @"UNIVERSAL", @"PEER") == FCRunningHashInvalid);
        assert(FCStaticCodeSliceHashes(@"THIN", @"PEER").count == 1);
        puts("slices");
    }
}
""".replace('UNIVERSAL', str(universal)).replace('THIN', str(thin)).replace('PEER', peer) \
                .replace('"ARM"', f'"{arm}"').replace('"INTEL"', f'"{intel}"')
            (root / 'fixture.m').write_text(source)
            result = subprocess.run([
                'clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations', '-mmacosx-version-min=14.0',
                '-DFCPinnedRequirement=TestPinnedRequirement', '-DFCPinnedCodePolicy=TestPinnedCodePolicy',
                '-I', str(MACOS / 'Shared'), str(root / 'fixture.m'), str(MACOS / 'Shared/HelperTrust.m'),
                '-framework', 'Foundation', '-framework', 'Security', '-o', str(root / 'fixture')],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn('slices', result.stdout)
        trust = (MACOS / 'Shared/HelperTrust.m').read_text()
        check = trust.split('@implementation FCMessageValidator', 1)[1].split('@end', 1)[0]
        self.assertEqual(check.count('FCCompareRunningToBundled('), 2)
        self.assertNotIn('FCCompareRunningHash(', check)

    def test_no_test_hook_reaches_a_production_build(self):
        # Every trust-relevant call a test may replace (`#ifndef FCx` / `#define FCx real`) and what it is in
        # production. A new hook must be added here, with its production meaning.
        production = {
            'FCLoadPlist': None,  # a static function in the #ifndef branch
            'FCPinnedRequirement': 'FCSigningRequirement',
            'FCPinnedCodePolicy': 'FCCodeEntitlementsAllowed',
            'FCCodeOps': 'csops_audittoken',
            'FCProcPath': 'proc_pidpath',
            'FCPidCodeOps': 'csops',
            'FCMessageAuditToken': 'xpc_dictionary_get_audit_token',
            'FCBundleStat': 'stat',
            'FCProcessToken': 'FCProcessTokenFromTask',
            'FCSweepPause': 'FCSweepPause() usleep(50000)',
        }
        sources = [*MACOS.glob('Shared/*.[mh]'), *MACOS.glob('PrivilegedHelper/*.[mhc]'), *MACOS.glob('Runner/*.[mh]')]
        hooks = set()
        for source in sources:
            text = source.read_text(errors='ignore')
            for name in re.findall(r'^#ifndef (FC[A-Z][A-Za-z]+)$', text, re.M):
                hooks.add(name)
                real = production.get(name, '?')
                if real:
                    branch = text.split(f'#ifndef {name}\n', 1)[1].split('#e', 1)[0]
                    defined = real if real.startswith(name + '(') else f'{name} {real}'
                    self.assertIn(f'\n#define {defined}\n', '\n' + branch, (source, name))
        self.assertEqual(hooks, set(production), 'test hooks changed: list each with its production meaning')
        listed = subprocess.run(['/usr/bin/git', '-C', str(MACOS.parent), 'ls-files', '-z'], capture_output=True)
        if listed.returncode:
            self.skipTest('not a git checkout')
        allowed = {source.resolve() for source in sources}
        leaks = []
        for relative in listed.stdout.decode().split('\0'):
            if not relative or '/Tests/' in f'/{relative}' or relative.startswith(('core/', 'plugins/')):
                continue
            path = MACOS.parent / relative
            if path.resolve() in allowed or not path.is_file() or path.stat().st_size > 4 << 20:
                continue
            text = path.read_text(errors='ignore')
            leaks += [f'{relative}: {name}' for name in hooks if re.search(rf'\b{name}\b', text)]
        # Not in the Xcode project, xcconfigs, packaging and signing scripts, CI workflows, Makefile or docs.
        self.assertEqual(leaks, [])

    def test_old_daemon_running_with_new_bundle_then_timeout_then_recover(self):
        source = BRIDGE_FIXTURE + method(BRIDGE, 'static NSString *FCStatusForHello') + r'''
@interface BridgeFixture : NSObject
@property dispatch_queue_t queue;
@property BOOL sessionActive;
@property NSDate *staleRetryAfter;
@property BOOL staleRetiring;
@property BOOL staleRetirable;
@property NSString *retireHash;
@property NSUInteger retireAttempts;
@property BOOL exitInFlight;
@property BOOL exitAnswered;
@property NSTimeInterval exitSettledAt;
@property NSTimeInterval clock;        // the bridge's uptime
@property BOOL requirementMissing;     // the pinned requirement is unavailable: nothing can be sent
@property BOOL exitReplies;            // the old daemon replies to exit at once (else it stays in flight)
@property BOOL hashRefusal;    // the old daemon's replies are refused only for their cdhash (validator verdict)
@property BOOL otherRefusal;   // ... or for anything else (identity, path): never asked to exit
@property NSMutableArray *calls;
@property BOOL oldDaemon;      // dev.6 daemon (previous cdhash) still runs beside the new bundle
@property BOOL oldDaemonBusy;  // ... and refuses to leave while it owns a Core
@property BOOL slow;           // the next hello runs out of time
@property BOOL operationInFlight;
@property NSTimeInterval okUnansweredSince;
@property NSDictionary *launcher;  // what the launcher status reports (nil: nothing to add)
@property NSMutableArray<NSDictionary *> *jobs;  // launchctl answers in order (last repeats); nil: idle
@end
@implementation BridgeFixture
- (BOOL)servesSession:(NSDictionary *)answer { return NO; }
- (void)expireSilentSession {}
- (NSDictionary *)launcherReport { return self.launcher; }
- (NSDictionary *)registrationStatus { return @{@"code": @"enabled"}; }
- (NSString *)currentHelperHash { return @"cdhash-new"; }
- (BOOL)isBundledHelperHash:(id)reported { return [reported isEqual:[self currentHelperHash]]; }
- (NSTimeInterval)uptime { return self.clock; }
- (NSDictionary *)launchdSnapshot {
    if (!self.jobs.count) return @{@"state": @"idle", @"versionStale": @NO, @"summary": @"idle"};
    [self.calls addObject:@"launchd"];
    NSDictionary *job = self.jobs.firstObject;
    if (self.jobs.count > 1) [self.jobs removeObjectAtIndex:0];
    return job;
}
- (void)resetConnection { [self.calls addObject:@"reset"]; }
// The fresh, pinned connection's `exit`: the old daemon leaves unless it owns a Core; its reply is never read.
- (BOOL)sendExitRequest {
    if (self.requirementMissing) return NO;
    [self.calls addObject:@"exit"];
    if (self.oldDaemon && !self.oldDaemonBusy) self.oldDaemon = NO;
    if (self.exitReplies) dispatch_async(self.queue, ^{ [self exitSettled:YES]; });
    return YES;
}
- (void)unregisterWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"unregister"]; c(@{@"code": @"ok"}); }
- (void)registerWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"register"]; [self status:c]; }
// The daemon as the bridge's request: sees it (validator verdict for the old build -> staleHelper).
- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    [self.calls addObject:method];
    if (self.slow) { self.slow = NO; completion(@{@"code": @"timeout"}); return; }
    if (self.oldDaemon) {
        assert(![method isEqual:@"exit"]);  // only ever on a connection of its own
        if (self.otherRefusal) { completion(@{@"code": @"untrustedReply", @"detail": @"path"}); return; }
        completion(self.hashRefusal ? @{@"code": @"staleHelper", @"runningCodeStale": @YES, @"detail": @"cdhash"} :
            @{@"code": @"staleHelper"}); return;
    }
    completion(@{@"code": @"ok", @"protocol": @1, @"pid": @0, @"exitConfirmed": @YES, @"helperCDHash": @"cdhash-new"});
}
'''
        source = source.replace('@interface BridgeFixture', RETIRE_CONSTANTS + '@interface BridgeFixture')
        source += method(BRIDGE, '- (void)status:') + '\n'
        source += method(BRIDGE, '- (BOOL)noteStaleHelper:') + '\n'
        source += method(BRIDGE, '- (BOOL)retireStaleHelper') + '\n'
        source += method(BRIDGE, '- (void)exitSettled:') + '\n'
        source += method(BRIDGE, '- (void)repairWithCompletion:') + '\n@end\n'
        source += r'''
static NSDictionary *Run(BridgeFixture *b, BOOL repair) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSDictionary *answer;
    dispatch_async(b.queue, ^{
        void (^finish)(NSDictionary *) = ^(NSDictionary *a) { answer = a; dispatch_semaphore_signal(done); };
        if (repair) [b repairWithCompletion:finish]; else [b status:finish];
    });
    assert(!dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)));
    return answer;
}
int main(void) {
    @autoreleasepool {
        BridgeFixture *b = [BridgeFixture new];
        b.queue = dispatch_queue_create("fixture-only", DISPATCH_QUEUE_SERIAL);
        b.calls = [NSMutableArray array];
        b.oldDaemon = YES; b.oldDaemonBusy = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"staleHelper"]);
        assert(!b.staleRetiring && [b.staleRetryAfter timeIntervalSinceNow] > 30);
        assert(([b.calls isEqual:@[@"hello", @"reset"]]));
        // Polls and repair do not reconnect, read the stale reply, or alter registration.
        for (int i = 0; i < 10; i++) assert([Run(b, NO)[@"code"] isEqual:@"staleHelper"]);
        assert([Run(b, YES)[@"code"] isEqual:@"staleHelper"] && b.oldDaemon);
        assert(([b.calls isEqual:@[@"hello", @"reset"]]));
        // Simulate idle retirement and the cooldown expiring.
        b.oldDaemon = NO;
        b.staleRetryAfter = [NSDate distantPast];
        NSDictionary *repaired = Run(b, NO);
        assert([repaired[@"code"] isEqual:@"enabled"] && !b.oldDaemon);
        assert([repaired[@"pid"] isEqual:@0] && [repaired[@"exitConfirmed"] isEqual:@YES]);
        assert(([b.calls isEqual:@[@"hello", @"reset", @"hello"]]));
        b.slow = YES;
        NSDictionary *late = Run(b, YES);
        assert([late[@"code"] isEqual:@"timeout"] && !late[@"exitConfirmed"] && !late[@"pid"]);
        assert(![b.calls containsObject:@"unregister"] && ![b.calls containsObject:@"register"] &&
               ![b.calls containsObject:@"exit"]);
        // An enabled helper that does not answer shows what the launcher reported (display only, no side effects).
        b.launcher = @{@"code": @"launcherDowngrade", @"detail": @"launcher result: downgrade"};
        b.slow = YES;
        NSDictionary *refused = Run(b, NO);
        assert([refused[@"code"] isEqual:@"launcherDowngrade"] && [refused[@"detail"] isEqual:@"launcher result: downgrade"]);
        // An "ok" still within its grace period adds detail only; the code stays the bridge's own.
        b.launcher = @{@"detail": @"launcher result: ok"};
        b.slow = YES;
        NSDictionary *waiting = Run(b, NO);
        assert([waiting[@"code"] isEqual:@"timeout"] && [waiting[@"detail"] isEqual:@"launcher result: ok"]);
        // An answering helper never consults the launcher status.
        b.launcher = @{@"code": @"launcherFailed"};
        assert([Run(b, NO)[@"code"] isEqual:@"enabled"]);
        assert(![b.calls containsObject:@"unregister"] && ![b.calls containsObject:@"register"] &&
               ![b.calls containsObject:@"exit"]);
        puts("old-daemon-then-timeout-then-recover");
''' + STALE_VERSION_MAIN + RETIRE_MAIN + r'''
    }
}
'''
        out = compile_and_run(self, source)
        self.assertIn('old-daemon-then-timeout-then-recover', out)
        self.assertIn('stale-version-waits', out)
        self.assertIn('stale-helper-retired', out)

    def test_status_does_not_mutate_registration(self):
        status = method(BRIDGE, '- (void)status:')
        for operation in ('registerAndReturnError', 'unregisterAndReturnError',
                          'registerWithCompletion', 'unregisterWithCompletion',
                          'reRegisterIfUpdated'):
            self.assertNotIn(operation, status)
        self.assertIn('[self registrationStatus]', status)
        self.assertIn('[self request:@"hello"', status)
        repair = method(BRIDGE, '- (void)repairWithCompletion:')
        self.assertIn('[self status:completion]', repair)
        self.assertNotIn('unregister', repair)
        self.assertNotIn('registerWithCompletion', repair)
        self.assertNotIn('@"exit"', repair)

    def test_idle_retirement_requires_no_core_or_uncertainty(self):
        idle = method(SUPERVISOR, '- (void)armIdle')
        self.assertIn('self.child == 0 && !self.ownershipUncertain && self.connections == 0', idle)
        self.assertIn('[self recoverOwnership]', idle)
        status = method(BRIDGE, '- (void)status:')
        self.assertLess(status.index('staleRetryAfter timeIntervalSinceNow'), status.index('[self request:@"hello"'))
        note = method(BRIDGE, '- (BOOL)noteStaleHelper:')
        self.assertIn('dateWithTimeIntervalSinceNow:retiring ? FCStaleRecheckSeconds : 40', note)
        self.assertIn('[self resetConnection]', note)
        self.assertIn('[self noteStaleHelper:answer]', status)

    def test_exit_send_failures_timeout_and_late_reply(self):
        source = BRIDGE_FIXTURE + r'''
#import <xpc/xpc.h>
NSString * const FCHelperIdentifier = @"fixture.helper";
NSString * const FCHelperLabel = @"fixture.label";
static BOOL missingRequirement, missingConnection, rejectedRequirement;
static int sends, cancels;
static int64_t delay;
static void (^replyHandler)(xpc_object_t);
static dispatch_block_t timeoutHandler;
static NSString *FixtureRequirement(NSString *identifier) { return missingRequirement ? nil : @"pinned"; }
static xpc_connection_t FixtureConnection(const char *name, dispatch_queue_t queue, uint64_t flags) {
    assert(!strcmp(name, "fixture.label") && flags == XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    return missingConnection ? nil : (xpc_connection_t)(id)[NSObject new];
}
static int FixturePeer(xpc_connection_t c, const char *requirement) {
    assert(!strcmp(requirement, "pinned")); return rejectedRequirement ? 1 : 0;
}
static void FixtureCancel(xpc_connection_t c) { cancels++; }
static void FixtureResume(xpc_connection_t c) {}
static void FixtureEvent(xpc_connection_t c, void (^handler)(xpc_object_t)) {}
static void FixtureSend(xpc_connection_t c, xpc_object_t message, dispatch_queue_t queue,
                        void (^handler)(xpc_object_t)) {
    assert(!strcmp(xpc_dictionary_get_string(message, "method"), "exit"));
    assert(xpc_dictionary_get_int64(message, "protocol") == 1);
    sends++; replyHandler = [handler copy];
}
static dispatch_time_t FixtureTime(dispatch_time_t now, int64_t delta) { delay = delta; return 1; }
static void FixtureAfter(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
    timeoutHandler = [block copy];
}
#define FCSigningRequirement FixtureRequirement
#define xpc_connection_create_mach_service FixtureConnection
#define xpc_connection_set_peer_code_signing_requirement FixturePeer
#define xpc_connection_cancel FixtureCancel
#define xpc_connection_resume FixtureResume
#define xpc_connection_set_event_handler FixtureEvent
#define xpc_connection_send_message_with_reply FixtureSend
#define dispatch_time FixtureTime
#define dispatch_after FixtureAfter
''' + RETIRE_CONSTANTS + method(BRIDGE, 'static int64_t FCRequestTimeoutSeconds') + r'''
@interface ExitFixture : NSObject
@property dispatch_queue_t queue;
@property BOOL sessionActive, operationInFlight, exitInFlight, exitAnswered;
@property NSString *retireHash;
@property NSUInteger retireAttempts;
@property NSTimeInterval exitSettledAt, clock;
@end
@implementation ExitFixture
- (void)expireSilentSession {}
- (NSString *)currentHelperHash { return @"bundled"; }
- (NSTimeInterval)uptime { return self.clock; }
'''
        for declaration in ('- (BOOL)retireStaleHelper', '- (void)exitSettled:', '- (BOOL)sendExitRequest'):
            source += method(BRIDGE, declaration) + '\n'
        source += r'''
@end
int main(void) {
    @autoreleasepool {
        ExitFixture *b = [ExitFixture new]; b.clock = 100;
        missingRequirement = YES;
        assert(![b retireStaleHelper] && !b.retireAttempts && !sends && !cancels);
        missingRequirement = NO; missingConnection = YES;
        assert(![b retireStaleHelper] && !b.retireAttempts && !sends && !cancels);
        missingConnection = NO; rejectedRequirement = YES;
        assert(![b retireStaleHelper] && !b.retireAttempts && !sends && cancels == 1);
        rejectedRequirement = NO;
        assert([b retireStaleHelper] && b.retireAttempts == 1 && b.exitInFlight && sends == 1);
        assert(delay == 8 * NSEC_PER_SEC);
        b.clock += 7;
        assert([b retireStaleHelper] && sends == 1);
        timeoutHandler();
        assert(!b.exitInFlight && !b.exitAnswered && b.exitSettledAt == 107 && cancels == 2);
        replyHandler(xpc_dictionary_create(NULL, NULL, 0));
        assert(!b.exitAnswered && cancels == 2);
        assert([b retireStaleHelper] && sends == 1);
        b.clock += 2;
        assert([b retireStaleHelper] && sends == 2 && b.retireAttempts == 2);
        replyHandler(XPC_ERROR_CONNECTION_INTERRUPTED);
        assert(!b.exitInFlight && !b.exitAnswered && cancels == 3);
        timeoutHandler(); assert(cancels == 3);
        b.clock += 2;
        assert([b retireStaleHelper] && sends == 3);
        replyHandler(xpc_dictionary_create(NULL, NULL, 0));
        assert(b.exitAnswered && !b.exitInFlight && cancels == 4);
        timeoutHandler(); assert(cancels == 4 && b.exitAnswered);
        b.clock += 2;
        assert(![b retireStaleHelper] && sends == 3);
        puts("exit-transport");
    }
}
'''
        self.assertIn('exit-transport', compile_and_run(self, source))

    def test_exit_request_is_the_helpers_own_on_a_pinned_connection(self):
        send = method(BRIDGE, '- (BOOL)sendExitRequest')
        # Exactly what Supervisor.m reads: `method` "exit" and `protocol` 1.
        self.assertIn('xpc_dictionary_set_string(message, "method", "exit");', send)
        self.assertIn('xpc_dictionary_set_int64(message, "protocol", 1);', send)
        handle = method(SUPERVISOR, '- (void)handle:')
        self.assertIn('xpc_dictionary_get_string(request, "method")', handle)
        self.assertIn('xpc_dictionary_get_int64(request, "protocol") != 1', handle)
        self.assertIn('[action isEqualToString:@"exit"]', handle)
        # Same pinned peer requirement as every other connection; the reply is never read or trusted.
        self.assertIn('FCSigningRequirement(FCHelperIdentifier)', send)
        self.assertIn('xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)', send)
        self.assertLess(send.index('set_peer_code_signing_requirement'), send.index('xpc_connection_resume'))
        for read in ('xpc_dictionary_get_', 'check:', 'self.connection', 'completion', 'reply, "'):
            self.assertNotIn(read, send)
        # Bounded like every other request (8 s), and only a reply that arrived counts as answered.
        self.assertIn('FCRequestTimeoutSeconds(@"exit") * NSEC_PER_SEC', send)
        self.assertIn('close(xpc_get_type(reply) == XPC_TYPE_DICTIONARY);', send)
        self.assertIn('[self exitSettled:answered];', send)
        self.assertLess(send.index('if (!requirement) return NO;'), send.index('return YES;'))
        # Only a validator verdict of "stale running cdhash" leads there; never SMAppService.
        request = method(BRIDGE, '- (void)request:')
        self.assertIn('BOOL stale = dictionary && validator.runningCodeStale;', request)
        self.assertIn('@"runningCodeStale": @YES', request)
        self.assertEqual(request.count('validator.runningCodeStale'), 1)
        note = method(BRIDGE, '- (BOOL)noteStaleHelper:')
        self.assertIn('self.staleRetirable = [answer[@"runningCodeStale"] isEqual:@YES];', note)
        self.assertIn('self.staleRetirable && [self retireStaleHelper]', note)
        retire = method(BRIDGE, '- (BOOL)retireStaleHelper')
        for operation in ('register', 'unregister', 'SMAppService', 'daemon]'):
            self.assertNotIn(operation, retire + send + note)
        self.assertIn('static const NSUInteger FCMaxRetireAttempts = 3;', BRIDGE)
        self.assertEqual(BRIDGE.count('[self sendExitRequest]'), 1)
        self.assertEqual(BRIDGE.count('[self retireStaleHelper]'), 1)



if __name__ == '__main__':
    unittest.main()
