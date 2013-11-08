#import <UIKit/UIKit.h>
@class SPTask;

@interface UIView (SPAsyncAnimation)
+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations;
+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations;
@end