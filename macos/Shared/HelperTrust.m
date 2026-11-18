#import "HelperTrust.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/acl.h>
#import <sys/stat.h>
#import <errno.h>
#import <fcntl.h>
#import <libproc.h>
#import <unistd.h>

#import "HelperIdentity.h"
#import "ProtectedPathPolicy.h"
#import "LibraryConstraintPolicy.h"
#import "HelperCompatibility.h"

NSString * const FCHelperLabel = @FC_HELPER_LABEL;
NSString * const FCDaemonPlistName = @FC_HELPER_LABEL ".plist";
NSString * const FCRetiredHelperLabel = @FC_RETIRED_HELPER_LABEL;
NSString * const FCRetiredDaemonPlistName = @FC_RETIRED_HELPER_LABEL ".plist";
NSString * const FCRetiredDaemonPlistRelativePath = @"Contents/Library/LaunchDaemons/" FC_RETIRED_HELPER_LABEL ".plist";
NSString * const FCClientIdentifier = @"com.layoute.flash";
NSString * const FCHelperIdentifier = @"com.layoute.flash.helper";
NSString * const FCCoreIdentifier = @"com.layoute.flash.core";
NSString * const FCGUIBundle = @"/Applications/Flash.app";
NSString * const FCDaemonPlistRelativePath = @"Contents/Library/LaunchDaemons/" FC_HELPER_LABEL ".plist";
NSString * const FCHelperRelativePath = @"Contents/Library/HelperTools/FlashHelper";
NSString * const FCCoreRelativePath = @"Contents/MacOS/FlClashCore";
NSString * const FCLauncherRelativePath = @"Contents/Library/HelperTools/FlashHelperLauncher";
NSString * const FCLauncherStateDirectory = @"/Library/Application Support/com.layoute.flash.helperd";
NSString * const FCLauncherStatusDirectory = @"/Library/Application Support/com.layoute.flash.helperd-status";
NSString * const FCHelperCopyPath = @"/Library/Application Support/com.layoute.flash.helperd/FlashHelper";
NSString * const FCHelperBundleArgument = @"--flash-bundle";
// Kept across the label change (see HelperTrust.h): the new helper recovers the previous helper's Core from here.
NSString * const FCRuntimeDirectory = @"/Library/Application Support/com.layoute.flash.daemon";

