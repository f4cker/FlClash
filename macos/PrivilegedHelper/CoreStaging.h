#pragma once
// Root-only runtime directory and verified Core copy for the SMAppService daemon.
// The app bundle (and so the bundled Core) is user-writable; root never executes it in place. The daemon
// copies Core through one O_NOFOLLOW descriptor into a root:wheel 0700 directory while hashing those exact
// bytes, checks the hash against the sealed contract, verifies the copy's signature, then executes the copy.
#import <Foundation/Foundation.h>
#import "../Shared/HelperTrust.h"
#import <CommonCrypto/CommonDigest.h>
#import <dirent.h>
#import <errno.h>
#import <fcntl.h>
#import <libproc.h>
#import <mach/mach.h>
#import <signal.h>
#import <sys/stat.h>
#import <unistd.h>

#define FC_CORE_MAX_BYTES (1024LL * 1024 * 1024)

BOOL FCProtectedTree(NSString *path, BOOL recursive);
NSString *FCHexString(NSData *data);

static inline BOOL FCPrepareRuntimeDirectory(NSString *directory) {
    const char *path = directory.fileSystemRepresentation;
    if (mkdir(path, 0700) && errno != EEXIST) return NO;
    struct stat state;
    if (lstat(path, &state) || !S_ISDIR(state.st_mode) || state.st_uid != 0) return NO;
    if ((state.st_mode & 07777) != 0700 && chmod(path, 0700)) return NO;
    if (lstat(path, &state) || (state.st_mode & 07777) != 0700) return NO;
    return FCProtectedTree(directory, NO);
}

static inline BOOL FCStagedCoreName(const char *name) {
    return !strncmp(name, "core-", 5) || !strncmp(name, ".core-", 6);
}

