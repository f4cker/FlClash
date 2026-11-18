// FlashHelperLauncher: the fixed BundleProgram of the Flash daemon. launchd pins the job's launch constraint to
// this file's cdhash, so it never changes; it copies, verifies, version-checks and execs the bundled FlashHelper.
// See README.md. Every constant is final: changing this file means registering the daemon under a new name.
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <errno.h>
#include <fcntl.h>
#include <libproc.h>
#include <limits.h>
#include <os/log.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifdef FLASH_LAUNCHER_TEST
#define FL_OWNER ((uid_t)FL_TEST_UID)
#define FL_PARENT FL_TEST_PARENT
#define FL_REQUIREMENT "identifier \"com.layoute.flash.helper\""
#else
#define FL_OWNER ((uid_t)0)
#define FL_PARENT "/Library/Application Support"
#define FL_REQUIREMENT "anchor H\"BBA7F8529FD271B9848EC03A2CE3F4780F585556\" and " \
    "certificate leaf = H\"BBA7F8529FD271B9848EC03A2CE3F4780F585556\" and identifier \"com.layoute.flash.helper\""
#endif

#define FL_STATE_NAME "com.layoute.flash.helperd"
#define FL_STATUS_NAME "com.layoute.flash.helperd-status"
#define FL_COPY_NAME "FlashHelper"
#define FL_COPY_TEMP ".FlashHelper.tmp"
#define FL_COPY_PATH FL_PARENT "/" FL_STATE_NAME "/" FL_COPY_NAME
#define FL_RECORD_NAME "max-version"
#define FL_RECORD_TEMP ".max-version.tmp"
#define FL_STATUS_FILE "launcher.json"
#define FL_STATUS_TEMP ".launcher.json.tmp"
#define FL_SELF_SUFFIX "/Contents/Library/HelperTools/FlashHelperLauncher"
#define FL_HELPER_RELATIVE "/Contents/Library/HelperTools/FlashHelper"
#define FL_BUNDLE_ARGUMENT "--flash-bundle"
#define FL_LAUNCHER_VERSION 1
#define FL_MAX_HELPER_BYTES (256LL * 1024 * 1024)
#define FL_COPY_FLAGS (kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)

enum {
    FL_OK = 0,
    FL_NOT_ROOT = 81,
    FL_LOCATION = 82,
    FL_COPY = 83,
    FL_SIGNATURE = 84,
    FL_VERSION = 85,
    FL_DOWNGRADE = 86,
    FL_EXEC = 87,
};

static const char *const fl_results[] = {
    "ok", "not_root", "location", "copy", "signature", "version_unreadable", "downgrade", "exec",
};

static uint64_t fl_helper_version, fl_recorded_version;
static bool fl_has_helper_version, fl_has_recorded_version;

static bool fl_write_all(int fd, const void *data, size_t length) {
    const char *bytes = data;
    while (length > 0) {
        ssize_t written = write(fd, bytes, length);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return false;
        bytes += written;
        length -= (size_t)written;
    }
    return true;
}

static bool fl_parse_version(const char *text, size_t length, uint64_t *value) {
    if (length == 0 || length > 20) return false;
    uint64_t result = 0;
    for (size_t i = 0; i < length; i++) {
        if (text[i] < '0' || text[i] > '9') return false;
        uint64_t digit = (uint64_t)(text[i] - '0');
        if (result > (UINT64_MAX - digit) / 10) return false;
        result = result * 10 + digit;
    }
    *value = result;
    return true;
}

static bool fl_directory_safe(const struct stat *state, mode_t forbidden) {
    return S_ISDIR(state->st_mode) && state->st_uid == FL_OWNER && (state->st_mode & forbidden) == 0;
}

static int fl_open_parent(void) {
    int fd = open(FL_PARENT, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    struct stat state;
    if (fd >= 0 && (fstat(fd, &state) || !fl_directory_safe(&state, 022))) {
        close(fd);
        errno = EPERM;
        return -1;
    }
    return fd;
}

// Returns NULL with *out open on success, otherwise a short reason; errno is 0 for a policy refusal.
static const char *fl_open_child(int parent, const char *name, mode_t mode, mode_t forbidden, int *out) {
    if (mkdirat(parent, name, mode) && errno != EEXIST) return "mkdir";
    struct stat link, opened;
    if (fstatat(parent, name, &link, AT_SYMLINK_NOFOLLOW)) return "lstat";
    errno = 0;
    if (S_ISLNK(link.st_mode)) return "is a symlink";
    if (!S_ISDIR(link.st_mode)) return "not a directory";
    if (link.st_uid != FL_OWNER) return "wrong owner";
    if (link.st_mode & forbidden) return "mode too wide";
    int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) return "open";
    if (fstat(fd, &opened) || opened.st_dev != link.st_dev || opened.st_ino != link.st_ino ||
        !fl_directory_safe(&opened, forbidden)) {
        close(fd);
        errno = 0;
        return "changed while opening";
    }
    *out = fd;
    return NULL;
}

