#import "../../Shared/HelperTrust.h"
#include <assert.h>
#include <errno.h>
#include <string.h>

// Compiled with -DFCCodeOps=FixtureCodeOps: the kernel's answers for a Core, without one running.
static uint32_t status;
static uint8_t cdhash[20];
static int failOp = -1;
static int calls;

int FixtureCodeOps(pid_t pid, unsigned int ops, void *address, size_t size, audit_token_t *token) {
    calls++;
    assert(pid == 77 && (pid_t)token->val[5] == 77);
    if ((int)ops == failOp) { errno = ESRCH; return -1; }
    if (ops == 0) { assert(size == sizeof(status)); memcpy(address, &status, size); return 0; }
    assert(ops == 5 && size == sizeof(cdhash));
    memcpy(address, cdhash, size);
    return 0;
}

int main(void) {
    @autoreleasepool {
        audit_token_t token = {{0}};
        token.val[5] = 77;
        NSData *core = [NSData dataWithBytes:&token length:sizeof(token)];
        memset(cdhash, 0xab, sizeof(cdhash));
        NSData *expected = [NSData dataWithBytes:cdhash length:sizeof(cdhash)];
        const uint32_t hardened = 0x1 | 0x100 | 0x200 | 0x10000;

        status = hardened;
        assert([FCCoreGuestCheck(core, 77, expected) isEqualToString:@"verified"]);
        status = hardened | 0x2000;
        assert([FCCoreGuestCheck(core, 77, expected) isEqualToString:@"verified"]);

        for (NSNumber *missing in @[@0x1, @0x100, @0x200, @0x10000]) {
            status = hardened & ~missing.unsignedIntValue;
            assert([FCCoreGuestCheck(core, 77, expected) hasPrefix:@"failed:status 0x"]);
        }
        status = hardened | 0x10000000;
        assert([FCCoreGuestCheck(core, 77, expected) hasPrefix:@"failed:status 0x"]);

        status = hardened;
        NSMutableData *other = expected.mutableCopy;
        ((uint8_t *)other.mutableBytes)[19] ^= 1;
        assert([FCCoreGuestCheck(core, 77, other) isEqualToString:@"failed:cdhash"]);
        assert([FCCoreGuestCheck(core, 77, [expected subdataWithRange:NSMakeRange(0, 19)])
            isEqualToString:@"failed:bundled"]);

        failOp = 0;
        assert([FCCoreGuestCheck(core, 77, expected) isEqualToString:@"failed:status-read errno=3"]);
        failOp = 5;
        assert([FCCoreGuestCheck(core, 77, expected) isEqualToString:@"failed:cdhash-read errno=3"]);
        failOp = -1;

        calls = 0;
        assert([FCCoreGuestCheck(core, 78, expected) isEqualToString:@"failed:pid"]);
        assert([FCCoreGuestCheck(nil, 77, expected) isEqualToString:@"failed:token"]);
        assert(calls == 0);
        puts("Core guest check passed");
    }
    return 0;
}
