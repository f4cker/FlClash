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
static NSMutableDictionary *helperCopyInfo;
static BOOL messageValid, runningValid, diskValid, canonicalValid, libraryValid, compatibilityValid;
static BOOL selfValid, helperDiskValid, helperCopyValid, daemonPlistValid, helperFileValid, launcherFileValid;
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
    if ([value isEqualToString:FCHelperCopyPath]) {
        *code = (SecStaticCodeRef)CFBridgingRetain(helperCopyInfo);
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
    if ((__bridge id)code == helperCopyInfo) return helperCopyValid ? errSecSuccess : errSecCSBadResource;
    return diskValid ? errSecSuccess : errSecCSBadResource;
}
static int FixtureLstat(const char *path, struct stat *state) {
    NSString *value = @(path);
    if ([value hasPrefix:[FCGUIBundle stringByAppendingString:@"/"]]) {
        memset(state, 0, sizeof(*state));
        state->st_mode = S_IFREG | 0755;
        state->st_nlink = 1;
        BOOL present = [value hasSuffix:FCHelperRelativePath] ? helperFileValid :
            [value hasSuffix:FCLauncherRelativePath] ? launcherFileValid : YES;
        if (!present) { errno = ENOENT; return -1; }
        return 0;
    }
    return lstat(path, state);
}
static NSDictionary *FixtureLoadPlist(NSString *path) {
    // The retired name's plist (kept for unregister only) is present in the bundle with its own exact schema.
    if ([path hasSuffix:FCRetiredDaemonPlistRelativePath]) return FCCanonicalDaemonPlistForLabel(FCRetiredHelperLabel);
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

// The kernel's view of the daemon (launcher's copy in a root-only directory): csops_audittoken, proc_pidpath and
// the sender's audit token of an XPC reply.
static uint32_t kernelStatus;
static uint8_t kernelHash[20];
static NSString *kernelPath;
static uint32_t kernelVersion;
static BOOL reuseDuringPath, pathFails;
static int kernelFailOp;
static NSUInteger kernelCalls;
static audit_token_t messageToken;
static const uint32_t KernelHardened = 0x1 | 0x100 | 0x200 | 0x10000 | 0x20000000;

int FixtureCodeOps(pid_t pid, unsigned int ops, void *address, size_t size, audit_token_t *token) {
    kernelCalls++;
    assert(token && (pid_t)token->val[5] == pid);
    // The token names one process lifetime: the kernel refuses it once the pid is held by another one.
    if (pid != 4242 || token->val[7] != kernelVersion) { errno = ESRCH; return -1; }
    if ((int)ops == kernelFailOp) { errno = EPERM; return -1; }
    if (ops == 0) { assert(size == sizeof(kernelStatus)); memcpy(address, &kernelStatus, size); return 0; }
    assert(ops == 5 && size == sizeof(kernelHash));
    memcpy(address, kernelHash, size);
    return 0;
}
int FixtureProcPath(int pid, void *buffer, uint32_t size) {
    kernelCalls++;
    if (pathFails) { errno = ESRCH; return 0; }
    // The process exits and its pid is handed to another one while the path is read.
    if (reuseDuringPath) kernelVersion++;
    const char *path = kernelPath.fileSystemRepresentation;
    strlcpy(buffer, path, size);
    return (int)strlen(path);
}
void FixtureAuditToken(xpc_object_t message, audit_token_t *token) { *token = messageToken; }

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
#define FCCodeOps FixtureCodeOps
#define FCProcPath FixtureProcPath
#define FCMessageAuditToken FixtureAuditToken
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
    selfValid = helperDiskValid = helperCopyValid = daemonPlistValid = helperFileValid = launcherFileValid = YES;
    uint8_t bytes[20];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) bytes[i] = (uint8_t)(0xa0 + i);
    // The daemon runs as the launcher's copy of the bundled helper: same bytes, same cdhash.
    helperRunningInfo = [@{(__bridge NSString *)kSecCodeInfoMainExecutable: [NSURL fileURLWithPath:FCHelperCopyPath],
        (__bridge NSString *)kSecCodeInfoUnique: [NSData dataWithBytes:bytes length:sizeof(bytes)],
        (__bridge NSString *)kSecCodeInfoEntitlementsDict: @{},
        (__bridge NSString *)kSecCodeInfoFlags: @(kSecCodeSignatureRuntime)} mutableCopy];
    helperDiskInfo = helperRunningInfo.mutableCopy;
    helperDiskInfo[(__bridge NSString *)kSecCodeInfoMainExecutable] =
        [NSURL fileURLWithPath:FCInstalledExecutable(FCHelperIdentifier)];
    helperCopyInfo = helperRunningInfo.mutableCopy;
    kernelStatus = KernelHardened;
    memcpy(kernelHash, bytes, sizeof(kernelHash));
    kernelPath = FCHelperCopyPath;
    kernelVersion = 9;
    reuseDuringPath = pathFails = NO;
    kernelFailOp = -1;
    memset(&messageToken, 0, sizeof(messageToken));
    messageToken.val[5] = 4242;
    messageToken.val[7] = 9;
}

