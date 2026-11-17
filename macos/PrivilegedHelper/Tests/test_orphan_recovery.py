import subprocess
import tempfile
import unittest
from pathlib import Path

from test_supervisor_stop import method

HELPER = Path(__file__).resolve().parents[1]


class OrphanRecoveryTests(unittest.TestCase):
    def test_injected_snapshot_and_recovery(self):
        source = r'''
#import <Foundation/Foundation.h>
#import <libproc.h>
#import <assert.h>
#import <stdlib.h>
#import <string.h>
static int scenario, calls, signals, journalUnlinks, coreRemovals;
static int FixtureList(void *buffer, int bytes) {
    calls++;
    if (!buffer) return scenario == 1 ? -1 : (scenario == 8 ? 65536 : 2);
    if (scenario == 2) return -1;
    if (scenario == 9) return 0;
    if (scenario == 3) return bytes / sizeof(pid_t);
    pid_t *p = buffer; p[0] = 1; p[1] = 42; return 2;
}
static int FixturePath(int pid, void *buffer, uint32_t size) {
    assert(pid == 42);
    if (scenario == 5) return 0;
    if (scenario == 10) return (int)size;
    const char *path = scenario == 6 ? "/fixture/core-abc" : "/unrelated/process";
    assert(strlen(path) + 1 < size); strcpy(buffer, path); return (int)strlen(path);
}
static void *FixtureCalloc(size_t count, size_t size) {
    return scenario == 4 ? NULL : calloc(count, size);
}
static int FixtureKill(pid_t pid, int sig) { signals++; return 0; }
#define proc_listallpids FixtureList
#define proc_pidpath FixturePath
#define calloc FixtureCalloc
#define kill FixtureKill
#import "CoreStaging.h"
#undef kill
static NSString * const FCRuntimeDirectory = @"/fixture";
static int FixtureUnlink(const char *path) { journalUnlinks++; return 0; }
static void FixtureRemove(NSString *directory) { coreRemovals++; }
#define FCRemoveStagedCores FixtureRemove
#define unlink FixtureUnlink
@interface RecoveryFixture : NSObject
@property BOOL ownershipUncertain, journalOwned;
@property pid_t child;
@property NSString *corePath;
@end
@implementation RecoveryFixture
- (BOOL)syncRuntime { return YES; }
- (void)closeRelay {}
'''
        source += method('- (BOOL)recoverOwnership')
        source += r'''
@end
int main(void) {
    @autoreleasepool {
        for (scenario = 1; scenario <= 10; scenario++) {
            if (scenario == 7) continue;
            calls = journalUnlinks = signals = 0;
            RecoveryFixture *fixture = [RecoveryFixture new];
            fixture.ownershipUncertain = YES; fixture.journalOwned = YES; fixture.child = -1;
            BOOL ok = [fixture recoverOwnership];
            if (scenario == 6 || scenario <= 5 || scenario >= 8) {
                assert(!ok && fixture.ownershipUncertain && fixture.journalOwned);
                assert(fixture.child == -1 && journalUnlinks == 0);
            }
            assert(signals == 0);
        }
        scenario = 6;
        RecoveryFixture *fixture = [RecoveryFixture new];
        fixture.ownershipUncertain = YES; fixture.journalOwned = YES; fixture.child = -1;
        assert(![fixture recoverOwnership] && fixture.ownershipUncertain);
        scenario = 0;
        assert([fixture recoverOwnership]);
        assert(!fixture.ownershipUncertain && !fixture.journalOwned && fixture.child == 0);
        assert(journalUnlinks == 1 && signals == 0 && coreRemovals == 1);
    }
}
'''
        with tempfile.TemporaryDirectory(prefix='flash-orphans-') as tmp:
            src = Path(tmp) / 'fixture.m'
            binary = Path(tmp) / 'fixture'
            src.write_text(source)
            subprocess.run(['clang', '-fobjc-arc', '-Werror', '-Wno-unused-function',
                            '-I', str(HELPER), '-framework', 'Foundation',
                            str(src), '-o', str(binary)], check=True, capture_output=True, text=True)
            subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=5)


if __name__ == '__main__':
    unittest.main()
