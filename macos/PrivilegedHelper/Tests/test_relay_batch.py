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


def wait_fixture(variant='stub'):
    """The real hold methods of Supervisor.m over a socketpair. `stub`: a stand-in stop and a recording reply; `stop`: the
    real -stop over a forked stand-in Core; `xpc`: the real -reply: to a peer on an anonymous XPC connection."""
    stop = r"""
- (BOOL)confirmExit {
    if (!self.exited) return NO;
    self.child = 0;
    [self closeRelay];
    return YES;
}
- (BOOL)stop { self.stops++; [self closeRelay]; self.exited = YES; return [self confirmExit]; }
""" if variant != 'stop' else r"""
- (BOOL)confirmExit {
    if (!self.child) return YES;
    int status;
    if (waitpid(self.child, &status, WNOHANG) != self.child) return NO;
    self.child = 0;
    [self closeRelay];
    return YES;
}
""" + method(SUPERVISOR, '- (BOOL)stop')
    reply = method(SUPERVISOR, '- (void)reply:(xpc_object_t)request') if variant == 'xpc' else r"""
- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frames:(NSArray<NSData *> *)frames
    base:(uint64_t)base coreToken:(NSData *)coreToken sweep:(NSDictionary *)sweep {
    assert(!coreToken);
    [self.replies addObject:@{@"request": request, @"code": code, @"frames": frames ?: NSNull.null, @"base": @(base),
        @"pid": @(pid), @"at": @(clock_gettime_nsec_np(CLOCK_MONOTONIC))}];
    dispatch_semaphore_signal(self.replied);
}
"""
    return r"""
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <fcntl.h>
#import <os/log.h>
#import <poll.h>
#import <signal.h>
#import <sys/socket.h>
#import <sys/wait.h>
#import <unistd.h>
#import "HelperCompatibility.h"
#define FC_HELPER_BUILD "0"
static os_log_t FCHelperLog(void) { return OS_LOG_DEFAULT; }
static const size_t FCMaxFrame = 1024;
static const NSUInteger FCRelayBatchFrames = 64;
""" + constant(SUPERVISOR, 'FCBatchBytes') + '\n' + constant(SUPERVISOR, 'FCReceiveWaitMaxMilliseconds') + '\n' + \
        constant(SUPERVISOR, 'FCReceiveHoldLateMilliseconds') + '\n' + constant(SUPERVISOR, 'FCOwnerGraceSeconds') + r"""
@interface WaitFixture : NSObject
@property dispatch_queue_t queue;
@property int socket, listener;
@property NSString *socketPath;
@property NSData *coreToken;
@property NSString *coreHash, *runningHash;
@property NSDictionary *contract;
@property NSMutableData *incoming;
@property NSMutableArray<NSData *> *outgoing;
@property uint64_t outgoingBase, written;
@property pid_t child, ownerPid;
@property BOOL exited, ownershipUncertain;
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
""" + stop + reply + method(SUPERVISOR, '- (void)closeRelay') + '\n' + \
        method(SUPERVISOR, '- (NSArray<NSData *> *)receive:') + '\n' + method(SUPERVISOR, '- (void)releaseWait') + '\n' + \
        method(SUPERVISOR, '- (BOOL)holdReceive:') + '\n' + method(SUPERVISOR, '- (void)answerWaiting:') + '\n' + \
        method(SUPERVISOR, '- (void)supersedeWaiting') + '\n' + method(SUPERVISOR, '- (void)ownerLost:') + r"""
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
static WaitFixture *FixtureOn(int local, int core) {
    assert(!fcntl(local, F_SETFL, O_NONBLOCK));
    WaitFixture *s = [WaitFixture new];
    s.queue = dispatch_queue_create("wait-fixture", DISPATCH_QUEUE_SERIAL);
    s.socket = local; s.listener = -1;
    s.incoming = [NSMutableData data]; s.outgoing = [NSMutableArray array];
    s.replies = [NSMutableArray array]; s.replied = dispatch_semaphore_create(0);
    s.child = 42;
    return s;
}
static WaitFixture *Fixture(int *core) {
    int pair[2];
    assert(!socketpair(AF_UNIX, SOCK_STREAM, 0, pair));
    *core = pair[1];
    return FixtureOn(pair[0], pair[1]);
}
// A receive as the bridge sends it: `wait` ms, stamped `sentAgo` ms ago (-1: no stamp).
static xpc_object_t Request(uint64_t ack, uint64_t wait, int64_t sentAgo) {
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(request, "method", "receive");
    xpc_dictionary_set_uint64(request, "ack", ack);
    if (wait) xpc_dictionary_set_uint64(request, "wait", wait);
    if (sentAgo >= 0)
        xpc_dictionary_set_uint64(request, "sent", clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - (uint64_t)sentAgo * NSEC_PER_MSEC);
    return request;
}
// handle:'s receive branch, on the supervisor queue.
static BOOL ReceiveOnQueue(WaitFixture *s, xpc_object_t request, xpc_connection_t connection) {
    uint64_t ack = xpc_dictionary_get_uint64(request, "ack");
    [s supersedeWaiting];
    uint64_t base; NSString *code;
    NSArray *frames = [s receive:ack base:&base code:&code];
    if (frames && !frames.count && [s holdReceive:request connection:connection ack:ack]) return YES;
    [s reply:request code:code pid:s.child frames:frames base:base coreToken:nil sweep:nil];
    return NO;
}
static BOOL Receive(WaitFixture *s, xpc_object_t request, xpc_connection_t connection) {
    __block BOOL held = NO;
    dispatch_sync(s.queue, ^{ held = ReceiveOnQueue(s, request, connection); });
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
    """A receive that names `wait` is held for the Core's next frame (the real methods, in process)."""

    def run_main(self, body, variant='stub'):
        source = wait_fixture(variant) + 'int main(void) {\n    @autoreleasepool {\n' + body + '\n    }\n}\n'
        return compile_and_run(self, source)

    def test_only_a_fresh_stamped_wait_is_held(self):
        self.assertIn('hold-rules-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        // An app from before (no wait), a bridge stamp missing, late (queue stalled > 1 s) or from the future, or
        // a wait already over: answered at once.
        xpc_object_t answered[] = {Request(0, 0, -1), Request(0, 3000, -1), Request(0, 3000, 1500), Request(0, 3000, -5000),
            Request(0, 300, 400)};
        for (int i = 0; i < 5; i++) {
            assert(!Receive(s, answered[i], nil));
            NSDictionary *reply = Await(s, 100);
            assert(reply[@"request"] == answered[i] && [reply[@"code"] isEqual:@"ok"] && !s.waiting);
        }
        // The hold ends `wait` after the bridge sent it, not after the queue got to it.
        uint64_t held = Now();
        xpc_object_t request = Request(0, 700, 500);
        assert(Receive(s, request, nil));
        NSDictionary *reply = Await(s, 2000);
        uint64_t waited = [reply[@"at"] unsignedLongLongValue] - held;
        assert(reply[@"request"] == request && waited >= 150 * NSEC_PER_MSEC && waited < 450 * NSEC_PER_MSEC);
        puts("hold-rules-ok");
"""))

    def test_a_held_receive_answers_when_a_frame_arrives(self):
        self.assertIn('arrival-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = Request(0, 4000, 0);
        assert(Receive(s, request, nil));
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
        assert([reply[@"at"] unsignedLongLongValue] - written < 50 * NSEC_PER_MSEC);
        Settle(s);
        assert(!s.waiting && !s.waitingRead && !s.waitingTimer && OpenFds() == fds && s.replies.count == 1);
        puts("arrival-ok");
"""))

    def test_a_held_receive_answers_empty_when_its_wait_expires(self):
        self.assertIn('expiry-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = Request(0, 200, 0);
        uint64_t held = Now();
        assert(Receive(s, request, nil));
        NSDictionary *reply = Await(s, 2000);
        uint64_t waited = [reply[@"at"] unsignedLongLongValue] - held;
        assert(reply && [reply[@"code"] isEqual:@"ok"] && [reply[@"frames"] count] == 0 && [reply[@"base"] isEqual:@0]);
        assert(waited >= 190 * NSEC_PER_MSEC && waited < 600 * NSEC_PER_MSEC);
        Settle(s);
        assert(!s.waiting && OpenFds() == fds && s.replies.count == 1);
        // Frames queued meanwhile go with the next receive, which is not held.
        Write(core, 4, 7);
        assert(!Receive(s, Request(0, 200, 0), nil));
        reply = Await(s, 100);
        assert([reply[@"frames"] count] == 1);
        puts("expiry-ok");
"""))

    def test_closing_the_relay_ends_the_core_socket_and_the_held_receive_at_once(self):
        self.assertIn('close-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        assert(!fcntl(core, F_SETFL, O_NONBLOCK));
        xpc_object_t request = Request(0, 4000, 0);
        assert(Receive(s, request, nil));
        dispatch_sync(s.queue, ^{
            [s closeRelay];
            // Still inside this queue turn, as a stop that goes on to signal and wait for the Core: the held source's
            // cancellation (which closes its duplicate) has not run, yet the Core already reads the end, and the
            // held receive was answered with the state of this moment.
            char byte;
            assert(read(core, &byte, 1) == 0);
            assert(s.replies.count == 1 && [s.replies[0][@"code"] isEqual:@"disconnected"] &&
                s.replies[0][@"request"] == request && [s.replies[0][@"pid"] isEqual:@42]);
        });
        Settle(s);
        assert(!s.waiting && s.replies.count == 1);
        puts("close-ok");
"""))

    def test_stop_lets_the_core_read_the_end_before_its_sigterm(self):
        self.assertEqual(self.run_main(r"""
        int pair[2], report[2];
        assert(!socketpair(AF_UNIX, SOCK_STREAM, 0, pair) && !pipe(report));
        pid_t child = fork();
        if (child == 0) {
            // A stand-in Core: once SIGTERM comes, it reports whether the end of its socket was readable by then.
            close(pair[0]); close(report[0]);
            sigset_t term; sigemptyset(&term); sigaddset(&term, SIGTERM);
            sigprocmask(SIG_BLOCK, &term, NULL);
            write(report[1], "R", 1);
            int signal;
            sigwait(&term, &signal);
            struct pollfd ready = { .fd = pair[1], .events = POLLIN };
            char byte;
            if (poll(&ready, 1, 0) == 1 && read(pair[1], &byte, 1) == 0) write(report[1], "E", 1);
            write(report[1], "T", 1);
            _exit(0);
        }
        close(pair[1]); close(report[1]);
        char ready;
        assert(read(report[0], &ready, 1) == 1 && ready == 'R');
        WaitFixture *s = FixtureOn(pair[0], -1);
        s.child = child;
        assert(Receive(s, Request(0, 4000, 0), nil));
        // The real -stop: it closes the relay, then signals and waits for the Core within this one queue turn, before
        // the held source's cancellation can close its duplicate of the socket.
        __block BOOL stopped;
        dispatch_sync(s.queue, ^{ stopped = [s stop]; });
        assert(stopped && !s.child);
        char seen[8] = {0};
        ssize_t n = 0, r;
        while ((r = read(report[0], seen + n, sizeof(seen) - 1 - n)) > 0) n += r;
        printf("%s\n", seen);
        Settle(s);
        assert(!s.waiting && s.replies.count == 1);
""", variant='stop').strip().splitlines()[-1], 'ET')

    def test_stop_and_core_exit_answer_a_held_receive_promptly(self):
        self.assertIn('stop-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        int fds = OpenFds();
        xpc_object_t request = Request(0, 4000, 0);
        assert(Receive(s, request, nil));
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
        request = Request(0, 4000, 0);
        assert(Receive(s, request, nil));
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
        assert(Receive(s, Request(0, 4000, 0), first));
        // The app's connection went away mid-wait: nothing is answered on it, the Core is kept for the grace period.
        dispatch_sync(s.queue, ^{ [s ownerLost:first]; });
        Settle(s);
        assert(!s.waiting && s.replies.count == 0 && s.stops == 0 && s.socket >= 0 && OpenFds() == fds);
        // The resumed relay holds again; a retry of it (its bridge request timed out) replaces the first.
        s.owner = second;
        xpc_object_t again = Request(0, 4000, 0);
        assert(Receive(s, again, second));
        xpc_object_t retry = Request(0, 4000, 0);
        assert(Receive(s, retry, second));
        NSDictionary *reply = Await(s, 100);
        assert(reply[@"request"] == again && [reply[@"code"] isEqual:@"ok"] && [reply[@"frames"] count] == 0);
        Write(core, 2, 9);
        reply = Await(s, 1000);
        assert(reply[@"request"] == retry && [reply[@"frames"] count] == 1);
        Settle(s);
        assert(s.replies.count == 2 && OpenFds() == fds);
        puts("release-ok");
"""))

    def test_held_replies_reach_a_real_xpc_peer_and_a_gone_one_is_harmless(self):
        self.assertIn('xpc-ok', self.run_main(r"""
        int core; WaitFixture *s = Fixture(&core);
        __block BOOL keepHeld = NO;
        __block int lost = 0;
        xpc_connection_t listener = xpc_connection_create(NULL, s.queue);
        xpc_connection_set_event_handler(listener, ^(xpc_object_t peer) {
            if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
            xpc_connection_set_target_queue(peer, s.queue);
            xpc_connection_set_event_handler(peer, ^(xpc_object_t message) {
                if (xpc_get_type(message) == XPC_TYPE_DICTIONARY) { ReceiveOnQueue(s, message, peer); return; }
                lost++;
                if (!keepHeld) [s ownerLost:peer];
            });
            xpc_connection_resume(peer);
        });
        xpc_connection_resume(listener);
        xpc_endpoint_t endpoint = xpc_endpoint_create(listener);
        dispatch_queue_t app = dispatch_queue_create("app", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t (^Connect)(void) = ^{
            xpc_connection_t client = xpc_connection_create_from_endpoint(endpoint);
            xpc_connection_set_event_handler(client, ^(xpc_object_t event) {});
            xpc_connection_resume(client);
            return client;
        };
        __block xpc_object_t answer;
        dispatch_semaphore_t answered = dispatch_semaphore_create(0);
        void (^Ask)(xpc_connection_t, xpc_object_t) = ^(xpc_connection_t client, xpc_object_t request) {
            xpc_connection_send_message_with_reply(client, request, app, ^(xpc_object_t reply) {
                answer = reply; dispatch_semaphore_signal(answered);
            });
        };
        BOOL (^Answered)(int64_t) = ^BOOL(int64_t ms) {
            return !dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, ms * NSEC_PER_MSEC));
        };
        BOOL (^Waiting)(void) = ^BOOL { __block BOOL held; dispatch_sync(s.queue, ^{ held = s.waiting != nil; }); return held; };
        // Held, then answered with the frame through the real reply (to the very request, later).
        xpc_connection_t client = Connect();
        Ask(client, Request(0, 3000, 0));
        assert(!Answered(150) && Waiting());
        Write(core, 3, 5);
        assert(Answered(1000) && xpc_get_type(answer) == XPC_TYPE_DICTIONARY);
        assert(!strcmp(xpc_dictionary_get_string(answer, "code"), "ok") && xpc_dictionary_get_int64(answer, "protocol") == 1);
        xpc_object_t frames = xpc_dictionary_get_value(answer, "frames");
        assert(frames && xpc_array_get_count(frames) == 1 && xpc_dictionary_get_uint64(answer, "seq") == 0);
        assert(!xpc_dictionary_get_value(answer, "coreAuditToken"));
        // Expired: answered empty.
        Ask(client, Request(1, 200, 0));
        assert(!Answered(100) && Answered(1000));
        assert(xpc_array_get_count(xpc_dictionary_get_value(answer, "frames")) == 0);
        // The app is gone while held, and its loss is not seen yet: the later reply goes nowhere, harmlessly.
        keepHeld = YES;
        Ask(client, Request(1, 3000, 0));
        assert(!Answered(100) && Waiting());
        xpc_connection_cancel(client);
        assert(Answered(1000) && answer == XPC_ERROR_CONNECTION_INVALID);
        for (int i = 0; i < 100 && !lost; i++) usleep(10000);
        assert(lost && Waiting());
        Write(core, 2, 6);
        Settle(s);
        assert(!Waiting());
        // Seen lost: released without a reply; the relay stays for the app to come back.
        keepHeld = NO;
        xpc_connection_t again = Connect();
        Ask(again, Request(2, 3000, 0));
        assert(!Answered(100) && Waiting());
        xpc_connection_cancel(again);
        assert(Answered(1000) && answer == XPC_ERROR_CONNECTION_INVALID);
        for (int i = 0; i < 100 && Waiting(); i++) usleep(10000);
        assert(!Waiting() && s.socket >= 0);
        // Closing the relay answers a held receive on a live peer with `disconnected`.
        xpc_connection_t last = Connect();
        Ask(last, Request(2, 3000, 0));
        assert(!Answered(100) && Waiting());
        dispatch_sync(s.queue, ^{ [s closeRelay]; });
        assert(Answered(500) && !strcmp(xpc_dictionary_get_string(answer, "code"), "disconnected"));
        assert([s.replies count] == 0);
        puts("xpc-ok");