NSString *FCInstalledExecutable(NSString *role) {
    if ([role isEqualToString:FCClientIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"];
    if ([role isEqualToString:FCHelperIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:FCHelperRelativePath];
    if ([role isEqualToString:FCCoreIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:FCCoreRelativePath];
    return @"";
}

// The current name runs the fixed launcher; the retired name's plist (never registered again, only unregistered)
// keeps the BundleProgram it was registered with.
NSDictionary *FCCanonicalDaemonPlistForLabel(NSString *label) {
    NSString *program = [label isEqualToString:FCRetiredHelperLabel] ? FCHelperRelativePath : FCLauncherRelativePath;
    return @{@"Label": label, @"BundleProgram": program,
        @"MachServices": @{label: @YES}, @"ProcessType": @"Interactive",
        @"AssociatedBundleIdentifiers": @[FCClientIdentifier]};
}

NSDictionary *FCCanonicalDaemonPlist(void) {
    return FCCanonicalDaemonPlistForLabel(FCHelperLabel);
}

// Exact schema: no Program/ProgramArguments/EnvironmentVariables/KeepAlive/RunAtLoad or any other key.
static BOOL FCDaemonPlistValidForLabel(id plist, NSString *label) {
    if (![plist isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *dictionary = plist;
    for (NSString *key in @[@"Label", @"BundleProgram", @"ProcessType"])
        if (![dictionary[key] isKindOfClass:NSString.class]) return NO;
    NSDictionary *services = dictionary[@"MachServices"];
    if (![services isKindOfClass:NSDictionary.class] || services.count != 1) return NO;
    id enabled = services[label];
    if (!enabled || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) return NO;
    id association = dictionary[@"AssociatedBundleIdentifiers"];
    if (![association isKindOfClass:NSArray.class] || [association count] != 1 ||
        ![association[0] isKindOfClass:NSString.class]) return NO;
    return [dictionary isEqualToDictionary:FCCanonicalDaemonPlistForLabel(label)];
}

BOOL FCDaemonPlistValid(id plist) {
    return FCDaemonPlistValidForLabel(plist, FCHelperLabel);
}

BOOL FCRetiredDaemonPlistValid(id plist) {
    return FCDaemonPlistValidForLabel(plist, FCRetiredHelperLabel);
}

static BOOL FCRegularCanonicalFile(NSString *path) {
    struct stat state;
    char canonical[PATH_MAX];
    return lstat(path.fileSystemRepresentation, &state) == 0 && S_ISREG(state.st_mode) &&
        realpath(path.fileSystemRepresentation, canonical) && [@(canonical) isEqualToString:path];
}

#ifndef FCLoadPlist
static NSDictionary *FCLoadPlist(NSString *path) { return [NSDictionary dictionaryWithContentsOfFile:path]; }
#endif

BOOL FCBundledDaemonPresent(NSString *bundle) {
    NSString *plist = [bundle stringByAppendingPathComponent:FCDaemonPlistRelativePath];
    NSString *helper = [bundle stringByAppendingPathComponent:FCHelperRelativePath];
    NSString *launcher = [bundle stringByAppendingPathComponent:FCLauncherRelativePath];
    // The retired name's plist is optional (it only serves unregister), but when present it must be exact.
    NSString *retired = [bundle stringByAppendingPathComponent:FCRetiredDaemonPlistRelativePath];
    struct stat state;
    BOOL retiredAbsent = lstat(retired.fileSystemRepresentation, &state) != 0 && errno == ENOENT;
    return FCRegularCanonicalFile(plist) && FCRegularCanonicalFile(helper) && FCRegularCanonicalFile(launcher) &&
        FCDaemonPlistValid(FCLoadPlist(plist)) &&
        (retiredAbsent || (FCRegularCanonicalFile(retired) && FCRetiredDaemonPlistValid(FCLoadPlist(retired))));
}

const size_t FCMaxFrame = 64 * 1024 * 1024;

NSString *FCRequirementForPolicy(NSString *identifier, NSString *certificatePin, NSString *team) {
    NSCharacterSet *identifierCharacters = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
    if (!identifier.length || [identifier rangeOfCharacterFromSet:identifierCharacters.invertedSet].location != NSNotFound)
        return nil;
    if (certificatePin.length) {
        NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
        if (team.length || certificatePin.length != 40 ||
            [certificatePin rangeOfCharacterFromSet:hex.invertedSet].location != NSNotFound) return nil;
        return [NSString stringWithFormat:
            @"anchor H\"%@\" and certificate leaf = H\"%@\" and identifier \"%@\"",
            certificatePin, certificatePin, identifier];
    }
    if (team.length != 10 ||
        [team rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:
            @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] invertedSet]].location != NSNotFound) return nil;
    return [NSString stringWithFormat:
        @"anchor apple generic and identifier \"%@\" and certificate leaf[subject.OU] = \"%@\" "
         "and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
         "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists", identifier, team];
}

NSString *FCSigningRequirement(NSString *identifier) {
    if (![@FC_PINNED_CERTIFICATE_SHA1 isEqualToString:@"BBA7F8529FD271B9848EC03A2CE3F4780F585556"] ||
        @FC_PRODUCTION_TEAM_ID.length) return nil;
    return FCRequirementForPolicy(identifier, @FC_PINNED_CERTIFICATE_SHA1, @FC_PRODUCTION_TEAM_ID);
}

// Daemon and Core: hardened runtime, real signature, and none of the entitlements that weaken it.
BOOL FCCodeEntitlementsAllowed(NSDictionary *entitlements, uint32_t flags) {
    if (entitlements && ![entitlements isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in @[@"com.apple.security.get-task-allow", @"com.apple.security.cs.disable-library-validation",
            @"com.apple.security.cs.allow-dyld-environment-variables", @"com.apple.security.cs.allow-unsigned-executable-memory",
            @"com.apple.security.cs.disable-executable-page-protection"])
        if (entitlements[key]) return NO;
    return (flags & kSecCodeSignatureRuntime) && !(flags & kSecCodeSignatureAdhoc);
}

BOOL FCGUIEntitlementsAllowed(NSDictionary *entitlements, uint32_t flags) {
    NSDictionary *expected = @{@"com.apple.security.files.user-selected.read-write": @YES,
        @"com.apple.security.personal-information.location": @YES,
        @"com.apple.security.cs.disable-library-validation": @YES};
    if (!(flags & kSecCodeSignatureRuntime) || (flags & kSecCodeSignatureAdhoc) ||
        ![entitlements isKindOfClass:NSDictionary.class] || ![entitlements isEqualToDictionary:expected]) return NO;
    for (id value in entitlements.allValues)
        if (CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
    return YES;
}

BOOL FCValidGUIHash(NSData *hash) {
    return [hash isKindOfClass:NSData.class] && hash.length == 20;
}

NSString *FCGUIRequirement(void) {
    return FCSigningRequirement(FCClientIdentifier);
}

static NSDictionary *FCSigningInformation(SecStaticCodeRef code) {
    CFDictionaryRef information = NULL;
    if (SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information)) return nil;
    return CFBridgingRelease(information);
}

static BOOL FCExecutableMatches(NSDictionary *info, NSString *expected) {
    NSURL *executable = info[(__bridge NSString *)kSecCodeInfoMainExecutable];
    char canonical[PATH_MAX];
    return expected.length && [executable isKindOfClass:NSURL.class] && [executable.path isEqualToString:expected] &&
        realpath(executable.path.fileSystemRepresentation, canonical) && [@(canonical) isEqualToString:expected];
}

static BOOL FCCheckGUIStaticAt(SecStaticCodeRef code, NSString *bundle) {
    NSString *text = FCGUIRequirement();
    SecRequirementRef requirement = NULL;
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    // The app seal covers the nested daemon, Core, the LaunchDaemons plist and the compatibility contract.
    BOOL valid = SecStaticCodeCheckValidity(code,
        kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, requirement) == errSecSuccess;
    CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    return valid && FCExecutableMatches(info, [bundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"]) &&
        FCGUILibraryPolicy(bundle, info[(__bridge NSString *)kSecCodeInfoUnique]) &&
        FCBundleCompatibilityValid(FCReadCompatibility(bundle)) && FCGUIEntitlementsAllowed(
        info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
        [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
}

static BOOL FCCheckGUIStatic(SecStaticCodeRef code) {
    return FCCheckGUIStaticAt(code, FCGUIBundle);
}

NSString *FCGUIBundleTrust(NSString *bundle) {
    if (@available(macOS 14.0, *)) {
        if (![bundle isEqualToString:FCGUIBundle]) return @"moveRequired";
        SecStaticCodeRef code = NULL;
        if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:bundle], 0, &code))
            return @"signingRequired";
        BOOL valid = FCCheckGUIStatic(code);
        CFRelease(code);
        return valid ? @"trusted" : @"signingRequired";
    }
    return @"unsupported";
}

NSString *FCGUICandidateTrust(NSString *bundle) {
    char canonical[PATH_MAX];
    if (!realpath(bundle.fileSystemRepresentation, canonical) || ![@(canonical) isEqualToString:bundle])
        return @"moveRequired";
    SecStaticCodeRef code = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:bundle], 0, &code))
        return @"signingRequired";
    BOOL valid = FCCheckGUIStaticAt(code, bundle);
    CFRelease(code);
    return valid ? @"trusted" : @"signingRequired";
}

// The pinned requirement and code policy for the daemon and Core. A test may substitute both (for an ad hoc signed
// peer it can build itself) to run the rest of the validation, Security and kernel included, on real processes.
#ifndef FCPinnedRequirement
#define FCPinnedRequirement FCSigningRequirement
#else
NSString *FCPinnedRequirement(NSString *identifier);
#endif
#ifndef FCPinnedCodePolicy
#define FCPinnedCodePolicy FCCodeEntitlementsAllowed
#else
BOOL FCPinnedCodePolicy(NSDictionary *entitlements, uint32_t flags);
#endif

static BOOL FCCheckCode(SecStaticCodeRef code, NSString *identifier, NSData **hash) {
    NSString *text = FCPinnedRequirement(identifier);
    if (!text) return NO;
    SecRequirementRef requirement = NULL;
    if (SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    BOOL valid = SecStaticCodeCheckValidity(code, kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode,
                                            requirement) == errSecSuccess;
    CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    NSData *unique = info[(__bridge NSString *)kSecCodeInfoUnique];
    valid = valid && FCValidGUIHash(unique) && FCPinnedCodePolicy(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
        [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
    if (valid && hash) *hash = unique;
    return valid;
}

NSData *FCStaticCodeHash(NSString *path, NSString *identifier) {
    SecStaticCodeRef code = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &code)) return nil;
    NSData *hash = nil;
    BOOL valid = FCCheckCode(code, identifier, &hash);
    CFRelease(code);
    return valid ? hash : nil;
}

BOOL FCCheckStatic(NSString *path, NSString *identifier) {
    return FCStaticCodeHash(path, identifier) != nil;
}

NSData *FCBundledCoreHash(void) {
    return FCStaticCodeHash(FCInstalledExecutable(FCCoreIdentifier), FCCoreIdentifier);
}

int csops_audittoken(pid_t pid, unsigned int ops, void *useraddr, size_t usersize, audit_token_t *token);
#ifndef FCCodeOps
#define FCCodeOps csops_audittoken
#else
int FCCodeOps(pid_t pid, unsigned int ops, void *useraddr, size_t usersize, audit_token_t *token);
#endif

enum { FCCodeOpsStatus = 0, FCCodeOpsCDHash = 5 };
static const uint32_t FCCoreRequiredStatus = 0x1 | 0x100 | 0x200 | 0x10000; // VALID, HARD, KILL, RUNTIME
static const uint32_t FCCoreDebugged = 0x10000000;

NSString *FCCoreGuestCheck(NSData *auditToken, pid_t pid, NSData *expectedHash) {
    if (![auditToken isKindOfClass:NSData.class] || auditToken.length != sizeof(audit_token_t)) return @"failed:token";
    audit_token_t token;
    memcpy(&token, auditToken.bytes, sizeof(token));
    // val[5] is the pid (audit_token_to_pid, without linking libbsm).
    if (pid <= 0 || (pid_t)token.val[5] != pid) return @"failed:pid";
    if (!FCValidGUIHash(expectedHash)) return @"failed:bundled";
    uint32_t status = 0;
    if (FCCodeOps(pid, FCCodeOpsStatus, &status, sizeof(status), &token))
        return [NSString stringWithFormat:@"failed:status-read errno=%d", errno];
    if ((status & FCCoreRequiredStatus) != FCCoreRequiredStatus || (status & FCCoreDebugged))
        return [NSString stringWithFormat:@"failed:status 0x%x", status];
    uint8_t hash[20] = {0};
    if (FCCodeOps(pid, FCCodeOpsCDHash, hash, sizeof(hash), &token))
        return [NSString stringWithFormat:@"failed:cdhash-read errno=%d", errno];
    if (![[NSData dataWithBytes:hash length:sizeof(hash)] isEqualToData:expectedHash]) return @"failed:cdhash";
    return @"verified";
}

#ifndef FCProcPath
#define FCProcPath proc_pidpath
#else
int FCProcPath(int pid, void *buffer, uint32_t size);
#endif

// CS_ADHOC, CS_GET_TASK_ALLOW, CS_DEBUGGED (kern/cs_blobs.h).
static const uint32_t FCHelperForbiddenStatus = 0x2 | 0x4 | 0x10000000;

// The daemon behind a reply, from the kernel alone. It runs as the launcher's copy inside a root 0700 directory:
// Security's dynamic validation (SecCodeCheckValidity, SecCodeCopySigningInformation) opens that file and fails
// with EACCES for the app, so the running code is identified by what the kernel enforces for it. Every read goes
// through the audit token or is bracketed by two of them: csops_audittoken fails once the token's pid no longer
// names the same process lifetime (pid version, which also changes on exec), so the path read by pid in between
// belongs to the process the token names.
NSString *FCHelperGuestCheck(const audit_token_t *token, NSString *expectedPath, NSData **runningHash) {
    if (runningHash) *runningHash = nil;
    if (!token || !expectedPath.length) return @"failed:token";
    audit_token_t copy = *token;
    pid_t pid = (pid_t)copy.val[5];
    if (pid <= 0) return @"failed:token";
    uint32_t status = 0;
    if (FCCodeOps(pid, FCCodeOpsStatus, &status, sizeof(status), &copy))
        return [NSString stringWithFormat:@"failed:status-read errno=%d", errno];
    if ((status & FCCoreRequiredStatus) != FCCoreRequiredStatus || (status & FCHelperForbiddenStatus))
        return [NSString stringWithFormat:@"failed:status 0x%x", status];
    uint8_t hash[20] = {0};
    if (FCCodeOps(pid, FCCodeOpsCDHash, hash, sizeof(hash), &copy))
        return [NSString stringWithFormat:@"failed:cdhash-read errno=%d", errno];
    char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
    int length = FCProcPath(pid, path, sizeof(path));
    if (length <= 0 || length >= (int)sizeof(path)) return [NSString stringWithFormat:@"failed:path-read errno=%d", errno];
    path[length] = 0;
    uint32_t after = 0;
    if (FCCodeOps(pid, FCCodeOpsStatus, &after, sizeof(after), &copy))
        return [NSString stringWithFormat:@"failed:pid-reused errno=%d", errno];
    if ((after & FCCoreRequiredStatus) != FCCoreRequiredStatus || (after & FCHelperForbiddenStatus))
        return [NSString stringWithFormat:@"failed:status 0x%x", after];
    // Exact: the kernel's path of the running image. The path itself is not reported (it may name a user folder).
    NSString *running = [[NSString alloc] initWithBytes:path length:(NSUInteger)length encoding:NSUTF8StringEncoding];
    if (![running isEqualToString:expectedPath]) return @"failed:path";
    if (runningHash) *runningHash = [NSData dataWithBytes:hash length:sizeof(hash)];
    return @"verified";
}

int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#ifndef FCPidCodeOps
#define FCPidCodeOps csops
#else
int FCPidCodeOps(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#endif
enum { FCCodeOpsIdentity = 11 };

// The kernel's identifier only selects candidates; the pinned requirement decides. The identity blob is an
// 8-byte header followed by the NUL-terminated identifier.
FCCoreMatch FCRunningFlashCore(pid_t pid, NSString **reason) {
    char identity[8 + 128] = {0};
    if (FCPidCodeOps(pid, FCCodeOpsIdentity, identity, sizeof(identity) - 1)) {
        if (errno == ESRCH) return FCCoreMatchGone;
        if (errno == ENOENT || errno == ERANGE || errno == EINVAL) return FCCoreMatchOther;
        if (reason) *reason = [NSString stringWithFormat:@"identity errno=%d", errno];
        return FCCoreMatchUnknown;
    }
    if (strcmp(identity + 8, FCCoreIdentifier.UTF8String)) return FCCoreMatchOther;
    NSString *text = FCSigningRequirement(FCCoreIdentifier);
    SecRequirementRef requirement = NULL;
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) {
        if (reason) *reason = @"requirement unavailable";
        return FCCoreMatchUnknown;
    }
    SecCodeRef code = NULL;
    OSStatus status = SecCodeCopyGuestWithAttributes(NULL,
        (__bridge CFDictionaryRef)@{(__bridge NSString *)kSecGuestAttributePid: @(pid)}, kSecCSDefaultFlags, &code);
    if (!status) status = SecCodeCheckValidity(code, kSecCSDefaultFlags, requirement);
    if (code) CFRelease(code);
    CFRelease(requirement);
    if (!status) return FCCoreMatchFlash;
    if (status == errSecCSReqFailed) return FCCoreMatchOther;
    if (status == errSecCSNoSuchCode) return FCCoreMatchGone;
    if (reason) *reason = [NSString stringWithFormat:@"signature check OSStatus %d", (int)status];
    return FCCoreMatchUnknown;
}

FCRunningHashVerdict FCCompareRunningHash(NSData *runningHash, NSData *diskHash) {
    if (!FCValidGUIHash(runningHash) || !FCValidGUIHash(diskHash)) return FCRunningHashInvalid;
    return [runningHash isEqualToData:diskHash] ? FCRunningHashCurrent : FCRunningHashStale;
}

#ifndef FCMessageAuditToken
void xpc_dictionary_get_audit_token(xpc_object_t message, audit_token_t *token);
#define FCMessageAuditToken xpc_dictionary_get_audit_token
#else
void FCMessageAuditToken(xpc_object_t message, audit_token_t *token);
#endif

// FCHelperGuestCheck steps that failed to read from the kernel, as opposed to reads whose answer was refused.
static BOOL FCKernelReadFailed(NSString *step) {
    for (NSString *prefix in @[@"failed:status-read ", @"failed:cdhash-read ", @"failed:path-read ", @"failed:pid-reused "])
        if ([step hasPrefix:prefix]) return YES;
    return NO;
}

@interface FCMessageValidator ()
@property BOOL runningCodeStale;
@property BOOL transientFailure;
@property NSString *failure;
@property NSString *identifier;
@property NSString *executable;
@property NSString *sealedExecutable;
@property NSData *sealedHash;
@end

// Validates replies from the daemon: pinned identity, exact bundled path, policy flags, and that the
// running code is the code currently on disk (checked once per connection, then pinned by cdhash).
@implementation FCMessageValidator
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable {
    return [self initWithIdentifier:identifier executable:executable sealedExecutable:executable];
}
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable
    sealedExecutable:(NSString *)sealedExecutable {
    if ((self = [super init])) { _identifier = identifier; _executable = executable; _sealedExecutable = sealedExecutable; }
    return self;
}
- (BOOL)fail:(NSString *)failure {
    self.failure = failure;
    return NO;
}
- (BOOL)check:(xpc_object_t)message {
    self.runningCodeStale = NO;
    self.transientFailure = NO;
    self.failure = nil;
    if ([self.identifier isEqualToString:FCClientIdentifier]) return [self fail:@"identifier"];
    if (![self.executable isEqualToString:self.sealedExecutable]) return [self checkCopy:message];
    SecCodeRef code = NULL;
    OSStatus status = SecCodeCreateWithXPCMessage(message, 0, &code);
    if (status) return [self fail:[NSString stringWithFormat:@"SecCodeCreateWithXPCMessage OSStatus %d", (int)status]];
    NSString *text = FCPinnedRequirement(self.identifier);
    SecRequirementRef requirement = NULL;
    BOOL valid = text && SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
    if (!valid) self.failure = @"requirement";
    if (valid) {
        status = SecCodeCheckValidity(code, kSecCSStrictValidate, requirement);
        valid = status == errSecSuccess;
        if (!valid) self.failure = [NSString stringWithFormat:@"SecCodeCheckValidity OSStatus %d", (int)status];
    }
    if (requirement) CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
    if (valid && !info) self.failure = @"SecCodeCopySigningInformation";
    valid = valid && FCExecutableMatches(info, self.executable) && FCValidGUIHash(runningHash) &&
        FCPinnedCodePolicy(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
            [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
    if (!valid && !self.failure) self.failure = @"path, cdhash or code flags";
    if (valid && !self.sealedHash) {
        FCRunningHashVerdict verdict = FCCompareRunningHash(runningHash,
            FCStaticCodeHash(self.sealedExecutable, self.identifier));
        valid = verdict == FCRunningHashCurrent;
        self.runningCodeStale = verdict == FCRunningHashStale;
        if (valid) self.sealedHash = runningHash;
        else self.failure = self.runningCodeStale ? @"cdhash differs from the bundled helper" : @"bundled helper";
    } else if (valid) {
        valid = [self.sealedHash isEqualToData:runningHash];
        if (!valid) self.failure = @"cdhash differs from the connection's";
    }
    CFRelease(code);
    return valid;
}
// The daemon as the launcher's root-only copy (executable != sealedExecutable): the app cannot read that file, so
// nothing here asks Security about the running code. Identity comes from the bundled helper, which must validate
// statically against the pinned requirement (FCStaticCodeHash: certificate, identifier, strict seal, entitlements,
// hardened runtime, not ad hoc) and whose cdhash the running process must have, as the kernel reports it for the
// sender's audit token. The connection's peer requirement (pinned certificate and identifier) was also enforced by
// XPC for this message.
- (BOOL)checkCopy:(xpc_object_t)message {
    if (!FCPinnedRequirement(self.identifier)) return [self fail:@"requirement"];
    audit_token_t token;
    memset(&token, 0, sizeof(token));
    FCMessageAuditToken(message, &token);
    NSData *runningHash = nil;
    NSString *kernel = FCHelperGuestCheck(&token, self.executable, &runningHash);
    if (![kernel isEqualToString:@"verified"]) {
        // A read the kernel could not answer (the process is gone or its pid names another lifetime) says nothing
        // about the code; a wrong status, path or cdhash does, and stays a refusal of the reply's identity.
        self.transientFailure = FCKernelReadFailed(kernel);
        return [self fail:kernel];
    }
    if (self.sealedHash) {
        if ([self.sealedHash isEqualToData:runningHash]) return YES;
        return [self fail:@"failed:cdhash differs from the connection's"];
    }
    NSData *sealedHash = FCStaticCodeHash(self.sealedExecutable, self.identifier);
    if (!sealedHash) return [self fail:@"failed:bundled helper signature"];
    FCRunningHashVerdict verdict = FCCompareRunningHash(runningHash, sealedHash);
    if (verdict == FCRunningHashCurrent) { self.sealedHash = runningHash; return YES; }
    self.runningCodeStale = verdict == FCRunningHashStale;
    return [self fail:[NSString stringWithFormat:@"failed:cdhash running=%@ bundled=%@",
        FCHexString(runningHash), FCHexString(sealedHash)]];
}
@end

#ifndef FCBundleStat
#define FCBundleStat stat
#else
int FCBundleStat(const char *path, struct stat *state);
#endif

// What a replaced or modified app changes: the bundle directory and the entries that carry or seal its code
// (identity, inode, size, modification and status-change times, with nanoseconds). An update moves a new bundle in
// (new inode); an in-place write changes the file's or its directory's times. Any difference, or any entry that
// cannot be read, sends the next message through the full validation again. Identity only, never trust.
static NSData *FCGUIBundleFingerprint(void) {
    NSMutableData *fingerprint = [NSMutableData data];
    for (NSString *relative in @[@"", @"Contents", @"Contents/Info.plist", @"Contents/MacOS", @"Contents/MacOS/Flash",
            @"Contents/_CodeSignature", @"Contents/_CodeSignature/CodeResources", @"Contents/Frameworks",
            @"Contents/Resources", @"Contents/Library", @"Contents/Library/HelperTools",
            @"Contents/Library/LaunchDaemons", FCHelperRelativePath, FCLauncherRelativePath, FCCoreRelativePath,
            FCDaemonPlistRelativePath]) {
        NSString *path = relative.length ? [FCGUIBundle stringByAppendingPathComponent:relative] : FCGUIBundle;
        struct stat state;
        if (FCBundleStat(path.fileSystemRepresentation, &state)) return nil;
        int64_t fields[] = {(int64_t)state.st_dev, (int64_t)state.st_ino, (int64_t)state.st_mode, (int64_t)state.st_size,
            (int64_t)state.st_mtimespec.tv_sec, (int64_t)state.st_mtimespec.tv_nsec,
            (int64_t)state.st_ctimespec.tv_sec, (int64_t)state.st_ctimespec.tv_nsec};
        [fingerprint appendBytes:fields length:sizeof(fields)];
    }
    return fingerprint;
}

@interface FCGUIMessageValidator ()
@property NSString *failure;
@property pid_t verifiedPid;
@property uint32_t verifiedPidVersion;
@property NSData *verifiedHash;
@property NSData *verifiedBundle;
@end

// Validates requests from the app on one connection (Supervisor makes one per connection). The first message,
// and the first after the app bundle changed on disk, gets the full validation: the running app against the
// pinned requirement (strict), its exact executable path, entitlements and flags, then the whole bundle statically
// (strict, all architectures, nested code: daemon, launcher, Core, plist, contract) with the running cdhash equal
// to the bundle's. Every later message must come from that same process lifetime (audit token pid and pid
// version, which also change on exec) whose code the kernel still reports valid, hardened and not debugged, with
// the same cdhash. The cdhash binds certificate, identifier, entitlements and flags, so nothing pinned is dropped;
// XPC also enforces the pinned requirement for every message on the connection.
@implementation FCGUIMessageValidator
- (BOOL)fail:(NSString *)failure {
    self.failure = failure;
    self.verifiedHash = nil;
    return NO;
}
- (BOOL)check:(xpc_object_t)message {
    self.failure = nil;
    if (@available(macOS 14.0, *)) {
        NSString *text = FCGUIRequirement();
        if (!text) return [self fail:@"requirement"];
        audit_token_t token;
        memset(&token, 0, sizeof(token));
        FCMessageAuditToken(message, &token);
        pid_t pid = (pid_t)token.val[5];
        if (pid <= 0) return [self fail:@"token"];
        NSData *bundle = FCGUIBundleFingerprint();
        if (!bundle) return [self fail:@"bundle-stat"];
        if (self.verifiedHash) {
            if (pid != self.verifiedPid || token.val[7] != self.verifiedPidVersion) return [self fail:@"sender changed"];
            if ([bundle isEqualToData:self.verifiedBundle]) {
                NSString *kernel = [self kernelCheck:&token hash:self.verifiedHash];
                return kernel ? [self fail:kernel] : YES;
            }
        }
        NSString *full = [self fullCheck:message requirement:text token:&token];
        if (full) return [self fail:full];
        self.verifiedPid = pid;
        self.verifiedPidVersion = token.val[7];
        self.verifiedBundle = bundle;
        return YES;
    }
    return [self fail:@"unsupported"];
}
// The kernel's view of the sender, through its audit token: nil, or the failed step.
- (NSString *)kernelCheck:(audit_token_t *)token hash:(NSData *)expected {
    pid_t pid = (pid_t)token->val[5];
    uint32_t status = 0;
    if (FCCodeOps(pid, FCCodeOpsStatus, &status, sizeof(status), token))
        return [NSString stringWithFormat:@"status-read errno=%d", errno];
    if ((status & FCCoreRequiredStatus) != FCCoreRequiredStatus || (status & FCHelperForbiddenStatus))
        return [NSString stringWithFormat:@"status 0x%x", status];
    uint8_t hash[20] = {0};
    if (FCCodeOps(pid, FCCodeOpsCDHash, hash, sizeof(hash), token))
        return [NSString stringWithFormat:@"cdhash-read errno=%d", errno];
    if (!FCValidGUIHash(expected) || ![[NSData dataWithBytes:hash length:sizeof(hash)] isEqualToData:expected])
        return @"cdhash";
    return nil;
}
- (NSString *)fullCheck:(xpc_object_t)message requirement:(NSString *)text token:(audit_token_t *)token {
    self.verifiedHash = nil;
    SecCodeRef code = NULL;
    OSStatus status = SecCodeCreateWithXPCMessage(message, 0, &code);
    if (status) return [NSString stringWithFormat:@"SecCodeCreateWithXPCMessage OSStatus %d", (int)status];
    SecRequirementRef requirement = NULL;
    BOOL valid = SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
    NSString *failure = valid ? nil : @"requirement";
    if (valid) {
        status = SecCodeCheckValidity(code, kSecCSStrictValidate, requirement);
        valid = status == errSecSuccess;
        if (!valid) failure = [NSString stringWithFormat:@"SecCodeCheckValidity OSStatus %d", (int)status];
    }
    if (requirement) CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    CFRelease(code);
    NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
    valid = valid && FCExecutableMatches(info, FCInstalledExecutable(FCClientIdentifier)) && FCValidGUIHash(runningHash) &&
        FCGUIEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
            [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
    if (!valid) return failure ?: @"path, cdhash, entitlements or flags";
    SecStaticCodeRef diskCode = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:FCGUIBundle], 0, &diskCode))
        return @"bundle";
    valid = FCCheckGUIStatic(diskCode);
    NSDictionary *diskInfo = valid ? FCSigningInformation(diskCode) : nil;
    CFRelease(diskCode);
    NSData *diskHash = diskInfo[(__bridge NSString *)kSecCodeInfoUnique];
    if (!valid || !FCValidGUIHash(diskHash)) return @"bundle seal";
    if (![diskHash isEqualToData:runningHash]) return @"cdhash differs from the bundle";
    // The same process the kernel reports for this message, with the cdhash just validated.
    NSString *kernel = [self kernelCheck:token hash:runningHash];
    if (kernel) return kernel;
    self.verifiedHash = runningHash;
    return nil;
}
@end

static BOOL FCProtectedNode(NSString *path) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) || st.st_uid != 0 || (st.st_mode & 06022) ||
        (!S_ISDIR(st.st_mode) && !S_ISREG(st.st_mode)) ||
        (S_ISREG(st.st_mode) && st.st_nlink != 1)) return NO;
    return FCPathACLEmpty(path.fileSystemRepresentation, &st);
}

static BOOL FCProtectedFrameworkLink(NSString *path, NSString *bundle) {
    NSString *prefix = [[bundle stringByAppendingPathComponent:@"Contents/Frameworks"] stringByAppendingString:@"/"];
    if (![path hasPrefix:prefix]) return NO;
    NSString *relative = [path substringFromIndex:prefix.length];
    NSArray<NSString *> *parts = relative.pathComponents;
    if (parts.count < 2 || ![parts.firstObject hasSuffix:@".framework"]) return NO;
    NSString *framework = [prefix stringByAppendingPathComponent:parts.firstObject];
    NSString *entry = [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@"/"];
    NSString *target = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:path error:nil];
    NSString *binary = parts.firstObject.stringByDeletingPathExtension;
    BOOL permitted = [entry isEqualToString:@"Versions/Current"]
        ? target.pathComponents.count == 1 && ![target isEqualToString:@"."] && ![target isEqualToString:@".."]
        : ([@[@"Resources", @"Headers", @"Modules", binary] containsObject:entry] &&
           [target isEqualToString:[@"Versions/Current" stringByAppendingPathComponent:entry]]);
    if (!permitted || target.isAbsolutePath) return NO;
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) || !S_ISLNK(st.st_mode) || st.st_uid != 0) return NO;
    if (!FCPathACLEmpty(path.fileSystemRepresentation, &st)) return NO;
    char resolved[PATH_MAX];
    if (!realpath(path.fileSystemRepresentation, resolved)) return NO;
    NSString *canonical = @(resolved);
    if (![canonical hasPrefix:[framework stringByAppendingString:@"/"]]) return NO;
    while (![canonical isEqualToString:framework]) {
        if (!FCProtectedNode(canonical)) return NO;
        canonical = canonical.stringByDeletingLastPathComponent;
    }
    return FCProtectedNode(framework);
}

