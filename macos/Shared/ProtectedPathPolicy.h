#ifndef FC_PROTECTED_PATH_POLICY_H
#define FC_PROTECTED_PATH_POLICY_H
#include <sys/acl.h>
#include <sys/stat.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>

static inline bool FCACLEmptyResult(bool validated, int result, int error) {
    return validated && result == -1 && error == EINVAL;
}

static inline bool FCACLEmpty(acl_t acl) {
    if (!acl || acl_valid(acl) != 0) return false;
    acl_entry_t entry;
    errno = 0;
    int result = acl_get_entry(acl, ACL_FIRST_ENTRY, &entry);
    // Darwin returns 0 for an entry; only validated exhaustion is empty.
    return FCACLEmptyResult(true, result, errno);
}

static inline bool FCACLReadEmptyResult(acl_t acl, int error, const struct stat *before, const struct stat *after) {
    if (!before || !after || before->st_nlink == 0 || after->st_nlink == 0 ||
        before->st_dev != after->st_dev || before->st_ino != after->st_ino ||
        before->st_mode != after->st_mode || before->st_uid != after->st_uid ||
        before->st_gid != after->st_gid || before->st_nlink != after->st_nlink ||
        before->st_flags != after->st_flags ||
        before->st_ctimespec.tv_sec != after->st_ctimespec.tv_sec ||
        before->st_ctimespec.tv_nsec != after->st_ctimespec.tv_nsec) return false;
    // Darwin also reports ENOENT when an existing unchanged node has no ACL.
    return acl ? FCACLEmpty(acl) : error == ENOENT;
}

static inline bool FCPathACLEmpty(const char *path, const struct stat *before) {
    if (!path || !before) return false;
    errno = 0;
    acl_t acl = S_ISLNK(before->st_mode) ? acl_get_link_np(path, ACL_TYPE_EXTENDED) : acl_get_file(path, ACL_TYPE_EXTENDED);
    int error = errno;
    struct stat after;
    bool exists = lstat(path, &after) == 0;
    bool empty = FCACLReadEmptyResult(acl, error, before, exists ? &after : NULL);
    if (acl) acl_free(acl);
    return empty;
}
#endif
