#import "ManagedHelperBridge.h"
#import "../Shared/HelperTrust.h"
#import "../Shared/HelperIdentity.h"
#import "../Shared/HelperCompatibility.h"
#import "../Shared/LegacyResidue.h"
#import <ServiceManagement/ServiceManagement.h>

// Bookkeeping of the helper build last registered with SMAppService (re-register after an app update).
static NSString * const FCRegisteredHelperDefault = @"FlashDaemonRegisteredHelperCDHash";
// Set once the daemon was seen enabled; distinguishes "turned off by the user" from "never approved".
static NSString * const FCApprovedDefault = @"FlashDaemonApproved";

@interface FCManagedHelperBridge ()
@property dispatch_queue_t queue;
@property xpc_connection_t connection;
@property NSUInteger pending;
@property NSUInteger pendingBytes;
@property FCMessageValidator *validator;
@property BOOL connectionTrusted;
@property NSString *negotiatedCoreHash;
@property BOOL sessionActive;
@property BOOL operationInFlight;
@property BOOL migrationAttempted;
@property BOOL reRegistrationChecked;
// The Core of the running session, as the daemon saw it on the relay socket.
@property NSData *coreToken;
@property pid_t corePid;
@property BOOL coreChecked;
@end

@implementation FCManagedHelperBridge
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.layoute.flash.daemon.bridge", DISPATCH_QUEUE_SERIAL);
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

- (NSDictionary *)registrationStatus {
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) return @{@"code": gate};
    if (@available(macOS 14.0, *)) {
        FCLegacyResidue residue = FCDetectLegacyResidue();
        if (residue) return [self residueAnswer:residue code:self.migrationAttempted ? @"migrationIncomplete" : @"migrationRequired"];
        switch ([self daemon].status) {
            case SMAppServiceStatusEnabled:
                [NSUserDefaults.standardUserDefaults setBool:YES forKey:FCApprovedDefault];
                return @{@"code": @"enabled"};
            case SMAppServiceStatusRequiresApproval:
                // Approved before and now needs approval again: the user switched it off in System Settings.
                return @{@"code": @"requiresApproval",
                    @"previouslyEnabled": @([NSUserDefaults.standardUserDefaults boolForKey:FCApprovedDefault])};
            case SMAppServiceStatusNotRegistered: return @{@"code": @"notRegistered"};
            case SMAppServiceStatusNotFound: return @{@"code": @"notFound"};
            default: return @{@"code": @"unavailable"};
        }
    }
    return @{@"code": @"unsupported"};
}

- (void)resetConnection {
    if (self.connection) xpc_connection_cancel(self.connection);
    self.connection = nil;
    self.connectionTrusted = NO;
    self.negotiatedCoreHash = nil;
    self.sessionActive = NO;
    [self forgetCore];
}

- (void)forgetCore {
    self.coreToken = nil;
    self.corePid = 0;
    self.coreChecked = NO;
}

- (NSString *)checkCore {
    if (!self.coreChecked) return @"none";
    return FCCoreGuestValid(self.coreToken, self.corePid) ? @"verified" : @"failed";
}

- (NSString *)coreIdentity {
    __block NSString *identity = @"none";
    dispatch_sync(self.queue, ^{ identity = [self checkCore]; });
    return identity;
}

// After an app update the registered job may still describe the previous build; re-register once per launch
// while no session runs so launchd/BTM pick up the new helper.
- (void)reRegisterIfUpdated {
    if (self.reRegistrationChecked || self.sessionActive) return;
    self.reRegistrationChecked = YES;
    NSString *current = [self currentHelperHash];
    NSString *stored = [NSUserDefaults.standardUserDefaults stringForKey:FCRegisteredHelperDefault];
    if (!current.length || [stored isEqualToString:current]) return;
    if (@available(macOS 14.0, *)) {
        if (stored.length) {
            [self resetConnection];
            [[self daemon] unregisterAndReturnError:nil];
        }
        if ([[self daemon] registerAndReturnError:nil] || [self daemon].status != SMAppServiceStatusNotRegistered)
            [NSUserDefaults.standardUserDefaults setObject:current forKey:FCRegisteredHelperDefault];
    }
}

