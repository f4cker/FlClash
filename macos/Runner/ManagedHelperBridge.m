#import "ManagedHelperBridge.h"
#import "../Shared/HelperTrust.h"
#import "../Shared/HelperIdentity.h"
#import "../Shared/HelperCompatibility.h"
#import "../Shared/LegacyResidue.h"
#import "../Shared/LaunchdProbe.h"
#import "../Shared/LauncherStatus.h"
#import "../Shared/LauncherRecordRepair.h"
#import <ServiceManagement/ServiceManagement.h>
#import <os/log.h>

// Unified log (subsystem com.layoute.flash, category bridge). Only step names, codes, OSStatus/errno and hashes;
// never paths or user names.
static os_log_t FCBridgeLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.layoute.flash", "bridge"); });
    return log;
}

// Bookkeeping of the helper build last registered with SMAppService.
static NSString * const FCRegisteredHelperDefault = @"FlashDaemonRegisteredHelperCDHash";
// Set once the daemon was seen enabled; distinguishes "turned off by the user" from "never approved".
static NSString * const FCApprovedDefault = @"FlashDaemonApproved";
// The app build (CFBundleVersion) that last tried to unregister the retired name: one attempt per build, across
// launches. Its outcome is only ever a detail.
static NSString * const FCRetiredAttemptDefault = @"FlashRetiredUnregisterAttemptedBuild";

// How long a request may wait for the daemon's reply. `start` validates the app, stages and verifies the Core
// and waits for it on the relay; right after an update (cold caches, files still being scanned) that can take
// well over the 8 s that every other request gets.
// `retireCores` checks the signature of every candidate process and waits for each old Core to exit.
static int64_t FCRequestTimeoutSeconds(NSString *method) {
    return [method isEqualToString:@"start"] || [method isEqualToString:@"retireCores"] ? 30 : 8;
}

// The card state for the daemon's answer to `hello`. A request that ran out of time is `timeout`, never
// `exitUnconfirmed`: only the daemon itself can say that a Core's exit is unconfirmed.
static NSString *FCStatusForHello(NSString *reply) {
    if ([reply isEqual:@"ok"]) return @"enabled";
    for (NSString *code in @[@"exitUnconfirmed", @"incompatible", @"staleHelper", @"timeout", @"untrustedReply"])
        if ([reply isEqual:code]) return code;
    return @"unavailable";
}

// A relay batch: data items only, each and all together within FCMaxFrame; nil otherwise.
static NSArray<NSData *> *FCRelayFrames(xpc_object_t frames) {
    if (xpc_get_type(frames) != XPC_TYPE_ARRAY || xpc_array_get_count(frames) > FCRelayBatchFrames) return nil;
    NSMutableArray<NSData *> *list = [NSMutableArray array];
    size_t total = 0;
    for (size_t index = 0; index < xpc_array_get_count(frames); index++) {
        xpc_object_t item = xpc_array_get_value(frames, index);
        if (xpc_get_type(item) != XPC_TYPE_DATA) return nil;
        size_t size = xpc_data_get_length(item);
        total += size;
        if (size > FCMaxFrame || total > FCMaxFrame) return nil;
        const void *bytes = xpc_data_get_bytes_ptr(item);
        if (size && !bytes) return nil;
        [list addObject:size ? [NSData dataWithBytes:bytes length:size] : [NSData data]];
    }
    return list;
}

// Full error text for "View details": domain, code and every userInfo entry (underlying errors included).
static NSString *FCErrorText(NSError *error) {
    if (!error) return @"none";
    NSString *text = [NSString stringWithFormat:@"domain=%@ code=%ld userInfo=%@",
        error.domain, (long)error.code, error.userInfo ?: @{}];
    return text.length > 2000 ? [text substringToIndex:2000] : text;
}

// SMAppService's error domains, by value: SMAppServiceErrorDomain (SMAppService.h; the symbol needs macOS 15, the
// errors carry this domain before that too) and kSMErrorDomainFramework (SMErrors.h, deprecated symbol).
static NSString * const FCSMAppServiceErrorDomain = @"SMAppServiceErrorDomain";
static NSString * const FCSMFrameworkErrorDomain = @"kSMErrorDomainFramework";

// The system refused to bootstrap the job until the user allows it (an unregistered and re-added daemon keeps a
// disabled Background Task item): EPERM ("Operation not permitted", SMAppService or POSIX domain) or
// kSMErrorLaunchDeniedByUser (SMAppService domain), while SMAppService.status (`status`, read right after) is
// requiresApproval or notRegistered. Any other error, domain or status is a registration failure.
static BOOL FCApprovalError(NSError *error, NSString *status) {
    if (!error || !([status isEqual:@"requiresApproval"] || [status isEqual:@"notRegistered"])) return NO;
    if ([error.domain isEqual:FCSMAppServiceErrorDomain] || [error.domain isEqual:FCSMFrameworkErrorDomain])
        return error.code == EPERM || error.code == kSMErrorLaunchDeniedByUser;
    return [error.domain isEqual:NSPOSIXErrorDomain] && error.code == EPERM;
}

// Unregister of a name that is not registered (any more) reports kSMErrorJobNotFound: already done.
static BOOL FCAlreadyUnregistered(NSError *error) {
    return !error || error.code == kSMErrorJobNotFound;
}

// The trust gate's notFound means the bundle's own daemon files (plist, helper, launcher) are missing or not as
// built: only a reinstall helps. SMAppService reporting notFound for an intact, trusted bundle is a different
// problem (the system's record does not match this copy) and has its own code, serviceNotFound. Both say which
// one in a non-secret `source` and in the details.
static NSDictionary *FCGateAnswer(NSString *gate) {
    if ([gate isEqualToString:@"notFound"])
        return @{@"code": @"notFound", @"source": @"bundle",
            @"detail": @"source: bundle (bundled daemon plist, helper or launcher missing or not as built)"};
    return @{@"code": gate};
}

static NSString *FCServiceStatusName(NSInteger status) {
    switch (status) {
        case SMAppServiceStatusEnabled: return @"enabled";
        case SMAppServiceStatusRequiresApproval: return @"requiresApproval";
        case SMAppServiceStatusNotRegistered: return @"notRegistered";
        case SMAppServiceStatusNotFound: return @"notFound";
        default: return @"unknown";
    }
}

// The completion runs only after launchd killed the service's process. Bounded; a missing completion is reported.
static NSError *FCUnregisterWithin(SMAppService *service, NSTimeInterval timeout, BOOL *timedOut) API_AVAILABLE(macos(13.0)) {
    *timedOut = NO;
    __block NSError *result = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    @try {
        [service unregisterWithCompletionHandler:^(NSError *error) {
            result = error;
            dispatch_semaphore_signal(done);
        }];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:@"FlashBridge" code:-1
            userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: exception.name}];
    }
    *timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) != 0;
    return *timedOut ? nil : result;
}

