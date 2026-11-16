#import "../../Shared/HelperTrust.h"
#import "../../Shared/HelperIdentity.h"
#import <assert.h>
#import "../../Shared/LibraryConstraintPolicy.h"
#import "../../Shared/HelperCompatibility.h"

static xpc_object_t fixtureMessage;
static NSMutableDictionary *runningInfo;
static NSMutableDictionary *diskInfo;
static NSMutableDictionary *helperRunningInfo;
static NSMutableDictionary *helperDiskInfo;
static BOOL messageValid, runningValid, diskValid, canonicalValid, libraryValid, compatibilityValid;
static BOOL selfValid, helperDiskValid, daemonPlistValid, helperFileValid;
static NSUInteger messageChecks, sealChecks;

static OSStatus FixtureMessage(xpc_object_t message, SecCSFlags flags, SecCodeRef *code) {
    messageChecks++;
    if (!messageValid) return errSecCSUnsigned;
    *code = (SecCodeRef)CFBridgingRetain(runningInfo);
    return errSecSuccess;
}
static OSStatus FixtureSelf(SecCSFlags flags, SecCodeRef *code) {
    *code = (SecCodeRef)CFBridgingRetain(helperRunningInfo);
    return errSecSuccess;
}
static OSStatus FixtureRunning(SecCodeRef code, SecCSFlags flags, SecRequirementRef requirement) {
    assert(flags == kSecCSStrictValidate && requirement);
    if ((__bridge id)code == helperRunningInfo) return selfValid ? errSecSuccess : errSecCSReqFailed;
    return runningValid ? errSecSuccess : errSecCSReqFailed;
}
static OSStatus FixtureInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef *info) {
    assert(flags == kSecCSSigningInformation);
    *info = CFRetain((CFDictionaryRef)code);
    return errSecSuccess;
}
static OSStatus FixtureDisk(CFURLRef path, SecCSFlags flags, SecStaticCodeRef *code) {
    NSString *value = ((__bridge NSURL *)path).path;
    if ([value isEqualToString:FCInstalledExecutable(FCHelperIdentifier)]) {
        *code = (SecStaticCodeRef)CFBridgingRetain(helperDiskInfo);
        return errSecSuccess;
    }
    assert([value isEqualToString:FCGUIBundle]);
    *code = (SecStaticCodeRef)CFBridgingRetain(diskInfo);
    return errSecSuccess;
}
static OSStatus FixtureSeal(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef requirement) {
    sealChecks++;
    assert(flags == (kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode));
    assert(requirement);
    if ((__bridge id)code == helperDiskInfo) return helperDiskValid ? errSecSuccess : errSecCSBadResource;
    return diskValid ? errSecSuccess : errSecCSBadResource;
}
static int FixtureLstat(const char *path, struct stat *state) {
    NSString *value = @(path);
    if ([value hasPrefix:[FCGUIBundle stringByAppendingString:@"/"]]) {
        memset(state, 0, sizeof(*state));
        state->st_mode = S_IFREG | 0755;
        state->st_nlink = 1;
        BOOL present = [value hasSuffix:FCHelperRelativePath] ? helperFileValid : YES;
        if (!present) { errno = ENOENT; return -1; }
        return 0;
    }
    return lstat(path, state);
}
static NSDictionary *FixtureLoadPlist(NSString *path) {
    if (!daemonPlistValid) {
        NSMutableDictionary *changed = FCCanonicalDaemonPlist().mutableCopy;
        changed[@"ProgramArguments"] = @[@"/bin/sh", @"-c", @"id"];
        return changed;
    }
    return FCCanonicalDaemonPlist();
}
static char *FixtureRealpath(const char *path, char *resolved) {
    if (!canonicalValid) return NULL;
    strcpy(resolved, path);
    return resolved;
}

