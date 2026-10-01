#import "LDApi.h"
@protocol LDHostListInitializer <NSObject>
- (instancetype)initWithUserID:(NSString *)uid;
@end
static id LDLikesManager(NSString *uid) {
    id<LDHostListInitializer> allocated = [NSClassFromString(@"AWEUserLikesDataManager") alloc];
    if (!LDHasMethod(allocated, @"initWithUserID:", "@", "@")) return nil;
    @try { return [allocated initWithUserID:uid]; } @catch (__unused NSException *exception) { return nil; }
}
static NSString *LDOrigin(id raw) {
    NSString *value = [raw isKindOfClass:NSURL.class] ? [raw absoluteString] : LDString(raw);
    if (!value.length || [value hasPrefix:@"/"]) return nil;
    if (![value containsString:@"://"]) value = [@"https://" stringByAppendingString:value];
    NSURLComponents *parts = [NSURLComponents componentsWithString:value];
    if (![parts.scheme isEqualToString:@"https"] || !parts.host.length || parts.user || parts.password) return nil;
    parts.path = @""; parts.query = nil; parts.fragment = nil;
    return parts.string;
}
static NSString *LDApiURL(NSString *path) {
    Class domain = NSClassFromString(@"NetworkProviderDomain");
    NSString *origin = LDOrigin(LDCall(domain, @"apiDomain", @[])) ?: LDOrigin(LDCall(domain, @"apiHost", @[]));
    // Fall back to the favorite endpoint when the host exposes no API domain.
    if (!origin) origin = LDOrigin(LDCall(LDLikesManager(LDCurrentAccount()), @"likeRequestURL", @[]));
    return [(origin ?: @"https://aweme.snssdk.com") stringByAppendingString:path];
}
static NSString *LDNativeURL(id raw, NSString *fallbackPath) {
    NSString *value = [raw isKindOfClass:NSURL.class] ? [raw absoluteString] : LDString(raw);
    NSURL *url = [NSURL URLWithString:value];
    if ([url.scheme isEqualToString:@"https"] && url.host.length) return value;
    return LDApiURL([value hasPrefix:@"/aweme/"] ? value : fallbackPath);
}
static NSDictionary *LDPayload(id value) {
    if (![value isKindOfClass:NSDictionary.class]) return nil;
    return [value[@"data"] isKindOfClass:NSDictionary.class] ? value[@"data"] : value;
}
static BOOL LDHandleMatches(NSDictionary *profile, NSString *handle) {
    NSString *actual = LDString(profile[@"handle"]);
    return actual.length && [actual caseInsensitiveCompare:handle] == NSOrderedSame;
}
// Search results may contain userInfo models or dictionary wrappers.
static void LDSearchMatches(id object, NSString *handle, NSMutableDictionary *matches, NSUInteger depth, NSUInteger *budget, NSUInteger *recognized) {
    if (!object || depth > 7 || !*budget) return;
    (*budget)--;
    if ([object isKindOfClass:NSArray.class]) {
        for (id item in object) { if (!*budget) break; LDSearchMatches(item, handle, matches, depth + 1, budget, recognized); }
        return;
    }
    NSDictionary *profile = LDProfile(object);
    if (profile) (*recognized)++;
    if (profile && LDHandleMatches(profile, handle)) matches[profile[@"uid"]] = profile;
    for (NSString *key in @[@"user_list", @"users", @"user_info", @"userInfo", @"user", @"data", @"items"]) {
        if (!*budget) break;
        LDSearchMatches(LDRead(object, key), handle, matches, depth + 1, budget, recognized);
    }
}
static id LDContactDatabase(void) {
    Class cls = NSClassFromString(@"AWEIMUserDBManager");
    for (NSString *selector in @[@"sharedInstance", @"defaultManager", @"manager"]) {
        id manager = LDCall(cls, selector, @[]); if (manager) return manager;
    }
    id center = LDCall(NSClassFromString(@"HTSServiceCenter"), @"defaultCenter", @[]);
    id manager = cls ? LDCall(center, @"getService:", @[cls]) : nil;
    if (!manager) { @try { manager = [cls new]; } @catch (__unused NSException *exception) { } }
    return manager;
}
static NSArray *LDLocalContacts(id database) {
    // Synchronous database reads run off the main thread.
    id value = LDCall(database, @"localContactList", @[]);
    NSArray *empty = [value isKindOfClass:NSArray.class] ? value : nil;
    if (empty.count) return [empty copy];
    if (LDHasMethod(database, @"localContactListWithReadScene:", "@", "q")) {
        for (NSInteger scene = 0; scene <= 6; scene++) {
            value = LDCall(database, @"localContactListWithReadScene:", @[@(scene)]);
            if ([value isKindOfClass:NSArray.class]) { empty = value; if (empty.count) return [empty copy]; }
        }
    }
    return empty;
}
static NSArray *LDFollowedContacts(id database) {
    if (!LDHasMethod(database, @"fetchFriendAndFollowedUsersWithLimits:readScene:", "@", "qq")) return nil;
    NSArray *empty;
    for (NSNumber *limit in @[@10000, @5000, @2000]) for (NSNumber *scene in @[@0, @1]) {
        id value = LDCall(database, @"fetchFriendAndFollowedUsersWithLimits:readScene:", @[limit, scene]);
        if ([value isKindOfClass:NSArray.class]) { empty = value; if (empty.count) return [empty copy]; }
    }
    return empty;
}
static NSDictionary *LDContactPage(NSArray *contacts, NSString *account) {
    NSMutableArray *all = [NSMutableArray array], *friends = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id user in contacts) {
        NSDictionary *profile = LDProfile(user);
        if (!profile || [profile[@"uid"] isEqual:account] || [seen containsObject:profile[@"uid"]]) continue;
        if ([LDCount(LDRead(user, @"blockStatus")) boolValue]) continue;
        [seen addObject:profile[@"uid"]]; [all addObject:profile];
        // Mutual follow requires followStatus=2 and followerStatus=1.
        if ([LDCount(LDRead(user, @"followStatus")) integerValue] == 2 &&
            [LDCount(LDRead(user, @"followerStatus")) integerValue] == 1) [friends addObject:profile];
    }
    return @{@"contacts": all, @"users": friends};
}
static void LDLoadContacts(NSString *owner, LDReply completion) {
    [LDNetwork.shared perform:@"AWEIMUserDBManager.localContactList" owner:owner start:^dispatch_block_t(LDReply reply, LDIsCurrent current) {
        id database = LDContactDatabase();
        if (!database) { reply(nil, LDError(503, @"当前抖音版本的联系人服务不可用，请复制诊断。")); return nil; }
        NSString *account = LDCurrentAccount();
        // The contact callback takes a single array argument.
        void (^finishRead)(id) = ^(id raw) {
            NSArray *snapshot = [raw isKindOfClass:NSArray.class] ? [raw copy] : nil;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSArray *contacts = snapshot.count ? snapshot : (LDFollowedContacts(database) ?: snapshot);
                NSDictionary *page = contacts ? LDContactPage(contacts, account) : nil;
                reply(page, page ? nil : LDError(502, @"联系人尚未就绪，可先打开抖音消息页，再返回刷新。"));
            });
        };
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSArray *local = LDLocalContacts(database);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!current()) { reply(nil, LDError(-999, @"联系人读取已暂停。")); return; }
                if (local.count) { finishRead(local); return; }
                if (LDHasMethod(database, @"localContactListWithReadScene:completion:", "v", "q@")) {
                    LDCall(database, @"localContactListWithReadScene:completion:", @[@0, [^(id contacts) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (!current()) { reply(nil, LDError(-999, @"联系人读取已暂停。")); return; }
                            finishRead(contacts ?: local);
                        });
                    } copy]]);
                } else finishRead(local);
            });
        });
        // Cancellation must not affect the host's shared database service.
        return nil;
    } completion:completion];
}
@implementation LDApi
+ (void)profile:(NSDictionary *)target owner:(NSString *)owner completion:(LDReply)completion {
    if (!LDIdentifier(target[@"uid"])) { completion(nil, LDError(400, @"账号标识无效，请重新添加。")); return; }
    NSMutableDictionary *params = [@{@"user_id": target[@"uid"], @"source": @"other_profile"} mutableCopy];
    if (LDString(target[@"secUID"]).length) params[@"sec_user_id"] = target[@"secUID"];
    [LDNetwork.shared get:LDApiURL(@"/aweme/v1/user/profile/other/") parameters:params owner:owner completion:^(id value, NSError *error) {
        NSDictionary *profile = error ? nil : LDProfile(LDPayload(value));
        if (!error && (!profile || ![profile[@"uid"] isEqual:target[@"uid"]])) error = LDError(502, @"资料返回不完整，本次数值已忽略。");
        if (!error && !LDString(profile[@"secUID"]).length && LDString(target[@"secUID"]).length) {
            NSMutableDictionary *merged = [profile mutableCopy]; merged[@"secUID"] = target[@"secUID"]; profile = merged;
        }
        completion(profile, error);
    }];
}
+ (void)resolveHandle:(NSString *)handle owner:(NSString *)owner completion:(LDReply)completion {
    NSString *clean = [handle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([clean hasPrefix:@"@"]) clean = [clean substringFromIndex:1];
    if (!clean.length || clean.length > 64 || [clean rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) {
        completion(nil, LDError(400, @"请输入主页显示的完整抖音号，不是昵称。")); return;
    }
    LDLoadContacts(owner, ^(id page, NSError *error) {
        if (error.code == NSURLErrorCancelled || error.code == 401) { completion(nil, error); return; }
        NSMutableDictionary *matches = [NSMutableDictionary dictionary];
        for (NSDictionary *profile in page[@"contacts"]) if (LDHandleMatches(profile, clean)) matches[profile[@"uid"]] = profile;
        if (matches.count == 1) { completion(matches.allValues.firstObject, nil); return; }
        id manager;
        @try { manager = [NSClassFromString(@"AWESearchUserManager") new]; } @catch (__unused NSException *exception) { }
        [self searchHandle:clean manager:manager page:0 owner:owner completion:completion];
    });
}
+ (void)searchHandle:(NSString *)handle manager:(id)manager page:(NSUInteger)page owner:(NSString *)owner completion:(LDReply)completion {
    NSNumber *previousCursor = LDCount(LDRead(manager, @"cursor")) ?: @0;
    [LDNetwork.shared perform:@"AWESearchUserManager.fetchUsersWithKeyword" owner:owner start:^dispatch_block_t(LDReply reply, LDIsCurrent current) {
        NSString *selector = @"fetchUsersWithKeyword:cursor:isPullToRefresh:completion:";
        BOOL compatible = LDHasMethod(manager, selector, "v", "@@B@") || LDHasMethod(manager, selector, "v", "@@c@");
        if (!compatible) { reply(nil, LDError(503, @"当前版本的抖音用户搜索入口不可用，请复制诊断。")); return nil; }
        if (!page) {
            LDSet(manager, @"count", @20); LDSet(manager, @"cursor", @0);
            LDSet(manager, @"searchSource", @"normal_search"); LDSet(manager, @"initialSearchSource", @"normal_search");
        }
        __weak id weakManager = manager;
        // Fetch returns (NSArray *, NSError *); userArray contains layout models.
        void (^ready)(NSArray *, NSError *) = ^(NSArray *users, NSError *error) {
            NSArray *snapshot = [users isKindOfClass:NSArray.class] ? [users copy] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!current()) { reply(nil, LDError(-999, @"用户搜索已暂停。")); return; }
                if (error) { reply(nil, error); return; }
                if (!snapshot) { reply(nil, LDError(502, @"抖音搜索返回的用户资料格式不可识别，请复制诊断。")); return; }
                NSMutableDictionary *matches = [NSMutableDictionary dictionary]; NSUInteger budget = 800, recognized = 0;
                LDSearchMatches(snapshot, handle, matches, 0, &budget, &recognized);
                if (matches.count > 1) { reply(nil, LDError(409, @"返回多个同号结果，请核对完整抖音号。")); return; }
                NSDictionary *profile = matches.allValues.firstObject;
                id live = weakManager;
                reply(@{@"profile": profile ?: @{}, @"count": @(recognized), @"rawCount": @(snapshot.count),
                    @"more": @([LDRead(live, @"hasMore") boolValue]), @"cursor": LDCount(LDRead(live, @"cursor")) ?: @0}, nil);
            });
        };
        LDCall(manager, selector, @[handle, previousCursor, @(page == 0), ready]);
        return ^{ LDCall(LDRead(manager, @"task"), @"cancel", @[]); };
    } completion:^(id result, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSDictionary *profile = result[@"profile"];
        if (LDIdentifier(profile[@"uid"])) { completion(profile, nil); return; }
        if (page < 2 && [result[@"more"] boolValue] && [result[@"cursor"] longLongValue] > previousCursor.longLongValue) {
            [self searchHandle:handle manager:manager page:page + 1 owner:owner completion:completion]; return;
        }
        // Empty callbacks do not distinguish missing users from search failures.
        NSError *failure = LDError([result[@"count"] unsignedIntegerValue] ? 404 : 502,
            [result[@"count"] unsignedIntegerValue] ? @"搜索结果中未匹配到完整抖音号，请从对方主页复制后重试。" :
            @"抖音用户搜索暂未返回可核对的账号，请确认抖音搜索可用后重试。也可以复制诊断反馈。" );
        NSMutableDictionary *info = [failure.userInfo mutableCopy]; info[@"LickingDogEndpoint"] = @"AWESearchUserManager.fetchUsersWithKeyword.result";
        completion(nil, [NSError errorWithDomain:failure.domain code:failure.code userInfo:info]);
    }];
}
+ (void)friendsForOwner:(NSString *)owner completion:(LDReply)completion {
    LDLoadContacts(owner, ^(id page, NSError *error) { completion(error ? nil : page[@"users"], error); });
}
+ (void)likes:(NSDictionary *)target cursor:(NSNumber *)cursor owner:(NSString *)owner completion:(LDReply)completion {
    if (!LDIdentifier(target[@"uid"])) { completion(nil, LDError(400, @"账号标识无效，请重新添加。")); return; }
    id manager = LDLikesManager(target[@"uid"]);
    LDSet(manager, @"pageSize", @30); LDSet(manager, @"count", @30);
    LDSet(manager, @"maxCursor", cursor); LDSet(manager, @"minCursor", @0);
    NSString *url = LDNativeURL(LDCall(manager, @"likeRequestURL", @[]), @"/aweme/v1/aweme/favorite/");
    id native = LDCall(manager, @"paramsIsRefresh:", @[@(cursor.longLongValue == 0)]);
    NSMutableDictionary *params = [native isKindOfClass:NSDictionary.class] ? [native mutableCopy] : [NSMutableDictionary dictionary];
    params[@"user_id"] = target[@"uid"]; params[@"count"] = @30; params[@"max_cursor"] = cursor; params[@"min_cursor"] = @0;
    if (LDString(target[@"secUID"]).length) params[@"sec_user_id"] = target[@"secUID"];
    [LDNetwork.shared get:url parameters:params owner:owner completion:^(id value, NSError *error) {
        NSDictionary *payload = LDPayload(value);
        id list = LDFirst(payload, @[@"aweme_list", @"awemes"]);
        if (error || ![list isKindOfClass:NSArray.class]) { completion(nil, error ?: LDError(502, @"喜欢列表暂不可读，保留上次记录。")); return; }
        NSMutableArray *videos = [NSMutableArray array]; NSMutableSet *ids = [NSMutableSet set];
        for (id raw in list) {
            NSDictionary *video = LDVideo(raw);
            if (!video) { completion(nil, LDError(502, @"喜欢作品资料不完整，保留上次基线。")); return; }
            if (![ids containsObject:video[@"id"]]) { [ids addObject:video[@"id"]]; [videos addObject:video]; }
        }
        NSNumber *next = LDCount(payload[@"max_cursor"]), *hasMore = LDCount(payload[@"has_more"]);
        if (!hasMore || (hasMore.boolValue && (!next || [next isEqual:cursor]))) {
            completion(nil, LDError(502, @"喜欢列表分页暂不可用，保留上次基线。")); return;
        }
        completion(@{@"videos": videos, @"cursor": next ?: cursor, @"more": @(hasMore.boolValue)}, nil);
    }];
}
@end
