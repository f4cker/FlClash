#import "HelperTrust.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/acl.h>
#import <sys/stat.h>
#import <errno.h>
#import <fcntl.h>
#import <unistd.h>

#import "HelperIdentity.h"
#import "ProtectedPathPolicy.h"
#import "LibraryConstraintPolicy.h"
#import "HelperCompatibility.h"

NSString * const FCHelperLabel = @"com.layoute.flash.daemon";
NSString * const FCDaemonPlistName = @"com.layoute.flash.daemon.plist";
NSString * const FCClientIdentifier = @"com.layoute.flash";
NSString * const FCHelperIdentifier = @"com.layoute.flash.helper";
NSString * const FCCoreIdentifier = @"com.layoute.flash.core";
NSString * const FCGUIBundle = @"/Applications/Flash.app";
NSString * const FCDaemonPlistRelativePath = @"Contents/Library/LaunchDaemons/com.layoute.flash.daemon.plist";
NSString * const FCHelperRelativePath = @"Contents/Library/HelperTools/FlashHelper";
NSString * const FCCoreRelativePath = @"Contents/MacOS/FlClashCore";
NSString * const FCRuntimeDirectory = @"/Library/Application Support/com.layoute.flash.daemon";

NSString *FCInstalledExecutable(NSString *role) {
    if ([role isEqualToString:FCClientIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"];
    if ([role isEqualToString:FCHelperIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:FCHelperRelativePath];
    if ([role isEqualToString:FCCoreIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:FCCoreRelativePath];
    return @"";
}

NSDictionary *FCCanonicalDaemonPlist(void) {
    return @{@"Label": FCHelperLabel, @"BundleProgram": FCHelperRelativePath,
        @"MachServices": @{FCHelperLabel: @YES}, @"ProcessType": @"Interactive",
        @"AssociatedBundleIdentifiers": @[FCClientIdentifier]};
}

// Exact schema: no Program/ProgramArguments/EnvironmentVariables/KeepAlive/RunAtLoad or any other key.
BOOL FCDaemonPlistValid(id plist) {
    if (![plist isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *dictionary = plist;
    for (NSString *key in @[@"Label", @"BundleProgram", @"ProcessType"])
        if (![dictionary[key] isKindOfClass:NSString.class]) return NO;
    NSDictionary *services = dictionary[@"MachServices"];
    if (![services isKindOfClass:NSDictionary.class] || services.count != 1) return NO;
    id enabled = services[FCHelperLabel];
    if (!enabled || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID()) return NO;
    id association = dictionary[@"AssociatedBundleIdentifiers"];
    if (![association isKindOfClass:NSArray.class] || [association count] != 1 ||
        ![association[0] isKindOfClass:NSString.class]) return NO;
    return [dictionary isEqualToDictionary:FCCanonicalDaemonPlist()];
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
    return FCRegularCanonicalFile(plist) && FCRegularCanonicalFile(helper) &&
        FCDaemonPlistValid(FCLoadPlist(plist));
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

static BOOL FCCheckGUIStatic(SecStaticCodeRef code) {
    NSString *text = FCGUIRequirement();
    SecRequirementRef requirement = NULL;
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    // The app seal covers the nested daemon, Core, the LaunchDaemons plist and the compatibility contract.
    BOOL valid = SecStaticCodeCheckValidity(code,
        kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, requirement) == errSecSuccess;
    CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    return valid && FCExecutableMatches(info, FCInstalledExecutable(FCClientIdentifier)) &&
        FCGUILibraryPolicy(FCGUIBundle, info[(__bridge NSString *)kSecCodeInfoUnique]) &&
        FCBundleCompatibilityValid(FCReadCompatibility(FCGUIBundle)) && FCGUIEntitlementsAllowed(
        info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
        [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
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

@implementation FCGUIMessageValidator
- (BOOL)check:(xpc_object_t)message {
    if (@available(macOS 14.0, *)) {
        NSString *text = FCGUIRequirement();
        if (!text) return NO;
        SecCodeRef code = NULL;
        if (SecCodeCreateWithXPCMessage(message, 0, &code)) return NO;
        SecRequirementRef requirement = NULL;
        BOOL valid = SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
        valid = valid && SecCodeCheckValidity(code, kSecCSStrictValidate, requirement) == errSecSuccess;
        if (requirement) CFRelease(requirement);
        NSDictionary *info = valid ? FCSigningInformation(code) : nil;
        NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
        valid = valid && FCExecutableMatches(info, FCInstalledExecutable(FCClientIdentifier)) && FCValidGUIHash(runningHash) &&
            FCGUIEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
                [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
        SecStaticCodeRef diskCode = NULL;
        valid = valid && SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:FCGUIBundle],
            0, &diskCode) == errSecSuccess;
        if (valid) {
            valid = FCCheckGUIStatic(diskCode);
            NSDictionary *diskInfo = valid ? FCSigningInformation(diskCode) : nil;
            NSData *diskHash = diskInfo[(__bridge NSString *)kSecCodeInfoUnique];
            valid = valid && FCValidGUIHash(diskHash) && [diskHash isEqualToData:runningHash];
        }
        if (diskCode) CFRelease(diskCode);
        CFRelease(code);
        return valid;
    }
    return NO;
}
@end

static BOOL FCCheckCode(SecStaticCodeRef code, NSString *identifier, NSData **hash) {
    NSString *text = FCSigningRequirement(identifier);
    if (!text) return NO;
    SecRequirementRef requirement = NULL;
    if (SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    BOOL valid = SecStaticCodeCheckValidity(code, kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode,
                                            requirement) == errSecSuccess;
    CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    NSData *unique = info[(__bridge NSString *)kSecCodeInfoUnique];
    valid = valid && FCValidGUIHash(unique) && FCCodeEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
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

@interface FCMessageValidator ()
@property NSString *identifier;
@property NSString *executable;
@property NSData *sealedHash;
@end

// Validates replies from the daemon: pinned identity, exact bundled path, policy flags, and that the
// running code is the code currently on disk (checked once per connection, then pinned by cdhash).
@implementation FCMessageValidator
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable {
    if ((self = [super init])) { _identifier = identifier; _executable = executable; }
    return self;
}
- (BOOL)check:(xpc_object_t)message {
    if ([self.identifier isEqualToString:FCClientIdentifier]) return NO;
    SecCodeRef code = NULL;
    if (SecCodeCreateWithXPCMessage(message, 0, &code)) return NO;
    NSString *text = FCSigningRequirement(self.identifier);
    SecRequirementRef requirement = NULL;
    BOOL valid = text && SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
    valid = valid && SecCodeCheckValidity(code, kSecCSStrictValidate, requirement) == errSecSuccess;
    if (requirement) CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
    valid = valid && FCExecutableMatches(info, self.executable) && FCValidGUIHash(runningHash) &&
        FCCodeEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
            [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
    if (valid && !self.sealedHash) {
        NSData *diskHash = FCStaticCodeHash(self.executable, self.identifier);
        valid = diskHash && [diskHash isEqualToData:runningHash];
        if (valid) self.sealedHash = runningHash;
    } else if (valid) {
        valid = [self.sealedHash isEqualToData:runningHash];
    }
    CFRelease(code);
    return valid;
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

// Mandatory before the daemon serves anything as root. Tampered code does not run:
//  1. the running process (SecCodeCopySelf) satisfies the pinned requirement for com.layoute.flash.helper;
//  2. it runs from the exact bundled path inside /Applications/Flash.app;
//  3. the on-disk helper validates strictly against the same requirement and has the same cdhash;
//  4. the containing Flash.app validates strictly incl. nested code (pinned GUI identity, library
//     constraint, entitlements, compatibility contract), which seals the daemon plist and Core;
//  5. the bundled daemon plist has the exact expected schema.
NSString *FCHelperSelfCheck(NSString *runningExecutable) {
    if (@available(macOS 14.0, *)) {} else return @"unsupported";
    NSString *expected = FCInstalledExecutable(FCHelperIdentifier);
    NSString *text = FCSigningRequirement(FCHelperIdentifier);
    if (!text) return @"requirement";
    if (![runningExecutable isEqualToString:expected]) return @"path";
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
    if (!FCExecutableMatches(info, expected)) return @"path";
    if (!FCCodeEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
            [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue])) return @"entitlements";
    NSData *diskHash = FCStaticCodeHash(expected, FCHelperIdentifier);
    if (!diskHash) return @"disk";
    if (![diskHash isEqualToData:runningHash]) return @"replaced";
    if (![FCGUIBundleTrust(FCGUIBundle) isEqualToString:@"trusted"]) return @"bundle";
    if (!FCBundledDaemonPresent(FCGUIBundle)) return @"plist";
    return @"ok";
}