static BOOL FixtureLibrary(NSString *bundle, NSData *hash) { return libraryValid; }
static NSDictionary *FixtureCompatibility(NSString *bundle) {
    return compatibilityValid ? @{@"CallerPolicy": @3, @"ServiceAPI": @1, @"CoreAPI": @1,
        @"CoreSHA256": @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        @"CoreVersion": @"v1.19.0", @"CoreRevision": @"abcdef0"} : nil;
}
#define FCGUILibraryPolicy FixtureLibrary
#define FCReadCompatibility FixtureCompatibility
#define SecCodeCreateWithXPCMessage FixtureMessage
#define SecCodeCheckValidity FixtureRunning
#define SecCodeCopySigningInformation FixtureInformation
#define SecStaticCodeCreateWithPath FixtureDisk
#define SecStaticCodeCheckValidity FixtureSeal
#define SecCodeCopySelf FixtureSelf
#define realpath FixtureRealpath
#define FCLoadPlist FixtureLoadPlist
#import <sys/stat.h>
static int FixtureLstat(const char *path, struct stat *state);
#define lstat FixtureLstat
#import "../../Shared/HelperTrust.m"
#undef lstat

static NSDictionary *GUIEntitlements(void) {
    return @{@"com.apple.security.files.user-selected.read-write": @YES,
        @"com.apple.security.personal-information.location": @YES,
        @"com.apple.security.cs.disable-library-validation": @YES};
}

static NSData *ApprovedHash(void) {
    uint8_t bytes[20];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) bytes[i] = (uint8_t)i;
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

static void Reset(void) {
    messageValid = runningValid = diskValid = canonicalValid = libraryValid = compatibilityValid = YES;
    runningInfo = [@{(__bridge NSString *)kSecCodeInfoMainExecutable:
        [NSURL fileURLWithPath:FCInstalledExecutable(FCClientIdentifier)],
        (__bridge NSString *)kSecCodeInfoUnique: ApprovedHash(),
        (__bridge NSString *)kSecCodeInfoEntitlementsDict: GUIEntitlements(),
        (__bridge NSString *)kSecCodeInfoFlags: @(kSecCodeSignatureRuntime)} mutableCopy];
    diskInfo = runningInfo.mutableCopy;
    selfValid = helperDiskValid = daemonPlistValid = helperFileValid = YES;
    uint8_t bytes[20];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) bytes[i] = (uint8_t)(0xa0 + i);
    helperRunningInfo = [@{(__bridge NSString *)kSecCodeInfoMainExecutable:
        [NSURL fileURLWithPath:FCInstalledExecutable(FCHelperIdentifier)],
        (__bridge NSString *)kSecCodeInfoUnique: [NSData dataWithBytes:bytes length:sizeof(bytes)],
        (__bridge NSString *)kSecCodeInfoEntitlementsDict: @{},
        (__bridge NSString *)kSecCodeInfoFlags: @(kSecCodeSignatureRuntime)} mutableCopy];
    helperDiskInfo = helperRunningInfo.mutableCopy;
}

