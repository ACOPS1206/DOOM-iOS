#import "DoomViewController.h"
#import "DoomPlatform.h"
#include "doomkeys.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DoomViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIImageView *screen;
@property (nonatomic, strong) UIView *welcome;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) dispatch_queue_t engineQueue;
@property (nonatomic) BOOL tickPending;
@end

@implementation DoomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.engineQueue = dispatch_queue_create("com.acops.doom.engine", DISPATCH_QUEUE_SERIAL);
    [self buildScreen];
    [self buildControls];
    [self buildWelcome];

    __weak typeof(self) weakSelf = self;
    DoomPlatformSetFrameHandler(^(NSData *frame) { [weakSelf presentFrame:frame]; });

    NSString *wad = [self installedWAD];
    if (wad) [self launchWAD:wad];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (void)buildScreen {
    self.screen = [UIImageView new];
    self.screen.translatesAutoresizingMaskIntoConstraints = NO;
    self.screen.contentMode = UIViewContentModeScaleAspectFit;
    self.screen.layer.magnificationFilter = kCAFilterNearest;
    [self.view addSubview:self.screen];
    [NSLayoutConstraint activateConstraints:@[
        [self.screen.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.screen.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.screen.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.screen.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
}

- (UIButton *)button:(NSString *)title key:(unsigned char)key {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.72];
    button.tintColor = UIColor.whiteColor;
    button.layer.cornerRadius = 14;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    button.tag = key;
    [button addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(keyUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [NSLayoutConstraint activateConstraints:@[[button.widthAnchor constraintEqualToConstant:64], [button.heightAnchor constraintEqualToConstant:52]]];
    return button;
}

- (void)buildControls {
    UIStackView *directions = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self button:@"◀" key:KEY_LEFTARROW], [self button:@"▲" key:KEY_UPARROW],
        [self button:@"▼" key:KEY_DOWNARROW], [self button:@"▶" key:KEY_RIGHTARROW]
    ]];
    directions.axis = UILayoutConstraintAxisHorizontal;
    directions.spacing = 8;
    directions.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self button:@"USE" key:KEY_USE], [self button:@"FIRE" key:KEY_FIRE], [self button:@"MENU" key:KEY_ESCAPE]
    ]];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 8;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:directions];
    [self.view addSubview:actions];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [directions.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [directions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10]
    ]];
}

- (void)buildWelcome {
    self.welcome = [UIView new];
    self.welcome.translatesAutoresizingMaskIntoConstraints = NO;
    self.welcome.backgroundColor = UIColor.blackColor;
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"DOOM iOS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:38 weight:UIFontWeightBlack];
    UILabel *message = [UILabel new];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.text = @"게임 데이터는 포함되어 있지 않습니다.\n합법적으로 보유한 DOOM.WAD 또는 DOOM1.WAD를 선택하세요.";
    message.textColor = UIColor.lightGrayColor;
    message.numberOfLines = 0;
    message.textAlignment = NSTextAlignmentCenter;
    UIButton *import = [UIButton buttonWithType:UIButtonTypeSystem];
    import.translatesAutoresizingMaskIntoConstraints = NO;
    [import setTitle:@"WAD 가져오기" forState:UIControlStateNormal];
    import.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    import.backgroundColor = UIColor.whiteColor;
    import.tintColor = UIColor.blackColor;
    import.layer.cornerRadius = 14;
    [import addTarget:self action:@selector(importWAD) forControlEvents:UIControlEventTouchUpInside];
    [self.welcome addSubview:title]; [self.welcome addSubview:message]; [self.welcome addSubview:import];
    [self.view addSubview:self.welcome];
    [NSLayoutConstraint activateConstraints:@[
        [self.welcome.topAnchor constraintEqualToAnchor:self.view.topAnchor], [self.welcome.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.welcome.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [self.welcome.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [title.centerXAnchor constraintEqualToAnchor:self.welcome.centerXAnchor], [title.bottomAnchor constraintEqualToAnchor:message.topAnchor constant:-18],
        [message.centerXAnchor constraintEqualToAnchor:self.welcome.centerXAnchor], [message.centerYAnchor constraintEqualToAnchor:self.welcome.centerYAnchor],
        [import.centerXAnchor constraintEqualToAnchor:self.welcome.centerXAnchor], [import.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:24],
        [import.widthAnchor constraintEqualToConstant:180], [import.heightAnchor constraintEqualToConstant:52]
    ]];
}

- (void)keyDown:(UIButton *)sender { DoomPlatformKey(YES, (unsigned char)sender.tag); }
- (void)keyUp:(UIButton *)sender { DoomPlatformKey(NO, (unsigned char)sender.tag); }

- (NSString *)installedWAD {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    for (NSString *name in @[@"DOOM.WAD", @"DOOM1.WAD"]) {
        NSString *path = [documents stringByAppendingPathComponent:name];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) return path;
    }
    return nil;
}

- (void)importWAD {
    UTType *wad = [UTType typeWithFilenameExtension:@"wad"] ?: UTTypeData;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[wad] asCopy:YES];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source) return;
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *name = [source.lastPathComponent.uppercaseString isEqualToString:@"DOOM1.WAD"] ? @"DOOM1.WAD" : @"DOOM.WAD";
    NSString *destination = [documents stringByAppendingPathComponent:name];
    [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
    NSError *error = nil;
    [NSFileManager.defaultManager copyItemAtPath:source.path toPath:destination error:&error];
    if (error) { [self showError:error.localizedDescription]; return; }
    [self launchWAD:destination];
}

- (void)launchWAD:(NSString *)path {
    self.welcome.hidden = YES;
    dispatch_async(self.engineQueue, ^{ DoomPlatformStart(path); });
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.displayLink.preferredFramesPerSecond = 35;
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)tick:(CADisplayLink *)link {
    if (!DoomPlatformIsRunning() || self.tickPending) return;
    self.tickPending = YES;
    dispatch_async(self.engineQueue, ^{
        DoomPlatformTick();
        dispatch_async(dispatch_get_main_queue(), ^{ self.tickPending = NO; });
    });
}

- (void)presentFrame:(NSData *)frame {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)frame);
    CGImageRef image = CGImageCreate(640, 400, 8, 32, 640 * 4, colorSpace,
        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, provider, NULL, false, kCGRenderingIntentDefault);
    self.screen.image = [UIImage imageWithCGImage:image];
    CGImageRelease(image); CGDataProviderRelease(provider); CGColorSpaceRelease(colorSpace);
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WAD를 열 수 없음" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"확인" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

