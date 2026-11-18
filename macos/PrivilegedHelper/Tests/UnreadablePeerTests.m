// Real (nothing mocked) reproduction of the mitm.4 failure and check of its fix, without root: a peer runs from a
// directory this process cannot read (chmod 000 right after exec; in production the launcher's copy in the root
// 0700 /Library/Application Support/com.layoute.flash.helperd), and this process validates a reply from it.
//   1. What mitm.4 did (SecCodeCreateWithXPCMessage → SecCodeCheckValidity(kSecCSStrictValidate) →
//      SecCodeCopySigningInformation) and SecCodeCopyGuestWithAttributes by audit token or pid: expected to fail.
//   2. What the kernel answers anyway: csops_audittoken / csops (CS_OPS_STATUS, CS_OPS_CDHASH), proc_pidpath.
//   3. FCHelperGuestCheck (the fix) over that reply's audit token: verified, with the peer's static cdhash.
//   4. FCMessageValidator itself, the class the app uses, on real replies: as mitm.4 configured it for a peer it
//      cannot read (executable == sealed executable: Security path) it fails, naming SecCodeCheckValidity; as the
//      app now configures it (running copy unreadable, sealed copy readable: kernel path) it accepts, twice; a
//      sealed copy with other bytes makes the same reply "stale". The pinned certificate cannot be had here, so the
//      requirement is the peer's identifier and ad hoc is allowed (FCPinnedRequirement and
//      FCPinnedCodePolicy, set when compiling); every Security, kernel and file access is real.
// Usage: unreadable-peer <directory> <peer path in it> <XPC peer requirement> <readable copy of the peer>
//        <readable, differently built peer>. Prints one JSON object; exit 0 when
// every expectation held, 3 when the Security calls did not fail (the root cause is not reproduced), 1 otherwise.
#import "../../Shared/HelperTrust.h"
#import <libproc.h>
#import <signal.h>
#import <spawn.h>
#import <sys/stat.h>
#import <sys/wait.h>

extern char **environ;
mach_port_t xpc_endpoint_copy_listener_port_4sim(xpc_endpoint_t endpoint);
void xpc_dictionary_get_audit_token(xpc_object_t message, audit_token_t *token);
int csops_audittoken(pid_t pid, unsigned int ops, void *address, size_t size, audit_token_t *token);
int csops(pid_t pid, unsigned int ops, void *address, size_t size);

// Stands in for the pinned certificate requirement: the identifier only (the XPC peer requirement adds the cdhash).
NSString *TestPinnedRequirement(NSString *identifier) {
    return [identifier isEqualToString:@"com.layoute.flash.test.peer"] ? @"identifier \"com.layoute.flash.test.peer\"" : nil;
}
BOOL TestPinnedCodePolicy(NSDictionary *entitlements, uint32_t flags) {
    return (flags & kSecCodeSignatureRuntime) && !entitlements[@"com.apple.security.get-task-allow"];
}

static NSMutableDictionary *results;
static NSMutableArray<NSString *> *problems;

static void Expect(BOOL condition, NSString *what) {
    if (!condition) [problems addObject:what];
}

