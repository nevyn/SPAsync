//
//  SPTask.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import <Foundation/Foundation.h>
@class SPTask;

typedef void(^SPTaskCallback)(id value);
typedef void(^SPTaskErrback)(NSError *error);
typedef void(^SPTaskFinally)(BOOL cancelled);
typedef id(^SPTaskThenCallback)(id value);
typedef SPTask*(^SPTaskChainCallback)(id value);

/** @class SPTask
    @abstract Any asynchronous operation that someone might want to know the result of.
 */
@interface SPTask : NSObject

/** @method addCallback:on:
    Add a callback to be called async when this task finishes, including the queue to
    call it on. If the task has already finished, the callback will be called immediately
    (but still asynchronously)
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addCallback:(SPTaskCallback)callback on:(dispatch_queue_t)queue;

/** @method addErrback:on:
    Like callback, but for when the task fails 
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addErrback:(SPTaskErrback)errback on:(dispatch_queue_t)queue;

/** @method addFinally:on:
    Called on both success, failure and cancellation.
    @return self, in case you want to add more call/errbacks on the same task */
- (instancetype)addFinally:(SPTaskFinally)finally on:(dispatch_queue_t)queue;

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

/** @method awaitAll:
    @return A task that will complete when all the given tasks have completed.
 */
+ (instancetype)awaitAll:(NSArray*)tasks;


- (void)cancel;
@property(getter=isCancelled,readonly) BOOL cancelled;
@end


/** @class SPTaskCompletionSource
    Task factory for a single task that the caller knows how to complete/fail.
  */
@interface SPTaskCompletionSource : NSObject
/** The task that this source can mark as completed. */
- (SPTask*)task;

/** Signal successful completion of the task to all callbacks */
- (void)completeWithValue:(id)value;
/** Signal failed completion of the task to all errbacks */
- (void)failWithError:(NSError*)error;

/** If the task is cancelled, your registered handlers will be called. If you'd rather
    poll, you can ask task.cancelled. */
- (void)addCancellationCallback:(void(^)())cancellationCallback;
@end


/** Convenience holder of a callback and the queue that the callback should be called on */
@interface SPCallbackHolder : NSObject
- (id)initWithCallback:(SPTaskCallback)callback onQueue:(dispatch_queue_t)callbackQueue;
@property(nonatomic,assign) dispatch_queue_t callbackQueue;
@property(nonatomic,copy) SPTaskCallback callback;
@end
