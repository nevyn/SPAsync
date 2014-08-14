#import <SPAsync/SPAwait.h>
#import <SPAsync/SPAgent.h>
#import <SPAsync/SPTask.h>

@implementation SPAwaitCoroutine {
    SPAwaitCoroutineBody _body;
    SPTaskCompletionSource *_source;
    id _yieldedValue;
    BOOL _completed;
	jmp_buf _resumeAt;
}
- (id)init
{
    if(!(self = [super init]))
        return nil;
    _source = [SPTaskCompletionSource new];
    
    // We need to live until the coroutine is complete
    CFRetain((__bridge CFTypeRef)(self));
    
    return self;
}
- (void)setBody:(SPAwaitCoroutineBody)body;
{
    _body = [body copy];
}

- (id)await:(SPTask*)awaitable
{
	__weak typeof(self) weakSelf = self;
	[awaitable addCallback:^(id value) {
		weakSelf.lastAwaitedValue = value;
		[weakSelf resume];
	} on:[weakSelf queueFor:self]];
	
	self.needsResuming = YES;
	if(setjmp(*self.resumeAt) == 0)
		return [SPAwaitCoroutine awaitSentinel];
	
	return self.lastAwaitedValue;
}

- (void)resume
{
    id ret = _body();
    if(ret == [SPAwaitCoroutine awaitSentinel])
        return;
    
    _yieldedValue = ret;
    [self finish];
}

+ (id)awaitSentinel
{
    static id sentinel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sentinel = [NSObject new];
    });
    return sentinel;
}

- (void)finish
{
    NSAssert(!_completed, @"Didn't expect to complete twice");
    _completed = YES;
    [_source completeWithValue:_yieldedValue];
    
    // The coroutine is complete. We can remove it now.
    CFRelease((__bridge CFTypeRef)(self));
}

- (void)yieldValue:(id)value
{
    _yieldedValue = value;
}

- (SPTask*)task
{
    return _source.task;
}

- (dispatch_queue_t)queueFor:(id)object
{
    if([NSRunLoop currentRunLoop] == [NSRunLoop mainRunLoop])
        return dispatch_get_main_queue();
    if([object respondsToSelector:@selector(workQueue)])
        return [object workQueue];
    return dispatch_get_global_queue(0, 0);
}

- (jmp_buf*)resumeAt
{
	return &_resumeAt;
}

@end