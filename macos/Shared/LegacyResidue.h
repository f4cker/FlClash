#pragma once
#import <Foundation/Foundation.h>

// Residue of the legacy (<= 0.9.15) privileged helper: /Library/LaunchDaemons job + root service wrapper
// installed by com.layoute.flash.managed.* packages. Detection runs as the user, needs no read access
// (lstat only) and treats any lstat error other than ENOENT as "present" so unreadable leftovers are cleaned.
typedef NS_OPTIONS(NSUInteger, FCLegacyResidue) {
    FCLegacyResidueNone = 0,
    FCLegacyResiduePlist = 1 << 0,     // R1 /Library/LaunchDaemons/com.layoute.flash.helper.plist
    FCLegacyResidueBundle = 1 << 1,    // R2 /Library/Application Support/Flash
    FCLegacyResidueJob = 1 << 2,       // R3 com.layoute.flash.helper still bootstrapped (also with no plist)
    FCLegacyResidueReceipts = 1 << 3,  // R4 /var/db/receipts/com.layoute.flash.managed.*
    FCLegacyResidueRuntime = 1 << 4,   // R5 /private/var/run/com.layoute.flash.helper
};

extern NSString * const FCLegacyLabel;
extern NSString * const FCLegacyPlist;
extern NSString * const FCLegacyServiceDirectory;
extern NSString * const FCLegacyRuntimeDirectory;
extern NSString * const FCLegacyPendingDefault;   // R6, cleared without admin rights
NSArray<NSString *> *FCLegacyReceiptPaths(void);

typedef BOOL (*FCPathProbe)(const char *path);
typedef BOOL (*FCJobProbe)(const char *name);
BOOL FCPathPresent(const char *path);
BOOL FCMachServiceRegistered(const char *name);
FCLegacyResidue FCDetectLegacyResidueWith(FCPathProbe present, FCJobProbe loaded);
FCLegacyResidue FCDetectLegacyResidue(void);
NSArray<NSString *> *FCLegacyResidueNames(FCLegacyResidue residue);
// Fixed root cleanup script (a compile-time constant of the signed GUI; never interpolated).
NSString *FCLegacyCleanupScript(void);
// Parses the script's key=value report (tolerates \r line endings from do shell script).
NSDictionary<NSString *, NSString *> *FCParseCleanupReport(NSString *output);
// "stopOld" | "removeOld" | "unknown"; registration failures are reported by the caller as "registerNew".
NSString *FCMigrationFailedStep(NSDictionary<NSString *, NSString *> *report, FCLegacyResidue remaining);
