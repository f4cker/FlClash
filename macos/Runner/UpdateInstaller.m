#import "UpdateInstaller.h"

#import <errno.h>
#import <fcntl.h>
#import <spawn.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <unistd.h>

#import "../Shared/HelperTrust.h"
#import "../Shared/LauncherStatus.h"

extern char **environ;

static NSString * const FCUpdateStagingPrefix = @".Flash-update-";
static NSString * const FCUpdateBundleName = @"Flash.app";

static NSDictionary *FCUpdateAnswer(NSString *code, NSString *detail) {
    return @{@"code": code, @"detail": detail ?: @""};
}

static NSString *FCUpdateCoreTrust(NSString *bundle, NSString *appTrust) {
    if (![appTrust isEqualToString:@"trusted"]) return appTrust;
    return FCCheckStatic([bundle stringByAppendingPathComponent:FCCoreRelativePath], FCCoreIdentifier) ? @"trusted" : @"core";
}

static NSString *FCUpdateDefaultCandidateTrust(NSString *bundle) {
    return FCUpdateCoreTrust(bundle, FCGUICandidateTrust(bundle));
}

static NSString *FCUpdateDefaultInstalledTrust(NSString *bundle) {
    return FCUpdateCoreTrust(bundle, FCGUIBundleTrust(bundle));
}

static BOOL FCUpdateDefaultHelperTrust(NSString *helper) {
    return FCCheckStatic(helper, FCHelperIdentifier);
}

NSString *FCUpdateInstalledBundle(void) {
    return FCGUIBundle;
}

FCUpdatePolicy FCUpdateDefaultPolicy(void) {
    return (FCUpdatePolicy){FCUpdateDefaultCandidateTrust, FCUpdateDefaultInstalledTrust, FCUpdateDefaultHelperTrust,
        (__bridge CFStringRef)FCLauncherStatusDirectory, 0};
}

// The launcher's rule (Launcher/main.c): an unsigned decimal without sign, space or leading zero.
static BOOL FCUpdateBuildNumber(id value, uint64_t *build) {
    if ([value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() &&
        !CFNumberIsFloatType((__bridge CFNumberRef)value)) value = [value stringValue];
    if (![value isKindOfClass:NSString.class] || [value length] == 0 || [value length] > 18 ||
        [value hasPrefix:@"0"] ||
        [value rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location != NSNotFound ||
        ![value canBeConvertedToEncoding:NSASCIIStringEncoding]) return NO;
    *build = strtoull([value UTF8String], NULL, 10);
    return YES;
}

static NSDictionary *FCUpdateInfo(NSString *bundle) {
    id info = [NSDictionary dictionaryWithContentsOfFile:[bundle stringByAppendingPathComponent:@"Contents/Info.plist"]];
    return [info isKindOfClass:NSDictionary.class] ? info : nil;
}

static BOOL FCUpdateAppBuild(NSString *bundle, uint64_t *build) {
    return FCUpdateBuildNumber(FCUpdateInfo(bundle)[@"CFBundleVersion"], build);
}

// The CFBundleVersion the launcher compares: the helper's Info.plist as bound into its signature.
static BOOL FCUpdateHelperBuild(NSString *bundle, uint64_t *build) {
    NSString *path = [bundle stringByAppendingPathComponent:FCHelperRelativePath];
    SecStaticCodeRef code = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &code)) return NO;
    CFDictionaryRef information = NULL;
    OSStatus status = SecCodeCopySigningInformation(code, kSecCSDefaultFlags, &information);
    CFRelease(code);
    if (status) return NO;
    NSDictionary *info = CFBridgingRelease(information);
    NSDictionary *plist = info[(__bridge NSString *)kSecCodeInfoPList];
    return [plist isKindOfClass:NSDictionary.class] && FCUpdateBuildNumber(plist[@"CFBundleVersion"], build);
}

static NSData *FCUpdateLauncher(NSString *bundle) {
    NSString *path = [bundle stringByAppendingPathComponent:FCLauncherRelativePath];
    struct stat state;
    if (lstat(path.fileSystemRepresentation, &state) || !S_ISREG(state.st_mode)) return nil;
    return [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:nil];
}

