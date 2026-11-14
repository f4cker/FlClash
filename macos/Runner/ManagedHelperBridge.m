#import "ManagedHelperBridge.h"
#import "../Shared/HelperTrust.h"
#import "../Shared/HelperIdentity.h"
#import "../Shared/HelperCompatibility.h"
#import "../Shared/LibraryConstraintPolicy.h"
#import <ServiceManagement/ServiceManagement.h>
#import <sys/stat.h>
#import <errno.h>
#import <limits.h>

@interface FCManagedHelperBridge ()
@property dispatch_queue_t queue;
@property xpc_connection_t connection;
@property NSUInteger pending;
@property NSUInteger pendingBytes;
@property FCMessageValidator *validator;
@property BOOL connectionTrusted;
@property NSString *negotiatedCoreHash;
@property BOOL installInFlight;
@property BOOL installationUncertain;
@end

@implementation FCManagedHelperBridge
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.layoute.flash.helper.bridge", DISPATCH_QUEUE_SERIAL);
        _installationUncertain = [self installerPending];
    }
    return self;
}

- (BOOL)installerPending {
    return [NSUserDefaults.standardUserDefaults objectForKey:@"FlashHelperInstallerPending"] != nil;
}

- (BOOL)writeInstallerPending:(BOOL)pending {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (pending) [defaults setBool:YES forKey:@"FlashHelperInstallerPending"];
    else [defaults removeObjectForKey:@"FlashHelperInstallerPending"];
    return [defaults synchronize];
}

- (BOOL)recordInstallerPending:(BOOL)pending {
    if (!pending && !self.installationUncertain) return YES;
    BOOL saved = [self writeInstallerPending:pending];
    self.installationUncertain = pending || !saved;
    return saved;
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
    if (@available(macOS 14.0, *)) {
        NSString *gui = FCGUIBundleTrust(NSBundle.mainBundle.bundlePath);
        if (![gui isEqualToString:@"trusted"]) return gui;
        struct stat state;
        if (lstat(FCInstalledBundle.fileSystemRepresentation, &state) < 0)
            return errno == ENOENT ? @"installerRequired" : @"protectedInstallationRequired";
        NSString *serviceTrust = FCBundleTrust(FCInstalledBundle);
        if (![serviceTrust isEqualToString:@"trusted"]) return serviceTrust;
        NSDictionary *service = FCReadCompatibility(FCInstalledBundle);
        if (!FCCompatibilityVersion(service[@"CallerPolicy"], 2)) return @"updateRequired";
        return FCCompatibilityAccepts(FCReadCompatibility(FCGUIBundle), service) ? @"trusted" : @"incompatible";
    }
    return @"unsupported";
}

- (NSString *)installationStatus {
    if (![self effectsAllowed]) return @"disabled";
    if (@available(macOS 14.0, *)) {
        NSString *gate = [self gate];
        if (![gate isEqualToString:@"trusted"]) return gate;
        if (!FCLegacyPlistTrusted()) return @"repairRequired";
        switch ([SMAppService statusForLegacyURL:[NSURL fileURLWithPath:FCLegacyPlist]]) {
            case SMAppServiceStatusEnabled: return @"enabled";
            case SMAppServiceStatusRequiresApproval: return @"approvalRequired";
            case SMAppServiceStatusNotRegistered: return @"off";
            case SMAppServiceStatusNotFound: return @"repairRequired";
            default: return @"installationUnknown";
        }
    }
    return @"unsupported";
}