@interface FCManagedHelperBridge ()
@property dispatch_queue_t queue;
@property dispatch_queue_t repairQueue;
@property NSTimeInterval residueClearUntil;
@property xpc_connection_t connection;
@property NSUInteger pending;
@property NSUInteger pendingBytes;
@property FCMessageValidator *validator;
@property BOOL connectionTrusted;
@property NSString *negotiatedCoreHash;
@property BOOL sessionActive;
// systemUptime of the last reply that passed verification while a session runs (see -expireSilentSession).
@property NSTimeInterval lastVerifiedReply;
@property BOOL operationInFlight;
@property BOOL migrationAttempted;
@property NSDate *staleRetryAfter;
// The retired registration name was seen absent, or one unregister of it was attempted by this build (this launch
// or an earlier one: FCRetiredAttemptDefault).
@property (atomic) BOOL retiredSettled;
// The Core of the running session, as the daemon saw it on the relay socket; session 0 is none.
@property NSData *coreToken;
@property pid_t corePid;
@property NSUInteger coreSession;
@property NSUInteger coreSessions;
@property NSObject *identityLock;
@property NSUInteger hashSession;
@property NSData *expectedCoreHash;
// Wall-clock start of this launch, and since when (uptime; 0 = not) a launcher "ok" has gone unanswered.
@property NSTimeInterval launchedAt;
@property NSTimeInterval okUnansweredSince;
@property NSTimeInterval recordRepairedAt;
// SMAppService read notFound right before the user started this recovery: unregister even without a launchd job.
@property BOOL serviceWasNotFound;
@end

@implementation FCManagedHelperBridge
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.layoute.flash.bridge", DISPATCH_QUEUE_SERIAL);
        _repairQueue = dispatch_queue_create("com.layoute.flash.bridge.repair", DISPATCH_QUEUE_SERIAL);
        _identityLock = [NSObject new];
        _launchedAt = NSDate.date.timeIntervalSince1970;
        // R6: the legacy installer's pending marker needs no admin rights; drop it.
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCLegacyPendingDefault];
    }
    return self;
}

- (BOOL)effectsAllowed {
    NSString *encoded = NSBundle.mainBundle.infoDictionary[@"FlashDartDefines"];
    if (![encoded isKindOfClass:NSString.class]) return NO;
    BOOL managed = NO;
    for (NSString *item in [encoded componentsSeparatedByString:@","]) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:item options:0];
        NSString *define = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([define isEqualToString:@"SAFE_MODE=true"]) return NO;
        if ([define isEqualToString:@"MACOS_MANAGED_HELPER=true"]) managed = YES;
    }
    return managed;
}

- (SMAppService *)daemon API_AVAILABLE(macos(13.0)) {
    return [SMAppService daemonServiceWithPlistName:FCDaemonPlistName];
}

// Only ever asked for its status and unregistered; never registered.
- (SMAppService *)retiredDaemon API_AVAILABLE(macos(13.0)) {
    return [SMAppService daemonServiceWithPlistName:FCRetiredDaemonPlistName];
}

- (NSString *)retiredStatusCode {
    if (@available(macOS 13.0, *)) {
        @try {
            return FCServiceStatusName([self retiredDaemon].status);
        } @catch (NSException *exception) {
            return @"unknown";
        }
    }
    return @"notFound";
}

- (NSUserDefaults *)preferences { return NSUserDefaults.standardUserDefaults; }

// Whether this app build already tried to unregister the retired name (in any launch).
- (BOOL)retiredAttemptedThisBuild {
    NSString *build = [self bundleVersion];
    return build.length && [[[self preferences] stringForKey:FCRetiredAttemptDefault] isEqual:build];
}

- (void)recordRetiredAttempt {
    NSString *build = [self bundleVersion];
    if (build.length) [[self preferences] setObject:build forKey:FCRetiredAttemptDefault];
}

// A registration under the retired name still exists: the app migrates it (under its maintenance exclusion) before
// the new name is used. Read until seen absent; after one attempt by this build (persisted across launches) it is a
// detail, never a block.
// Seen absent once by this build (persisted too): later launches do not ask launchd about the retired label again.
- (NSDictionary *)retiredRegistration {
    if (self.retiredSettled) return nil;
    if ([self retiredAttemptedThisBuild]) { self.retiredSettled = YES; return nil; }
    NSString *build = [self bundleVersion];
    if (build.length && [[[self preferences] stringForKey:@"FlashRetiredAbsentBuild"] isEqual:build]) {
        self.retiredSettled = YES; return nil;
    }
    NSString *status = [self retiredStatusCode];
    if ([status isEqual:@"notRegistered"] || [status isEqual:@"notFound"]) {
        if (build.length) [[self preferences] setObject:build forKey:@"FlashRetiredAbsentBuild"];
        self.retiredSettled = YES; return nil;
    }
    return @{@"code": @"retiredRegistration",
        @"detail": [NSString stringWithFormat:@"%@: %@", FCRetiredHelperLabel, status]};
}

// Trust of the running app only: pinned identity, exact install path, seal (covers daemon, plist, Core, contract).
- (NSString *)appGate {
    if (![self effectsAllowed]) return @"disabled";
    if (@available(macOS 14.0, *)) return FCGUIBundleTrust(NSBundle.mainBundle.bundlePath);
    return @"unsupported";
}

- (NSString *)gate {
    NSString *gate = [self appGate];
    if (![gate isEqualToString:@"trusted"]) return gate;
    if (!FCBundledDaemonPresent(FCGUIBundle)) return @"notFound";
    // The bundled daemon must itself carry the pinned identity (no bypass: the UI offers reinstall only).
    if (!FCCheckStatic(FCInstalledExecutable(FCHelperIdentifier), FCHelperIdentifier)) return @"signingRequired";
    if (!FCBundleCompatibilityValid(FCReadCompatibility(FCGUIBundle))) return @"incompatible";
    return @"trusted";
}

- (NSString *)currentHelperHash {
    return FCHexString(FCStaticCodeHash(FCInstalledExecutable(FCHelperIdentifier), FCHelperIdentifier));
}

- (NSDictionary *)residueAnswer:(FCLegacyResidue)residue code:(NSString *)code {
    return @{@"code": code, @"residue": FCLegacyResidueNames(residue)};
}

// The legacy pkg helper probe (files, receipts and a bootstrap lookup of com.layoute.flash.helper, which is what
// shows up in the gui/<uid> domain) is deliberate; a clean result is reused for a minute so that status polling
// does not repeat it.
- (FCLegacyResidue)legacyResidue {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now < self.residueClearUntil) return FCLegacyResidueNone;
    FCLegacyResidue residue = FCDetectLegacyResidue();
    self.residueClearUntil = residue ? 0 : now + 60;
    return residue;
}

