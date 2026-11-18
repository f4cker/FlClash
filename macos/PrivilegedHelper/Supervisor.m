#import "../Shared/HelperTrust.h"
#import "Spawn.h"
#import "SessionPolicy.h"
#import "CoreStaging.h"
#import "../Shared/HelperCompatibility.h"
#import <CommonCrypto/CommonDigest.h>
#import <libproc.h>
#import <poll.h>
#import <signal.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/wait.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdio.h>
#import <sysexits.h>
#import <os/log.h>

#ifndef FC_HELPER_BUILD
#define FC_HELPER_BUILD "0"
#endif

static const int64_t FCIdleSeconds = 30;
// How long a Core outlives its app's connection while that same app process may resume the relay on a new one.
static const int64_t FCOwnerGraceSeconds = 10;
// How often one session's relay may move to a new connection within FCAdoptionWindowSeconds; a GUI stuck
// reconnecting cannot keep its Core alive by itself (each move re-arms the grace period).
static const int FCMaxAdoptions = 3;
static const uint64_t FCAdoptionWindowSeconds = 600;
// One receive answers with every frame queued, up to FCRelayBatchFrames and this many bytes (a larger single frame
// still goes alone).
static const size_t FCBatchBytes = 4 * 1024 * 1024;

#ifndef FCMessageAuditToken
void xpc_dictionary_get_audit_token(xpc_object_t message, audit_token_t *token);
#define FCMessageAuditToken xpc_dictionary_get_audit_token
#endif

// Unified log (subsystem com.layoute.flash, category helper): step names and reasons only, no user paths or names.
static os_log_t FCHelperLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.layoute.flash", "helper"); });
    return log;
}

static NSString *FCRunningExecutable(void) {
    char executable[PROC_PIDPATHINFO_MAXSIZE];
    if (proc_pidpath(getpid(), executable, sizeof(executable)) <= 0) return @"";
    return [NSString stringWithUTF8String:executable] ?: @"";
}

static NSString *FCRunningHash(void) {
    SecCodeRef me = NULL;
    if (SecCodeCopySelf(kSecCSDefaultFlags, &me) || !me) return @"";
    CFDictionaryRef information = NULL;
    OSStatus status = SecCodeCopySigningInformation((SecStaticCodeRef)me, kSecCSSigningInformation, &information);
    CFRelease(me);
    if (status || !information) return @"";
    NSDictionary *info = CFBridgingRelease(information);
    return FCHexString(info[(__bridge NSString *)kSecCodeInfoUnique]);
}

@interface FCSupervisor : NSObject
// The app bundle the launcher named (--flash-bundle), already checked to be the canonical /Applications/Flash.app;
// every path into the app (Core, compatibility contract, self-check) is derived from it.
@property (readonly) NSString *bundle;
@property dispatch_queue_t queue;
@property xpc_connection_t owner;
@property NSString *session;
@property NSString *coreHash;
@property NSString *corePath;
@property NSString *runningHash;
@property NSDictionary *contract;
@property uid_t uid;
@property pid_t child;
@property int listener;
@property int socket;
@property NSString *socketPath;
@property NSMutableData *incoming;
// Frames read from the Core that the app has not acknowledged yet, the first being frame number `outgoingBase`;
// and how many app frames were written to the Core. Both count from the start of the session.
@property NSMutableArray<NSData *> *outgoing;
@property uint64_t outgoingBase;
@property uint64_t written;
// The app process (audit token pid and pid version) that started the session.
@property pid_t ownerPid;
@property uint32_t ownerPidVersion;
@property int adoptions;
@property uint64_t adoptionsSince;  // CLOCK_MONOTONIC ns of the first move in the window
// The accepted Core's audit token, for the app to check the Core's identity before it signs for it.
@property NSData *coreToken;
@property BOOL ownershipUncertain;
@property BOOL journalOwned;
@property NSDictionary *lastSweep;
@property NSUInteger connections;
@property dispatch_source_t idle;
- (instancetype)initWithBundle:(NSString *)bundle;
- (void)accept:(xpc_connection_t)connection;
@end

