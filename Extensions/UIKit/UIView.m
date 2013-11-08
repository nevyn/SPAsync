#import <SPAsync/UIKit/UIView.h>
#import <SPAsync/SPTask.h>

@implementation UIView (SPAsyncAnimation)
+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [self animateWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
        [source completeWithValue:@(finished)];
    }];
    return source.task;
}

+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [self animateWithDuration:duration animations:animations completion:^(BOOL finished) {
        [source completeWithValue:@(finished)];
    }];
    return source.task;

}

+ (SPTask*)task_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [self animateWithDuration:duration delay:delay usingSpringWithDamping:dampingRatio initialSpringVelocity:velocity options:options animations:animations completion:^(BOOL finished) {
        [source completeWithValue:@(finished)];
    }];
    return source.task;
}
@end