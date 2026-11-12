#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <xpc/xpc.h>

NS_ASSUME_NONNULL_BEGIN
extern NSString * const FCHelperLabel;
extern NSString * const FCClientIdentifier;
extern NSString * const FCMaintenanceIdentifier;
extern NSString * const FCInstalledBundle;
extern NSString * const FCLegacyPlist;
extern NSString * const FCRuntimeDirectory;
NSString *FCInstalledExecutable(NSString *role);
BOOL FCLegacyPlistTrusted(void);
@interface FCMessageValidator : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable bundle:(nullable NSString *)bundle;
- (BOOL)check:(xpc_object_t)message;
@end
extern const size_t FCMaxFrame;
NSString * _Nullable FCRequirementForPolicy(NSString *identifier, NSString *certificatePin, NSString *team);
NSString * _Nullable FCSigningRequirement(NSString *identifier);
BOOL FCCheckMessage(xpc_object_t message, NSString *identifier);
BOOL FCCheckClientMessage(xpc_object_t message, NSString *expectedBundle);
BOOL FCCheckStatic(NSString *path, NSString *identifier);
BOOL FCProtectedTree(NSString *path, BOOL recursive);
NSString *FCSHA256(NSString *path);
NSString *FCBundleTrust(NSString *bundle);
NSString *FCPayloadTrust(NSString *bundle);
NS_ASSUME_NONNULL_END