- (void)status:(void (^)(NSDictionary *))completion {
    NSString *code = [self installationStatus];
    if (![code isEqualToString:@"enabled"]) { completion(@{@"code": code}); return; }
    [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
        NSString *code = [answer[@"code"] isEqual:@"ok"] ? @"enabled" :
            [answer[@"code"] isEqual:@"exitUnconfirmed"] || [answer[@"code"] isEqual:@"maintenance"] ? @"exitUnconfirmed" :
            [answer[@"code"] isEqual:@"incompatible"] ? @"incompatible" : @"unavailable";
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
                self.connectionTrusted = NO; self.negotiatedCoreHash = nil;
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
        completion(answer);
    };
    xpc_connection_send_message_with_reply(connection, message, self.queue, ^(xpc_object_t reply) {
        if (finished) return;
        if (xpc_get_type(reply) != XPC_TYPE_DICTIONARY || ![self.validator check:reply] ||
            xpc_dictionary_get_int64(reply, "protocol") != 1) {
            xpc_connection_cancel(connection);
            if (self.connection == connection) { self.connection = nil; self.connectionTrusted = NO; self.negotiatedCoreHash = nil; }
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
        if ([method isEqualToString:@"hello"] && [answer[@"code"] isEqual:@"ok"]) {
            const char *version = xpc_dictionary_get_string(reply, "coreVersion");
            const char *revision = xpc_dictionary_get_string(reply, "coreRevision");
            NSDictionary *service = FCReadCompatibility(FCInstalledBundle);
            NSDictionary *reported = @{@"CallerPolicy": @(xpc_dictionary_get_int64(reply, "callerPolicy")),
                @"ServiceAPI": @(xpc_dictionary_get_int64(reply, "serviceAPI")),
                @"CoreAPI": @(xpc_dictionary_get_int64(reply, "coreAPI")), @"CoreSHA256": answer[@"coreHash"],
                @"CoreVersion": version ? @(version) : @"", @"CoreRevision": revision ? @(revision) : @""};
            BOOL compatible = FCCompatibilityHelloMatches(FCReadCompatibility(FCGUIBundle), service, reported);
            if (!compatible) { self.negotiatedCoreHash = nil; finish(@{@"code": @"incompatible"}); return; }
            self.connectionTrusted = YES;
            self.negotiatedCoreHash = answer[@"coreHash"];
        }
        finish(answer);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), self.queue, ^{
        if (finished) return;
        xpc_connection_cancel(connection);
        if (self.connection == connection) { self.connection = nil; self.connectionTrusted = NO; self.negotiatedCoreHash = nil; }
        finish(@{@"code": @"exitUnconfirmed"});
    });
}

- (NSString *)installerGate {
    if (![self effectsAllowed]) return @"disabled";
    if (@available(macOS 14.0, *)) return FCGUIBundleTrust(NSBundle.mainBundle.bundlePath);
    return @"unsupported";
}

- (NSData *)validatedInstallerCodeHash {
    SecStaticCodeRef code = NULL;
    SecRequirementRef requirement = NULL;
    NSString *text = FCSplitGUIRequirement();
    if (!text || SecRequirementCreateWithString((__bridge CFStringRef)text, 0, &requirement)) return nil;
    BOOL valid = SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:FCGUIBundle], 0, &code) == errSecSuccess;
    valid = valid && SecStaticCodeCheckValidity(code,
        kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode, requirement) == errSecSuccess;
    CFDictionaryRef information = NULL;
    valid = valid && SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information) == errSecSuccess;
    NSDictionary *info = CFBridgingRelease(information);
    NSData *hash = valid ? info[(__bridge NSString *)kSecCodeInfoUnique] : nil;
    CFRelease(requirement);
    if (code) CFRelease(code);
    return FCGUILibraryPolicy(FCGUIBundle, hash) ? hash : nil;
}

- (BOOL)installerResources:(NSData *)resources codeDirectory:(NSData *)directory matchHash:(NSData *)validatedHash {
    NSData *cd = FCPolicyCodeDirectory(@{@0: directory ?: NSData.data});
    if (!cd || ![validatedHash isKindOfClass:NSData.class] || validatedHash.length != 20 ||
        ![FCPolicyDigest(cd, 20) isEqualToData:validatedHash]) return NO;
    const uint8_t *p = cd.bytes;
    uint32_t offset = FCRead32(p + 16, YES), special = FCRead32(p + 24, YES);
    return special >= 3 && resources && resources.length <= UINT32_MAX &&
        [[cd subdataWithRange:NSMakeRange(offset - 3 * 32, 32)] isEqualToData:FCPolicyDigest(resources, 32)];
}

- (NSString *)installerDigestHex:(NSData *)digest {
    NSMutableString *hex = [NSMutableString string];
    const uint8_t *bytes = digest.bytes;
    for (NSUInteger index = 0; index < digest.length; index++) [hex appendFormat:@"%02x", bytes[index]];
    return hex;
}

