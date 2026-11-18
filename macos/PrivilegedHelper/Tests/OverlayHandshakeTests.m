// One step of an overlay install (test_overlay_handshake.py), on real processes: a peer (UnreadablePeer.c) runs from
// a given path, optionally in a directory this process cannot read (the launcher's root 0700 copy), connects over an
// anonymous XPC listener whose peer requirement it must meet, and answers two hellos. The app's own reply validator
// (FCMessageValidator, as ManagedHelperBridge configures it: running copy path + helper sealed in the app) judges
// both replies, and the bridge's mapping turns the verdict into the card code. Only the pinned certificate is
// replaced (FCPinnedRequirement/FCPinnedCodePolicy, set when compiling); every Security, kernel and file access is real.
// Usage: overlay-handshake <directory> <peer path> <XPC peer requirement> <expected copy path> <sealed helper>
//        <lock: 0|1>. Prints one JSON object; exit 0 when it ran (the verdict is the test's to judge), 1 otherwise.
#import "../../Shared/HelperTrust.h"
#import <signal.h>
#import <spawn.h>
#import <sys/stat.h>
#import <sys/wait.h>

extern char **environ;
mach_port_t xpc_endpoint_copy_listener_port_4sim(xpc_endpoint_t endpoint);

NSString *TestPinnedRequirement(NSString *identifier) {
    return [identifier isEqualToString:@"com.layoute.flash.test.peer"] ? @"identifier \"com.layoute.flash.test.peer\"" : nil;
}
BOOL TestPinnedCodePolicy(NSDictionary *entitlements, uint32_t flags) {
    return (flags & kSecCodeSignatureRuntime) && !entitlements[@"com.apple.security.get-task-allow"];
}

// ManagedHelperBridge -request:: refused reply → staleHelper / untrustedReply; accepted → the reply's code.
static NSString *BridgeCode(FCMessageValidator *validator, BOOL accepted) {
    if (accepted) return @"ok";
    return validator.runningCodeStale ? @"staleHelper" : @"untrustedReply";
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 7) return 64;
        NSString *directory = @(argv[1]), *peer = @(argv[2]), *text = @(argv[3]);
        NSString *expected = @(argv[4]), *sealed = @(argv[5]);
        BOOL lock = atoi(argv[6]) != 0;
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        dispatch_queue_t queue = dispatch_queue_create("overlay-handshake", DISPATCH_QUEUE_SERIAL);
        xpc_connection_t listener = xpc_connection_create(NULL, queue);
        __block xpc_connection_t connection = NULL;
        dispatch_semaphore_t connected = dispatch_semaphore_create(0);
        xpc_connection_set_event_handler(listener, ^(xpc_object_t peerConnection) {
            if (xpc_get_type(peerConnection) != XPC_TYPE_CONNECTION || connection) return;
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
        if (lock) chmod(directory.fileSystemRepresentation, 0);
        int exit = 1;
        if (dispatch_semaphore_wait(connected, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
            results[@"error"] = @"the peer did not connect";
        } else {
            struct stat state;
            results[@"peerFileUnreadable"] = @(stat(peer.fileSystemRepresentation, &state) != 0 && errno == EACCES);
            FCMessageValidator *validator = [[FCMessageValidator alloc] initWithIdentifier:@"com.layoute.flash.test.peer"
                executable:expected sealedExecutable:sealed];
            NSMutableArray *replies = [NSMutableArray array];
            for (int round = 0; round < 2; round++) {
                xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
                xpc_dictionary_set_string(request, "method", "hello");
                xpc_dictionary_set_int64(request, "protocol", 1);
                xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
                if (xpc_get_type(reply) != XPC_TYPE_DICTIONARY) { [replies addObject:@{@"xpc": @"error"}]; continue; }
                BOOL accepted = [validator check:reply];
                [replies addObject:@{@"accepted": @(accepted), @"failure": validator.failure ?: @"",
                    @"stale": @(validator.runningCodeStale), @"code": BridgeCode(validator, accepted)}];
            }
            results[@"replies"] = replies;
            exit = 0;
        }
        if (child > 0) { kill(child, SIGKILL); int ignored; waitpid(child, &ignored, 0); }
        if (lock) chmod(directory.fileSystemRepresentation, 0700);
        NSData *json = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingSortedKeys error:nil];
        puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
        return exit;
    }
}
