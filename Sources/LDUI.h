#import <UIKit/UIKit.h>
#import "LDMonitor.h"
UIWindow *LDActiveWindow(void);
UIViewController *LDTopController(UIViewController *controller);
UIUserInterfaceStyle LDStyle(void);
UIColor *LDAccent(void);
UIColor *LDButtonColor(void);
UILabel *LDLabel(NSString *text, CGFloat size, UIFontWeight weight);
UIView *LDHeader(NSString *title, NSString *subtitle, NSString *symbol);
UITableViewCell *LDCell(NSString *title, NSString *subtitle, NSString *symbol, BOOL disclosure);
UITableViewCell *LDPersonCell(NSDictionary *person, NSString *subtitle, BOOL disclosure);
void LDToast(UIViewController *presenter, NSString *message);
void LDMessage(UIViewController *presenter, NSString *title, NSString *message);
void LDConfirm(UIViewController *presenter, NSString *title, NSString *message, NSString *button, dispatch_block_t action);
void LDSheet(UIViewController *presenter, NSString *title, NSArray<NSString *> *options, void (^chosen)(NSUInteger index));
void LDCopy(UIViewController *presenter, NSString *text);
void LDCopySignature(UIViewController *presenter, id signature);
void LDOpenVideo(UIViewController *presenter, NSString *videoID);
void LDOpenSettings(void);
void LDShowAbout(UIViewController *presenter);
@interface LDTableController : UITableViewController
- (void)refresh;
- (void)updateTheme;
- (BOOL)checkAccount:(NSString *)account;
@end
@interface LDSettingsController : LDTableController
@end
@interface LDPeoplePicker : LDTableController
@end
@interface LDHistoryController : LDTableController
@property(nonatomic, copy) NSString *personID;
@end
@interface LDPersonController : LDTableController
@property(nonatomic, copy) NSString *personID;
@end
@interface LDRecordController : LDTableController
@property(nonatomic, copy) NSDictionary *record;
@end
void LDShowNotice(NSArray<NSDictionary *> *events);
void LDDismissNotice(void);
