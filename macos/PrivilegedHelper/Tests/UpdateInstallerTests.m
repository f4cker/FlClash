// Drives UpdateInstaller.m on fixture bundles: `prepare`/`install` with the test policy (ad hoc signatures checked
// for real by Security, identifiers instead of the pinned certificate) or the production policy (`pinned`).
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <errno.h>
#import <signal.h>
#import <stdio.h>
#import "../../Runner/UpdateInstaller.h"
#import "../../Shared/HelperTrust.h"

static NSString *FCTestRequirement(NSString *path, NSString *identifier) {
    SecStaticCodeRef code = NULL;
    SecRequirementRef requirement = NULL;
    NSString *text = [NSString stringWithFormat:@"identifier \"%@\"", identifier];
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &code)) return @"unsigned";
    SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement);
    OSStatus status = SecStaticCodeCheckValidity(code,
        kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, requirement);
    CFRelease(requirement);
    CFRelease(code);
    return status == errSecSuccess ? @"trusted" : [NSString stringWithFormat:@"signature %d", (int)status];
}

static NSString *FCTestAppTrust(NSString *bundle) {
    return FCTestRequirement(bundle, @"com.layoute.flash");
}

static NSString *FCTestInstalledTrust(NSString *bundle) {
    if (getenv("FC_TEST_FAIL_INSTALLED")) return @"signingRequired";
    return FCTestAppTrust(bundle);
}

static BOOL FCTestHelperTrust(NSString *helper) {
    return [FCTestRequirement(helper, @"com.layoute.flash.helper") isEqualToString:@"trusted"];
}

// FC_TEST_FAIL_SWAP_BACK: every swap after the first fails, as when the swap back cannot happen.
// FC_TEST_KILL=beforeSwap|afterSwap|beforeSwapBack: the process dies there, as on a crash or a forced quit.
// FC_TEST_KILL=beforeRelease: it dies as the rollback marker is about to become the staging marker again; this
// definition takes the place of libc's rename(2) for UpdateInstaller.m, which is linked into this driver.
static int FCTestSwap(const char *from, const char *to) {
    static int swaps = 0;
    const char *kill_at = getenv("FC_TEST_KILL") ?: "";
    BOOL first = swaps++ == 0;
    if ((first && !strcmp(kill_at, "beforeSwap")) || (!first && !strcmp(kill_at, "beforeSwapBack"))) kill(getpid(), SIGKILL);
    if (getenv("FC_TEST_FAIL_SWAP_BACK") && !first) {
        errno = EBUSY;
        return -1;
    }
    int result = renamex_np(from, to, RENAME_SWAP);
    if (first && !strcmp(kill_at, "afterSwap")) kill(getpid(), SIGKILL);
    return result;
}

int rename(const char *from, const char *to) {
    const char *kill_at = getenv("FC_TEST_KILL") ?: "";
    size_t length = strlen(to), suffix = strlen("/.flash-update-staging");
    if (!strcmp(kill_at, "beforeRelease") && length > suffix && !strcmp(to + length - suffix, "/.flash-update-staging"))
        kill(getpid(), SIGKILL);
    return renamex_np(from, to, 0);
}

static CFStringRef FCTestRescueDirectory(void) {
    const char *directory = getenv("FC_TEST_RESCUE_DIR");
    return directory ? (CFStringRef)CFBridgingRetain(@(directory)) : CFSTR("/nonexistent/update-rescue");
}

static void FCPrint(id object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:nil];
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *arguments = [NSMutableArray array];
        for (int i = 1; i < argc; i++) [arguments addObject:@(argv[i])];
        NSString *command = arguments.firstObject;
        BOOL pinned = [arguments.lastObject isEqualToString:@"pinned"];
        if (pinned) [arguments removeLastObject];
        FCUpdatePolicy policy = pinned ? FCUpdateDefaultPolicy() : (FCUpdatePolicy){
            FCTestAppTrust, FCTestInstalledTrust, FCTestHelperTrust, CFSTR(""), getuid(), FCTestSwap,
            FCTestRescueDirectory()};
        if ([command isEqualToString:@"prepare"] && arguments.count == 9) {
            policy.launcherStatusDirectory = (__bridge CFStringRef)arguments[3];
            NSNumberFormatter *number = [NSNumberFormatter new];
            NSDictionary *expected = @{@"sha256": arguments[4], @"size": [number numberFromString:arguments[5]],
                @"version": arguments[6], @"build": [number numberFromString:arguments[7]],
                @"helperBuild": [number numberFromString:arguments[8]]};
            FCPrint(FCUpdatePrepare(arguments[1], expected, arguments[2], policy));
        } else if ([command isEqualToString:@"install"] && arguments.count == 4) {
            policy.launcherStatusDirectory = (__bridge CFStringRef)arguments[3];
            FCPrint(FCUpdateInstall(arguments[1], arguments[2], policy));
        } else if ([command isEqualToString:@"trust"] && arguments.count == 2) {
            FCPrint(@{@"candidate": FCGUICandidateTrust(arguments[1]), @"installed": FCGUIBundleTrust(arguments[1]),
                @"test": FCTestAppTrust(arguments[1])});
        } else if ([command isEqualToString:@"cleanup"] && arguments.count == 2) {
            FCUpdateCleanupKeeping(arguments[1], (__bridge NSString *)FCTestRescueDirectory());
            FCPrint(@{@"code": @"ok"});
        } else if ([command isEqualToString:@"manual"] && arguments.count == 4) {
            FCPrint(@{@"app": FCUpdateUnpackForManualInstall(arguments[1], arguments[2], arguments[3]) ?: @""});
        } else {
            fprintf(stderr, "usage\n");
            return 64;
        }
    }
    return 0;
}
