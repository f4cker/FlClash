#include "../RemovalPolicy.h"
#include <assert.h>
#include <stdio.h>

static unsigned checks;
#define CHECK(condition) do { assert(condition); checks++; } while (0)

int main(void) {
    struct {
        const char *interruption;
        FCRemovalSnapshot durable;
        FCRemovalAction resume;
    } fixtures[] = {
        {"before authenticated handoff", {FCRemovalPending, FCRemovalMatching, FCRemovalAbsent, FCRemovalMatching, false}, FCRemovalHandoff},
        {"after authenticated handoff, before bootout", {FCRemovalStopped, FCRemovalMatching, FCRemovalAbsent, FCRemovalMatching, false}, FCRemovalHandoff},
        {"after bootout and confirmed quiescence", {FCRemovalStopped, FCRemovalMatching, FCRemovalAbsent, FCRemovalMatching, true}, FCRemovalRetire},
        {"after durable ready, before atomic retirement", {FCRemovalReady, FCRemovalMatching, FCRemovalAbsent, FCRemovalMatching, true}, FCRemovalRetire},
        {"after atomic retirement, before phase write", {FCRemovalReady, FCRemovalAbsent, FCRemovalMatching, FCRemovalMatching, true}, FCRemovalRecordRetired},
        {"after durable retirement, before cleanup authorization", {FCRemovalRetired, FCRemovalAbsent, FCRemovalMatching, FCRemovalMatching, true}, FCRemovalClean},
        {"after cleanup authorization, before plist unlink", {FCRemovalCleaning, FCRemovalAbsent, FCRemovalMatching, FCRemovalMatching, true}, FCRemovalClean},
        {"after plist unlink, before tombstone cleanup", {FCRemovalCleaning, FCRemovalAbsent, FCRemovalMatching, FCRemovalAbsent, true}, FCRemovalClean},
        {"during recursive tombstone deletion, installed tool absent", {FCRemovalCleaning, FCRemovalAbsent, FCRemovalProtectedPartial, FCRemovalAbsent, true}, FCRemovalClean},
        {"after tombstone deletion, before cleaned write", {FCRemovalCleaning, FCRemovalAbsent, FCRemovalAbsent, FCRemovalAbsent, true}, FCRemovalClean},
        {"after cleaned write, before runtime cleanup", {FCRemovalCleaned, FCRemovalAbsent, FCRemovalAbsent, FCRemovalAbsent, true}, FCRemovalFinish},
        {"after runtime cleanup, before state unlink", {FCRemovalCleaned, FCRemovalAbsent, FCRemovalAbsent, FCRemovalAbsent, true}, FCRemovalFinish},
    };
    for (unsigned i = 0; i < sizeof(fixtures) / sizeof(fixtures[0]); i++) {
        FCRemovalSnapshot state = fixtures[i].durable;
        CHECK(FCClassifyRemoval(state) == fixtures[i].resume);
        state.quiescent = false;
        FCRemovalAction blocked = FCClassifyRemoval(state);
        CHECK(blocked == FCRemovalReject || blocked == FCRemovalHandoff);
        state = fixtures[i].durable;
        state.installed = FCRemovalUntrusted;
        CHECK(FCClassifyRemoval(state) == FCRemovalReject);
        state = fixtures[i].durable;
        state.tombstone = FCRemovalUntrusted;
        CHECK(FCClassifyRemoval(state) == FCRemovalReject);
        state = fixtures[i].durable;
        state.plist = FCRemovalUntrusted;
        CHECK(FCClassifyRemoval(state) == FCRemovalReject);
    }
    for (FCRemovalPhase phase = FCRemovalNone; phase <= FCRemovalCleaned; phase++) {
        FCRemovalSnapshot partial = {phase, FCRemovalAbsent, FCRemovalProtectedPartial, FCRemovalAbsent, true};
        CHECK(FCClassifyRemoval(partial) == (phase == FCRemovalCleaning ? FCRemovalClean : FCRemovalReject));
        FCRemovalSnapshot occupied = {phase, FCRemovalMatching, FCRemovalMatching, FCRemovalMatching, true};
        CHECK(FCClassifyRemoval(occupied) == FCRemovalReject);
        FCRemovalSnapshot missing = {phase, FCRemovalAbsent, FCRemovalAbsent, FCRemovalAbsent, true};
        FCRemovalAction expected = phase == FCRemovalCleaning ? FCRemovalClean : phase == FCRemovalCleaned ? FCRemovalFinish : FCRemovalReject;
        CHECK(FCClassifyRemoval(missing) == expected);
    }
    CHECK(FCRemovalPhaseFromName(NULL) == FCRemovalNone);
    CHECK(FCRemovalPhaseFromName("committed") == FCRemovalNone);
    CHECK(FCRemovalPhaseFromName("unknown") == FCRemovalNone);
    CHECK(FCRemovalPhaseFromName("remove-pending") == FCRemovalPending);
    CHECK(FCRemovalPhaseFromName("remove-stopped") == FCRemovalStopped);
    CHECK(FCRemovalPhaseFromName("remove-ready") == FCRemovalReady);
    CHECK(FCRemovalPhaseFromName("remove-retired") == FCRemovalRetired);
    CHECK(FCRemovalPhaseFromName("remove-cleaning") == FCRemovalCleaning);
    CHECK(FCRemovalPhaseFromName("remove-cleaned") == FCRemovalCleaned);
    CHECK(FCRemovalQuiescenceAllowed(true, true, false, true));
    CHECK(FCRemovalQuiescenceAllowed(true, true, true, false));
    CHECK(!FCRemovalQuiescenceAllowed(false, true, true, false));
    CHECK(!FCRemovalQuiescenceAllowed(true, false, true, false));
    CHECK(!FCRemovalQuiescenceAllowed(true, false, false, true));
    CHECK(!FCRemovalQuiescenceAllowed(true, true, false, false));
    printf("%u removal-policy assertions passed; production state classification only; no filesystem, tools, services, or children executed\n", checks);
}
