#import "../../Shared/HelperTrust.h"
#import "../../Shared/HelperIdentity.h"
#include <assert.h>

#ifndef FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED
#define FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED 0
#endif

extern BOOL FCCodeEntitlementsAllowed(NSString *identifier, BOOL protectedGUI, NSDictionary *entitlements, uint32_t flags);

static void testEntitlements(void) {
    NSArray<NSString *> *roles = @[FCClientIdentifier, FCHelperLabel, FCMaintenanceIdentifier, @"com.layoute.flash.core"];
    for (NSString *role in roles) {
        for (NSNumber *protected in @[@NO, @YES]) {
            for (NSNumber *disableValidation in @[@NO, @YES]) {
                NSDictionary *entitlements = @{@"com.apple.security.cs.disable-library-validation": disableValidation};
                BOOL exception = FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED && protected.boolValue &&
                    [role isEqualToString:FCClientIdentifier];
                BOOL allowed = !disableValidation.boolValue || exception;
                assert(FCCodeEntitlementsAllowed(role, protected.boolValue, entitlements, kSecCodeSignatureRuntime) == allowed);
                assert(!FCCodeEntitlementsAllowed(role, protected.boolValue, entitlements, 0));
                assert(!FCCodeEntitlementsAllowed(role, protected.boolValue, entitlements,
                    kSecCodeSignatureRuntime | kSecCodeSignatureAdhoc));
                for (NSString *forbidden in @[@"com.apple.security.get-task-allow",
                                               @"com.apple.security.cs.allow-dyld-environment-variables"]) {
                    NSMutableDictionary *denied = entitlements.mutableCopy;
                    denied[forbidden] = @YES;
                    assert(!FCCodeEntitlementsAllowed(role, protected.boolValue, denied, kSecCodeSignatureRuntime));
                }
            }
        }
    }
    NSString *fixture = NSProcessInfo.processInfo.arguments.firstObject.stringByStandardizingPath;
    assert(!FCProtectedTree(fixture, NO));
    for (NSString *role in roles) assert(!FCCheckStatic(fixture, role));
    assert(!FCProtectedTree(@"relative/Flash.app", YES));
    assert([FCPayloadTrust(@"/unqualified/Flash.app") isEqualToString:@"protectedInstallationRequired"]);
    assert([FCBundleTrust(@"/unqualified/Flash.app") isEqualToString:@"protectedInstallationRequired"]);
#if !FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED
    assert([FCPayloadTrust(FCInstalledBundle) isEqualToString:@"signingRequired"]);
#endif
}

int main(void) {
    @autoreleasepool {
        NSString *pin = @"0123456789abcdef0123456789abcdef01234567";
        assert([@FC_PINNED_CERTIFICATE_SHA1 isEqualToString:@"BBA7F8529FD271B9848EC03A2CE3F4780F585556"]);
        assert(@FC_PRODUCTION_TEAM_ID.length == 0);
        assert(FC_MANAGED_CANDIDATE_ENABLED == FC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED);
        testEntitlements();
        NSArray<NSString *> *roles = @[FCClientIdentifier, FCHelperLabel, FCMaintenanceIdentifier];
        for (NSString *role in roles) {
            NSString *production = FCSigningRequirement(role);
            NSString *expected = [NSString stringWithFormat:
                @"anchor H\"%@\" and certificate leaf = H\"%@\" and identifier \"%@\"",
                @FC_PINNED_CERTIFICATE_SHA1, @FC_PINNED_CERTIFICATE_SHA1, role];
            assert([production isEqualToString:expected]);
            SecRequirementRef parsed = NULL;
            assert(SecRequirementCreateWithString((__bridge CFStringRef)production, 0, &parsed) == errSecSuccess);
            CFRelease(parsed);
        }
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
