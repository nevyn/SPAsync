#import <SPAsync/SPAwait.h>
#import <SPAsync/SPAgent.h>
#import <SPAsync/SPTask.h>

@implementation SPAwaitCoroutine {
    void(^_body)(int resumeAt);
    SPTaskCompletionSource *_source;
    id _yieldedValue;
    BOOL _completed;
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
- (void)setBody:(void(^)(int resumeAt))body;
{
    _body = [body copy];
}

- (void)resumeAt:(int)line
{
    _body(line);
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

@end