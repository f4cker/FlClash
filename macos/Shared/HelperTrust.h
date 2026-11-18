#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <xpc/xpc.h>

// The daemon's registration name, in one place: launchd label, Mach service and plist file name
// (Contents/Library/LaunchDaemons/<label>.plist). A new name makes the system create a fresh Background Task
// record, and with it a launch constraint computed from the current helper, instead of re-using the record (and
// the constraint pinned to an older helper's cdhash) of the previous name. The code-signing identifier of the
// helper (com.layoute.flash.helper), its BundleProgram path and the certificate requirement do not change with it.
#define FC_HELPER_LABEL "com.layoute.flash.helperd"
// The name used up to 0.9.15-mitm.3. Its plist stays in the bundle only so SMAppService can unregister it
// (daemonServiceWithPlistName: requires the plist in Contents/Library/LaunchDaemons); it is never registered.
#define FC_RETIRED_HELPER_LABEL "com.layoute.flash.daemon"

NS_ASSUME_NONNULL_BEGIN
// launchd label and Mach service of the SMAppService daemon (distinct from the legacy com.layoute.flash.helper job).
extern NSString * const FCHelperLabel;
extern NSString * const FCDaemonPlistName;
extern NSString * const FCRetiredHelperLabel;
extern NSString * const FCRetiredDaemonPlistName;
extern NSString * const FCRetiredDaemonPlistRelativePath;
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
// Deliberately not renamed with the label: the new helper finds the previous helper's Core journal there.
extern NSString * const FCRuntimeDirectory;

NSString *FCInstalledExecutable(NSString *role);
NSDictionary *FCCanonicalDaemonPlist(void);
NSDictionary *FCCanonicalDaemonPlistForLabel(NSString *label);
BOOL FCDaemonPlistValid(id _Nullable plist);
// The retired name's plist: the same exact schema under the retired label (and its Mach service).
BOOL FCRetiredDaemonPlistValid(id _Nullable plist);
BOOL FCBundledDaemonPresent(NSString *bundle);

// How the running daemon's cdhash compares with the bundled (on-disk) one, for a sender that passed every
// other identity check: current, an older build still running after an app update (stale), or not acceptable.
typedef NS_ENUM(NSInteger, FCRunningHashVerdict) { FCRunningHashCurrent, FCRunningHashStale, FCRunningHashInvalid };
FCRunningHashVerdict FCCompareRunningHash(NSData * _Nullable runningHash, NSData * _Nullable diskHash);
@interface FCMessageValidator : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable;
- (BOOL)check:(xpc_object_t)message;
// After a failed check: the sender is the pinned helper at the bundled path, only its running cdhash is not
// the bundled one (a previous build's daemon still runs). Nothing in such a message is trusted or read.
@property (readonly) BOOL runningCodeStale;
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
// The bundled Core's cdhash, once it passes the pinned requirement for com.layoute.flash.core. The daemon
// runs a copy whose bytes the contract's CoreSHA256 pins to this file.
NSData * _Nullable FCBundledCoreHash(void);
// The running Core behind the audit token the daemon read off the relay socket, from the kernel alone: the
// staged copy is root-only, so the app cannot read it. The token names one process lifetime, so a reused pid
// does not pass. Returns @"verified" or @"failed:<stage>" naming the first check that failed.
NSString *FCCoreGuestCheck(NSData * _Nullable auditToken, pid_t pid, NSData * _Nullable expectedHash);
NSData * _Nullable FCStaticCodeHash(NSString *path, NSString *identifier);
// Whether a running process is a Flash Core, from its code signature alone (pinned certificate and
// com.layoute.flash.core); `reason` explains FCCoreMatchUnknown.
typedef NS_ENUM(NSInteger, FCCoreMatch) { FCCoreMatchOther, FCCoreMatchFlash, FCCoreMatchGone, FCCoreMatchUnknown };
FCCoreMatch FCRunningFlashCore(pid_t pid, NSString * _Nullable * _Nullable reason);
BOOL FCProtectedTree(NSString *path, BOOL recursive);
NSString *FCSHA256(NSString *path);
NSString *FCHexString(NSData * _Nullable data);
// Daemon startup/per-operation self verification. Returns @"ok" or a short reason; any other value means
// the daemon must exit (EX_CONFIG) without doing privileged work.
NSString *FCHelperSelfCheck(NSString *runningExecutable);
NS_ASSUME_NONNULL_END