// The daemon's mandatory startup/per-operation verification: every failure is a refusal (exit FC_HELPER_REFUSED_EXIT = 79 in main).
static void TestSelfCheck(void) {
    NSString *path = FCHelperCopyPath, *bundle = FCGUIBundle;
    Reset();
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"ok"]);
    // Started directly from the bundle (a registration that still names FlashHelper) or from anywhere else.
    for (NSString *other in @[FCInstalledExecutable(FCHelperIdentifier),
            @"/Library/Application Support/Flash/Flash.app/Contents/Library/HelperTools/FlashHelper", @""])
        assert([FCHelperSelfCheck(other, bundle) isEqualToString:@"path"]);
    // The bundle argument is untrusted: only the canonical /Applications/Flash.app.
    for (NSString *other in @[@"/Applications/Flash Copy.app", @"/Applications/Flash.app/", @"/tmp/Flash.app", @""])
        assert([FCHelperSelfCheck(path, other) isEqualToString:@"bundlePath"]);
    Reset(); canonicalValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"bundlePath"]);
    Reset(); selfValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"self"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:19];
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"self"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoMainExecutable] = [NSURL fileURLWithPath:@"/tmp/FlashHelper"];
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"path"]);
    for (NSString *key in @[@"com.apple.security.get-task-allow", @"com.apple.security.cs.disable-library-validation",
            @"com.apple.security.cs.allow-dyld-environment-variables"]) {
        Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{key: @YES};
        assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"entitlements"]);
    }
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoFlags] = @0;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"entitlements"]);
    Reset(); helperRunningInfo[(__bridge NSString *)kSecCodeInfoFlags] = @(kSecCodeSignatureRuntime | kSecCodeSignatureAdhoc);
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"entitlements"]);
    // The copy on disk.
    Reset(); helperCopyValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"disk"]);
    Reset(); helperCopyInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"replaced"]);
    // The helper the sealed app carries must be the one running (static check, then cdhash comparison).
    Reset(); helperDiskValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"bundledHelper"]);
    Reset(); helperDiskInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    NSString *mismatch = FCHelperSelfCheck(path, bundle);
    assert([mismatch hasPrefix:@"bundledHelperMismatch running=a0a1"] &&
        [mismatch hasSuffix:@"bundled=0000000000000000000000000000000000000000"]);
    Reset(); diskValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"bundle"]);
    Reset(); libraryValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"bundle"]);
    Reset(); compatibilityValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"bundle"]);
    Reset(); daemonPlistValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"plist"]);
    Reset(); helperFileValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"plist"]);
    Reset(); launcherFileValid = NO;
    assert([FCHelperSelfCheck(path, bundle) isEqualToString:@"plist"]);
    Reset();
}