@implementation FCSupervisor
- (instancetype)initWithBundle:(NSString *)bundle {
    if ((self = [super init])) {
        _bundle = [bundle copy];
        _queue = dispatch_queue_create("com.layoute.flash.supervisor", DISPATCH_QUEUE_SERIAL);
        _listener = _socket = -1;
        _incoming = [NSMutableData data];
        _outgoing = [NSMutableArray array];
        _runningHash = FCRunningHash();
        NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
        // No Core of this daemon runs yet, so any running Flash Core is left over from an earlier daemon or
        // app build. Stop it while its staged copy still exists, so its signature can still be checked.
        _lastSweep = FCRetireFlashCores(0);
        struct stat state;
        if (lstat(journal.fileSystemRepresentation, &state) == 0 || errno != ENOENT) {
            _ownershipUncertain = [_lastSweep[@"outcome"] isEqual:@"unconfirmed"] ||
                (unlink(journal.fileSystemRepresentation) && errno != ENOENT);
            if (_ownershipUncertain) _child = -1;
        }
        if (!_ownershipUncertain) FCRemoveStagedCores(FCRuntimeDirectory);
    }
    return self;
}

- (void)armIdle {
    if (!self.idle) {
        self.idle = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
        dispatch_source_set_event_handler(self.idle, ^{
            // On-demand daemon: leave when nobody uses it so a replaced (updated) binary is picked up next time.
            // Uncertain ownership is retried here too so an unused daemon does not stay forever.
            if (self.ownershipUncertain) [self recoverOwnership];
            if (self.child == 0 && !self.ownershipUncertain && self.connections == 0) exit(0);
            [self armIdle];
        });
        dispatch_resume(self.idle);
    }
    dispatch_source_set_timer(self.idle, dispatch_time(DISPATCH_TIME_NOW, FCIdleSeconds * NSEC_PER_SEC),
        DISPATCH_TIME_FOREVER, NSEC_PER_SEC);
}

// The Core's audit token goes only to the connection that just started it.
static BOOL FCRepliesWithCoreToken(NSString *action, NSString *code) {
    return [action isEqualToString:@"start"] && [code isEqualToString:@"ok"];
}

- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frames:(NSArray<NSData *> *)frames
    base:(uint64_t)base coreToken:(NSData *)coreToken sweep:(NSDictionary *)sweep {
    xpc_object_t reply = xpc_dictionary_create_reply(request);
    if (!reply) return;
    xpc_dictionary_set_string(reply, "code", code.UTF8String);
    xpc_dictionary_set_int64(reply, "protocol", 1);
    xpc_dictionary_set_int64(reply, "pid", pid);
    xpc_dictionary_set_bool(reply, "exitConfirmed", self.child == 0 && !self.ownershipUncertain);
    const char *nonce = xpc_dictionary_get_string(request, "nonce");
    if (nonce && strlen(nonce) <= 64) xpc_dictionary_set_string(reply, "nonce", nonce);
    xpc_dictionary_set_string(reply, "coreHash", self.coreHash.UTF8String ?: "");
    xpc_dictionary_set_string(reply, "helperBuild", FC_HELPER_BUILD);
    xpc_dictionary_set_string(reply, "helperCDHash", self.runningHash.UTF8String ?: "");
    if (self.contract) {
        xpc_dictionary_set_int64(reply, "callerPolicy", FC_CALLER_POLICY);
        xpc_dictionary_set_int64(reply, "serviceAPI", FC_SERVICE_API);
        xpc_dictionary_set_int64(reply, "coreAPI", FC_CORE_API);
        xpc_dictionary_set_string(reply, "coreVersion", [self.contract[@"CoreVersion"] UTF8String]);
        xpc_dictionary_set_string(reply, "coreRevision", [self.contract[@"CoreRevision"] UTF8String]);
    }
    if (frames) {
        xpc_object_t list = xpc_array_create(NULL, 0);
        for (NSData *frame in frames) xpc_array_set_data(list, XPC_ARRAY_APPEND, frame.bytes, frame.length);
        xpc_dictionary_set_value(reply, "frames", list);
        xpc_dictionary_set_uint64(reply, "seq", base);
    }
    if (coreToken) xpc_dictionary_set_data(reply, "coreAuditToken", coreToken.bytes, coreToken.length);
    if (sweep) {
        xpc_dictionary_set_string(reply, "reason", [sweep[@"reason"] UTF8String] ?: "");
        xpc_dictionary_set_int64(reply, "stopped", [sweep[@"stopped"] longLongValue]);
    }
    xpc_connection_send_message(xpc_dictionary_get_remote_connection(request), reply);
}

