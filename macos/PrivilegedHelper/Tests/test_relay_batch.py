"""The daemon's relay batches and adoption (pure fixtures: the real `receive:` and `adopt:` over a socketpair; no
daemon, Core or XPC peer)."""
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


def constant(source, name):
    return next(line for line in source.splitlines() if re.match(rf'static const \w+ {name} = ', line))


def compile_and_run(test, source):
    with tempfile.TemporaryDirectory(prefix='flash-relay-batch-') as directory:
        root = Path(directory)
        (root / 'fixture.m').write_text(source)
        result = subprocess.run([
            'clang', '-fobjc-arc', '-fblocks', '-Werror', '-mmacosx-version-min=14.0',
            '-I', str(MACOS / 'Shared'), '-I', str(MACOS / 'PrivilegedHelper'),
            str(root / 'fixture.m'), '-framework', 'Foundation', '-o', str(root / 'fixture'),
        ], capture_output=True, text=True, timeout=60)
        test.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=20)
        test.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return result.stdout


SUPERVISOR_FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <os/log.h>
#import <sys/socket.h>
#import "SessionPolicy.h"
static os_log_t FCHelperLog(void) { return OS_LOG_DEFAULT; }
static const size_t FCMaxFrame = 1024;
static const NSUInteger FCRelayBatchFrames = 64;
''' + constant(SUPERVISOR, 'FCBatchBytes') + '\n' + constant(SUPERVISOR, 'FCMaxAdoptions') + '\n' + \
    constant(SUPERVISOR, 'FCAdoptionWindowSeconds') + r'''
static pid_t tokenPid = 500;
static uint32_t tokenVersion = 7;
static void FixtureToken(xpc_object_t message, audit_token_t *token) { token->val[5] = tokenPid; token->val[7] = tokenVersion; }
#define FCMessageAuditToken FixtureToken
static uid_t FixtureEuid(xpc_connection_t c) { return 501; }
#define xpc_connection_get_euid FixtureEuid

@interface SupervisorFixture : NSObject
@property int socket;
@property NSMutableData *incoming;
@property NSMutableArray<NSData *> *outgoing;
@property uint64_t outgoingBase;
@property pid_t child;
@property BOOL exited;
@property int stops;
@property xpc_connection_t owner;
@property NSString *session;
@property uid_t uid;
@property pid_t ownerPid;
@property uint32_t ownerPidVersion;
@property int adoptions;
@property uint64_t adoptionsSince;
@end
@implementation SupervisorFixture
- (BOOL)confirmExit {
    if (!self.exited) return NO;
    // As the real one: closes the relay, dropping whatever is still queued.
    self.child = 0; self.socket = -1; [self.outgoing removeAllObjects]; [self.incoming setLength:0];
    return YES;
}
- (BOOL)stop { self.stops++; return [self confirmExit]; }
''' + method(SUPERVISOR, '- (NSArray<NSData *> *)receive:') + '\n' + method(SUPERVISOR, '- (void)noteOwner:') + '\n' + \
    method(SUPERVISOR, '- (BOOL)adopt:') + r'''
