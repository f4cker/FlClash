#import "../../Shared/HelperTrust.h"
#import "../../Shared/HelperIdentity.h"
#include <assert.h>
#include <unistd.h>
#include <mach/mach.h>

#ifndef FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED
#define FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED 0
#endif

static void testEntitlements(void) {
    for (NSDictionary *entitlements in @[@{}, @{@"com.apple.security.network.client": @YES}]) {
        assert(FCCodeEntitlementsAllowed(entitlements, kSecCodeSignatureRuntime));
        assert(!FCCodeEntitlementsAllowed(entitlements, 0));
        assert(!FCCodeEntitlementsAllowed(entitlements, kSecCodeSignatureRuntime | kSecCodeSignatureAdhoc));
    }
    assert(FCCodeEntitlementsAllowed(nil, kSecCodeSignatureRuntime));
    for (NSString *forbidden in @[@"com.apple.security.get-task-allow",
            @"com.apple.security.cs.disable-library-validation",
            @"com.apple.security.cs.allow-dyld-environment-variables",
            @"com.apple.security.cs.allow-unsigned-executable-memory",
            @"com.apple.security.cs.disable-executable-page-protection"]) {
        // Presence alone is refused (also with a NO/non-boolean value), so no truthiness games.
        for (id value in @[@YES, @NO, @"true"])
            assert(!FCCodeEntitlementsAllowed(@{forbidden: value}, kSecCodeSignatureRuntime));
    }
    NSString *fixture = NSProcessInfo.processInfo.arguments.firstObject.stringByStandardizingPath;
    assert(!FCProtectedTree(fixture, NO));
    for (NSString *role in @[FCClientIdentifier, FCHelperIdentifier, FCCoreIdentifier]) assert(!FCCheckStatic(fixture, role));
    assert(FCStaticCodeHash(fixture, FCHelperIdentifier) == nil);
    assert(!FCProtectedTree(@"relative/Flash.app", YES));
    assert([FCGUIBundleTrust(@"/unqualified/Flash.app") isEqualToString:@"moveRequired"]);
    assert([FCGUIBundleTrust(@"/Applications/Flash Copy.app") isEqualToString:@"moveRequired"]);
    // Self-check refuses anything not running from the exact bundled path before touching Security.
    for (NSString *path in @[fixture, @"/Library/Application Support/Flash/Flash.app/Contents/Library/HelperTools/FlashHelper",
            @"/Applications/Flash.app/Contents/Library/HelperTools/../HelperTools/FlashHelper", @""])
        assert([FCHelperSelfCheck(path) isEqualToString:@"path"]);
}

static void testDaemonPlist(void) {
    NSDictionary *canonical = FCCanonicalDaemonPlist();
    assert(canonical.count == 5);
    assert(FCDaemonPlistValid(canonical));
    assert([canonical[@"Label"] isEqualToString:@"com.layoute.flash.helperd"]);
    assert([canonical[@"MachServices"] isEqual:@{@"com.layoute.flash.helperd": @YES}]);
    assert([FCDaemonPlistName isEqualToString:@"com.layoute.flash.helperd.plist"]);
    assert([FCDaemonPlistRelativePath isEqualToString:@"Contents/Library/LaunchDaemons/com.layoute.flash.helperd.plist"]);
    assert(![canonical[@"Label"] isEqualToString:@"com.layoute.flash.helper"]);
    assert([canonical[@"BundleProgram"] isEqualToString:@"Contents/Library/HelperTools/FlashHelper"]);
    assert(!canonical[@"Program"] && !canonical[@"ProgramArguments"] && !canonical[@"KeepAlive"] && !canonical[@"RunAtLoad"]);
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:
        [@FC_SOURCE_ROOT stringByAppendingPathComponent:@"PrivilegedHelper/com.layoute.flash.helperd.plist"]];
    assert([disk isEqualToDictionary:canonical]);
    // The retired name: same schema under its own label, only valid as the retired plist.
    NSDictionary *retired = [NSDictionary dictionaryWithContentsOfFile:
        [@FC_SOURCE_ROOT stringByAppendingPathComponent:@"PrivilegedHelper/com.layoute.flash.daemon.plist"]];
    assert([FCRetiredHelperLabel isEqualToString:@"com.layoute.flash.daemon"]);
    assert([FCRetiredDaemonPlistName isEqualToString:@"com.layoute.flash.daemon.plist"]);
    assert([retired isEqualToDictionary:FCCanonicalDaemonPlistForLabel(FCRetiredHelperLabel)]);
    assert(FCRetiredDaemonPlistValid(retired) && !FCDaemonPlistValid(retired) && !FCRetiredDaemonPlistValid(canonical));
    assert([retired[@"BundleProgram"] isEqualToString:canonical[@"BundleProgram"]]);
    for (NSString *key in canonical) {
        NSMutableDictionary *invalid = canonical.mutableCopy;
        [invalid removeObjectForKey:key];
        assert(!FCDaemonPlistValid(invalid));
        invalid[key] = @42;
        assert(!FCDaemonPlistValid(invalid));
    }
    for (NSDictionary *mutation in @[@{@"Label": @"com.layoute.flash.helper"},
            @{@"BundleProgram": @"/Applications/Flash.app/Contents/Library/HelperTools/FlashHelper"},
            @{@"BundleProgram": @"Contents/MacOS/FlClashCore"},
            @{@"Program": @"/tmp/FlashHelper"}, @{@"ProgramArguments": @[@"/bin/sh"]},
            @{@"EnvironmentVariables": @{@"DYLD_INSERT_LIBRARIES": @"/tmp/x.dylib"}},
            @{@"KeepAlive": @YES}, @{@"RunAtLoad": @YES}, @{@"UserName": @"root"},
            @{@"ProcessType": @"Background"}, @{@"MachServices": @{FCHelperLabel: @1}},
            @{@"MachServices": @{FCHelperLabel: @NO}}, @{@"MachServices": @{@"com.layoute.flash.helper": @YES}},
            @{@"MachServices": @{FCHelperLabel: @YES, @"extra": @YES}},
            @{@"AssociatedBundleIdentifiers": @[]}, @{@"AssociatedBundleIdentifiers": FCClientIdentifier},
            @{@"AssociatedBundleIdentifiers": @[FCClientIdentifier, @"com.example"]}, @{@"Unknown": @YES}]) {
        NSMutableDictionary *invalid = canonical.mutableCopy;
        [invalid addEntriesFromDictionary:mutation];
        assert(!FCDaemonPlistValid(invalid));
    }
    assert(!FCDaemonPlistValid(nil));
    assert(!FCDaemonPlistValid(@[]));
}

