#import "LDUI.h"
static NSDictionary *LDRecordPerson(NSDictionary *record) {
    return [LDStore.shared target:record[@"person"][@"uid"]] ?: record[@"person"];
}
static NSString *LDChangeText(NSArray *changes) {
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *change in changes) {
        long long delta = [change[@"delta"] longLongValue];
        [lines addObject:[NSString stringWithFormat:@"%@  %@ → %@（%@%lld）", LDMetricName(change[@"key"]), change[@"before"], change[@"after"], delta > 0 ? @"+" : @"", delta]];
    }
    return [lines componentsJoinedByString:@"\n"];
}
@interface LDHistoryController () <UISearchResultsUpdating>
@property(nonatomic, copy) NSString *account;
@property(nonatomic, strong) UISegmentedControl *filter;
@property(nonatomic, strong) UISearchController *search;
@property(nonatomic, copy) NSArray<NSDictionary *> *items;
@end
@implementation LDHistoryController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"动态档案"; self.account = LDStore.shared.accountID;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clear)];
    self.filter = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"喜欢作品", @"数值变化", @"简介变化"]]; self.filter.selectedSegmentIndex = 0;
    self.filter.selectedSegmentTintColor = LDButtonColor();
    [self.filter setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateSelected];
    [self.filter addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 360, 64)];
    self.filter.translatesAutoresizingMaskIntoConstraints = NO; [header addSubview:self.filter];
    [NSLayoutConstraint activateConstraints:@[[self.filter.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20], [self.filter.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20], [self.filter.topAnchor constraintEqualToAnchor:header.topAnchor constant:12], [self.filter.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12], [self.filter.heightAnchor constraintGreaterThanOrEqualToConstant:36]]];
    self.tableView.tableHeaderView = header;
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil]; self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO; self.search.searchBar.placeholder = @"搜索对象、作品或简介内容";
    self.navigationItem.searchController = self.search; self.definesPresentationContext = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:LDStoreChanged object:nil];
}
- (void)refresh {
    if (!self.isViewLoaded) return;
    NSString *query = self.search.searchBar.text ?: @"";
    NSMutableArray *items = [NSMutableArray array];
    if ([self.account isEqual:LDStore.shared.accountID]) for (NSDictionary *record in LDStore.shared.records) {
        if (self.personID.length && ![record[@"person"][@"uid"] isEqual:self.personID]) continue;
        if (self.filter.selectedSegmentIndex == 1 && ![record[@"kind"] isEqual:@"like"]) continue;
        if (self.filter.selectedSegmentIndex == 2 && ![record[@"kind"] isEqual:@"counts"]) continue;
        if (self.filter.selectedSegmentIndex == 3 && ![record[@"kind"] isEqual:@"signature"]) continue;
        NSString *searchable = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@", LDPersonSearchText(LDRecordPerson(record)), LDPersonSearchText(record[@"person"]), record[@"video"][@"author"] ?: @"", record[@"video"][@"text"] ?: @"", record[@"before"] ?: @"", record[@"after"] ?: @""];
        if (query.length && ![searchable localizedCaseInsensitiveContainsString:query]) continue;
        [items addObject:record];
    }
    self.items = items; [super refresh];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController { [self refresh]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MAX(1, self.items.count); }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return @"记录时间为发现时间。左滑可单独删除，点击查看完整内容并复制。简介支持搜索修改前后原文。"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (!self.items.count) return LDCell(@"这里还没有动态", @"检测到变化后会显示在这里；首次检测仅建立基线。", @"tray", NO);
    NSDictionary *r = self.items[(NSUInteger)path.row]; BOOL like = [r[@"kind"] isEqual:@"like"];
    BOOL signature = [r[@"kind"] isEqual:@"signature"];
    NSString *title = [NSString stringWithFormat:@"%@ · %@", LDDisplayName(LDRecordPerson(r)), like ? @"喜欢列表新发现" : signature ? @"简介变化" : @"数值变化"];
    NSString *body = like ? [NSString stringWithFormat:@"%@\n%@", LDString(r[@"video"][@"author"]).length ? [@"@" stringByAppendingString:r[@"video"][@"author"]] : @"作者未提供", LDString(r[@"video"][@"text"]).length ? r[@"video"][@"text"] : @"无作品文案"] : LDChangeText(r[@"changes"]);
    if (signature) body = [NSString stringWithFormat:@"修改前：%@\n修改后：%@", LDSignatureText(r[@"before"]), LDSignatureText(r[@"after"])];
    if (body.length > 150) body = [[body substringWithRange:[body rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 150)]] stringByAppendingString:@"…"];
    NSMutableDictionary *identity = [LDRecordPerson(r) mutableCopy];
    identity[@"name"] = title; [identity removeObjectsForKeys:@[@"remark", @"note"]];
    return LDPersonCell(identity, [NSString stringWithFormat:@"%@\n%@", LDDateText([r[@"timestamp"] doubleValue]), body], YES);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; if (!self.items.count || ![self checkAccount:self.account]) return;
    LDRecordController *detail = [LDRecordController new]; detail.record = self.items[(NSUInteger)path.row];
    [self.navigationController pushViewController:detail animated:YES];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    if (!self.items.count) return nil;
    NSString *recordID = self.items[(NSUInteger)path.row][@"id"];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
        if (![self checkAccount:self.account]) { completion(NO); return; }
        [LDStore.shared deleteRecord:recordID]; completion(YES);
    }];
    remove.image = [UIImage systemImageNamed:@"trash"]; return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
