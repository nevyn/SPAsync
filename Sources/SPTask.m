//
//  SPTask.m
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import <SPAsync/SPTask.h>

@interface SPA_NS(Task) ()
{
    NSMutableArray *_callbacks;
    NSMutableArray *_errbacks;
    NSMutableArray *_finallys;
    NSMutableArray *_childTasks;
    BOOL _isCompleted;
	BOOL _isCancelled;
    id _completedValue;
    NSError *_completedError;
    __weak SPA_NS(TaskCompletionSource) *_source;
}
@property(getter=isCancelled,readwrite) BOOL cancelled;
@end

@interface SPA_NS(TaskCompletionSource) ()
- (void)cancel;
@end

@implementation SPA_NS(Task)
@synthesize cancelled = _isCancelled;

- (id)initFromSource:(SPA_NS(TaskCompletionSource)*)source;
{
    if(!(self = [super init]))
        return nil;
    _callbacks = [NSMutableArray new];
    _errbacks = [NSMutableArray new];
    _finallys = [NSMutableArray new];
    _childTasks = [NSMutableArray new];
    _source = source;
    return self;
}

- (instancetype)addCallback:(SPTaskCallback)callback on:(dispatch_queue_t)queue
{
    @synchronized(_callbacks) {
        if(_isCompleted) {
            if(!_completedError) {
                dispatch_async(queue, ^{
                    callback(_completedValue);
                });
            }
        } else {
            [_callbacks addObject:[[SPA_NS(CallbackHolder) alloc] initWithCallback:callback onQueue:queue]];
        }
    }
    return self;
}

- (instancetype)addCallback:(SPTaskCallback)callback
{
    return [self addCallback:callback on:dispatch_get_main_queue()];
}

- (instancetype)addErrorCallback:(SPTaskErrback)errback on:(dispatch_queue_t)queue
{
    @synchronized(_callbacks) {
        if(_isCompleted) {
            if(_completedError) {
                dispatch_async(queue, ^{
                    errback(_completedError);
                });
            }
        } else {
            [_errbacks addObject:[[SPA_NS(CallbackHolder) alloc] initWithCallback:errback onQueue:queue]];
        }
    }
    return self;
}

- (instancetype)addErrorCallback:(SPTaskErrback)errback
{
    return [self addErrorCallback:errback on:dispatch_get_main_queue()];
}

- (instancetype)addFinallyCallback:(SPTaskFinally)finally on:(dispatch_queue_t)queue
{
    @synchronized(_callbacks) {
        if(_isCompleted) {
            dispatch_async(queue, ^{
                finally(_isCancelled);
            });
        } else {
            [_finallys addObject:[[SPA_NS(CallbackHolder) alloc] initWithCallback:(id)finally onQueue:queue]];
        }
    }
    return self;
}
    
    
- (instancetype)addFinallyCallback:(SPTaskFinally)finally
{
    return [self addFinallyCallback:finally on:dispatch_get_main_queue()];
}

+ (instancetype)awaitAll:(NSArray*)tasks
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
		
	if([tasks count] == 0) {
		[source completeWithValue:@[]];
			return source.task;
	}
    
    NSMutableArray *values = [NSMutableArray new];
    NSMutableSet *remainingTasks = [NSMutableSet setWithArray:tasks];
    
    int i = 0;
    for(SPA_NS(Task) *task in tasks) {
        [source.task->_childTasks addObject:task];
        
        __weak SPA_NS(Task) *weakTask = task;
        
        [values addObject:[NSNull null]];
        [[[task addCallback:^(id value) {
            if(value)
                [values replaceObjectAtIndex:i withObject:value];
            
            [remainingTasks removeObject:weakTask];
            if([remainingTasks count] == 0)
                [source completeWithValue:values];
        } on:dispatch_get_main_queue()] addErrorCallback:^(NSError *error) {
            if ([remainingTasks count] == 0) {
                return;
            }
            
            [remainingTasks removeObject:weakTask];
            [source failWithError:error];
            
            [remainingTasks makeObjectsPerformSelector:@selector(cancel)];
            [remainingTasks removeAllObjects];
            [values removeAllObjects];
        } on:dispatch_get_main_queue()] addFinallyCallback:^(BOOL canceled) {
            if(canceled) {
                [source.task cancel];
            }
        } on:dispatch_get_main_queue()];
        
        i++;
    }
    return source.task;
}

