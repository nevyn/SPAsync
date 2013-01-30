//
//  SPAwait.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2013-01-30.
//
//

/** @file SPAwait
    @abstract Emulates the behavior of the 'await' keyword in C#, letting you pause execution of a method, waiting for a value.
    @example
        - (SPTask<NSNumber> *)uploadThing:(NSData*)thing
        {
            // Variables you want to use need to be declared as __block at the top of the method.
            __block NSData *encrypted, *hash, *confirmation;
            // Immediately after, you need to state that you are starting an async method body
            SPAsyncMethodBegin
            
            // Do work like normal
            [self prepareFor:thing];
            
            // When you make a call to something returning an SPTask, you can wait for its value. The method
            // will actually return at this point, and resume on the next line when the encrypted value is available.
            encrypted = SPAsyncAwait([_encryptor encrypt:thing]);
            
            // Keep doing work as normal. This line might run much later, as we have suspended and waited for the encrypted
            // value.
            hash ≈ [encrypted hash];
            [_network send:encrypted];
            [_network send:hash];
            
            confirmation = SPAsyncAwait([_network read:1]);
            
            // Returning will complete the SPTask, sending this value to all the callbacks registered with it
            return @([confirmation bytes][0] == 0);
            
            // You must also clean up the async method body manually.
            SPAsyncMethodEnd
        }
 */

/** @macro SPAsyncMethodBegin
    @abstract Place at the beginning of an async method, after
              variable declarations
 */
#define SPAsyncMethodBegin \
    __block SPAwaitCoroutine *__awaitCoroutine = [SPAwaitCoroutine new]; \
    __block __weak SPAwaitCoroutine *__weakAwaitCoroutine = __awaitCoroutine; \
    [__awaitCoroutine setBody:^ id (int resumeAt) { \
        switch (resumeAt) { \
            case 0:;

/** @macro SPAsyncAwait
    @abstract Pauses the execution of the calling method, waiting for the value in
              'awaitable' to be available.
 */
 
#define SPAsyncAwait(awaitable) \
    ({ \
        [awaitable addCallback:^(id value) { \
            __weakAwaitCoroutine.lastAwaitedValue = value; \
            [__weakAwaitCoroutine resumeAt:__LINE__]; \
        } on:[__weakAwaitCoroutine queueFor:self]]; \
        return [SPAwaitCoroutine awaitSentinel]; \
        case __LINE__:; \
        __weakAwaitCoroutine.lastAwaitedValue; \
    })

/** @macro SPAsyncMethodEnd
    @abstract Place at the very end of an async method
 */
#define SPAsyncMethodEnd \
        } /* switch ends here */ \
        return nil; \
    }]; /* setBody ends here */ \
    [__weakAwaitCoroutine resumeAt:0]; \
    return [__weakAwaitCoroutine task];


@class SPTask;
typedef id(^SPAwaitCoroutineBody)(int resumeAt);

/** @class SPAwaitCoroutine
    @abstract Private implementation detail of SPAwait
*/
@interface SPAwaitCoroutine : NSObject
// if returned from body, the method has not completed
+ (id)awaitSentinel;
@property(nonatomic,retain) id lastAwaitedValue;

- (void)setBody:(SPAwaitCoroutineBody)body;
- (void)resumeAt:(int)line;
- (void)finish;

- (SPTask*)task;

/// works out a suitable queue to continue running on
- (dispatch_queue_t)queueFor:(id)object;
@end
