#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <xpc/xpc.h>

NS_ASSUME_NONNULL_BEGIN
// launchd label and Mach service of the SMAppService daemon (distinct from the legacy com.layoute.flash.helper job).
extern NSString * const FCHelperLabel;
extern NSString * const FCDaemonPlistName;
// Code-signing identifiers (pinned leaf certificate + identifier).
extern NSString * const FCClientIdentifier;
extern NSString * const FCHelperIdentifier;
extern NSString * const FCCoreIdentifier;
// The only supported install location; everything privileged is derived from it, never from caller input.
extern NSString * const FCGUIBundle;
extern NSString * const FCDaemonPlistRelativePath;
extern NSString * const FCHelperRelativePath;
extern NSString * const FCCoreRelativePath;
// Root-only (root:wheel 0700) runtime directory owned by the daemon: relay sockets and the verified Core copy.
extern NSString * const FCRuntimeDirectory;

NSString *FCInstalledExecutable(NSString *role);
NSDictionary *FCCanonicalDaemonPlist(void);
BOOL FCDaemonPlistValid(id _Nullable plist);
BOOL FCBundledDaemonPresent(NSString *bundle);

@interface FCMessageValidator : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable;
- (BOOL)check:(xpc_object_t)message;
@end
@interface FCGUIMessageValidator : NSObject
- (BOOL)check:(xpc_object_t)message;
@end
extern const size_t FCMaxFrame;
NSString * _Nullable FCGUIRequirement(void);
NSString *FCGUIBundleTrust(NSString *bundle);
NSString * _Nullable FCRequirementForPolicy(NSString *identifier, NSString *certificatePin, NSString *team);
NSString * _Nullable FCSigningRequirement(NSString *identifier);
BOOL FCCodeEntitlementsAllowed(NSDictionary * _Nullable entitlements, uint32_t flags);
BOOL FCGUIEntitlementsAllowed(NSDictionary * _Nullable entitlements, uint32_t flags);
BOOL FCCheckStatic(NSString *path, NSString *identifier);
NSData * _Nullable FCStaticCodeHash(NSString *path, NSString *identifier);
BOOL FCProtectedTree(NSString *path, BOOL recursive);
NSString *FCSHA256(NSString *path);
NSString *FCHexString(NSData * _Nullable data);
// Daemon startup/per-operation self verification. Returns @"ok" or a short reason; any other value means
// the daemon must exit (EX_CONFIG) without doing privileged work.
NSString *FCHelperSelfCheck(NSString *runningExecutable);
NS_ASSUME_NONNULL_END
