#pragma once
#import <Foundation/Foundation.h>

static inline BOOL FCCompatibilityVersion(id value, NSInteger expected) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() &&
        CFNumberIsFloatType((__bridge CFNumberRef)value) == false && [value longLongValue] == expected;
}

static inline BOOL FCCoreHashValid(id hash) {
    return [hash isKindOfClass:NSString.class] && [hash length] == 64 &&
        [hash rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
}

static inline BOOL FCCompatibilityCommon(id contract) {
    return [contract isKindOfClass:NSDictionary.class] && FCCompatibilityVersion(contract[@"CallerPolicy"], 2) &&
        FCCompatibilityVersion(contract[@"ServiceAPI"], 1) && FCCompatibilityVersion(contract[@"CoreAPI"], 1);
}

static inline BOOL FCGUICompatibilityValid(id contract) {
    if (!FCCompatibilityCommon(contract)) return NO;
    NSArray *hashes = contract[@"AcceptedCoreSHA256"];
    if (![hashes isKindOfClass:NSArray.class] || !hashes.count || hashes.count > 16) return NO;
    for (id hash in hashes) if (!FCCoreHashValid(hash)) return NO;
    return [NSSet setWithArray:hashes].count == hashes.count;
}

static inline BOOL FCServiceCompatibilityValid(id contract) {
    if (!FCCompatibilityCommon(contract) || !FCCoreHashValid(contract[@"CoreSHA256"])) return NO;
    for (NSString *key in @[@"CoreVersion", @"CoreRevision"]) {
        id value = contract[key];
        if (![value isKindOfClass:NSString.class] || ![value length] || [value length] > 128) return NO;
    }
    return YES;
}

static inline BOOL FCCompatibilityAccepts(id gui, id service) {
    return FCGUICompatibilityValid(gui) && FCServiceCompatibilityValid(service) &&
        [gui[@"AcceptedCoreSHA256"] containsObject:service[@"CoreSHA256"]];
}

static inline BOOL FCCompatibilityHelloMatches(id gui, id service, id reported) {
    if (!FCCompatibilityAccepts(gui, service) || !FCServiceCompatibilityValid(reported)) return NO;
    for (NSString *key in @[@"CallerPolicy", @"ServiceAPI", @"CoreAPI", @"CoreSHA256", @"CoreVersion", @"CoreRevision"])
        if (![service[key] isEqual:reported[key]]) return NO;
    return YES;
}

static inline NSDictionary *FCReadCompatibility(NSString *bundle) {
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
        [bundle stringByAppendingPathComponent:@"Contents/Info.plist"]];
    id contract = info[@"FlashHelperCompatibility"];
    return [contract isKindOfClass:NSDictionary.class] ? contract : nil;
}
