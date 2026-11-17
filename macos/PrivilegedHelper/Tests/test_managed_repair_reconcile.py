import subprocess
import tempfile
import unittest
from pathlib import Path

BRIDGE = (Path(__file__).resolve().parents[2] / 'Runner/ManagedHelperBridge.m').read_text()


def method(prefix):
    start = BRIDGE.index(prefix)
    opening = BRIDGE.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (BRIDGE[end] == '{') - (BRIDGE[end] == '}')
        end += 1
    return BRIDGE[start:end]


class RegisterOnlyTests(unittest.TestCase):
    def test_timeout_keeps_lock_until_late_completion(self):
        source = r'''
#import <Foundation/Foundation.h>
#import <assert.h>
typedef NSInteger SMAppServiceStatus;
enum { SMAppServiceStatusNotRegistered, SMAppServiceStatusEnabled, SMAppServiceStatusRequiresApproval };
typedef int FCLegacyResidue;
static FCLegacyResidue FCDetectLegacyResidue(void) { return 0; }
''' + method('static void FCPerformRepairCall') + r'''
@interface FakeDaemon : NSObject
@property SMAppServiceStatus status;
@end
@implementation FakeDaemon
@end
@interface Fixture : NSObject
@property BOOL operationInFlight, sessionActive;
@property NSUInteger pending, calls, completions;
@property dispatch_queue_t queue;
@property dispatch_semaphore_t began;
@property NSString *result;
@property FakeDaemon *daemon;
@property (copy) void (^registered)(NSDictionary *);
@end
@implementation Fixture
- (instancetype)init { if ((self = [super init])) { self.daemon = [FakeDaemon new]; } return self; }
- (NSString *)gate { return @"trusted"; }
- (NSDictionary *)residueAnswer:(FCLegacyResidue)r code:(NSString *)c { return @{ @"code": c }; }
- (NSTimeInterval)repairUnregisterTimeout { return 0.05; }
- (void)registerAfterRepairIfPermitted:(BOOL (^)(void))allowed completion:(void (^)(NSDictionary *))done {
    if (!allowed()) { done(@{ @"code": @"timeout" }); return; }
    self.calls++; self.registered = done; dispatch_semaphore_signal(self.began);
}
''' + method('- (void)repairRegisterOnlyWithArguments:') + r'''
@end
static void until(Fixture *f, BOOL (^condition)(void)) {
    for (int i = 0; i < 1000; i++) {
        __block BOOL done; dispatch_sync(f.queue, ^{ done = condition(); });
        if (done) return; [NSThread sleepForTimeInterval:0.001];
    }
    assert(0);
}
int main(void) { @autoreleasepool {
    Fixture *f = [Fixture new];
    f.queue = dispatch_queue_create("fixture", DISPATCH_QUEUE_SERIAL);
    f.began = dispatch_semaphore_create(0);
    dispatch_sync(f.queue, ^{ [f repairRegisterOnlyWithArguments:@{} completion:^(NSDictionary *a) { f.result = a[@"code"]; }]; });
    assert([f.result isEqual:@"invalidRequest"] && f.calls == 0);
    dispatch_sync(f.queue, ^{ [f repairRegisterOnlyWithArguments:@{ @"repairRecordWritten": @YES }
        completion:^(NSDictionary *a) { f.completions++; f.result = a[@"code"]; }]; });
    assert(!dispatch_semaphore_wait(f.began, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)));
    until(f, ^BOOL{ return f.completions == 1; });
    assert([f.result isEqual:@"registrationOutcomeUnknown"] && f.operationInFlight && f.calls == 1);
    dispatch_sync(f.queue, ^{ [f repairRegisterOnlyWithArguments:@{ @"repairRecordWritten": @YES }
        completion:^(NSDictionary *a) { assert([a[@"code"] isEqual:@"operationInProgress"]); }]; });
    f.registered(@{ @"code": @"repairRegistered" });
    until(f, ^BOOL{ return !f.operationInFlight; });
    assert(f.calls == 1 && f.completions == 1);
} }
'''
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'fixture.m').write_text(source)
            compiled = subprocess.run(
                ['clang', '-fobjc-arc', '-fblocks', '-Werror', str(root / 'fixture.m'),
                 '-framework', 'Foundation', '-o', str(root / 'fixture')],
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(root / 'fixture')], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
