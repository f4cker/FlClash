#import "../../Shared/HelperTrust.h"
#import "../../Shared/HelperIdentity.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSString *pin = @"0123456789abcdef0123456789abcdef01234567";
        assert([@FC_PINNED_CERTIFICATE_SHA1 isEqualToString:@"BBA7F8529FD271B9848EC03A2CE3F4780F585556"]);
        assert(@FC_PRODUCTION_TEAM_ID.length == 0);
        assert(FC_MANAGED_GUI_LOADS_VERIFIED == 0);
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
        puts("Trust-policy assertions passed for all fixed roles; GUI load gate remains false; no services or processes used");
    }
}
