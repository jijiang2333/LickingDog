#import "LDStore.h"
NS_ASSUME_NONNULL_BEGIN
extern NSNotificationName const LDMonitorStatusChanged;
extern NSNotificationName const LDMonitorAlert;
@interface LDMonitor : NSObject
+ (instancetype)shared;
@property(nonatomic, readonly) BOOL busy;
@property(nonatomic, readonly, copy) NSString *status;
- (void)start;
- (void)synchronizeAccount;
- (void)checkNow;
- (void)invalidateTarget:(NSString *)uid;
@end
NS_ASSUME_NONNULL_END
