#pragma once
// Root-only runtime directory and verified Core copy for the SMAppService daemon.
// The app bundle (and so the bundled Core) is user-writable; root never executes it in place. The daemon
// copies Core through one O_NOFOLLOW descriptor into a root:wheel 0700 directory while hashing those exact
// bytes, checks the hash against the sealed contract, verifies the copy's signature, then executes the copy.
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <dirent.h>
#import <errno.h>
#import <fcntl.h>
#import <libproc.h>
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

static inline NSArray<NSNumber *> *FCStagedCoreProcesses(NSString *directory) {
    NSMutableArray *found = [NSMutableArray array];
    int count = proc_listallpids(NULL, 0);
    if (count <= 0) return found;
    pid_t *pids = calloc((size_t)count + 64, sizeof(pid_t));
    if (!pids) return found;
    count = proc_listallpids(pids, (int)(((size_t)count + 64) * sizeof(pid_t)));
    NSString *prefix = [directory stringByAppendingString:@"/core-"];
    for (int i = 0; i < count; i++) {
        char path[PROC_PIDPATHINFO_MAXSIZE];
        if (pids[i] > 1 && proc_pidpath(pids[i], path, sizeof(path)) > 0 && [@(path) hasPrefix:prefix])
            [found addObject:@(pids[i])];
    }
    free(pids);
    return found;
}

// Recovery after a daemon crash: any surviving Core copy is stopped (TERM, then KILL). YES when none remain.
static inline BOOL FCReapOrphanedCores(NSString *directory) {
    NSArray<NSNumber *> *running = FCStagedCoreProcesses(directory);
    if (!running.count) return YES;
    for (NSNumber *pid in running) kill(pid.intValue, SIGTERM);
    for (int i = 0; i < 30 && FCStagedCoreProcesses(directory).count; i++) usleep(100000);
    for (NSNumber *pid in FCStagedCoreProcesses(directory)) kill(pid.intValue, SIGKILL);
    for (int i = 0; i < 10 && FCStagedCoreProcesses(directory).count; i++) usleep(100000);
    return FCStagedCoreProcesses(directory).count == 0;
}
