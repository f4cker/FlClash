#include "../MaintenancePolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(FCMaintenanceReady(true, true, true, 0));
    assert(!FCMaintenanceReady(false, true, true, 0));
    assert(!FCMaintenanceReady(true, false, true, 0));
    assert(!FCMaintenanceReady(true, true, false, 0));
    assert(!FCMaintenanceReady(true, true, true, 42));
    assert(!FCMaintenanceReady(true, true, true, -1));
    assert(FCFirstInstallAllowed(true, true, true, true));
    assert(!FCFirstInstallAllowed(false, true, true, true));
    assert(!FCFirstInstallAllowed(true, false, true, true));
    assert(!FCFirstInstallAllowed(true, true, false, true));
    assert(!FCFirstInstallAllowed(true, true, true, false));
    assert(FCTransactionResumeAllowed(true, true, false));
    assert(FCTransactionResumeAllowed(true, false, true));
    assert(FCTransactionResumeAllowed(true, true, true));
    assert(!FCTransactionResumeAllowed(false, true, true));
    assert(!FCTransactionResumeAllowed(true, false, false));
    assert(FCTransactionCommitAllowed(true, true, true, true));
    assert(!FCTransactionCommitAllowed(false, true, true, true));
    assert(!FCTransactionCommitAllowed(true, false, true, true));
    assert(!FCTransactionCommitAllowed(true, true, false, true));
    assert(!FCTransactionCommitAllowed(true, true, true, false));
    struct {
        const char *phase;
        bool oldPresent;
        bool newPresent;
        bool resume;
    } failures[] = {
        {"payload-copy-interrupted", true, false, true},
        {"prepared-before-freeze", true, false, true},
        {"freeze-unconfirmed", true, false, true},
        {"after-confirmed-exit-before-swap", true, false, true},
        {"atomic-swap-before-state-write", false, true, true},
        {"plist-write-interrupted", false, true, true},
        {"committed-before-cleanup", false, true, true},
        {"unrecognized-installed-seal", false, false, false},
    };
    for (unsigned i = 0; i < sizeof(failures) / sizeof(failures[0]); i++) {
        assert(FCTransactionResumeAllowed(true, failures[i].oldPresent, failures[i].newPresent) == failures[i].resume);
        assert(!FCTransactionCommitAllowed(true, false, failures[i].oldPresent, true));
    }
    assert(FCEmptyLockRecoveryAllowed(true, true, true, false, false, true));
    assert(FCEmptyLockRecoveryAllowed(true, true, false, true, true, false));
    assert(!FCEmptyLockRecoveryAllowed(false, true, false, true, true, false));
    assert(!FCEmptyLockRecoveryAllowed(true, false, false, true, true, false));
    assert(!FCEmptyLockRecoveryAllowed(true, true, false, false, true, false));
    assert(!FCEmptyLockRecoveryAllowed(true, true, false, true, false, false));
    assert(!FCEmptyLockRecoveryAllowed(true, true, true, false, false, false));
    puts("44 maintenance-policy assertions passed; no tools, services, or children executed");
}
