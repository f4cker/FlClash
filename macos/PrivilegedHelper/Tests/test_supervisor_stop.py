import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()


def method(declaration):
    start = SUPERVISOR.index(declaration)
    opening = SUPERVISOR.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (SUPERVISOR[end] == '{') - (SUPERVISOR[end] == '}')
        end += 1
    return SUPERVISOR[start:end]


class SupervisorStopTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-stop-pure-')
        cls.addClassCleanup(cls.scratch.cleanup)
        source = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
#import <signal.h>
#import <sys/wait.h>
#import <unistd.h>
#import "SessionPolicy.h"

static int sleeps, exitAt, waitError, waits, terms, kills, unlinks, relayCloses;
static BOOL unlinkFails, syncFails;
static NSString * const FCRuntimeDirectory = @"/fixture-only";

static pid_t FixtureWait(pid_t pid, int *status, int options) {
    assert(pid == 42 && options == WNOHANG);
    waits++;
    if (waitError) { errno = waitError; return -1; }
    return sleeps >= exitAt ? pid : 0;
}
static int FixtureKill(pid_t pid, int signal) {
    assert(pid == 42);
    assert(signal == SIGTERM || signal == SIGKILL);
    if (signal == SIGTERM) terms++;
    else kills++;
    return 0;
}
static int FixtureSleep(const struct timespec *delay, struct timespec *remaining) {
    assert(delay->tv_sec == 0 && delay->tv_nsec == 10000000);
    sleeps++;
    return 0;
}
static int FixtureUnlink(const char *path) {
    assert(strcmp(path, "/fixture-only/child-owned") == 0);
    unlinks++;
    return unlinkFails ? -1 : 0;
}
#define waitpid FixtureWait
#define kill FixtureKill
#define nanosleep FixtureSleep
#define unlink FixtureUnlink

@interface StopFixture : NSObject
@property pid_t child;
@property BOOL ownershipUncertain;
@property BOOL journalOwned;
- (BOOL)stop;
@end
@implementation StopFixture
- (BOOL)syncRuntime { return !syncFails; }
- (void)closeRelay { relayCloses++; }
'''
        source += method('- (BOOL)confirmExit') + '\n'
        source += method('- (BOOL)stop') + '\n@end\n'
        source += r'''
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        NSString *scenario = @(argv[1]);
        StopFixture *supervisor = [StopFixture new];
        supervisor.child = 42;
        supervisor.journalOwned = YES;
        exitAt = 201;
        if ([scenario isEqual:@"already-exited"]) exitAt = 0;
        else if ([scenario isEqual:@"graceful-exit"]) exitAt = 50;
        else if ([scenario isEqual:@"forced-exit"]) exitAt = 150;
        else if ([scenario isEqual:@"last-graceful-sleep"]) exitAt = 100;
        else if ([scenario isEqual:@"last-kill-sleep"]) exitAt = 200;
        else if ([scenario isEqual:@"still-running"]) {}
        else if ([scenario isEqual:@"interrupted-wait"]) waitError = EINTR;
        else if ([scenario isEqual:@"lost-child"]) waitError = ECHILD;
        else if ([scenario isEqual:@"uncertain-owner"]) supervisor.ownershipUncertain = YES;
        else if ([scenario isEqual:@"unlink-failure"]) { exitAt = 200; unlinkFails = YES; }
        else if ([scenario isEqual:@"sync-failure"]) { exitAt = 200; syncFails = YES; }
        else abort();
        BOOL stopped = [supervisor stop];
        if (exitAt <= 200 && !unlinkFails && !syncFails) {
            assert(stopped);
            assert(supervisor.child == 0 && !supervisor.ownershipUncertain);
            assert(!supervisor.journalOwned && unlinks == 1);
            assert(sleeps == exitAt);
            int priorWaits = waits, priorTerms = terms, priorKills = kills;
            assert([supervisor stop]);
            assert(waits == priorWaits && terms == priorTerms && kills == priorKills);
            assert(unlinks == 1);
        } else {
            assert(!stopped && supervisor.journalOwned);
            if (unlinkFails || syncFails) {
                assert(supervisor.child == 0 && supervisor.ownershipUncertain);
                assert(unlinks == 1);
                assert(![supervisor stop]);
            } else {
                assert(supervisor.child == 42 && unlinks == 0);
                if (waitError == ECHILD || [scenario isEqual:@"uncertain-owner"]) {
                    assert(supervisor.ownershipUncertain);
                    assert(terms == 0 && kills == 0 && sleeps == 0);
                } else {
                    assert(!supervisor.ownershipUncertain);
                    assert(terms == 1 && kills == 1 && sleeps == 200);
                    waitError = 0;
                    exitAt = sleeps;
                    assert([supervisor stop]);
                    assert(supervisor.child == 0 && !supervisor.journalOwned);
                    assert(terms == 1 && kills == 1);
                }
            }
        }
    }
}
'''
        fixture = Path(cls.scratch.name) / 'stop.m'
        fixture.write_text(source)
        cls.executable = str(Path(cls.scratch.name) / 'stop')
        subprocess.run([
            'clang', '-fobjc-arc', '-Werror', str(fixture),
            '-I', str(MACOS / 'PrivilegedHelper'),
            '-framework', 'Foundation', '-o', cls.executable,
        ], check=True, capture_output=True, text=True, timeout=30)

    def test_reap_boundaries_and_fail_closed_ownership(self):
        for scenario in (
            'already-exited', 'graceful-exit', 'forced-exit',
            'last-graceful-sleep', 'last-kill-sleep', 'still-running',
            'interrupted-wait', 'lost-child', 'uncertain-owner',
            'unlink-failure', 'sync-failure',
        ):
            with self.subTest(scenario=scenario):
                result = subprocess.run(
                    [self.executable, scenario], capture_output=True,
                    text=True, timeout=5,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