// Everything that must hold for `candidate` to replace `target`. `expected` keys are optional; when present they
// must match. Sets *recordUnreadable when the launcher reports its version record as unreadable.
static NSDictionary *FCUpdateCheckCandidate(NSString *candidate, NSString *target, NSDictionary *expected,
    FCUpdatePolicy policy, BOOL *recordUnreadable) {
    NSString *trust = policy.candidateTrust(candidate);
    if (![trust isEqualToString:@"trusted"]) return FCUpdateAnswer(@"rejected", [@"app signature: " stringByAppendingString:trust]);
    NSDictionary *info = FCUpdateInfo(candidate);
    uint64_t build = 0, installedBuild = 0, helperBuild = 0, installedHelperBuild = 0, expectedBuild = 0;
    if (![info[@"CFBundleIdentifier"] isEqual:FCClientIdentifier] || !FCUpdateBuildNumber(info[@"CFBundleVersion"], &build))
        return FCUpdateAnswer(@"rejected", @"app Info.plist");
    if (expected[@"version"] && ![info[@"CFBundleShortVersionString"] isEqual:expected[@"version"]])
        return FCUpdateAnswer(@"rejected", @"version differs from the manifest");
    if (expected[@"build"] && (!FCUpdateBuildNumber(expected[@"build"], &expectedBuild) || expectedBuild != build))
        return FCUpdateAnswer(@"rejected", @"build differs from the manifest");
    if (!FCUpdateAppBuild(target, &installedBuild)) return FCUpdateAnswer(@"failed", @"installed build unreadable");
    if (build <= installedBuild)
        return FCUpdateAnswer(@"notNewer", [NSString stringWithFormat:@"build %llu, installed %llu", build, installedBuild]);
    if (!FCBundledDaemonPresent(candidate)) return FCUpdateAnswer(@"rejected", @"daemon layout");
    NSData *launcher = FCUpdateLauncher(candidate), *installedLauncher = FCUpdateLauncher(target);
    if (!launcher || !installedLauncher || ![launcher isEqualToData:installedLauncher])
        return FCUpdateAnswer(@"launcherChanged", @"FlashHelperLauncher differs from the installed one");
    if (!policy.helperTrust([candidate stringByAppendingPathComponent:FCHelperRelativePath]) ||
        !FCUpdateHelperBuild(candidate, &helperBuild))
        return FCUpdateAnswer(@"rejected", @"helper signature");
    if (expected[@"helperBuild"] && (!FCUpdateBuildNumber(expected[@"helperBuild"], &expectedBuild) ||
            expectedBuild != helperBuild))
        return FCUpdateAnswer(@"rejected", @"helper build differs from the manifest");
    if (FCUpdateHelperBuild(target, &installedHelperBuild) && helperBuild <= installedHelperBuild)
        return FCUpdateAnswer(@"helperOlder",
            [NSString stringWithFormat:@"helper %llu, installed %llu", helperBuild, installedHelperBuild]);
    NSString *problem = nil;
    NSDictionary *status = FCReadLauncherStatus((__bridge NSString *)policy.launcherStatusDirectory, policy.launcherStatusOwner, &problem);
    id recorded = status[@"recordedVersion"];
    if (FCLauncherNumber(recorded) && helperBuild < [recorded unsignedLongLongValue])
        return FCUpdateAnswer(@"helperOlder",
            [NSString stringWithFormat:@"helper %llu, highest run %@", helperBuild, recorded]);
    *recordUnreadable = [status[@"result"] isEqual:@"version_unreadable"];
    return nil;
}

