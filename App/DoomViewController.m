#import "DoomViewController.h"
#import "DoomPlatform.h"
#include "doomkeys.h"
#include <math.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DoomGlassView : UIView
@property (nonatomic, strong, readonly) UIView *contentView;
@end

@implementation DoomGlassView {
    UIVisualEffectView *_effectView;
}
- (instancetype)init {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        UIVisualEffect *effect = nil;
        Class glassClass = NSClassFromString(@"UIGlassEffect");
        if (glassClass && [glassClass instancesRespondToSelector:@selector(init)]) effect = [[glassClass alloc] init];
        if (!effect) effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        _effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        _effectView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_effectView];
        [NSLayoutConstraint activateConstraints:@[
            [_effectView.topAnchor constraintEqualToAnchor:self.topAnchor], [_effectView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_effectView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor], [_effectView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];
        self.layer.cornerRadius = 28;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 0.75;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
        self.clipsToBounds = YES;
    }
    return self;
}
- (UIView *)contentView { return _effectView.contentView; }
@end

@interface DoomJoystickView : UIView
@end

@implementation DoomJoystickView {
    UIVisualEffectView *_base;
    UIView *_knob;
    BOOL _left, _right, _up, _down;
}
- (instancetype)init {
    if ((self = [super initWithFrame:CGRectZero])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"이동 및 회전 조이스틱";
        self.accessibilityHint = @"위아래로 이동하고 좌우로 회전합니다";
        UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        Class glassClass = NSClassFromString(@"UIGlassEffect");
        if (glassClass && [glassClass instancesRespondToSelector:@selector(init)]) effect = [[glassClass alloc] init];
        _base = [[UIVisualEffectView alloc] initWithEffect:effect];
        _base.userInteractionEnabled = NO;
        _base.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
        _base.layer.borderWidth = 1;
        _base.clipsToBounds = YES;
        [self addSubview:_base];
        _knob = [UIView new];
        _knob.userInteractionEnabled = NO;
        _knob.backgroundColor = [UIColor colorWithWhite:1 alpha:0.82];
        _knob.layer.shadowColor = UIColor.blackColor.CGColor;
        _knob.layer.shadowOpacity = 0.3;
        _knob.layer.shadowRadius = 8;
        [self addSubview:_knob];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)]];
        [NSLayoutConstraint activateConstraints:@[[self.widthAnchor constraintEqualToConstant:150], [self.heightAnchor constraintEqualToConstant:150]]];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _base.frame = self.bounds;
    _base.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2;
    CGFloat size = 66;
    if (CGRectIsEmpty(_knob.frame)) _knob.frame = CGRectMake(0, 0, size, size);
    _knob.layer.cornerRadius = size / 2;
    if (!(_left || _right || _up || _down)) _knob.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}
- (void)setKey:(unsigned char)key active:(BOOL)active current:(BOOL *)current {
    if (*current == active) return;
    *current = active;
    DoomPlatformKey(active, key);
}
- (void)panned:(UIPanGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self];
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat dx = point.x - center.x, dy = point.y - center.y, radius = 44;
    CGFloat distance = hypot(dx, dy);
    if (distance > radius) { dx = dx / distance * radius; dy = dy / distance * radius; }
    BOOL ended = gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed;
    if (ended) { dx = 0; dy = 0; }
    _knob.center = CGPointMake(center.x + dx, center.y + dy);
    CGFloat threshold = 12;
    [self setKey:KEY_LEFTARROW active:!ended && dx < -threshold current:&_left];
    [self setKey:KEY_RIGHTARROW active:!ended && dx > threshold current:&_right];
    [self setKey:KEY_UPARROW active:!ended && dy < -threshold current:&_up];
    [self setKey:KEY_DOWNARROW active:!ended && dy > threshold current:&_down];
    if (ended) [UIView animateWithDuration:0.18 animations:^{ self->_knob.center = center; }];
}
@end

@interface DoomViewController () <UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIImageView *screen;
@property (nonatomic, strong) UIView *launcher;
@property (nonatomic, strong) UIView *controlsView;
@property (nonatomic, strong) UITableView *wadTable;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, copy) NSArray<NSString *> *wadPaths;
@property (nonatomic, copy) NSString *selectedWAD;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) dispatch_queue_t engineQueue;
@property (nonatomic, strong) CAGradientLayer *launcherGradient;
@property (nonatomic) BOOL tickPending;
@end

