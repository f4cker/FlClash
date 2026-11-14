#ifndef FC_MAINTENANCE_POLICY_H
#define FC_MAINTENANCE_POLICY_H
#include <stdbool.h>
#include <sys/types.h>

static inline bool FCMaintenanceReady(bool authenticated, bool frozen, bool exitConfirmed, pid_t child) {
    return authenticated && frozen && exitConfirmed && child == 0;
}

static inline bool FCFirstInstallAllowed(bool bundleAbsent, bool plistAbsent, bool runtimeAbsent, bool serviceAbsent) {
    return bundleAbsent && plistAbsent && runtimeAbsent && serviceAbsent;
}

static inline bool FCTransactionResumeAllowed(bool protectedState, bool currentIsOld, bool currentIsNew) {
    return protectedState && (currentIsOld || currentIsNew);
}

static inline bool FCTransactionCommitAllowed(bool prepared, bool quiescent, bool currentIsOld, bool incomingIsNew) {
    return prepared && quiescent && currentIsOld && incomingIsNew;
}

static inline bool FCEmptyLockRecoveryAllowed(bool explicitRepair, bool protectedEmptyLock, bool installedAbsent,
                                            bool installedTrusted, bool plistTrusted, bool firstInstallSafe) {
    return explicitRepair && protectedEmptyLock &&
        (installedAbsent ? firstInstallSafe : installedTrusted && plistTrusted);
}
#endif