// The daemon's mandatory startup/per-operation verification: every failure is a refusal (exit 78 in main).
static void TestSelfCheck(void) {
    NSString *path = FCInstalledExecutable(FCHelperIdentifier);
    Reset();
    assert([FCHelperSelfCheck(path) isEqualToString:@"ok"]);
    assert([FCHelperSelfCheck(@"/Library/Application Support/Flash/Flash.app/Contents/Library/HelperTools/FlashHelper")
        isEqualToString:@"path"]);
    Reset(); selfValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"self"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:19];
    assert([FCHelperSelfCheck(path) isEqualToString:@"self"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoMainExecutable] = [NSURL fileURLWithPath:@"/tmp/FlashHelper"];
    assert([FCHelperSelfCheck(path) isEqualToString:@"path"]);
    Reset(); canonicalValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"path"]);
    for (NSString *key in @[@"com.apple.security.get-task-allow", @"com.apple.security.cs.disable-library-validation",
            @"com.apple.security.cs.allow-dyld-environment-variables"]) {
        Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{key: @YES};
        assert([FCHelperSelfCheck(path) isEqualToString:@"entitlements"]);
    }
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoFlags] = @0;
    assert([FCHelperSelfCheck(path) isEqualToString:@"entitlements"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoFlags] = @(kSecCodeSignatureRuntime | kSecCodeSignatureAdhoc);
    assert([FCHelperSelfCheck(path) isEqualToString:@"entitlements"]);
    Reset(); helperDiskValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"disk"]);
    Reset(); helperDiskInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    assert([FCHelperSelfCheck(path) isEqualToString:@"replaced"]);
    Reset(); diskValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"bundle"]);
    Reset(); libraryValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"bundle"]);
    Reset(); compatibilityValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"bundle"]);
    Reset(); daemonPlistValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"plist"]);
    Reset(); helperFileValid = NO;
    assert([FCHelperSelfCheck(path) isEqualToString:@"plist"]);
    // Reply validation on the GUI side pins the daemon cdhash for the connection after the first disk match.
    Reset();
    FCMessageValidator *daemon = [[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier executable:path];
    runningInfo = helperRunningInfo;
    assert([daemon check:fixtureMessage]);
    runningInfo = helperRunningInfo.mutableCopy;
    runningInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    assert(![daemon check:fixtureMessage]);
    Reset(); helperDiskInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    runningInfo = helperRunningInfo;
    assert(![[[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier executable:path] check:fixtureMessage]);
    Reset();
}

static void TestEntitlements(void) {
    NSDictionary *allowed = GUIEntitlements();
    assert(FCGUIEntitlementsAllowed(allowed, kSecCodeSignatureRuntime));
    assert(!FCGUIEntitlementsAllowed(allowed, 0));
    assert(!FCGUIEntitlementsAllowed(allowed, kSecCodeSignatureRuntime | kSecCodeSignatureAdhoc));
    assert(!FCGUIEntitlementsAllowed(nil, kSecCodeSignatureRuntime));
    for (NSString *key in allowed) {
        NSMutableDictionary *changed = allowed.mutableCopy;
        [changed removeObjectForKey:key];
        assert(!FCGUIEntitlementsAllowed(changed, kSecCodeSignatureRuntime));
        for (id value in @[@NO, @1, @"true"]) {
            changed[key] = value;
            assert(!FCGUIEntitlementsAllowed(changed, kSecCodeSignatureRuntime));
        }
    }
    for (NSString *key in @[@"com.apple.security.cs.allow-jit",
        @"com.apple.security.cs.allow-unsigned-executable-memory",
        @"com.apple.security.cs.allow-dyld-environment-variables",
        @"com.apple.security.get-task-allow", @"unknown"]) {
        NSMutableDictionary *changed = allowed.mutableCopy;
        changed[key] = @NO;
        assert(!FCGUIEntitlementsAllowed(changed, kSecCodeSignatureRuntime));
    }
    // The GUI's library-validation exception never applies to the daemon or Core.
    assert(!FCCodeEntitlementsAllowed(allowed, kSecCodeSignatureRuntime));
}

static void TestMessages(void) {
    FCGUIMessageValidator *validator = [FCGUIMessageValidator new];
    Reset();
    assert([validator check:fixtureMessage]);
    NSUInteger seals = sealChecks;
    assert([validator check:fixtureMessage]);
    assert(sealChecks == seals + 1);
    diskValid = NO;
    assert(![validator check:fixtureMessage]);
    Reset(); libraryValid = NO;
    assert(![validator check:fixtureMessage]);
    Reset(); compatibilityValid = NO;
    assert(![validator check:fixtureMessage]);
    Reset();
    runningInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    diskInfo[(__bridge NSString *)kSecCodeInfoUnique] = runningInfo[(__bridge NSString *)kSecCodeInfoUnique];
    assert([validator check:fixtureMessage]);
    for (id malformed in @[[NSData data], [NSMutableData dataWithLength:19], [NSMutableData dataWithLength:21], @"hash"]) {
        Reset();
        runningInfo[(__bridge NSString *)kSecCodeInfoUnique] = malformed;
        diskInfo[(__bridge NSString *)kSecCodeInfoUnique] = malformed;
        assert(![validator check:fixtureMessage]);
    }
    Reset();
    [runningInfo removeObjectForKey:(__bridge NSString *)kSecCodeInfoUnique];
    [diskInfo removeObjectForKey:(__bridge NSString *)kSecCodeInfoUnique];
    assert(![validator check:fixtureMessage]);
    Reset(); runningValid = NO;
    assert(![validator check:fixtureMessage]);
    Reset(); messageValid = NO;
    assert(![validator check:fixtureMessage]);
    Reset(); canonicalValid = NO;
    assert(![validator check:fixtureMessage]);
    for (NSNumber *disk in @[@NO, @YES]) {
        Reset();
        NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
        info[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
        assert(![validator check:fixtureMessage]);
    }
    for (NSNumber *disk in @[@NO, @YES]) {
        for (NSString *path in @[@"/tmp/Flash.app/Contents/MacOS/Flash",
            @"/Applications/Flash Copy.app/Contents/MacOS/Flash",
            @"/Library/Application Support/Flash/Flash.app/Contents/MacOS/Flash"]) {
            Reset();
            NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
            info[(__bridge NSString *)kSecCodeInfoMainExecutable] = [NSURL fileURLWithPath:path];
            assert(![validator check:fixtureMessage]);
        }
        Reset();
        NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
        info[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{};
        assert(![validator check:fixtureMessage]);
    }
    FCMessageValidator *legacy = [[FCMessageValidator alloc] initWithIdentifier:FCClientIdentifier
        executable:FCInstalledExecutable(FCClientIdentifier)];
    assert(![legacy check:fixtureMessage]);
}

int main(void) {
    @autoreleasepool {
        fixtureMessage = xpc_dictionary_create(NULL, NULL, 0);
        TestEntitlements();
        assert([FCGUIBundle isEqualToString:@"/Applications/Flash.app"]);
        for (NSString *role in @[FCClientIdentifier, FCHelperIdentifier, FCCoreIdentifier])
            assert([FCInstalledExecutable(role) hasPrefix:[FCGUIBundle stringByAppendingString:@"/"]]);
        assert(!FCValidGUIHash(nil));
        assert(!FCValidGUIHash([NSMutableData dataWithLength:19]));
        assert(!FCValidGUIHash([NSMutableData dataWithLength:21]));
        assert(FCValidGUIHash(ApprovedHash()));
        BOOL identity = [@FC_PINNED_CERTIFICATE_SHA1 isEqual:@"BBA7F8529FD271B9848EC03A2CE3F4780F585556"];
        assert((FCGUIRequirement() != nil) == identity);
        Reset();
        assert([FCGUIBundleTrust(FCGUIBundle) isEqualToString:@"trusted"] == identity);
        assert([FCGUIBundleTrust(@"/Library/Application Support/Flash/Flash.app") isEqualToString:@"moveRequired"]);
        if (identity) {
            assert([FCGUIRequirement() isEqual:FCSigningRequirement(FCClientIdentifier)]);
            assert(![FCGUIRequirement() containsString:@"cdhash"]);
            TestMessages();
            TestSelfCheck();
        } else {
            Reset();
            assert(![FCHelperSelfCheck(FCInstalledExecutable(FCHelperIdentifier)) isEqualToString:@"ok"]);
            NSUInteger checks = messageChecks;
            assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
            assert(messageChecks == checks);
        }
        puts("GUI trust and daemon self-check fixtures passed; Security/process/filesystem validation mocked");
    }
}
