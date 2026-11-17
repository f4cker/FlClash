#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FCManagedHelperBridge : NSObject
- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments
    completion:(void (^)(NSDictionary *))completion;
// The Core this app started through the daemon, checked on the calling queue (never the main thread):
// "verified", "none" (no Core started through the daemon) or "failed:<stage>".
- (NSString *)coreIdentity;
@end
NS_ASSUME_NONNULL_END
