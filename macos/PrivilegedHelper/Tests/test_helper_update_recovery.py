"""Recovery after a helper update or a lost connection (pure fixtures; no daemon, launchd or SMAppService use).

Covers: request timeouts are `timeout`, not `exitUnconfirmed`; `stop` from a later connection of the same
user naming the session; uncertain ownership is retried on hello/start; a previous build's daemon is reported
as `staleHelper` and retired; re-registration after an update is retried and asks for approval again.
"""
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


SUPERVISOR_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <sysexits.h>
#import <sys/wait.h>
#import "SessionPolicy.h"
static NSString * const FCRuntimeDirectory = @"/fixture-runtime";
static const size_t FCMaxFrame = 1024;
static BOOL reapSucceeds, syncSucceeds = YES;
static int unlinkErrno, reaps, unlinks, staged, waits;
static NSMutableArray *replies;
static BOOL FixtureReap(NSString *d) { assert([d isEqual:FCRuntimeDirectory]); reaps++; return reapSucceeds; }
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
#define FCReapOrphanedCores FixtureReap
#define FCRemoveStagedCores FixtureRemoveStaged
#define unlink FixtureUnlink
#define waitpid FixtureWait
#define xpc_connection_get_euid FixtureEuid
#define xpc_connection_cancel FixtureCancel
static BOOL FCRepliesWithCoreToken(NSString *action, NSString *code) { return NO; }

@interface FCGUIMessageValidator : NSObject
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
- (NSData *)receive:(NSString **)code { *code = @"ok"; return nil; }
- (NSString *)send:(NSData *)frame { return @"ok"; }
- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frame:(NSData *)frame coreToken:(NSData *)token {
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

    def test_idle_and_termination_retry_recovery(self):
        idle = method(SUPERVISOR, '- (void)armIdle')
        self.assertLess(idle.index('[self recoverOwnership]'), idle.index('exit(0)'))
        main = method(SUPERVISOR, 'int main(void)')
        self.assertIn('[supervisor recoverOwnership] && [supervisor stop]', main)
        handle = method(SUPERVISOR, '- (void)handle:')
        # Per-message caller validation still comes first.
        self.assertLess(handle.index('[gui check:request]'), handle.index('[self recoverOwnership]'))
        self.assertLess(handle.index('[gui check:request]'), handle.index('FCMayStopSession('))


BRIDGE_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <assert.h>
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
        self.assertIn('finish(@{@"code": @"timeout"})', timer)
        self.assertNotIn('exitUnconfirmed', request)
        # A stale reply is recognised only after the validator rejected it; nothing else of it is read.
        rejected = request[request.index('[validator check:reply]'):request.index('const char *code')]
        self.assertIn('validator.runningCodeStale', rejected)
        self.assertIn('@"staleHelper" : @"unavailable"', rejected)

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

    def test_old_daemon_running_with_new_bundle_then_timeout_then_recover(self):
        source = BRIDGE_FIXTURE + method(BRIDGE, 'static NSString *FCStatusForHello') + r'''
@interface BridgeFixture : NSObject
@property dispatch_queue_t queue;
@property BOOL sessionActive;
@property NSMutableArray *calls;
@property BOOL oldDaemon;      // dev.6 daemon (previous cdhash) still runs beside the new bundle
@property BOOL oldDaemonBusy;  // ... and refuses to leave while it owns a Core
@property BOOL slow;           // the next hello runs out of time
@end
@implementation BridgeFixture
- (NSDictionary *)registrationStatus { return @{@"code": @"enabled"}; }
- (BOOL)reRegisterIfUpdated:(NSString *)code { return NO; }
- (NSString *)currentHelperHash { return @"cdhash-new"; }
- (void)resetConnection { [self.calls addObject:@"reset"]; }
- (void)unregisterWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"unregister"]; c(@{@"code": @"ok"}); }
- (void)registerWithCompletion:(void (^)(NSDictionary *))c { [self.calls addObject:@"register"]; [self status:c]; }
// The daemon as the bridge's request: sees it (validator verdict for the old build -> staleHelper).
- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    [self.calls addObject:method];
    if (self.slow) { self.slow = NO; completion(@{@"code": @"timeout"}); return; }
    if (self.oldDaemon) {
        if ([method isEqual:@"exit"] && !self.oldDaemonBusy) self.oldDaemon = NO;  // it exits; launchd runs the new one next
        completion(@{@"code": @"staleHelper"}); return;
    }
    completion(@{@"code": @"ok", @"protocol": @1, @"pid": @0, @"exitConfirmed": @YES, @"helperCDHash": @"cdhash-new"});
}
'''
        source += method(BRIDGE, '- (void)status:') + '\n'
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
        // New bundle installed over a running old daemon: status says staleHelper, not unavailable.
        b.oldDaemon = YES; b.oldDaemonBusy = YES;
        assert([Run(b, NO)[@"code"] isEqual:@"staleHelper"]);
        // The old daemon still owns a Core: it refuses to exit and repair keeps reporting it.
        assert([Run(b, YES)[@"code"] isEqual:@"staleHelper"] && b.oldDaemon);
        assert(([b.calls isEqual:@[@"hello", @"hello", @"exit", @"reset", @"hello"]]));
        // Once idle it leaves on request and the next hello reaches this build's daemon.
        b.oldDaemonBusy = NO;
        [b.calls removeAllObjects];
        NSDictionary *repaired = Run(b, YES);
        assert([repaired[@"code"] isEqual:@"enabled"] && !b.oldDaemon);
        assert([repaired[@"pid"] isEqual:@0] && [repaired[@"exitConfirmed"] isEqual:@YES]);
        assert(([b.calls isEqual:@[@"hello", @"exit", @"reset", @"hello"]]));
        assert(![b.calls containsObject:@"unregister"]);
        // A hello that runs out of time is a wait (`timeout`), not "exit unconfirmed"; the next one recovers.
        b.slow = YES;
        NSDictionary *late = Run(b, NO);
        assert([late[@"code"] isEqual:@"timeout"] && !late[@"exitConfirmed"] && !late[@"pid"]);
        assert([Run(b, NO)[@"code"] isEqual:@"enabled"]);
        // Repair from a timeout re-registers (the existing repair path for anything not otherwise handled).
        b.slow = YES;
        [b.calls removeAllObjects];
        assert([Run(b, YES)[@"code"] isEqual:@"enabled"]);
        assert(([b.calls isEqual:@[@"hello", @"unregister", @"register", @"hello"]]));
        puts("old-daemon-then-timeout-then-recover");
    }
}
'''
        self.assertIn('old-daemon-then-timeout-then-recover', compile_and_run(self, source))

    def test_re_registration_after_update(self):
        source = BRIDGE_FIXTURE + r'''
