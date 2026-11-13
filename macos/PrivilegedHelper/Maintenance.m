#import "../Shared/HelperTrust.h"
#import "MaintenancePolicy.h"
#import "RemovalPolicy.h"
#import <ServiceManagement/ServiceManagement.h>
#import <servers/bootstrap.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdio.h>
#import "../Shared/ProtectedPathPolicy.h"

static BOOL FCAbsent(NSString *path) {
    struct stat state;
    return lstat(path.fileSystemRepresentation, &state) < 0 && errno == ENOENT;
}

static BOOL FCMachAbsent(void) {
    mach_port_t service = MACH_PORT_NULL;
    kern_return_t result = bootstrap_look_up(bootstrap_port, FCHelperLabel.UTF8String, &service);
    if (service != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), service);
    return result == BOOTSTRAP_UNKNOWN_SERVICE;
}

static BOOL FCPreflightFailure(const char *diagnostic) {
    fprintf(stderr, "FlashMaintenance: %s\n", diagnostic);
    return NO;
}

static int FCResult(BOOL success, const char *diagnostic) {
    return success ? 0 : (FCPreflightFailure(diagnostic), 78);
}

static BOOL FCPrivateRuntimeNode(NSString *path, BOOL directory) {
    struct stat state;
    return FCProtectedTree(path, NO) && lstat(path.fileSystemRepresentation, &state) == 0 &&
        (directory ? S_ISDIR(state.st_mode) : S_ISREG(state.st_mode)) &&
        (state.st_mode & 07777) == (directory ? 0700 : 0600);
}

static BOOL FCParentsSafe(void) {
    NSString *base = FCRuntimeDirectory.stringByDeletingLastPathComponent;
    if (!FCProtectedTree(@"/Library/LaunchDaemons", NO))
        return FCPreflightFailure("launch-daemon-parent-unsafe");
    BOOL absent = FCAbsent(base);
    if (!FCProtectedTree(absent ? base.stringByDeletingLastPathComponent : base, NO))
        return FCPreflightFailure(absent ? "owned-base-parent-unsafe" : "owned-base-unsafe");
    if (!FCAbsent(FCRuntimeDirectory) && !FCPrivateRuntimeNode(FCRuntimeDirectory, YES))
        return FCPreflightFailure("runtime-root-unsafe");
    return YES;
}

static BOOL FCRecordRemovalHandoff(void);

static BOOL FCPrepare(void) {
    NSString *requirement = FCSigningRequirement(FCHelperLabel);
    if (!requirement || ![FCBundleTrust(FCInstalledBundle) isEqual:@"trusted"] || !FCLegacyPlistTrusted()) return NO;
    dispatch_queue_t queue = dispatch_queue_create("com.layoute.flash.maintenance", DISPATCH_QUEUE_SERIAL);
    xpc_connection_t connection = xpc_connection_create_mach_service(FCHelperLabel.UTF8String,
        queue, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    if (xpc_connection_set_peer_code_signing_requirement(connection, requirement.UTF8String)) {
        xpc_connection_cancel(connection); return NO;
    }
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {});
    xpc_connection_resume(connection);
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    NSString *nonce = NSUUID.UUID.UUIDString;
    xpc_dictionary_set_string(message, "method", "prepareMaintenance");
    xpc_dictionary_set_string(message, "nonce", nonce.UTF8String);
    xpc_dictionary_set_int64(message, "protocol", 1);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block BOOL accepted = NO;
    xpc_connection_send_message_with_reply(connection, message, queue, ^(xpc_object_t reply) {
        const char *code = xpc_get_type(reply) == XPC_TYPE_DICTIONARY ? xpc_dictionary_get_string(reply, "code") : NULL;
        const char *echo = code ? xpc_dictionary_get_string(reply, "nonce") : NULL;
        BOOL authenticated = code && !strcmp(code, "ok") && echo && [@(echo) isEqual:nonce] &&
            xpc_dictionary_get_int64(reply, "protocol") == 1 && xpc_dictionary_get_int64(reply, "pid") == 0 &&
            xpc_connection_get_euid(connection) == 0 &&
            FCCheckMessage(reply, FCHelperLabel);
        accepted = authenticated && FCMaintenanceReady(authenticated, xpc_dictionary_get_bool(reply, "frozen"),
            xpc_dictionary_get_bool(reply, "exitConfirmed"), (pid_t)xpc_dictionary_get_int64(reply, "pid"));
        dispatch_semaphore_signal(done);
    });
    BOOL completed = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC)) == 0;
    xpc_connection_cancel(connection);
    return completed && accepted && FCRecordRemovalHandoff();
}

