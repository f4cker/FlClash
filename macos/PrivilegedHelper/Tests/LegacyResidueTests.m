#import "../../Shared/LegacyResidue.h"
#import <assert.h>

static NSSet<NSString *> *present;
static BOOL jobLoaded;
static NSMutableArray<NSString *> *probed;
static BOOL FixturePresent(const char *path) { [probed addObject:@(path)]; return [present containsObject:@(path)]; }
static BOOL FixtureLoaded(const char *name) { assert(!strcmp(name, "com.layoute.flash.helper")); return jobLoaded; }

static FCLegacyResidue Detect(NSArray<NSString *> *paths, BOOL loaded) {
    present = [NSSet setWithArray:paths];
    jobLoaded = loaded;
    probed = [NSMutableArray array];
    return FCDetectLegacyResidueWith(FixturePresent, FixtureLoaded);
}

int main(void) {
    @autoreleasepool {
        assert(Detect(@[], NO) == FCLegacyResidueNone);
        assert(Detect(@[@"/Library/LaunchDaemons/com.layoute.flash.helper.plist"], NO) == FCLegacyResiduePlist);
        assert(Detect(@[@"/Library/Application Support/Flash"], NO) == FCLegacyResidueBundle);
        // A stale job still bootstrapped with no plist on disk is residue on its own.
        assert(Detect(@[], YES) == FCLegacyResidueJob);
        assert(Detect(@[@"/var/db/receipts/com.layoute.flash.managed.disable.bom"], NO) == FCLegacyResidueReceipts);
        assert(Detect(@[@"/private/var/run/com.layoute.flash.helper"], NO) == FCLegacyResidueRuntime);
        FCLegacyResidue all = Detect(@[@"/Library/LaunchDaemons/com.layoute.flash.helper.plist",
            @"/Library/Application Support/Flash", @"/var/db/receipts/com.layoute.flash.managed.install.plist",
            @"/private/var/run/com.layoute.flash.helper"], YES);
        assert(all == (FCLegacyResiduePlist | FCLegacyResidueBundle | FCLegacyResidueJob |
            FCLegacyResidueReceipts | FCLegacyResidueRuntime));
        assert(([FCLegacyResidueNames(all) isEqual:@[@"plist", @"service", @"job", @"receipts", @"runtime"]]));
        // New-design locations are never mistaken for residue.
        assert(Detect(@[@"/Applications/Flash.app", @"/Library/Application Support/com.layoute.flash.daemon"], NO) == 0);
        for (NSString *path in probed) assert(![path containsString:@"com.layoute.flash.daemon"]);
        // Real probe: unreadable/odd errors count as present; ENOENT as absent.
        assert(!FCPathPresent("/nonexistent-flash-residue-probe"));
        assert(FCPathPresent("/"));
        assert(!FCMachServiceRegistered("com.layoute.flash.nonexistent-probe"));

        NSDictionary *report = FCParseCleanupReport(@"stop=ok\rremove=fail\rreceipts=ok\rdetail=rm: Operation not permitted\r");
        assert([report[@"stop"] isEqual:@"ok"] && [report[@"remove"] isEqual:@"fail"]);
        assert([report[@"detail"] isEqual:@"rm: Operation not permitted"]);
        assert([FCMigrationFailedStep(report, FCLegacyResiduePlist) isEqual:@"removeOld"]);
        assert([FCMigrationFailedStep(@{@"stop": @"fail"}, FCLegacyResiduePlist) isEqual:@"stopOld"]);
        assert([FCMigrationFailedStep(@{}, FCLegacyResidueJob) isEqual:@"stopOld"]);
        assert([FCMigrationFailedStep(@{}, FCLegacyResidueReceipts) isEqual:@"removeOld"]);
        assert([FCMigrationFailedStep(@{}, FCLegacyResidueNone) isEqual:@"unknown"]);
        assert(FCParseCleanupReport(@"garbage").count == 0);
        assert([FCParseCleanupReport(@"detail=a=b\ndetail=second")[@"detail"] isEqual:@"a=b"]);

        NSString *script = FCLegacyCleanupScript();
        for (NSString *forbidden in @[@"%@", @"$HOME", @"/Applications", @"com.layoute.flash.daemon", @"com.layoute.flash.helperd", @"curl", @"eval"])
            assert(![script containsString:forbidden]);
        assert([script hasPrefix:@"set -u; PATH=/usr/bin:/bin:/usr/sbin:/sbin;"]);
        assert(![script containsString:@"set -e"]);
        puts("Legacy residue detection, step attribution and script constants passed; nothing removed");
    }
}
