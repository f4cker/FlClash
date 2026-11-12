#ifndef FC_PROTECTED_PATH_POLICY_H
#define FC_PROTECTED_PATH_POLICY_H
#include <sys/acl.h>
#include <errno.h>
#include <stdbool.h>

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
#endif