static NSString *FCBase(void) { return FCInstalledBundle.stringByDeletingLastPathComponent; }
static NSString *FCLock(void) { return [FCBase() stringByAppendingPathComponent:@".installer-lock"]; }
static NSString *FCIncoming(void) { return [FCBase() stringByAppendingPathComponent:@".incoming"]; }
static NSString *FCRetiredBundle(void) { return [FCBase() stringByAppendingPathComponent:@".retired.app"]; }
static NSString *FCIncomingBundle(void) { return [FCIncoming() stringByAppendingPathComponent:@"Flash.app"]; }

static BOOL FCSync(NSString *path) {
    int file = open(path.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (file < 0) return NO;
    BOOL synced = fsync(file) == 0;
    close(file);
    return synced;
}

static NSString *FCSeal(NSString *bundle) {
    if (FCAbsent(bundle)) return @"absent";
    if (![FCPayloadTrust(bundle) isEqual:@"trusted"]) return nil;
    NSString *executable = FCSHA256([bundle stringByAppendingPathComponent:@"Contents/MacOS/Flash"]);
    NSString *resources = FCSHA256([bundle stringByAppendingPathComponent:@"Contents/_CodeSignature/CodeResources"]);
    return executable.length == 64 && resources.length == 64 ? [executable stringByAppendingString:resources] : nil;
}

static NSDictionary *FCTransaction(void) {
    if (!FCProtectedTree(FCLock(), YES)) return nil;
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:[FCLock() stringByAppendingPathComponent:@"state.plist"]];
    NSString *phase = state[@"phase"];
    if (state.count != 3 || ![phase isKindOfClass:NSString.class] ||
        (![@[@"staging", @"prepared", @"committed"] containsObject:phase] && FCRemovalPhaseFromName(phase.UTF8String) == FCRemovalNone)) return nil;
    NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:FCLock() error:nil];
    if (entries.count != 1 || ![entries.firstObject isEqual:@"state.plist"]) return nil;
    for (NSString *key in @[@"old", @"new"]) {
        NSString *seal = state[key];
        if (![seal isKindOfClass:NSString.class] ||
            (![@[@"", @"absent"] containsObject:seal] && (seal.length != 128 ||
             [seal rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location != NSNotFound))) return nil;
    }
    if (FCRemovalPhaseFromName(phase.UTF8String) != FCRemovalNone &&
        ([state[@"old"] length] != 128 || ![state[@"new"] isEqual:@""])) return nil;
    return state;
}

static BOOL FCWriteTransaction(NSString *phase, NSString *old, NSString *new) {
    NSString *file = [FCLock() stringByAppendingPathComponent:@"state.plist"];
    if (!FCAbsent(file) && !FCProtectedTree(file, NO)) return NO;
    return [@{@"phase": phase, @"old": old, @"new": new} writeToFile:file atomically:YES] &&
        chmod(file.fileSystemRepresentation, 0600) == 0 && FCSync(file) && FCSync(FCLock()) && FCSync(FCBase());
}