- (void)closeRelay {
    if (self.socket >= 0) { close(self.socket); self.socket = -1; }
    if (self.listener >= 0) { close(self.listener); self.listener = -1; }
    if (self.socketPath) unlink(self.socketPath.fileSystemRepresentation);
    self.socketPath = nil;
    self.coreToken = nil;
    [self.incoming setLength:0];
    [self.outgoing removeAllObjects];
    self.outgoingBase = 0;
    self.written = 0;
}

- (BOOL)syncRuntime {
    int directory = open(FCRuntimeDirectory.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return NO;
    BOOL synced = fsync(directory) == 0;
    close(directory);
    return synced;
}

// While ownership is uncertain a Core of ours may still run. Retried on every hello/start/stop/exit and on
// idle: stop every Flash Core, confirm none survives, release the journal, and only then accept work again.
// Fails closed: any doubt keeps the flag.
- (BOOL)recoverOwnership {
    if (!self.ownershipUncertain) return YES;
    self.lastSweep = FCRetireFlashCores(0);
    if ([self.lastSweep[@"outcome"] isEqual:@"unconfirmed"]) return NO;
    NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
    if (unlink(journal.fileSystemRepresentation)) {
        if (errno != ENOENT) return NO;
    } else if (![self syncRuntime]) return NO;
    if (self.child > 0) {
        int status;
        waitpid(self.child, &status, WNOHANG);
    }
    self.child = 0;
    self.journalOwned = NO;
    if (self.corePath) { unlink(self.corePath.fileSystemRepresentation); self.corePath = nil; }
    [self closeRelay];
    FCRemoveStagedCores(FCRuntimeDirectory);
    self.ownershipUncertain = NO;
    return YES;
}

- (BOOL)confirmExit {
    if (self.ownershipUncertain) return NO;
    if (!self.child) return YES;
    int status;
    pid_t result = waitpid(self.child, &status, WNOHANG);
    if (FCWaitOwnershipUnknown(result, errno)) self.ownershipUncertain = YES;
    if (result != self.child) return NO;
    self.child = 0;
    if (self.journalOwned) {
        NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
        if (unlink(journal.fileSystemRepresentation) || ![self syncRuntime]) { self.ownershipUncertain = YES; return NO; }
        self.journalOwned = NO;
    }
    if (self.corePath) { unlink(self.corePath.fileSystemRepresentation); self.corePath = nil; }
    [self closeRelay];
    return YES;
}

- (BOOL)stop {
    if ([self confirmExit]) return YES;
    if (self.ownershipUncertain) return NO;
    [self closeRelay];
    kill(self.child, SIGTERM);
    for (int i = 0; i < 100; i++) {
        if ([self confirmExit]) return YES;
        if (self.ownershipUncertain) return NO;
        struct timespec delay = {0, 10000000};
        nanosleep(&delay, NULL);
    }
    kill(self.child, SIGKILL);
    for (int i = 0; i < 100; i++) {
        if ([self confirmExit]) return YES;
        if (self.ownershipUncertain) return NO;
        struct timespec delay = {0, 10000000};
        nanosleep(&delay, NULL);
    }
    return [self confirmExit];
}

- (BOOL)openRelay {
    if (!FCPrepareRuntimeDirectory(FCRuntimeDirectory)) return NO;
    self.socketPath = [FCRuntimeDirectory stringByAppendingPathComponent:
        [NSUUID.UUID.UUIDString stringByAppendingString:@".sock"]];
    self.listener = socket(AF_UNIX, SOCK_STREAM, 0);
    if (self.listener < 0) return NO;
    fcntl(self.listener, F_SETFD, FD_CLOEXEC);
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    if (strlcpy(address.sun_path, self.socketPath.fileSystemRepresentation,
                sizeof(address.sun_path)) >= sizeof(address.sun_path)) return NO;
    address.sun_len = sizeof(address);
    return bind(self.listener, (struct sockaddr *)&address, sizeof(address)) == 0 &&
        chmod(address.sun_path, 0600) == 0 && listen(self.listener, 1) == 0;
}

- (BOOL)acceptCore {
    struct pollfd ready = { .fd = self.listener, .events = POLLIN };
    if (poll(&ready, 1, 5000) <= 0) return NO;
    self.socket = accept(self.listener, NULL, NULL);
    if (self.socket < 0) return NO;
    pid_t peer = 0;
    socklen_t length = sizeof(peer);
    if (getsockopt(self.socket, SOL_LOCAL, LOCAL_PEERPID, &peer, &length) || peer != self.child) return NO;
    audit_token_t token;
    length = sizeof(token);
    if (getsockopt(self.socket, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &length) || length != sizeof(token) ||
        (pid_t)token.val[5] != self.child) return NO;
    self.coreToken = [NSData dataWithBytes:&token length:sizeof(token)];
    fcntl(self.socket, F_SETFD, FD_CLOEXEC);
    fcntl(self.socket, F_SETFL, O_NONBLOCK);
    int yes = 1;
    setsockopt(self.socket, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    close(self.listener);
    self.listener = -1;
    return YES;
}

- (NSString *)validateCompatibility {
    self.contract = nil;
    NSDictionary *contract = FCReadCompatibility(self.bundle);
    if (!FCBundleCompatibilityValid(contract)) return @"incompatible";
    self.contract = contract;
    return @"ok";
}

// Re-verify our own code and the app before every privileged operation; a failure ends the daemon.
- (BOOL)selfCheck {
    NSString *result = FCHelperSelfCheck(FCRunningExecutable(), self.bundle);
    if ([result isEqualToString:@"ok"]) return YES;
    fprintf(stderr, "FlashHelper: self-check-failed: %s\n", result.UTF8String);
    os_log_error(FCHelperLog(), "self-check failed before an operation: %{public}s", result.UTF8String);
    return NO;
}

- (NSString *)start:(xpc_object_t)request connection:(xpc_connection_t)connection session:(NSString *)session {
    if (self.ownershipUncertain) return @"exitUnconfirmed";
    if (self.child) return @"sessionBusy";
    if (xpc_connection_get_euid(connection) == 0) return @"wrongOwner";
    if (![self selfCheck]) return @"selfCheckFailed";
    NSString *compatibility = [self validateCompatibility];
    if (![compatibility isEqualToString:@"ok"]) return compatibility;
    const char *expected = xpc_dictionary_get_string(request, "coreHash");
    if (!expected || ![@(expected) isEqualToString:self.contract[@"CoreSHA256"]]) return @"incompatible";
    if (!FCPrepareRuntimeDirectory(FCRuntimeDirectory)) return @"relayFailed";
    // Copy Core (fd-based, O_NOFOLLOW) into the root-only runtime directory, hashing while copying, then
    // verify the copy's signature (pinned identity + com.layoute.flash.core) and spawn only the copy.
    FCRemoveStagedCores(FCRuntimeDirectory);
    NSString *staged = FCStageCore([self.bundle stringByAppendingPathComponent:FCCoreRelativePath],
        FCRuntimeDirectory, self.contract[@"CoreSHA256"]);
    if (!staged) return @"incompatible";
    if (!FCCheckStatic(staged, FCCoreIdentifier)) { unlink(staged.fileSystemRepresentation); return @"signingRequired"; }
    if (![self openRelay]) { [self closeRelay]; unlink(staged.fileSystemRepresentation); return @"relayFailed"; }
    NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
    int record = open(journal.fileSystemRepresentation, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (record < 0) { [self closeRelay]; self.ownershipUncertain = YES; return @"exitUnconfirmed"; }
    BOOL recorded = write(record, "owned\n", 6) == 6 && fsync(record) == 0 && [self syncRuntime];
    close(record);
    if (!recorded) { [self closeRelay]; self.ownershipUncertain = YES; return @"exitUnconfirmed"; }
    self.journalOwned = YES;
    self.owner = connection;
    [self noteOwner:request];
    self.session = session;
    self.uid = xpc_connection_get_euid(connection);
    self.coreHash = self.contract[@"CoreSHA256"];
    self.corePath = staged;
    self.child = FCSpawnCore(staged.fileSystemRepresentation, self.socketPath.fileSystemRepresentation,
                             self.uid, xpc_connection_get_egid(connection));
    if (self.child <= 0) {
        self.child = 0;
        if (unlink(journal.fileSystemRepresentation) || ![self syncRuntime]) self.ownershipUncertain = YES;
        else self.journalOwned = NO;
        [self closeRelay];
        return self.ownershipUncertain ? @"exitUnconfirmed" : @"spawnFailed";
    }
    if (![self acceptCore]) return [self stop] ? @"relayFailed" : @"exitUnconfirmed";
    return @"ok";
}

// Old Cores are stopped by the daemon itself: identified by signature, never by path, and the Core this
// daemon runs now is kept.
- (NSString *)retireCores:(NSDictionary **)sweep {
    if (![self selfCheck]) return @"selfCheckFailed";
    if (self.ownershipUncertain) {
        *sweep = self.lastSweep;
        return @"staleCoreUnconfirmed";
    }
    *sweep = self.lastSweep = FCRetireFlashCores(self.child > 0 ? self.child : 0);
    NSString *outcome = (*sweep)[@"outcome"];
    return [outcome isEqual:@"none"] ? @"noStaleCore" : [outcome isEqual:@"stopped"] ? @"staleCoreStopped" :
        @"staleCoreUnconfirmed";
}

// `seq` numbers the app's frames: a retry of one already written (its reply was lost) is not written again.
- (NSString *)send:(NSData *)frame seq:(uint64_t)seq {
    if (self.socket < 0 || frame.length > FCMaxFrame) return @"disconnected";
    if (seq < self.written) return @"ok";
    if (seq > self.written) return @"invalidRequest";
    uint32_t size = CFSwapInt32HostToLittle((uint32_t)frame.length);
    NSMutableData *wire = [NSMutableData dataWithBytes:&size length:4];
    [wire appendData:frame];
    size_t offset = 0;
    uint64_t deadline = clock_gettime_nsec_np(CLOCK_MONOTONIC) + 1000000000ULL;
    while (offset < wire.length && clock_gettime_nsec_np(CLOCK_MONOTONIC) < deadline) {
        ssize_t n = write(self.socket, (const char *)wire.bytes + offset, wire.length - offset);
        if (n > 0) offset += n;
        else if (n < 0 && (errno == EAGAIN || errno == EINTR)) {
            struct pollfd ready = { .fd = self.socket, .events = POLLOUT };
            poll(&ready, 1, 20);
        } else break;
    }
    if (offset == wire.length) {
        self.written++;
        return @"ok";
    }
    [self stop];
    return @"disconnected";
}

// Answers with every queued frame from `ack` on (the number of frames the app has taken); frames stay queued until
// a later receive acknowledges them, so one whose reply was lost is sent again, never dropped or duplicated.
- (NSArray<NSData *> *)receive:(uint64_t)ack base:(uint64_t *)base code:(NSString **)code {
    *code = @"ok";
    *base = self.outgoingBase;
    if (self.socket < 0) { *code = @"disconnected"; return nil; }
    if (ack < self.outgoingBase || ack - self.outgoingBase > self.outgoing.count) { *code = @"invalidRequest"; return nil; }
    [self.outgoing removeObjectsInRange:NSMakeRange(0, (NSUInteger)(ack - self.outgoingBase))];
    self.outgoingBase = *base = ack;
    size_t bytes = 0;
    for (NSData *queued in self.outgoing) bytes += queued.length;
    BOOL failed = NO;
    for (int attempt = 0; attempt < 1025 && self.outgoing.count < FCRelayBatchFrames && bytes < FCBatchBytes; attempt++) {
        if (self.incoming.length >= 4) {
            uint32_t size;
            memcpy(&size, self.incoming.bytes, 4);
            size = CFSwapInt32LittleToHost(size);
            if (size > FCMaxFrame) { failed = YES; break; }
            if (self.incoming.length >= (size_t)size + 4) {
                // A batch stays within FCMaxFrame in total (the bridge's limit); a frame that does not fit goes
                // alone in the next one.
                if (self.outgoing.count && bytes + size > FCMaxFrame) break;
                [self.outgoing addObject:[self.incoming subdataWithRange:NSMakeRange(4, size)]];
                [self.incoming replaceBytesInRange:NSMakeRange(0, size + 4) withBytes:NULL length:0];
                bytes += size;
                continue;
            }
        }
        uint8_t buffer[65536];
        ssize_t n = read(self.socket, buffer, sizeof(buffer));
        if (n > 0) { [self.incoming appendBytes:buffer length:n]; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && errno == EAGAIN) return [self.outgoing copy];
        failed = YES;
        break;
    }
    // The Core's last frames are delivered before its end is reported: its exit is confirmed (which closes the
    // relay) only once nothing it wrote is left.
    if (self.outgoing.count) return [self.outgoing copy];
    if (!failed && ![self confirmExit]) return @[];
    [self stop];
    *code = @"disconnected";
    return nil;
}

- (void)noteOwner:(xpc_object_t)request {
    audit_token_t token;
    memset(&token, 0, sizeof(token));
    FCMessageAuditToken(request, &token);
    self.ownerPid = (pid_t)token.val[5];
    self.ownerPidVersion = token.val[7];
    self.adoptions = 0;
}

// The app process that started the session, back on a new connection after its previous one was reset (a request
// timed out or a reply was refused), takes the relay over: same process lifetime by audit token, same user, the
// session's secret id, and the full per-connection GUI validation that `handle:` already passed.
- (BOOL)adopt:(xpc_object_t)request connection:(xpc_connection_t)connection session:(NSString *)session {
    audit_token_t token;
    memset(&token, 0, sizeof(token));
    FCMessageAuditToken(request, &token);
    if (!FCMayAdoptSession((__bridge void *)self.owner, self.child > 0, self.ownerPid, self.ownerPidVersion,
            (pid_t)token.val[5], token.val[7], self.uid, xpc_connection_get_euid(connection),
            self.session.UTF8String, session.UTF8String)) return NO;
    uint64_t now = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    if (!self.adoptions || now - self.adoptionsSince > FCAdoptionWindowSeconds * NSEC_PER_SEC) {
        self.adoptions = 0;
        self.adoptionsSince = now;
    }
    if (self.adoptions >= FCMaxAdoptions) {
        os_log(FCHelperLog(), "relay moved %d times already; not resumed again", self.adoptions);
        return NO;
    }
    self.adoptions++;
    os_log(FCHelperLog(), "relay resumed on a new connection of the same app process (%d/%d)", self.adoptions,
        FCMaxAdoptions);
    self.owner = connection;
    return YES;
}

// The owning connection went away. Its Core is stopped unless the same app process resumes the relay within the
// grace period; at once when that process is gone.
- (void)ownerLost:(xpc_connection_t)connection {
    if (self.owner != connection) return;
    if (self.child <= 0 || self.ownerPid <= 0 || (kill(self.ownerPid, 0) && errno == ESRCH)) { [self stop]; return; }
    os_log(FCHelperLog(), "app connection lost; Core kept for %lld s for the app to resume", FCOwnerGraceSeconds);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, FCOwnerGraceSeconds * NSEC_PER_SEC), self.queue, ^{
        if (self.owner != connection) return;
        os_log(FCHelperLog(), "app did not resume the relay; stopping its Core");
        [self stop];
    });
}

- (void)handle:(xpc_object_t)request connection:(xpc_connection_t)connection gui:(FCGUIMessageValidator *)gui {
    [self armIdle];
    if (![gui check:request]) {
        os_log_error(FCHelperLog(), "request from pid %d rejected: GUI verification failed: %{public}s",
            xpc_connection_get_pid(connection), gui.failure.UTF8String ?: "unknown step");
        xpc_connection_cancel(connection);
        // A kernel read that failed says nothing against the app: its process may resume on a new connection,
        // which is validated in full again.
        if (FCGUIReadFailure(gui.failure.UTF8String)) [self ownerLost:connection];
        else if (self.owner == connection) [self stop];
        return;
    }
    const char *method = xpc_dictionary_get_string(request, "method");
    const char *rawSession = xpc_dictionary_get_string(request, "session");
    if (!method || strlen(method) > 32 || (rawSession && strlen(rawSession) > 32) ||
        xpc_dictionary_get_int64(request, "protocol") != 1) {
        [self reply:request code:@"incompatible" pid:0 frames:nil base:0 coreToken:nil sweep:nil]; return;
    }
    NSString *action = @(method);
    NSString *session = rawSession ? @(rawSession) : @"";
    NSString *code = @"invalidRequest";
    NSArray<NSData *> *frames = nil;
    uint64_t base = 0;
    NSDictionary *sweep = nil;
    if (self.ownershipUncertain && ![action isEqualToString:@"send"] && ![action isEqualToString:@"receive"])
        [self recoverOwnership];
    BOOL matching = FCOwnsSession((__bridge void *)self.owner, (__bridge void *)connection,
        self.uid, xpc_connection_get_euid(connection), self.session.UTF8String, session.UTF8String);
    if ([action isEqualToString:@"hello"]) {
        code = self.ownershipUncertain ? @"exitUnconfirmed" : [self validateCompatibility];
    } else if ([action isEqualToString:@"start"]) {
        if (FCValidSession(rawSession))
            code = [self start:request connection:connection session:session];
    } else if ([action isEqualToString:@"retireCores"]) {
        code = [self retireCores:&sweep];
    } else if ([action isEqualToString:@"exit"]) {
        // Lets the GUI retire a stale daemon after an app update; refused while a Core is owned.
        code = self.child == 0 && !self.ownershipUncertain ? @"ok" : @"sessionBusy";
    } else if ([action isEqualToString:@"stop"]) {
        // The owning connection, or a later one of the same user naming the running session.
        BOOL mayStop = matching || FCMayStopSession((__bridge void *)self.owner, self.uid,
            xpc_connection_get_euid(connection), self.session.UTF8String, session.UTF8String);
        code = !mayStop ? @"wrongOwner" : [self stop] ? @"ok" : @"exitUnconfirmed";
    } else if (!matching && !(FCRelayAction(method) && [self adopt:request connection:connection session:session]))
        code = @"wrongOwner";
    else if ([action isEqualToString:@"receive"]) {
        xpc_object_t ack = xpc_dictionary_get_value(request, "ack");
        if (ack && xpc_get_type(ack) == XPC_TYPE_UINT64)
            frames = [self receive:xpc_uint64_get_value(ack) base:&base code:&code];
    } else if ([action isEqualToString:@"send"]) {
        size_t length = 0;
        const void *data = xpc_dictionary_get_data(request, "frame", &length);
        xpc_object_t seq = xpc_dictionary_get_value(request, "seq");
        if (data && length <= FCMaxFrame && seq && xpc_get_type(seq) == XPC_TYPE_UINT64)
            code = [self send:[NSData dataWithBytes:data length:length] seq:xpc_uint64_get_value(seq)];
    }
    [self reply:request code:code pid:self.child frames:frames base:base
        coreToken:FCRepliesWithCoreToken(action, code) ? self.coreToken : nil sweep:sweep];
    if ([code isEqualToString:@"selfCheckFailed"] ||
        ([action isEqualToString:@"exit"] && [code isEqualToString:@"ok"])) {
        int status = [code isEqualToString:@"ok"] ? 0 : FC_HELPER_REFUSED_EXIT;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), self.queue, ^{ exit(status); });
    }
}