BOOL FCProtectedTree(NSString *path, BOOL recursive) {
    if (![path isAbsolutePath] || ![path isEqualToString:path.stringByStandardizingPath]) return NO;
    NSString *ancestor = path;
    while (YES) {
        if (!FCProtectedNode(ancestor)) return NO;
        if ([ancestor isEqualToString:@"/"]) break;
        ancestor = ancestor.stringByDeletingLastPathComponent;
    }
    if (!recursive) return YES;
    __block BOOL readable = YES;
    NSURL *root = [NSURL fileURLWithPath:path];
    NSDirectoryEnumerator *items = [[NSFileManager defaultManager]
        enumeratorAtURL:root includingPropertiesForKeys:nil options:0
        errorHandler:^BOOL(NSURL *url, NSError *error) { readable = NO; return NO; }];
    if (!items) return NO;
    for (NSURL *item in items) {
        if (!FCProtectedNode(item.path) && !FCProtectedFrameworkLink(item.path, path)) return NO;
    }
    if (!readable) return NO;
    return YES;
}

NSString *FCSHA256(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) return @"";
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    uint8_t buffer[65536];
    ssize_t count;
    while ((count = read(fd, buffer, sizeof(buffer))) > 0) CC_SHA256_Update(&context, buffer, (CC_LONG)count);
    close(fd);
    if (count < 0) return @"";
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    return FCHexString([NSData dataWithBytes:digest length:sizeof(digest)]);
}

