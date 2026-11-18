// Administrator repair of FlashHelperLauncher's anti-downgrade record (PrivilegedHelper/Launcher/README.md) when the
// launcher reported it unreadable or unwritable. The launcher itself never changes; this rewrites only
// <state>/max-version, and only when it is not a valid record, to the version the launcher had just verified.
//
// Anti-downgrade is kept: a valid record is never touched (the script's validity test is the launcher's parser, byte
// for byte), so the repair cannot lower a known floor. The value written is the helperVersion of the launcher's own
// root-written status, cross-checked against the root-only helper copy, which must still pass the pinned code
// requirement and embed that same CFBundleVersion: exactly what the launcher writes on a first run of that copy.
#import <Foundation/Foundation.h>

// Fixed root script (a compile-time constant of the signed GUI; never interpolated). Every path is a constant under
// /Library/Application Support; directories and files must be root-owned, not symlinks, and not writable by group or
// other (the state directory not accessible by them at all). Output, one key=value per line:
//   record=repaired|kept|refused|failed  reason=<step>  version=<helper version from the launcher status>
static inline NSString *FCLauncherRecordRepairScript(void) {
    return
        @"set -u; PATH=/usr/bin:/bin:/usr/sbin:/sbin; export PATH; LC_ALL=C; export LC_ALL; umask 077; "
         "base='/Library/Application Support'; owner=0; "
         "requirement='anchor H\"BBA7F8529FD271B9848EC03A2CE3F4780F585556\" and certificate leaf = "
         "H\"BBA7F8529FD271B9848EC03A2CE3F4780F585556\" and identifier \"com.layoute.flash.helper\"'; "
         "state=\"$base/com.layoute.flash.helperd\"; record=\"$state/max-version\"; temp=\"$state/.max-version.repair\"; "
         "stale=\"$state/.max-version.tmp\"; copy=\"$state/FlashHelper\"; "
         "statusdir=\"$base/com.layoute.flash.helperd-status\"; statusfile=\"$statusdir/launcher.json\"; version=''; "
         "report() { printf 'record=%s\\nreason=%s\\nversion=%s\\n' \"$1\" \"$2\" \"$version\"; exit 0; }; "
         "safe() { [ ! -L \"$1\" ] && [ \"$2\" \"$1\" ] && [ \"$(stat -f %u \"$1\")\" = \"$owner\" ] && "
         "[ $(( 0$(stat -f %Lp \"$1\") & $3 )) -eq 0 ]; }; "
         "count() { tr -cd '0-9' | wc -c | tr -d ' '; }; "
         "valid() { [ ! -L \"$record\" ] && [ -f \"$record\" ] && [ \"$(stat -f %u \"$record\")\" = \"$owner\" ] || return 1; "
         "size=$(stat -f %z \"$record\"); [ \"$size\" -ge 1 ] && [ \"$size\" -le 21 ] || return 1; "
         "digits=$(count < \"$record\"); [ \"$digits\" -ge 1 ] && [ \"$digits\" -le 20 ] || return 1; "
         "[ \"$(head -c \"$digits\" \"$record\" | count)\" = \"$digits\" ] || return 1; "
         "if [ \"$size\" -ne \"$digits\" ]; then [ \"$size\" -eq $((digits + 1)) ] && "
         "[ \"$(tail -c 1 \"$record\" | od -An -tx1 | tr -d ' \\n')\" = 0a ] || return 1; fi; "
         "value=$(head -c \"$digits\" \"$record\"); [ \"$digits\" -lt 20 ] && return 0; "
         "[ \"$value\" = 18446744073709551615 ] || "
         "[ \"$(printf '%s\\n%s\\n' \"$value\" 18446744073709551615 | sort | head -n 1)\" = \"$value\" ]; }; "
         "safe \"$base\" -d 18 || report refused parent; "
         "safe \"$state\" -d 63 || report refused state; "
         "safe \"$statusdir\" -d 18 && safe \"$statusfile\" -f 18 || report refused status; "
         "[ \"$(wc -l < \"$statusfile\" | tr -d ' ')\" = 1 ] || report refused status; "
         "version=$(sed -n -E 's/^[{]\"v\":1,\"result\":\"version_unreadable\",\"detail\":\"max-version (unreadable|write) "
         "errno=[0-9]+\",\"helperVersion\":([0-9]{1,20}),\"recordedVersion\":(null|[0-9]{1,20}),\"launcherVersion\":1,"
         "\"time\":[0-9]+[}]$/\\2/p' \"$statusfile\"); "
         "[ -n \"$version\" ] || report refused status; "
         "safe \"$copy\" -f 18 || report refused copy; "
         "codesign --verify --strict --all-architectures -R \"=$requirement\" \"$copy\" >/dev/null 2>&1 || report refused signature; "
         "embedded=$(tr -d ' \\t\\r\\n' < \"$copy\" | grep -a -o '<key>CFBundleVersion</key><string>[^<]*</string>' | sort -u); "
         "[ \"$embedded\" = \"<key>CFBundleVersion</key><string>$version</string>\" ] || report refused version; "
         "if [ -d \"$stale\" ] && [ ! -L \"$stale\" ]; then rm -rf \"$stale\" || report failed temporary; fi; "
         "valid && report kept record; "
         "rm -rf \"$temp\" && printf '%s\\n' \"$version\" > \"$temp\" && chmod 600 \"$temp\" || report failed write; "
         "if [ -d \"$record\" ] && [ ! -L \"$record\" ]; then rm -rf \"$record\" || report failed write; fi; "
         "mv -f \"$temp\" \"$record\" || report failed write; sync; "
         "valid && [ \"$value\" = \"$version\" ] || report failed verify; "
         "report repaired record";
}

// Parses the script's key=value report (tolerates \r line endings from do shell script).
static inline NSDictionary<NSString *, NSString *> *FCParseRecordRepairReport(NSString *output) {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    NSString *normalized = [output stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    for (NSString *line in [normalized componentsSeparatedByString:@"\n"]) {
        NSRange equals = [line rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [line substringToIndex:equals.location];
        if ([@[@"record", @"reason", @"version"] containsObject:key] && !report[key])
            report[key] = [line substringFromIndex:equals.location + 1];
    }
    return report;
}

// What the app reports for one repair: `authorization` is the administrator prompt's outcome ("ok",
// "authorizationCancelled", "authorizationDenied", anything else a failure to run the script).
// Returns "ok" (record rewritten, or found valid), "cancelled", "denied" or "failed".
static inline NSString *FCRecordRepairOutcome(NSString *authorization, NSDictionary<NSString *, NSString *> *report) {
    if ([authorization isEqualToString:@"authorizationCancelled"]) return @"cancelled";
    if ([authorization isEqualToString:@"authorizationDenied"]) return @"denied";
    if (![authorization isEqualToString:@"ok"]) return @"failed";
    return [@[@"repaired", @"kept"] containsObject:report[@"record"] ?: @""] ? @"ok" : @"failed";
}
