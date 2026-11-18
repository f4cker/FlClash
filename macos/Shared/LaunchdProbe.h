// Read-only view of launchd's record of the daemon, from `launchctl print system/<label>` (no root needed).
// Used only to decide whether the registration has gone stale after an app update (launchd keeps the old
// launch constraint and cannot spawn the new helper); it never grants trust: hello, the pinned requirement and
// peer authentication still decide whether the helper is used.
#import <Foundation/Foundation.h>
#import "HelperTrust.h"

// Whether a last exit code is the helper refusing to run (FC_HELPER_REFUSED_EXIT) or FlashHelperLauncher stopping
// before exec (81–87): launchd started the job, so this is not a registration problem; the launcher status says why.
static inline BOOL FCRefusalExit(NSInteger code) {
    return code == FC_HELPER_REFUSED_EXIT || (code >= FC_LAUNCHER_EXIT_FIRST && code <= FC_LAUNCHER_EXIT_LAST);
}

// state: "missing" (no such job), "running" (has a pid), "idle" (loaded, not running, nothing wrong seen),
// "broken" (no pid and launchd itself says it cannot start the job: needs LWCR update, or spawn failed without a
// refusal exit code) or "unknown" (could not read/parse). Only "broken" means the registration is stale; any last
// exit code alone (78 included) does not.
// refused: no pid and the last exit code is a refusal (FCRefusalExit).
// versionStale: the job's parent bundle version differs from `currentVersion`. Detail only: after every app update
// launchd keeps the version it registered with until the next login, so it never means the registration is stale.
static inline NSDictionary *FCParseLaunchdPrint(NSString *output, int exitStatus, NSString *currentVersion) {
    NSString *text = output ?: @"";
    if ([text containsString:@"Could not find service"] || [text containsString:@"Could not find job"])
        return @{@"state": @"missing", @"summary": @"job not found"};
    NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];
    NSString *first = lines.firstObject ?: @"";
    if (exitStatus != 0 || ![first hasSuffix:@"= {"])
        return @{@"state": @"unknown", @"summary": [NSString stringWithFormat:@"unreadable (exit %d)", exitStatus]};
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary dictionary];
    NSInteger depth = 0;
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (depth == 1) {
            NSRange separator = [trimmed rangeOfString:@" = "];
            if (separator.location != NSNotFound && ![trimmed hasSuffix:@"{"]) {
                NSString *key = [trimmed substringToIndex:separator.location];
                if (!fields[key]) fields[key] = [trimmed substringFromIndex:NSMaxRange(separator)];
            }
        }
        if ([trimmed hasSuffix:@"{"]) depth++;
        if ([trimmed isEqualToString:@"}"]) depth--;
    }
    if (depth != 0 || !fields.count) return @{@"state": @"unknown", @"summary": @"unparsable"};
    NSString *jobState = fields[@"state"] ?: @"";
    NSString *pidText = fields[@"pid"];
    NSInteger pid = pidText.integerValue;
    NSString *exitText = fields[@"last exit code"] ?: @"";
    NSInteger lastExit = exitText.length ? exitText.integerValue : -1;
    NSString *properties = fields[@"properties"] ?: @"";
    NSString *parentVersion = fields[@"parent bundle version"] ?: @"";
    BOOL spawnFailed = [jobState isEqualToString:@"spawn failed"];
    BOOL needsLWCR = [properties containsString:@"needs LWCR update"];
    BOOL versionStale = parentVersion.length && currentVersion.length && ![parentVersion isEqualToString:currentVersion];
    BOOL refused = pid <= 0 && FCRefusalExit(lastExit);
    NSString *state = pid > 0 ? @"running" : (needsLWCR || (spawnFailed && !refused)) ? @"broken" : @"idle";
    NSString *summary = [NSString stringWithFormat:@"state=%@ pid=%@ lastExit=%@ needsLWCR=%@ parentVersion=%@ current=%@",
        jobState.length ? jobState : @"?", pid > 0 ? @(pid) : @"none", exitText.length ? exitText : @"none",
        needsLWCR ? @"yes" : @"no", parentVersion.length ? parentVersion : @"?", currentVersion ?: @"?"];
    return @{@"state": state, @"pid": @(pid > 0 ? pid : 0), @"spawnFailed": @(spawnFailed), @"lastExit": @(lastExit),
        @"needsLWCR": @(needsLWCR), @"refused": @(refused), @"parentVersion": parentVersion, @"versionStale": @(versionStale),
        @"summary": summary};
}

// Runs `/bin/launchctl print system/<label>` with a hard deadline; any failure is "unknown".
static inline NSDictionary *FCLaunchdSnapshot(NSString *label, NSString *currentVersion, NSTimeInterval timeout) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    task.arguments = @[@"print", [@"system/" stringByAppendingString:label]];
    task.standardInput = [NSFileHandle fileHandleWithNullDevice];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    NSError *error = nil;
    if (![task launchAndReturnError:&error])
        return @{@"state": @"unknown", @"summary": [NSString stringWithFormat:@"launchctl not run: %@", error.localizedDescription ?: @"?"]};
    __block NSData *data = nil;
    dispatch_semaphore_t read = dispatch_semaphore_create(0);
    NSFileHandle *handle = pipe.fileHandleForReading;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        data = [handle readDataToEndOfFile];
        dispatch_semaphore_signal(read);
    });
    if (dispatch_semaphore_wait(read, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)))) {
        [task terminate];
        return @{@"state": @"unknown", @"summary": @"launchctl timed out"};
    }
    [task waitUntilExit];
    NSString *output = data.length <= 256 * 1024 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    return FCParseLaunchdPrint(output, task.terminationStatus, currentVersion);
}
