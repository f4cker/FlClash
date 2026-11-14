#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <xpc/xpc.h>

NS_ASSUME_NONNULL_BEGIN
extern NSString * const FCHelperLabel;
extern NSString * const FCClientIdentifier;
extern NSString * const FCServiceIdentifier;
extern NSString * const FCGUIBundle;
extern NSString * const FCMaintenanceIdentifier;
extern NSString * const FCInstalledBundle;
extern NSString * const FCLegacyPlist;
extern NSString * const FCRuntimeDirectory;
extern NSString * const FCLegacyRuntimeDirectory;
BOOL FCLegacyRuntimeAbsent(void);
NSString *FCInstalledExecutable(NSString *role);
typedef NS_ENUM(NSUInteger, FCHelperPlistSchema) {
    FCHelperPlistInvalid,
    FCHelperPlistLegacy,
    FCHelperPlistAssociated,
};
NSDictionary *FCCanonicalHelperPlist(void);
FCHelperPlistSchema FCClassifyHelperPlist(id _Nullable plist);
BOOL FCLegacyPlistTrusted(void);
BOOL FCLegacyPlistTrustedForMaintenance(void);
@interface FCMessageValidator : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable bundle:(nullable NSString *)bundle;
- (BOOL)check:(xpc_object_t)message;
@end
@interface FCGUIMessageValidator : NSObject
- (BOOL)check:(xpc_object_t)message;
@end
extern const size_t FCMaxFrame;
NSString * _Nullable FCSplitGUIRequirement(void);
NSString *FCGUIBundleTrust(NSString *bundle);
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