NSString *FCHexString(NSData *data) {
    if (![data isKindOfClass:NSData.class]) return @"";
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length * 2];
    const uint8_t *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) [result appendFormat:@"%02x", bytes[i]];
    return result;
}

NSString *FCHelperBundleFromArguments(NSArray<NSString *> *arguments, NSString **reason) {
    NSString *problem = nil, *bundle = arguments.count == 3 ? arguments[2] : nil;
    char canonical[PATH_MAX];
    if (arguments.count < 3 || ![arguments containsObject:FCHelperBundleArgument])
        problem = @"missing --flash-bundle: the helper only runs as the copy started by FlashHelperLauncher";
    else if (arguments.count != 3 || ![arguments[1] isEqualToString:FCHelperBundleArgument])
        problem = @"unexpected arguments";
    else if (![arguments[0] isEqualToString:FCHelperCopyPath])
        problem = @"argv[0] is not the launcher's verified copy";
    else if (![bundle isEqualToString:FCGUIBundle])
        problem = @"--flash-bundle is not /Applications/Flash.app";
    else if (!realpath(bundle.fileSystemRepresentation, canonical) || ![@(canonical) isEqualToString:bundle])
        problem = @"--flash-bundle is not a canonical path";
    if (reason) *reason = problem;
    return problem ? nil : bundle;
}

