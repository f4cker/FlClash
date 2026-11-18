// Read-only view of FlashHelperLauncher's last outcome (PrivilegedHelper/Launcher/README.md), for the app's helper
// card only. It never grants or withholds trust: the helper is still used only after an authenticated hello. It is
// consulted only when the daemon is enabled but does not answer, to say why.
#import <Foundation/Foundation.h>
#import <errno.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString * const FCLauncherStatusFile = @"launcher.json";
// A status written long before this launch of the app belongs to an earlier episode and is not shown.
static const NSTimeInterval FCLauncherStatusMaxAgeBeforeLaunch = 600;
// "ok" means the launcher exec'd the helper. Only when the helper has not answered for this long after such a
// status was first seen is it reported as a failure (it may have been ended by the system after exec, or refused
// to run); before that it is an ordinary start.
static const NSTimeInterval FCLauncherOkGrace = 8;

static inline BOOL FCLauncherNumber(id value) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID();
}

static inline BOOL FCLauncherNode(const struct stat *state, uid_t owner, BOOL directory) {
    return (directory ? S_ISDIR(state->st_mode) : S_ISREG(state->st_mode)) && state->st_uid == owner &&
        (state->st_mode & 022) == 0;
}

// Returns the parsed status. Returns nil with *problem nil when there is none (no directory or file), and nil with
// *problem set when one is present but cannot be used (not owned by `owner`, writable by group/other, a symlink,
// malformed).
static inline NSDictionary *FCReadLauncherStatus(NSString *directory, uid_t owner, NSString **problem) {
    *problem = nil;
    struct stat state;
    if (lstat(directory.fileSystemRepresentation, &state)) {
        if (errno != ENOENT) *problem = [NSString stringWithFormat:@"status directory lstat errno=%d", errno];
        return nil;
    }
    if (!FCLauncherNode(&state, owner, YES)) { *problem = @"status directory not root-owned or writable by others"; return nil; }
    NSString *path = [directory stringByAppendingPathComponent:FCLauncherStatusFile];
    if (lstat(path.fileSystemRepresentation, &state)) {
        if (errno != ENOENT) *problem = [NSString stringWithFormat:@"status file lstat errno=%d", errno];
        return nil;
    }
    if (!FCLauncherNode(&state, owner, NO) || state.st_nlink != 1 || state.st_size <= 0 || state.st_size > 4096) {
        *problem = S_ISLNK(state.st_mode) ? @"status file is a symlink" : @"status file not a root-owned regular file";
        return nil;
    }
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) { *problem = [NSString stringWithFormat:@"status file open errno=%d", errno]; return nil; }
    struct stat opened;
    char buffer[4097];
    ssize_t length = -1;
    if (fstat(fd, &opened) == 0 && opened.st_dev == state.st_dev && opened.st_ino == state.st_ino &&
        FCLauncherNode(&opened, owner, NO)) length = read(fd, buffer, sizeof(buffer));
    close(fd);
    if (length <= 0 || length > 4096) { *problem = @"status file unreadable"; return nil; }
    id status = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:buffer length:(NSUInteger)length]
        options:0 error:nil];
    NSSet *keys = [NSSet setWithArray:@[@"v", @"result", @"detail", @"helperVersion", @"recordedVersion",
        @"launcherVersion", @"time"]];
    NSArray *results = @[@"ok", @"not_root", @"location", @"copy", @"signature", @"version_unreadable",
        @"downgrade", @"exec"];
    BOOL valid = [status isKindOfClass:NSDictionary.class] && [[NSSet setWithArray:[status allKeys]] isEqualToSet:keys];
    valid = valid && FCLauncherNumber(status[@"v"]) && [status[@"v"] isEqual:@1] &&
        [status[@"result"] isKindOfClass:NSString.class] && [results containsObject:status[@"result"]] &&
        [status[@"detail"] isKindOfClass:NSString.class] && [status[@"detail"] length] <= 200 &&
        FCLauncherNumber(status[@"launcherVersion"]) && FCLauncherNumber(status[@"time"]);
    for (NSString *key in @[@"helperVersion", @"recordedVersion"])
        valid = valid && (status[key] == NSNull.null || FCLauncherNumber(status[key]));
    if (!valid) { *problem = @"status file malformed"; return nil; }
    return status;
}

// The card code for a launcher result: a failed security check, an older Flash than one that already ran, or a
// helper that could not be prepared or started.
static inline NSString *FCLauncherCardCode(NSString *result) {
    if ([@[@"signature", @"location", @"version_unreadable"] containsObject:result]) return @"launcherCheckFailed";
    if ([result isEqualToString:@"downgrade"]) return @"launcherDowngrade";
    return @"launcherFailed";
}

static inline NSString *FCLauncherDetail(NSDictionary *status, NSString *appVersion) {
    id (^text)(id) = ^id(id value) { return value == NSNull.null || !value ? @"none" : value; };
    NSDate *time = [NSDate dateWithTimeIntervalSince1970:[status[@"time"] doubleValue]];
    NSISO8601DateFormatter *format = [NSISO8601DateFormatter new];
    return [NSString stringWithFormat:@"launcher result: %@\nlauncher detail: %@\n"
        "helper version: %@; highest version run: %@; app version: %@; launcher version: %@\nlauncher time: %@",
        status[@"result"], status[@"detail"], text(status[@"helperVersion"]), text(status[@"recordedVersion"]),
        appVersion.length ? appVersion : @"unknown", status[@"launcherVersion"], [format stringFromDate:time]];
}

// What the app reports when the daemon is enabled but did not answer. Returns @{code, detail}, @{detail} (only
// more detail for an ordinary wait), or nil (nothing to add). `okUnanswered` is how long a launcher "ok" has been
// seen without an answer from the helper.
static inline NSDictionary *FCLauncherAnswer(NSDictionary *status, NSString *problem, NSTimeInterval appStarted,
    NSTimeInterval okUnanswered, NSString *appVersion) {
    if (problem)
        return @{@"code": @"launcherFailed", @"detail": [@"launcher status unreadable: " stringByAppendingString:problem]};
    if (!status || [status[@"time"] doubleValue] < appStarted - FCLauncherStatusMaxAgeBeforeLaunch) return nil;
    NSString *detail = FCLauncherDetail(status, appVersion);
    if (![status[@"result"] isEqualToString:@"ok"])
        return @{@"code": FCLauncherCardCode(status[@"result"]), @"detail": detail};
    detail = [detail stringByAppendingString:@"\nThe launcher verified and started the helper, but the helper did not "
        "answer: the system may have ended it after exec (launch constraint), or it refused to run (self-check)."];
    if (okUnanswered < FCLauncherOkGrace) return @{@"detail": detail};
    return @{@"code": @"launcherFailed", @"detail": detail};
}