- (NSDictionary *)registrationStatus {
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) return FCGateAnswer(gate);
    if (@available(macOS 14.0, *)) {
        FCLegacyResidue residue = [self legacyResidue];
        if (residue) return [self residueAnswer:residue code:self.migrationAttempted ? @"migrationIncomplete" : @"migrationRequired"];
        NSDictionary *retired = [self retiredRegistration];
        if (retired) return retired;
        switch ([self daemon].status) {
            case SMAppServiceStatusEnabled:
                [NSUserDefaults.standardUserDefaults setBool:YES forKey:FCApprovedDefault];
                return @{@"code": @"enabled"};
            case SMAppServiceStatusRequiresApproval:
                // Approved before and now needs approval again: the user switched it off in System Settings.
                return @{@"code": @"requiresApproval",
                    @"previouslyEnabled": @([NSUserDefaults.standardUserDefaults boolForKey:FCApprovedDefault])};
            case SMAppServiceStatusNotRegistered: return @{@"code": @"notRegistered"};
            // The bundle passed the full gate above (seal, pinned identity, daemon files present and exact): the
            // system has no record that matches this copy. The user can re-register it (serviceNotFound card).
            case SMAppServiceStatusNotFound:
                return @{@"code": @"serviceNotFound", @"source": @"service", @"serviceStatus": @"notFound",
                    @"detail": @"source: service (SMAppService status notFound; bundled daemon intact and trusted)"};
            default: return @{@"code": @"unavailable"};
        }
    }
    return @{@"code": @"unsupported"};
}

// The session outlives its connection: the daemon keeps the Core while this app process resumes the relay on a new
// one (verified again in full). The session ends only on the daemon's word (stop, or exit confirmed).
- (void)resetConnection {
    if (self.connection) xpc_connection_cancel(self.connection);
    self.connection = nil;
    self.connectionTrusted = NO;
    self.negotiatedCoreHash = nil;
}

// An authenticated reply from the daemon that runs this app's Core: it reports the very pid it started.
- (BOOL)servesSession:(NSDictionary *)answer {
    return self.sessionActive && self.corePid > 0 && [answer[@"protocol"] isEqual:@1] &&
        [answer[@"pid"] isEqual:@(self.corePid)];
}

// The session is held only while the daemon still answers: with no verified reply for FCSessionSilenceSeconds (it
// cannot be started, reached or verified), this app stops treating it as running, so repair, disable and the
// launchd check work again. Its Core, if any, is the daemon's to stop (grace period, or its own exit).
static const NSTimeInterval FCSessionSilenceSeconds = 30;
- (void)expireSilentSession {
    if (!self.sessionActive || [self uptime] - self.lastVerifiedReply < FCSessionSilenceSeconds) return;
    os_log(FCBridgeLog(), "no verified helper reply for %.0f s; session no longer held", [self uptime] - self.lastVerifiedReply);
    self.sessionActive = NO;
    [self forgetCore];
}

- (void)forgetCore {
    self.coreToken = nil;
    self.corePid = 0;
    self.coreSession = 0;
}

// The bridge queue only hands out the session; the bundled Core is validated once per session, and each
// call then asks the kernel about the running Core, both on the caller's queue.
- (NSString *)coreIdentity {
    __block NSData *token = nil;
    __block pid_t pid = 0;
    __block NSUInteger session = 0;
    dispatch_sync(self.queue, ^{
        token = self.coreToken;
        pid = self.corePid;
        session = self.coreSession;
    });
    if (!session) return @"none";
    NSData *expected = nil;
    @synchronized (self.identityLock) {
        if (self.hashSession != session) {
            self.expectedCoreHash = FCBundledCoreHash();
            self.hashSession = session;
        }
        expected = self.expectedCoreHash;
    }
    return FCCoreGuestCheck(token, pid, expected);
}

- (void)status:(void (^)(NSDictionary *))completion {
    // A recovery owns the registration; no hello (no reconnect) until it reports.
    if (self.operationInFlight) { completion(@{@"code": @"repairInProgress"}); return; }
    NSDictionary *registration = [self registrationStatus];
    NSString *code = registration[@"code"];
    if (![code isEqualToString:@"enabled"]) { completion(registration); return; }
    // While a Core session runs the helper evidently runs; otherwise ask launchd whether it can start it at all.
    // Only launchd's own word that it cannot start the job ("broken": needs LWCR update, or spawn failed) makes the
    // registration stale. Its parent bundle version lags after every app update until the next login and says
    // nothing: an old helper copy still idling (staleHelper) or a slow first start (timeout) is waited for, and a
    // refusal exit code (helper 79, launcher 81–87) is a card of its own.
    [self expireSilentSession];
    NSDictionary *job = self.sessionActive ? nil : [self launchdSnapshot];
    if ([job[@"state"] isEqual:@"broken"]) {
        completion(@{@"code": @"registrationStale", @"launchd": job[@"summary"] ?: @""}); return;
    }
    if (self.staleRetryAfter && [self.staleRetryAfter timeIntervalSinceNow] > 0) {
        completion(@{@"code": @"staleHelper"}); return;
    }
    [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
        NSString *result = FCStatusForHello(answer[@"code"]);
        // A helper process from the previous app build is still running: retire it before use. The daemon serving
        // this app's Core passed the reply check against the bundled helper; a different hash read here (the file
        // momentarily unreadable) does not take its session away.
        BOOL served = [self servesSession:answer];
        if ([result isEqualToString:@"enabled"] && !served && ![answer[@"helperCDHash"] isEqual:[self currentHelperHash]])
            result = @"staleHelper";
        if ([result isEqualToString:@"staleHelper"]) {
            // Do not keep the old daemon alive with status polling; its idle timeout is 30 seconds.
            self.staleRetryAfter = [NSDate dateWithTimeIntervalSinceNow:40];
            os_log(FCBridgeLog(), "status: helper of another build answered (session %{public}s); connection reset",
                self.sessionActive ? "running" : "none");
            [self resetConnection];
        } else {
            self.staleRetryAfter = nil;
        }
        NSMutableDictionary *status = [@{@"code": result} mutableCopy];
        // Why a reply was refused (verification step, XPC error) or that none came: "View details" only.
        NSString *replyDetail = [answer[@"detail"] isKindOfClass:NSString.class] ? answer[@"detail"] : nil;
        if (replyDetail.length) status[@"detail"] = replyDetail;
        // From an authenticated reply only: whether the daemon still owns a Core, so the app can let go of a
        // session it could not stop itself.
        if ([answer[@"protocol"] isEqual:@1]) {
            status[@"pid"] = answer[@"pid"] ?: @0;
            status[@"exitConfirmed"] = answer[@"exitConfirmed"] ?: @NO;
        }
        if (job[@"summary"]) status[@"launchd"] = job[@"summary"];
        // Enabled, yet the helper does not answer: say what the launcher reported, and how launchd saw this start
        // end (display only; nothing is re-registered for it).
        if ([@[@"timeout", @"unavailable"] containsObject:status[@"code"]]) {
            NSDictionary *after = self.sessionActive ? nil : [self launchdSnapshot];
            if (after[@"summary"]) status[@"launchd"] = after[@"summary"];
            if ([after[@"state"] isEqual:@"broken"]) {
                status[@"code"] = @"registrationStale";
                completion(status); return;
            }
            NSDictionary *launcher = FCRefusalExitAnswer(after, [self launcherReport]);
            if (launcher[@"code"]) status[@"code"] = launcher[@"code"];
            if (launcher[@"detail"]) status[@"detail"] = replyDetail.length ?
                [NSString stringWithFormat:@"%@\n%@", replyDetail, launcher[@"detail"]] : launcher[@"detail"];
        } else {
            self.okUnansweredSince = 0;
        }
        completion(status);
    }];
}

