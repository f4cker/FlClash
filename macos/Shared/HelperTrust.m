#import "HelperTrust.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/acl.h>
#import <sys/stat.h>
#import <errno.h>

#import "HelperIdentity.h"
#import "ProtectedPathPolicy.h"

NSString * const FCHelperLabel = @"com.layoute.flash.helper";
NSString * const FCClientIdentifier = @"com.layoute.flash";
NSString * const FCServiceIdentifier = @"com.layoute.flash.service";
NSString * const FCGUIBundle = @"/Applications/Flash.app";
NSString * const FCMaintenanceIdentifier = @"com.layoute.flash.maintenance";
NSString * const FCInstalledBundle = @"/Library/Application Support/Flash/Flash.app";
NSString * const FCLegacyPlist = @"/Library/LaunchDaemons/com.layoute.flash.helper.plist";
NSString * const FCRuntimeDirectory = @"/Library/Application Support/Flash/run";
NSString * const FCLegacyRuntimeDirectory = @"/private/var/run/com.layoute.flash.helper";

BOOL FCLegacyRuntimeAbsent(void) {
    struct stat state;
    return lstat(FCLegacyRuntimeDirectory.fileSystemRepresentation, &state) < 0 && errno == ENOENT;
}

NSString *FCInstalledExecutable(NSString *role) {
    if ([role isEqualToString:FCClientIdentifier]) return [FCGUIBundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"];
    if ([role isEqualToString:FCHelperLabel]) return [FCInstalledBundle stringByAppendingPathComponent:@"Contents/Library/HelperTools/FlashHelper"];
    if ([role isEqualToString:FCMaintenanceIdentifier]) return [FCInstalledBundle stringByAppendingPathComponent:@"Contents/Library/HelperTools/FlashMaintenance"];
    return @"";
}

BOOL FCLegacyPlistTrusted(void) {
    if (!FCProtectedTree(FCLegacyPlist, NO)) return NO;
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:FCLegacyPlist];
    return [plist isEqual:@{@"Label": FCHelperLabel, @"Program": FCInstalledExecutable(FCHelperLabel),
        @"MachServices": @{FCHelperLabel: @YES}, @"ProcessType": @"Interactive"}];
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
    return FCRequirementForPolicy(identifier, @FC_PINNED_CERTIFICATE_SHA1, @FC_PRODUCTION_TEAM_ID);
}

BOOL FCCodeEntitlementsAllowed(NSString *identifier, BOOL protectedGUI, NSDictionary *entitlements, uint32_t flags) {
    BOOL guiException = protectedGUI && FC_MANAGED_CANDIDATE_ENABLED &&
        @FC_PINNED_CERTIFICATE_SHA1.length == 40 && [identifier isEqualToString:FCClientIdentifier];
    return (flags & kSecCodeSignatureRuntime) &&
        !(flags & kSecCodeSignatureAdhoc) &&
        ![entitlements[@"com.apple.security.get-task-allow"] boolValue] &&
        (guiException || ![entitlements[@"com.apple.security.cs.disable-library-validation"] boolValue]) &&
        ![entitlements[@"com.apple.security.cs.allow-dyld-environment-variables"] boolValue];
}

BOOL FCGUIEntitlementsAllowed(NSDictionary *entitlements, uint32_t flags) {
    NSDictionary *expected = @{@"com.apple.security.files.user-selected.read-write": @YES,
        @"com.apple.security.personal-information.location": @YES,
        @"com.apple.security.cs.disable-library-validation": @YES};
    if (!(flags & kSecCodeSignatureRuntime) || (flags & kSecCodeSignatureAdhoc) ||
        ![entitlements isEqualToDictionary:expected]) return NO;
    for (id value in entitlements.allValues)
        if (CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
    return YES;
}

BOOL FCSplitGUIHashMatches(NSData *hash) {
    NSString *approved = @FC_SPLIT_GUI_CDHASH;
    if (approved.length != 40 || ![hash isKindOfClass:NSData.class] || hash.length != 20 ||
        [approved rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:
            @"0123456789abcdefABCDEF"] invertedSet]].location != NSNotFound) return NO;
    const uint8_t *bytes = hash.bytes;
    NSMutableString *actual = [NSMutableString stringWithCapacity:40];
    for (NSUInteger i = 0; i < hash.length; i++) [actual appendFormat:@"%02x", bytes[i]];
    return [actual isEqualToString:approved.lowercaseString];
}

