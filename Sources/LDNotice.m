#import "LDUI.h"
#import "LDPolicy.h"
@interface LDNotice : UIView
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UILabel *body;
@property(nonatomic, strong) UILabel *footer;
@property(nonatomic, strong) UILabel *lockHint;
@property(nonatomic, strong) UIButton *confirmButton;
@property(nonatomic, strong) UIButton *videoButton;
@property(nonatomic, strong) UIControl *backdrop;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *people;
@property(nonatomic, strong) NSMutableArray<NSString *> *order;
@property(nonatomic, strong) NSTimer *unlockTimer;
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSString *videoID;
@property(nonatomic) NSTimeInterval lockedAt;
@property(nonatomic) NSUInteger total;
@end
static __weak LDNotice *LDVisibleNotice;
@implementation LDNotice
- (UIButton *)button:(NSString *)title primary:(BOOL)primary action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:primary ? UIColor.whiteColor : LDAccent() forState:UIControlStateNormal];
    button.backgroundColor = primary ? LDButtonColor() : UIColor.tertiarySystemFillColor;
    button.layer.cornerRadius = 14; button.layer.cornerCurve = kCACornerCurveContinuous;
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] maximumPointSize:24];
    button.titleLabel.adjustsFontForContentSizeCategory = YES; button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.75; button.contentEdgeInsets = UIEdgeInsetsMake(14, 12, 14, 12);
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:50].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.overrideUserInterfaceStyle = LDStyle(); self.accessibilityViewIsModal = YES;
        self.people = [NSMutableDictionary dictionary]; self.order = [NSMutableArray array]; self.account = LDStore.shared.accountID;
        self.backdrop = [[UIControl alloc] initWithFrame:self.bounds]; self.backdrop.autoresizingMask = self.autoresizingMask;
        self.backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38]; self.backdrop.accessibilityLabel = @"关闭动态提醒";
        [self.backdrop addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.backdrop];
        self.panel = [UIView new]; self.panel.translatesAutoresizingMaskIntoConstraints = NO;
        self.panel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.panel.layer.cornerRadius = 24; self.panel.layer.cornerCurve = kCACornerCurveContinuous;
        self.panel.layer.shadowColor = UIColor.blackColor.CGColor; self.panel.layer.shadowOpacity = 0.16;
        self.panel.layer.shadowRadius = 28; self.panel.layer.shadowOffset = CGSizeMake(0, 10); [self addSubview:self.panel];
        UIScrollView *scroll = [UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints = NO; [self.panel addSubview:scroll];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.circle.fill"]];
        icon.tintColor = LDAccent(); icon.contentMode = UIViewContentModeScaleAspectFit; [icon.heightAnchor constraintEqualToConstant:42].active = YES;
        self.heading = LDLabel(@"你留意的人有了新动态", 21, UIFontWeightBold); self.heading.textAlignment = NSTextAlignmentCenter;
        self.heading.accessibilityTraits |= UIAccessibilityTraitHeader;
        self.body = LDLabel(@"", 16, UIFontWeightRegular);
        self.footer = LDLabel(@"", 12, UIFontWeightRegular); self.footer.textColor = UIColor.secondaryLabelColor;
        UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icon, self.heading, self.body, self.footer]];
        content.axis = UILayoutConstraintAxisVertical; content.spacing = 14; content.translatesAutoresizingMaskIntoConstraints = NO; [scroll addSubview:content];
        self.confirmButton = [self button:@"确定" primary:YES action:@selector(close)];
        self.videoButton = [self button:@"查看作品" primary:NO action:@selector(openVideo)]; self.videoButton.hidden = YES;
        self.lockHint = LDLabel(@"防误触保护 · 2 秒后可操作", 12, UIFontWeightRegular);
        self.lockHint.textAlignment = NSTextAlignmentCenter; self.lockHint.textColor = UIColor.secondaryLabelColor;
        UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[self.videoButton, self.confirmButton]];
        buttons.axis = UILayoutConstraintAxisHorizontal; buttons.distribution = UIStackViewDistributionFillEqually; buttons.spacing = 10;
        UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[self.lockHint, buttons]];
        actions.axis = UILayoutConstraintAxisVertical; actions.spacing = 10; actions.translatesAutoresizingMaskIntoConstraints = NO; [self.panel addSubview:actions];
        NSLayoutConstraint *width = [self.panel.widthAnchor constraintEqualToConstant:360]; width.priority = 999;
        NSLayoutConstraint *height = [scroll.heightAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.heightAnchor]; height.priority = 750;
        [NSLayoutConstraint activateConstraints:@[width, height,
            [self.panel.widthAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.widthAnchor constant:-36],
            [self.panel.centerXAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.centerXAnchor], [self.panel.centerYAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.centerYAnchor],
            [self.panel.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:12], [self.panel.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-12],
            [scroll.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:24], [scroll.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-24],
            [scroll.topAnchor constraintEqualToAnchor:self.panel.topAnchor constant:24], [scroll.heightAnchor constraintGreaterThanOrEqualToConstant:44],
            [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
            [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor], [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor], [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
            [actions.leadingAnchor constraintEqualToAnchor:self.panel.leadingAnchor constant:20], [actions.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-20],
            [actions.topAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:18], [actions.bottomAnchor constraintEqualToAnchor:self.panel.bottomAnchor constant:-20]
        ]];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(forceClose) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(theme) name:LDThemeChanged object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(accountChanged) name:LDStoreChanged object:nil];
        [self lockActions];
    }
    return self;
}
- (void)theme { self.overrideUserInterfaceStyle = LDStyle(); }
- (void)accountChanged { if (![self.account isEqual:LDStore.shared.accountID] || ![LDStore.shared.options[@"alerts"] boolValue]) [self forceClose]; }
- (BOOL)canAct { return LDNoticeReady(NSProcessInfo.processInfo.systemUptime, self.lockedAt); }
- (void)setActionsEnabled:(BOOL)enabled {
    self.confirmButton.enabled = enabled; self.videoButton.enabled = enabled; self.backdrop.enabled = enabled;
    self.confirmButton.alpha = enabled ? 1 : 0.5; self.videoButton.alpha = enabled ? 1 : 0.5;
    self.lockHint.text = enabled ? @"请确认后关闭 · 提醒不会自动消失" : @"防误触保护 · 2 秒后可操作";
}
- (void)lockActions {
    self.lockedAt = NSProcessInfo.processInfo.systemUptime; [self setActionsEnabled:NO];
    [self.unlockTimer invalidate]; __weak typeof(self) weakSelf = self;
    self.unlockTimer = [NSTimer timerWithTimeInterval:2 repeats:NO block:^(NSTimer *timer) {
        typeof(self) self = weakSelf; if (!self) return;
        self.unlockTimer = nil; [self setActionsEnabled:[self canAct]];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.unlockTimer forMode:NSRunLoopCommonModes];
}
- (void)append:(NSArray *)events {
    // Bound per-user summaries; keep full events in the archive.
    NSString *newVideoID;
    for (NSDictionary *event in events) {
        NSDictionary *person = event[@"person"]; NSString *uid = person[@"uid"];
        if (!LDIdentifier(uid)) continue;
        NSMutableDictionary *summary = self.people[uid];
        if (!summary) {
            if (self.order.count >= 20) continue;
            summary = [@{@"person": person, @"changes": [NSMutableDictionary dictionary], @"likes": @0} mutableCopy];
            self.people[uid] = summary; [self.order addObject:uid];
        }
        summary[@"person"] = [LDStore.shared target:uid] ?: person; self.total++;
        if ([event[@"kind"] isEqual:@"like"]) {
            summary[@"likes"] = @([summary[@"likes"] unsignedIntegerValue] + 1);
            if (!newVideoID && LDIdentifier(event[@"video"][@"id"])) newVideoID = event[@"video"][@"id"];
        } else if ([event[@"kind"] isEqual:@"signature"]) {
            summary[@"signatureCount"] = @([summary[@"signatureCount"] unsignedIntegerValue] + 1);
            summary[@"signature"] = event[@"after"];
        } else for (NSDictionary *change in event[@"changes"]) {
            NSString *key = change[@"key"]; if (![@[@"received", @"following", @"followers", @"likes"] containsObject:key]) continue;
            NSMutableDictionary *changes = summary[@"changes"];
            NSNumber *before = changes[key][@"before"] ?: change[@"before"], *after = change[@"after"];
            changes[key] = @{@"before": before, @"after": after, @"delta": @(after.longLongValue - before.longLongValue)};
        }
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *uid in self.order) {
        NSDictionary *summary = self.people[uid]; NSMutableArray *details = [NSMutableArray arrayWithObject:LDDisplayName(summary[@"person"])];
        for (NSString *key in @[@"received", @"following", @"followers", @"likes"]) {
            NSDictionary *change = summary[@"changes"][key]; if (!change) continue;
            long long delta = [change[@"delta"] longLongValue];
            NSString *difference = delta ? [NSString stringWithFormat:@"%@%lld", delta > 0 ? @"+" : @"", delta] : @"期间有变动";
            [details addObject:[NSString stringWithFormat:@"%@  %@ → %@（%@）", LDMetricName(key), change[@"before"], change[@"after"], difference]];
        }
        if ([summary[@"likes"] unsignedIntegerValue]) [details addObject:[NSString stringWithFormat:@"喜欢列表新发现 %@ 个作品", summary[@"likes"]]];
        if ([summary[@"signatureCount"] unsignedIntegerValue]) {
            NSString *preview = LDSignatureText(summary[@"signature"]);
            if (preview.length > 120) preview = [[preview substringWithRange:[preview rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 120)]] stringByAppendingString:@"…"];
            [details addObject:[NSString stringWithFormat:@"个人简介变化 %@ 次\n最新简介：%@", summary[@"signatureCount"], preview]];
        }
        [lines addObject:[details componentsJoinedByString:@"\n"]];
    }
    self.body.text = [lines componentsJoinedByString:@"\n\n"];
    self.footer.text = [NSString stringWithFormat:@"共 %lu 条记录，已存入\n设置 → 心动雷达 → 动态档案", (unsigned long)self.total];
    if (newVideoID && ![newVideoID isEqual:self.videoID]) {
        self.videoID = newVideoID; self.videoButton.hidden = NO;
        [self.videoButton setTitle:self.total > 1 ? @"查看最新作品" : @"查看作品" forState:UIControlStateNormal];
        [self lockActions]; // Protect a newly appearing or changed route button too.
    }
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.heading);
}
- (BOOL)accessibilityPerformEscape { if (![self canAct]) return NO; [self close]; return YES; }
- (void)close { if ([self canAct]) [self forceClose]; }
- (void)openVideo {
    if (![self canAct] || ![self.account isEqual:LDStore.shared.accountID] || !LDIdentifier(self.videoID)) return;
    NSString *videoID = self.videoID; UIViewController *presenter = LDTopController(self.window.rootViewController);
    [self forceClose]; LDOpenVideo(presenter, videoID);
}
- (void)forceClose {
    [self.unlockTimer invalidate]; self.unlockTimer = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self]; [self removeFromSuperview];
    if (LDVisibleNotice == self) LDVisibleNotice = nil;
}
- (void)dealloc { [self.unlockTimer invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
void LDShowNotice(NSArray<NSDictionary *> *events) {
    if (!events.count || ![LDStore.shared.options[@"alerts"] boolValue]) return;
    UIWindow *window = LDActiveWindow(); if (!window) return;
    if (LDVisibleNotice) { [LDVisibleNotice append:events]; return; }
    LDNotice *notice = [[LDNotice alloc] initWithFrame:window.bounds]; LDVisibleNotice = notice;
    [window addSubview:notice]; [notice append:events]; [notice layoutIfNeeded];
    notice.alpha = 0; notice.panel.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.97, 0.97);
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : 0.2 animations:^{ notice.alpha = 1; notice.panel.transform = CGAffineTransformIdentity; }];
}
void LDDismissNotice(void) { [LDVisibleNotice forceClose]; }
