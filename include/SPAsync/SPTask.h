//
//  SPTask.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.

#import <Foundation/Foundation.h>
#import <SPAsync/SPAsyncNamespacing.h>

#pragma mark Boring build time details (scroll down for actual interface)
/*
    For wrapping SPTask in binary libraries (read: Lookback) without conflicting with SPTask's existance in the app that
    uses the library, the binary library can change the name of this class to something else (such as LBTask) by defining
    the macro `-DSPASYNC_NAMESPACE=LB` at build time in that project.
*/
@class SPA_NS(Task);

/*
    For backwards compatibility with ObjC before lightweight generics, these macros allow us to define
    SPTask with generics support only if it's available. In this case, whenever you see SPA_GENERIC_TYPE(PromisedType)
    as a parameter or return value, pretend that it just says `id`.
*/
#if __has_feature(objc_generics)
#   define SPA_GENERIC(class, ...)      class<__VA_ARGS__>
#   define SPA_GENERIC_TYPE(type)       type
#else
#   define SPA_GENERIC(class, ...)      class
#   define SPA_GENERIC_TYPE(type)       id
#endif

#pragma mark - SPTask and friends!

/** @class SPTask
    @abstract Wraps any asynchronous operation that someone might want to know the result of in the future.
    
    You can use SPTask in any place where you'd traditionally use a callback.
    
    Instead of doing a Pyramid Of Doom like this:
 
    [thing fetchNetworkThingie:url callback:^(NSData *data) {
        [AsyncJsonParser parse:data callback:^(NSDictionary *parsed) {
            [_database updateWithData:parsed callback:^(NSError *err) {
                if(err)
                    ... and it just goes on...
            }];
            // don't forget error handling here
        }];
        // don't forget error handling here too
    }];
    
    you can get a nice chain of things like this:
    
    [[[[[thing fetchNetworkThingie:url] chain:^(NSData *data) {
        return [AsyncJsonParser parse:data];
    }] chain:^(NSDictionary *parsed) {
        return [_database updateWithData:data];
    }] addCallback:^{
        NSLog(@"Yay!");
    }] addErrorCallback:^(NSError *error) {
        NSLog(@"An error caught anywhere along the line can be handled here in this one place: %@", error);
    }];
    
    That's nicer, yeah?
    
    By using task trees like this, you can make your interfaces prettier, make cancellation easier, centralize your
    error handling, make it easier to work with dispatch_queues, and so on.
 */
@interface SPA_GENERIC(SPA_NS(Task), PromisedType) : NSObject

typedef void(^SPTaskCallback)(SPA_GENERIC_TYPE(PromisedType) value);
typedef void(^SPTaskErrback)(NSError *error);
typedef void(^SPTaskFinally)(BOOL cancelled);
typedef id(^SPTaskThenCallback)(SPA_GENERIC_TYPE(PromisedType) value);
typedef id(^SPTaskWorkGeneratingCallback)();
typedef SPA_NS(Task*)(^SPTaskTaskGeneratingCallback)();
typedef SPA_NS(Task)*(^SPTaskChainCallback)(SPA_GENERIC_TYPE(PromisedType) value);
typedef SPA_NS(Task)*(^SPTaskRecoverCallback)(NSError *error);


/** @method addCallback:on:
    Add a callback to be called async when this task finishes, including the queue to
    call it on. If the task has already finished, the callback will be called immediately
    (but still asynchronously)
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addCallback:(SPTaskCallback)callback on:(dispatch_queue_t)queue;

/** @method addCallback:
	@discussion Like addCallback:on:, but defaulting to the main queue. */
- (instancetype)addCallback:(SPTaskCallback)callback;

/** @method addErrorCallback:on:
    Like callback, but for when the task fails 
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addErrorCallback:(SPTaskErrback)errback on:(dispatch_queue_t)queue;

/** @method addErrorCallback:
	@discussion Like addErrorCallback:on:, but defaulting to the main queue. */
- (instancetype)addErrorCallback:(SPTaskErrback)errback;

/** @method addFinally:on:
    Called on both success, failure and cancellation.
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addFinallyCallback:(SPTaskFinally)finally on:(dispatch_queue_t)queue;

/** @method addFinallyCallback:on:
	@discussion Like addFinallyCallback:on:, but defaulting to the main queue. */
- (instancetype)addFinallyCallback:(SPTaskFinally)finally;

/** @method awaitAll:
    @return A task that will complete when all the given tasks have completed.
 */
+ (instancetype)awaitAll:(NSArray*)tasks;

@end


@interface SPA_NS(Task) (SPTaskCancellation)
/** @property cancelled
	Whether someone has explicitly cancelled this task.
 */
@property(getter=isCancelled,readonly) BOOL cancelled;

/** @method cancel
	Tells the owner of this task to cancel the operation if possible. This method also
	tries to cancel callback calling, but unless you're on the same queue as the callback
	being cancelled, it might trigger before the invocation of 'cancel' completes.
 */
- (void)cancel;
@end


@interface SPA_NS(Task) (SPTaskExtended)

/** @method then:on:
    Add a callback, and return a task that represents the return value of that
    callback. Useful for doing background work with the result of some other task.
    This task will fail if the parent task fails, chaining them together.
    @return A new task to be executed when 'self' completes, representing
            the work in 'worker'
 */
- (instancetype)then:(SPTaskThenCallback)worker on:(dispatch_queue_t)queue;