// FlashHelperLauncher's last outcome (root-owned status file), mapped to a card for an enabled helper that does not
// answer. Display only: it never enables, retries or trusts anything.
- (NSDictionary *)launcherReport {
    NSString *problem = nil;
    NSDictionary *launcher = FCReadLauncherStatus(FCLauncherStatusDirectory, 0, &problem);
    // After a record repair, the refusal it repaired (and launchd's exit code for it) is not shown again: until the
    // launcher has run once more, this is an ordinary start.
    if (self.recordRepairedAt && !problem && launcher) {
        if ([launcher[@"time"] doubleValue] < floor(self.recordRepairedAt))
            return @{@"superseded": @YES, @"detail": @"max-version repaired; the launcher has not run since"};
        self.recordRepairedAt = 0;
    }
    BOOL ok = !problem && [launcher[@"result"] isEqual:@"ok"];
    NSTimeInterval now = [self uptime];
    if (!ok) self.okUnansweredSince = 0;
    else if (!self.okUnansweredSince) self.okUnansweredSince = now;
    return FCLauncherAnswer(launcher, problem, self.launchedAt, ok ? now - self.okUnansweredSince : 0,
        [self bundleVersion]);
}

- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    NSData *frame = arguments[@"frame"];
    NSUInteger bytes = [frame isKindOfClass:NSData.class] ? frame.length : 0;
    if (self.pending >= 32 || bytes > FCMaxFrame || self.pendingBytes + bytes > FCMaxFrame) {
        completion(@{@"code": @"backpressure"}); return;
    }
    if (!self.connection) {
        NSString *requirement = FCSigningRequirement(FCHelperIdentifier);
        if (!requirement) { completion(@{@"code": @"signingRequired"}); return; }
        xpc_connection_t connection = xpc_connection_create_mach_service(FCHelperLabel.UTF8String,
            self.queue, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        if (xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)) {
            xpc_connection_cancel(connection); completion(@{@"code": @"signingRequired"}); return;
        }
        self.connection = connection;
        // The daemon runs as the launcher's root-only copy; its cdhash must be that of the helper sealed in the app.
        self.validator = [[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier
            executable:FCHelperCopyPath sealedExecutable:FCInstalledExecutable(FCHelperIdentifier)];
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            if (xpc_get_type(event) != XPC_TYPE_ERROR) return;
            const char *description = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION);
            os_log(FCBridgeLog(), "helper connection: %{public}s", description ?: "error");
            if (self.connection == connection) [self resetConnection];
        });
        xpc_connection_resume(connection);
    }
    xpc_connection_t connection = self.connection;
    FCMessageValidator *validator = self.validator;
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "method", method.UTF8String);
    xpc_dictionary_set_int64(message, "protocol", 1);
    NSString *session = arguments[@"session"];
    if ([session isKindOfClass:NSString.class]) xpc_dictionary_set_string(message, "session", session.UTF8String);
    if (frame && [frame isKindOfClass:NSData.class]) xpc_dictionary_set_data(message, "frame", frame.bytes, bytes);
    for (NSString *key in @[@"ack", @"seq"]) {
        NSNumber *number = arguments[key];
        if ([number isKindOfClass:NSNumber.class] && number.longLongValue >= 0)
            xpc_dictionary_set_uint64(message, key.UTF8String, number.unsignedLongLongValue);
    }
    if ([method isEqualToString:@"start"]) {
        if (!self.connectionTrusted || !FCCoreHashValid(self.negotiatedCoreHash)) {
            completion(@{@"code": @"incompatible"}); return;
        }
        xpc_dictionary_set_string(message, "coreHash", self.negotiatedCoreHash.UTF8String);
    }
    self.pending++;
    self.pendingBytes += bytes;
    __block BOOL finished = NO;
    void (^finish)(NSDictionary *) = ^(NSDictionary *answer) {
        if (finished) return;
        finished = YES;
        self.pending--;
        self.pendingBytes -= bytes;
        if ([method isEqualToString:@"start"] && [answer[@"code"] isEqual:@"ok"]) self.sessionActive = YES;
        if ([method isEqualToString:@"start"] || [method isEqualToString:@"stop"]) [self forgetCore];
        if ([method isEqualToString:@"start"] && [answer[@"code"] isEqual:@"ok"]) {
            self.coreToken = answer[@"coreAuditToken"];
            self.corePid = (pid_t)[answer[@"pid"] intValue];
            self.coreSession = ++self.coreSessions;
            answer = [answer mutableCopy];
            [(NSMutableDictionary *)answer removeObjectForKey:@"coreAuditToken"];
        }
        if ([answer[@"exitConfirmed"] isEqual:@YES]) {
            if (self.sessionActive)
                os_log(FCBridgeLog(), "%{public}s: helper confirmed the Core exited; session over", method.UTF8String);
            self.sessionActive = NO;
            [self forgetCore];
        }
        completion(answer);
    };
    xpc_connection_send_message_with_reply(connection, message, self.queue, ^(xpc_object_t reply) {
        if (finished) return;
        BOOL dictionary = xpc_get_type(reply) == XPC_TYPE_DICTIONARY;
        NSString *refusal = nil;
        // The helper answered, but its reply failed the app's verification: `untrustedReply`, never `unavailable`
        // (that reads as "not answering" and leads to the launcher's report and a re-registration, which cannot
        // change what the app verifies). Nothing in the reply is read.
        BOOL untrusted = NO;
        // The kernel could not be asked about the sender (it exited right after replying, ESRCH): refused all the
        // same, but reported as not answering (`unavailable`, asked again), never as a failed verification.
        BOOL transient = NO;
        if (!dictionary) {
            const char *description = reply == XPC_ERROR_CONNECTION_INVALID ? "connection invalid" :
                reply == XPC_ERROR_CONNECTION_INTERRUPTED ? "connection interrupted" :
                xpc_get_type(reply) == XPC_TYPE_ERROR ? xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION) : NULL;
            refusal = [NSString stringWithFormat:@"helper reply: XPC error (%s)", description ?: "unknown"];
        } else if (![validator check:reply]) {
            transient = validator.transientFailure;
            refusal = [NSString stringWithFormat:@"%@: %@", transient ? @"helper reply not verifiable (helper gone?)" :
                @"helper reply rejected by the app's verification", validator.failure ?: @"unknown step"];
            untrusted = !transient;
        } else if (xpc_dictionary_get_int64(reply, "protocol") != 1) {
            refusal = @"helper reply rejected: protocol is not 1";
        }
        if (refusal) {
            // Do not read payloads from a previous build even when its identity is pinned.
            BOOL stale = dictionary && validator.runningCodeStale;
            os_log_error(FCBridgeLog(), "%{public}s %{public}s", method.UTF8String, refusal.UTF8String);
            xpc_connection_cancel(connection);
            if (self.connection == connection) [self resetConnection];
            [self expireSilentSession];
            finish(@{@"code": stale ? @"staleHelper" : untrusted ? @"untrustedReply" : @"unavailable",
                @"detail": refusal}); return;
        }
        self.lastVerifiedReply = [self uptime];
        const char *code = xpc_dictionary_get_string(reply, "code");
        const char *hash = xpc_dictionary_get_string(reply, "coreHash");
        const char *helper = xpc_dictionary_get_string(reply, "helperCDHash");
        const char *build = xpc_dictionary_get_string(reply, "helperBuild");
        const char *reason = xpc_dictionary_get_string(reply, "reason");
        NSMutableDictionary *answer = [@{@"code": code ? @(code) : @"incompatible",
            @"protocol": @1, @"pid": @(xpc_dictionary_get_int64(reply, "pid")),
            @"exitConfirmed": @(xpc_dictionary_get_bool(reply, "exitConfirmed")),
            @"coreHash": hash ? @(hash) : @"", @"helperCDHash": helper ? @(helper) : @"",
            @"helperBuild": build ? @(build) : @""} mutableCopy];
        if ([method isEqualToString:@"retireCores"]) {
            answer[@"reason"] = reason ? @(reason) : @"";
            answer[@"stopped"] = @(xpc_dictionary_get_int64(reply, "stopped"));
        }
        size_t tokenSize = 0;
        const void *token = xpc_dictionary_get_data(reply, "coreAuditToken", &tokenSize);
        if (token && tokenSize == sizeof(audit_token_t)) answer[@"coreAuditToken"] = [NSData dataWithBytes:token length:tokenSize];
        size_t size = 0;
        const void *data = xpc_dictionary_get_data(reply, "frame", &size);
        if (size > FCMaxFrame) { finish(@{@"code": @"incompatible"}); return; }
        if (data) answer[@"frame"] = [NSData dataWithBytes:data length:size];
        xpc_object_t frames = xpc_dictionary_get_value(reply, "frames");
        if (frames) {
            NSArray<NSData *> *list = FCRelayFrames(frames);
            if (!list) { finish(@{@"code": @"incompatible"}); return; }
            answer[@"frames"] = list;
            answer[@"seq"] = @(xpc_dictionary_get_uint64(reply, "seq"));
        }
        if ([method isEqualToString:@"hello"] && [answer[@"code"] isEqual:@"ok"]) {
            const char *version = xpc_dictionary_get_string(reply, "coreVersion");
            const char *revision = xpc_dictionary_get_string(reply, "coreRevision");
            NSDictionary *contract = FCReadCompatibility(FCGUIBundle);
            NSDictionary *reported = @{@"CallerPolicy": @(xpc_dictionary_get_int64(reply, "callerPolicy")),
                @"ServiceAPI": @(xpc_dictionary_get_int64(reply, "serviceAPI")),
                @"CoreAPI": @(xpc_dictionary_get_int64(reply, "coreAPI")), @"CoreSHA256": contract[@"CoreSHA256"] ?: @"",
                @"CoreVersion": version ? @(version) : @"", @"CoreRevision": revision ? @(revision) : @""};
            if (!FCCompatibilityHelloMatches(contract, reported)) {
                self.negotiatedCoreHash = nil; finish(@{@"code": @"incompatible"}); return;
            }
            self.connectionTrusted = YES;
            self.negotiatedCoreHash = contract[@"CoreSHA256"];
        }
        finish(answer);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, FCRequestTimeoutSeconds(method) * NSEC_PER_SEC), self.queue, ^{
        if (finished) return;
        xpc_connection_cancel(connection);
        if (self.connection == connection) [self resetConnection];
        // No answer is not a statement about the Core: the daemon keeps it briefly for this process to resume the
        // relay on a new connection, then stops it; a later `hello` reports whether it still owns one.
        os_log_error(FCBridgeLog(), "%{public}s: no reply within %lld s", method.UTF8String,
            FCRequestTimeoutSeconds(method));
        [self expireSilentSession];
        finish(@{@"code": @"timeout", @"detail": [NSString stringWithFormat:@"helper reply: none within %lld s",
            FCRequestTimeoutSeconds(method)]});
    });
}

