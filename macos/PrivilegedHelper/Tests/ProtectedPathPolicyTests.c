#include "../../Shared/ProtectedPathPolicy.h"
#include <assert.h>
#include <stdio.h>
#include <uuid/uuid.h>

int main(void) {
    acl_t empty = acl_init(0);
    assert(empty != NULL);
    assert(FCACLEmpty(empty));
    acl_t present = acl_init(1);
    assert(present != NULL);
    acl_entry_t entry;
    assert(acl_create_entry(&present, &entry) == 0);
    assert(!FCACLEmpty(present));
    assert(!FCACLEmpty(NULL));
    assert(!FCACLEmptyResult(false, -1, EINVAL));
    assert(!FCACLEmptyResult(true, 0, 0));
    assert(!FCACLEmptyResult(true, -1, EIO));
    assert(!FCACLEmptyResult(true, -1, ENOENT));
    assert(!FCACLEmptyResult(true, -1, 0));
    assert(FCACLEmptyResult(true, -1, EINVAL));
    for (int deny = 0; deny < 2; deny++) {
        acl_t valid = acl_init(1);
        assert(valid != NULL);
        acl_entry_t ace;
        assert(acl_create_entry(&valid, &ace) == 0);
        assert(acl_set_tag_type(ace, deny ? ACL_EXTENDED_DENY : ACL_EXTENDED_ALLOW) == 0);
        uuid_t subject = {0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef};
        assert(acl_set_qualifier(ace, subject) == 0);
        acl_permset_t permissions;
        assert(acl_get_permset(ace, &permissions) == 0);
        assert(acl_clear_perms(permissions) == 0);
        assert(acl_add_perm(permissions, ACL_WRITE_DATA) == 0);
        assert(acl_valid(valid) == 0);
        assert(!FCACLEmpty(valid));
        acl_free(valid);
    }
    acl_free(empty);
    acl_free(present);
    puts("30 Darwin ACL assertions passed; in-memory ACLs only, no filesystem ACLs accessed");
}