- (void)clear {
    if (![self checkAccount:self.account]) return;
    LDConfirm(self, @"清空全部动态档案？", @"当前账号的所有记录都会被删除，包括筛选结果之外的记录。监控基线保留。", @"全部清空", ^{ if ([self checkAccount:self.account]) [LDStore.shared clearRecords]; });
}
@end

@interface LDRecordController ()
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSArray<NSDictionary *> *fields;
@end
@implementation LDRecordController
- (void)viewDidLoad {
    [super viewDidLoad]; self.account = LDStore.shared.accountID;
    BOOL signature = [self.record[@"kind"] isEqual:@"signature"];
    self.title = [self.record[@"kind"] isEqual:@"like"] ? @"作品详情" : signature ? @"简介变化详情" : @"变化详情";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"删除" style:UIBarButtonItemStylePlain target:self action:@selector(deleteRecord)];
    NSMutableArray *fields = [NSMutableArray array];
    NSDictionary *person = LDRecordPerson(self.record), *video = self.record[@"video"];
    [fields addObject:@{@"title": @"关注对象", @"value": LDDisplayName(person)}];
    [fields addObject:@{@"title": @"对象抖音号", @"value": LDString(person[@"handle"])}];
    [fields addObject:@{@"title": @"发现时间", @"value": LDDateText([self.record[@"timestamp"] doubleValue])}];
    if (video) {
        for (NSArray *pair in @[@[@"作者", @"author"], @[@"作者抖音号", @"authorHandle"], @[@"作品文案", @"text"], @[@"作品链接", @"url"], @[@"作品 ID", @"id"]])
            [fields addObject:@{@"title": pair[0], @"value": LDString(video[pair[1]])}];
        if ([video[@"publishedAt"] doubleValue] > 0) [fields addObject:@{@"title": @"作品发布时间", @"value": LDDateText([video[@"publishedAt"] doubleValue])}];
    } else if (signature) {
        [fields addObject:@{@"title": @"修改前的简介", @"value": self.record[@"before"], @"signature": @YES}];
        [fields addObject:@{@"title": @"修改后的简介", @"value": self.record[@"after"], @"signature": @YES}];
    } else [fields addObject:@{@"title": @"数值变化", @"value": LDChangeText(self.record[@"changes"])}];
    self.fields = fields;
    self.tableView.tableHeaderView = LDHeader(video ? @"留住这次新发现" : signature ? @"留住每一次简介变化" : @"新的动态已记录", video ? @"点击字段即可复制。打开作品将在抖音中查看。" : signature ? @"完整保留修改前后原文，点击简介即可复制，也可复制全部资料。" : @"只记录可见数量的变化，不推断具体关注关系。", video ? @"heart.text.square.fill" : signature ? @"text.alignleft" : @"chart.bar.fill");
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? self.fields.count : self.record[@"video"] ? 2 : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 1) return @"点击任意字段复制其内容。";
    if ([self.record[@"kind"] isEqual:@"signature"]) return @"发现时间不等于实际修改时间。空简介表示对方清空了内容，点击会清空剪贴板；复制全部用（空简介）标明。接口未返回简介不会记为清空。";
    if (!self.record[@"video"]) return @"关注、粉丝或获赞变化可能来自多种原因，以抖音实际展示为准。";
    return [self.record[@"uncertain"] boolValue] ? @"两次检测间列表跨度较大，此条记录表示新发现的作品，无法确认实际点赞时间。作品若已删除或变为私密，链接可能无法打开。" : @"发现时间不等于点赞时间。作品删除、取消喜欢或权限变化后，历史资料仍会保留到清理时。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) {
        NSDictionary *field = self.fields[(NSUInteger)path.row];
        if ([field[@"title"] isEqual:@"关注对象"]) return LDPersonCell(LDRecordPerson(self.record), @"关注对象 · 点击复制名称", NO);
        if ([field[@"title"] isEqual:@"作者"]) return LDPersonCell(@{@"name": LDString(field[@"value"]), @"avatar": LDString(self.record[@"video"][@"authorAvatar"])}, @"作品作者 · 点击复制名称", NO);
        if ([field[@"signature"] boolValue]) return LDCell(field[@"title"], LDSignatureText(field[@"value"]), @"doc.on.doc", NO);
        return LDCell(field[@"title"], LDString(field[@"value"]).length ? field[@"value"] : @"未提供", @"doc.on.doc", NO);
    }
    if (self.record[@"video"] && path.row == 0) return LDCell(@"在抖音打开作品", @"视频 / 图文按原作品展示", @"play.circle.fill", YES);
    return LDCell(@"复制全部资料", nil, @"square.on.square", NO);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; if (![self checkAccount:self.account]) return;
    if (path.section == 0) {
        NSDictionary *field = self.fields[(NSUInteger)path.row];
        if ([field[@"signature"] boolValue]) LDCopySignature(self, field[@"value"]);
        else LDCopy(self, field[@"value"]);
        return;
    }
    if (self.record[@"video"] && path.row == 0) { LDOpenVideo(self, self.record[@"video"][@"id"]); return; }
    NSMutableArray *lines = [NSMutableArray array]; for (NSDictionary *field in self.fields) [lines addObject:[NSString stringWithFormat:@"%@：%@", field[@"title"], [field[@"signature"] boolValue] ? LDSignatureText(field[@"value"]) : field[@"value"]]];
    LDCopy(self, [lines componentsJoinedByString:@"\n"]);
}
- (void)deleteRecord {
    if (![self checkAccount:self.account]) return;
    LDConfirm(self, @"删除这条记录？", @"不会影响对此人的后续检测。", @"删除", ^{
        if (![self checkAccount:self.account]) return;
        [LDStore.shared deleteRecord:self.record[@"id"]]; [self.navigationController popViewControllerAnimated:YES];
    });
}
@end
