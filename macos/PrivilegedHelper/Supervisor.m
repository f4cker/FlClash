#import "../Shared/HelperTrust.h"
#import "Spawn.h"
#import "SessionPolicy.h"
#import <libproc.h>
#import <poll.h>
#import <signal.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/wait.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdio.h>

@interface FCSupervisor : NSObject
@property dispatch_queue_t queue;
@property xpc_connection_t owner;
@property NSString *session;
@property NSString *bundle;
@property NSString *coreHash;
@property uid_t uid;
@property pid_t child;
@property int listener;
@property int socket;
@property NSString *socketPath;
@property NSMutableData *incoming;
@property BOOL maintenance;
@property BOOL ownershipUncertain;
@property BOOL journalOwned;
- (void)accept:(xpc_connection_t)connection;
@end

static BOOL FCTransactionPending(void) {
    NSString *lock = [FCInstalledBundle.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".installer-lock"];
    struct stat state;
    return lstat(lock.fileSystemRepresentation, &state) == 0 || errno != ENOENT;
}

@implementation FCSupervisor
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.layoute.flash.supervisor", DISPATCH_QUEUE_SERIAL);
        _listener = _socket = -1;
        _incoming = [NSMutableData data];
        NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
        struct stat state;
        if (lstat(journal.fileSystemRepresentation, &state) == 0 || errno != ENOENT) {
            _ownershipUncertain = YES;
            _child = -1;
            _maintenance = YES;
        }
        NSString *freeze = [FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"];
        if (lstat(freeze.fileSystemRepresentation, &state) == 0 || errno != ENOENT || FCTransactionPending()) _maintenance = YES;
        char executable[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(getpid(), executable, sizeof(executable)) > 0) {
            NSString *path = [NSString stringWithUTF8String:executable];
            _bundle = path.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent
                .stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
        }
    }
    return self;
}

- (void)reply:(xpc_object_t)request code:(NSString *)code pid:(pid_t)pid frame:(NSData *)frame {
    xpc_object_t reply = xpc_dictionary_create_reply(request);
    if (!reply) return;
    xpc_dictionary_set_string(reply, "code", code.UTF8String);
    xpc_dictionary_set_int64(reply, "protocol", 1);
    xpc_dictionary_set_int64(reply, "pid", pid);
    xpc_dictionary_set_bool(reply, "exitConfirmed", self.child == 0 && !self.ownershipUncertain);
    xpc_dictionary_set_bool(reply, "frozen", self.maintenance);
    const char *nonce = xpc_dictionary_get_string(request, "nonce");
    if (nonce && strlen(nonce) <= 64) xpc_dictionary_set_string(reply, "nonce", nonce);
    xpc_dictionary_set_string(reply, "coreHash", self.coreHash.UTF8String ?: "");
    if (frame) xpc_dictionary_set_data(reply, "frame", frame.bytes, frame.length);
    xpc_connection_send_message(xpc_dictionary_get_remote_connection(request), reply);
}

- (void)closeRelay {
    if (self.socket >= 0) { close(self.socket); self.socket = -1; }
    if (self.listener >= 0) { close(self.listener); self.listener = -1; }
    if (self.socketPath) unlink(self.socketPath.fileSystemRepresentation);
    self.socketPath = nil;
    [self.incoming setLength:0];
}

