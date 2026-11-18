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
