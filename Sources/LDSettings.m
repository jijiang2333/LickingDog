#import "LDUI.h"
#import "LDNetwork.h"
#import "LDPolicy.h"
@interface LDSettingsController ()
@property(nonatomic, copy) NSArray *people;
@end
@implementation LDSettingsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = LDName;
    if (self.navigationController.viewControllers.firstObject == self)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.tableView.tableHeaderView = LDHeader(LDName, @"留意每一次变化，也留给你自在刷视频的时间。", @"heart.circle.fill");
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:LDStoreChanged object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateStatus) name:LDMonitorStatusChanged object:nil];
}
- (void)close { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }
- (void)refresh { self.people = LDStore.shared.targets; [super refresh]; [self updateStatus]; }
- (void)updateStatus {
    UILabel *label = [self.tableView.tableHeaderView viewWithTag:811];
    label.text = LDStore.shared.storageError.length ? LDStore.shared.storageError : LDMonitor.shared.status;
    [self.view setNeedsLayout];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 3 : section == 1 ? 1 : section == 2 ? MAX(1, self.people.count) : section == 3 ? 5 : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"检测与提醒", @"添加关注对象", [NSString stringWithFormat:@"正在留意 · %lu / 20", (unsigned long)self.people.count], @"动态档案", @"关于"][(NSUInteger)section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"只在抖音前台检测；默认 30 秒，支持 30–300 秒。多人检测会依次排队；网络异常时自动减慢，不会补发后台期间的请求。";
    if (section == 1) return @"可多选互关好友，也可输入未互关用户的抖音号，核对后添加。";
    if (section == 2) return @"获赞指对方收到的赞；喜欢指对方点赞的作品。四项数量和个人简介变化均会记录并提醒；首次成功读取仅建立基线。";
    if (section == 3) return @"仅保存文字和作品链接，不下载视频。自动清理在抖音前台执行；清空档案不会重置监控基线。";
    return @"适配抖音 39.9.0 接口 · iOS 14 及以上";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    NSDictionary *options = LDStore.shared.options;
    if (path.section == 0) {
        if (path.row == 2) return LDCell(@"刷新间隔", [NSString stringWithFormat:@"每 %.0f 秒 · 点击自定义", LDInterval([options[@"interval"] doubleValue])], @"timer", YES);
        UITableViewCell *cell = LDCell(path.row == 0 ? @"开启前台检测" : @"变化弹窗提醒", path.row == 0 ? @"退到后台即暂停" : @"关闭弹窗仍会保存动态", path.row == 0 ? @"waveform.path.ecg" : @"bell.badge", NO);
        UISwitch *toggle = [UISwitch new]; toggle.onTintColor = LDAccent(); toggle.tag = path.row;
        toggle.on = [options[path.row == 0 ? @"enabled" : @"alerts"] boolValue];
        toggle.accessibilityLabel = path.row == 0 ? @"开启前台检测" : @"变化弹窗提醒";
        [toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle; cell.selectionStyle = UITableViewCellSelectionStyleNone; return cell;
    }
    if (path.section == 1) return LDCell(@"选择好友 / 输入抖音号", @"单选、多选，确认后开始检测", @"person.crop.circle.badge.plus", YES);
    if (path.section == 2) {
        if (!self.people.count) return LDCell(@"还没有关注对象", @"从上方添加一位你想留意的人", @"person.2", NO);
        NSDictionary *person = self.people[(NSUInteger)path.row];
        NSDictionary *counts = person[@"counts"] ?: @{};
        NSString *(^number)(NSString *) = ^NSString *(NSString *key) { return [counts[key] stringValue] ?: @"—"; };
        NSString *detail = [NSString stringWithFormat:@"获赞 %@ · 关注 %@\n粉丝 %@ · 喜欢 %@\n%@ · %@", number(@"received"), number(@"following"), number(@"followers"), number(@"likes"),
            [person[@"paused"] boolValue] ? @"已暂停" : LDString(person[@"status"]), LDDateText([person[@"checkedAt"] doubleValue])];
        return LDPersonCell(person, detail, YES);
    }
    if (path.section == 3) {
        if (path.row == 0) return LDCell(@"查看动态档案", [NSString stringWithFormat:@"%lu 条 · 作品、数值与简介变化", (unsigned long)LDStore.shared.records.count], @"clock.arrow.circlepath", YES);
        if (path.row == 1) return LDCell(@"自动清理", [options[@"retentionDays"] integerValue] ? [NSString stringWithFormat:@"保留最近 %@ 天", options[@"retentionDays"]] : @"不按时间清理，仍受条数上限约束", @"calendar.badge.clock", YES);
        if (path.row == 2) return LDCell(@"记录上限", [NSString stringWithFormat:@"最多 %@ 条，超出自动移除最早记录", options[@"recordLimit"]], @"tray.full", YES);
        if (path.row == 3) return LDCell(@"一键清空档案", [NSString stringWithFormat:@"当前资料约 %@", [NSByteCountFormatter stringFromByteCount:(long long)LDStore.shared.storageBytes countStyle:NSByteCountFormatterCountStyleFile]], @"trash", NO);
        return LDCell(@"检查到期对象", @"仍遵守 30 秒最短间隔", @"arrow.clockwise", NO);
    }
    return LDCell(@"心动雷达 · LickingDog", [@"版本 " stringByAppendingString:LDVersion], @"info.circle", YES);
}
- (void)toggle:(UISwitch *)toggle {
    [LDStore.shared setOption:toggle.tag == 0 ? @"enabled" : @"alerts" value:@(toggle.on)];
    if (!toggle.on && toggle.tag == 1) LDDismissNotice();
}
- (void)editInterval {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"刷新间隔" message:@"输入 30–300 秒的整数。对象较多时，实际周期会包含排队时间。" preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = LDStyle(); alert.view.tintColor = LDAccent();
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.keyboardType = UIKeyboardTypeNumberPad; field.text = [LDStore.shared.options[@"interval"] stringValue]; field.placeholder = @"默认 30 秒"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSNumber *value = LDCount(weakAlert.textFields.firstObject.text);
        if (!value || value.integerValue < 30 || value.integerValue > 300) { dispatch_async(dispatch_get_main_queue(), ^{ LDMessage(self, @"间隔不合适", @"请输入 30 到 300 之间的整数秒数。原设置已保留。"); }); return; }
        [LDStore.shared setOption:@"interval" value:value];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0 && path.row == 2) { [self editInterval]; return; }
    if (path.section == 1) {
        [LDMonitor.shared synchronizeAccount];
        if (!LDStore.shared.accountID.length) { LDMessage(self, @"请先登录", @"登录抖音后即可选择好友或输入抖音号。"); return; }
        [self.navigationController pushViewController:[LDPeoplePicker new] animated:YES]; return;
    }
    if (path.section == 2 && self.people.count) {
        LDPersonController *person = [LDPersonController new]; person.personID = self.people[(NSUInteger)path.row][@"uid"];
        [self.navigationController pushViewController:person animated:YES]; return;
    }
    if (path.section == 3) {
        if (path.row == 0) [self.navigationController pushViewController:[LDHistoryController new] animated:YES];
        if (path.row == 1) LDSheet(self, @"自动清理", @[@"保留 1 天", @"保留 7 天（默认）", @"保留 30 天", @"不按时间清理"], ^(NSUInteger index) { [LDStore.shared setOption:@"retentionDays" value:@[@1, @7, @30, @0][index]]; });
        if (path.row == 2) LDSheet(self, @"记录条数上限", @[@"100 条", @"500 条（默认）", @"1,000 条"], ^(NSUInteger index) { [LDStore.shared setOption:@"recordLimit" value:@[@100, @500, @1000][index]]; });
        if (path.row == 3) LDConfirm(self, @"清空动态档案？", @"这会删除当前账号的所有档案。关注对象和检测基线会保留。", @"全部清空", ^{ [LDStore.shared clearRecords]; });
        if (path.row == 4) { [LDMonitor.shared checkNow]; LDMessage(self, @"已安排检测", @"到期对象会依次检查；尚未到期的对象按原间隔执行。"); }
        return;
    }
    if (path.section == 4) LDShowAbout(self);
}
@end

