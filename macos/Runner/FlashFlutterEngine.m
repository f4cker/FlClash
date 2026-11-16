#import "FlashFlutterEngine.h"

@interface FlashFlutterEngine ()
- (void)loadAOTData:(NSString *)assetsDir;
@end

@implementation FlashFlutterEngine

// Flutter 3.50.0 private selector (unchanged from 3.47.4): recheck dispatch and null-AOT App.framework fallback on SDK upgrades; never call super's ELF loader.
- (void)loadAOTData:(NSString *)assetsDir {
    (void)assetsDir;
}

@end