- (void)accept:(xpc_connection_t)connection {
    // Only the pinned Flash GUI may connect (identity at the XPC layer, then full per-message validation).
    NSString *requirement = FCGUIRequirement();
    if (!requirement || xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)) {
        os_log_error(FCHelperLog(), "connection refused: GUI requirement unavailable");
        xpc_connection_cancel(connection); return;
    }
    FCGUIMessageValidator *gui = [FCGUIMessageValidator new];
    self.connections++;
    xpc_connection_set_target_queue(connection, self.queue);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) { [self handle:event connection:connection gui:gui]; return; }
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            if (self.connections) self.connections--;
            [self armIdle];
        }
        [self ownerLost:connection];
    });
    xpc_connection_resume(connection);
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (@available(macOS 14.0, *)) {} else return EX_CONFIG;
        if (geteuid() != 0 || !FCGUIRequirement()) return EX_CONFIG;
        // Only the launcher's verified copy runs, and it is told which app it belongs to. Started any other way
        // (directly from the bundle, e.g. by a registration that still names FlashHelper as its BundleProgram) the
        // helper refuses: that path skips the launcher's downgrade check. Environment variables are not read.
        NSMutableArray<NSString *> *arguments = [NSMutableArray array];
        for (int i = 0; i < argc; i++) [arguments addObject:@(argv[i]) ?: @""];
        NSString *reason = nil;
        NSString *bundle = FCHelperBundleFromArguments(arguments, &reason);
        if (!bundle) {
            fprintf(stderr, "FlashHelper: launch-refused: %s\n", reason.UTF8String ?: "invalid arguments");
            os_log_error(FCHelperLog(), "launch refused: %{public}s", reason.UTF8String ?: "invalid arguments");
            return FC_HELPER_REFUSED_EXIT;
        }
        // Verify before anything else is done as root: tampered or relocated code does not run.
        NSString *check = FCHelperSelfCheck(FCRunningExecutable(), bundle);
        if (![check isEqualToString:@"ok"]) {
            fprintf(stderr, "FlashHelper: self-check-failed: %s\n", check.UTF8String);
            os_log_error(FCHelperLog(), "self-check failed at startup: %{public}s", check.UTF8String);
            return FC_HELPER_REFUSED_EXIT;
        }
        os_log(FCHelperLog(), "self-check ok; serving %{public}s", FCHelperLabel.UTF8String);
        FCSupervisor *supervisor = [[FCSupervisor alloc] initWithBundle:bundle];
        xpc_connection_t listener = xpc_connection_create_mach_service(FCHelperLabel.UTF8String,
            supervisor.queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
        xpc_connection_set_event_handler(listener, ^(xpc_object_t connection) {
            if (xpc_get_type(connection) == XPC_TYPE_CONNECTION) [supervisor accept:connection];
        });
        signal(SIGTERM, SIG_IGN);
        dispatch_source_t termination = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,
            SIGTERM, 0, supervisor.queue);
        dispatch_source_set_event_handler(termination, ^{
            if ([supervisor recoverOwnership] && [supervisor stop]) exit(0);
        });
        dispatch_resume(termination);
        dispatch_async(supervisor.queue, ^{ [supervisor armIdle]; });
        xpc_connection_resume(listener);
        dispatch_main();
    }
}