- (BOOL)syncRuntime {
    int directory = open(FCRuntimeDirectory.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return NO;
    BOOL synced = fsync(directory) == 0;
    close(directory);
    return synced;
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
    NSString *directory = FCRuntimeDirectory;
    if (mkdir(directory.fileSystemRepresentation, 0700) && errno != EEXIST) return NO;
    if (!FCProtectedTree(directory, NO)) return NO;
    struct stat st;
    if (lstat(directory.fileSystemRepresentation, &st) || (st.st_mode & 0777) != 0700) return NO;
    self.socketPath = [directory stringByAppendingPathComponent:
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
    fcntl(self.socket, F_SETFD, FD_CLOEXEC);
    fcntl(self.socket, F_SETFL, O_NONBLOCK);
    int yes = 1;
    setsockopt(self.socket, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    close(self.listener);
    self.listener = -1;
    return YES;
}

- (NSString *)start:(xpc_object_t)request connection:(xpc_connection_t)connection session:(NSString *)session {
    if (self.ownershipUncertain) return @"exitUnconfirmed";
    if (FCTransactionPending()) self.maintenance = YES;
    if (self.maintenance) return @"maintenance";
    if (self.child) return @"sessionBusy";
    if (xpc_connection_get_euid(connection) == 0) return @"wrongOwner";
    NSString *trust = FCBundleTrust(self.bundle ?: @"");
    if (![trust isEqualToString:@"trusted"]) return trust;
    NSString *core = [self.bundle stringByAppendingPathComponent:@"Contents/MacOS/FlClashCore"];
    NSString *hash = FCSHA256(core);
    const char *expected = xpc_dictionary_get_string(request, "coreHash");
    if (!expected || hash.length != 64 || ![hash isEqualToString:@(expected)]) return @"incompatible";
    if (![self openRelay]) { [self closeRelay]; return @"relayFailed"; }
    NSString *journal = [FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"];
    int record = open(journal.fileSystemRepresentation, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (record < 0) { [self closeRelay]; self.ownershipUncertain = YES; return @"exitUnconfirmed"; }
    BOOL recorded = write(record, "owned\n", 6) == 6 && fsync(record) == 0 && [self syncRuntime];
    close(record);
    if (!recorded) { [self closeRelay]; self.ownershipUncertain = YES; return @"exitUnconfirmed"; }
    self.journalOwned = YES;
    self.owner = connection;
    self.session = session;
    self.uid = xpc_connection_get_euid(connection);
    self.coreHash = hash;
    self.child = FCSpawnCore(core.fileSystemRepresentation, self.socketPath.fileSystemRepresentation,
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

- (NSString *)send:(NSData *)frame {
    if (self.socket < 0 || frame.length > FCMaxFrame) return @"disconnected";
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
    if (offset == wire.length) return @"ok";
    [self stop];
    return @"disconnected";
}

- (NSData *)receive:(NSString **)code {
    *code = @"ok";
    if (self.socket < 0 || [self confirmExit]) { *code = @"disconnected"; return nil; }
    for (int attempt = 0; attempt < 1025; attempt++) {
        if (self.incoming.length >= 4) {
            uint32_t size;
            memcpy(&size, self.incoming.bytes, 4);
            size = CFSwapInt32LittleToHost(size);
            if (size > FCMaxFrame) break;
            if (self.incoming.length >= (size_t)size + 4) {
                NSData *frame = [self.incoming subdataWithRange:NSMakeRange(4, size)];
                [self.incoming replaceBytesInRange:NSMakeRange(0, size + 4) withBytes:NULL length:0];
                return frame;
            }
        }
        uint8_t buffer[65536];
        ssize_t n = read(self.socket, buffer, sizeof(buffer));
        if (n > 0) { [self.incoming appendBytes:buffer length:n]; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && errno == EAGAIN) return nil;
        break;
    }
    [self stop];
    *code = @"disconnected";
    return nil;
}

- (void)handle:(xpc_object_t)request connection:(xpc_connection_t)connection
    gui:(FCGUIMessageValidator *)gui tool:(FCMessageValidator *)tool {
    const char *method = xpc_dictionary_get_string(request, "method");
    BOOL maintenanceRequest = method && !strcmp(method, "prepareMaintenance");
    BOOL authenticated = maintenanceRequest ? xpc_connection_get_euid(connection) == 0 && [tool check:request] : [gui check:request];
    if (!authenticated) {
        xpc_connection_cancel(connection);
        if (self.owner == connection) [self stop];
        return;
    }
    const char *rawSession = xpc_dictionary_get_string(request, "session");
    if (!method || strlen(method) > 32 || (rawSession && strlen(rawSession) > 32) ||
        xpc_dictionary_get_int64(request, "protocol") != 1) {
        [self reply:request code:@"incompatible" pid:0 frame:nil]; return;
    }
    NSString *action = @(method);
    NSString *session = rawSession ? @(rawSession) : @"";
    NSString *code = @"invalidRequest";
    NSData *frame = nil;
    BOOL matching = FCOwnsSession((__bridge void *)self.owner, (__bridge void *)connection,
        self.uid, xpc_connection_get_euid(connection), self.session.UTF8String, session.UTF8String);
    if ([action isEqualToString:@"hello"]) {
        NSString *core = [self.bundle stringByAppendingPathComponent:@"Contents/MacOS/FlClashCore"];
        self.coreHash = FCSHA256(core);
        code = self.ownershipUncertain ? @"exitUnconfirmed" : self.maintenance ? @"maintenance" : @"ok";
    } else if ([action isEqualToString:@"start"]) {
        if (FCValidSession(rawSession))
            code = [self start:request connection:connection session:session];
    } else if ([action isEqualToString:@"prepareMaintenance"]) {
        self.maintenance = YES;
        code = [self stop] ? @"ok" : @"exitUnconfirmed";
    } else if (!matching) code = @"wrongOwner";
    else if ([action isEqualToString:@"stop"]) code = [self stop] ? @"ok" : @"exitUnconfirmed";
    else if ([action isEqualToString:@"receive"]) frame = [self receive:&code];
    else if ([action isEqualToString:@"send"]) {
        size_t length = 0;
        const void *data = xpc_dictionary_get_data(request, "frame", &length);
        if (data && length <= FCMaxFrame) code = [self send:[NSData dataWithBytes:data length:length]];
    }
    [self reply:request code:code pid:self.child frame:frame];
}

- (void)accept:(xpc_connection_t)connection {
    NSString *guiRequirement = FCSplitGUIRequirement();
    NSString *toolRequirement = FCSigningRequirement(FCMaintenanceIdentifier);
    NSString *requirement = guiRequirement && toolRequirement ?
        [NSString stringWithFormat:@"(%@) or (%@)", guiRequirement, toolRequirement] : nil;
    if (!requirement || xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)) {
        xpc_connection_cancel(connection); return;
    }
    FCGUIMessageValidator *gui = [FCGUIMessageValidator new];
    FCMessageValidator *tool = [[FCMessageValidator alloc] initWithIdentifier:FCMaintenanceIdentifier
        executable:FCInstalledExecutable(FCMaintenanceIdentifier) bundle:nil];
    xpc_connection_set_target_queue(connection, self.queue);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) [self handle:event connection:connection gui:gui tool:tool];
        else if (self.owner == connection) [self stop];
    });
    xpc_connection_resume(connection);
}
@end

int main(void) {
    @autoreleasepool {
        if (@available(macOS 14.0, *)) {} else return 78;
        if (geteuid() != 0 || !FCSplitGUIRequirement()) return 78;
        if (!FCLegacyRuntimeAbsent()) {
            fputs("FlashHelper: legacy-runtime-recovery-required: legacy runtime exists or absence cannot be proven; preserve journals and recover before retry\n", stderr);
            return 78;
        }
        FCSupervisor *supervisor = [FCSupervisor new];
        if (![FCBundleTrust(supervisor.bundle ?: @"") isEqualToString:@"trusted"] || !FCLegacyPlistTrusted()) return 78;
        xpc_connection_t listener = xpc_connection_create_mach_service(FCHelperLabel.UTF8String,
            supervisor.queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
        xpc_connection_set_event_handler(listener, ^(xpc_object_t connection) {
            if (xpc_get_type(connection) == XPC_TYPE_CONNECTION) [supervisor accept:connection];
        });
        signal(SIGTERM, SIG_IGN);
        dispatch_source_t termination = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,
            SIGTERM, 0, supervisor.queue);
        dispatch_source_set_event_handler(termination, ^{
            if ([supervisor stop]) exit(0);
        });
        dispatch_resume(termination);
        xpc_connection_resume(listener);
        dispatch_main();
    }
}