- (NSDictionary *)installerPayloadFromResources:(NSData *)resources manifest:(NSData *)data
    packageHashes:(NSDictionary *)hashes codeDirectory:(NSData *)directory validatedHash:(NSData *)validatedHash
    operation:(NSString *)operation {
    if (![operation isEqualToString:@"install"] ||
        ![self installerResources:resources codeDirectory:directory matchHash:validatedHash]) return nil;
    id seal = [NSPropertyListSerialization propertyListWithData:resources options:0 format:nil error:nil];
    if (![seal isKindOfClass:NSDictionary.class] || ![seal[@"files2"] isKindOfClass:NSDictionary.class] ||
        !data || data.length > 16384) return nil;
    NSDictionary *files = seal[@"files2"];
    for (NSString *name in @[@"manifest.json", @"Flash-helper-install.pkg"]) {
        id entry = files[[@"Resources/HelperInstaller" stringByAppendingPathComponent:name]];
        if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"hash2"] isKindOfClass:NSData.class] ||
            [entry[@"hash2"] length] != 32 || [entry[@"optional"] boolValue]) return nil;
        NSString *digest = [name isEqualToString:@"manifest.json"] ?
            [self installerDigestHex:FCPolicyDigest(data, 32)] : hashes[name];
        if (![[self installerDigestHex:entry[@"hash2"]] isEqualToString:digest]) return nil;
    }
    id manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![manifest isKindOfClass:NSDictionary.class] || [manifest count] != 2 ||
        !FCCompatibilityVersion(manifest[@"schema"], 1)) return nil;
    id packages = manifest[@"packages"];
    if (![packages isKindOfClass:NSDictionary.class] || [packages count] != 1) return nil;
    id package = packages[@"install"];
    NSString *name = @"Flash-helper-install.pkg";
    if (![package isKindOfClass:NSDictionary.class] || [package count] != 2 ||
        ![package[@"file"] isEqual:name] || !FCCoreHashValid(package[@"sha256"]) ||
        ![hashes[name] isEqual:package[@"sha256"]]) return nil;
    NSString *root = [FCGUIBundle stringByAppendingPathComponent:@"Contents/Resources/HelperInstaller"];
    return @{@"path": [root stringByAppendingPathComponent:name], @"sha256": package[@"sha256"]};
}