- (void)status:(void (^)(NSDictionary *))completion {
    NSDictionary *registration = [self registrationStatus];
    NSString *code = registration[@"code"];
    if ([@[@"enabled", @"requiresApproval"] containsObject:code]) {
        [self reRegisterIfUpdated];
        registration = [self registrationStatus];
        code = registration[@"code"];
    }
    if (![code isEqualToString:@"enabled"]) { completion(registration); return; }
    [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
        NSString *reply = answer[@"code"];
        NSString *result = [reply isEqual:@"ok"] ? @"enabled" :
            [reply isEqual:@"exitUnconfirmed"] ? @"exitUnconfirmed" :
            [reply isEqual:@"incompatible"] ? @"incompatible" : @"unavailable";
        // A helper process from the previous app build is still running: retire it before use.
        if ([result isEqualToString:@"enabled"] && ![answer[@"helperCDHash"] isEqual:[self currentHelperHash]])
            result = @"staleHelper";
        completion(@{@"code": result});
    }];
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
        self.validator = [[FCMessageValidator alloc] initWithIdentifier:FCHelperIdentifier
            executable:FCInstalledExecutable(FCHelperIdentifier)];
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            if (xpc_get_type(event) == XPC_TYPE_ERROR && self.connection == connection) [self resetConnection];
        });
        xpc_connection_resume(connection);
    }
    xpc_connection_t connection = self.connection;
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "method", method.UTF8String);
    xpc_dictionary_set_int64(message, "protocol", 1);
    NSString *session = arguments[@"session"];
    if ([session isKindOfClass:NSString.class]) xpc_dictionary_set_string(message, "session", session.UTF8String);
    if (frame && [frame isKindOfClass:NSData.class]) xpc_dictionary_set_data(message, "frame", frame.bytes, bytes);
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
            self.coreChecked = YES;
            answer = [answer mutableCopy];
            ((NSMutableDictionary *)answer)[@"coreIdentity"] = [self checkCore];
            [(NSMutableDictionary *)answer removeObjectForKey:@"coreAuditToken"];
        }
        if ([answer[@"exitConfirmed"] isEqual:@YES]) self.sessionActive = NO;
        completion(answer);
    };
    xpc_connection_send_message_with_reply(connection, message, self.queue, ^(xpc_object_t reply) {
        if (finished) return;
        if (xpc_get_type(reply) != XPC_TYPE_DICTIONARY || ![self.validator check:reply] ||
            xpc_dictionary_get_int64(reply, "protocol") != 1) {
            xpc_connection_cancel(connection);
            if (self.connection == connection) [self resetConnection];
            finish(@{@"code": @"unavailable"}); return;
        }
        const char *code = xpc_dictionary_get_string(reply, "code");
        const char *hash = xpc_dictionary_get_string(reply, "coreHash");
        const char *helper = xpc_dictionary_get_string(reply, "helperCDHash");
        const char *build = xpc_dictionary_get_string(reply, "helperBuild");
        NSMutableDictionary *answer = [@{@"code": code ? @(code) : @"incompatible",
            @"protocol": @1, @"pid": @(xpc_dictionary_get_int64(reply, "pid")),
            @"exitConfirmed": @(xpc_dictionary_get_bool(reply, "exitConfirmed")),
            @"coreHash": hash ? @(hash) : @"", @"helperCDHash": helper ? @(helper) : @"",
            @"helperBuild": build ? @(build) : @""} mutableCopy];
        size_t tokenSize = 0;
        const void *token = xpc_dictionary_get_data(reply, "coreAuditToken", &tokenSize);
        if (token && tokenSize == sizeof(audit_token_t)) answer[@"coreAuditToken"] = [NSData dataWithBytes:token length:tokenSize];
        size_t size = 0;
        const void *data = xpc_dictionary_get_data(reply, "frame", &size);
        if (size > FCMaxFrame) { finish(@{@"code": @"incompatible"}); return; }
        if (data) answer[@"frame"] = [NSData dataWithBytes:data length:size];
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), self.queue, ^{
        if (finished) return;
        xpc_connection_cancel(connection);
        if (self.connection == connection) [self resetConnection];
        finish(@{@"code": @"exitUnconfirmed"});
    });
}

#pragma mark - Migration from the legacy LaunchDaemon

- (NSString *)authorizationOutcomeForAnswer:(NSAppleEventDescriptor *)answer error:(NSDictionary *)error {
    NSInteger number = [error[NSAppleScriptErrorNumber] integerValue];
    return answer && !error ? @"ok" :
        number == -128 || number == -60006 ? @"authorizationCancelled" :
        number == -60005 || number == -1743 ? @"authorizationDenied" : @"migrationFailed";
}

