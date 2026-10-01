#import "LDNetwork.h"
@interface LDRequest : NSObject
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSDictionary *params;
@property(nonatomic, copy) NSString *owner;
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) LDReply completion;
@property(nonatomic, strong) id task;
@property(nonatomic, copy) LDStartOperation start;
@property(nonatomic, copy) dispatch_block_t cancellation;
@property(nonatomic, strong) NSTimer *deadline;
@property(nonatomic) BOOL finished;
@end
@implementation LDRequest
@end
@interface LDNetwork ()
@property(nonatomic, strong) NSMutableArray<LDRequest *> *queue;
@property(nonatomic, strong) LDRequest *active;
@property(nonatomic, strong) NSTimer *pumpTimer;
@property(nonatomic) NSTimeInterval lastStarted;
@end
NSString *LDCurrentAccount(void) {
    id service = LDCall(NSClassFromString(@"AWEUserService"), @"sharedService", @[]);
    NSString *uid = LDString(LDCall(service, @"userID", @[]));
    if (!LDIdentifier(uid) || [uid isEqual:@"0"]) return @"";
    return uid;
}
NSString *LDDiagnosticText(NSError *error) {
    // No account IDs, request parameters, cookies or response bodies.
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    Class database = NSClassFromString(@"AWEIMUserDBManager");
    Class search = NSClassFromString(@"AWESearchUserManager");
    SEL local = NSSelectorFromString(@"localContactListWithReadScene:completion:");
    SEL query = NSSelectorFromString(@"fetchUsersWithKeyword:cursor:isPullToRefresh:completion:");
    return [NSString stringWithFormat:@"心动雷达 %@\n抖音 %@ (%@)\n阶段：%@\n错误：%@ / %ld\n联系人入口：%@ / 异步 %@\n用户搜索入口：%@",
        LDVersion, LDString(info[@"CFBundleShortVersionString"]), LDString(info[@"CFBundleVersion"]),
        LDString(error.userInfo[@"LickingDogEndpoint"]), error.domain, (long)error.code,
        database ? @"存在" : @"缺失", [database instancesRespondToSelector:local] ? @"存在" : @"缺失",
        [search instancesRespondToSelector:query] ? @"存在" : @"缺失"];
}
@implementation LDNetwork
+ (instancetype)shared {
    static LDNetwork *network; static dispatch_once_t once;
    dispatch_once(&once, ^{ network = [self new]; }); return network;
}
- (instancetype)init {
    if ((self = [super init])) {
        _queue = [NSMutableArray array];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(cancelAll) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (void)get:(NSString *)url parameters:(NSDictionary *)parameters owner:(NSString *)owner completion:(LDReply)completion {
    LDRequest *r = [LDRequest new]; r.url = url; r.params = parameters; r.owner = owner; r.completion = completion;
    [self enqueue:r];
}
- (void)perform:(NSString *)stage owner:(NSString *)owner start:(LDStartOperation)start completion:(LDReply)completion {
    LDRequest *r = [LDRequest new]; r.url = stage; r.owner = owner; r.start = start; r.completion = completion;
    [self enqueue:r];
}
- (void)cancelRequest:(LDRequest *)request {
    dispatch_block_t cancel = request.cancellation; request.cancellation = nil;
    if (cancel) cancel();
    LDCall(request.task, @"cancel", @[]);
}
- (void)enqueue:(LDRequest *)request {
    NSAssert(NSThread.isMainThread, @"Network broker is confined to main thread");
    request.account = LDCurrentAccount();
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive || !request.account.length) {
        request.completion(nil, LDError(401, @"请保持抖音在前台，并先登录账号。")); return;
    }
    [self.queue addObject:request]; [self pump];
}
- (void)pump {
    if (self.active || self.pumpTimer || !self.queue.count) return;
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) { [self cancelAll]; return; }
    NSTimeInterval wait = MAX(0, self.lastStarted + 2.0 - NSProcessInfo.processInfo.systemUptime);
    __weak typeof(self) weakSelf = self;
    self.pumpTimer = [NSTimer timerWithTimeInterval:MAX(wait, 0.01) repeats:NO block:^(NSTimer *timer) {
        weakSelf.pumpTimer = nil; [weakSelf beginNext];
    }];
    self.pumpTimer.tolerance = 0.15;
    [NSRunLoop.mainRunLoop addTimer:self.pumpTimer forMode:NSRunLoopCommonModes];
}
- (void)beginNext {
    if (self.active || !self.queue.count) return;
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) { [self cancelAll]; return; }
    LDRequest *r = self.queue.firstObject; [self.queue removeObjectAtIndex:0]; self.active = r;
    if (![r.account isEqual:LDCurrentAccount()]) { [self finish:r value:nil error:LDError(-999, @"账号已切换，请重新操作。")]; return; }
    self.lastStarted = NSProcessInfo.processInfo.systemUptime;
    __weak typeof(self) weakSelf = self; __weak LDRequest *weakRequest = r;
    r.deadline = [NSTimer timerWithTimeInterval:15 repeats:NO block:^(NSTimer *timer) {
        LDRequest *request = weakRequest;
        if (request && !request.finished) {
            [weakSelf cancelRequest:request];
            [weakSelf finish:request value:nil error:LDError(408, @"请求超时，稍后会自动重试。")];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:r.deadline forMode:NSRunLoopCommonModes];
    if (r.start) {
        LDReply reply = ^(id value, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                LDRequest *request = weakRequest;
                if (request && !request.finished) [weakSelf finish:request value:value error:error];
            });
        };
        LDIsCurrent current = ^BOOL {
            LDRequest *request = weakRequest;
            return request && !request.finished && UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
                [request.account isEqual:LDCurrentAccount()];
        };
        @try { r.cancellation = r.start(reply, current); }
        @catch (__unused NSException *exception) { reply(nil, LDError(502, @"抖音数据服务未能完成操作，请重试或复制诊断。")); }
        r.start = nil;
        return;
    }
    // The raw AWENetwork completion passes two objects; accept either error order.
    id callback = [^(id first, id second) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LDRequest *request = weakRequest; if (!request || request.finished) return;
            NSError *error = [first isKindOfClass:NSError.class] ? first : [second isKindOfClass:NSError.class] ? second : nil;
            id value = first && first != NSNull.null && ![first isKindOfClass:NSError.class] ? first : second;
            if ([value isKindOfClass:NSError.class] || value == NSNull.null) value = nil;
            for (id envelope in @[value ?: @{}, LDRead(value, @"data") ?: @{}]) {
                id rawStatus = LDFirst(envelope, @[@"status_code", @"statusCode"]);
                NSNumber *status = [rawStatus isKindOfClass:NSNumber.class] ? rawStatus : LDCount(rawStatus);
                if (!error && rawStatus && !status) error = LDError(502, @"响应状态不可识别，本次结果已忽略。");
                if (!error && status.longLongValue != 0) error = LDError(status.integerValue,
                    LDString(LDFirst(envelope, @[@"status_msg", @"statusMsg"])).length ? LDString(LDFirst(envelope, @[@"status_msg", @"statusMsg"])) : @"抖音暂时未返回数据。");
            }
            if (!error && !value) error = LDError(502, @"请求返回了空数据。");
            [weakSelf finish:request value:value error:error];
        });
    } copy];
    // Host GET supplies login context and common parameters; TTNet needs an absolute URL.
    NSURL *url = [NSURL URLWithString:r.url];
    if (![url.scheme isEqualToString:@"https"] || !url.host.length) {
        [self finish:r value:nil error:LDError(400, @"请求地址不完整，请重新打开页面。")]; return;
    }
    Class service = NSClassFromString(@"AWENetworkService");
    if (LDHasMethod(service, @"getWithURLString:params:timeout:completion:", "@", "@@d@")) {
        r.task = LDCall(service, @"getWithURLString:params:timeout:completion:", @[r.url, r.params, @12.0, callback]);
    } else if (LDHasMethod(service, @"getWithURLString:params:completion:", "@", "@@@")) {
        r.task = LDCall(service, @"getWithURLString:params:completion:", @[r.url, r.params, callback]);
    } else {
        [self finish:r value:nil error:LDError(503, @"当前抖音版本的网络入口不可用。")]; return;
    }
    if (r.finished) { LDCall(r.task, @"cancel", @[]); r.task = nil; }
    // A nil task may still complete synchronously; let the watchdog handle missing callbacks.
}
- (void)finish:(LDRequest *)request value:(id)value error:(NSError *)error {
    if (request.finished) return;
    request.finished = YES; [request.deadline invalidate]; request.deadline = nil; request.task = nil;
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive || ![request.account isEqual:LDCurrentAccount()]) {
        value = nil; error = LDError(-999, @"已暂停请求。");
    }
    if (error) {
        NSMutableDictionary *info = [error.userInfo mutableCopy];
        NSString *message = error.localizedDescription;
        if ([error.domain isEqual:NSURLErrorDomain]) {
            if (error.code == NSURLErrorCancelled) message = @"请求已暂停。";
            else if (error.code == NSURLErrorTimedOut) message = @"连接超时，请稍后重试。";
            else if (error.code == NSURLErrorNotConnectedToInternet) message = @"网络未连接，请检查抖音联网后重试。";
        }
        // A host business error (e.g. code 5) is not necessarily a network error.
        if (![error.domain isEqual:@"LickingDog"]) {
            info[NSUnderlyingErrorKey] = error;
            message = [NSString stringWithFormat:@"%@（%@ / %ld）", message, error.domain, (long)error.code];
        }
        info[NSLocalizedDescriptionKey] = message;
        info[@"LickingDogEndpoint"] = [request.url hasPrefix:@"https://"] ? ([NSURL URLWithString:request.url].path ?: @"") : request.url;
        error = [NSError errorWithDomain:error.domain code:error.code userInfo:info];
    }
    request.cancellation = nil; request.start = nil;
    LDReply completion = request.completion; request.completion = nil;
    if (self.active == request) self.active = nil;
    if (completion) completion(value, error);
    [self pump];
}
- (void)cancelOwner:(NSString *)owner {
    NSMutableArray *cancelled = [NSMutableArray array];
    for (LDRequest *r in self.queue.copy) if ([r.owner isEqual:owner]) { [self.queue removeObject:r]; [cancelled addObject:r]; }
    if ([self.active.owner isEqual:owner]) { [self cancelRequest:self.active]; [cancelled addObject:self.active]; }
    for (LDRequest *r in cancelled) [self finish:r value:nil error:LDError(-999, @"请求已取消。")];
    if (!self.queue.count) { [self.pumpTimer invalidate]; self.pumpTimer = nil; }
}
- (void)cancelAll {
    [self.pumpTimer invalidate]; self.pumpTimer = nil;
    NSArray *queued = self.queue.copy; [self.queue removeAllObjects];
    LDRequest *active = self.active; [self cancelRequest:active];
    if (active) [self finish:active value:nil error:LDError(-999, @"已暂停请求。")];
    for (LDRequest *r in queued) [self finish:r value:nil error:LDError(-999, @"已暂停请求。")];
}
@end
