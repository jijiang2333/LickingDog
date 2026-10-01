#import "LDMonitor.h"
#import "LDApi.h"
#import "LDPolicy.h"
#import <float.h>
NSNotificationName const LDMonitorStatusChanged = @"LickingDog.MonitorStatusChanged";
NSNotificationName const LDMonitorAlert = @"LickingDog.MonitorAlert";
static NSString *const LDMonitorOwner = @"LickingDog.Monitor";
@interface LDMonitor ()
@property(nonatomic) BOOL started;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL reconciling;
@property(nonatomic) NSUInteger generation;
@property(nonatomic, copy) NSString *flightUID;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *attempts;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *failures;
@property(nonatomic) NSTimeInterval lastPruned;
@end
@implementation LDMonitor
+ (instancetype)shared {
    static LDMonitor *monitor; static dispatch_once_t once;
    dispatch_once(&once, ^{ monitor = [self new]; }); return monitor;
}
- (instancetype)init {
    if ((self = [super init])) { _attempts = [NSMutableDictionary dictionary]; _failures = [NSMutableDictionary dictionary]; }
    return self;
}
- (void)start {
    if (self.started) return;
    self.started = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(becameActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resignedActive) name:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged) name:LDStoreChanged object:nil];
    [self becameActive];
}
- (BOOL)active { return UIApplication.sharedApplication.applicationState == UIApplicationStateActive; }
- (void)notify { [NSNotificationCenter.defaultCenter postNotificationName:LDMonitorStatusChanged object:self]; }
- (NSString *)status {
    if (!LDStore.shared.accountID.length) return @"请先登录抖音";
    if (![LDStore.shared.options[@"enabled"] boolValue]) return @"检测已关闭";
    if (!self.active) return @"后台已暂停";
    if (!LDStore.shared.targets.count) return @"添加一个人，开始留意新动态";
    if (self.busy) return @"正在轻量检测…";
    for (NSDictionary *person in LDStore.shared.targets) if (![person[@"paused"] boolValue]) return @"仅在前台检测 · 正在守候";
    return @"所有关注对象已暂停";
}
- (void)cancelCycle {
    self.generation++;
    [self.timer invalidate]; self.timer = nil; self.busy = NO; self.flightUID = nil;
    [LDNetwork.shared cancelOwner:LDMonitorOwner];
}
- (void)synchronizeAccount {
    if (self.reconciling) return;
    NSString *account = LDCurrentAccount();
    if ([account isEqual:LDStore.shared.accountID]) return;
    self.reconciling = YES; [self cancelCycle]; [LDNetwork.shared cancelAll];
    [LDStore.shared activateAccount:account];
    [self.attempts removeAllObjects]; [self.failures removeAllObjects];
    self.reconciling = NO; [self notify];
}
- (void)becameActive {
    if (!self.active) return;
    [self synchronizeAccount]; [LDStore.shared prune]; [LDStore.shared save]; [self schedule];
}
- (void)resignedActive {
    [self cancelCycle]; [LDNetwork.shared cancelAll]; [LDStore.shared flush]; [self notify];
}
- (BOOL)enabled {
    return self.active && LDStore.shared.accountID.length && [LDStore.shared.options[@"enabled"] boolValue];
}
- (void)settingsChanged {
    if (self.reconciling) return;
    NSDictionary *target = self.flightUID ? [LDStore.shared target:self.flightUID] : nil;
    if (self.busy && (![self enabled] || !target || [target[@"paused"] boolValue])) [self cancelCycle];
    [self schedule]; [self notify];
}
- (NSTimeInterval)remainingFor:(NSDictionary *)person {
    NSString *uid = person[@"uid"];
    double interval = LDRetryInterval([LDStore.shared.options[@"interval"] doubleValue], [self.failures[uid] unsignedIntValue]);
    NSNumber *attempt = self.attempts[uid];
    if (!attempt) {
        NSTimeInterval persisted = [person[@"lastAttempt"] doubleValue];
        if (persisted <= 0) return 0;
        double elapsed = MAX(0, NSDate.date.timeIntervalSince1970 - persisted);
        attempt = @(NSProcessInfo.processInfo.systemUptime - MIN(elapsed, 300.0)); self.attempts[uid] = attempt;
    }
    return MAX(0, interval - (NSProcessInfo.processInfo.systemUptime - attempt.doubleValue));
}
- (void)schedule {
    [self.timer invalidate]; self.timer = nil;
    if (self.busy || !self.enabled) return;
    NSTimeInterval next = DBL_MAX;
    for (NSDictionary *person in LDStore.shared.targets) if (![person[@"paused"] boolValue]) next = MIN(next, [self remainingFor:person]);
    if (next == DBL_MAX) return;
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:MAX(0.2, next) repeats:NO block:^(NSTimer *timer) {
        weakSelf.timer = nil; [weakSelf tick];
    }];
    self.timer.tolerance = MIN(2, MAX(0.1, next * 0.1));
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)checkNow {
    [self synchronizeAccount]; [self tick];
}
- (void)invalidateTarget:(NSString *)uid {
    if ([self.flightUID isEqual:uid]) [self cancelCycle];
    [self schedule];
}
- (BOOL)valid:(NSUInteger)generation uid:(NSString *)uid account:(NSString *)account {
    NSDictionary *person = [LDStore.shared target:uid];
    return generation == self.generation && self.enabled && [account isEqual:LDCurrentAccount()] &&
        [account isEqual:LDStore.shared.accountID] && person && ![person[@"paused"] boolValue];
}
- (void)tick {
    [self synchronizeAccount];
    if (!self.enabled || self.busy) return;
    NSDictionary *person;
    double oldest = DBL_MAX;
    for (NSDictionary *candidate in LDStore.shared.targets) {
        if ([candidate[@"paused"] boolValue] || [self remainingFor:candidate] > 0.05) continue;
        double attempt = [self.attempts[candidate[@"uid"]] doubleValue];
        if (!person || attempt < oldest) { oldest = attempt; person = candidate; }
    }
    if (!person) { [self schedule]; return; }
    if (NSDate.date.timeIntervalSince1970 - self.lastPruned > 60) { self.lastPruned = NSDate.date.timeIntervalSince1970; [LDStore.shared prune]; }
    self.busy = YES; self.flightUID = person[@"uid"];
    NSString *uid = self.flightUID, *account = LDStore.shared.accountID;
    NSUInteger generation = ++self.generation;
    self.attempts[uid] = @(NSProcessInfo.processInfo.systemUptime);
    [LDStore.shared updateTarget:uid values:@{@"lastAttempt": @(NSDate.date.timeIntervalSince1970), @"status": @"正在检测…"}];
    [self notify];
    [LDApi profile:person owner:LDMonitorOwner completion:^(id profile, NSError *error) {
        if (![self valid:generation uid:uid account:account]) { [self discard:generation]; return; }
        if (error) { [self finish:generation uid:uid events:@[] error:error]; return; }
        NSArray *profileEvents = [LDStore.shared applyProfile:profile forUID:uid];
        if (profileEvents.count && self.active && [LDStore.shared.options[@"alerts"] boolValue])
            [NSNotificationCenter.defaultCenter postNotificationName:LDMonitorAlert object:profileEvents];
        NSMutableArray *events = [NSMutableArray array];
        if (profile[@"likesVisible"] && ![profile[@"likesVisible"] boolValue]) {
            [LDStore.shared markLikesUnavailable:uid]; [self finish:generation uid:uid events:events error:nil]; return;
        }
        [self fetchLikes:profile cursor:@0 accumulated:[NSMutableArray array] pages:0 events:events generation:generation account:account];
    }];
}
- (void)fetchLikes:(NSDictionary *)profile cursor:(NSNumber *)cursor accumulated:(NSMutableArray *)videos
             pages:(NSUInteger)pages events:(NSMutableArray *)events generation:(NSUInteger)generation account:(NSString *)account {
    NSString *uid = profile[@"uid"];
    [LDApi likes:profile cursor:cursor owner:LDMonitorOwner completion:^(id page, NSError *error) {
        if (![self valid:generation uid:uid account:account]) { [self discard:generation]; return; }
        if (error) {
            [LDStore.shared updateTarget:uid values:@{@"likesStatus": @"喜欢列表暂不可读，已保留上次记录"}];
            [self finish:generation uid:uid events:events error:error]; return;
        }
        NSArray *items = page[@"videos"];
        if (!items.count && pages == 0 && (!profile[@"counts"][@"likes"] || [profile[@"counts"][@"likes"] longLongValue] > 0)) {
            [LDStore.shared markLikesUnavailable:uid]; [self finish:generation uid:uid events:events error:nil]; return;
        }
        NSMutableSet *collected = [NSMutableSet setWithArray:[videos valueForKey:@"id"]];
        for (NSDictionary *video in items) if (![collected containsObject:video[@"id"]]) { [videos addObject:video]; [collected addObject:video[@"id"]]; }
        NSDictionary *baseline = [LDStore.shared target:uid][@"likesBaseline"];
        NSSet *old = [NSSet setWithArray:baseline[@"head"] ?: @[]];
        BOOL overlap = [collected intersectsSet:old];
        BOOL more = [page[@"more"] boolValue];
        // One page normally. At most three pages to bridge a large burst of new likes.
        if (more && items.count && [baseline[@"valid"] boolValue] && !overlap && pages < 2 && videos.count < 90) {
            [self fetchLikes:profile cursor:page[@"cursor"] accumulated:videos pages:pages + 1 events:events generation:generation account:account]; return;
        }
        if (videos.count > 90) [videos removeObjectsInRange:NSMakeRange(90, videos.count - 90)];
        [events addObjectsFromArray:[LDStore.shared applyLikes:videos complete:!more forUID:uid]];
        [self finish:generation uid:uid events:events error:nil];
    }];
}
- (void)discard:(NSUInteger)generation {
    if (generation != self.generation) return;
    self.busy = NO; self.flightUID = nil; [self synchronizeAccount]; [self schedule]; [self notify];
}
- (void)finish:(NSUInteger)generation uid:(NSString *)uid events:(NSArray *)events error:(NSError *)error {
    if (generation != self.generation) return;
    self.failures[uid] = error ? @(MIN(8, [self.failures[uid] unsignedIntValue] + 1)) : @0;
    NSString *status = error ? [NSString stringWithFormat:@"%@（稍后重试）", error.localizedDescription] : @"检测完成";
    // Backoff starts after a failed request completes, preventing timeout retry loops.
    if (error) self.attempts[uid] = @(NSProcessInfo.processInfo.systemUptime);
    [LDStore.shared updateTarget:uid values:@{@"status": status}];
    self.busy = NO; self.flightUID = nil;
    if (events.count && self.active && [LDStore.shared.options[@"alerts"] boolValue])
        [NSNotificationCenter.defaultCenter postNotificationName:LDMonitorAlert object:events];
    [self schedule]; [self notify];
}
@end