- (void)completeWithValue:(id)value
{
    NSAssert(!_isCompleted, @"Can't complete a task twice");
    if(_isCompleted)
        return;
    
    if(self.cancelled)
        return;
    
    NSArray *callbacks = nil;
    NSArray *finallys = nil;
    @synchronized(_callbacks) {
        _isCompleted = YES;
        _completedValue = value;
        callbacks = [_callbacks copy];
        finallys = [_finallys copy];
    
        for(SPA_NS(CallbackHolder) *holder in callbacks) {
            dispatch_async(holder.callbackQueue, ^{
                if(self.cancelled)
                    return;
                
                holder.callback(value);
            });
        }
        
        for(SPA_NS(CallbackHolder) *holder in finallys) {
            dispatch_async(holder.callbackQueue, ^{
                ((SPTaskFinally)holder.callback)(self.cancelled);
            });
        }
        
        [_callbacks removeAllObjects];
        [_errbacks removeAllObjects];
        [_finallys removeAllObjects];
    }
}

- (void)failWithError:(NSError*)error
{
    NSAssert(!_isCompleted, @"Can't complete a task twice");
    if(_isCompleted)
        return;
    
    if(self.cancelled)
        return;

    NSArray *errbacks = nil;
    NSArray *finallys = nil;
    @synchronized(_callbacks) {
        _isCompleted = YES;
        _completedError = error;
        errbacks = [_errbacks copy];
        finallys = [_finallys copy];
        
        for(SPA_NS(CallbackHolder) *holder in errbacks) {
            dispatch_async(holder.callbackQueue, ^{
                holder.callback(error);
            });
        }
        
        for(SPA_NS(CallbackHolder) *holder in finallys) {
            dispatch_async(holder.callbackQueue, ^{
                ((SPTaskFinally)holder.callback)(self.cancelled);
            });
        }

        
        [_callbacks removeAllObjects];
        [_errbacks removeAllObjects];
		[_finallys removeAllObjects];
    }
}
@end

@implementation SPA_NS(Task) (SPTaskCancellation)
@dynamic cancelled; // provided in main implementation block as a synthesize

- (void)cancel
{
    BOOL shouldCancel = NO;
    @synchronized(self) {
        shouldCancel = !self.cancelled;
        self.cancelled = YES;
    }
    
    if(shouldCancel) {
        [_source cancel];
        // break any circular references between source<> task by removing
        // callbacks and errbacks which might reference the source
        @synchronized(_callbacks) {
            [_callbacks removeAllObjects];
            [_errbacks removeAllObjects];
            
            for(SPA_NS(CallbackHolder) *holder in _finallys) {
                dispatch_async(holder.callbackQueue, ^{
                    ((SPTaskFinally)holder.callback)(YES);
                });
            }
            
            [_finallys removeAllObjects];
        }
    }
    
    for(SPA_NS(Task) *child in _childTasks)
        [child cancel];
}
@end

@implementation SPA_NS(Task) (SPTaskExtended)
- (instancetype)then:(SPTaskThenCallback)worker on:(dispatch_queue_t)queue
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
    SPA_NS(Task) *then = source.task;
    [_childTasks addObject:then];
    
    [self addCallback:^(id value) {
        id result = worker(value);
        [source completeWithValue:result];
    } on:queue];
    [self addErrorCallback:^(NSError *error) {
        [source failWithError:error];
    } on:queue];

    return then;
}
    
- (instancetype)chain:(SPTaskChainCallback)chainer on:(dispatch_queue_t)queue
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
    SPA_NS(Task) *chain = source.task;
    [_childTasks addObject:chain];
    
    [self addCallback:^(id value) {
        SPA_NS(Task) *workToBeProvided = chainer(value);
        
        [chain->_childTasks addObject:workToBeProvided];
        
        [source completeWithTask:workToBeProvided];
    } on:queue];
    [self addErrorCallback:^(NSError *error) {
        [source failWithError:error];
    } on:queue];

    return chain;
}

