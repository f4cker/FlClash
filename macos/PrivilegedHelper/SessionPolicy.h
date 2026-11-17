#include <errno.h>
#include <stdbool.h>
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

static inline bool FCWaitOwnershipUnknown(pid_t result, int waitError) {
    return result < 0 && waitError != EINTR;
}