static inline void FCRemoveStagedCores(NSString *directory) {
    int dirfd = open(directory.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (dirfd < 0) return;
    DIR *listing = fdopendir(dirfd);
    if (!listing) { close(dirfd); return; }
    struct dirent *entry;
    while ((entry = readdir(listing)))
        if (FCStagedCoreName(entry->d_name)) unlinkat(dirfd, entry->d_name, 0);
    closedir(listing);
}

// Returns the staged path, or nil when the source is not a regular file or its bytes do not hash to expected.
static inline NSString *FCStageCore(NSString *source, NSString *directory, NSString *expected) {
    if (expected.length != 64) return nil;
    int input = open(source.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (input < 0) return nil;
    struct stat state;
    if (fstat(input, &state) || !S_ISREG(state.st_mode) || state.st_size <= 0 || state.st_size > FC_CORE_MAX_BYTES) {
        close(input); return nil;
    }
    char temporary[PATH_MAX];
    if (snprintf(temporary, sizeof(temporary), "%s/.core-XXXXXXXX", directory.fileSystemRepresentation) >= (int)sizeof(temporary)) {
        close(input); return nil;
    }
    int output = mkstemp(temporary);
    if (output < 0) { close(input); return nil; }
    fcntl(output, F_SETFD, FD_CLOEXEC);
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    uint8_t buffer[65536];
    long long total = 0;
    BOOL ok = YES;
    for (;;) {
        ssize_t count = read(input, buffer, sizeof(buffer));
        if (count < 0 && errno == EINTR) continue;
        if (count < 0) { ok = NO; break; }
        if (count == 0) break;
        total += count;
        if (total > FC_CORE_MAX_BYTES) { ok = NO; break; }
        CC_SHA256_Update(&context, buffer, (CC_LONG)count);
        for (ssize_t offset = 0; offset < count;) {
            ssize_t written = write(output, buffer + offset, count - offset);
            if (written < 0 && errno == EINTR) continue;
            if (written <= 0) { ok = NO; break; }
            offset += written;
        }
        if (!ok) break;
    }
    close(input);
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSString *actual = FCHexString([NSData dataWithBytes:digest length:sizeof(digest)]);
    ok = ok && [actual isEqualToString:expected] && fchmod(output, 0500) == 0 && fsync(output) == 0;
    close(output);
    NSString *staged = [directory stringByAppendingPathComponent:[@"core-" stringByAppendingString:expected]];
    if (!ok || rename(temporary, staged.fileSystemRepresentation)) { unlink(temporary); return nil; }
    return staged;
}

#ifndef FCProcessToken
#define FCProcessToken FCProcessTokenFromTask
#endif
#ifndef FCSweepPause
#define FCSweepPause() usleep(50000)
#endif

// The audit token names one process lifetime, so a signal sent through it cannot reach a reused pid.
static inline int FCProcessTokenFromTask(pid_t pid, audit_token_t *token) {
    mach_port_t task = MACH_PORT_NULL;
    if (task_name_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) { errno = ESRCH; return -1; }
    mach_msg_type_number_t count = TASK_AUDIT_TOKEN_COUNT;
    kern_return_t result = task_info(task, TASK_AUDIT_TOKEN, (task_info_t)token, &count);
    mach_port_deallocate(mach_task_self(), task);
    if (result != KERN_SUCCESS) { errno = ESRCH; return -1; }
    return 0;
}

static inline BOOL FCSameProcess(const audit_token_t *a, const audit_token_t *b) {
    return a->val[5] == b->val[5] && a->val[7] == b->val[7];
}

static inline BOOL FCProcessExited(pid_t pid, const audit_token_t *token) {
    audit_token_t now;
    return FCProcessToken(pid, &now) != 0 || !FCSameProcess(token, &now);
}

// nil means the snapshot cannot prove anything; a full buffer may have been truncated.
static inline NSArray<NSNumber *> *FCRunningPids(void) {
    const int maxPids = 65536;
    int count = proc_listallpids(NULL, 0);
    if (count <= 0 || count > maxPids - 64) return nil;
    int capacity = count + 64;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (!pids) return nil;
    count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (count <= 0 || count >= capacity) { free(pids); return nil; }
    NSMutableArray *found = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (int i = 0; i < count; i++) if (pids[i] > 1) [found addObject:@(pids[i])];
    free(pids);
    return found;
}

// Flash Cores other than `keep` and this process; `unknown` collects processes whose identity cannot be read.
static inline NSArray<NSNumber *> *FCFlashCoreProcesses(pid_t keep, NSMutableArray<NSString *> *unknown) {
    NSArray<NSNumber *> *pids = FCRunningPids();
    if (!pids) return nil;
    NSMutableArray *found = [NSMutableArray array];
    for (NSNumber *number in pids) {
        pid_t pid = number.intValue;
        if (pid == keep || pid == getpid()) continue;
        NSString *reason = nil;
        FCCoreMatch match = FCRunningFlashCore(pid, &reason);
        if (match == FCCoreMatchFlash) [found addObject:number];
        else if (match == FCCoreMatchUnknown)
            [unknown addObject:[NSString stringWithFormat:@"pid %d: %@", pid, reason ?: @"identity unreadable"]];
    }
    return found;
}

// Identity is checked between two tokens of the same lifetime, so it describes the process the signal reaches.
static inline NSString *FCStopFlashCore(pid_t pid, BOOL *stopped) {
    *stopped = NO;
    audit_token_t token;
    if (FCProcessToken(pid, &token)) return nil;
    NSString *reason = nil;
    FCCoreMatch match = FCRunningFlashCore(pid, &reason);
    if (match == FCCoreMatchUnknown) return [NSString stringWithFormat:@"pid %d: %@", pid, reason ?: @"identity unreadable"];
    if (match != FCCoreMatchFlash || FCProcessExited(pid, &token)) return nil;
    for (int signal = SIGTERM; ; signal = SIGKILL) {
        if (proc_signal_with_audittoken(&token, signal) && errno != ESRCH)
            return [NSString stringWithFormat:@"pid %d: signal %d errno=%d", pid, signal, errno];
        for (int i = 0; i < 40; i++) {
            if (FCProcessExited(pid, &token)) { *stopped = YES; return nil; }
            FCSweepPause();
        }
        if (signal == SIGKILL) return [NSString stringWithFormat:@"pid %d: still running after SIGKILL", pid];
        match = FCRunningFlashCore(pid, &reason);
        if (FCProcessExited(pid, &token)) { *stopped = YES; return nil; }
        if (match == FCCoreMatchOther) return nil;
        if (match != FCCoreMatchFlash) return [NSString stringWithFormat:@"pid %d: %@", pid, reason ?: @"identity unreadable"];
    }
}

// Stops every Flash Core except `keep` and enumerates again to confirm. Never trusts a path: an old Core may
// run from a previous bundle or a deleted staged copy. Outcome: none, stopped or unconfirmed (with reason).
static inline NSDictionary *FCRetireFlashCores(pid_t keep) {
    NSMutableArray<NSString *> *unknown = [NSMutableArray array];
    NSArray<NSNumber *> *cores = FCFlashCoreProcesses(keep, unknown);
    if (!cores) return @{@"outcome": @"unconfirmed", @"stopped": @0, @"reason": @"process enumeration failed"};
    NSUInteger stopped = 0;
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    for (NSNumber *pid in cores) {
        BOOL done = NO;
        NSString *failure = FCStopFlashCore(pid.intValue, &done);
        if (failure) [failures addObject:failure];
        if (done) stopped++;
    }
    [unknown removeAllObjects];
    NSArray<NSNumber *> *remaining = FCFlashCoreProcesses(keep, unknown);
    if (!remaining) [failures addObject:@"process enumeration failed"];
    for (NSNumber *pid in remaining) [failures addObject:[NSString stringWithFormat:@"pid %@: Flash Core still running", pid]];
    [failures addObjectsFromArray:unknown];
    if (failures.count) {
        NSString *reason = [failures componentsJoinedByString:@"; "];
        if (reason.length > 1000) reason = [reason substringToIndex:1000];
        return @{@"outcome": @"unconfirmed", @"stopped": @(stopped), @"reason": reason};
    }
    return @{@"outcome": stopped ? @"stopped" : @"none", @"stopped": @(stopped), @"reason": @""};
}
