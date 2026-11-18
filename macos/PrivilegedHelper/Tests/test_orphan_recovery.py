"""Leftover Flash Cores are found by code signature (never by path), stopped through their audit token and
confirmed gone. Pure fixtures: no process is listed, inspected or signalled for real."""
import subprocess
import tempfile
import unittest
from pathlib import Path

HELPER = Path(__file__).resolve().parents[1]
STAGING = (HELPER / 'CoreStaging.h').read_text()
SUPERVISOR = (HELPER / 'Supervisor.m').read_text()

FIXTURE = r'''
#import <Foundation/Foundation.h>
#import <bsm/libbsm.h>
#import <libproc.h>
#import <assert.h>
#import <errno.h>
#import <signal.h>
#import <stdlib.h>
#import <string.h>
typedef enum { Alive, Gone, Reused } Life;
static int listFails, termIgnored, unkillable, reuseAfterTerm;
static pid_t listed[8]; static int listedCount;
static Life life[100];
static int matches[100];            // FCCoreMatch per pid
static NSMutableArray<NSString *> *signals;
static int FixtureList(void *buffer, int bytes) {
    if (listFails) return -1;
    if (!buffer) return listedCount;
    memcpy(buffer, listed, listedCount * sizeof(pid_t)); return listedCount;
}
static void *FixtureCalloc(size_t count, size_t size) { return calloc(count, size); }
static int FixtureToken(pid_t pid, audit_token_t *token) {
    if (life[pid] == Gone) { errno = ESRCH; return -1; }
    memset(token, 0, sizeof(*token));
    token->val[5] = (unsigned)pid; token->val[7] = life[pid] == Reused ? 2 : 1;
    return 0;
}
static int FixtureSignal(audit_token_t *token, int sig) {
    pid_t pid = (pid_t)token->val[5];
    [signals addObject:[NSString stringWithFormat:@"%d:%d", pid, sig]];
    if (life[pid] == Gone || token->val[7] != 1 || life[pid] == Reused) { errno = ESRCH; return -1; }
    if (unkillable) return 0;
    if (sig == SIGTERM && reuseAfterTerm) { life[pid] = Reused; return 0; }
    if (sig == SIGTERM && termIgnored) return 0;
    life[pid] = Gone; return 0;
}
#define proc_listallpids FixtureList
#define calloc FixtureCalloc
#define FCProcessToken FixtureToken
#define FCSweepPause() ((void)0)
#define proc_signal_with_audittoken FixtureSignal
#define FCRunningFlashCore FixtureMatch
#import "CoreStaging.h"
FCCoreMatch FixtureMatch(pid_t pid, NSString **reason) {
    if (life[pid] == Gone) return FCCoreMatchGone;
    if (life[pid] == Reused) return FCCoreMatchOther;
    if (matches[pid] == FCCoreMatchUnknown && reason) *reason = @"signature check OSStatus -67050";
    return (FCCoreMatch)matches[pid];
}
static NSDictionary *Run(pid_t keep, NSArray<NSNumber *> *pids) {
    listedCount = 0;
    for (NSNumber *p in pids) listed[listedCount++] = p.intValue;
    [signals removeAllObjects];
    return FCRetireFlashCores(keep);
}
static void Reset(void) {
    listFails = termIgnored = unkillable = reuseAfterTerm = 0;
    for (int i = 0; i < 100; i++) { life[i] = Alive; matches[i] = FCCoreMatchOther; }
}
int main(void) { @autoreleasepool {
    signals = [NSMutableArray array];
    // Nothing of Flash runs: nothing is signalled.
    Reset();
    NSDictionary *r = Run(0, @[@1, @43]);
    assert([r[@"outcome"] isEqual:@"none"] && signals.count == 0);
    // An old Core (any path: an old bundle, a deleted staged copy) stops on SIGTERM and is confirmed gone.
    Reset(); matches[42] = FCCoreMatchFlash;
    r = Run(0, @[@1, @42, @43]);
    assert([r[@"outcome"] isEqual:@"stopped"] && [r[@"stopped"] isEqual:@1]);
    assert(([signals isEqual:@[@"42:15"]]));
    // One that ignores SIGTERM gets SIGKILL, then is confirmed gone.
    Reset(); matches[42] = FCCoreMatchFlash; termIgnored = 1;
    r = Run(0, @[@42]);
    assert([r[@"outcome"] isEqual:@"stopped"] && ([signals isEqual:@[@"42:15", @"42:9"]]));
    // One that survives SIGKILL is reported, never assumed gone.
    Reset(); matches[42] = FCCoreMatchFlash; unkillable = 1;
    r = Run(0, @[@42]);
    assert([r[@"outcome"] isEqual:@"unconfirmed"] && [r[@"reason"] containsString:@"still running after SIGKILL"]);
    // The pid is reused by another process after SIGTERM: that one is never signalled.
    Reset(); matches[42] = FCCoreMatchFlash; reuseAfterTerm = 1;
    r = Run(0, @[@42]);
    assert([r[@"outcome"] isEqual:@"stopped"] && ([signals isEqual:@[@"42:15"]]));
    // The daemon's own Core is kept.
    Reset(); matches[42] = FCCoreMatchFlash;
    r = Run(42, @[@42]);
    assert([r[@"outcome"] isEqual:@"none"] && signals.count == 0);
    // An identity that cannot be read is not called absent.
    Reset(); matches[44] = FCCoreMatchUnknown;
    r = Run(0, @[@44]);
    assert([r[@"outcome"] isEqual:@"unconfirmed"] && [r[@"reason"] containsString:@"pid 44"] && signals.count == 0);
    // Neither is a process list that could not be read.
    Reset(); listFails = 1;
    r = Run(0, @[@42]);
    assert([r[@"outcome"] isEqual:@"unconfirmed"] && signals.count == 0);
    puts("signature-sweep");
} }
'''


class OrphanRecoveryTests(unittest.TestCase):
    def test_signature_sweep(self):
        with tempfile.TemporaryDirectory(prefix='flash-orphans-') as tmp:
            src = Path(tmp) / 'fixture.m'
            binary = Path(tmp) / 'fixture'
            src.write_text(FIXTURE)
            compiled = subprocess.run(['clang', '-fobjc-arc', '-Werror', '-Wno-unused-function',
                                       '-I', str(HELPER), '-framework', 'Foundation',
                                       str(src), '-o', str(binary)], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn('signature-sweep', result.stdout)

    def test_no_path_based_identification(self):
        sweep = STAGING[STAGING.index('static inline NSArray<NSNumber *> *FCFlashCoreProcesses'):]
        self.assertNotIn('proc_pidpath', sweep)
        self.assertNotIn('kill(', sweep)
        self.assertIn('proc_signal_with_audittoken', sweep)
        # The daemon sweeps at launch and from the app's explicit request, keeping its own Core.
        self.assertIn('_lastSweep = FCRetireFlashCores(0);', SUPERVISOR)
        self.assertIn('FCRetireFlashCores(self.child > 0 ? self.child : 0)', SUPERVISOR)
        trust = (HELPER.parent / 'Shared/HelperTrust.m').read_text()
        match = trust[trust.index('FCCoreMatch FCRunningFlashCore'):]
        match = match[:match.index('\n}\n')]
        # The kernel's identifier only selects candidates; the pinned requirement decides.
        self.assertIn('FCSigningRequirement(FCCoreIdentifier)', match)
        self.assertIn('SecCodeCheckValidity(code, kSecCSDefaultFlags, requirement)', match)


if __name__ == '__main__':
    unittest.main()