static BOOL FCRemovableTree(NSString *root) {
    if (![root isEqual:FCIncoming()] && ![root isEqual:FCRetiredBundle()]) return NO;
    struct stat node;
    if (!FCProtectedTree(root, NO) || lstat(root.fileSystemRepresentation, &node) || !S_ISDIR(node.st_mode)) return NO;
    __block BOOL readable = YES;
    NSDirectoryEnumerator *items = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:root]
        includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url, NSError *error) { readable = NO; return NO; }];
    if (!items) return NO;
    for (NSURL *item in items) {
        NSString *path = item.path;
        if (lstat(path.fileSystemRepresentation, &node) || node.st_uid != 0) return NO;
        if (S_ISLNK(node.st_mode)) {
            if (!FCPathACLEmpty(path.fileSystemRepresentation, &node)) return NO;
        } else if (!FCProtectedTree(path, NO)) return NO;
    }
    return readable;
}

static BOOL FCRemoveFixedTree(NSString *root) {
    if (![root isEqual:FCIncoming()] && ![root isEqual:FCRetiredBundle()]) return NO;
    return FCAbsent(root) || (FCRemovableTree(root) &&
        [NSFileManager.defaultManager removeItemAtPath:root error:nil] && FCSync(FCBase()));
}

static BOOL FCRemoveIncoming(void) { return FCRemoveFixedTree(FCIncoming()); }