@implementation DoomViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.engineQueue = dispatch_queue_create("com.acops.doom.engine", DISPATCH_QUEUE_SERIAL);
    [self buildScreen];
    [self buildControls];
    [self buildLauncher];
    [self refreshWADs];
    __weak typeof(self) weakSelf = self;
    DoomPlatformSetFrameHandler(^(NSData *frame) { [weakSelf presentFrame:frame]; });
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; self.launcherGradient.frame = self.launcher.bounds; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (void)buildScreen {
    self.screen = [UIImageView new];
    self.screen.translatesAutoresizingMaskIntoConstraints = NO;
    self.screen.contentMode = UIViewContentModeScaleAspectFit;
    self.screen.layer.magnificationFilter = kCAFilterNearest;
    [self.view addSubview:self.screen];
    [NSLayoutConstraint activateConstraints:@[
        [self.screen.topAnchor constraintEqualToAnchor:self.view.topAnchor], [self.screen.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.screen.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [self.screen.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
}

- (UIButton *)gameButton:(NSString *)title symbol:(NSString *)symbol key:(unsigned char)key {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = title;
    configuration.image = [UIImage systemImageNamed:symbol];
    configuration.imagePlacement = NSDirectionalRectEdgeTop;
    configuration.imagePadding = 3;
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.baseBackgroundColor = [UIColor colorWithWhite:0.08 alpha:0.68];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    button.configuration = configuration;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    button.layer.borderWidth = 0.75;
    button.tag = key;
    button.accessibilityLabel = title;
    [button addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(keyUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [NSLayoutConstraint activateConstraints:@[[button.widthAnchor constraintEqualToConstant:76], [button.heightAnchor constraintEqualToConstant:60]]];
    return button;
}

- (void)buildControls {
    self.controlsView = [UIView new];
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlsView.hidden = YES;
    [self.view addSubview:self.controlsView];
    DoomJoystickView *joystick = [DoomJoystickView new];
    [self.controlsView addSubview:joystick];
    UIButton *select = [self gameButton:@"SELECT" symbol:@"checkmark" key:KEY_ENTER];
    UIButton *use = [self gameButton:@"USE" symbol:@"hand.tap.fill" key:KEY_USE];
    UIButton *fire = [self gameButton:@"FIRE" symbol:@"scope" key:KEY_FIRE];
    UIButton *menu = [self gameButton:@"MENU" symbol:@"line.3.horizontal" key:KEY_ESCAPE];
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[select, use]];
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[fire, menu]];
    top.spacing = bottom.spacing = 10;
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[top, bottom]];
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 10;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsView addSubview:actions];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.view.topAnchor], [self.controlsView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [self.controlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [joystick.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18], [joystick.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-14],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18], [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-14]
    ]];
}

- (UIButton *)launcherButton:(NSString *)title symbol:(NSString *)symbol primary:(BOOL)primary action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *configuration = primary ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.image = [UIImage systemImageNamed:symbol];
    configuration.imagePadding = 8;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.baseForegroundColor = primary ? UIColor.blackColor : UIColor.whiteColor;
    configuration.baseBackgroundColor = primary ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.14];
    button.configuration = configuration;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:50].active = YES;
    return button;
}

- (void)buildLauncher {
    self.launcher = [UIView new];
    self.launcher.translatesAutoresizingMaskIntoConstraints = NO;
    self.launcherGradient = [CAGradientLayer layer];
    self.launcherGradient.colors = @[(id)[UIColor colorWithRed:0.10 green:0.04 blue:0.02 alpha:1].CGColor, (id)UIColor.blackColor.CGColor];
    self.launcherGradient.startPoint = CGPointMake(0, 0);
    self.launcherGradient.endPoint = CGPointMake(1, 1);
    [self.launcher.layer addSublayer:self.launcherGradient];
    [self.view addSubview:self.launcher];
    DoomGlassView *panel = [DoomGlassView new];
    [self.launcher addSubview:panel];
    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.text = @"WAD LIBRARY";
    eyebrow.textColor = [UIColor colorWithRed:1 green:0.48 blue:0.20 alpha:1];
    eyebrow.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"DOOM iOS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBlack];
    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"보유한 WAD를 추가하고 실행할 항목을 선택하세요.";
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.wadTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.wadTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.wadTable.backgroundColor = UIColor.clearColor;
    self.wadTable.dataSource = self;
    self.wadTable.delegate = self;
    self.wadTable.rowHeight = 58;
    self.wadTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    UIButton *import = [self launcherButton:@"WAD 추가" symbol:@"plus" primary:NO action:@selector(importWAD)];
    self.playButton = [self launcherButton:@"선택 항목 실행" symbol:@"play.fill" primary:YES action:@selector(launchSelectedWAD)];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[import, self.playButton]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.spacing = 12;
    buttons.distribution = UIStackViewDistributionFillEqually;
    for (UIView *view in @[eyebrow, title, subtitle, self.wadTable, buttons]) [panel.contentView addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [self.launcher.topAnchor constraintEqualToAnchor:self.view.topAnchor], [self.launcher.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.launcher.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [self.launcher.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [panel.centerXAnchor constraintEqualToAnchor:self.launcher.centerXAnchor],
        [panel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16], [panel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [panel.widthAnchor constraintLessThanOrEqualToConstant:680], [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [panel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [eyebrow.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:24], [eyebrow.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:28],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:3], [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitle.centerYAnchor constraintEqualToAnchor:title.centerYAnchor], [subtitle.leadingAnchor constraintEqualToAnchor:title.trailingAnchor constant:18],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:panel.contentView.trailingAnchor constant:-28],
        [self.wadTable.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8], [self.wadTable.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:12],
        [self.wadTable.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-12],
        [buttons.topAnchor constraintEqualToAnchor:self.wadTable.bottomAnchor constant:8], [buttons.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:28],
        [buttons.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-28], [buttons.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-22]
    ]];
}

- (NSString *)wadDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *directory = [documents stringByAppendingPathComponent:@"WADs"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}
- (void)migrateLegacyWADs {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    for (NSString *name in @[@"DOOM.WAD", @"DOOM1.WAD"]) {
        NSString *old = [documents stringByAppendingPathComponent:name];
        NSString *new = [[self wadDirectory] stringByAppendingPathComponent:name];
        if ([NSFileManager.defaultManager fileExistsAtPath:old] && ![NSFileManager.defaultManager fileExistsAtPath:new]) [NSFileManager.defaultManager moveItemAtPath:old toPath:new error:nil];
    }
}
- (void)refreshWADs {
    [self migrateLegacyWADs];
    NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self wadDirectory] error:nil] ?: @[];
    names = [names filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *_) { return [name.pathExtension.lowercaseString isEqualToString:@"wad"]; }]];
    names = [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *name in names) [paths addObject:[[self wadDirectory] stringByAppendingPathComponent:name]];
    self.wadPaths = paths;
    if (self.selectedWAD && ![self.wadPaths containsObject:self.selectedWAD]) self.selectedWAD = nil;
    if (!self.selectedWAD) self.selectedWAD = self.wadPaths.firstObject;
    self.playButton.enabled = self.selectedWAD != nil;
    [self.wadTable reloadData];
    if (self.selectedWAD) {
        NSUInteger row = [self.wadPaths indexOfObject:self.selectedWAD];
        [self.wadTable selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    if (self.wadPaths.count == 0) {
        UILabel *empty = [UILabel new];
        empty.text = @"아직 추가된 WAD가 없습니다\n아래의 ‘WAD 추가’를 눌러 시작하세요.";
        empty.numberOfLines = 0;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = UIColor.secondaryLabelColor;
        self.wadTable.backgroundView = empty;
    } else self.wadTable.backgroundView = nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.wadPaths.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WAD"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WAD"];
    NSString *path = self.wadPaths[indexPath.row];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    cell.textLabel.text = path.lastPathComponent;
    cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    cell.imageView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
    cell.imageView.tintColor = [UIColor colorWithRed:1 green:0.46 blue:0.18 alpha:1];
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = [path isEqualToString:self.selectedWAD] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedWAD = self.wadPaths[indexPath.row];
    self.playButton.enabled = YES;
    [tableView reloadData];
    [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"삭제" handler:^(__unused UIContextualAction *action, __unused UIView *view, void (^completion)(BOOL)) {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:self.wadPaths[indexPath.row] error:&error];
        [self refreshWADs];
        completion(error == nil);
    }];
    delete.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

