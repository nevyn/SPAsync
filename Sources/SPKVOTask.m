#import "SPKVOTask.h"

static void *kContext = &kContext;

@interface SPA_NS(KVOTaskContainer) : NSObject
@property(nonatomic) SPA_NS(TaskCompletionSource) *source;
@property(nonatomic) id value;
@end

@implementation SPA_NS(KVOTask)
+ (id)awaitValue:(id)value onObject:(id)object forKeyPath:(NSString*)keyPath
{
	SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
	SPA_NS(KVOTaskContainer) *container = [SPA_NS(KVOTaskContainer) new]; // owned by the task
	container.source = source;
	
	container.value = value;
	[source.task addFinallyCallback:^(BOOL cancelled) {
		[object removeObserver:container forKeyPath:keyPath context:kContext];
	}];
	[object addObserver:container forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:kContext];
	return (id)source.task;
}
@end
@implementation SPA_NS(KVOTaskContainer)
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context != kContext)
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	
	id newValue = [object valueForKeyPath:keyPath];
	if([newValue isEqual:self.value])
		[self.source completeWithValue:newValue];
}
@end
