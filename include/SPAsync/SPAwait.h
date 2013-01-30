//
//  SPAwait.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2013-01-30.
//
//

/** @class SPAwaitCoroutine
    @abstract Emulates the behavior of the 'await' keyword in C#, letting you pause execution of a method, waiting for a value.
    @example
        - (SPTask<NSNumber> *)uploadThing:(NSData*)thing
        {
            // Variables you want to use need to be declared as __block at the top of the method.
            __block NSData *encrypted, *hash, *confirmation;
            // Immediately after, you need to state that you are starting an async method body
            SPAsyncMethodBegin();
            
            // Do work like normal
            [self prepareFor:thing];
            
            // When you make a call to something returning an SPTask, you can wait for its value. The method
            // will actually return at this point, and resume on the next line when the encrypted value is available.
            SPAsyncAwait(encrypted, [_encryptor encrypt:thing]);
            
            // Keep doing work as normal. This line might run much later, as we have suspended and waited for the encrypted
            // value.
            hash ≈ [encrypted hash];
            [_network send:encrypted];
            [_network send:hash];
            
            SPAsyncAwait(confirmation, [_network read:1]);
            
            // If you have a value you want to return once our task completes, yield it with SPAsyncMethodReturn.
            SPAsyncMethodReturn(@([confirmation bytes][0] == 0));
            
            // You must also clean up the async method body manually.
            SPAsyncMethodEnd();
        }
 */

#define SPAsyncMethodBegin() \
    __block SPAwaitCoroutine *__awaitCoroutine = [SPAwaitCoroutine new]; \
    __block __weak SPAwaitCoroutine *__weakAwaitCoroutine = __awaitCoroutine; \
    [__awaitCoroutine setBody:^ (int resumeAt) { \
        switch (resumeAt) { \
            case 0: \

#define SPAsyncAwait(destination, awaitable) \
    ({ \
        [awaitable addCallback:^(id value) { \
            destination = value; \
            [__weakAwaitCoroutine resumeAt:__LINE__]; \
        } on:[__weakAwaitCoroutine queueFor:self]]; \
        return; \
        case __LINE__:; \
    })

#define SPAsyncAwaitVoid(awaitable) \
    ({ \
        [awaitable addCallback:^(id value) { \
            [__weakAwaitCoroutine resumeAt:__LINE__]; \
        } on:[__weakAwaitCoroutine queueFor:self]]; \
        return; \
        case __LINE__:; \
    })

#define SPAsyncMethodReturn(value) ({ \
    [__weakAwaitCoroutine yieldValue:value]; \
    [__weakAwaitCoroutine finish]; \
    return; \
})

#define SPAsyncMethodEnd() \
            [__weakAwaitCoroutine finish]; \
        } /* switch ends here */ \
    }]; /* setBody ends here */ \
    [__awaitCoroutine resumeAt:0]; \
    return [__awaitCoroutine task];

@class SPTask;

@interface SPAwaitCoroutine : NSObject
- (void)setBody:(void(^)(int resumeAt))body;
- (void)resumeAt:(int)line;
- (void)finish;
/// Set the value to complete the task with, once every part of the body has completed
- (void)yieldValue:(id)value;

- (SPTask*)task;

/// works out a suitable queue to continue running on
- (dispatch_queue_t)queueFor:(id)object;
@end
