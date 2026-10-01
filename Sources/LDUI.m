#import "LDUI.h"
#import "LDNetwork.h"
#import <objc/message.h>
UIWindow *LDActiveWindow(void) {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return nil;
    UIWindow *fallback;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha < 0.01 || window.windowLevel != UIWindowLevelNormal || !window.rootViewController) continue;
            if (window.isKeyWindow) return window; fallback = window;
        }
    }
    if (!fallback) for (UIWindow *window in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
        if (!window.hidden && window.windowLevel == UIWindowLevelNormal && window.rootViewController) { if (window.isKeyWindow) return window; fallback = window; }
    }
    return fallback;
}
UIViewController *LDTopController(UIViewController *controller) {
    if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) return LDTopController(controller.presentedViewController);
    if ([controller isKindOfClass:UINavigationController.class]) return LDTopController(((UINavigationController *)controller).visibleViewController);
    if ([controller isKindOfClass:UITabBarController.class]) return LDTopController(((UITabBarController *)controller).selectedViewController);
    return controller;
}
UIUserInterfaceStyle LDStyle(void) {
    Class cls = NSClassFromString(@"AWEUIThemeManager");
    if (LDHasMethod(cls, @"isLightTheme", "B", "")) return [LDCall(cls, @"isLightTheme", @[]) boolValue] ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
    return LDActiveWindow().traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
}
UIColor *LDAccent(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithRed:1 green:0.43 blue:0.56 alpha:1] : [UIColor colorWithRed:0.78 green:0.15 blue:0.32 alpha:1];
    }];
}
UIColor *LDButtonColor(void) { return [UIColor colorWithRed:0.76 green:0.12 blue:0.30 alpha:1]; }
UILabel *LDLabel(NSString *text, CGFloat size, UIFontWeight weight) {
    UILabel *label = [UILabel new]; label.text = text; label.textColor = UIColor.labelColor; label.numberOfLines = 0;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight] maximumPointSize:36];
    label.adjustsFontForContentSizeCategory = YES; return label;
}
UIView *LDHeader(NSString *title, NSString *subtitle, NSString *symbol) {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 176)];
    UIView *card = [UIView new]; card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 22; card.layer.cornerCurve = kCACornerCurveContinuous; card.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:card];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.contentMode = UIViewContentModeScaleAspectFit; icon.tintColor = LDAccent();
    [icon.heightAnchor constraintEqualToConstant:36].active = YES;
    UILabel *heading = LDLabel(title, 25, UIFontWeightBold); heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    UILabel *body = LDLabel(subtitle, 14, UIFontWeightRegular); body.textColor = UIColor.secondaryLabelColor; body.tag = 811;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, heading, body]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 9; stack.alignment = UIStackViewAlignmentLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20], [card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [card.topAnchor constraintEqualToAnchor:header.topAnchor constant:16], [card.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20], [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20], [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20]
    ]];
    return header;
}
UITableViewCell *LDCell(NSString *title, NSString *subtitle, NSString *symbol, BOOL disclosure) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    UIListContentConfiguration *config = [UIListContentConfiguration subtitleCellConfiguration];
    config.text = title; config.secondaryText = subtitle;
    config.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; config.textProperties.color = UIColor.labelColor;
    config.textProperties.numberOfLines = 0; config.secondaryTextProperties.numberOfLines = 0;
    config.secondaryTextProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    config.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    config.textToSecondaryTextVerticalPadding = 5;
    config.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(13, 16, 13, 16);
    if (symbol.length) {
        config.image = [UIImage systemImageNamed:symbol]; config.imageProperties.tintColor = LDAccent();
        config.imageProperties.maximumSize = CGSizeMake(26, 26); config.imageToTextPadding = 14;
    }
    cell.contentConfiguration = config;
    cell.accessoryType = disclosure ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}
