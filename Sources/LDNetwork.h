#import "LDModel.h"
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^LDReply)(id _Nullable value, NSError * _Nullable error);
typedef BOOL (^LDIsCurrent)(void);
// Starts on main; returns cancellation for this operation only (never a shared host service).
typedef dispatch_block_t _Nullable (^LDStartOperation)(LDReply reply, LDIsCurrent isCurrent);
NSString *LDCurrentAccount(void);
NSString *LDDiagnosticText(NSError *error);
@interface LDNetwork : NSObject
+ (instancetype)shared;
- (void)get:(NSString *)url parameters:(NSDictionary *)parameters owner:(NSString *)owner completion:(LDReply)completion;
- (void)perform:(NSString *)stage owner:(NSString *)owner start:(LDStartOperation)start completion:(LDReply)completion;
- (void)cancelOwner:(NSString *)owner;
- (void)cancelAll;
@end
NS_ASSUME_NONNULL_END
