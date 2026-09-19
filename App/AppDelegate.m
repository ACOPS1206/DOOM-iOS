#import "AppDelegate.h"
#import "DoomViewController.h"

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [DoomViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