""", variant='xpc'))

    def test_the_hold_is_wired_and_bounded_on_both_sides(self):
        handle = method(SUPERVISOR, '- (void)handle:')
        receive = handle[handle.index('else if ([action isEqualToString:@"receive"])'):]
        receive = receive[:receive.index('else if ([action isEqualToString:@"send"])')]
        self.assertIn('[self supersedeWaiting]', receive)
        self.assertIn('[self holdReceive:request connection:connection', receive)
        hold = method(SUPERVISOR, '- (BOOL)holdReceive:')
        self.assertIn('MIN(xpc_dictionary_get_uint64(request, "wait"), FCReceiveWaitMaxMilliseconds)', hold)
        self.assertIn('clock_gettime_nsec_np(CLOCK_UPTIME_RAW)', hold)
        request = method(BRIDGE, '- (void)request:')
        self.assertIn('xpc_dictionary_set_uint64(message, "sent", clock_gettime_nsec_np(CLOCK_UPTIME_RAW))', request)
        self.assertIn('dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC)', request)
        self.assertEqual(constant(SUPERVISOR, 'FCReceiveWaitMaxMilliseconds'),
                         constant(BRIDGE, 'FCReceiveWaitMaxMilliseconds'))

    def test_the_bridge_waits_for_a_held_receive_as_long_as_it_may_be_held(self):
        source = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
''' + method(BRIDGE, 'static int64_t FCRequestTimeoutSeconds') + '\n' + constant(BRIDGE, 'FCReceiveWaitMaxMilliseconds') + \
            '\n' + method(BRIDGE, 'static uint64_t FCReceiveWait') + '\n' + \
            method(BRIDGE, 'static int64_t FCReceiveTimeoutSeconds') + '\n' + constant(SUPERVISOR, 'FCReceiveHoldLateMilliseconds') + r'''
int main(void) {
    assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": @3000}) == 11);
    assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": @2001}) == 11);
    assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": @1}) == 9);
    assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": @5000}) == 13);
    assert(FCReceiveWait(@"receive", @{@"wait": @600000}) == 5000 && FCReceiveTimeoutSeconds(@"receive", @{@"wait": @600000}) == 13);
    for (id wait in @[@0, @-5, @"3000", NSNull.null]) {
        assert(FCReceiveWait(@"receive", @{@"wait": wait}) == 0);
        assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": wait}) == 8);
    }
    assert(FCReceiveTimeoutSeconds(@"receive", @{}) == 8);
    assert(FCReceiveWait(@"send", @{@"wait": @3000}) == 0 && FCReceiveTimeoutSeconds(@"send", @{@"wait": @3000}) == 8);
    assert(FCReceiveTimeoutSeconds(@"start", @{}) == 30);
    // A held reply comes at most the wait after the bridge sent the request, plus a queue stall the bridge already
    // allows any request; a receive that reached the daemon late is not held at all.
    for (uint64_t wait = 1; wait <= 600000; wait += 997) {
        uint64_t held = MIN(wait, FCReceiveWaitMaxMilliseconds);
        assert(FCReceiveTimeoutSeconds(@"receive", @{@"wait": @(wait)}) * 1000 >= held + 8000);
    }
    assert(FCReceiveHoldLateMilliseconds < 8000);
    puts("timeout-ok");
}
'''
        self.assertIn('timeout-ok', compile_and_run(self, source))


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
