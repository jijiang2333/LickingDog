#import "LDUI.h"
#import <math.h>

static NSString *const LDTelegramURL = @"https://t.me/JiJiang_778";
static NSString *const LDRepositoryURL = @"https://github.com/jijiang2333/LickingDog";

@interface LDAboutController : UIViewController <UITextViewDelegate>
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UITextView *details;
@property(nonatomic, strong) NSLayoutConstraint *textHeight;
@end

@implementation LDAboutController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.accessibilityViewIsModal = YES;
    UIControl *backdrop = [UIControl new];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    backdrop.backgroundColor = [UIColor colorWithWhite:0 alpha:0.38];
    backdrop.isAccessibilityElement = NO;
    [backdrop addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backdrop];

    UIView *panel = [UIView new]; panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    panel.layer.cornerRadius = 22; panel.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:panel];
    self.heading = LDLabel([NSString stringWithFormat:@"%@ %@", LDName, LDVersion], 21, UIFontWeightBold);
    self.heading.textAlignment = NSTextAlignmentCenter;
    self.heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    [self.heading setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh + 1 forAxis:UILayoutConstraintAxisVertical];

    self.details = [UITextView new]; self.details.backgroundColor = UIColor.clearColor;
    self.details.editable = NO; self.details.selectable = YES;
    self.details.scrollEnabled = YES; self.details.delegate = self;
    self.details.adjustsFontForContentSizeCategory = YES;
    self.details.textContainerInset = UIEdgeInsetsZero;
    self.details.textContainer.lineFragmentPadding = 0;
    self.details.dataDetectorTypes = UIDataDetectorTypeNone;
    self.textHeight = [self.details.heightAnchor constraintEqualToConstant:280];
    self.textHeight.priority = UILayoutPriorityDefaultHigh;
    self.textHeight.active = YES;
    [self.details.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"知道了" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.backgroundColor = LDButtonColor(); close.layer.cornerRadius = 12;
    close.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    close.titleLabel.adjustsFontForContentSizeCategory = YES;
    close.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    [close.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.heading, self.details, close]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO; [panel addSubview:stack];
    NSLayoutConstraint *width = [panel.widthAnchor constraintEqualToConstant:360]; width.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        width, [panel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-32],
        [panel.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [panel.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [panel.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20]
    ]];
    [self updateTheme];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateTheme) name:LDThemeChanged object:nil];
}
- (void)updateTheme {
    self.overrideUserInterfaceStyle = LDStyle();
    NSString *text = [NSString stringWithFormat:@"作者：JiJiang778\nTg：%@\n仓库：%@\n\n只有抖音前台运行时才检测。关注和粉丝仅记录数量变化；喜欢作品记录的是发现时间，不等于实际点赞时间。\n对方隐藏的数据无法读取；作品删除、取消喜欢或修改可见范围均可能造成变化。", LDTelegramURL, LDRepositoryURL];
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new]; paragraph.lineSpacing = 5;
    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
        NSForegroundColorAttributeName: UIColor.labelColor, NSParagraphStyleAttributeName: paragraph
    }];
    for (NSString *link in @[LDTelegramURL, LDRepositoryURL])
        [content addAttribute:NSLinkAttributeName value:[NSURL URLWithString:link] range:[text rangeOfString:link]];
    self.details.attributedText = content;
    self.details.linkTextAttributes = @{NSForegroundColorAttributeName: LDAccent(), NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.details.bounds.size.width;
    if (width <= 0) return;
    CGFloat height = ceil([self.details sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    if (fabs(self.textHeight.constant - height) > 0.5) self.textHeight.constant = height;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.isViewLoaded && ![previousTraitCollection.preferredContentSizeCategory isEqual:self.traitCollection.preferredContentSizeCategory]) [self updateTheme];
}
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction {
    if (![@[LDTelegramURL, LDRepositoryURL] containsObject:URL.absoluteString]) return NO;
    if (interaction != UITextItemInteractionInvokeDefaultAction) return YES;
    __weak typeof(self) weakSelf = self;
    [UIApplication.sharedApplication openURL:URL options:@{} completionHandler:^(BOOL success) {
        if (!success) dispatch_async(dispatch_get_main_queue(), ^{
            LDAboutController *controller = weakSelf;
            if (controller.view.window) LDMessage(controller, @"无法打开链接", @"请稍后重试，或长按链接复制地址。");
        });
    }];
    return NO;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (BOOL)accessibilityPerformEscape { [self close]; return YES; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end

void LDShowAbout(UIViewController *presenter) {
    if (!presenter.view.window || presenter.presentedViewController) return;
    LDAboutController *about = [LDAboutController new];
    about.modalPresentationStyle = UIModalPresentationOverFullScreen;
    about.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:about animated:YES completion:nil];
}
