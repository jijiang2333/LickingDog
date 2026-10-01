#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
extern NSString *const LDVersion;
extern NSString *const LDName;
extern NSNotificationName const LDStoreChanged;
extern NSNotificationName const LDThemeChanged;
id _Nullable LDRead(id _Nullable object, NSString *key);
id _Nullable LDFirst(id _Nullable object, NSArray<NSString *> *keys);
NSString *LDString(id _Nullable value);
NSNumber * _Nullable LDCount(id _Nullable value);
BOOL LDIdentifier(id _Nullable value);
BOOL LDSet(id _Nullable object, NSString *key, id _Nullable value);
BOOL LDHasMethod(id _Nullable receiver, NSString *selector, const char *returns, const char *arguments);
id _Nullable LDCall(id _Nullable receiver, NSString *selector, NSArray *arguments);
NSDictionary * _Nullable LDProfile(id _Nullable value);
extern NSUInteger const LDSignatureLimit;
NSString *LDSignatureText(id _Nullable value);
NSDictionary * _Nullable LDVideo(id _Nullable value);
NSArray<NSDictionary *> *LDChanges(NSDictionary *previous, NSDictionary *current);
NSDictionary *LDCompareLikes(NSDictionary * _Nullable previous, NSArray<NSDictionary *> *videos, BOOL complete);
NSString *LDMetricName(NSString *key);
NSString *LDDisplayName(NSDictionary *person);
NSString *LDPersonSearchText(NSDictionary *person);
NSString *LDDateText(NSTimeInterval timestamp);
NSError *LDError(NSInteger code, NSString *message);
NS_ASSUME_NONNULL_END
