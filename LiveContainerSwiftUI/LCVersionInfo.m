#import "LCVersionInfo.h"

@implementation LCVersionInfo
+ (NSString*)getVersionStr {
    return [NSString stringWithFormat:@"版本: %@-%s (%s/%s)",
        NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],
        CONFIG_TYPE, CONFIG_BRANCH, CONFIG_COMMIT];
}
@end