static int fl_create(int dir, const char *temporary, mode_t mode) {
    if (unlinkat(dir, temporary, 0) && errno != ENOENT) return -1;
    return openat(dir, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode);
}

static bool fl_commit(int dir, int fd, const char *temporary, const char *name, mode_t mode, bool ok) {
    ok = ok && fchmod(fd, mode) == 0 && fsync(fd) == 0;
    int saved = errno;
    close(fd);
    if (ok && renameat(dir, temporary, dir, name) == 0) return fsync(dir) == 0;
    if (ok) saved = errno;
    unlinkat(dir, temporary, 0);
    errno = saved;
    return false;
}

static bool fl_store(int dir, const char *temporary, const char *name, mode_t mode, const char *text) {
    int fd = fl_create(dir, temporary, mode);
    return fd >= 0 && fl_commit(dir, fd, temporary, name, mode, fl_write_all(fd, text, strlen(text)));
}

static void fl_write_status(const char *json) {
    int parent = fl_open_parent(), status = -1;
    if (parent < 0) return;
    if (!fl_open_child(parent, FL_STATUS_NAME, 0755, 022, &status)) {
        if (fchmod(status, 0755) == 0) fl_store(status, FL_STATUS_TEMP, FL_STATUS_FILE, 0644, json);
        close(status);
    }
    close(parent);
}

// Details are built only from literals and numbers, so they need no JSON escaping.
static void fl_report(int code, const char *detail) {
    const char *result = fl_results[code == FL_OK ? 0 : code - FL_NOT_ROOT + 1];
    char helper[24] = "null", recorded[24] = "null", json[512];
    if (fl_has_helper_version) snprintf(helper, sizeof(helper), "%llu", (unsigned long long)fl_helper_version);
    if (fl_has_recorded_version)
        snprintf(recorded, sizeof(recorded), "%llu", (unsigned long long)fl_recorded_version);
    snprintf(json, sizeof(json),
        "{\"v\":1,\"result\":\"%s\",\"detail\":\"%s\",\"helperVersion\":%s,\"recordedVersion\":%s,"
        "\"launcherVersion\":%d,\"time\":%lld}\n",
        result, detail, helper, recorded, FL_LAUNCHER_VERSION, (long long)time(NULL));
    os_log_with_type(os_log_create("com.layoute.flash.launcher", "launcher"),
        code == FL_OK ? OS_LOG_TYPE_DEFAULT : OS_LOG_TYPE_ERROR, "%{public}s: %{public}s", result, detail);
    fl_write_status(json);
}

__attribute__((noreturn, format(printf, 2, 3)))
static void fl_fail(int code, const char *format, ...) {
    char detail[160];
    va_list arguments;
    va_start(arguments, format);
    vsnprintf(detail, sizeof(detail), format, arguments);
    va_end(arguments);
    fl_report(code, detail);
    exit(code);
}

static const char *fl_copy(int state, const char *source) {
    int input = open(source, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (input < 0) return "open source";
    struct stat info;
    if (fstat(input, &info) || !S_ISREG(info.st_mode) || info.st_size <= 0 || info.st_size > FL_MAX_HELPER_BYTES) {
        close(input);
        errno = 0;
        return "source not a regular file";
    }
    int output = fl_create(state, FL_COPY_TEMP, 0500);
    if (output < 0) {
        close(input);
        return "create copy";
    }
    char buffer[65536];
    long long total = 0;
    bool ok = true;
    while (ok) {
        ssize_t count = read(input, buffer, sizeof(buffer));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            ok = count == 0;
            break;
        }
        total += count;
        ok = fl_write_all(output, buffer, (size_t)count);
        if (total > info.st_size) break;
    }
    close(input);
    if (ok && total != info.st_size) {
        ok = false;
        errno = 0;
    }
    return fl_commit(state, output, FL_COPY_TEMP, FL_COPY_NAME, 0500, ok) ? NULL : "write copy";
}

static OSStatus fl_check_signature(SecStaticCodeRef *code) {
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)FL_COPY_PATH,
        (CFIndex)strlen(FL_COPY_PATH), false);
    if (!url) return errSecAllocate;
    SecRequirementRef requirement = NULL;
    OSStatus status = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, code);
    CFRelease(url);
    if (status == errSecSuccess)
        status = SecRequirementCreateWithString(CFSTR(FL_REQUIREMENT), kSecCSDefaultFlags, &requirement);
    if (status == errSecSuccess) status = SecStaticCodeCheckValidityWithErrors(*code, FL_COPY_FLAGS, requirement, NULL);
    if (requirement) CFRelease(requirement);
    return status;
}

static bool fl_read_helper_version(SecStaticCodeRef code, uint64_t *version) {
    CFDictionaryRef info = NULL;
    bool ok = false;
    if (SecCodeCopySigningInformation(code, kSecCSDefaultFlags, &info) == errSecSuccess && info) {
        CFTypeRef plist = CFDictionaryGetValue(info, kSecCodeInfoPList);
        CFTypeRef value = plist && CFGetTypeID(plist) == CFDictionaryGetTypeID()
            ? CFDictionaryGetValue((CFDictionaryRef)plist, CFSTR("CFBundleVersion")) : NULL;
        char text[32];
        ok = value && CFGetTypeID(value) == CFStringGetTypeID() &&
            CFStringGetCString((CFStringRef)value, text, sizeof(text), kCFStringEncodingASCII) &&
            fl_parse_version(text, strlen(text), version);
    }
    if (info) CFRelease(info);
    return ok;
}