- (NSString *)migrationAppleScript {
    NSString *command = FCLegacyCleanupScript();
    NSString *escaped = [[command stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges without altering line endings", escaped];
}

- (void)authorizeCleanup:(void (^)(NSString *, NSString *))completion {
    NSString *source = [self migrationAppleScript];
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
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    if (!FCDetectLegacyResidue()) { [self registerWithCompletion:completion]; return; }
    self.operationInFlight = YES;
    [self authorizeCleanup:^(NSString *outcome, NSString *output) {
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

#pragma mark - SMAppService registration

- (void)registerWithCompletion:(void (^)(NSDictionary *))completion {
    NSString *gate = [self gate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
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
            self.reRegistrationChecked = YES;
            [self status:completion]; return;
        }
        completion(@{@"code": @"registrationFailed", @"error": @(error.code), @"domain": error.domain ?: @""});
        return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)unregisterWithCompletion:(void (^)(NSDictionary *))completion {
    if (self.sessionActive) { completion(@{@"code": @"sessionBusy"}); return; }
    NSString *gate = [self appGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    if (@available(macOS 14.0, *)) {
        [self resetConnection];
        NSError *error = nil;
        BOOL removed = [[self daemon] unregisterAndReturnError:&error];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCRegisteredHelperDefault];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:FCApprovedDefault];
        if (!removed && [self daemon].status != SMAppServiceStatusNotRegistered) {
            completion(@{@"code": @"registrationFailed", @"error": @(error.code), @"domain": error.domain ?: @""});
            return;
        }
        [self status:completion]; return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)repairWithCompletion:(void (^)(NSDictionary *))completion {
    if (self.sessionActive) { completion(@{@"code": @"sessionBusy"}); return; }
    [self status:^(NSDictionary *before) {
        if ([before[@"code"] isEqual:@"staleHelper"]) {
            // Ask the previous build's daemon to leave; launchd starts the current binary on the next request.
            [self request:@"exit" arguments:@{} completion:^(NSDictionary *answer) {
                [self resetConnection];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), self.queue, ^{
                    [self status:completion];
                });
            }];
            return;
        }
        if ([@[@"migrationRequired", @"migrationIncomplete", @"disabled", @"unsupported", @"signingRequired",
              @"moveRequired", @"notFound", @"incompatible"] containsObject:before[@"code"]]) {
            completion(before); return;
        }
        [self unregisterWithCompletion:^(NSDictionary *removed) {
            if ([removed[@"code"] isEqual:@"registrationFailed"] || [removed[@"code"] isEqual:@"sessionBusy"]) {
                completion(removed); return;
            }
            [self registerWithCompletion:completion];
        }];
    }];
}

- (void)openApprovalSettings:(void (^)(NSDictionary *))completion {
    NSString *gate = [self appGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    if (@available(macOS 14.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SMAppService openSystemSettingsLoginItems];
            dispatch_async(self.queue, ^{ completion([self registrationStatus]); });
        });
        return;
    }
    completion(@{@"code": @"unsupported"});
}

- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    dispatch_async(self.queue, ^{
        if (![self effectsAllowed]) { completion(@{@"code": @"disabled"}); return; }
        BOOL relay = [@[@"stop", @"send", @"receive"] containsObject:method];
        if (self.operationInFlight && !relay) { completion(@{@"code": @"operationInProgress"}); return; }
        BOOL argumentless = !arguments.count;
        if ([method isEqualToString:@"status"]) { [self status:completion]; return; }
        if ([method isEqualToString:@"coreIdentity"]) { completion(@{@"code": [self checkCore]}); return; }
        if ([method isEqualToString:@"migrate"]) { [self migrateWithArguments:arguments completion:completion]; return; }
        if ([@[@"enable", @"disable", @"repair", @"openApprovalSettings"] containsObject:method] && !argumentless) {
            completion(@{@"code": @"invalidRequest"}); return;
        }
        if ([method isEqualToString:@"enable"]) { [self registerWithCompletion:completion]; return; }
        if ([method isEqualToString:@"disable"]) { [self unregisterWithCompletion:completion]; return; }
        if ([method isEqualToString:@"repair"]) { [self repairWithCompletion:completion]; return; }
        if ([method isEqualToString:@"openApprovalSettings"]) { [self openApprovalSettings:completion]; return; }
        if (![@[@"hello", @"start", @"stop", @"send", @"receive"] containsObject:method]) {
            completion(@{@"code": @"invalidRequest"}); return;
        }
        if (relay && self.connectionTrusted) { [self request:method arguments:arguments completion:completion]; return; }
        NSDictionary *registration = [self registrationStatus];
        if (![registration[@"code"] isEqual:@"enabled"]) { completion(registration); return; }
        [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
            if (![answer[@"code"] isEqual:@"ok"]) { completion(answer); return; }
            if (![answer[@"helperCDHash"] isEqual:[self currentHelperHash]]) { completion(@{@"code": @"staleHelper"}); return; }
            if ([method isEqualToString:@"hello"]) completion(answer);
            else [self request:method arguments:arguments completion:completion];
        }];
    });
}
@end