/** @method chain:on:
    Add a callback that will be used to provide further work to be done. The
    returned SPTask represents this work-to-be-provided.
    @return A new task to be executed when 'self' completes, representing
            the work provided by 'worker'
  */
- (instancetype)chain:(SPTaskChainCallback)chainer on:(dispatch_queue_t)queue;

/** @method chain
    @abstract Convenience for asynchronously waiting on a task that returns a task.
    @discussion Equivalent to [task chain:^SPTask*(SPTask *task) { return task; } ...]
    @example sp_agentAsync returns a task. When run on a method that returns a task,
             you want to wait on the latter, rather than the former. Thus, you chain:
                [[[[foo sp_agentAsync] fetchSomething] chain] addCallback:^(id something) {}];
            ... to first convert `Task<Task<Thing>>` into `Task<Thing>` through chain,
            then into `Thing` through addCallback.
  */
- (instancetype)chain;

/** @method recover:on:
    If the receiver fails, this callback will be called as if it was an error callback.
    If it returns a new SPTask, its completion will determine the completion of the returned
    task. If it returns nil, the original error will be propagated. */
- (instancetype)recover:(SPTaskRecoverCallback)recoverer on:(dispatch_queue_t)queue;
@end


@interface SPA_GENERIC(SPA_NS(Task), PromisedType) (SPTaskConvenience)

/** @method performWork:onQueue:
    Convenience method to do work on a specified queue, completing the task with the value
    returned from the block. */
+ (instancetype)performWork:(SPTaskWorkGeneratingCallback)work onQueue:(dispatch_queue_t)queue;
/** @method fetchWork:onQueue:
    Like performWork:onQueue, but returning a task from the block that we'll wait on before
    completing the task. */
+ (instancetype)fetchWork:(SPTaskTaskGeneratingCallback)work onQueue:(dispatch_queue_t)queue;

/** @method delay:completeValue:
    Create a task that will complete after the specified time interval and
    with specified complete value.
    @return A new task delayed task.
  */
+ (instancetype)delay:(NSTimeInterval)delay completeValue:(SPA_GENERIC_TYPE(PromisedType))completeValue;

/** @method delay:
    Create a task that will complete after the specified time interval with
    complete value nil.
    @return A new task delayed task.
  */
+ (instancetype)delay:(NSTimeInterval)delay;

/** @method completedTask:
	Convenience method for when an asynchronous caller happens to immediately have an
	available value.
	@return A new task with a completed value. */
+ (instancetype)completedTask:(SPA_GENERIC_TYPE(PromisedType))completeValue;

/** @method failedTask:
	Convenience method for when an asynchronous caller happens to immediately knows it
	will fail with a specific failure.
	@return A new task with an associated error. */
+ (instancetype)failedTask:(NSError*)failure;

@end

/** @class SPTaskCompletionSource
    Task factory for a single task that the caller knows how to complete/fail.
  */
@interface SPA_GENERIC(SPA_NS(TaskCompletionSource), PromisedType) : NSObject
/** The task that this source can mark as completed. */
- (SPA_GENERIC(SPA_NS(Task), PromisedType)*)task;

/** Signal successful completion of the task to all callbacks.
    NOTE: If you pass an NSError, this call will forward to failWithError:
 */
- (void)completeWithValue:(SPA_GENERIC_TYPE(PromisedType))value;
/** Signal failed completion of the task to all errbacks */
- (void)failWithError:(NSError*)error;

/** Signal completion for this source's task based on another task. */
- (void)completeWithTask:(SPA_GENERIC(SPA_NS(Task), PromisedType)*)task;

/** Returns a block that when called calls completeWithValue:nil.
    @example
        SPTaskCompletionSource *source = [SPTaskCompletionSource new];
        [_assetWriter finishWritingWithCompletionHandler:[source voidResolver]];
        return source.task; // task triggers callbacks when asset writer finishes writing
*/
- (dispatch_block_t)voidResolver;
/** Returns a block that when called calls completeWithValue: with its first parameter*/
- (void(^)(SPA_GENERIC_TYPE(PromisedType)))resolver;

/** If the task is cancelled, your registered handlers will be called. If you'd rather
    poll, you can ask task.cancelled. */
- (void)addCancellationCallback:(void(^)())cancellationCallback;
@end


@interface SPA_NS(Task) (Testing)

/** Check a task's completed state.
    @warning This is intended for testing purposes only, and it is not recommended to use
             this property as a means to do micro optimizations for synchronous code.
 
    @return  Whether or not the receiver has been completed with a value or error. */
@property(getter=isCompleted,readonly) BOOL completed;

@end

/** Convenience holder of a callback and the queue that the callback should be called on */
@interface SPA_NS(CallbackHolder) : NSObject
- (id)initWithCallback:(SPTaskCallback)callback onQueue:(dispatch_queue_t)callbackQueue;
@property(nonatomic,assign) dispatch_queue_t callbackQueue;
@property(nonatomic,copy) SPTaskCallback callback;
@end


@interface SPA_NS(Task) (Deprecated)
/** @discussion use addErrorCallback:: instead */
- (instancetype)addErrback:(SPTaskErrback)errback on:(dispatch_queue_t)queue;

/** @discussion Use addFinallyCallback:: instead */
- (instancetype)addFinally:(SPTaskFinally)finally on:(dispatch_queue_t)queue;
@end
