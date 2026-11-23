#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>

static inline bool FCValidSession(const char *session) {
    if (!session || strlen(session) != 32) return false;
    for (int i = 0; i < 32; i++) {
        if (!((session[i] >= '0' && session[i] <= '9') ||
              (session[i] >= 'a' && session[i] <= 'f'))) return false;
    }
    return true;
}

static inline bool FCOwnsSession(const void *owner, const void *caller, uid_t uid,
                                 uid_t callerUID, const char *session, const char *requested) {
    return owner && owner == caller && uid == callerUID && session && requested &&
        strcmp(session, requested) == 0;
}

// `stop` alone may also come from a later connection of the same user that names the running session: the
// app's connection can be reset (a request timed out) while its Core still runs, and the new connection must
// be able to end it. The caller's identity is still checked per message (FCGUIMessageValidator) first;
// relay traffic (send/receive) stays bound to the owning connection through FCOwnsSession.
static inline bool FCMayStopSession(const void *owner, uid_t uid, uid_t callerUID, const char *session,
                                    const char *requested) {
    return owner && uid == callerUID && session && requested && FCValidSession(requested) &&
        strcmp(session, requested) == 0;
}

static inline bool FCRelayAction(const char *method) {
    return method && (strcmp(method, "send") == 0 || strcmp(method, "receive") == 0);
}

// Relay traffic may move to a new connection only from the very app process that started the running session
// (audit token pid and pid version), of the same user, naming the session.
static inline bool FCMayAdoptSession(const void *owner, bool coreRunning, pid_t ownerPid, uint32_t ownerPidVersion,
                                     pid_t callerPid, uint32_t callerPidVersion, uid_t uid, uid_t callerUID,
                                     const char *session, const char *requested) {
    return owner && coreRunning && ownerPid > 0 && callerPid == ownerPid && callerPidVersion == ownerPidVersion &&
        uid == callerUID && session && requested && FCValidSession(requested) && strcmp(session, requested) == 0;
}

// A GUI check that failed only because the kernel could not be read (FCGUIMessageValidator's kernel steps).
static inline bool FCGUIReadFailure(const char *failure) {
    return failure && (strncmp(failure, "status-read ", 12) == 0 || strncmp(failure, "cdhash-read ", 12) == 0);
}

// Written to the Core when the app's connection drops (core/protocol.go mitmStopSigningMethod): it clears the MITM CA
// the app handed over, so nothing is signed while no app vouches for it.
static const char FCStopSigningCall[] = "{\"method\":\"mitm.stopSigning\"}";

static inline bool FCWaitOwnershipUnknown(pid_t result, int waitError) {
    return result < 0 && waitError != EINTR;
}