static NSMutableDictionary *store;
@interface FixtureDefaults : NSObject
@property (class, readonly) FixtureDefaults *standardUserDefaults;
@end
@implementation FixtureDefaults
+ (FixtureDefaults *)standardUserDefaults { static FixtureDefaults *d; if (!d) d = [FixtureDefaults new]; return d; }
- (NSString *)stringForKey:(NSString *)k { return store[k]; }
- (BOOL)boolForKey:(NSString *)k { return [store[k] boolValue]; }
- (void)setBool:(BOOL)v forKey:(NSString *)k { store[k] = @(v); }
- (void)setObject:(id)v forKey:(NSString *)k { store[k] = v; }
- (void)removeObjectForKey:(NSString *)k { [store removeObjectForKey:k]; }
@end
#define NSUserDefaults FixtureDefaults
static NSString * const FCRegisteredHelperDefault = @"FlashDaemonRegisteredHelperCDHash";
static NSString * const FCApprovedDefault = @"FlashDaemonApproved";
typedef NSUInteger FCLegacyResidue;
#define FCDetectLegacyResidue() ((FCLegacyResidue)0)

@interface FakeDaemon : NSObject
@property SMAppServiceStatus status;
@property SMAppServiceStatus afterRegister;
@property BOOL registerSucceeds;
@property int registers, unregisters;
@end
@implementation FakeDaemon
- (BOOL)registerAndReturnError:(NSError **)error {
    self.registers++;
    self.status = self.afterRegister;
    if (!self.registerSucceeds && error) *error = [NSError errorWithDomain:@"SMAppServiceErrorDomain" code:1 userInfo:nil];
    return self.registerSucceeds;
}
- (BOOL)unregisterAndReturnError:(NSError **)error { self.unregisters++; self.status = SMAppServiceStatusNotRegistered; return YES; }
@end

@interface BridgeFixture : NSObject
@property BOOL reRegistrationChecked;
@property NSUInteger reRegistrationAttempts;
@property BOOL sessionActive;
@property BOOL migrationAttempted;
@property FakeDaemon *fake;
@property int resets;
@end
@implementation BridgeFixture
- (FakeDaemon *)daemon { return self.fake; }
- (NSString *)gate { return @"trusted"; }
- (NSString *)currentHelperHash { return @"cdhash-new"; }
- (void)resetConnection { self.resets++; }
- (NSDictionary *)residueAnswer:(FCLegacyResidue)r code:(NSString *)code { return @{@"code": code}; }
'''
        source += method(BRIDGE, '- (NSDictionary *)registrationStatus') + '\n'
        source += method(BRIDGE, '- (BOOL)reRegisterIfUpdated:') + '\n@end\n'
        source += r'''
