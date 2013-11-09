#import <UIKit/UIKit.h>
@class SPTask;

@interface UIScrollView (SPAsyncAnimation)
- (SPTask*)task_setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
@end