@end
static void Write(int fd, size_t size, uint8_t fill) {
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)size);
    NSMutableData *wire = [NSMutableData dataWithBytes:&length length:4];
    NSMutableData *body = [NSMutableData dataWithLength:size];
    memset(body.mutableBytes, fill, size);
    [wire appendData:body];
    assert(write(fd, wire.bytes, wire.length) == (ssize_t)wire.length);
}
static SupervisorFixture *Fixture(int *core) {
    int pair[2];
    assert(!socketpair(AF_UNIX, SOCK_STREAM, 0, pair));
    assert(!fcntl(pair[0], F_SETFL, O_NONBLOCK));
    SupervisorFixture *s = [SupervisorFixture new];
    s.socket = pair[0]; *core = pair[1];
    s.incoming = [NSMutableData data]; s.outgoing = [NSMutableArray array];
    s.child = 42;
    return s;
}
'''


class RelayBatchTests(unittest.TestCase):
    def run_main(self, body):
        source = SUPERVISOR_FIXTURE + 'int main(void) {\n    @autoreleasepool {\n' + body + '\n    }\n}\n'
        return compile_and_run(self, source)

    def test_batches_stay_within_the_bridge_limit(self):
        self.assertIn('oversized-ok', self.run_main(r'''
        int core; SupervisorFixture *s = Fixture(&core);
        NSString *code; uint64_t base;
        // 600 + 600 > FCMaxFrame: the second frame waits for the next batch; a full-size frame goes alone.
        Write(core, 600, 1); Write(core, 600, 2); Write(core, 1024, 3); Write(core, 10, 4);
        NSArray *batch = [s receive:0 base:&base code:&code];
        assert([code isEqual:@"ok"] && base == 0 && batch.count == 1 && [batch[0] length] == 600);
        batch = [s receive:1 base:&base code:&code];
        assert(base == 1 && batch.count == 1 && ((const uint8_t *)[batch[0] bytes])[0] == 2);
        batch = [s receive:2 base:&base code:&code];
        assert(base == 2 && batch.count == 1 && [batch[0] length] == 1024);
        batch = [s receive:3 base:&base code:&code];
        assert(base == 3 && batch.count == 1 && [batch[0] length] == 10);
        // Every batch the bridge gets is within FCMaxFrame in total; a lost reply is answered again.
        batch = [s receive:3 base:&base code:&code];
        assert(base == 3 && batch.count == 1);
        batch = [s receive:4 base:&base code:&code];
        assert([code isEqual:@"ok"] && batch.count == 0);
        puts("oversized-ok");
'''))

    def test_last_frames_are_delivered_before_the_exit(self):
        self.assertIn('last-frames-ok', self.run_main(r'''
        int core; SupervisorFixture *s = Fixture(&core);
        NSString *code; uint64_t base;
        Write(core, 5, 1); Write(core, 6, 2);
        close(core);
        s.exited = YES;  // the Core is gone, its socket at EOF
        NSArray *batch = [s receive:0 base:&base code:&code];
        assert([code isEqual:@"ok"] && batch.count == 2);
        batch = [s receive:2 base:&base code:&code];
        assert([code isEqual:@"disconnected"] && !batch && s.stops == 1);
        puts("last-frames-ok");
'''))

    def test_adoption_is_bounded(self):
        self.assertIn('adoption-ok', self.run_main(r'''
        int core; SupervisorFixture *s = Fixture(&core);
        s.session = @"0123456789abcdef0123456789abcdef"; s.uid = 501;
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        [s noteOwner:request];
        s.owner = (xpc_connection_t)(id)[NSObject new];
        for (int i = 0; i < FCMaxAdoptions; i++) {
            xpc_connection_t next = (xpc_connection_t)(id)[NSObject new];
            assert([s adopt:request connection:next session:s.session] && s.owner == next);
        }
        xpc_connection_t late = (xpc_connection_t)(id)[NSObject new];
        assert(![s adopt:request connection:late session:s.session] && s.owner != late);
        // Another process (pid version) or session never adopts; a new session starts counting afresh.
        tokenVersion = 8;
        [s noteOwner:request];
        tokenVersion = 9;
        assert(![s adopt:request connection:late session:s.session]);
        tokenVersion = 8;
        assert(![s adopt:request connection:late session:@"1123456789abcdef0123456789abcdef"]);
        assert([s adopt:request connection:late session:s.session] && s.owner == late);
        puts("adoption-ok");