- (NSDictionary *)installerPayload:(NSString *)operation {
    NSString *root = [FCGUIBundle stringByAppendingPathComponent:@"Contents/Resources/HelperInstaller"];
    NSData *resources = [NSData dataWithContentsOfFile:
        [FCGUIBundle stringByAppendingPathComponent:@"Contents/_CodeSignature/CodeResources"]];
    NSData *directory = FCPolicyCodeDirectory(FCPolicyFile(
        [FCGUIBundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"]));
    NSMutableDictionary *hashes = [NSMutableDictionary dictionary];
    NSData *manifest = nil;
    for (NSString *name in @[@"manifest.json", @"Flash-helper-install.pkg"]) {
        NSString *path = [root stringByAppendingPathComponent:name];
        struct stat state;
        char canonical[PATH_MAX];
        if (lstat(path.fileSystemRepresentation, &state) || !S_ISREG(state.st_mode) || state.st_nlink != 1 ||
            !realpath(path.fileSystemRepresentation, canonical) || ![path isEqualToString:@(canonical)]) return nil;
        if ([name isEqualToString:@"manifest.json"]) {
            if (state.st_size > 16384) return nil;
            manifest = [NSData dataWithContentsOfFile:path];
        } else hashes[name] = FCSHA256(path);
    }
    // Authenticate the retained bytes, not a later successful check of mutable bundle paths.
    return [self installerPayloadFromResources:resources manifest:manifest packageHashes:hashes
        codeDirectory:directory validatedHash:[self validatedInstallerCodeHash] operation:operation];
}

- (NSString *)installerScript:(NSDictionary *)payload {
    NSString *(^quote)(NSString *) = ^NSString *(NSString *value) {
        return [NSString stringWithFormat:@"'%@'", [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
    };
    // Snapshot after authorization so the package cannot change while the system prompt is open.
    NSString *command = [NSString stringWithFormat:
        @"set -eu; umask 077; work=$(/usr/bin/mktemp -d /private/tmp/com.layoute.flash.helper.XXXXXXXX); "
         "trap '/bin/rm -rf -- \"$work\"' EXIT; "
         "/bin/cp %@ \"$work/installer.pkg\"; "
         "actual=$(/usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C /usr/bin/shasum -a 256 \"$work/installer.pkg\"); "
         "[ \"${actual%%%% *}\" = %@ ] || exit 65; "
         "/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/sbin/installer -pkg \"$work/installer.pkg\" -target / >/dev/null 2>&1",
        quote(payload[@"path"]), quote(payload[@"sha256"])];
    NSString *escaped = [[command stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", escaped];
}

- (NSString *)installerOutcomeForAnswer:(NSAppleEventDescriptor *)answer error:(NSDictionary *)error {
    NSInteger number = [error[NSAppleScriptErrorNumber] integerValue];
    return answer && !error ? @"ok" :
        number == -128 || number == -60006 ? @"authorizationCancelled" :
        number == -60005 || number == -1743 ? @"authorizationDenied" :
        number > 0 && number <= 255 ? @"installationFailed" : @"installationUnknown";
}

- (void)authorizeInstaller:(NSDictionary *)payload completion:(void (^)(NSString *))completion {
    NSString *source = [self installerScript:payload];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *error = nil;
        NSAppleEventDescriptor *answer = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
        NSString *code = [self installerOutcomeForAnswer:answer error:error];
        dispatch_async(self.queue, ^{ completion(code); });
    });
}

- (void)installWithArguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    if (arguments.count > 1 || (arguments.count && !arguments[@"confirmed"])) {
        completion(@{@"code": @"invalidRequest"}); return;
    }
    if (![arguments[@"confirmed"] isEqual:@YES] ||
        CFGetTypeID((__bridge CFTypeRef)arguments[@"confirmed"]) != CFBooleanGetTypeID()) {
        completion(@{@"code": @"consentRequired"}); return;
    }
    NSString *gate = [self installerGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    self.installInFlight = YES;
    void (^finish)(NSDictionary *) = ^(NSDictionary *answer) {
        self.installInFlight = NO;
        completion(answer);
    };
    [self status:^(NSDictionary *before) {
        NSString *status = before[@"code"];
        if ([status isEqualToString:@"enabled"]) {
            [self recordInstallerPending:NO];
            finish(before); return;
        }
        if ([status isEqualToString:@"approvalRequired"]) { finish(before); return; }
        if (self.installationUncertain || [@[@"unavailable", @"exitUnconfirmed", @"installationUnknown"] containsObject:status]) {
            [self recordInstallerPending:YES];
            finish(@{@"code": @"installationUnknown", @"installationStatus": status}); return;
        }
        if (![@[@"installerRequired", @"off", @"updateRequired", @"incompatible"] containsObject:status]) {
            finish(before); return;
        }
        NSDictionary *payload = [self installerPayload:@"install"];
        if (!payload) { finish(@{@"code": @"installerPayloadInvalid"}); return; }
        if (![self recordInstallerPending:YES]) {
            finish(@{@"code": @"installationUnknown"}); return;
        }
        [self authorizeInstaller:payload completion:^(NSString *outcome) {
            if ([@[@"authorizationCancelled", @"authorizationDenied", @"installationFailed"] containsObject:outcome])
                [self recordInstallerPending:NO];
            if (self.connection) xpc_connection_cancel(self.connection);
            self.connection = nil; self.connectionTrusted = NO; self.negotiatedCoreHash = nil;
            [self status:^(NSDictionary *after) {
                NSString *status = after[@"code"];
                NSString *code = [outcome isEqualToString:@"ok"] ?
                    ([@[@"enabled", @"approvalRequired"] containsObject:status] ? status : @"installationUnknown") : outcome;
                if ([status isEqualToString:@"enabled"]) [self recordInstallerPending:NO];
                finish(@{@"code": code, @"installationStatus": status});
            }];
        }];
    }];
}

- (void)openApprovalSettings:(void (^)(NSDictionary *))completion {
    NSString *gate = [self installerGate];
    if (![gate isEqualToString:@"trusted"]) { completion(@{@"code": gate}); return; }
    NSString *status = [self installationStatus];
    if (![status isEqualToString:@"approvalRequired"]) { [self status:completion]; return; }
    if (@available(macOS 14.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SMAppService openSystemSettingsLoginItems];
            dispatch_async(self.queue, ^{ completion(@{@"code": @"approvalRequired"}); });
        });
    }
}

- (void)invoke:(NSString *)method arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *))completion {
    dispatch_async(self.queue, ^{
        if (![self effectsAllowed]) { completion(@{@"code": @"disabled"}); return; }
        if (self.installInFlight && ![@[@"stop", @"send", @"receive"] containsObject:method]) {
            completion(@{@"code": @"installInProgress"}); return;
        }
        if ([method isEqualToString:@"status"]) {
            [self status:^(NSDictionary *answer) {
                NSString *code = answer[@"code"];
                if ([code isEqualToString:@"enabled"]) [self recordInstallerPending:NO];
                if (self.installationUncertain && ![code isEqualToString:@"approvalRequired"])
                    completion(@{@"code": @"installationUnknown", @"installationStatus": code});
                else completion(answer);
            }];
            return;
        }
        if ([method isEqualToString:@"installerInstructions"]) {
            [self installWithArguments:arguments completion:completion]; return;
        }
        if ([method isEqualToString:@"openApprovalSettings"]) {
            if (arguments.count) { completion(@{@"code": @"invalidRequest"}); return; }
            [self openApprovalSettings:completion]; return;
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
        if ([method isEqualToString:@"start"]) {
            [self request:@"hello" arguments:@{} completion:^(NSDictionary *answer) {
                if (![answer[@"code"] isEqual:@"ok"]) { completion(answer); return; }
                [self request:method arguments:arguments completion:completion];
            }];
        } else [self request:method arguments:arguments completion:completion];
    });
}
@end
