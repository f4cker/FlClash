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
// The app bundle on disk as stat(2) sees it: `bundleGeneration` stands for its inode/mtime, `bundleStatFails` for
// an entry that cannot be read.
static int64_t bundleGeneration;
static BOOL bundleStatFails;
static NSUInteger bundleStats;
int FixtureBundleStat(const char *path, struct stat *state) {
    bundleStats++;
    assert([@(path) hasPrefix:FCGUIBundle]);
    if (bundleStatFails) { errno = ENOENT; return -1; }
    memset(state, 0, sizeof(*state));
    state->st_ino = 1000 + bundleGeneration;
    state->st_mtimespec.tv_sec = 1700000000 + bundleGeneration;
    return 0;
}

static BOOL FixtureLibrary(NSString *bundle, NSData *hash) { return libraryValid; }
static NSDictionary *FixtureCompatibility(NSString *bundle) {
    return compatibilityValid ? @{@"CallerPolicy": @3, @"ServiceAPI": @1, @"CoreAPI": @1,
        @"CoreSHA256": @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        @"CoreVersion": @"v1.19.0", @"CoreRevision": @"abcdef0"} : nil;
}
static BOOL sliceReadFails;
@interface FixtureFileHandle : NSObject
@end
@implementation FixtureFileHandle
+ (instancetype)fileHandleForReadingAtPath:(NSString *)path { return [self new]; }
- (NSData *)readDataUpToLength:(NSUInteger)length error:(NSError **)error {
    return sliceReadFails ? nil : [NSMutableData dataWithLength:8];
}
- (BOOL)closeAndReturnError:(NSError **)error { return YES; }
@end
#define NSFileHandle FixtureFileHandle
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
#define FCBundleStat FixtureBundleStat
#import <sys/stat.h>
static int FixtureLstat(const char *path, struct stat *state);
#define lstat FixtureLstat
#import "../../Shared/HelperTrust.m"
#undef lstat
#undef NSFileHandle

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
    sliceReadFails = NO;
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
    bundleGeneration = 0;
    bundleStatFails = NO;
}