'''))


WAIT_FIXTURE = r"""
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <fcntl.h>
#import <os/log.h>
#import <sys/socket.h>
#import <unistd.h>
static os_log_t FCHelperLog(void) { return OS_LOG_DEFAULT; }
static const size_t FCMaxFrame = 1024;
static const NSUInteger FCRelayBatchFrames = 64;
""" + constant(SUPERVISOR, 'FCBatchBytes') + '\n' + constant(SUPERVISOR, 'FCReceiveWaitMaxMilliseconds') + '\n' + \
    constant(SUPERVISOR, 'FCOwnerGraceSeconds') + r"""
@interface WaitFixture : NSObject
@property dispatch_queue_t queue;
@property int socket, listener;
@property NSString *socketPath;
@property NSData *coreToken;
@property NSMutableData *incoming;
@property NSMutableArray<NSData *> *outgoing;
@property uint64_t outgoingBase, written;
@property pid_t child, ownerPid;
@property BOOL exited;
@property int stops;
@property xpc_connection_t owner;
@property xpc_object_t waiting;
@property xpc_connection_t waitingConnection;
@property uint64_t waitingAck;
@property dispatch_source_t waitingRead;
@property dispatch_source_t waitingTimer;
@property NSMutableArray<NSDictionary *> *replies;
@property dispatch_semaphore_t replied;
@end
@implementation WaitFixture
- (BOOL)confirmExit {
    if (!self.exited) return NO;
    self.child = 0;
    [self closeRelay];
    return YES;
}
- (BOOL)stop { self.stops++; [self closeRelay]; self.exited = YES; return [self confirmExit]; }
- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frames:(NSArray<NSData *> *)frames
    base:(uint64_t)base coreToken:(NSData *)coreToken sweep:(NSDictionary *)sweep {
    assert(!coreToken);
    [self.replies addObject:@{@"request": request, @"code": code, @"frames": frames ?: NSNull.null, @"base": @(base),
        @"at": @(clock_gettime_nsec_np(CLOCK_MONOTONIC))}];
    dispatch_semaphore_signal(self.replied);
}
""" + method(SUPERVISOR, '- (void)closeRelay') + '\n' + method(SUPERVISOR, '- (NSArray<NSData *> *)receive:') + '\n' + \
    method(SUPERVISOR, '- (void)releaseWait') + '\n' + method(SUPERVISOR, '- (BOOL)holdReceive:') + '\n' + \
    method(SUPERVISOR, '- (void)answerWaiting:') + '\n' + method(SUPERVISOR, '- (void)supersedeWaiting') + '\n' + \
    method(SUPERVISOR, '- (void)ownerLost:') + r"""
@end
static uint64_t Now(void) { return clock_gettime_nsec_np(CLOCK_MONOTONIC); }
static int OpenFds(void) { int n = 0; for (int fd = 0; fd < 256; fd++) n += fcntl(fd, F_GETFD) != -1; return n; }
static void Write(int fd, size_t size, uint8_t fill) {
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)size);
    NSMutableData *wire = [NSMutableData dataWithBytes:&length length:4];
    NSMutableData *body = [NSMutableData dataWithLength:size];
    memset(body.mutableBytes, fill, size);
    [wire appendData:body];
    assert(write(fd, wire.bytes, wire.length) == (ssize_t)wire.length);
}
static WaitFixture *Fixture(int *core) {
    int pair[2];
    assert(!socketpair(AF_UNIX, SOCK_STREAM, 0, pair));
    assert(!fcntl(pair[0], F_SETFL, O_NONBLOCK));
    WaitFixture *s = [WaitFixture new];
    s.queue = dispatch_queue_create("wait-fixture", DISPATCH_QUEUE_SERIAL);
    s.socket = pair[0]; s.listener = -1; *core = pair[1];
    s.incoming = [NSMutableData data]; s.outgoing = [NSMutableArray array];
    s.replies = [NSMutableArray array]; s.replied = dispatch_semaphore_create(0);
    s.child = 42;
    return s;
}
// As handle: does for a receive: a held one is replaced, then this one answers now unless nothing is queued and it
// names a wait.
static BOOL Receive(WaitFixture *s, xpc_object_t request, xpc_connection_t connection, uint64_t ack, uint64_t wait) {
    __block BOOL held = NO;
    dispatch_sync(s.queue, ^{
        [s supersedeWaiting];
        uint64_t base; NSString *code;
        NSArray *frames = [s receive:ack base:&base code:&code];
        if (frames && !frames.count && [s holdReceive:request connection:connection ack:ack wait:wait]) { held = YES; return; }
        [s reply:request code:code pid:s.child frames:frames base:base coreToken:nil sweep:nil];
    });
    return held;
}
static NSDictionary *Await(WaitFixture *s, int64_t ms) {
    if (dispatch_semaphore_wait(s.replied, dispatch_time(DISPATCH_TIME_NOW, ms * NSEC_PER_MSEC))) return nil;
    __block NSDictionary *last;
    dispatch_sync(s.queue, ^{ last = s.replies.lastObject; });
    return last;
}
static void Settle(WaitFixture *s) {
    for (int i = 0; i < 3; i++) dispatch_sync(s.queue, ^{});
    usleep(20000);
    for (int i = 0; i < 3; i++) dispatch_sync(s.queue, ^{});
}
"""


class ReceiveWaitTests(unittest.TestCase):
    """A receive that names `wait` is held for the Core's next frame (real methods over a socketpair)."""

    def run_main(self, body):
        source = WAIT_FIXTURE + 'int main(void) {\n    @autoreleasepool {\n' + body + '\n    }\n}\n'
        return compile_and_run(self, source)

    def test_without_wait_an_empty_receive_answers_at_once(self):
        self.assertIn('nowait-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        assert(!Receive(s, request, nil, 0, 0));
        NSDictionary *reply = Await(s, 100);
        assert(reply && [reply[@"code"] isEqual:@"ok"] && [reply[@"frames"] count] == 0 && !s.waiting);
        puts("nowait-ok");
"""))

    def test_a_held_receive_answers_when_a_frame_arrives(self):
        out = self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, request, nil, 0, 4000));
        assert(!Await(s, 100));
        // Half a frame keeps waiting; the rest answers at once.
        uint32_t length = CFSwapInt32HostToLittle(3);
        assert(write(core, &length, 4) == 4);
        assert(!Await(s, 100));
        uint64_t written = Now();
        assert(write(core, "abc", 3) == 3);
        NSDictionary *reply = Await(s, 1000);
        assert(reply && reply[@"request"] == request && [reply[@"code"] isEqual:@"ok"]);
        assert([reply[@"frames"] count] == 1 && [reply[@"frames"][0] isEqual:[NSData dataWithBytes:"abc" length:3]]);
        uint64_t latency = [reply[@"at"] unsignedLongLongValue] - written;
        assert(latency < 50 * NSEC_PER_MSEC);
        Settle(s);
        assert(!s.waiting && !s.waitingRead && !s.waitingTimer && OpenFds() == fds && s.replies.count == 1);
        printf("arrival-ok latency_us=%llu\n", latency / 1000);
""")
        self.assertIn('arrival-ok', out)

    def test_a_held_receive_answers_empty_when_its_wait_expires(self):
        out = self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        uint64_t held = Now();
        assert(Receive(s, request, nil, 0, 200));
        NSDictionary *reply = Await(s, 2000);
        uint64_t waited = [reply[@"at"] unsignedLongLongValue] - held;
        assert(reply && [reply[@"code"] isEqual:@"ok"] && [reply[@"frames"] count] == 0 && [reply[@"base"] isEqual:@0]);
        assert(waited >= 190 * NSEC_PER_MSEC && waited < 600 * NSEC_PER_MSEC);
        Settle(s);
        assert(!s.waiting && OpenFds() == fds && s.replies.count == 1);
        // Frames queued meanwhile go with the next receive, which is not held.
        Write(core, 4, 7);
        assert(!Receive(s, xpc_dictionary_create(NULL, NULL, 0), nil, 0, 200));
        reply = Await(s, 100);
        assert([reply[@"frames"] count] == 1);
        printf("expiry-ok waited_ms=%llu\n", waited / NSEC_PER_MSEC);
""")
        self.assertIn('expiry-ok', out)

    def test_stop_and_core_exit_answer_a_held_receive_promptly(self):
        self.assertIn('stop-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, request, nil, 0, 4000));
        uint64_t stopped = Now();
        dispatch_sync(s.queue, ^{ [s stop]; });
        NSDictionary *reply = Await(s, 500);
        assert(reply && reply[@"request"] == request && [reply[@"code"] isEqual:@"disconnected"]);
        assert(reply[@"frames"] == NSNull.null && [reply[@"at"] unsignedLongLongValue] - stopped < 100 * NSEC_PER_MSEC);
        Settle(s);
        assert(!s.waiting && s.replies.count == 1);
        close(core);
        assert(OpenFds() == fds - 2);
        // The Core ends by itself (socket at EOF) while a receive is held: its end is the answer.
        s = Fixture(&core);
        fds = OpenFds();
        request = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, request, nil, 0, 4000));
        s.exited = YES;
        close(core);
        reply = Await(s, 500);
        assert(reply && [reply[@"code"] isEqual:@"disconnected"] && s.stops == 1);
        Settle(s);
        assert(!s.waiting && s.replies.count == 1 && OpenFds() == fds - 2);
        puts("stop-ok");
"""))

    def test_a_lost_connection_or_a_newer_receive_releases_the_held_one(self):
        self.assertIn('release-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_connection_t first = (xpc_connection_t)(id)[NSObject new];
        xpc_connection_t second = (xpc_connection_t)(id)[NSObject new];
        s.owner = first; s.ownerPid = getpid();
        xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, request, first, 0, 4000));
        // The app's connection went away mid-wait: nothing is answered on it, the Core is kept for the grace period.
        dispatch_sync(s.queue, ^{ [s ownerLost:first]; });
        Settle(s);
        assert(!s.waiting && s.replies.count == 0 && s.stops == 0 && s.socket >= 0 && OpenFds() == fds);
        // The resumed relay holds again; a retry of it (its bridge request timed out) replaces the first.
        s.owner = second;
        xpc_object_t again = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, again, second, 0, 4000));
        xpc_object_t retry = xpc_dictionary_create(NULL, NULL, 0);
        assert(Receive(s, retry, second, 0, 4000));
        NSDictionary *reply = Await(s, 100);
        assert(reply[@"request"] == again && [reply[@"code"] isEqual:@"ok"] && [reply[@"frames"] count] == 0);
        Write(core, 2, 9);
        reply = Await(s, 1000);
        assert(reply[@"request"] == retry && [reply[@"frames"] count] == 1);
        Settle(s);
        assert(s.replies.count == 2 && OpenFds() == fds);
        puts("release-ok");
"""))

    def test_only_a_receive_naming_a_wait_is_held_and_never_past_the_cap(self):
        handle = method(SUPERVISOR, '- (void)handle:')
        receive = handle[handle.index('else if ([action isEqualToString:@"receive"])'):]
        receive = receive[:receive.index('else if ([action isEqualToString:@"send"])')]
        self.assertIn('[self supersedeWaiting]', receive)
        self.assertIn('xpc_dictionary_get_uint64(request, "wait")', receive)
        self.assertIn('MIN(milliseconds, FCReceiveWaitMaxMilliseconds)', method(SUPERVISOR, '- (BOOL)holdReceive:'))
        cap = int(re.search(r'FCReceiveWaitMaxMilliseconds = (\d+);', SUPERVISOR).group(1))
        timeout = re.search(r'\? 30 : (\d+);', BRIDGE)
        self.assertLess(cap, int(timeout.group(1)) * 1000)
        self.assertIn('@"wait"', method(BRIDGE, '- (void)request:'))


class BridgeSessionHoldTests(unittest.TestCase):
    def test_silent_session_is_released(self):
        source = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
#import <os/log.h>
static os_log_t FCBridgeLog(void) { return OS_LOG_DEFAULT; }
@interface BridgeFixture : NSObject
@property BOOL sessionActive;
@property NSTimeInterval lastVerifiedReply;
@property NSTimeInterval clock;
@property int forgets;
@end
@implementation BridgeFixture
- (NSTimeInterval)uptime { return self.clock; }
- (void)forgetCore { self.forgets++; }
''' + constant(BRIDGE, 'FCSessionSilenceSeconds') + '\n' + method(BRIDGE, '- (void)expireSilentSession') + r'''
@end
int main(void) {
    @autoreleasepool {
        BridgeFixture *b = [BridgeFixture new];
        b.sessionActive = YES; b.clock = 100; b.lastVerifiedReply = 100;
        b.clock = 129; [b expireSilentSession];
        assert(b.sessionActive && b.forgets == 0);
        b.clock = 131; [b expireSilentSession];
        assert(!b.sessionActive && b.forgets == 1);
        [b expireSilentSession];
        assert(b.forgets == 1);
        puts("silent-ok");
    }
}
'''
        self.assertIn('silent-ok', compile_and_run(self, source))

    def test_unanswered_requests_and_holders_check_silence(self):
        request = method(BRIDGE, '- (void)request:')
        self.assertEqual(request.count('[self expireSilentSession]'), 2)
        self.assertIn('self.lastVerifiedReply = [self uptime]', request)
        for name in ('- (void)repairWithCompletion:', '- (void)unregisterWithCompletion:', '- (void)status:'):
            body = method(BRIDGE, name)
            self.assertLess(body.index('[self expireSilentSession]'), body.index('self.sessionActive'), name)


if __name__ == '__main__':
    unittest.main()