static NSData *StaticHash(NSString *path) {
    SecStaticCodeRef code = NULL;
    CFDictionaryRef info = NULL;
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &code)) return nil;
    SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info);
    CFRelease(code);
    NSDictionary *dictionary = CFBridgingRelease(info);
    return dictionary[(__bridge NSString *)kSecCodeInfoUnique];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 6) return 64;
        NSString *directory = @(argv[1]), *peer = @(argv[2]), *text = @(argv[3]);
        NSString *sealed = @(argv[4]), *otherBuild = @(argv[5]);
        results = [NSMutableDictionary dictionary];
        problems = [NSMutableArray array];
        NSData *staticHash = StaticHash(peer);
        if (staticHash.length != 20) { puts("{\"error\": \"no static cdhash\"}"); return 1; }
        dispatch_queue_t queue = dispatch_queue_create("unreadable-peer", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t listener = xpc_connection_create(NULL, queue);
        __block xpc_connection_t connection = NULL;
        dispatch_semaphore_t connected = dispatch_semaphore_create(0);
        xpc_connection_set_event_handler(listener, ^(xpc_object_t peerConnection) {
            if (xpc_get_type(peerConnection) != XPC_TYPE_CONNECTION || connection) return;
            // As the app does for the daemon: pinned at the XPC layer (here identifier and cdhash).
            if (xpc_connection_set_peer_code_signing_requirement(peerConnection, text.UTF8String)) return;
            connection = peerConnection;
            xpc_connection_set_event_handler(peerConnection, ^(xpc_object_t event) {
                if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) dispatch_semaphore_signal(connected);
            });
            xpc_connection_resume(peerConnection);
        });
        xpc_connection_resume(listener);
        mach_port_t ports[1] = {xpc_endpoint_copy_listener_port_4sim(xpc_endpoint_create(listener))};
        if (mach_ports_register(mach_task_self(), ports, 1)) { puts("{\"error\": \"mach_ports_register\"}"); return 1; }
        pid_t child = 0;
        char *arguments[] = {(char *)peer.fileSystemRepresentation, NULL};
        if (posix_spawn(&child, peer.fileSystemRepresentation, NULL, NULL, arguments, environ)) {
            puts("{\"error\": \"posix_spawn\"}"); return 1;
        }
        // The image is mapped; from now on nothing in the directory can be opened by this (non-root) process.
        chmod(directory.fileSystemRepresentation, 0);
        int exit = 1;
        if (dispatch_semaphore_wait(connected, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
            results[@"error"] = @"the peer did not connect (XPC peer requirement refused it?)";
        } else {
            xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(request, "method", "hello");
            xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
            BOOL dictionary = xpc_get_type(reply) == XPC_TYPE_DICTIONARY;
            results[@"xpcPeerRequirementReply"] = dictionary ? @"dictionary" : @"error";
            Expect(dictionary, @"the XPC peer requirement refused the unreadable peer's reply");
            audit_token_t token = {{0}};
            if (dictionary) xpc_dictionary_get_audit_token(reply, &token);
            pid_t pid = (pid_t)token.val[5];
            results[@"tokenPidMatches"] = @(pid == child);
            Expect(pid == child, @"reply audit token pid");

            // 1. mitm.4's validation (and its by-token/by-pid variants).
            SecCodeRef code = NULL;
            OSStatus created = dictionary ? SecCodeCreateWithXPCMessage(reply, 0, &code) : -1;
            SecRequirementRef requirement = NULL;
            SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement);
            OSStatus strict = code ? SecCodeCheckValidity(code, kSecCSStrictValidate, requirement) : created;
            CFDictionaryRef info = NULL;
            OSStatus signing = code ? SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info) : created;
            if (info) CFRelease(info);
            if (code) CFRelease(code);
            NSMutableDictionary *guests = [NSMutableDictionary dictionary];
            for (NSString *by in @[@"auditToken", @"pid"]) {
                NSDictionary *attributes = [by isEqual:@"pid"] ? @{(__bridge NSString *)kSecGuestAttributePid: @(pid)} :
                    @{(__bridge NSString *)kSecGuestAttributeAudit: [NSData dataWithBytes:&token length:sizeof(token)]};
                SecCodeRef guest = NULL;
                OSStatus copied = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes, 0, &guest);
                OSStatus valid = guest ? SecCodeCheckValidity(guest, kSecCSStrictValidate, requirement) : copied;
                info = NULL;
                OSStatus information = guest ? SecCodeCopySigningInformation(guest, kSecCSSigningInformation, &info) : copied;
                if (info) CFRelease(info);
                if (guest) CFRelease(guest);
                guests[by] = @{@"copyGuest": @(copied), @"checkValidityStrict": @(valid), @"signingInformation": @(information)};
            }
            if (requirement) CFRelease(requirement);
            results[@"security"] = @{@"createWithXPCMessage": @(created), @"checkValidityStrict": @(strict),
                @"signingInformation": @(signing), @"guest": guests};
            BOOL securityFailed = strict != errSecSuccess && signing != errSecSuccess &&
                [guests[@"auditToken"][@"checkValidityStrict"] intValue] != 0 && [guests[@"pid"][@"checkValidityStrict"] intValue] != 0;

            // 2. The kernel's answers.
            uint32_t status = 0, pidStatus = 0;
            uint8_t hash[20] = {0}, pidHash[20] = {0};
            int statusError = csops_audittoken(pid, 0, &status, sizeof(status), &token) ? errno : 0;
            int hashError = csops_audittoken(pid, 5, hash, sizeof(hash), &token) ? errno : 0;
            int pidStatusError = csops(pid, 0, &pidStatus, sizeof(pidStatus)) ? errno : 0;
            int pidHashError = csops(pid, 5, pidHash, sizeof(pidHash)) ? errno : 0;
            char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
            int pathLength = proc_pidpath(pid, path, sizeof(path));
            NSData *kernelHash = [NSData dataWithBytes:hash length:sizeof(hash)];
            results[@"kernel"] = @{@"csopsAuditTokenStatus": statusError ? @(-statusError) : [NSString stringWithFormat:@"0x%x", status],
                @"csopsAuditTokenCDHash": hashError ? @(-hashError) : FCHexString(kernelHash),
                @"csopsPidStatus": pidStatusError ? @(-pidStatusError) : [NSString stringWithFormat:@"0x%x", pidStatus],
                @"csopsPidCDHash": pidHashError ? @(-pidHashError) : FCHexString([NSData dataWithBytes:pidHash length:20]),
                @"procPidPathMatches": @(pathLength > 0 && [@(path) isEqualToString:peer]),
                @"staticCDHash": FCHexString(staticHash)};
            Expect(!statusError && (status & 0x1), @"csops_audittoken CS_OPS_STATUS (CS_VALID)");
            Expect(!hashError && [kernelHash isEqualToData:staticHash], @"csops_audittoken CS_OPS_CDHASH");
            Expect(!pidStatusError && !pidHashError && !memcmp(pidHash, hash, 20), @"csops by pid");
            Expect(pathLength > 0 && [@(path) isEqualToString:peer], @"proc_pidpath");
            struct stat state;
            BOOL unreadable = stat(peer.fileSystemRepresentation, &state) != 0 && errno == EACCES;
            results[@"peerFileUnreadable"] = @(unreadable);
            Expect(unreadable, @"the peer's directory is still readable");

            // 3. The fix, on the real reply, and its refusals on real data.
            NSData *running = nil;
            NSString *verdict = FCHelperGuestCheck(&token, peer, &running);
            results[@"fix"] = verdict;
            Expect([verdict isEqualToString:@"verified"] && [running isEqualToData:staticHash], @"FCHelperGuestCheck");
            NSString *wrongPath = FCHelperGuestCheck(&token, [peer stringByAppendingString:@"x"], &running);
            results[@"fixWrongPath"] = wrongPath;
            Expect([wrongPath isEqualToString:@"failed:path"] && !running, @"wrong path refused");
            audit_token_t other = token;
            other.val[7] ^= 1;
            NSString *otherLifetime = FCHelperGuestCheck(&other, peer, &running);
            results[@"fixOtherPidVersion"] = otherLifetime;
            Expect([otherLifetime hasPrefix:@"failed:status-read"], @"token of another lifetime refused");

            // 4. The app's validator on real replies.
            FCMessageValidator *mitm4 = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:peer];
            BOOL mitm4Accepted = [mitm4 check:reply];
            results[@"validatorAsMitm4"] = mitm4Accepted ? @"accepted" : mitm4.failure ?: @"?";
            Expect(!mitm4Accepted && [mitm4.failure hasPrefix:@"SecCodeCheckValidity OSStatus"],
                @"mitm.4's validator configuration did not fail at SecCodeCheckValidity");
            FCMessageValidator *fixed = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:peer sealedExecutable:sealed];
            BOOL first = [fixed check:reply];
            results[@"validatorFixed"] = first ? @"accepted" : fixed.failure ?: @"?";
            xpc_object_t again = xpc_connection_send_message_with_reply_sync(connection, request);
            BOOL second = xpc_get_type(again) == XPC_TYPE_DICTIONARY && [fixed check:again];
            results[@"validatorFixedSecondReply"] = second ? @"accepted" : fixed.failure ?: @"?";
            Expect(first && second && !fixed.runningCodeStale, @"FCMessageValidator (copy path) on real replies");
            FCMessageValidator *stale = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:peer sealedExecutable:otherBuild];
            BOOL staleAccepted = [stale check:reply];
            results[@"validatorOtherBuild"] = staleAccepted ? @"accepted" : stale.failure ?: @"?";
            Expect(!staleAccepted && stale.runningCodeStale && !stale.transientFailure &&
                [stale.failure hasPrefix:@"failed:cdhash running="],
                @"a different sealed build was not reported stale");
            FCMessageValidator *elsewhere = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:[directory stringByAppendingPathComponent:@"Other"] sealedExecutable:sealed];
            BOOL elsewhereAccepted = [elsewhere check:reply];
            results[@"validatorWrongPath"] = elsewhereAccepted ? @"accepted" : elsewhere.failure ?: @"?";
            Expect(!elsewhereAccepted && [elsewhere.failure isEqualToString:@"failed:path"] && !elsewhere.transientFailure,
                @"wrong copy path accepted, or its refusal called transient");

            kill(child, SIGKILL);
            int ignored;
            waitpid(child, &ignored, 0);
            NSString *gone = FCHelperGuestCheck(&token, peer, &running);
            results[@"fixAfterExit"] = gone;
            Expect([gone hasPrefix:@"failed:status-read"], @"exited peer refused");
            // The daemon exits right after replying: its reply is refused, as transient (the app says "not
            // answering" and asks again), never as a failed verification.
            FCMessageValidator *late = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:peer sealedExecutable:sealed];
            BOOL lateAccepted = [late check:reply];
            results[@"validatorAfterExit"] = lateAccepted ? @"accepted" :
                [NSString stringWithFormat:@"%@ transient=%d", late.failure ?: @"?", late.transientFailure];
            Expect(!lateAccepted && late.transientFailure && !late.runningCodeStale &&
                [late.failure hasPrefix:@"failed:status-read errno=3"], @"reply of an exited peer not transient");
            child = 0;
            exit = problems.count ? 1 : securityFailed ? 0 : 3;
            if (!securityFailed) [problems addObject:@"Security calls did not fail: root cause NOT reproduced"];
        }
        if (child > 0) { kill(child, SIGKILL); int ignored; waitpid(child, &ignored, 0); }
        chmod(directory.fileSystemRepresentation, 0700);
        results[@"problems"] = problems;
        NSData *json = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingSortedKeys error:nil];
        puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
        return exit;
    }
}