- (instancetype)chain
{
    return [self chain:^SPA_NS(Task) *(id value) {
        return value;
    } on:dispatch_get_global_queue(0, 0)];
}
@end

@implementation SPA_NS(Task) (SPTaskConvenience)
+ (instancetype)delay:(NSTimeInterval)delay completeValue:(id)completeValue
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (source.task.cancelled)
            return;
        
        [source completeWithValue:completeValue];
    });
    
    return source.task;
}

+ (instancetype)delay:(NSTimeInterval)delay
{
    return [SPA_NS(Task) delay:delay completeValue:nil];
}

+ (instancetype)performWork:(SPTaskWorkGeneratingCallback)work onQueue:(dispatch_queue_t)queue;
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
    dispatch_async(queue, ^{
        id value = work();
        [source completeWithValue:value];
    });
    return source.task;
}

+ (instancetype)fetchWork:(SPTaskTaskGeneratingCallback)work onQueue:(dispatch_queue_t)queue
{
    SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
    dispatch_async(queue, ^{
        SPA_NS(Task) *task = work();
        [source completeWithTask:task];
    });
    return source.task;
}

+ (instancetype)completedTask:(id)completeValue;
{
	SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
	[source completeWithValue:completeValue];
	return source.task;
}

+ (instancetype)failedTask:(NSError*)failure
{
	SPA_NS(TaskCompletionSource) *source = [SPA_NS(TaskCompletionSource) new];
	[source failWithError:failure];
	return source.task;
}

@end

@implementation SPA_NS(TaskCompletionSource)
{
    SPA_NS(Task) *_task;
    NSMutableArray *_cancellationHandlers;
}

- (id)init
{
    if(!(self = [super init]))
        return nil;
    _cancellationHandlers = [NSMutableArray new];
    _task = [[SPA_NS(Task) alloc] initFromSource:self];
    return self;
}

- (SPA_NS(Task)*)task
{
    return _task;
}

- (void)completeWithValue:(id)value
{
    [self.task completeWithValue:value];
}

- (void)failWithError:(NSError*)error
{
    [self.task failWithError:error];
}

- (void)completeWithTask:(SPA_NS(Task)*)task
{
    [[task addCallback:^(id value) {
        [self.task completeWithValue:value];
    } on:dispatch_get_global_queue(0, 0)] addErrorCallback:^(NSError *error) {
        [self.task failWithError:error];
    } on:dispatch_get_global_queue(0, 0)];
}

- (dispatch_block_t)voidResolver
{
    return [^{
        [self completeWithValue:nil];
    } copy];
}

- (void(^)(id))resolver
{
    return [^(id param){
        [self completeWithValue:param];
    } copy];
}

- (void)addCancellationCallback:(void(^)())cancellationCallback
{
    [_cancellationHandlers addObject:cancellationCallback];
}

- (void)cancel
{
    for(void(^cancellationHandler)() in _cancellationHandlers)
        cancellationHandler();
}

@end

@implementation SPA_NS(CallbackHolder)
- (id)initWithCallback:(SPTaskCallback)callback onQueue:(dispatch_queue_t)callbackQueue
{
    if(!(self = [super init]))
        return nil;
    
    self.callback = callback;
    self.callbackQueue = callbackQueue;
    
    return self;
}

- (void)dealloc
{
    self.callbackQueue = nil;
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue
{
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
    if(callbackQueue)
        dispatch_retain(callbackQueue);
    if(_callbackQueue)
        dispatch_release(_callbackQueue);
#endif
    _callbackQueue = callbackQueue;
}
@end

@implementation SPA_NS(Task) (Deprecated)
- (instancetype)addErrback:(SPTaskErrback)errback on:(dispatch_queue_t)queue;
{
    return [self addErrorCallback:errback on:queue];
}

- (instancetype)addFinally:(SPTaskFinally)finally on:(dispatch_queue_t)queue;
{
    return [self addFinallyCallback:finally on:queue];
}
@end