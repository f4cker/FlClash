#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The checks a candidate and the installed result must pass. Production uses FCUpdateDefaultPolicy (pinned
// certificate + identifiers, the launcher's status directory owned by root); a test substitutes the trust
// functions to run everything else on ad hoc signed fixtures.
typedef struct {
    NSString * _Nonnull (* _Nonnull candidateTrust)(NSString * _Nonnull bundle);
    NSString * _Nonnull (* _Nonnull installedTrust)(NSString * _Nonnull bundle);
    BOOL (* _Nonnull helperTrust)(NSString * _Nonnull helper);
    CFStringRef _Nonnull launcherStatusDirectory;
    uid_t launcherStatusOwner;
} FCUpdatePolicy;

FCUpdatePolicy FCUpdateDefaultPolicy(void);
// The only location an update replaces (FCGUIBundle).
NSString *FCUpdateInstalledBundle(void);

// Every answer is @{@"code": …} plus details. Codes: ok, notInApplications, notWritable (the update is fine, only
// this account cannot replace the app in place), rejected (archive or signature), notNewer, helperOlder,
// launcherChanged, unpackFailed, swapFailed, rolledBack, rollbackFailed, failed.
//
// `expected` comes from the signed manifest: sha256, size, version, build, helperBuild. Unpacks the archive into
// a fresh hidden directory beside `target` (same volume, so the swap is a rename) and checks the result there.
NSDictionary *FCUpdatePrepare(NSString *archive, NSDictionary *expected, NSString *target, FCUpdatePolicy policy);

// Checks the staged app again, swaps it with `target` (renamex_np RENAME_SWAP), checks the installed result and
// swaps back when that fails. The replaced app stays in the staging directory until FCUpdateCleanup.
NSDictionary *FCUpdateInstall(NSString *staged, NSString *target, FCUpdatePolicy policy);

// Removes this user's staging directories (and the app replaced into them) beside `target`.
void FCUpdateCleanup(NSString *target);

// A detached shell that waits for `pid` to exit, then opens `target`.
BOOL FCUpdateScheduleRelaunch(pid_t pid, NSString *target);

// Unpacks a verified archive into `directory`/Flash-<version> for a manual install. Returns the app path or nil.
NSString * _Nullable FCUpdateUnpackForManualInstall(NSString *archive, NSString *version, NSString *directory);

NS_ASSUME_NONNULL_END
