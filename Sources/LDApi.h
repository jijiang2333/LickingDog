#import "LDNetwork.h"
NS_ASSUME_NONNULL_BEGIN
@interface LDApi : NSObject
+ (void)profile:(NSDictionary *)target owner:(NSString *)owner completion:(LDReply)completion;
+ (void)resolveHandle:(NSString *)handle owner:(NSString *)owner completion:(LDReply)completion;
+ (void)friendsForOwner:(NSString *)owner completion:(LDReply)completion;
+ (void)likes:(NSDictionary *)target cursor:(NSNumber *)cursor owner:(NSString *)owner completion:(LDReply)completion;
@end
NS_ASSUME_NONNULL_END