void LDMessage(UIViewController *presenter, NSString *title, NSString *message) {
    if (!presenter.view.window) return;
    UIViewController *presented = presenter.presentedViewController;
    if (presented) {
        if ([presented isKindOfClass:UIAlertController.class])
            [presented dismissViewControllerAnimated:YES completion:^{ LDMessage(presenter, title, message); }];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = LDStyle(); alert.view.tintColor = LDAccent();
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
void LDConfirm(UIViewController *presenter, NSString *title, NSString *message, NSString *button, dispatch_block_t action) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = LDStyle(); alert.view.tintColor = LDAccent();
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:button style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { if (action) action(); }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
void LDSheet(UIViewController *presenter, NSString *title, NSArray<NSString *> *options, void (^chosen)(NSUInteger)) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.overrideUserInterfaceStyle = LDStyle(); sheet.view.tintColor = LDAccent();
    for (NSUInteger i = 0; i < options.count; i++) [sheet addAction:[UIAlertAction actionWithTitle:options[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { chosen(i); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = presenter.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width / 2, presenter.view.bounds.size.height / 2, 1, 1);
    sheet.popoverPresentationController.permittedArrowDirections = 0;
    [presenter presentViewController:sheet animated:YES completion:nil];
}
@interface LDPillToast : UIView
@end
@implementation LDPillToast
- (void)layoutSubviews { [super layoutSubviews]; self.layer.cornerRadius = self.bounds.size.height / 2; }
@end
static __weak UIView *LDVisibleToast;
void LDToast(UIViewController *presenter, NSString *message) {
    UIWindow *window = presenter.view.window ?: LDActiveWindow(); if (!window || !message.length) return;
    [LDVisibleToast removeFromSuperview];
    LDPillToast *toast = [LDPillToast new]; LDVisibleToast = toast;
    toast.overrideUserInterfaceStyle = LDStyle(); toast.userInteractionEnabled = NO;
    toast.backgroundColor = UIColor.secondarySystemBackgroundColor; toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.layer.shadowColor = UIColor.blackColor.CGColor; toast.layer.shadowOpacity = 0.18;
    toast.layer.shadowRadius = 12; toast.layer.shadowOffset = CGSizeMake(0, 4);
    UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
    check.tintColor = UIColor.systemGreenColor; check.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *label = LDLabel(message, 15, UIFontWeightSemibold);
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[check, label]];
    stack.axis = UILayoutConstraintAxisHorizontal; stack.alignment = UIStackViewAlignmentCenter; stack.spacing = 9;
    stack.translatesAutoresizingMaskIntoConstraints = NO; [toast addSubview:stack]; [window addSubview:toast];
    CGFloat top = window.safeAreaInsets.top + 14;
    UINavigationBar *bar = presenter.navigationController.navigationBar;
    if (bar.window && !bar.hidden && !presenter.navigationController.navigationBarHidden)
        top = MAX(top, CGRectGetMaxY([bar convertRect:bar.bounds toView:window]) + 12);
    [NSLayoutConstraint activateConstraints:@[
        [toast.topAnchor constraintEqualToAnchor:window.topAnchor constant:top], [toast.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [toast.widthAnchor constraintLessThanOrEqualToAnchor:window.safeAreaLayoutGuide.widthAnchor constant:-36],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:46],
        [stack.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:18], [stack.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:toast.topAnchor constant:12], [stack.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-12],
        [check.widthAnchor constraintEqualToConstant:21], [check.heightAnchor constraintEqualToConstant:21]]];
    toast.alpha = 0; [UIView animateWithDuration:0.18 animations:^{ toast.alpha = 1; }];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 0; } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
    });
}
void LDCopy(UIViewController *presenter, NSString *text) {
    if (!text.length) return;
    UIPasteboard.generalPasteboard.string = text; LDToast(presenter, @"已复制到剪贴板");
}
void LDCopySignature(UIViewController *presenter, id signature) {
    if (![signature isKindOfClass:NSString.class]) {
        LDMessage(presenter, @"暂无可复制的简介", @"尚未成功读取个人简介，请等待下一次资料检测。"); return;
    }
    UIPasteboard.generalPasteboard.string = signature;
    LDToast(presenter, [signature length] ? @"个人简介已复制" : @"简介为空，已清空剪贴板");
}
void LDOpenVideo(UIViewController *presenter, NSString *videoID) {
    if (!LDIdentifier(videoID)) return;
    NSString *route = [@"aweme://aweme/detail/" stringByAppendingString:videoID];
    NSString *web = [@"https://www.douyin.com/video/" stringByAppendingString:videoID];
    dispatch_block_t open = ^{
        Class router = NSClassFromString(@"AWERouter");
        if (LDHasMethod(router, @"transferToURLString:", "B", "@") && [LDCall(router, @"transferToURLString:", @[route]) boolValue]) return;
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:web] options:@{} completionHandler:nil];
    };
    open();
}
// Share one appearance snapshot across the plugin's navigation stack.
@interface LDNavigationState : NSObject
@property(nonatomic) BOOL hidden;
@property(nonatomic, strong) UIColor *tint;
@end
@implementation LDNavigationState
@end
@interface LDTableController ()
@property(nonatomic, strong) LDNavigationState *navigationState;
@property(nonatomic) CGPoint savedOffset;
@property(nonatomic) BOOL restoresOffset;
@property(nonatomic) BOOL hasAppeared;
@end
@implementation LDTableController
- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.hidesBottomBarWhenPushed = YES;
    return self;
}
- (void)applyNavigation:(BOOL)animated {
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    if (!self.navigationState) {
        for (UIViewController *page in nav.viewControllers) {
            if ([page isKindOfClass:LDTableController.class] && ((LDTableController *)page).navigationState) {
                self.navigationState = ((LDTableController *)page).navigationState; break;
            }
        }
        if (!self.navigationState) {
            self.navigationState = [LDNavigationState new];
            self.navigationState.hidden = nav.navigationBarHidden; self.navigationState.tint = nav.navigationBar.tintColor;
        }
    }
    [nav setNavigationBarHidden:NO animated:animated];
    nav.navigationBar.tintColor = [LDAccent() resolvedColorWithTraitCollection:self.traitCollection];
}
- (void)restoreNavigation:(BOOL)animated {
    if (!self.navigationState) return;
    [self.navigationController setNavigationBarHidden:self.navigationState.hidden animated:animated];
    self.navigationController.navigationBar.tintColor = self.navigationState.tint;
}
- (void)restoreTableOffset:(CGPoint)offset {
    [self.tableView layoutIfNeeded];
    CGFloat low = -self.tableView.adjustedContentInset.top;
    CGFloat high = MAX(low, self.tableView.contentSize.height - self.tableView.bounds.size.height + self.tableView.adjustedContentInset.bottom);
    [self.tableView setContentOffset:CGPointMake(offset.x, MIN(high, MAX(low, offset.y))) animated:NO];
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.tintColor = LDAccent(); self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 70;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension; self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.backButtonTitle = @"返回";
    self.clearsSelectionOnViewWillAppear = NO;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateTheme) name:LDThemeChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateTheme) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self updateTheme];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; [LDMonitor.shared synchronizeAccount];
    [self updateTheme]; [self applyNavigation:animated]; [self refresh];
    if (self.restoresOffset) [self restoreTableOffset:self.savedOffset];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; self.hasAppeared = YES; [self applyNavigation:NO];
    if (self.restoresOffset) { [self restoreTableOffset:self.savedOffset]; self.restoresOffset = NO; }
}
- (void)viewWillDisappear:(BOOL)animated {
    self.savedOffset = self.tableView.contentOffset; self.restoresOffset = YES;
    [super viewWillDisappear:animated];
    UIViewController *to = [self.transitionCoordinator viewControllerForKey:UITransitionContextToViewControllerKey];
    BOOL leaving = (to && ![to isKindOfClass:LDTableController.class]) ||
        (self.isMovingFromParentViewController && ![self.navigationController.topViewController isKindOfClass:LDTableController.class]);
    if (leaving) {
        [self restoreNavigation:animated];
        __weak typeof(self) weakSelf = self;
        [self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (context.isCancelled) [weakSelf applyNavigation:NO];
        }];
    }
}
- (void)refresh {
    CGPoint offset = self.tableView.contentOffset;
    [self.tableView reloadData];
    if (self.hasAppeared) [self restoreTableOffset:offset];
}
- (void)updateTheme {
    UIUserInterfaceStyle style = LDStyle();
    if (self.overrideUserInterfaceStyle != style) self.overrideUserInterfaceStyle = style;
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new]; [appearance configureWithOpaqueBackground];
    UITraitCollection *traits = [UITraitCollection traitCollectionWithUserInterfaceStyle:style];
    appearance.backgroundColor = [UIColor.systemGroupedBackgroundColor resolvedColorWithTraitCollection:traits];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor.labelColor resolvedColorWithTraitCollection:traits]};
    UIColor *accent = [LDAccent() resolvedColorWithTraitCollection:traits];
    appearance.buttonAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: accent};
    appearance.doneButtonAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: accent};
    appearance.backButtonAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: accent};
    self.navigationItem.standardAppearance = appearance; self.navigationItem.scrollEdgeAppearance = appearance; self.navigationItem.compactAppearance = appearance;
    if (self.view.window && self.navigationController.topViewController == self) self.navigationController.navigationBar.tintColor = accent;
    [self setNeedsStatusBarAppearanceUpdate];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; if (self.isViewLoaded) [self updateTheme]; }