NSString *FCSplitGUIRequirement(void) {
    NSString *pin = @FC_SPLIT_GUI_CDHASH;
    NSString *certificate = @FC_PINNED_CERTIFICATE_SHA1;
    if (pin.length != 40 || certificate.length != 40 || @FC_PRODUCTION_TEAM_ID.length ||
        [pin rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:
            @"0123456789abcdefABCDEF"] invertedSet]].location != NSNotFound) return nil;
    NSString *identity = FCSigningRequirement(FCClientIdentifier);
    return identity ? [NSString stringWithFormat:@"(%@) and cdhash H\"%@\"", identity, pin] : nil;
}

static NSDictionary *FCSigningInformation(SecStaticCodeRef code) {
    CFDictionaryRef information = NULL;
    if (SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information)) return nil;
    return CFBridgingRelease(information);
}

static BOOL FCGUIExecutableMatches(NSDictionary *info) {
    NSURL *executable = info[(__bridge NSString *)kSecCodeInfoMainExecutable];
    NSString *expected = FCInstalledExecutable(FCClientIdentifier);
    char canonical[PATH_MAX];
    return [executable isKindOfClass:NSURL.class] && [executable.path isEqualToString:expected] &&
        realpath(executable.path.fileSystemRepresentation, canonical) && [@(canonical) isEqualToString:expected];
}

static BOOL FCCheckGUIStatic(SecStaticCodeRef code) {
    NSString *text = @FC_PINNED_CERTIFICATE_SHA1.length == 40 && !@FC_PRODUCTION_TEAM_ID.length
        ? FCSigningRequirement(FCClientIdentifier) : nil;
    SecRequirementRef requirement = NULL;
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    BOOL valid = SecStaticCodeCheckValidity(code,
        kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, requirement) == errSecSuccess;
    CFRelease(requirement);
    NSDictionary *info = valid ? FCSigningInformation(code) : nil;
    return valid && FCGUIExecutableMatches(info) && FCGUIEntitlementsAllowed(
        info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
        [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
}

NSString *FCGUIBundleTrust(NSString *bundle) {
    if (@available(macOS 14.0, *)) {
        if (![bundle isEqualToString:FCGUIBundle]) return @"protectedInstallationRequired";
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
        NSString *text = FCSplitGUIRequirement();
        if (!text) return NO;
        SecCodeRef code = NULL;
        if (SecCodeCreateWithXPCMessage(message, 0, &code)) return NO;
        SecRequirementRef requirement = NULL;
        BOOL valid = SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement) == errSecSuccess;
        valid = valid && SecCodeCheckValidity(code, kSecCSStrictValidate, requirement) == errSecSuccess;
        if (requirement) CFRelease(requirement);
        NSDictionary *info = valid ? FCSigningInformation(code) : nil;
        NSData *runningHash = info[(__bridge NSString *)kSecCodeInfoUnique];
        valid = valid && FCGUIExecutableMatches(info) && FCSplitGUIHashMatches(runningHash) &&
            FCGUIEntitlementsAllowed(info[(__bridge NSString *)kSecCodeInfoEntitlementsDict],
                [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue]);
        SecStaticCodeRef diskCode = NULL;
        valid = valid && SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:FCGUIBundle],
            0, &diskCode) == errSecSuccess;
        if (valid) {
            valid = FCCheckGUIStatic(diskCode);
            NSDictionary *diskInfo = valid ? FCSigningInformation(diskCode) : nil;
            NSData *diskHash = diskInfo[(__bridge NSString *)kSecCodeInfoUnique];
            valid = valid && FCSplitGUIHashMatches(diskHash) && [diskHash isEqualToData:runningHash];
        }
        if (diskCode) CFRelease(diskCode);
        CFRelease(code);
        return valid;
    }
    return NO;
}
@end

static BOOL FCCheckCode(SecStaticCodeRef code, NSString *identifier, BOOL protectedGUI) {
    NSString *text = FCSigningRequirement(identifier);
    if (!text) return NO;
    SecRequirementRef requirement = NULL;
    if (SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return NO;
    BOOL valid = SecStaticCodeCheckValidity(code, kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode,
                                            requirement) == errSecSuccess;
    CFRelease(requirement);
    CFDictionaryRef information = NULL;
    if (!valid || SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information)) return NO;
    NSDictionary *info = CFBridgingRelease(information);
    NSDictionary *entitlements = info[(__bridge NSString *)kSecCodeInfoEntitlementsDict];
    uint32_t flags = [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue];
    return FCCodeEntitlementsAllowed(identifier, protectedGUI, entitlements, flags);
}

