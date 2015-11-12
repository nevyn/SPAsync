//
//  SPTask.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.

#import <Foundation/Foundation.h>
#import <SPAsync/SPAsyncNamespacing.h>
@class SPA_NS(Task);

typedef void(^SPTaskCallback)(id value);
typedef void(^SPTaskErrback)(NSError *error);
typedef void(^SPTaskFinally)(BOOL cancelled);
typedef id(^SPTaskThenCallback)(id value);
typedef id(^SPTaskWorkGeneratingCallback)();
typedef SPA_NS(Task*)(^SPTaskTaskGeneratingCallback)();
typedef SPA_NS(Task)*(^SPTaskChainCallback)(id value);
typedef SPA_NS(Task)*(^SPTaskRecoverCallback)(NSError *error);


/** @class SPTask
    @abstract Any asynchronous operation that someone might want to know the result of.
 */
@interface SPA_NS(Task) : NSObject

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


@interface SPA_NS(Task) (SPTaskConvenience)

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
+ (instancetype)delay:(NSTimeInterval)delay completeValue:(id)completeValue;

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
+ (instancetype)completedTask:(id)completeValue;

/** @method failedTask:
	Convenience method for when an asynchronous caller happens to immediately knows it
	will fail with a specific failure.
	@return A new task with an associated error. */
+ (instancetype)failedTask:(NSError*)failure;

@end

/** @class SPTaskCompletionSource
    Task factory for a single task that the caller knows how to complete/fail.
  */
@interface SPA_NS(TaskCompletionSource) : NSObject
/** The task that this source can mark as completed. */
- (SPA_NS(Task)*)task;

/** Signal successful completion of the task to all callbacks */
- (void)completeWithValue:(id)value;
/** Signal failed completion of the task to all errbacks */
- (void)failWithError:(NSError*)error;

/** Signal completion for this source's task based on another task. */
- (void)completeWithTask:(SPA_NS(Task)*)task;

/** Returns a block that when called calls completeWithValue:nil.
    @example
        SPTaskCompletionSource *source = [SPTaskCompletionSource new];
        [_assetWriter finishWritingWithCompletionHandler:[source voidResolver]];
        return source.task; // task triggers callbacks when asset writer finishes writing
*/
- (dispatch_block_t)voidResolver;
/** Returns a block that when called calls completeWithValue: with its first parameter*/
- (void(^)(id))resolver;

/** If the task is cancelled, your registered handlers will be called. If you'd rather
    poll, you can ask task.cancelled. */
- (void)addCancellationCallback:(void(^)())cancellationCallback;
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