static FCMessageValidator *CopyValidator(void) {
    return [[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier executable:FCHelperCopyPath
        sealedExecutable:FCInstalledExecutable(FCHelperIdentifier)];
}

// Reply validation on the GUI side for the daemon running as the launcher's root-only copy: the app cannot read
// that file, so Security is never asked about the running code; the kernel's status, cdhash and path for the
// reply's audit token decide, against the bundled helper's statically validated cdhash.
static void TestCopyValidator(void) {
    // The copy's directory is unreadable: every Security call about the running code would fail (EACCES).
    Reset(); messageValid = runningValid = NO;
    NSUInteger messages = messageChecks;
    FCMessageValidator *daemon = CopyValidator();
    assert([daemon check:fixtureMessage] && !daemon.failure);
    assert(messageChecks == messages);
    // Pinned for the connection after the first match; nothing in the copy is resolved (no realpath).
    canonicalValid = NO;
    assert([daemon check:fixtureMessage]);
    kernelHash[0] ^= 1;
    assert(![daemon check:fixtureMessage] && [daemon.failure containsString:@"cdhash"] && !daemon.runningCodeStale);
    // A running cdhash other than the bundled helper's: a previous build (stale), never trusted.
    Reset(); kernelHash[19] ^= 1;
    FCMessageValidator *stale = CopyValidator();
    assert(![stale check:fixtureMessage] && stale.runningCodeStale && [stale.failure hasPrefix:@"failed:cdhash running="]);
    // The bundled helper must itself pass the pinned static requirement.
    Reset(); helperDiskValid = NO;
    FCMessageValidator *unsealed = CopyValidator();
    assert(![unsealed check:fixtureMessage] && !unsealed.runningCodeStale);
    assert([unsealed.failure isEqualToString:@"failed:bundled helper signature"]);
    Reset(); helperDiskInfo[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{@"com.apple.security.get-task-allow": @YES};
    assert(![CopyValidator() check:fixtureMessage]);
    // Kernel status: valid, hard, kill and hardened runtime required; ad hoc, get-task-allow, debugged refused.
    for (NSNumber *missing in @[@0x1, @0x100, @0x200, @0x10000]) {
        Reset(); kernelStatus = KernelHardened & ~missing.unsignedIntValue;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"failed:status 0x"]);
    }
    for (NSNumber *extra in @[@0x2, @0x4, @0x10000000]) {
        Reset(); kernelStatus = KernelHardened | extra.unsignedIntValue;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"failed:status 0x"]);
    }
    // Exactly the launcher's copy; the path itself never goes into the failure text.
    for (NSString *other in @[FCInstalledExecutable(FCHelperIdentifier), @"/tmp/FlashHelper",
            @"/Library/Application Support/com.layoute.flash.daemon/FlashHelper",
            [FCHelperCopyPath lowercaseString], [FCHelperCopyPath stringByAppendingString:@"/"]]) {
        Reset(); kernelPath = other;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"failed:path"]);
    }
    // pid reuse: a token of an earlier lifetime of the pid, or the pid handed over while its path is read.
    Reset(); messageToken.val[7] = 8;
    FCMessageValidator *reused = CopyValidator();
    assert(![reused check:fixtureMessage] && [reused.failure isEqualToString:@"failed:status-read errno=3"]);
    Reset(); reuseDuringPath = YES;
    reused = CopyValidator();
    assert(![reused check:fixtureMessage] && [reused.failure isEqualToString:@"failed:pid-reused errno=3"]);
    // Kernel reads that fail are named with their errno.
    Reset(); kernelFailOp = 5;
    FCMessageValidator *unread = CopyValidator();
    assert(![unread check:fixtureMessage] && [unread.failure isEqualToString:@"failed:cdhash-read errno=1"]);
    Reset(); pathFails = YES;
    unread = CopyValidator();
    assert(![unread check:fixtureMessage] && [unread.failure isEqualToString:@"failed:path-read errno=3"]);
    // A reply without a sender token reaches no kernel call.
    Reset(); memset(&messageToken, 0, sizeof(messageToken));
    kernelCalls = 0;
    FCMessageValidator *anonymous = CopyValidator();
    assert(![anonymous check:fixtureMessage] && [anonymous.failure isEqualToString:@"failed:token"] && kernelCalls == 0);
    // The in-bundle path (executable == sealed executable) keeps the Security validation, now with the failed step.
    Reset(); runningValid = NO;
    FCMessageValidator *bundled = [[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier
        executable:FCInstalledExecutable(FCHelperIdentifier)];
    runningInfo = helperDiskInfo;
    kernelCalls = 0;
    assert(![bundled check:fixtureMessage] && [bundled.failure hasPrefix:@"SecCodeCheckValidity OSStatus"]);
    assert(kernelCalls == 0);
    Reset(); runningInfo = helperDiskInfo;
    assert([bundled check:fixtureMessage]);
    Reset();
}

static void TestArguments(void) {
    NSString *reason = nil;
    Reset();
    assert([FCHelperBundleFromArguments(@[FCHelperCopyPath, @"--flash-bundle", FCGUIBundle], &reason)
        isEqualToString:FCGUIBundle] && !reason);
    // Started without the launcher: refused, with the reason.
    assert(!FCHelperBundleFromArguments(@[FCInstalledExecutable(FCHelperIdentifier)], &reason));
    assert([reason hasPrefix:@"missing --flash-bundle"]);
    for (NSArray *arguments in @[@[FCHelperCopyPath, @"--flash-bundle"],
            @[FCHelperCopyPath, @"--flash-bundle", FCGUIBundle, @"extra"],
            @[FCHelperCopyPath, @"--bundle", FCGUIBundle],
            @[FCHelperCopyPath, FCGUIBundle, @"--flash-bundle"],
            @[FCInstalledExecutable(FCHelperIdentifier), @"--flash-bundle", FCGUIBundle],
            @[FCHelperCopyPath, @"--flash-bundle", @"/Applications/Flash Copy.app"],
            @[FCHelperCopyPath, @"--flash-bundle", @"/Applications/../Applications/Flash.app"],
            @[FCHelperCopyPath, @"--flash-bundle", @""], @[]]) {
        reason = nil;
        assert(!FCHelperBundleFromArguments(arguments, &reason) && reason.length);
    }
    Reset(); canonicalValid = NO;
    assert(!FCHelperBundleFromArguments(@[FCHelperCopyPath, @"--flash-bundle", FCGUIBundle], &reason));
    assert([reason containsString:@"canonical"]);
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
            TestCopyValidator();
            TestArguments();
        } else {
            Reset();
            assert(![FCHelperSelfCheck(FCHelperCopyPath, FCGUIBundle) isEqualToString:@"ok"]);
            NSUInteger checks = messageChecks;
            assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
            assert(messageChecks == checks);
            kernelCalls = 0;
            FCMessageValidator *copy = CopyValidator();
            assert(![copy check:fixtureMessage] && [copy.failure isEqualToString:@"requirement"] && kernelCalls == 0);
        }
        puts("GUI trust and daemon self-check fixtures passed; Security/process/filesystem validation mocked");
    }
}
