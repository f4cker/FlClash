#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FCManagedHelperBridge : NSObject
- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments
    completion:(void (^)(NSDictionary *))completion;
// Checks again, off the main thread, the Core this app started through the daemon: "verified", "failed"
// (another identity, or it is gone) or "none" (no Core started through the daemon).
- (NSString *)coreIdentity;
@end
NS_ASSUME_NONNULL_END