- (void)keyDown:(UIButton *)sender {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    DoomPlatformKey(YES, (unsigned char)sender.tag);
}
- (void)keyUp:(UIButton *)sender { DoomPlatformKey(NO, (unsigned char)sender.tag); }
- (void)importWAD {
    UTType *wad = [UTType typeWithFilenameExtension:@"wad"] ?: UTTypeData;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[wad] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}
- (NSString *)availableDestinationForName:(NSString *)name {
    NSString *base = name.stringByDeletingPathExtension;
    NSString *extension = name.pathExtension.length ? name.pathExtension : @"wad";
    NSString *candidate = [[self wadDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", base, extension]];
    NSInteger number = 2;
    while ([NSFileManager.defaultManager fileExistsAtPath:candidate]) candidate = [[self wadDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ %ld.%@", base, (long)number++, extension]];
    return candidate;
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSError *lastError = nil;
    for (NSURL *source in urls) {
        if (![source.pathExtension.lowercaseString isEqualToString:@"wad"]) continue;
        NSString *destination = [self availableDestinationForName:source.lastPathComponent];
        if (![NSFileManager.defaultManager copyItemAtURL:source toURL:[NSURL fileURLWithPath:destination] error:&lastError]) break;
        self.selectedWAD = destination;
    }
    [self refreshWADs];
    if (lastError) [self showError:lastError.localizedDescription];
}
- (void)launchSelectedWAD {
    if (!self.selectedWAD) return;
    NSString *path = self.selectedWAD;
    self.launcher.hidden = YES;
    self.controlsView.hidden = NO;
    dispatch_async(self.engineQueue, ^{ DoomPlatformStart(path); });
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.displayLink.preferredFramesPerSecond = 35;
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)tick:(CADisplayLink *)link {
    if (!DoomPlatformIsRunning() || self.tickPending) return;
    self.tickPending = YES;
    dispatch_async(self.engineQueue, ^{ DoomPlatformTick(); dispatch_async(dispatch_get_main_queue(), ^{ self.tickPending = NO; }); });
}
- (void)presentFrame:(NSData *)frame {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)frame);
    CGImageRef image = CGImageCreate(640, 400, 8, 32, 640 * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, provider, NULL, false, kCGRenderingIntentDefault);
    self.screen.image = [UIImage imageWithCGImage:image];
    CGImageRelease(image); CGDataProviderRelease(provider); CGColorSpaceRelease(colorSpace);
}
- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WAD를 열 수 없음" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"확인" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
