#import <SPAsync/UIKit/UIView.h>
#import <SPAsync/SPTask.h>
#import <objc/runtime.h>

@interface SPAsyncScrollViewClosure : NSObject <UIScrollViewDelegate>
@property(nonatomic) SPTaskCompletionSource *source;
@property(nonatomic,weak) id<UIScrollViewDelegate> oldDelegate;
@end

@implementation UIScrollView (SPAsyncAnimation)
static const void *scrollClosureKey = &scrollClosureKey;
- (SPTask*)task_setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if(!animated) {
        [self setContentOffset:contentOffset animated:NO];
        return [SPTask delay:0];
    } else {
        SPAsyncScrollViewClosure *closure = [SPAsyncScrollViewClosure new];
        closure.source = [SPTaskCompletionSource new];
        closure.oldDelegate = self.delegate;
        objc_setAssociatedObject(self, scrollClosureKey, closure, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.delegate = closure;
        [self setContentOffset:contentOffset animated:YES];
        
        return closure.source.task;
    }
}
@end

@implementation SPAsyncScrollViewClosure
- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] || [self.oldDelegate respondsToSelector:aSelector];
}
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return self.oldDelegate;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    scrollView.delegate = self.oldDelegate;
    if([self.oldDelegate respondsToSelector:_cmd])
        [self.oldDelegate scrollViewDidEndScrollingAnimation:scrollView];
    [self.source completeWithValue:nil];
    objc_setAssociatedObject(scrollView, scrollClosureKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end