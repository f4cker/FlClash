#pragma once
#import <Foundation/Foundation.h>

// One sealed contract in Flash.app/Contents/Info.plist (key FlashHelperCompatibility) binds the GUI,
// the bundled daemon and the bundled Core. CallerPolicy 3 = SMAppService daemon inside the app bundle.
#define FC_CALLER_POLICY 3
#define FC_SERVICE_API 1
#define FC_CORE_API 1

static inline BOOL FCCompatibilityVersion(id value, NSInteger expected) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() &&
        CFNumberIsFloatType((__bridge CFNumberRef)value) == false && [value longLongValue] == expected;
}

static inline BOOL FCCoreHashValid(id hash) {
    return [hash isKindOfClass:NSString.class] && [hash length] == 64 &&
        [hash rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
}

static inline BOOL FCBundleCompatibilityValid(id contract) {
    if (![contract isKindOfClass:NSDictionary.class] || [contract count] != 6 ||
        !FCCompatibilityVersion(contract[@"CallerPolicy"], FC_CALLER_POLICY) ||
        !FCCompatibilityVersion(contract[@"ServiceAPI"], FC_SERVICE_API) ||
        !FCCompatibilityVersion(contract[@"CoreAPI"], FC_CORE_API) || !FCCoreHashValid(contract[@"CoreSHA256"])) return NO;
    for (NSString *key in @[@"CoreVersion", @"CoreRevision"]) {
        id value = contract[key];
        if (![value isKindOfClass:NSString.class] || ![value length] || [value length] > 128) return NO;
    }
    return YES;
}

// The daemon reports the contract it validated; the GUI accepts it only when it equals its own sealed copy.
static inline BOOL FCCompatibilityHelloMatches(id contract, id reported) {
    if (!FCBundleCompatibilityValid(contract) || !FCBundleCompatibilityValid(reported)) return NO;
    return [contract isEqualToDictionary:reported];
}

static inline NSDictionary *FCReadCompatibility(NSString *bundle) {
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
        [bundle stringByAppendingPathComponent:@"Contents/Info.plist"]];
    id contract = info[@"FlashHelperCompatibility"];
    return [contract isKindOfClass:NSDictionary.class] ? contract : nil;
}
