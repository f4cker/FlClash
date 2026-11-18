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
// Exit status of a helper that refuses to run (launch arguments rejected, or its self-check failed at startup or
// before an operation). Distinct from EX_CONFIG (78) and from FlashHelperLauncher's own exit codes, so that the app
// can tell "the helper refused" from "launchd cannot start the job" in `launchctl print`'s last exit code.
#define FC_HELPER_REFUSED_EXIT 79
// FlashHelperLauncher's exit codes (Launcher/README.md): 81 not_root, 82 location, 83 copy, 84 signature,
// 85 version_unreadable, 86 downgrade, 87 exec.
#define FC_LAUNCHER_EXIT_FIRST 81
#define FC_LAUNCHER_EXIT_LAST 87

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
// FlashHelperLauncher (macos/PrivilegedHelper/Launcher, signed once and never rebuilt) is the daemon's BundleProgram:
// launchd pins the job's launch constraint to its cdhash, which never changes. It copies the bundled FlashHelper to
// FCHelperCopyPath (root 0700 directory), verifies the copy (pinned certificate + identifier, no downgrade) and execs
// it with argv [FCHelperCopyPath, FCHelperBundleArgument, <bundle>]. The helper treats <bundle> as untrusted input.
extern NSString * const FCLauncherRelativePath;
extern NSString * const FCHelperCopyPath;
extern NSString * const FCHelperBundleArgument;
// Written by the launcher only (root:wheel, 0755 directory, 0644 file); the app reads it for display, never for trust.
// The helper never reads or writes either launcher directory.
extern NSString * const FCLauncherStateDirectory;
extern NSString * const FCLauncherStatusDirectory;
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
// `executable` is where the peer must run; `sealedExecutable` the file whose static cdhash it must have. They differ
// for the daemon: it runs as the launcher's root-only copy (FCHelperCopyPath, unreadable for the app) of the helper
// sealed in the app (FCInstalledExecutable(FCHelperIdentifier)); the bytes, and so the cdhash, are the same.
- (instancetype)initWithIdentifier:(NSString *)identifier executable:(NSString *)executable
    sealedExecutable:(NSString *)sealedExecutable;
- (BOOL)check:(xpc_object_t)message;
// After a failed check: the first step that failed, with its OSStatus/errno (diagnostics only, never trusted).
@property (readonly, nullable) NSString *failure;
// After a failed check: the sender is the pinned helper at the bundled path, only its running cdhash is not
// the bundled one (a previous build's daemon still runs). Nothing in such a message is trusted or read.
@property (readonly) BOOL runningCodeStale;
// After a failed check: the kernel could not be asked about the sender (its status, cdhash or path read failed,
// typically ESRCH because the daemon exited right after replying). The message is still refused; this only says
// that nothing was found wrong with it, so the app reports "not answering" and asks again, not a failed check.
@property (readonly) BOOL transientFailure;
@end
// One per connection: the full validation (running app and the whole sealed bundle) for the first message and
// again whenever the bundle changes on disk; in between, the same process lifetime with the same cdhash, from the
// kernel through the message's audit token.
@interface FCGUIMessageValidator : NSObject
- (BOOL)check:(xpc_object_t)message;
// After a failed check: the step that failed (diagnostics only, never trusted, no paths).
@property (readonly, nullable) NSString *failure;
@end
extern const size_t FCMaxFrame;
// The most frames one relay `receive` answers with.
static const NSUInteger FCRelayBatchFrames = 64;
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
// The daemon behind an audit token, from the kernel alone (its executable may be unreadable for the caller): code
// signature status valid, hardened runtime, hard/kill, not ad hoc, not debuggable or debugged; running image exactly
// at `expectedPath`; the token's process lifetime unchanged across the reads (no pid reuse, no exec). Returns
// @"verified" with the running cdhash, or @"failed:<step>" naming the first failed step (with errno/status).
NSString *FCHelperGuestCheck(const audit_token_t * _Nullable token, NSString *expectedPath,
    NSData * _Nullable * _Nullable runningHash);
// Whether a running process is a Flash Core, from its code signature alone (pinned certificate and
// com.layoute.flash.core); `reason` explains FCCoreMatchUnknown.
typedef NS_ENUM(NSInteger, FCCoreMatch) { FCCoreMatchOther, FCCoreMatchFlash, FCCoreMatchGone, FCCoreMatchUnknown };
FCCoreMatch FCRunningFlashCore(pid_t pid, NSString * _Nullable * _Nullable reason);
BOOL FCProtectedTree(NSString *path, BOOL recursive);
NSString *FCSHA256(NSString *path);
NSString *FCHexString(NSData * _Nullable data);
// The daemon's argv as set by the launcher: exactly [FCHelperCopyPath, FCHelperBundleArgument, <bundle>], where
// <bundle> is canonical (realpath) and is FCGUIBundle. Returns the bundle, or nil and a reason to refuse to run.
NSString * _Nullable FCHelperBundleFromArguments(NSArray<NSString *> *arguments, NSString * _Nullable * _Nullable reason);
// Daemon startup/per-operation self verification against the bundle the launcher named. Returns @"ok" or a short
// reason; any other value means the daemon must exit (FC_HELPER_REFUSED_EXIT) without doing privileged work.
NSString *FCHelperSelfCheck(NSString *runningExecutable, NSString *bundle);
NS_ASSUME_NONNULL_END
