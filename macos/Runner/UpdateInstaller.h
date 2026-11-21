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
    // renamex_np(RENAME_SWAP); a test makes the swap back fail.
    int (* _Nonnull swap)(const char * _Nonnull from, const char * _Nonnull to);
    // Where the previous app is kept when it cannot be swapped back (FCUpdateRescueDirectory).
    CFStringRef _Nonnull rescueDirectory;
} FCUpdatePolicy;

FCUpdatePolicy FCUpdateDefaultPolicy(void);
// ~/Library/Application Support/Flash/update-rescue: writable by the user without any extra permission.
NSString *FCUpdateRescueDirectory(void);
// The only location an update replaces (FCGUIBundle).
NSString *FCUpdateInstalledBundle(void);

// Every failed answer from FCUpdatePrepare/FCUpdateInstall carries `unchanged`: the installed app was confirmed
// untouched (same directory, same build) afterwards.
//
// Every answer is @{@"code": …} plus details. Codes: ok, notInApplications, notWritable (the update is fine, only
// this account cannot replace the app in place), rejected (archive or signature), notNewer, helperOlder,
// launcherChanged, unpackFailed, swapFailed, rolledBack, rollbackFailed, failed.
//
// `expected` comes from the signed manifest: sha256, size, version, build, helperBuild. Unpacks the archive into
// a fresh hidden directory beside `target` (same volume, so the swap is a rename) and checks the result there.
NSDictionary *FCUpdatePrepare(NSString *archive, NSDictionary *expected, NSString *target, FCUpdatePolicy policy);

// Checks the staged app again, swaps it with `target` (renamex_np RENAME_SWAP), checks the installed result and
// swaps back when that fails. The replaced app stays in the staging directory until FCUpdateCleanup. From just
// before the swap until the installed app passed its checks (or was swapped back) the directory carries a rollback
// marker instead of the staging marker.
//
// When the swap back fails too (rollbackFailed), the previous app is the only good copy: its staging directory
// loses its marker, so no cleanup ever deletes it, and it moves to policy.rescueDirectory/Flash-<build>.app with
// a record beside it: last-failed-update.json, plus failed-update-<date>.json that later rescues never overwrite.
// `rescued` is where it ends up (still the staging directory when the move fails), `rescueMoved` whether it moved,
// `rescueVerified` whether an app with the previous build was found there after the move.
NSDictionary *FCUpdateInstall(NSString *staged, NSString *target, FCUpdatePolicy policy);

// Removes this user's staging directories beside `target`, only those still carrying the marker FCUpdatePrepare
// writes when it creates them (so never a previous app kept after rollbackFailed). A directory still carrying the
// rollback marker (an install stopped mid-way) is never deleted for its marker: it is removed only when it still
// holds the candidate recorded in that marker (same build and seal). Any other app in it moves to `rescueDirectory`
// as after rollbackFailed; without an app bundle in it, it loses its markers, stays, and gets a record there.
void FCUpdateCleanupKeeping(NSString *target, NSString *rescueDirectory);
// FCUpdateCleanupKeeping with FCUpdateRescueDirectory().
void FCUpdateCleanup(NSString *target);
NSData * _Nullable FCUpdateCandidateSeal(NSString *bundle);
NSDictionary *FCUpdateInstallExpected(NSString *staged, NSString *target, NSDictionary *expected, FCUpdatePolicy policy);

// A detached shell that waits for `pid` to exit, then opens `target`.
BOOL FCUpdateScheduleRelaunch(pid_t pid, NSString *target);

// Unpacks a verified archive into `directory`/Flash-<version> for a manual install. Returns the app path or nil.
NSString * _Nullable FCUpdateUnpackForManualInstall(NSString *archive, NSString *version, NSString *directory);

NS_ASSUME_NONNULL_END