#pragma mark - Migration from the legacy LaunchDaemon

- (NSString *)authorizationOutcomeForAnswer:(NSAppleEventDescriptor *)answer error:(NSDictionary *)error {
    NSInteger number = [error[NSAppleScriptErrorNumber] integerValue];
    return answer && !error ? @"ok" :
        number == -128 || number == -60006 ? @"authorizationCancelled" :
        number == -60005 || number == -1743 ? @"authorizationDenied" : @"migrationFailed";
}

- (NSString *)administratorAppleScript:(NSString *)command {
    NSString *escaped = [[command stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges without altering line endings", escaped];
}

- (void)authorize:(NSString *)command completion:(void (^)(NSString *, NSString *))completion {
    NSString *source = [self administratorAppleScript:command];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *error = nil;
        NSAppleEventDescriptor *answer = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
        NSString *code = [self authorizationOutcomeForAnswer:answer error:error];
        NSString *output = answer.stringValue ?: @"";
        if (error) output = [NSString stringWithFormat:@"AppleScript error %@: %@",
            error[NSAppleScriptErrorNumber] ?: @"?", error[NSAppleScriptErrorMessage] ?: @""];
        dispatch_async(self.queue, ^{ completion(code, output); });
    });
}

- (NSDictionary *)migrationFailure:(NSString *)step detail:(NSString *)detail residue:(FCLegacyResidue)residue {
    return @{@"code": @"migrationFailed", @"step": step, @"detail": detail.length > 2000 ? [detail substringToIndex:2000] : detail ?: @"",
        @"residue": FCLegacyResidueNames(residue)};
}

- (BOOL)confirmed:(NSDictionary *)arguments {
    id value = arguments[@"confirmed"];
    return arguments.count == 1 && [value isEqual:@YES] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

- (void)migrateWithArguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    if (arguments.count > 1 || (arguments.count && !arguments[@"confirmed"])) {
        completion(@{@"code": @"invalidRequest"}); return;
    }
    if (![self confirmed:arguments]) { completion(@{@"code": @"consentRequired"}); return; }
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) { completion(FCGateAnswer(gate)); return; }
    if (!FCDetectLegacyResidue()) { [self registerWithCompletion:completion]; return; }
    self.operationInFlight = YES;
    [self authorize:FCLegacyCleanupScript() completion:^(NSString *outcome, NSString *output) {
        self.operationInFlight = NO;
        FCLegacyResidue residue = FCDetectLegacyResidue();
        if ([outcome isEqualToString:@"authorizationCancelled"] || [outcome isEqualToString:@"authorizationDenied"]) {
            // Nothing ran as root; keep the "update required" state and let the user start again.
            NSMutableDictionary *answer = [[self residueAnswer:residue code:outcome] mutableCopy];
            answer[@"status"] = residue ? (self.migrationAttempted ? @"migrationIncomplete" : @"migrationRequired") : @"notRegistered";
            completion(answer); return;
        }
        self.migrationAttempted = YES;
        NSDictionary *report = FCParseCleanupReport(output);
        if (residue) {
            NSString *step = [outcome isEqualToString:@"ok"] ? FCMigrationFailedStep(report, residue) : @"unknown";
            completion([self migrationFailure:step detail:report[@"detail"] ?: output residue:residue]); return;
        }
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCLegacyPendingDefault];
        [self registerWithCompletion:^(NSDictionary *answer) {
            if (![answer[@"code"] isEqual:@"registrationFailed"]) { completion(answer); return; }
            completion([self migrationFailure:@"registerNew"
                detail:[NSString stringWithFormat:@"%@ %@", answer[@"domain"], answer[@"error"]] residue:FCLegacyResidueNone]);
        }];
    }];
}

