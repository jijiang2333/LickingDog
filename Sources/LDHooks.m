#import "LDUI.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <stdatomic.h>
static void LDInstallEntry(void) {
    static BOOL installed; if (installed) return;
    Class cls = NSClassFromString(@"AWESettingsViewModel");
    Class itemClass = NSClassFromString(@"AWESettingItemModel"), sectionClass = NSClassFromString(@"AWESettingSectionModel");
    SEL sel = NSSelectorFromString(@"sectionDataArray"); Method method = class_getInstanceMethod(cls, sel);
    if (!method || !itemClass || !sectionClass) return;
    NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (s.numberOfArguments != 2 || s.methodReturnType[0] != '@') return;
    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(^id(id owner) {
        id sections = ((id (*)(id, SEL))original)(owner, sel);
        if (![sections isKindOfClass:NSArray.class]) return sections;
        Class page = NSClassFromString(@"AWESettingsTableViewController");
        id delegate = LDRead(owner, @"controllerDelegate");
        if (!page || ![delegate isKindOfClass:page]) return sections;
        if ([LDRead(delegate, @"onSearchStatus") boolValue]) return sections;
        for (id section in sections) {
            id items = LDRead(section, @"itemArray"); if (![items isKindOfClass:NSArray.class]) continue;
            for (id item in items) if ([LDRead(item, @"identifier") isEqual:@"LickingDog.Settings"]) return sections;
        }
        id item = [itemClass new];
        BOOL valid = LDSet(item, @"identifier", @"LickingDog.Settings");
        valid &= LDSet(item, @"title", LDName); valid &= LDSet(item, @"cellType", @26);
        valid &= LDSet(item, @"cellTappedBlock", ^{ LDOpenSettings(); });
        LDSet(item, @"detail", LDVersion); LDSet(item, @"isEnable", @YES); LDSet(item, @"colorStyle", @2);
        LDSet(item, @"svgIconImageName", @"ic_gearsimplify_outlined_20");
        LDSet(item, @"specificIconImage", [UIImage systemImageNamed:@"heart.circle"]);
        id section = [sectionClass new]; valid &= LDSet(section, @"itemArray", @[item]); LDSet(section, @"sectionHeaderHeight", @16);
        if (!valid) return sections;
        NSMutableArray *copy = [sections mutableCopy]; [copy insertObject:section atIndex:0]; return copy;
    });
    class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(method)); installed = YES;
}
static void LDThemeNotification(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:LDThemeChanged object:nil]; });
}
static void LDInstallTheme(void) {
    static BOOL installed[3];
    NSArray *selectors = @[@"changeThemeStyleLightModeEnable:", @"setLightMode:", @"setThemeStyle:"];
    for (NSUInteger i = 0; i < 3; i++) {
        if (installed[i]) continue;
        Class cls = NSClassFromString(i == 2 ? @"AWEThemeManager" : @"AWESettingThemeManager");
        if (i == 2) cls = object_getClass(cls);
        SEL sel = NSSelectorFromString(selectors[i]); Method method = class_getInstanceMethod(cls, sel); if (!method) continue;
        NSMethodSignature *s = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        if (s.methodReturnType[0] != 'v' || s.numberOfArguments != 3 || [s getArgumentTypeAtIndex:2][0] != (i == 2 ? 'Q' : 'B')) continue;
        IMP original = method_getImplementation(method), replacement;
        if (i == 2) replacement = imp_implementationWithBlock(^(id owner, unsigned long long style) { ((void (*)(id, SEL, unsigned long long))original)(owner, sel, style); LDThemeNotification(); });
        else replacement = imp_implementationWithBlock(^(id owner, BOOL light) { ((void (*)(id, SEL, BOOL))original)(owner, sel, light); LDThemeNotification(); });
        class_replaceMethod(cls, sel, replacement, method_getTypeEncoding(method)); installed[i] = YES;
    }
}
static void LDInstall(void) {
    LDInstallEntry(); LDInstallTheme(); [LDMonitor.shared start];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:LDMonitorAlert object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { LDShowNotice(note.object); }];
    });
}
static atomic_bool LDScheduled;
static void LDImageLoaded(const struct mach_header *header, intptr_t slide) {
    if (atomic_exchange(&LDScheduled, true)) return;
    dispatch_async(dispatch_get_main_queue(), ^{ atomic_store(&LDScheduled, false); LDInstall(); });
}
__attribute__((constructor)) static void LDStart(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.ss.iphone.ugc.Aweme"]) return;
        _dyld_register_func_for_add_image(LDImageLoaded);
    }
}