// The app as the kernel reports it (the GUI's cdhash) for the GUI validator.
static void ResetGUI(void) {
    Reset();
    memcpy(kernelHash, ApprovedHash().bytes, sizeof(kernelHash));
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
    assert([daemon check:fixtureMessage] && !daemon.failure && !daemon.transientFailure);
    assert(messageChecks == messages);
    // Pinned for the connection after the first match; nothing in the copy is resolved (no realpath).
    canonicalValid = NO;
    assert([daemon check:fixtureMessage]);
    kernelHash[0] ^= 1;
    assert(![daemon check:fixtureMessage] && [daemon.failure containsString:@"cdhash"] && !daemon.runningCodeStale);
    // Refusals of what the kernel answered are never transient (a wrong cdhash, status or path).
    assert(!daemon.transientFailure);
    // A running cdhash other than the bundled helper's: a previous build (stale), never trusted.
    Reset(); kernelHash[19] ^= 1;
    FCMessageValidator *stale = CopyValidator();
    assert(![stale check:fixtureMessage] && stale.runningCodeStale && [stale.failure hasPrefix:@"failed:cdhash running="]);
    assert(!stale.transientFailure);
    sliceReadFails = YES;
    FCMessageValidator *unreadSlices = CopyValidator();
    assert(![unreadSlices check:fixtureMessage] && !unreadSlices.runningCodeStale);
    // The bundled helper must itself pass the pinned static requirement.
    Reset(); helperDiskValid = NO;
    FCMessageValidator *unsealed = CopyValidator();
    assert(![unsealed check:fixtureMessage] && !unsealed.runningCodeStale);
    assert([unsealed.failure isEqualToString:@"failed:bundled helper signature"] && !unsealed.transientFailure);
    Reset(); helperDiskInfo[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{@"com.apple.security.get-task-allow": @YES};
    assert(![CopyValidator() check:fixtureMessage]);
    // Kernel status: valid, hard, kill and hardened runtime required; ad hoc, get-task-allow, debugged refused.
    for (NSNumber *missing in @[@0x1, @0x100, @0x200, @0x10000]) {
        Reset(); kernelStatus = KernelHardened & ~missing.unsignedIntValue;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"failed:status 0x"] && !validator.transientFailure);
    }
    for (NSNumber *extra in @[@0x2, @0x4, @0x10000000]) {
        Reset(); kernelStatus = KernelHardened | extra.unsignedIntValue;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"failed:status 0x"] && !validator.transientFailure);
    }
    // Exactly the launcher's copy; the path itself never goes into the failure text.
    for (NSString *other in @[FCInstalledExecutable(FCHelperIdentifier), @"/tmp/FlashHelper",
            @"/Library/Application Support/com.layoute.flash.daemon/FlashHelper",
            [FCHelperCopyPath lowercaseString], [FCHelperCopyPath stringByAppendingString:@"/"]]) {
        Reset(); kernelPath = other;
        FCMessageValidator *validator = CopyValidator();
        assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"failed:path"] && !validator.transientFailure);
    }
    // pid reuse: a token of an earlier lifetime of the pid, or the pid handed over while its path is read.
    Reset(); messageToken.val[7] = 8;
    FCMessageValidator *reused = CopyValidator();
    // Reads the kernel could not answer (the daemon is gone, ESRCH): refused, but transient ("not answering").
    assert(![reused check:fixtureMessage] && [reused.failure isEqualToString:@"failed:status-read errno=3"]);
    assert(reused.transientFailure && !reused.runningCodeStale);
    Reset(); reuseDuringPath = YES;
    reused = CopyValidator();
    assert(![reused check:fixtureMessage] && [reused.failure isEqualToString:@"failed:pid-reused errno=3"] && reused.transientFailure);
    // Kernel reads that fail are named with their errno.
    Reset(); kernelFailOp = 5;
    FCMessageValidator *unread = CopyValidator();
    assert(![unread check:fixtureMessage] && [unread.failure isEqualToString:@"failed:cdhash-read errno=1"] && unread.transientFailure);
    Reset(); pathFails = YES;
    unread = CopyValidator();
    assert(![unread check:fixtureMessage] && [unread.failure isEqualToString:@"failed:path-read errno=3"] && unread.transientFailure);
    // The next check of the same validator starts clean.
    pathFails = NO;
    assert([unread check:fixtureMessage] && !unread.transientFailure && !unread.failure);
    // A reply without a sender token reaches no kernel call.
    Reset(); memset(&messageToken, 0, sizeof(messageToken));
    kernelCalls = 0;
    FCMessageValidator *anonymous = CopyValidator();
    assert(![anonymous check:fixtureMessage] && [anonymous.failure isEqualToString:@"failed:token"] && kernelCalls == 0);
    assert(!anonymous.transientFailure);
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
    // Full validation on the first message: running app, then the whole bundle (one nested seal check).
    ResetGUI();
    FCGUIMessageValidator *validator = [FCGUIMessageValidator new];
    NSUInteger seals = sealChecks, messages = messageChecks;
    assert([validator check:fixtureMessage] && !validator.failure);
    assert(sealChecks == seals + 1 && messageChecks == messages + 1);
    // Later messages of the same connection: no Security call, only the kernel for the same process lifetime.
    for (int i = 0; i < 100; i++) assert([validator check:fixtureMessage]);
    assert(sealChecks == seals + 1 && messageChecks == messages + 1);
    // The bundle changed on disk (update moved in, or a file was rewritten): validated in full again.
    bundleGeneration = 1;
    assert([validator check:fixtureMessage] && sealChecks == seals + 2 && messageChecks == messages + 2);
    assert([validator check:fixtureMessage] && sealChecks == seals + 2);
    // ... and a changed bundle that no longer validates is refused, and stays refused.
    bundleGeneration = 2; diskValid = NO;
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"bundle seal"]);
    diskValid = YES; runningValid = NO;
    assert(![validator check:fixtureMessage]);
    // Bundle entries that cannot be read: no fast path.
    ResetGUI();
    validator = [FCGUIMessageValidator new];
    assert([validator check:fixtureMessage]);
    bundleStatFails = YES;
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"bundle-stat"]);
    // Per message: the cached cdhash, the same pid and pid version, and the kernel's status flags.
    ResetGUI();
    validator = [FCGUIMessageValidator new];
    assert([validator check:fixtureMessage]);
    kernelHash[3] ^= 1;
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"cdhash"]);
    // A failure forgets the connection's verification: the next message needs the full validation again.
    kernelHash[3] ^= 1; seals = sealChecks;
    assert([validator check:fixtureMessage] && sealChecks == seals + 1);
    messageToken.val[7] = 10; kernelVersion = 10;
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"sender changed"]);
    ResetGUI();
    validator = [FCGUIMessageValidator new];
    assert([validator check:fixtureMessage]);
    messageToken.val[5] = 4243;
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"sender changed"]);
    ResetGUI();
    validator = [FCGUIMessageValidator new];
    assert([validator check:fixtureMessage]);
    kernelVersion = 10; // The token's process lifetime ended.
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"status-read errno=3"]);
    for (NSNumber *missing in @[@0x1, @0x100, @0x200, @0x10000]) {
        ResetGUI();
        validator = [FCGUIMessageValidator new];
        assert([validator check:fixtureMessage]);
        kernelStatus = KernelHardened & ~missing.unsignedIntValue;
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"status 0x"]);
    }
    for (NSNumber *extra in @[@0x2, @0x4, @0x10000000]) {
        ResetGUI();
        validator = [FCGUIMessageValidator new];
        assert([validator check:fixtureMessage]);
        kernelStatus = KernelHardened | extra.unsignedIntValue;
        assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"status 0x"]);
        // The full validation asks the kernel too.
        assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    }
    // The full validation: the kernel's cdhash for the message's token must be the one Security validated.
    ResetGUI(); kernelHash[0] ^= 1;
    validator = [FCGUIMessageValidator new];
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"cdhash"]);
    ResetGUI(); memset(&messageToken, 0, sizeof(messageToken));
    validator = [FCGUIMessageValidator new];
    assert(![validator check:fixtureMessage] && [validator.failure isEqualToString:@"token"]);
    ResetGUI(); diskValid = NO;
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    ResetGUI(); libraryValid = NO;
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    ResetGUI(); compatibilityValid = NO;
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    ResetGUI();
    runningInfo[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
    diskInfo[(__bridge NSString *)kSecCodeInfoUnique] = runningInfo[(__bridge NSString *)kSecCodeInfoUnique];
    memset(kernelHash, 0, sizeof(kernelHash));
    assert([[FCGUIMessageValidator new] check:fixtureMessage]);
    for (id malformed in @[[NSData data], [NSMutableData dataWithLength:19], [NSMutableData dataWithLength:21], @"hash"]) {
        ResetGUI();
        runningInfo[(__bridge NSString *)kSecCodeInfoUnique] = malformed;
        diskInfo[(__bridge NSString *)kSecCodeInfoUnique] = malformed;
        assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    }
    ResetGUI();
    [runningInfo removeObjectForKey:(__bridge NSString *)kSecCodeInfoUnique];
    [diskInfo removeObjectForKey:(__bridge NSString *)kSecCodeInfoUnique];
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    ResetGUI(); runningValid = NO;
    validator = [FCGUIMessageValidator new];
    assert(![validator check:fixtureMessage] && [validator.failure hasPrefix:@"SecCodeCheckValidity OSStatus"]);
    ResetGUI(); messageValid = NO;
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    ResetGUI(); canonicalValid = NO;
    assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    for (NSNumber *disk in @[@NO, @YES]) {
        ResetGUI();
        NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
        info[(__bridge NSString *)kSecCodeInfoUnique] = [NSMutableData dataWithLength:20];
        assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    }
    for (NSNumber *disk in @[@NO, @YES]) {
        for (NSString *path in @[@"/tmp/Flash.app/Contents/MacOS/Flash",
            @"/Applications/Flash Copy.app/Contents/MacOS/Flash",
            @"/Library/Application Support/Flash/Flash.app/Contents/MacOS/Flash"]) {
            ResetGUI();
            NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
            info[(__bridge NSString *)kSecCodeInfoMainExecutable] = [NSURL fileURLWithPath:path];
            assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
        }
        ResetGUI();
        NSMutableDictionary *info = disk.boolValue ? diskInfo : runningInfo;
        info[(__bridge NSString *)kSecCodeInfoEntitlementsDict] = @{};
        assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
    }
    FCMessageValidator *legacy = [[FCMessageValidator alloc] initWithIdentifier:FCClientIdentifier
        executable:FCInstalledExecutable(FCClientIdentifier)];
    assert(![legacy check:fixtureMessage]);
    Reset();
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