#pragma mark - Repair of the launcher's version record

// The launcher refused because its root-only max-version record is unreadable: one administrator prompt runs the
// fixed repair script (LauncherRecordRepair.h), then the helper is asked again (launchd starts the launcher on
// demand). Offered only while the launcher's own status says exactly that; never touches a valid record.
- (void)repairRecordWithArguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    if (arguments.count > 1 || (arguments.count && !arguments[@"confirmed"])) {
        completion(@{@"code": @"invalidRequest"}); return;
    }
    if (![self confirmed:arguments]) { completion(@{@"code": @"consentRequired"}); return; }
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) { completion(FCGateAnswer(gate)); return; }
    NSString *problem = nil;
    if (!FCLauncherRecordDamaged(FCReadLauncherStatus(FCLauncherStatusDirectory, 0, &problem))) {
        [self status:^(NSDictionary *answer) {
            NSMutableDictionary *result = [answer mutableCopy];
            result[@"recordRepair"] = @"notNeeded";
            completion(result);
        }];
        return;
    }
    self.operationInFlight = YES;
    [self authorize:FCLauncherRecordRepairScript() completion:^(NSString *authorization, NSString *output) {
        self.operationInFlight = NO;
        NSDictionary *report = FCParseRecordRepairReport(output);
        NSString *outcome = FCRecordRepairOutcome(authorization, report);
        os_log(FCBridgeLog(), "record repair: %{public}s (record=%{public}s reason=%{public}s)", outcome.UTF8String,
            [report[@"record"] ?: @"" UTF8String], [report[@"reason"] ?: @"" UTF8String]);
        NSString *line = report.count ? [NSString stringWithFormat:@"record repair: %@ (record=%@ reason=%@ version=%@)",
            outcome, report[@"record"] ?: @"", report[@"reason"] ?: @"", report[@"version"] ?: @""] :
            [NSString stringWithFormat:@"record repair: %@ %@", outcome, output.length > 400 ? [output substringToIndex:400] : output];
        if ([outcome isEqualToString:@"ok"]) {
            self.recordRepairedAt = NSDate.date.timeIntervalSince1970;
            self.staleRetryAfter = nil;
            [self resetConnection];
        }
        [self status:^(NSDictionary *answer) {
            NSMutableDictionary *result = [answer mutableCopy];
            result[@"recordRepair"] = outcome;
            NSString *detail = [answer[@"detail"] isKindOfClass:NSString.class] ? answer[@"detail"] : nil;
            result[@"detail"] = detail.length ? [NSString stringWithFormat:@"%@\n%@", line, detail] : line;
            completion(result);
        }];
    }];
}

#pragma mark - SMAppService registration

- (void)registerWithCompletion:(void (^)(NSDictionary *))completion {
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) { completion(FCGateAnswer(gate)); return; }
    FCLegacyResidue residue = FCDetectLegacyResidue();
    if (residue) { completion([self residueAnswer:residue code:@"migrationRequired"]); return; }
    if (@available(macOS 14.0, *)) {
        NSError *error = nil;
        BOOL registered = [[self daemon] registerAndReturnError:&error];
        SMAppServiceStatus status = [self daemon].status;
        if (registered || error.code == kSMErrorAlreadyRegistered ||
            status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval) {
            NSString *current = [self currentHelperHash];
            if (current.length) [NSUserDefaults.standardUserDefaults setObject:current forKey:FCRegisteredHelperDefault];
            [self status:completion]; return;
        }
        NSString *statusName = FCServiceStatusName(status);
        NSMutableDictionary *answer = [@{@"error": @(error.code), @"domain": error.domain ?: @"",
            @"serviceStatus": statusName,
            @"detail": [NSString stringWithFormat:@"register: %@; status: %@", FCErrorText(error), statusName]} mutableCopy];
        // Not a failure: the system waits for the user to allow Flash in Login Items.
        answer[@"code"] = FCApprovalError(error, statusName) ? @"requiresApproval" : @"registrationFailed";
        completion(answer);
        return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)unregisterWithCompletion:(void (^)(NSDictionary *))completion {
    [self expireSilentSession];
    if (self.sessionActive) { completion(@{@"code": @"sessionBusy"}); return; }
    NSString *gate = [self appGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    if (@available(macOS 14.0, *)) {
        os_log(FCBridgeLog(), "unregister: connection reset");
        [self resetConnection];
        NSError *error = nil;
        BOOL removed = [[self daemon] unregisterAndReturnError:&error];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCRegisteredHelperDefault];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCApprovedDefault];
        if (!removed && [self daemon].status != SMAppServiceStatusNotRegistered) {
            completion(@{@"code": @"registrationFailed", @"error": @(error.code), @"domain": error.domain ?: @"",
                @"detail": FCErrorText(error)});
            return;
        }
        [self status:completion]; return;
    }
    completion(@{@"code": @"unsupported"});
}

#pragma mark - Recovery of a stale registration

- (NSString *)bundleVersion {
    NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    return [version isKindOfClass:NSString.class] ? version : @"";
}

- (NSDictionary *)launchdSnapshot {
    return FCLaunchdSnapshot(FCHelperLabel, [self bundleVersion], 2);
}

- (NSString *)serviceStatusCode {
    if (@available(macOS 13.0, *)) return FCServiceStatusName([self daemon].status);
    return @"unknown";
}

- (NSError *)unregisterDaemonWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    *timedOut = NO;
    if (@available(macOS 13.0, *)) return FCUnregisterWithin([self daemon], timeout, timedOut);
    return [NSError errorWithDomain:@"FlashBridge" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"unsupported"}];
}

- (NSError *)unregisterRetiredWithin:(NSTimeInterval)timeout timedOut:(BOOL *)timedOut {
    *timedOut = NO;
    if (@available(macOS 13.0, *)) return FCUnregisterWithin([self retiredDaemon], timeout, timedOut);
    return [NSError errorWithDomain:@"FlashBridge" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"unsupported"}];
}

// Step 0 of a recovery: unregister the retired name, asynchronously, and count it done only in the completion (or
// report that none came). Its outcome is recorded; a failure never stops the new name from being registered.
// Returns nil when the retired name was not registered.
// One attempt per app build (persisted): a later launch of the same build does not try again.
- (NSString *)retireOldRegistration:(NSMutableArray<NSString *> *)log {
    if ([self retiredAttemptedThisBuild]) { self.retiredSettled = YES; return nil; }
    NSString *before = [self retiredStatusCode];
    if ([before isEqual:@"notRegistered"] || [before isEqual:@"notFound"]) { self.retiredSettled = YES; return nil; }
    [self recordRetiredAttempt];
    BOOL timedOut = NO;
    NSError *error = [self unregisterRetiredWithin:15 timedOut:&timedOut];
    NSString *outcome = timedOut ? @"timeout" : FCAlreadyUnregistered(error) ? @"ok" : @"failed";
    [log addObject:[NSString stringWithFormat:@"retired %@ (%@): unregister: %@; status: %@", FCRetiredHelperLabel, before,
        timedOut ? @"no completion within 15 s" : error ? FCErrorText(error) : @"ok", [self retiredStatusCode]]];
    self.retiredSettled = YES;
    return outcome;
}