static int FCUpdateRun(NSArray<NSString *> *arguments) {
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    char **argv = calloc(arguments.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < arguments.count; i++) argv[i] = (char *)arguments[i].fileSystemRepresentation;
    pid_t pid = 0;
    int spawned = posix_spawn(&pid, argv[0], &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    free(argv);
    if (spawned) return -1;
    int status = 0;
    while (waitpid(pid, &status, 0) < 0) if (errno != EINTR) return -1;
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static BOOL FCUpdateUnpack(NSString *archive, NSString *directory) {
    if (FCUpdateRun(@[@"/usr/bin/ditto", @"-x", @"-k", archive, directory])) return NO;
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    struct stat state;
    NSString *bundle = [directory stringByAppendingPathComponent:FCUpdateBundleName];
    return [contents isEqualToArray:@[FCUpdateBundleName]] && lstat(bundle.fileSystemRepresentation, &state) == 0 &&
        S_ISDIR(state.st_mode);
}

static BOOL FCUpdateCanonicalDirectory(NSString *path) {
    char canonical[PATH_MAX];
    struct stat state;
    return realpath(path.fileSystemRepresentation, canonical) && [@(canonical) isEqualToString:path] &&
        lstat(canonical, &state) == 0 && S_ISDIR(state.st_mode);
}

static BOOL FCUpdatePermissionError(int error) {
    return error == EACCES || error == EPERM || error == EROFS;
}

NSDictionary *FCUpdatePrepare(NSString *archive, NSDictionary *expected, NSString *target, FCUpdatePolicy policy) {
    uint64_t size = 0, build = 0, installedBuild = 0;
    NSString *sha256 = expected[@"sha256"];
    if (![sha256 isKindOfClass:NSString.class] || !FCUpdateBuildNumber(expected[@"size"], &size) ||
        !FCUpdateBuildNumber(expected[@"build"], &build) || ![expected[@"version"] isKindOfClass:NSString.class])
        return FCUpdateAnswer(@"rejected", @"manifest values");
    struct stat state;
    if (lstat(archive.fileSystemRepresentation, &state) || !S_ISREG(state.st_mode) || (uint64_t)state.st_size != size)
        return FCUpdateAnswer(@"rejected", @"archive size");
    if (![FCSHA256(archive) isEqualToString:sha256]) return FCUpdateAnswer(@"rejected", @"archive sha256");
    if (!FCUpdateCanonicalDirectory(target)) return FCUpdateAnswer(@"notInApplications", @"target not canonical");
    if (!FCUpdateAppBuild(target, &installedBuild)) return FCUpdateAnswer(@"failed", @"installed build unreadable");
    if (build <= installedBuild)
        return FCUpdateAnswer(@"notNewer", [NSString stringWithFormat:@"build %llu, installed %llu", build, installedBuild]);
    NSString *parent = target.stringByDeletingLastPathComponent;
    if (access(parent.fileSystemRepresentation, W_OK)) return FCUpdateAnswer(@"notWritable", @(strerror(errno)));
    NSString *pattern = [parent stringByAppendingPathComponent:[FCUpdateStagingPrefix stringByAppendingString:@"XXXXXX"]];
    char staging[PATH_MAX];
    strlcpy(staging, pattern.fileSystemRepresentation, sizeof(staging));
    if (!mkdtemp(staging)) {
        int error = errno;
        return FCUpdateAnswer(FCUpdatePermissionError(error) ? @"notWritable" : @"failed", @(strerror(error)));
    }
    NSString *directory = @(staging);
    NSString *candidate = [directory stringByAppendingPathComponent:FCUpdateBundleName];
    if (!FCUpdateUnpack(archive, directory)) {
        [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
        return FCUpdateAnswer(@"unpackFailed", @"ditto");
    }
    BOOL recordUnreadable = NO;
    NSDictionary *refused = FCUpdateCheckCandidate(candidate, target, expected, policy, &recordUnreadable);
    if (refused) {
        [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
        return refused;
    }
    return @{@"code": @"ok", @"staged": candidate, @"recordUnreadable": @(recordUnreadable)};
}

static BOOL FCUpdateStagedPath(NSString *staged, NSString *target) {
    NSString *directory = staged.stringByDeletingLastPathComponent;
    struct stat state;
    return [staged.lastPathComponent isEqualToString:FCUpdateBundleName] &&
        [directory.lastPathComponent hasPrefix:FCUpdateStagingPrefix] &&
        [directory.stringByDeletingLastPathComponent isEqualToString:target.stringByDeletingLastPathComponent] &&
        FCUpdateCanonicalDirectory(directory) && lstat(directory.fileSystemRepresentation, &state) == 0 &&
        state.st_uid == getuid() && (state.st_mode & 077) == 0 && FCUpdateCanonicalDirectory(staged);
}

NSDictionary *FCUpdateInstall(NSString *staged, NSString *target, FCUpdatePolicy policy) {
    if (!FCUpdateCanonicalDirectory(target)) return FCUpdateAnswer(@"notInApplications", @"target not canonical");
    if (!FCUpdateStagedPath(staged, target)) return FCUpdateAnswer(@"rejected", @"staged path");
    BOOL recordUnreadable = NO;
    NSDictionary *refused = FCUpdateCheckCandidate(staged, target, @{}, policy, &recordUnreadable);
    if (refused) return refused;
    uint64_t build = 0;
    NSData *launcher = FCUpdateLauncher(target);
    if (!FCUpdateAppBuild(staged, &build) || !launcher) return FCUpdateAnswer(@"failed", @"staged app unreadable");
    if (renamex_np(staged.fileSystemRepresentation, target.fileSystemRepresentation, RENAME_SWAP)) {
        int error = errno;
        return FCUpdateAnswer(FCUpdatePermissionError(error) ? @"notWritable" : @"swapFailed", @(strerror(error)));
    }
    uint64_t installed = 0;
    NSString *trust = policy.installedTrust(target);
    NSString *problem = nil;
    if (![trust isEqualToString:@"trusted"]) problem = [@"installed app signature: " stringByAppendingString:trust];
    else if (!FCUpdateAppBuild(target, &installed) || installed != build) problem = @"installed build";
    else if (![FCUpdateLauncher(target) isEqualToData:launcher]) problem = @"installed launcher";
    if (!problem) return @{@"code": @"ok", @"replaced": staged};
    if (renamex_np(staged.fileSystemRepresentation, target.fileSystemRepresentation, RENAME_SWAP))
        return FCUpdateAnswer(@"rollbackFailed", [NSString stringWithFormat:@"%@; swap back: %s; previous app at %@",
            problem, strerror(errno), staged]);
    return FCUpdateAnswer(@"rolledBack", problem);
}

void FCUpdateCleanup(NSString *target) {
    NSString *parent = target.stringByDeletingLastPathComponent;
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:parent error:nil]) {
        if (![name hasPrefix:FCUpdateStagingPrefix]) continue;
        NSString *path = [parent stringByAppendingPathComponent:name];
        struct stat state;
        if (lstat(path.fileSystemRepresentation, &state) == 0 && S_ISDIR(state.st_mode) && state.st_uid == getuid())
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}

BOOL FCUpdateScheduleRelaunch(pid_t pid, NSString *target) {
    posix_spawnattr_t attributes;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT);
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    const char *script = "i=0; while /bin/kill -0 \"$1\" 2>/dev/null && [ $i -lt 600 ]; do /bin/sleep 0.2; i=$((i+1)); done; "
        "exec /usr/bin/open \"$2\"";
    NSString *process = [NSString stringWithFormat:@"%d", pid];
    char *argv[] = {"/bin/sh", "-c", (char *)script, "sh", (char *)process.UTF8String,
        (char *)target.fileSystemRepresentation, NULL};
    pid_t child = 0;
    int spawned = posix_spawn(&child, "/bin/sh", &actions, &attributes, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attributes);
    return spawned == 0;
}

NSString *FCUpdateUnpackForManualInstall(NSString *archive, NSString *version, NSString *directory) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.+-"];
    if (!version.length || version.length > 64 || [version rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound)
        return nil;
    NSString *base = [directory stringByAppendingPathComponent:[@"Flash-" stringByAppendingString:version]];
    NSString *destination = base;
    for (int i = 2; mkdir(destination.fileSystemRepresentation, 0755); i++) {
        if (errno != EEXIST || i > 99) return nil;
        destination = [NSString stringWithFormat:@"%@ (%d)", base, i];
    }
    if (!FCUpdateUnpack(archive, destination)) {
        [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
        return nil;
    }
    return [destination stringByAppendingPathComponent:FCUpdateBundleName];
}