@interface LDPersonController ()
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSDictionary *person;
@end
@implementation LDPersonController
- (void)viewDidLoad {
    [super viewDidLoad]; self.account = LDStore.shared.accountID;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:LDStoreChanged object:nil];
}
- (void)refresh {
    self.person = [self.account isEqual:LDStore.shared.accountID] ? [LDStore.shared target:self.personID] : nil;
    self.title = LDDisplayName(self.person); [super refresh];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 3 : section == 1 ? 4 : 3; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"个人资料", @"最新可见数据", @"检测状态", @"管理"][(NSUInteger)section]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"优先显示插件备注，其次抖音备注，最后昵称。点击个人简介复制原文（保留换行）；空简介会清空剪贴板。未返回简介时保留上次内容，不记为清空。";
    if (section == 1) return @"数值以最近成功读取为准。开启提醒后，四项可见数量变化均会提示；— 表示未提供，不按 0 处理。";
    return section == 3 ? @"重建后首次读取数值、简介和喜欢只建立基线；移除对象后已有档案保留。" : nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) {
        if (path.row == 0) return LDPersonCell(self.person, [NSString stringWithFormat:@"昵称：%@\n抖音号：%@", LDString(self.person[@"name"]), LDString(self.person[@"handle"])], NO);
        if (path.row == 2) {
            NSString *title = @"个人简介 · 点击复制";
            NSString *detail = LDSignatureText(self.person[@"signature"]);
            if (self.person[@"signatureAvailable"] && ![self.person[@"signatureAvailable"] boolValue])
                title = self.person[@"signature"] ? @"上次读取的简介 · 本次未返回" : @"个人简介 · 暂未读取";
            if ([self.person[@"signatureCheckedAt"] doubleValue] > 0)
                detail = [detail stringByAppendingFormat:@"\n\n读取于 %@", LDDateText([self.person[@"signatureCheckedAt"] doubleValue])];
            else if (self.person[@"signature"]) detail = [detail stringByAppendingString:@"\n\n添加时的资料，等待首次检测"];
            if ([self.person[@"signatureChangedAt"] doubleValue] > 0)
                detail = [detail stringByAppendingFormat:@"\n最近变化 %@", LDDateText([self.person[@"signatureChangedAt"] doubleValue])];
            return LDCell(title, detail, @"text.alignleft", NO);
        }
        return LDCell(@"备注名", LDString(self.person[@"note"]).length ? self.person[@"note"] : LDString(self.person[@"remark"]).length ? [@"抖音备注：" stringByAppendingString:self.person[@"remark"]] : @"设置一个好记的名字", @"pencil", YES);
    }
    if (path.section == 1) {
        NSString *key = @[@"received", @"following", @"followers", @"likes"][(NSUInteger)path.row];
        NSString *number = [self.person[@"counts"][key] stringValue] ?: @"—";
        NSString *detail = [NSString stringWithFormat:@"最近可见 %@", number];
        for (NSDictionary *change in self.person[@"lastChanges"]) if ([change[@"key"] isEqual:key]) {
            long long delta = [change[@"delta"] longLongValue];
            detail = [detail stringByAppendingFormat:@"\n最近变化 %@%lld（%@ → %@）", delta > 0 ? @"+" : @"", delta, change[@"before"], change[@"after"]];
            if ([change[@"timestamp"] doubleValue] > 0) detail = [detail stringByAppendingFormat:@"\n%@", LDDateText([change[@"timestamp"] doubleValue])];
            break;
        }
        return LDCell(LDMetricName(key), detail, @[@"hand.thumbsup", @"person.badge.plus", @"person.2", @"heart"][(NSUInteger)path.row], NO);
    }
    if (path.section == 2) {
        if (path.row == 0) return LDCell(@"资料检测", [NSString stringWithFormat:@"%@\n%@", LDDateText([self.person[@"checkedAt"] doubleValue]), self.person[@"status"] ?: @"对象已移除或账号已切换"], @"clock", NO);
        if (path.row == 1) return LDCell(@"喜欢列表", [NSString stringWithFormat:@"%@\n%@", self.person[@"likesStatus"] ?: @"等待首次读取", LDDateText([self.person[@"likesCheckedAt"] doubleValue])], @"heart", NO);
        return LDCell(@"此人的动态档案", @"查看作品、数值和简介变化", @"clock.arrow.circlepath", YES);
    }
    if (path.row == 0) return LDCell([self.person[@"paused"] boolValue] ? @"继续检测" : @"暂停此人检测", nil, @"pause.circle", NO);
    if (path.row == 1) return LDCell(@"重建检测基线", @"下一轮只保存初始状态", @"arrow.triangle.2.circlepath", NO);
    return LDCell(@"移除关注对象", nil, @"person.crop.circle.badge.minus", NO);
}
- (void)editNote {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置备注" message:@"仅用于心动雷达，搜索和提醒也会优先显示。留空恢复抖音备注或昵称。" preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = LDStyle(); alert.view.tintColor = LDAccent();
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = LDString(self.person[@"note"]); field.placeholder = LDDisplayName(self.person); field.clearButtonMode = UITextFieldViewModeWhileEditing; }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (![self checkAccount:self.account]) return;
        NSString *note = [weakAlert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        if (note.length > 40) { dispatch_async(dispatch_get_main_queue(), ^{ LDMessage(self, @"备注太长", @"请使用 40 个字以内的备注。"); }); return; }
        [LDStore.shared updateTarget:self.personID values:@{@"note": note}]; [LDStore.shared save]; LDToast(self, @"备注已保存");
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES]; if (![self checkAccount:self.account] || !self.person) return;
    if (path.section == 0) {
        if (path.row == 1) [self editNote];
        else if (path.row == 2) LDCopySignature(self, self.person[@"signature"]);
        else LDCopy(self, LDString(self.person[@"handle"]));
        return;
    }
    if (path.section == 2 && path.row == 2) { LDHistoryController *history = [LDHistoryController new]; history.personID = self.personID; [self.navigationController pushViewController:history animated:YES]; return; }
    if (path.section != 3) return;
    if (path.row == 0) [LDStore.shared updateTarget:self.personID values:@{@"paused": @(![self.person[@"paused"] boolValue])}];
    if (path.row == 1) LDConfirm(self, @"重建基线？", @"下次检测会作为新的起点，已有档案不会删除。", @"重建基线", ^{ if (![self checkAccount:self.account]) return; [LDMonitor.shared invalidateTarget:self.personID]; [LDStore.shared resetBaseline:self.personID]; });
    if (path.row == 2) LDConfirm(self, @"移除此人？", @"停止检测此人的动态，已保存的档案仍可查看。", @"移除", ^{ if (![self checkAccount:self.account]) return; [LDStore.shared removeTarget:self.personID]; [self.navigationController popViewControllerAnimated:YES]; });
}
@end
