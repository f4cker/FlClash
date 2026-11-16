#import "LegacyResidue.h"
#import <errno.h>
#import <sys/stat.h>
#import <servers/bootstrap.h>
#import <mach/mach.h>

NSString * const FCLegacyLabel = @"com.layoute.flash.helper";
NSString * const FCLegacyPlist = @"/Library/LaunchDaemons/com.layoute.flash.helper.plist";
NSString * const FCLegacyServiceDirectory = @"/Library/Application Support/Flash";
NSString * const FCLegacyRuntimeDirectory = @"/private/var/run/com.layoute.flash.helper";
NSString * const FCLegacyPendingDefault = @"FlashHelperInstallerPending";

NSArray<NSString *> *FCLegacyReceiptPaths(void) {
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *operation in @[@"install", @"repair", @"remove", @"disable"])
        for (NSString *suffix in @[@"plist", @"bom"])
            [paths addObject:[NSString stringWithFormat:@"/var/db/receipts/com.layoute.flash.managed.%@.%@", operation, suffix]];
    return paths;
}

BOOL FCPathPresent(const char *path) {
    struct stat state;
    return lstat(path, &state) == 0 || errno != ENOENT;
}

BOOL FCMachServiceRegistered(const char *name) {
    mach_port_t port = MACH_PORT_NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    kern_return_t result = bootstrap_look_up(bootstrap_port, name, &port);
#pragma clang diagnostic pop
    if (port != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), port);
    return result == KERN_SUCCESS;
}

FCLegacyResidue FCDetectLegacyResidueWith(FCPathProbe present, FCJobProbe loaded) {
    FCLegacyResidue residue = FCLegacyResidueNone;
    if (present(FCLegacyPlist.fileSystemRepresentation)) residue |= FCLegacyResiduePlist;
    if (present(FCLegacyServiceDirectory.fileSystemRepresentation)) residue |= FCLegacyResidueBundle;
    if (loaded(FCLegacyLabel.UTF8String)) residue |= FCLegacyResidueJob;
    for (NSString *receipt in FCLegacyReceiptPaths())
        if (present(receipt.fileSystemRepresentation)) { residue |= FCLegacyResidueReceipts; break; }
    if (present(FCLegacyRuntimeDirectory.fileSystemRepresentation)) residue |= FCLegacyResidueRuntime;
    return residue;
}

FCLegacyResidue FCDetectLegacyResidue(void) {
    return FCDetectLegacyResidueWith(FCPathPresent, FCMachServiceRegistered);
}

NSArray<NSString *> *FCLegacyResidueNames(FCLegacyResidue residue) {
    NSMutableArray *names = [NSMutableArray array];
    if (residue & FCLegacyResiduePlist) [names addObject:@"plist"];
    if (residue & FCLegacyResidueBundle) [names addObject:@"service"];
    if (residue & FCLegacyResidueJob) [names addObject:@"job"];
    if (residue & FCLegacyResidueReceipts) [names addObject:@"receipts"];
    if (residue & FCLegacyResidueRuntime) [names addObject:@"runtime"];
    return names;
}

// Idempotent and robust to partial states: every step tolerates "already gone", nothing aborts early.
// bootout sends SIGTERM; the legacy supervisor stops Core (TUN/routes torn down by Core) before exiting.
// Only fixed root-owned paths are removed (rm does not follow a symlink operand).
// Output (stdout, one key=value per line) reports each step so the UI can name the step that failed:
//   stop=ok|fail  remove=ok|fail  receipts=ok|fail  detail=<last raw error output, single line>
NSString *FCLegacyCleanupScript(void) {
    return
        @"set -u; PATH=/usr/bin:/bin:/usr/sbin:/sbin; export PATH; LC_ALL=C; export LC_ALL; umask 077; "
         "label=com.layoute.flash.helper; plist=/Library/LaunchDaemons/com.layoute.flash.helper.plist; "
         "old='/Library/Application Support/Flash'; run=/private/var/run/com.layoute.flash.helper; "
         "detail=''; note() { [ -n \"$1\" ] && detail=$(printf '%s' \"$1\" | tr '\\n\\r' '  ' | cut -c1-400); }; "
         "note \"$(launchctl bootout system/$label 2>&1)\"; "
         "i=0; while launchctl print system/$label >/dev/null 2>&1 && [ $i -lt 20 ]; do sleep 0.5; i=$((i+1)); done; "
         "if launchctl print system/$label >/dev/null 2>&1; then "
         "note \"$(launchctl bootout system \"$plist\" 2>&1)\"; note \"$(launchctl remove $label 2>&1)\"; sleep 1; fi; "
         "if pkill -TERM -f '^/Library/Application Support/Flash/Flash[.]app/Contents/' >/dev/null 2>&1; then sleep 2; fi; "
         "pkill -KILL -f '^/Library/Application Support/Flash/Flash[.]app/Contents/' >/dev/null 2>&1; "
         "stop=ok; if launchctl print system/$label >/dev/null 2>&1 || "
         "pgrep -f '^/Library/Application Support/Flash/Flash[.]app/Contents/' >/dev/null 2>&1; then stop=fail; fi; "
         "note \"$(rm -f \"$plist\" 2>&1)\"; note \"$(rm -rf \"$old\" \"$run\" 2>&1)\"; "
         "remove=ok; for f in \"$plist\" \"$old\" \"$run\"; do if [ -e \"$f\" ] || [ -L \"$f\" ]; then remove=fail; fi; done; "
         "for op in install repair remove disable; do pkgutil --forget com.layoute.flash.managed.$op >/dev/null 2>&1; done; "
         "note \"$(rm -f /var/db/receipts/com.layoute.flash.managed.*.plist /var/db/receipts/com.layoute.flash.managed.*.bom 2>&1)\"; "
         "receipts=ok; for f in /var/db/receipts/com.layoute.flash.managed.*; do [ -e \"$f\" ] && receipts=fail; done; "
         "printf 'stop=%s\\nremove=%s\\nreceipts=%s\\ndetail=%s\\n' \"$stop\" \"$remove\" \"$receipts\" \"$detail\"; "
         "exit 0";
}

NSDictionary<NSString *, NSString *> *FCParseCleanupReport(NSString *output) {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    NSString *normalized = [output stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    for (NSString *line in [normalized componentsSeparatedByString:@"\n"]) {
        NSRange equals = [line rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [line substringToIndex:equals.location];
        if ([@[@"stop", @"remove", @"receipts", @"detail"] containsObject:key] && !report[key])
            report[key] = [line substringFromIndex:equals.location + 1];
    }
    return report;
}

// Which step the UI should name. Residue that remains is attributed to the step that owns it.
NSString *FCMigrationFailedStep(NSDictionary<NSString *, NSString *> *report, FCLegacyResidue remaining) {
    if ([report[@"stop"] isEqualToString:@"fail"] || (remaining & (FCLegacyResidueJob))) return @"stopOld";
    if ([report[@"remove"] isEqualToString:@"fail"] || [report[@"receipts"] isEqualToString:@"fail"] ||
        (remaining & (FCLegacyResiduePlist | FCLegacyResidueBundle | FCLegacyResidueReceipts | FCLegacyResidueRuntime)))
        return @"removeOld";
    return @"unknown";
}