@interface FCMessageValidator ()
@property NSString *identifier;
@property NSString *executable;
@property NSString *bundle;
@property BOOL sealed;
@end

@implementation FCMessageValidator
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable bundle:(NSString *)bundle {
    if ((self = [super init])) { _identifier = identifier; _executable = executable; _bundle = bundle; }
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
    CFDictionaryRef information = NULL;
    valid = valid && SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information) == errSecSuccess;
    NSDictionary *info = information ? CFBridgingRelease(information) : nil;
    NSURL *executable = info[(__bridge NSString *)kSecCodeInfoMainExecutable];
    NSDictionary *entitlements = info[(__bridge NSString *)kSecCodeInfoEntitlementsDict];
    uint32_t flags = [info[(__bridge NSString *)kSecCodeInfoFlags] unsignedIntValue];
    char canonical[PATH_MAX];
    valid = valid && executable && [executable.path isEqualToString:self.executable] &&
        realpath(executable.path.fileSystemRepresentation, canonical) && [@(canonical) isEqualToString:self.executable] &&
        FCCodeEntitlementsAllowed(self.identifier, self.bundle != nil, entitlements, flags);
    if (valid && !self.sealed) {
        SecStaticCodeRef diskCode = NULL;
        valid = FCProtectedTree(self.executable, NO) && (!self.bundle || FCProtectedTree(self.bundle, YES)) &&
            SecCodeCopyStaticCode(code, 0, &diskCode) == errSecSuccess;
        if (valid) valid = FCCheckCode(diskCode, self.identifier, self.bundle != nil);
        if (diskCode) CFRelease(diskCode);
        self.sealed = valid;
    }
    CFRelease(code);
    return valid;
}
@end

BOOL FCCheckMessage(xpc_object_t message, NSString *identifier) {
    return [[[FCMessageValidator alloc] initWithIdentifier:identifier executable:FCInstalledExecutable(identifier) bundle:nil] check:message];
}

BOOL FCCheckClientMessage(xpc_object_t message, NSString *expectedBundle) {
    if (![expectedBundle isEqualToString:FCGUIBundle]) return NO;
    return [[FCGUIMessageValidator new] check:message];
}

BOOL FCCheckStatic(NSString *path, NSString *identifier) {
    SecStaticCodeRef code = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &code)) return NO;
    BOOL gui = [identifier isEqualToString:FCClientIdentifier];
    BOOL valid = (!gui || FCProtectedTree(path, YES)) && FCCheckCode(code, identifier, gui);
    CFRelease(code);
    return valid;
}

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
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    [stream open];
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    uint8_t buffer[65536];
    NSInteger count;
    while ((count = [stream read:buffer maxLength:sizeof(buffer)]) > 0)
        CC_SHA256_Update(&context, buffer, (CC_LONG)count);
    [stream close];
    if (count < 0) return @"";
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *result = [NSMutableString string];
    for (size_t i = 0; i < sizeof(digest); i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}

NSString *FCPayloadTrust(NSString *bundle) {
    NSString *incoming = [FCInstalledBundle.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".incoming/Flash.app"];
    NSString *retired = [FCInstalledBundle.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".retired.app"];
    if (![bundle isEqualToString:FCInstalledBundle] && ![bundle isEqualToString:incoming] && ![bundle isEqualToString:retired]) return @"protectedInstallationRequired";
    if (@FC_PINNED_CERTIFICATE_SHA1.length && !FC_MANAGED_CANDIDATE_ENABLED) return @"signingRequired";
    if (!FCCheckStatic(bundle, FCServiceIdentifier)) return @"signingRequired";
    if (!FCProtectedTree(bundle, YES)) return @"protectedInstallationRequired";
    if (!FCCheckStatic([bundle stringByAppendingPathComponent:@"Contents/Library/HelperTools/FlashHelper"],
                       FCHelperLabel)) return @"signingRequired";
    if (!FCCheckStatic([bundle stringByAppendingPathComponent:@"Contents/MacOS/FlClashCore"],
                       @"com.layoute.flash.core")) return @"signingRequired";
    if (!FCCheckStatic([bundle stringByAppendingPathComponent:@"Contents/Library/HelperTools/FlashMaintenance"], FCMaintenanceIdentifier)) return @"signingRequired";
    return @"trusted";
}

NSString *FCBundleTrust(NSString *bundle) {
    return [bundle isEqualToString:FCInstalledBundle] ? FCPayloadTrust(bundle) : @"protectedInstallationRequired";
}
