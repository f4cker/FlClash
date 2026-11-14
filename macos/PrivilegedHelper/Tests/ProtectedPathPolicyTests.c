#include <sys/acl.h>
#include <sys/stat.h>
static int FCFixtureLstat(const char *path, struct stat *state);
static acl_t FCFixtureACLGetFile(const char *path, acl_type_t type);
static acl_t FCFixtureACLGetLink(const char *path, acl_type_t type);
#define lstat FCFixtureLstat
#define acl_get_file FCFixtureACLGetFile
#define acl_get_link_np FCFixtureACLGetLink
#include "../../Shared/ProtectedPathPolicy.h"
#undef lstat
#undef acl_get_file
#undef acl_get_link_np
#include <assert.h>
#include <stdio.h>
#include <uuid/uuid.h>
#include <string.h>

static unsigned checks, fileReads, linkReads;
#define CHECK(condition) do { assert(condition); checks++; } while (0)
static struct stat fixtureNode;
static acl_t fixtureACL;
static int fixtureACLError, fixtureStatError;

static int FCFixtureLstat(const char *path, struct stat *state) {
    CHECK(strcmp(path, "synthetic-only") == 0);
    if (fixtureStatError) { errno = fixtureStatError; return -1; }
    *state = fixtureNode;
    return 0;
}

static acl_t FCFixtureACLRead(const char *path, acl_type_t type) {
    CHECK(strcmp(path, "synthetic-only") == 0 && type == ACL_TYPE_EXTENDED);
    if (!fixtureACL) { errno = fixtureACLError; return NULL; }
    acl_t result = acl_dup(fixtureACL);
    CHECK(result != NULL);
    return result;
}

static acl_t FCFixtureACLGetFile(const char *path, acl_type_t type) {
    fileReads++;
    return FCFixtureACLRead(path, type);
}

static acl_t FCFixtureACLGetLink(const char *path, acl_type_t type) {
    linkReads++;
    return FCFixtureACLRead(path, type);
}

static void FCCheckAbsentACL(void) {
    struct stat before = {.st_dev = 1, .st_ino = 42, .st_mode = S_IFREG | 0644,
                          .st_uid = 0, .st_gid = 0, .st_nlink = 1,
                          .st_ctimespec = {.tv_sec = 123, .tv_nsec = 456}};
    fixtureNode = before;
    fixtureACLError = ENOENT;
    CHECK(FCPathACLEmpty("synthetic-only", &before));
    CHECK(fileReads == 1 && linkReads == 0);
    before.st_mode = S_IFDIR | 0755;
    fixtureNode = before;
    CHECK(FCPathACLEmpty("synthetic-only", &before));
    CHECK(fileReads == 2 && linkReads == 0);
    before.st_mode = S_IFLNK | 0777;
    fixtureNode = before;
    CHECK(FCPathACLEmpty("synthetic-only", &before));
    CHECK(fileReads == 2 && linkReads == 1);
    fixtureStatError = ENOENT;
    CHECK(!FCPathACLEmpty("synthetic-only", &before));
    fixtureStatError = EACCES;
    CHECK(!FCPathACLEmpty("synthetic-only", &before));
    fixtureStatError = 0;
    int errors[] = {0, EIO, EACCES, EINVAL, ENOTSUP};
    for (unsigned i = 0; i < sizeof(errors) / sizeof(errors[0]); i++) {
        fixtureACLError = errors[i];
        CHECK(!FCPathACLEmpty("synthetic-only", &before));
    }
    fixtureACLError = ENOENT;
    for (unsigned change = 0; change < 9; change++) {
        fixtureNode = before;
        switch (change) {
            case 0: fixtureNode.st_dev++; break;
            case 1: fixtureNode.st_ino++; break;
            case 2: fixtureNode.st_mode ^= S_IWOTH; break;
            case 3: fixtureNode.st_uid++; break;
            case 4: fixtureNode.st_gid++; break;
            case 5: fixtureNode.st_nlink++; break;
            case 6: fixtureNode.st_flags++; break;
            case 7: fixtureNode.st_ctimespec.tv_sec++; break;
            case 8: fixtureNode.st_ctimespec.tv_nsec++; break;
        }
        CHECK(!FCPathACLEmpty("synthetic-only", &before));
    }
    fixtureNode = before;
    fixtureNode.st_nlink = 0;
    CHECK(!FCPathACLEmpty("synthetic-only", &before));
    before.st_nlink = 0;
    CHECK(!FCPathACLEmpty("synthetic-only", &before));
    CHECK(!FCPathACLEmpty("synthetic-only", NULL));
    CHECK(!FCPathACLEmpty(NULL, &before));
    CHECK(!FCACLReadEmptyResult(NULL, ENOENT, NULL, &fixtureNode));
    CHECK(!FCACLReadEmptyResult(NULL, ENOENT, &before, NULL));
    before.st_nlink = 1;
    fixtureNode = before;
}

int main(void) {
    FCCheckAbsentACL();
    acl_t empty = acl_init(0);
    CHECK(empty != NULL);
    CHECK(FCACLEmpty(empty));
    fixtureACL = empty;
    CHECK(FCPathACLEmpty("synthetic-only", &fixtureNode));
    fixtureACL = NULL;
    acl_t present = acl_init(1);
    CHECK(present != NULL);
    acl_entry_t entry;
    CHECK(acl_create_entry(&present, &entry) == 0);
    CHECK(!FCACLEmpty(present));
    CHECK(!FCACLEmpty(NULL));
    CHECK(!FCACLEmptyResult(false, -1, EINVAL));
    CHECK(!FCACLEmptyResult(true, 0, 0));
    CHECK(!FCACLEmptyResult(true, -1, EIO));
    CHECK(!FCACLEmptyResult(true, -1, ENOENT));
    CHECK(!FCACLEmptyResult(true, -1, 0));
    CHECK(FCACLEmptyResult(true, -1, EINVAL));
    for (int deny = 0; deny < 2; deny++) {
        acl_t valid = acl_init(1);
        CHECK(valid != NULL);
        acl_entry_t ace;
        CHECK(acl_create_entry(&valid, &ace) == 0);
        CHECK(acl_set_tag_type(ace, deny ? ACL_EXTENDED_DENY : ACL_EXTENDED_ALLOW) == 0);
        uuid_t subject = {0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef};
        CHECK(acl_set_qualifier(ace, subject) == 0);
        acl_permset_t permissions;
        CHECK(acl_get_permset(ace, &permissions) == 0);
        CHECK(acl_clear_perms(permissions) == 0);
        CHECK(acl_add_perm(permissions, ACL_WRITE_DATA) == 0);
        CHECK(acl_valid(valid) == 0);
        CHECK(!FCACLEmpty(valid));
        fixtureACL = valid;
        CHECK(!FCPathACLEmpty("synthetic-only", &fixtureNode));
        fixtureACL = NULL;
        acl_free(valid);
    }
    acl_free(empty);
    acl_free(present);
    printf("%u Darwin ACL assertions passed; synthetic stat/ACL-fetch outcomes and in-memory ACLs only, no filesystem paths accessed\n", checks);
}
