#ifndef FC_REMOVAL_POLICY_H
#define FC_REMOVAL_POLICY_H
#include <stdbool.h>
#include <string.h>

typedef enum {
    FCRemovalNone, FCRemovalPending, FCRemovalStopped, FCRemovalReady,
    FCRemovalRetired, FCRemovalCleaning, FCRemovalCleaned,
} FCRemovalPhase;

typedef enum {
    FCRemovalAbsent, FCRemovalMatching, FCRemovalProtectedPartial, FCRemovalUntrusted,
} FCRemovalArtifact;

typedef enum {
    FCRemovalReject, FCRemovalHandoff, FCRemovalRetire, FCRemovalRecordRetired,
    FCRemovalClean, FCRemovalFinish,
} FCRemovalAction;

typedef struct {
    FCRemovalPhase phase;
    FCRemovalArtifact installed;
    FCRemovalArtifact tombstone;
    FCRemovalArtifact plist;
    bool quiescent;
} FCRemovalSnapshot;

static inline FCRemovalPhase FCRemovalPhaseFromName(const char *name) {
    static const char *names[] = {"", "remove-pending", "remove-stopped", "remove-ready",
                                  "remove-retired", "remove-cleaning", "remove-cleaned"};
    if (name) for (int phase = FCRemovalPending; phase <= FCRemovalCleaned; phase++)
        if (!strcmp(name, names[phase])) return (FCRemovalPhase)phase;
    return FCRemovalNone;
}

static inline bool FCRemovalQuiescenceAllowed(bool serviceAbsent, bool childJournalAbsent,
                                             bool runtimeAbsent, bool protectedFreezeOnly) {
    return serviceAbsent && childJournalAbsent && (runtimeAbsent || protectedFreezeOnly);
}

static inline FCRemovalAction FCClassifyRemoval(FCRemovalSnapshot state) {
    if (state.installed == FCRemovalMatching && state.tombstone == FCRemovalAbsent && state.plist == FCRemovalMatching) {
        if (state.phase == FCRemovalPending) return FCRemovalHandoff;
        if (state.phase == FCRemovalStopped || state.phase == FCRemovalReady)
            return state.quiescent ? FCRemovalRetire : FCRemovalHandoff;
    }
    if (!state.quiescent || state.installed != FCRemovalAbsent) return FCRemovalReject;
    if (state.phase == FCRemovalReady && state.tombstone == FCRemovalMatching && state.plist == FCRemovalMatching)
        return FCRemovalRecordRetired;
    if (state.phase == FCRemovalRetired && state.tombstone == FCRemovalMatching && state.plist == FCRemovalMatching)
        return FCRemovalClean;
    if (state.phase == FCRemovalCleaning &&
        (state.tombstone == FCRemovalAbsent || state.tombstone == FCRemovalMatching || state.tombstone == FCRemovalProtectedPartial) &&
        (state.plist == FCRemovalAbsent || state.plist == FCRemovalMatching)) return FCRemovalClean;
    if (state.phase == FCRemovalCleaned && state.tombstone == FCRemovalAbsent && state.plist == FCRemovalAbsent)
        return FCRemovalFinish;
    return FCRemovalReject;
}
#endif
