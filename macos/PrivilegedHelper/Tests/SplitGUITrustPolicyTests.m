#import "../../Shared/HelperTrust.h"
#import "../../Shared/HelperIdentity.h"
#import <assert.h>

static xpc_object_t fixtureMessage;
static NSMutableDictionary *runningInfo;
static NSMutableDictionary *diskInfo;
static BOOL messageValid, runningValid, diskValid, canonicalValid;
static NSUInteger messageChecks, sealChecks;

static OSStatus FixtureMessage(xpc_object_t message, SecCSFlags flags, SecCodeRef *code) {
    messageChecks++;
    if (!messageValid) return errSecCSUnsigned;
    *code = (SecCodeRef)CFBridgingRetain(runningInfo);
    return errSecSuccess;
}
static OSStatus FixtureRunning(SecCodeRef code, SecCSFlags flags, SecRequirementRef requirement) {
    assert(flags == kSecCSStrictValidate && requirement);
    return runningValid ? errSecSuccess : errSecCSReqFailed;
}
static OSStatus FixtureInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef *info) {
    assert(flags == kSecCSSigningInformation);
    *info = CFRetain((CFDictionaryRef)code);
    return errSecSuccess;
}
static OSStatus FixtureDisk(CFURLRef path, SecCSFlags flags, SecStaticCodeRef *code) {
    assert([((__bridge NSURL *)path).path isEqualToString:FCGUIBundle]);
    *code = (SecStaticCodeRef)CFBridgingRetain(diskInfo);
    return errSecSuccess;
}
static OSStatus FixtureSeal(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef requirement) {
    sealChecks++;
    assert(flags == (kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode));
    assert(requirement);
    return diskValid ? errSecSuccess : errSecCSBadResource;
}
static char *FixtureRealpath(const char *path, char *resolved) {
    if (!canonicalValid) return NULL;
    strcpy(resolved, path);
    return resolved;
}

#define SecCodeCreateWithXPCMessage FixtureMessage
#define SecCodeCheckValidity FixtureRunning
#define SecCodeCopySigningInformation FixtureInformation
#define SecStaticCodeCreateWithPath FixtureDisk
#define SecStaticCodeCheckValidity FixtureSeal
#define realpath FixtureRealpath
#import "../../Shared/HelperTrust.m"

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
    messageValid = runningValid = diskValid = canonicalValid = YES;
    runningInfo = [@{(__bridge NSString *)kSecCodeInfoMainExecutable:
        [NSURL fileURLWithPath:FCInstalledExecutable(FCClientIdentifier)],
        (__bridge NSString *)kSecCodeInfoUnique: ApprovedHash(),
        (__bridge NSString *)kSecCodeInfoEntitlementsDict: GUIEntitlements(),
        (__bridge NSString *)kSecCodeInfoFlags: @(kSecCodeSignatureRuntime)} mutableCopy];
    diskInfo = runningInfo.mutableCopy;
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
    for (NSString *role in @[FCServiceIdentifier, FCHelperLabel, FCMaintenanceIdentifier, @"com.layoute.flash.core"])
        assert(!FCCodeEntitlementsAllowed(role, YES, allowed, kSecCodeSignatureRuntime));
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
        executable:FCInstalledExecutable(FCClientIdentifier) bundle:FCGUIBundle];
    assert(![legacy check:fixtureMessage]);
}

int main(void) {
    @autoreleasepool {
        fixtureMessage = xpc_dictionary_create(NULL, NULL, 0);
        TestEntitlements();
        assert([FCServiceIdentifier isEqualToString:@"com.layoute.flash.service"]);
        assert([FCGUIBundle isEqualToString:@"/Applications/Flash.app"]);
        assert([FCInstalledBundle isEqualToString:@"/Library/Application Support/Flash/Flash.app"]);
        assert([FCInstalledExecutable(FCClientIdentifier) hasPrefix:[FCGUIBundle stringByAppendingString:@"/"]]);
        assert([FCInstalledExecutable(FCHelperLabel) hasPrefix:[FCInstalledBundle stringByAppendingString:@"/"]]);
        assert([FCInstalledExecutable(FCMaintenanceIdentifier) hasPrefix:[FCInstalledBundle stringByAppendingString:@"/"]]);
        assert(!FCSplitGUIHashMatches(nil));
        assert(!FCSplitGUIHashMatches([NSMutableData dataWithLength:19]));
        assert(!FCSplitGUIHashMatches([NSMutableData dataWithLength:21]));
        Reset();
        assert([FCGUIBundleTrust(FCGUIBundle) isEqualToString:@"trusted"]);
        assert(![FCGUIBundleTrust(FCInstalledBundle) isEqualToString:@"trusted"]);
        BOOL pinned = [@FC_SPLIT_GUI_CDHASH.lowercaseString isEqualToString:@"000102030405060708090a0b0c0d0e0f10111213"];
        assert(FCSplitGUIHashMatches(ApprovedHash()) == pinned);
        assert((FCSplitGUIRequirement() != nil) == pinned);
        if (pinned) TestMessages();
        else {
            NSUInteger checks = messageChecks;
            assert(![[FCGUIMessageValidator new] check:fixtureMessage]);
            assert(messageChecks == checks);
        }
        puts("Split GUI trust fixtures passed; Security/process/filesystem validation mocked");
    }
}