- (UIStatusBarStyle)preferredStatusBarStyle { return LDStyle() == UIUserInterfaceStyleDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header = self.tableView.tableHeaderView; if (!header) return;
    CGFloat width = self.tableView.bounds.size.width;
    CGSize size = [header systemLayoutSizeFittingSize:CGSizeMake(width, 0) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = ceil(size.height);
    if (height > 0 && (fabs(header.frame.size.height - height) > 0.5 || fabs(header.frame.size.width - width) > 0.5)) {
        header.frame = CGRectMake(0, 0, width, height); self.tableView.tableHeaderView = header;
    }
}
- (BOOL)checkAccount:(NSString *)account {
    [LDMonitor.shared synchronizeAccount];
    if ([account isEqual:LDStore.shared.accountID] && account.length) return YES;
    LDMessage(self, @"账号已切换", @"已停止本次操作，请返回重新打开页面。"); return NO;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
void LDOpenSettings(void) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ LDOpenSettings(); }); return; }
    UIViewController *top = LDTopController(LDActiveWindow().rootViewController);
    Class settings = NSClassFromString(@"AWESettingsTableViewController");
    if (!settings || ![top isKindOfClass:settings]) return;
    [LDMonitor.shared synchronizeAccount];
    LDSettingsController *controller = [LDSettingsController new];
    UINavigationController *host = top.navigationController;
    if (host && host.topViewController == top && !host.transitionCoordinator) {
        controller.navigationState = [LDNavigationState new];
        controller.navigationState.hidden = host.navigationBarHidden;
        controller.navigationState.tint = host.navigationBar.tintColor;
        [host pushViewController:controller animated:YES];
    } else if (!host) {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        navigation.overrideUserInterfaceStyle = LDStyle();
        [top presentViewController:navigation animated:YES completion:nil];
    }
}