- (NSError *)registerDaemon {
    if (@available(macOS 13.0, *)) {
        NSError *error = nil;
        @try {
            if ([[self daemon] registerAndReturnError:&error]) return nil;
        } @catch (NSException *exception) {
            return [NSError errorWithDomain:@"FlashBridge" code:-1
                userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: exception.name}];
        }
        return error ?: [NSError errorWithDomain:@"FlashBridge" code:-2
            userInfo:@{NSLocalizedDescriptionKey: @"register returned NO without an error"}];
    }
    return [NSError errorWithDomain:@"FlashBridge" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"unsupported"}];
}

- (void)pause:(NSTimeInterval)seconds { [NSThread sleepForTimeInterval:seconds]; }

- (NSTimeInterval)uptime { return NSProcessInfo.processInfo.systemUptime; }

// An authenticated hello from the repair queue; `request:` bounds it to 8 s.
- (NSDictionary *)helloFromRepairQueue {
    __block NSDictionary *answer = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(self.queue, ^{
        [self request:@"hello" arguments:@{} completion:^(NSDictionary *reply) {
            answer = reply;
            dispatch_semaphore_signal(done);
        }];
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) return @{@"code": @"timeout"};
    return answer ?: @{@"code": @"unavailable"};
}

// Re-registers a stale daemon registration (or moves from the retired name to the current one). Every step asks the
// system what happened instead of assuming it: unregister the retired name if it is still registered (its outcome is
// only recorded) → unregister (only if launchd still has the job) → wait until launchd dropped it → register → SMAppService.status →
// when enabled, wait for the new helper's authenticated hello. Nothing here starts a Core; the caller stopped its
// Core first, and the new helper stops any leftover Core by signature before the app starts one again.
- (NSDictionary *)recoverySequence {
    NSMutableArray<NSString *> *log = [NSMutableArray array];
    NSString *retired = [self retireOldRegistration:log];
    NSDictionary *(^done)(NSString *, NSDictionary *) = ^NSDictionary *(NSString *code, NSDictionary *extra) {
        NSMutableDictionary *answer = [@{@"code": code, @"detail": [log componentsJoinedByString:@"\n"]} mutableCopy];
        if (retired) answer[@"retiredUnregister"] = retired;
        if (extra) [answer addEntriesFromDictionary:extra];
        return answer;
    };
    NSDictionary *job = [self launchdSnapshot];
    [log addObject:[@"launchd before: " stringByAppendingString:job[@"summary"] ?: @"?"]];
    // Migrating only the retired name (whatever its unregister did): an enabled registration under the new name that
    // launchd has and does not call broken is kept as it is (re-adding it would ask the user to allow Flash again
    // for nothing). Its parent bundle version is not looked at: it lags after every update until the next login.
    if (retired && [[self serviceStatusCode] isEqual:@"enabled"] && job[@"state"] &&
        ![@[@"broken", @"missing"] containsObject:job[@"state"]]) {
        return [self awaitNewHelper:log done:done];
    }
    // Recovering from serviceNotFound: the system's record does not match this copy, whatever launchd shows, so it
    // is unregistered first; an error here (not found / not registered) is recorded and does not stop the register.
    if (self.serviceWasNotFound) [log addObject:@"service status before: notFound (unregister, then register)"];
    if (self.serviceWasNotFound || ![job[@"state"] isEqual:@"missing"]) {
        BOOL timedOut = NO;
        NSError *error = [self unregisterDaemonWithin:15 timedOut:&timedOut];
        [log addObject:timedOut ? @"unregister: no completion within 15 s" :
            [@"unregister: " stringByAppendingString:error ? FCErrorText(error) : @"ok"]];
        NSTimeInterval deadline = [self uptime] + 5;
        for (;;) {
            job = [self launchdSnapshot];
            if ([job[@"state"] isEqual:@"missing"] || [self uptime] >= deadline) break;
            [self pause:0.25];
        }
        [log addObject:[@"launchd after unregister: " stringByAppendingString:job[@"summary"] ?: @"?"]];
    }
    [self pause:1];
    NSError *registerError = nil;
    NSString *status = @"unknown";
    for (int attempt = 0; attempt < 2; attempt++) {
        registerError = [self registerDaemon];
        status = [self serviceStatusCode];
        [log addObject:[NSString stringWithFormat:@"register: %@; status: %@",
            registerError ? FCErrorText(registerError) : @"ok", status]];
        if (![status isEqual:@"notRegistered"] || FCApprovalError(registerError, status)) break;
        [self pause:1];
    }
    NSDictionary *errorFields = registerError ? @{@"domain": registerError.domain ?: @"", @"error": @(registerError.code),
        @"serviceStatus": status} : @{@"serviceStatus": status};
    // Re-adding a daemon leaves its Background Task item disabled: the user allows it once in System Settings.
    if ([status isEqual:@"requiresApproval"] || FCApprovalError(registerError, status))
        return done(@"requiresApproval", errorFields);
    // Still notFound after a fresh register: reported once with the register error and status; never retried here.
    if ([status isEqual:@"notFound"]) {
        NSMutableDictionary *fields = [errorFields mutableCopy];
        fields[@"source"] = @"service";
        fields[@"afterRepair"] = @YES;
        return done(@"serviceNotFound", fields);
    }
    if (![status isEqual:@"enabled"]) return done(@"registrationFailed", errorFields);
    return [self awaitNewHelper:log done:done];
}

// After the system reports the daemon enabled: wait (≤ 15 s) for the new build's authenticated hello. If launchd
// still cannot spawn it, say so in the details and stop; the app decides whether one more recovery is due.
- (NSDictionary *)awaitNewHelper:(NSMutableArray<NSString *> *)log done:(NSDictionary *(^)(NSString *, NSDictionary *))done {
    NSTimeInterval deadline = [self uptime] + 15;
    while ([self uptime] < deadline) {
        NSDictionary *job = [self launchdSnapshot];
        if ([job[@"state"] isEqual:@"broken"]) {
            [log addObject:[@"enabled, but launchd still cannot start the helper (launch constraint not refreshed): "
                stringByAppendingString:job[@"summary"] ?: @"?"]];
            return done(@"registrationStale", nil);
        }
        NSDictionary *hello = [self helloFromRepairQueue];
        NSString *code = hello[@"code"];
        if ([code isEqual:@"ok"] && [hello[@"helperCDHash"] isEqual:[self currentHelperHash]]) {
            [log addObject:@"new helper answered"];
            return done(@"enabled", @{@"protocol": @1, @"pid": hello[@"pid"] ?: @0,
                @"exitConfirmed": hello[@"exitConfirmed"] ?: @NO});
        }
        [log addObject:[NSString stringWithFormat:@"hello: %@%@", code ?: @"?",
            [hello[@"detail"] isKindOfClass:NSString.class] ? [@" — " stringByAppendingString:hello[@"detail"]] : @""]];
        // A reply the app cannot verify does not change with more waiting or another registration: stop here.
        if ([@[@"exitUnconfirmed", @"incompatible", @"signingRequired", @"untrustedReply"] containsObject:code ?: @""])
            return done(code, nil);
        [self pause:1];
    }
    return done(@"helperNotReady", nil);
}

- (void)recoverWithArguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    id written = arguments[@"repairRecordWritten"];
    if (arguments.count != 1 || !written || CFGetTypeID((__bridge CFTypeRef)written) != CFBooleanGetTypeID() ||
        ![written boolValue]) { completion(@{@"code": @"invalidRequest"}); return; }
    if (self.operationInFlight) { completion(@{@"code": @"operationInProgress"}); return; }
    if (self.pending) { completion(@{@"code": @"sessionBusy"}); return; }
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) { completion(FCGateAnswer(gate)); return; }
    FCLegacyResidue residue = FCDetectLegacyResidue();
    if (residue) { completion([self residueAnswer:residue code:@"migrationRequired"]); return; }
    if (@available(macOS 14.0, *)) {
        self.operationInFlight = YES;
        self.staleRetryAfter = nil;
        self.serviceWasNotFound = [[self serviceStatusCode] isEqual:@"notFound"];
        os_log(FCBridgeLog(), "recovery: connection reset");
        [self resetConnection];
        dispatch_async(self.repairQueue, ^{
            NSDictionary *answer = nil;
            @try {
                answer = [self recoverySequence];
            } @catch (NSException *exception) {
                answer = @{@"code": @"registrationFailed",
                    @"detail": [NSString stringWithFormat:@"exception %@: %@", exception.name, exception.reason ?: @""]};
            }
            dispatch_async(self.queue, ^{
                self.operationInFlight = NO;
                completion(answer);
            });
        });
        return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)repairWithCompletion:(void (^)(NSDictionary *))completion {
    [self expireSilentSession];
    if (self.sessionActive) { completion(@{@"code": @"sessionBusy"}); return; }
    [self status:completion];
}

