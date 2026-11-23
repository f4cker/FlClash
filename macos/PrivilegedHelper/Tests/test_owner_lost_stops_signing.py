"""When the app's connection drops, the daemon tells its Core to stop MITM signing before any grace period (pure
fixture: the real `ownerLost:`, `stopCoreSigning`, `writeFrame:` and `send:seq:` over a socketpair; no daemon, Core
or XPC peer)."""
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
ROOT = MACOS.parent
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()


def method(declaration):
    start = SUPERVISOR.index(declaration)
    opening = SUPERVISOR.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (SUPERVISOR[end] == '{') - (SUPERVISOR[end] == '}')
        end += 1
    return SUPERVISOR[start:end]


FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <assert.h>
#import <os/log.h>
#import <poll.h>
#import <signal.h>
#import <sys/socket.h>
#import "SessionPolicy.h"
static os_log_t FCHelperLog(void) { return OS_LOG_DEFAULT; }
static const size_t FCMaxFrame = 1024;
static const int64_t FCOwnerGraceSeconds = 10;
static BOOL ownerAlive = YES;
static int FixtureKill(pid_t pid, int signal) {
    assert(pid == 500 && signal == 0);
    if (ownerAlive) return 0;
    errno = ESRCH;
    return -1;
}
#define kill FixtureKill

@interface OwnerFixture : NSObject
@property dispatch_queue_t queue;
@property xpc_connection_t owner;
@property xpc_connection_t waitingConnection;
@property pid_t child;
@property pid_t ownerPid;
@property int socket;
@property uint64_t written;
@property int stops;
@property int releases;
@end
@implementation OwnerFixture
- (BOOL)stop { self.stops++; self.child = 0; return YES; }
- (void)releaseWait { self.releases++; }
''' + method('- (NSString *)send:') + '\n' + method('- (BOOL)writeFrame:') + '\n' + \
    method('- (BOOL)stopCoreSigning') + '\n' + method('- (void)ownerLost:') + r'''
@end

static OwnerFixture *Fixture(int *core, xpc_connection_t owner) {
    int pair[2];
    assert(!socketpair(AF_UNIX, SOCK_STREAM, 0, pair));
    assert(!fcntl(pair[0], F_SETFL, O_NONBLOCK));
    int yes = 1;
    setsockopt(pair[0], SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    OwnerFixture *s = [OwnerFixture new];
    s.queue = dispatch_queue_create("fixture", DISPATCH_QUEUE_SERIAL);
    s.owner = owner; s.child = 42; s.ownerPid = 500; s.socket = pair[0];
    *core = pair[1];
    return s;
}

// Reads one frame the Core would see; NO when none is waiting.
static BOOL ReadFrame(int core, NSString **body) {
    struct pollfd ready = { .fd = core, .events = POLLIN };
    if (poll(&ready, 1, 0) <= 0) return NO;
    uint32_t size;
    assert(read(core, &size, 4) == 4);
    size = CFSwapInt32LittleToHost(size);
    char buffer[1024];
    assert(size < sizeof(buffer) && read(core, buffer, size) == (ssize_t)size);
    *body = [[NSString alloc] initWithBytes:buffer length:size encoding:NSUTF8StringEncoding];
    return YES;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        NSString *scenario = @(argv[1]);
        xpc_connection_t owner = (xpc_connection_t)(id)[NSObject new];
        xpc_connection_t other = (xpc_connection_t)(id)[NSObject new];
        int core;
        OwnerFixture *s = Fixture(&core, owner);
        NSString *body = nil;
        if ([scenario isEqual:@"grace"]) {
            NSData *app = [@"{\"id\":\"1\"}" dataUsingEncoding:NSUTF8StringEncoding];
            assert([[s send:app seq:0] isEqual:@"ok"] && s.written == 1);
            assert(ReadFrame(core, &body) && [body isEqual:@"{\"id\":\"1\"}"]);
            s.waitingConnection = owner;
            [s ownerLost:owner];
            assert(ReadFrame(core, &body));
            assert([body isEqual:@"{\"method\":\"mitm.stopSigning\"}"]);
            assert(!ReadFrame(core, &body));
            // The Core is kept for the app to resume; its frame count is the app's alone.
            assert(s.stops == 0 && s.child == 42 && s.written == 1 && s.releases == 1);
            assert([[s send:app seq:1] isEqual:@"ok"] && s.written == 2);
        } else if ([scenario isEqual:@"not-the-owner"]) {
            [s ownerLost:other];
            assert(!ReadFrame(core, &body) && s.stops == 0);
        } else if ([scenario isEqual:@"owner-gone"]) {
            ownerAlive = NO;
            [s ownerLost:owner];
            assert(s.stops == 1);
        } else if ([scenario isEqual:@"relay-closed"]) {
            close(s.socket); s.socket = -1;
            [s ownerLost:owner];
            assert(s.stops == 1);
        } else if ([scenario isEqual:@"core-unreachable"]) {
            close(core);
            [s ownerLost:owner];
            assert(s.stops == 1);
        } else abort();
        puts("ok");
    }
}
'''


class OwnerLostStopsSigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-owner-lost-')
        cls.addClassCleanup(cls.scratch.cleanup)
        root = Path(cls.scratch.name)
        (root / 'fixture.m').write_text(FIXTURE)
        cls.executable = str(root / 'fixture')
        result = subprocess.run([
            'clang', '-fobjc-arc', '-fblocks', '-Werror', '-mmacosx-version-min=14.0',
            '-I', str(MACOS / 'Shared'), '-I', str(MACOS / 'PrivilegedHelper'),
            str(root / 'fixture.m'), '-framework', 'Foundation', '-o', cls.executable,
        ], capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stderr)

    def test_scenarios(self):
        for scenario in ('grace', 'not-the-owner', 'owner-gone', 'relay-closed', 'core-unreachable'):
            with self.subTest(scenario=scenario):
                result = subprocess.run([self.executable, scenario], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_the_frame_names_a_method_the_core_dispatches(self):
        protocol = (ROOT / 'core/protocol.go').read_text()
        policy = (MACOS / 'PrivilegedHelper/SessionPolicy.h').read_text()
        name = re.search(r'mitmStopSigningMethod\s+CoreMethod = "([^"]+)"', protocol).group(1)
        self.assertIn(f'{{\\"method\\":\\"{name}\\"}}', policy)
        runtime = (ROOT / 'core/mitm_ca_runtime.go').read_text()
        self.assertRegex(runtime, r'mitmStopSigningMethod:\s+handleMitmStopSigningCall')

    def test_the_stop_comes_before_the_grace_period(self):
        lost = method('- (void)ownerLost:')
        self.assertLess(lost.index('stopCoreSigning'), lost.index('dispatch_after'))


if __name__ == '__main__':
    unittest.main()