// 1 when a record exists, 0 when there is none, -1 when it cannot be trusted.
static int fl_read_record(int state, uint64_t *version) {
    int fd = openat(state, FL_RECORD_NAME, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return errno == ENOENT ? 0 : -1;
    struct stat info;
    char text[32];
    ssize_t length = -1;
    if (fstat(fd, &info) == 0 && S_ISREG(info.st_mode) && info.st_uid == FL_OWNER)
        length = read(fd, text, sizeof(text));
    close(fd);
    errno = 0;
    if (length > 0 && text[length - 1] == '\n') length--;
    return length > 0 && fl_parse_version(text, (size_t)length, version) ? 1 : -1;
}

static bool fl_same_file(const struct stat *a, const struct stat *b) {
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino && a->st_size == b->st_size &&
        a->st_mtimespec.tv_sec == b->st_mtimespec.tv_sec && a->st_mtimespec.tv_nsec == b->st_mtimespec.tv_nsec;
}

int main(void) {
    umask(022);
    if (getuid() != FL_OWNER || geteuid() != FL_OWNER)
        fl_fail(FL_NOT_ROOT, "uid=%u euid=%u", (unsigned)getuid(), (unsigned)geteuid());

    char self[PROC_PIDPATHINFO_MAXSIZE], bundle[PATH_MAX], source[PATH_MAX];
    if (proc_pidpath(getpid(), self, sizeof(self)) <= 0) fl_fail(FL_LOCATION, "proc_pidpath errno=%d", errno);
    if (!realpath(self, bundle)) fl_fail(FL_LOCATION, "realpath errno=%d", errno);
    size_t length = strlen(bundle), suffix = strlen(FL_SELF_SUFFIX);
    if (length <= suffix + 4 || strcmp(bundle + length - suffix, FL_SELF_SUFFIX) ||
        strncmp(bundle + length - suffix - 4, ".app", 4))
        fl_fail(FL_LOCATION, "launcher is not inside an app bundle");
    bundle[length - suffix] = '\0';
    if (snprintf(source, sizeof(source), "%s" FL_HELPER_RELATIVE, bundle) >= (int)sizeof(source))
        fl_fail(FL_LOCATION, "helper path too long");

    int parent = fl_open_parent(), state = -1;
    if (parent < 0) fl_fail(FL_COPY, "parent directory unsafe errno=%d", errno);
    const char *failure = fl_open_child(parent, FL_STATE_NAME, 0700, 077, &state);
    if (failure) fl_fail(FL_COPY, "state directory %s errno=%d", failure, errno);
    close(parent);
    if ((failure = fl_copy(state, source))) fl_fail(FL_COPY, "%s errno=%d", failure, errno);

    struct stat pinned, current;
    int copy = openat(state, FL_COPY_NAME, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (copy < 0 || fstat(copy, &pinned) || !S_ISREG(pinned.st_mode) || pinned.st_uid != FL_OWNER)
        fl_fail(FL_COPY, "reopen copy errno=%d", errno);
    SecStaticCodeRef code = NULL;
    OSStatus status = fl_check_signature(&code);
    if (status != errSecSuccess) fl_fail(FL_SIGNATURE, "copy rejected OSStatus=%d", (int)status);
    if (!fl_read_helper_version(code, &fl_helper_version))
        fl_fail(FL_VERSION, "CFBundleVersion is not an unsigned integer");
    fl_has_helper_version = true;
    CFRelease(code);

    int record = fl_read_record(state, &fl_recorded_version);
    if (record < 0) fl_fail(FL_VERSION, "max-version unreadable errno=%d", errno);
    fl_has_recorded_version = record == 1;
    if (fl_has_recorded_version && fl_helper_version < fl_recorded_version)
        fl_fail(FL_DOWNGRADE, "helper is older than the highest version run");
    if (!fl_has_recorded_version || fl_helper_version > fl_recorded_version) {
        char text[24];
        snprintf(text, sizeof(text), "%llu\n", (unsigned long long)fl_helper_version);
        if (!fl_store(state, FL_RECORD_TEMP, FL_RECORD_NAME, 0600, text))
            fl_fail(FL_VERSION, "max-version write errno=%d", errno);
    }

    fl_report(FL_OK, "verified");
    if (fstatat(state, FL_COPY_NAME, &current, AT_SYMLINK_NOFOLLOW) || !fl_same_file(&pinned, &current))
        fl_fail(FL_EXEC, "copy changed before exec errno=%d", errno);
    char *const arguments[] = {FL_COPY_PATH, FL_BUNDLE_ARGUMENT, bundle, NULL};
    execv(FL_COPY_PATH, arguments);
    fl_fail(FL_EXEC, "execv errno=%d", errno);
}
