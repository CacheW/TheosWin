#import <UIKit/UIKit.h>
extern int vanta_swift_fib(int n);      // Swift @_cdecl
extern int vanta_swift_add(int a,int b); // Swift @_cdecl

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication*)a didFinishLaunchingWithOptions:(NSDictionary*)o {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1];

    int fib = vanta_swift_fib(20);      // <-- runs SWIFT on device
    int sum = vanta_swift_add(40, 2);

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20,140,320,120)];
    title.numberOfLines = 0; title.textColor = [UIColor colorWithRed:0.855 green:0.165 blue:0.255 alpha:1];
    title.font = [UIFont boldSystemFontOfSize:22];
    title.text = @"Swift on iOS\nbuilt on native Windows";

    UILabel *out = [[UILabel alloc] initWithFrame:CGRectMake(20,280,320,160)];
    out.numberOfLines = 0; out.textColor = UIColor.whiteColor; out.font = [UIFont systemFontOfSize:18];
    out.text = [NSString stringWithFormat:@"Swift @_cdecl results:\n\n  fib(20) = %d\n  add(40,2) = %d\n\nIf you see 6765 and 42,\nSwift ran on your device.", fib, sum];

    [vc.view addSubview:title]; [vc.view addSubview:out];
    self.window.rootViewController = vc; [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int c, char**v){ @autoreleasepool { return UIApplicationMain(c,v,nil,NSStringFromClass(AppDelegate.class)); } }