static BridgeFixture *Fresh(SMAppServiceStatus status, NSString *stored) {
    store = [NSMutableDictionary dictionary];
    if (stored) store[FCRegisteredHelperDefault] = stored;
    store[FCApprovedDefault] = @YES;
    BridgeFixture *b = [BridgeFixture new];
    b.fake = [FakeDaemon new];
    b.fake.status = status;
    return b;
}
static NSString *Code(SMAppServiceStatus s) {
    return s == SMAppServiceStatusEnabled ? @"enabled" : s == SMAppServiceStatusRequiresApproval ? @"requiresApproval" :
        s == SMAppServiceStatusNotRegistered ? @"notRegistered" : @"notFound";
}
int main(void) {
    @autoreleasepool {
        // Enabled with the previous build's hash: unregister, register; approval asked again (not "turned off").
        BridgeFixture *b = Fresh(SMAppServiceStatusEnabled, @"cdhash-old");
        b.fake.registerSucceeds = YES; b.fake.afterRegister = SMAppServiceStatusRequiresApproval;
        assert([b reRegisterIfUpdated:@"enabled"]);
        assert(b.fake.unregisters == 1 && b.fake.registers == 1 && b.resets == 1 && b.reRegistrationChecked);
        assert([store[FCRegisteredHelperDefault] isEqual:@"cdhash-new"] && !store[FCApprovedDefault]);
        NSDictionary *now = [b registrationStatus];
        assert([now[@"code"] isEqual:@"requiresApproval"] && [now[@"previouslyEnabled"] isEqual:@NO]);
        assert(![b reRegisterIfUpdated:@"requiresApproval"] && b.fake.registers == 1);

        // Register fails and the job reads notRegistered: not marked done, retried on the next status
        // (without another unregister), at most three times per launch.
        b = Fresh(SMAppServiceStatusEnabled, @"cdhash-old");
        b.fake.registerSucceeds = NO; b.fake.afterRegister = SMAppServiceStatusNotRegistered;
        assert([b reRegisterIfUpdated:@"enabled"] && !b.reRegistrationChecked);
        assert([store[FCRegisteredHelperDefault] isEqual:@"cdhash-old"]);
        assert([b reRegisterIfUpdated:Code(b.fake.status)] && b.fake.unregisters == 1 && b.fake.registers == 2);
        b.fake.registerSucceeds = YES; b.fake.afterRegister = SMAppServiceStatusEnabled;
        assert([b reRegisterIfUpdated:Code(b.fake.status)] && b.reRegistrationChecked && b.fake.registers == 3);
        assert([store[FCRegisteredHelperDefault] isEqual:@"cdhash-new"]);
        assert([[b registrationStatus][@"code"] isEqual:@"enabled"] && [store[FCApprovedDefault] isEqual:@YES]);
        b = Fresh(SMAppServiceStatusNotRegistered, @"cdhash-old");
        for (int i = 0; i < 5; i++) [b reRegisterIfUpdated:@"notRegistered"];
        assert(b.fake.registers == 3 && b.reRegistrationChecked && b.fake.unregisters == 0);

        // The job went missing after the app swap (notRegistered / notFound) with a stale stored hash.
        for (NSNumber *status in @[@(SMAppServiceStatusNotRegistered), @(SMAppServiceStatusNotFound)]) {
            b = Fresh((SMAppServiceStatus)status.integerValue, @"cdhash-old");
            b.fake.registerSucceeds = YES; b.fake.afterRegister = SMAppServiceStatusRequiresApproval;
            assert([b reRegisterIfUpdated:Code(b.fake.status)] && b.fake.registers == 1 && b.fake.unregisters == 0);
            assert([[b registrationStatus][@"previouslyEnabled"] isEqual:@NO]);
        }
        // Never registered by this app, or turned off with "disable" (no stored hash): left alone.
        b = Fresh(SMAppServiceStatusNotRegistered, nil);
        assert(![b reRegisterIfUpdated:@"notRegistered"] && b.fake.registers == 0);
        // Same build, or a session running: nothing.
        b = Fresh(SMAppServiceStatusEnabled, @"cdhash-new");
        assert(![b reRegisterIfUpdated:@"enabled"] && b.reRegistrationChecked && b.fake.registers == 0);
        b = Fresh(SMAppServiceStatusEnabled, @"cdhash-old");
        b.sessionActive = YES;
        assert(![b reRegisterIfUpdated:@"enabled"] && b.fake.registers == 0 && b.fake.unregisters == 0);
        puts("re-registration");
    }
}
'''
        self.assertIn('re-registration', compile_and_run(
            self, source, frameworks=('Foundation', 'ServiceManagement')))


if __name__ == '__main__':
    unittest.main()
