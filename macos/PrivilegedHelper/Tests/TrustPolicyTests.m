#import "../../Shared/HelperTrust.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSString *pin = @"0123456789abcdef0123456789abcdef01234567";
        assert(FCSigningRequirement(FCClientIdentifier) == nil);
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
        puts("12 trust-policy assertions passed; no services or processes used");
    }
}