static BOOL FCRemovalQuiescent(void) {
    BOOL serviceAbsent = FCMachAbsent();
    BOOL childAbsent = FCAbsent([FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"]);
    if (FCAbsent(FCRuntimeDirectory)) return FCRemovalQuiescenceAllowed(serviceAbsent, childAbsent, YES, NO);
    if (!FCProtectedTree(FCRuntimeDirectory, YES)) return NO;
    NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:FCRuntimeDirectory error:nil];
    BOOL freezeOnly = entries && (entries.count == 0 || (entries.count == 1 && [entries.firstObject isEqual:@"maintenance"]));
    return FCRemovalQuiescenceAllowed(serviceAbsent, childAbsent, NO, freezeOnly);
}

static FCRemovalArtifact FCRemovalArtifactAt(NSString *bundle, NSString *old, BOOL partialAllowed) {
    if (FCAbsent(bundle)) return FCRemovalAbsent;
    if ([FCSeal(bundle) isEqual:old]) return FCRemovalMatching;
    return partialAllowed && FCRemovableTree(bundle) ? FCRemovalProtectedPartial : FCRemovalUntrusted;
}

static FCRemovalAction FCRemovalState(NSDictionary *state) {
    FCRemovalPhase phase = FCRemovalPhaseFromName([state[@"phase"] UTF8String]);
    if (phase == FCRemovalNone) return FCRemovalReject;
    return FCClassifyRemoval((FCRemovalSnapshot){phase,
        FCRemovalArtifactAt(FCInstalledBundle, state[@"old"], NO),
        FCRemovalArtifactAt(FCRetiredBundle(), state[@"old"], phase == FCRemovalCleaning),
        FCAbsent(FCLegacyPlist) ? FCRemovalAbsent : FCLegacyPlistTrusted() ? FCRemovalMatching : FCRemovalUntrusted,
        FCRemovalQuiescent()});
}

static BOOL FCRecordRemovalHandoff(void) {
    NSDictionary *state = FCTransaction();
    if (FCRemovalPhaseFromName([state[@"phase"] UTF8String]) == FCRemovalNone) return YES;
    FCRemovalAction action = FCRemovalState(state);
    return (action == FCRemovalHandoff || action == FCRemovalRetire) &&
        FCWriteTransaction(@"remove-stopped", state[@"old"], @"");
}

static BOOL FCFinishRemoval(void) {
    NSDictionary *state = FCTransaction();
    FCRemovalAction action = FCRemovalState(state);
    if (action == FCRemovalRetire) {
        if (!FCWriteTransaction(@"remove-ready", state[@"old"], @"") ||
            renamex_np(FCInstalledBundle.fileSystemRepresentation, FCRetiredBundle().fileSystemRepresentation, RENAME_EXCL) ||
            !FCSync(FCBase())) return NO;
        action = FCRemovalRecordRetired;
    }
    if (action == FCRemovalRecordRetired) {
        if (!FCWriteTransaction(@"remove-retired", state[@"old"], @"")) return NO;
        action = FCRemovalClean;
    }
    if (action == FCRemovalClean) {
        if (!FCWriteTransaction(@"remove-cleaning", state[@"old"], @"") || !FCRemovalQuiescent()) return NO;
        if (!FCAbsent(FCLegacyPlist) && (!FCLegacyPlistTrusted() || unlink(FCLegacyPlist.fileSystemRepresentation))) return NO;
        if (!FCSync(FCLegacyPlist.stringByDeletingLastPathComponent) || !FCRemoveFixedTree(FCRetiredBundle()) ||
            !FCWriteTransaction(@"remove-cleaned", state[@"old"], @"")) return NO;
        action = FCRemovalFinish;
    }
    if (action != FCRemovalFinish || FCRemovalState(FCTransaction()) != FCRemovalFinish) return NO;
    if (!FCAbsent(FCRuntimeDirectory)) {
        NSString *marker = [FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"];
        if (!FCAbsent(marker) && unlink(marker.fileSystemRepresentation)) return NO;
        if (rmdir(FCRuntimeDirectory.fileSystemRepresentation)) return NO;
    }
    if (!FCSync(FCRuntimeDirectory.stringByDeletingLastPathComponent)) return NO;
    NSString *file = [FCLock() stringByAppendingPathComponent:@"state.plist"];
    return unlink(file.fileSystemRepresentation) == 0 && rmdir(FCLock().fileSystemRepresentation) == 0 && FCSync(FCBase());
}

static int FCBeginRemoval(void) {
    NSDictionary *state = FCTransaction();
    if (state) {
        FCRemovalAction action = FCRemovalState(state);
        if (action == FCRemovalHandoff) return 0;
        return action != FCRemovalReject ? 20 : 78;
    }
    BOOL emptyLock = NO;
    if (!FCAbsent(FCLock())) {
        NSArray *entries = FCProtectedTree(FCLock(), YES) ? [NSFileManager.defaultManager contentsOfDirectoryAtPath:FCLock() error:nil] : nil;
        if (!entries || entries.count) return 78;
        emptyLock = YES;
    }
    if (!FCAbsent(FCRetiredBundle())) return 78;
    if (FCFirstInstallAllowed(FCAbsent(FCInstalledBundle), FCAbsent(FCLegacyPlist), FCAbsent(FCRuntimeDirectory), FCMachAbsent())) {
        if (emptyLock && (rmdir(FCLock().fileSystemRepresentation) || !FCSync(FCBase()))) return 78;
        return 10;
    }
    NSString *current = FCSeal(FCInstalledBundle);
    if (current.length != 128 || !FCLegacyPlistTrusted()) return 78;
    if (!emptyLock && mkdir(FCLock().fileSystemRepresentation, 0700)) return 78;
    return FCWriteTransaction(@"remove-pending", current, @"") ? 0 : 78;
}

static BOOL FCBegin(BOOL repair) {
    NSDictionary *removal = repair ? FCTransaction() : nil;
    if (FCRemovalPhaseFromName([removal[@"phase"] UTF8String]) != FCRemovalNone) {
        FCRemovalAction action = FCRemovalState(removal);
        if (action == FCRemovalReject) return NO;
        if (FCAbsent(FCInstalledBundle) && !FCFinishRemoval()) return NO;
    }
    if (!FCAbsent(FCRetiredBundle())) return NO;
    NSString *current = FCSeal(FCInstalledBundle);
    if (!current) return NO;
    if (FCAbsent(FCLock())) {
        BOOL absent = [current isEqual:@"absent"];
        if (absent ? !FCFirstInstallAllowed(YES, FCAbsent(FCLegacyPlist), FCAbsent(FCRuntimeDirectory), FCMachAbsent()) : !FCLegacyPlistTrusted()) return NO;
        if (mkdir(FCBase().fileSystemRepresentation, 0755) && errno != EEXIST) return NO;
        if (mkdir(FCLock().fileSystemRepresentation, 0700)) return NO;
    } else {
        NSDictionary *state = repair ? FCTransaction() : nil;
        NSArray *entries = repair && FCProtectedTree(FCLock(), YES) ?
            [NSFileManager.defaultManager contentsOfDirectoryAtPath:FCLock() error:nil] : nil;
        BOOL emptyInterruptedLock = FCEmptyLockRecoveryAllowed(repair, entries && entries.count == 0,
            [current isEqual:@"absent"], current != nil, FCLegacyPlistTrusted(),
            FCFirstInstallAllowed(YES, FCAbsent(FCLegacyPlist), FCAbsent(FCRuntimeDirectory), FCMachAbsent()));
        if (!emptyInterruptedLock && !FCTransactionResumeAllowed(state != nil, [current isEqual:state[@"old"]], [current isEqual:state[@"new"]])) return NO;
        if (!FCAbsent(FCLegacyPlist) && !FCLegacyPlistTrusted()) return NO;
        if (!emptyInterruptedLock && FCAbsent(FCLegacyPlist) && ![state[@"old"] isEqual:@"absent"]) return NO;
    }
    if (!FCRemoveIncoming()) return NO;
    return FCWriteTransaction(@"staging", current, @"");
}

static BOOL FCStageReady(void) {
    NSDictionary *state = FCTransaction();
    NSString *current = FCSeal(FCInstalledBundle);
    NSString *incoming = FCSeal(FCIncomingBundle());
    return state && [state[@"phase"] isEqual:@"staging"] && [current isEqual:state[@"old"]] &&
        incoming && ![incoming isEqual:@"absent"] && (FCAbsent(FCLegacyPlist) || FCLegacyPlistTrusted()) &&
        FCWriteTransaction(@"prepared", current, incoming);
}

static BOOL FCQuiescent(void) {
    return FCAbsent([FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"]) &&
        FCProtectedTree([FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"], NO) &&
        FCProtectedTree(FCRuntimeDirectory, YES) && FCMachAbsent();
}

static BOOL FCCommit(void) {
    NSDictionary *state = FCTransaction();
    if (!state || !FCTransactionCommitAllowed([state[@"phase"] isEqual:@"prepared"], FCQuiescent(),
        [FCSeal(FCInstalledBundle) isEqual:state[@"old"]], [FCSeal(FCIncomingBundle()) isEqual:state[@"new"]])) return NO;
    BOOL first = [state[@"old"] isEqual:@"absent"];
    int result = first ? rename(FCIncomingBundle().fileSystemRepresentation, FCInstalledBundle.fileSystemRepresentation) :
        renamex_np(FCIncomingBundle().fileSystemRepresentation, FCInstalledBundle.fileSystemRepresentation, RENAME_SWAP);
    if (result || !FCSync(FCBase()) || !FCSync(FCIncoming())) return NO;
    NSDictionary *plist = @{@"Label": FCHelperLabel, @"Program": FCInstalledExecutable(FCHelperLabel),
        @"MachServices": @{FCHelperLabel: @YES}, @"ProcessType": @"Interactive"};
    if (!FCAbsent(FCLegacyPlist) && !FCLegacyPlistTrusted()) return NO;
    if (![plist writeToFile:FCLegacyPlist atomically:YES] || chmod(FCLegacyPlist.fileSystemRepresentation, 0644) ||
        !FCSync(FCLegacyPlist) || !FCSync(FCLegacyPlist.stringByDeletingLastPathComponent)) return NO;
    return [FCSeal(FCInstalledBundle) isEqual:state[@"new"]] && FCLegacyPlistTrusted() &&
        FCWriteTransaction(@"committed", state[@"old"], state[@"new"]);
}

static BOOL FCFinish(void) {
    NSDictionary *state = FCTransaction();
    if (!state || ![state[@"phase"] isEqual:@"committed"] || ![FCSeal(FCInstalledBundle) isEqual:state[@"new"]] ||
        !FCLegacyPlistTrusted() || !FCRemoveIncoming()) return NO;
    NSString *file = [FCLock() stringByAppendingPathComponent:@"state.plist"];
    return unlink(file.fileSystemRepresentation) == 0 && rmdir(FCLock().fileSystemRepresentation) == 0 && FCSync(FCBase());
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (geteuid() != 0) return FCResult(NO, "root-required");
        if (argc != 2) return FCResult(NO, "one-action-required");
        if (!FCSigningRequirement(FCMaintenanceIdentifier)) return FCResult(NO, "signing-policy-unavailable");
        if (!FCLegacyRuntimeAbsent()) return FCResult(NO,
            "legacy-runtime-recovery-required: legacy runtime exists or absence cannot be proven; preserve journals and recover before retry");
        if (!FCParentsSafe()) return 78;
        NSString *action = @(argv[1]);
        if ([action isEqual:@"beginRemove"]) {
            int result = FCBeginRemoval();
            if (result == 78) FCPreflightFailure("begin-remove-state-rejected");
            return result;
        }
        if ([action isEqual:@"finishRemove"]) return FCResult(FCFinishRemoval(), "finish-remove-state-rejected");
        if ([action isEqual:@"beginInstall"]) return FCResult(FCBegin(NO), "begin-install-state-rejected");
        if ([action isEqual:@"beginRepair"]) return FCResult(FCBegin(YES), "begin-repair-state-rejected");
        if ([action isEqual:@"stageReady"]) return FCResult(FCStageReady(), "stage-state-rejected");
        if ([action isEqual:@"commitInstall"]) return FCResult(FCCommit(), "commit-state-rejected");
        if ([action isEqual:@"finishInstall"]) return FCResult(FCFinish(), "finish-install-state-rejected");
        if ([action isEqual:@"preflight"]) {
            if (FCFirstInstallAllowed(FCAbsent(FCInstalledBundle), FCAbsent(FCLegacyPlist), FCAbsent(FCRuntimeDirectory), FCMachAbsent())) return 10;
            if (![FCBundleTrust(FCInstalledBundle) isEqual:@"trusted"]) return FCResult(NO, "installed-bundle-untrusted");
            return FCResult(FCLegacyPlistTrusted(), "launch-daemon-untrusted");
        }
        if ([action isEqual:@"arm"]) {
            if (mkdir(FCRuntimeDirectory.fileSystemRepresentation, 0700) && errno != EEXIST)
                return FCResult(NO, "runtime-root-create-failed");
            if (!FCPrivateRuntimeNode(FCRuntimeDirectory, YES)) return FCResult(NO, "runtime-root-unsafe");
            NSString *marker = [FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"];
            if (!FCAbsent(marker)) return FCResult(FCPrivateRuntimeNode(marker, NO), "maintenance-marker-unsafe");
            int file = open(marker.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
            if (file < 0) return FCResult(NO, "maintenance-marker-create-failed");
            BOOL durable = fsync(file) == 0 && FCSync(FCRuntimeDirectory) &&
                FCSync(FCRuntimeDirectory.stringByDeletingLastPathComponent);
            close(file);
            return FCResult(durable, "runtime-sync-failed");
        }
        if ([action isEqual:@"disarm"]) {
            NSString *marker = [FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"];
            return FCResult(FCAbsent(marker) || (FCPrivateRuntimeNode(marker, NO) &&
                unlink(marker.fileSystemRepresentation) == 0), "maintenance-marker-remove-failed");
        }
        if ([action isEqual:@"serviceAbsent"]) return FCResult(FCMachAbsent(), "service-not-proven-absent");
        if ([action isEqual:@"verify"]) return FCResult([FCBundleTrust(FCInstalledBundle) isEqual:@"trusted"] &&
            FCLegacyPlistTrusted(), "installed-state-untrusted");
        if ([action isEqual:@"quiescent"]) return FCResult(FCQuiescent(), "runtime-not-quiescent");
        if ([action isEqual:@"prepare"]) return FCResult(FCPrepare(), "maintenance-handoff-rejected");
        return 64;
    }
}