// Mandatory before the daemon serves anything as root. Tampered code does not run:
//  1. the running process (SecCodeCopySelf) satisfies the pinned requirement for com.layoute.flash.helper;
//  2. it runs from the launcher's root-only copy, and the bundle the launcher named is /Applications/Flash.app
//     (canonical);
//  3. the copy on disk validates strictly against the same requirement and has the running cdhash;
//  4. the helper inside that bundle validates strictly and has the running cdhash too: what runs is exactly the
//     helper the sealed app carries (the launcher's own checks are not relied on);
//  5. the containing Flash.app validates strictly incl. nested code (pinned GUI identity, library
//     constraint, entitlements, compatibility contract), which seals the daemon plist, launcher and Core;
//  6. the bundled daemon plist has the exact expected schema, and helper and launcher are present.
NSString *FCHelperSelfCheck(NSString *runningExecutable, NSString *bundle) {
    if (@available(macOS 14.0, *)) {} else return @"unsupported";
    NSString *text = FCSigningRequirement(FCHelperIdentifier);
    if (!text) return @"requirement";
    if (![runningExecutable isEqualToString:FCHelperCopyPath]) return @"path";
    char canonical[PATH_MAX];
    if (![bundle isEqualToString:FCGUIBundle] || !realpath(bundle.fileSystemRepresentation, canonical) ||
        ![@(canonical) isEqualToString:bundle]) return @"bundlePath";
    SecCodeRef me = NULL;
    if (SecCodeCopySelf(kSecCSDefaultFlags, &me) || !me) return @"self";
    SecRequirementRef requirement = NULL;
    BOOL valid = SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
    valid = valid && SecCodeCheckValidity(me, kSecCSStrictValidate, requirement) == errSecSuccess;
    if (requirement) CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation((SecStaticCodeRef)me) : nil;
    CFRelease(me);
    NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
    if (!valid || !FCValidGUIHash(runningHash)) return @"self";
    if (!FCExecutableMatches(info, FCHelperCopyPath)) return @"path";
    if (!FCCodeEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
            [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue])) return @"entitlements";
    NSData *diskHash = FCStaticCodeHash(FCHelperCopyPath, FCHelperIdentifier);
    if (!diskHash) return @"disk";
    if (![diskHash isEqualToData:runningHash]) return @"replaced";
    NSData *bundledHash = FCStaticCodeHash([bundle stringByAppendingPathComponent:FCHelperRelativePath], FCHelperIdentifier);
    if (!bundledHash) return @"bundledHelper";
    if (![bundledHash isEqualToData:runningHash])
        return [NSString stringWithFormat:@"bundledHelperMismatch running=%@ bundled=%@",
            FCHexString(runningHash), FCHexString(bundledHash)];
    if (![FCGUIBundleTrust(bundle) isEqualToString:@"trusted"]) return @"bundle";
    if (!FCBundledDaemonPresent(bundle)) return @"plist";
    return @"ok";
}
