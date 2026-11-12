#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FCManagedHelperBridge : NSObject
- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments
    completion:(void (^)(NSDictionary *))completion;
@end
NS_ASSUME_NONNULL_END
