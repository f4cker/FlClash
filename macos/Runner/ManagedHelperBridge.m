#import "ManagedHelperBridge.h"
#import "../Shared/HelperTrust.h"
#import "../Shared/HelperIdentity.h"
#import <ServiceManagement/ServiceManagement.h>

@interface FCManagedHelperBridge ()
@property dispatch_queue_t queue;
@property xpc_connection_t connection;
@property NSUInteger pending;
@property NSUInteger pendingBytes;
@property FCMessageValidator *validator;
@property BOOL connectionTrusted;
@end

@implementation FCManagedHelperBridge
- (instancetype)init {
    if ((self = [super init])) _queue = dispatch_queue_create("com.layoute.flash.helper.bridge", DISPATCH_QUEUE_SERIAL);
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

- (NSString *)gate {
    if (![self effectsAllowed]) return @"disabled";
    if (@available(macOS 13.0, *)) return FCBundleTrust(NSBundle.mainBundle.bundlePath);
    return @"unsupported";
}

- (NSString *)installationStatus {
    if (![self effectsAllowed]) return @"disabled";
    if (@available(macOS 13.0, *)) {
        NSString *gate = self.connectionTrusted ? @"trusted" : [self gate];
        if (![gate isEqualToString:@"trusted"]) return gate;
        if (!FCLegacyPlistTrusted()) return @"repairRequired";
        switch ([SMAppService statusForLegacyURL:[NSURL fileURLWithPath:FCLegacyPlist]]) {
            case SMAppServiceStatusEnabled: return @"enabled";
            case SMAppServiceStatusRequiresApproval: return @"approvalRequired";
            case SMAppServiceStatusNotRegistered: return @"off";
            case SMAppServiceStatusNotFound: return @"repairRequired";
        }
    }
    return @"unsupported";
}

- (void)status:(void (^)(NSDictionary *))completion {
    NSString *code = [self installationStatus];
    if (![code isEqualToString:@"enabled"]) { completion(@{@"code": code}); return; }
    [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
        NSString *code = [answer[@"code"] isEqual:@"ok"] ? @"enabled" :
            [answer[@"code"] isEqual:@"exitUnconfirmed"] || [answer[@"code"] isEqual:@"maintenance"] ? @"exitUnconfirmed" : @"unavailable";
        completion(@{@"code": code});
    }];
}

- (void)request:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    NSData *frame = arguments[@"frame"];
    NSUInteger bytes = [frame isKindOfClass:NSData.class] ? frame.length : 0;
    if (self.pending >= 32 || bytes > FCMaxFrame || self.pendingBytes + bytes > FCMaxFrame) {
        completion(@{@"code": @"backpressure"}); return;
    }
    if (!self.connection) {
        NSString *requirement = FCSigningRequirement(FCHelperLabel);
        if (!requirement) { completion(@{@"code": @"signingRequired"}); return; }
        xpc_connection_t connection = xpc_connection_create_mach_service(FCHelperLabel.UTF8String,
            self.queue, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        if (xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)) {
            xpc_connection_cancel(connection); completion(@{@"code": @"signingRequired"}); return;
        }
        self.connection = connection;
        self.validator = [[FCMessageValidator alloc] initWithIdentifier:FCHelperLabel
            executable:FCInstalledExecutable(FCHelperLabel) bundle:nil];
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            if (xpc_get_type(event) == XPC_TYPE_ERROR && self.connection == connection) {
                xpc_connection_cancel(connection);
                self.connection = nil;
                self.connectionTrusted = NO;
            }
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
    if ([method isEqualToString:@"start"] || [method isEqualToString:@"hello"]) {
        NSString *hash = FCSHA256([NSBundle.mainBundle.bundlePath
            stringByAppendingPathComponent:@"Contents/MacOS/FlClashCore"]);
        xpc_dictionary_set_string(message, "coreHash", hash.UTF8String);
    }
    self.pending++;
    self.pendingBytes += bytes;
    __block BOOL finished = NO;
    void (^finish)(NSDictionary *) = ^(NSDictionary *answer) {
        if (finished) return;
        finished = YES;
        self.pending--;
        self.pendingBytes -= bytes;
        completion(answer);
    };
    xpc_connection_send_message_with_reply(connection, message, self.queue, ^(xpc_object_t reply) {
        if (finished) return;
        if (xpc_get_type(reply) != XPC_TYPE_DICTIONARY || ![self.validator check:reply] ||
            xpc_dictionary_get_int64(reply, "protocol") != 1) {
            xpc_connection_cancel(connection);
            if (self.connection == connection) { self.connection = nil; self.connectionTrusted = NO; }
            finish(@{@"code": @"unavailable"}); return;
        }
        const char *code = xpc_dictionary_get_string(reply, "code");
        const char *hash = xpc_dictionary_get_string(reply, "coreHash");
        NSMutableDictionary *answer = [@{@"code": code ? @(code) : @"incompatible",
            @"protocol": @1, @"pid": @(xpc_dictionary_get_int64(reply, "pid")),
            @"exitConfirmed": @(xpc_dictionary_get_bool(reply, "exitConfirmed")),
            @"coreHash": hash ? @(hash) : @""} mutableCopy];
        size_t size = 0;
        const void *data = xpc_dictionary_get_data(reply, "frame", &size);
        if (size > FCMaxFrame) { finish(@{@"code": @"incompatible"}); return; }
        if (data) answer[@"frame"] = [NSData dataWithBytes:data length:size];
        self.connectionTrusted = YES;
        finish(answer);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), self.queue, ^{
        if (finished) return;
        xpc_connection_cancel(connection);
        if (self.connection == connection) { self.connection = nil; self.connectionTrusted = NO; }
        finish(@{@"code": @"exitUnconfirmed"});
    });
}

- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    dispatch_async(self.queue, ^{
        if ([method isEqualToString:@"status"]) { [self status:completion]; return; }
        if (![self effectsAllowed]) { completion(@{@"code": @"disabled"}); return; }
        if ([method isEqualToString:@"installerInstructions"]) {
            completion(@{@"code": [arguments[@"confirmed"] isEqual:@YES] ? @"installerRequired" : @"consentRequired"});
            return;
        }
        BOOL relay = [@[@"stop", @"send", @"receive"] containsObject:method];
        NSString *gate = relay && self.connectionTrusted ? @"trusted" : [self gate];
        if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
        if (![@[@"hello", @"start", @"stop", @"send", @"receive"] containsObject:method]) {
            completion(@{@"code": @"invalidRequest"}); return;
        }
        if (!relay) {
            NSString *status = [self installationStatus];
            if (![status isEqualToString:@"enabled"]) { completion(@{@"code": status}); return; }
        }
        [self request:method arguments:arguments completion:completion];
    });
}
@end