- (void)openApprovalSettings:(void (^)(NSDictionary *))completion {
    NSString *gate = [self appGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    if (@available(macOS 14.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SMAppService openSystemSettingsLoginItems];
            dispatch_async(self.queue, ^{ completion(@{@"code": @"settingsOpened"}); });
        });
        return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))reply {
    // The app's own account of a relay it retried or lost (it grants nothing): the unified log then holds every
    // reason a session ended, from both sides of the bridge.
    if ([method isEqualToString:@"note"]) {
        NSString *reason = [arguments[@"reason"] isKindOfClass:NSString.class] ? arguments[@"reason"] : @"";
        if (reason.length > 300) reason = [reason substringToIndex:300];
        os_log(FCBridgeLog(), "app: %{public}s", reason.UTF8String);
        reply(@{@"code": @"ok"}); return;
    }
    // The app declared its relay lost: the session is no longer held here (its Core is the daemon's to stop), so
    // repair and disable are not refused for it. A later verified `exitConfirmed` or start settles the rest.
    if ([method isEqualToString:@"relayLost"]) {
        dispatch_async(self.queue, ^{
            if (self.sessionActive) os_log(FCBridgeLog(), "app declared the relay lost; session no longer held");
            self.sessionActive = NO;
            [self forgetCore];
            reply(@{@"code": @"ok"});
        });
        return;
    }
    BOOL relay = [@[@"stop", @"send", @"receive"] containsObject:method];
    // Every relay answer other than ok (and the bridge's own predispatch backpressure) is logged at default level.
    void (^completion)(NSDictionary *) = !relay ? reply : ^(NSDictionary *answer) {
        NSString *code = [answer[@"code"] isKindOfClass:NSString.class] ? answer[@"code"] : @"none";
        if (![code isEqual:@"ok"] && ![code isEqual:@"backpressure"])
            os_log(FCBridgeLog(), "%{public}s answered %{public}s (session %{public}s, connection %{public}s)",
                method.UTF8String, code.UTF8String, self.sessionActive ? "running" : "none",
                self.connectionTrusted ? "trusted" : "new");
        reply(answer);
    };
    dispatch_async(self.queue, ^{
        if (![self effectsAllowed]) { completion(@{@"code": @"disabled"}); return; }
        BOOL allowedDuringRepair = relay || [method isEqualToString:@"openApprovalSettings"] ||
            [method isEqualToString:@"status"] || [method isEqualToString:@"approvalStatus"];
        if (self.operationInFlight && !allowedDuringRepair) { completion(@{@"code": @"operationInProgress"}); return; }
        BOOL argumentless = !arguments.count;
        // Read-only SMAppService.status for polling while the user is in System Settings; it grants nothing,
        // a full status (trust gate and authenticated hello) follows once it reads enabled.
        if ([method isEqualToString:@"approvalStatus"]) { completion(@{@"code": [self serviceStatusCode]}); return; }
        if ([method isEqualToString:@"status"]) { [self status:completion]; return; }
        if ([method isEqualToString:@"migrate"]) { [self migrateWithArguments:arguments completion:completion]; return; }
        if ([method isEqualToString:@"recover"]) { [self recoverWithArguments:arguments completion:completion]; return; }
        if ([method isEqualToString:@"repairRecord"]) {
            [self repairRecordWithArguments:arguments completion:completion]; return;
        }
        if ([@[@"enable", @"disable", @"repair", @"openApprovalSettings"] containsObject:method] && !argumentless) {
            completion(@{@"code": @"invalidRequest"}); return;
        }
        if ([method isEqualToString:@"enable"]) { [self registerWithCompletion:completion]; return; }
        if ([method isEqualToString:@"disable"]) { [self unregisterWithCompletion:completion]; return; }
        if ([method isEqualToString:@"repair"]) { [self repairWithCompletion:completion]; return; }
        if ([method isEqualToString:@"openApprovalSettings"]) { [self openApprovalSettings:completion]; return; }
        if (![@[@"hello", @"start", @"stop", @"send", @"receive", @"retireCores"] containsObject:method]) {
            completion(@{@"code": @"invalidRequest"}); return;
        }
        if (relay && self.connectionTrusted) { [self request:method arguments:arguments completion:completion]; return; }
        // The relay of a running session reconnects with a fresh hello (verified in full): SMAppService's
        // registration was read when it started, and a momentary misread there must not end the session.
        // The app's own trust gate (bundle seal and location) is kept; only the SMAppService read is skipped.
        NSString *appGate = relay && self.sessionActive ? [self appGate] : nil;
        NSDictionary *registration = !appGate ? [self registrationStatus] :
            [appGate isEqualToString:@"trusted"] ? @{@"code": @"enabled"} : @{@"code": appGate};
        if (![registration[@"code"] isEqual:@"enabled"]) { completion(registration); return; }
        [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
            if (![answer[@"code"] isEqual:@"ok"]) { completion(answer); return; }
            if (![self servesSession:answer] && ![answer[@"helperCDHash"] isEqual:[self currentHelperHash]]) {
                os_log(FCBridgeLog(), "%{public}s: helper of another build answered", method.UTF8String);
                completion(@{@"code": @"staleHelper"}); return;
            }
            if ([method isEqualToString:@"hello"]) completion(answer);
            else [self request:method arguments:arguments completion:completion];
        }];
    });
}
@end