static void testBundleLayout(void) {
    char temporary[PATH_MAX];
    assert(realpath(NSTemporaryDirectory().fileSystemRepresentation, temporary));
    NSString *root = [@(temporary) stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *bundle = [root stringByAppendingPathComponent:@"Flash.app"];
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *plist = [bundle stringByAppendingPathComponent:FCDaemonPlistRelativePath];
    NSString *helper = [bundle stringByAppendingPathComponent:FCHelperRelativePath];
    [files createDirectoryAtPath:plist.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    [files createDirectoryAtPath:helper.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    assert(!FCBundledDaemonPresent(bundle));
    assert([FCCanonicalDaemonPlist() writeToFile:plist atomically:YES]);
    assert(!FCBundledDaemonPresent(bundle));
    assert([[NSData data] writeToFile:helper atomically:YES]);
    assert(FCBundledDaemonPresent(bundle));
    // The retired plist is optional, but exact when present.
    NSString *retired = [bundle stringByAppendingPathComponent:FCRetiredDaemonPlistRelativePath];
    assert([FCCanonicalDaemonPlist() writeToFile:retired atomically:YES]);
    assert(!FCBundledDaemonPresent(bundle));
    assert([FCCanonicalDaemonPlistForLabel(FCRetiredHelperLabel) writeToFile:retired atomically:YES]);
    assert(FCBundledDaemonPresent(bundle));
    NSMutableDictionary *changed = FCCanonicalDaemonPlist().mutableCopy;
    changed[@"ProgramArguments"] = @[@"/bin/sh"];
    assert([changed writeToFile:plist atomically:YES]);
    assert(!FCBundledDaemonPresent(bundle));
    assert([FCCanonicalDaemonPlist() writeToFile:plist atomically:YES]);
    NSString *elsewhere = [root stringByAppendingPathComponent:@"FlashHelper"];
    assert([files moveItemAtPath:helper toPath:elsewhere error:nil]);
    assert(symlink(elsewhere.fileSystemRepresentation, helper.fileSystemRepresentation) == 0);
    assert(!FCBundledDaemonPresent(bundle));
    [files removeItemAtPath:root error:nil];
}

// The app signs for no Core it cannot place. This unsigned fixture is a real process the kernel answers for,
// and it lacks the hardened runtime, so it stops at the status check.
static void testCoreGuest(void) {
    audit_token_t token;
    mach_msg_type_number_t count = TASK_AUDIT_TOKEN_COUNT;
    assert(task_info(mach_task_self(), TASK_AUDIT_TOKEN, (task_info_t)&token, &count) == KERN_SUCCESS);
    NSData *own = [NSData dataWithBytes:&token length:sizeof(token)];
    NSMutableData *hash = [NSMutableData dataWithLength:20];
    assert([FCCoreGuestCheck(nil, getpid(), hash) isEqualToString:@"failed:token"]);
    assert([FCCoreGuestCheck([NSData data], getpid(), hash) isEqualToString:@"failed:token"]);
    assert([FCCoreGuestCheck([own subdataWithRange:NSMakeRange(0, sizeof(token) - 1)], getpid(), hash)
        isEqualToString:@"failed:token"]);
    assert([FCCoreGuestCheck(own, 0, hash) isEqualToString:@"failed:pid"]);
    assert([FCCoreGuestCheck(own, getpid() + 1, hash) isEqualToString:@"failed:pid"]);
    assert([FCCoreGuestCheck(own, getpid(), nil) isEqualToString:@"failed:bundled"]);
    assert([FCCoreGuestCheck(own, getpid(), hash) hasPrefix:@"failed:status 0x"]);
    // A token of an exited process: the kernel refuses it rather than answer for whoever has the pid now.
    token.val[7]++;
    NSData *stale = [NSData dataWithBytes:&token length:sizeof(token)];
    assert([FCCoreGuestCheck(stale, getpid(), hash) hasPrefix:@"failed:status-read"]);
}

int main(void) {
    @autoreleasepool {
        testCoreGuest();
        NSString *pin = @"0123456789abcdef0123456789abcdef01234567";
        assert([@FC_PINNED_CERTIFICATE_SHA1 isEqualToString:@"BBA7F8529FD271B9848EC03A2CE3F4780F585556"]);
        assert(@FC_PRODUCTION_TEAM_ID.length == 0);
        assert(FC_MANAGED_CANDIDATE_ENABLED == FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED);
        assert([FCHelperLabel isEqualToString:@"com.layoute.flash.helperd"]);
        assert([@FC_HELPER_LABEL isEqualToString:FCHelperLabel] && [@FC_RETIRED_HELPER_LABEL isEqualToString:FCRetiredHelperLabel]);
        assert([FCHelperIdentifier isEqualToString:@"com.layoute.flash.helper"]);
        assert([FCInstalledExecutable(FCHelperIdentifier) isEqualToString:
            @"/Applications/Flash.app/Contents/Library/HelperTools/FlashHelper"]);
        assert([FCInstalledExecutable(FCCoreIdentifier) isEqualToString:@"/Applications/Flash.app/Contents/MacOS/FlClashCore"]);
        assert([FCInstalledExecutable(@"com.layoute.flash.maintenance") isEqualToString:@""]);
        assert(![FCRuntimeDirectory hasPrefix:@"/Library/Application Support/Flash/"]);
        assert(![FCRuntimeDirectory isEqualToString:@"/private/var/run/com.layoute.flash.helper"]);
        testEntitlements();
        testDaemonPlist();
        testBundleLayout();
        for (NSString *role in @[FCClientIdentifier, FCHelperIdentifier, FCCoreIdentifier]) {
            NSString *production = FCSigningRequirement(role);
            NSString *expected = [NSString stringWithFormat:
                @"anchor H\"%@\" and certificate leaf = H\"%@\" and identifier \"%@\"",
                @FC_PINNED_CERTIFICATE_SHA1, @FC_PINNED_CERTIFICATE_SHA1, role];
            assert([production isEqualToString:expected]);
            SecRequirementRef parsed = NULL;
            assert(SecRequirementCreateWithString((__bridge CFStringRef)production, 0, &parsed) == errSecSuccess);
            CFRelease(parsed);
        }
        assert([FCGUIRequirement() isEqualToString:FCSigningRequirement(FCClientIdentifier)]);
        assert(FCRequirementForPolicy(FCClientIdentifier, @"", @"") == nil);
        assert(FCRequirementForPolicy(FCClientIdentifier, @"Alice", @"") == nil);
        assert(FCRequirementForPolicy(FCClientIdentifier, pin, @"ABCDE12345") == nil);
        assert(FCRequirementForPolicy(@"injected\" or true", pin, @"") == nil);
        NSString *requirement = FCRequirementForPolicy(FCClientIdentifier, pin, @"");
        assert([requirement containsString:@"anchor H\""]);
        assert([requirement containsString:@"certificate leaf = H\""]);
        assert([requirement containsString:@"identifier \"com.layoute.flash\""]);
        assert(![requirement containsString:@"trusted"]);
        SecRequirementRef parsed = NULL;
        assert(SecRequirementCreateWithString((__bridge CFStringRef)requirement, 0, &parsed) == errSecSuccess);
        CFRelease(parsed);
        requirement = FCRequirementForPolicy(FCClientIdentifier, @"", @"ABCDE12345");
        assert([requirement containsString:@"anchor apple generic"]);
        parsed = NULL;
        assert(SecRequirementCreateWithString((__bridge CFStringRef)requirement, 0, &parsed) == errSecSuccess);
        CFRelease(parsed);
        printf("Trust-policy pure fixtures passed (candidate=%d); no app, helper, Core, or installer execution\n",
            FC_MANAGED_CANDIDATE_ENABLED);
    }
}
