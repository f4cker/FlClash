#include "../SessionPolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const char *session = "0123456789abcdef0123456789abcdef";
    int owner = 0, other = 1;
    assert(FCValidSession(session));
    assert(!FCValidSession(NULL));
    assert(!FCValidSession(""));
    assert(!FCValidSession("0123456789ABCDEF0123456789abcdef"));
    assert(!FCValidSession("/123456789abcdef0123456789abcdef"));
    assert(FCOwnsSession(&owner, &owner, 501, 501, session, session));
    assert(!FCOwnsSession(&owner, &other, 501, 501, session, session));
    assert(!FCOwnsSession(&owner, &owner, 501, 502, session, session));
    assert(!FCOwnsSession(&owner, &owner, 501, 501, session, "wrong"));
    assert(!FCOwnsSession(NULL, NULL, 501, 501, session, session));
    // stop from a later connection of the same user naming the running session.
    assert(FCMayStopSession(&owner, 501, 501, session, session));
    assert(!FCMayStopSession(&owner, 501, 502, session, session));
    assert(!FCMayStopSession(&owner, 501, 501, session, "0123456789abcdef0123456789abcde0"));
    assert(!FCMayStopSession(&owner, 501, 501, session, "wrong"));
    assert(!FCMayStopSession(&owner, 501, 501, session, NULL));
    assert(!FCMayStopSession(&owner, 501, 501, NULL, session));
    assert(!FCMayStopSession(NULL, 501, 501, session, session));
    assert(FCWaitOwnershipUnknown(-1, ECHILD));
    assert(!FCWaitOwnershipUnknown(-1, EINTR));
    assert(!FCWaitOwnershipUnknown(0, 0));
    // The frame the daemon writes to its Core when the app's connection drops.
    assert(strcmp(FCStopSigningCall, "{\"method\":\"mitm.stopSigning\"}") == 0);
    puts("21 session-policy assertions passed; no child processes or services used");
}
