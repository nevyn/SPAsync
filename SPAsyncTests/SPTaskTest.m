//
//  SPTaskTest.m
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import "SPTaskTest.h"
#import <SPAsync/SPTask.h>

@implementation SPTaskTest

- (void)testCallback
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    SPTask *task = source.task;
    dispatch_queue_t callbackQueue = dispatch_get_main_queue();
    __block BOOL firstCallbackTriggered = NO;
    __block BOOL secondCallbackTriggered = NO;
    
    __weak __typeof(task) weakTask = task;
    [task addCallback:^(id value) {
        XCTAssertTrue(weakTask.isCompleted, @"Should be completed by the time the first callback fires.");
        XCTAssertEqualObjects(value, @(1337), @"Unexpected value");
        XCTAssertEqual(firstCallbackTriggered, NO, @"Callback should only trigger once");
        firstCallbackTriggered = YES;
    } on:callbackQueue];
    [task addErrorCallback:^(id value) {
        XCTAssertTrue(NO, @"Error should not have triggered");
    } on:callbackQueue];
    [task addCallback:^(id value) {
        XCTAssertEqualObjects(value, @(1337), @"Unexpected value");
        XCTAssertEqual(firstCallbackTriggered, YES, @"First callback should have triggered before the second");
        secondCallbackTriggered = YES;
    } on:callbackQueue];
    
    [source completeWithValue:@(1337)];
    
    // Spin the runloop
    while(!secondCallbackTriggered)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    XCTAssertEqual(firstCallbackTriggered, YES, @"First callback should have triggered");
    XCTAssertEqual(secondCallbackTriggered, YES, @"Second callback should have triggered");
    XCTAssertTrue(task.isCompleted, @"Completion state not altered by callbacks.");
}

- (void)testErrback
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    SPTask *task = source.task;
    dispatch_queue_t callbackQueue = dispatch_get_main_queue();
    __block BOOL firstErrbackTriggered = NO;
    __block BOOL secondErrbackTriggered = NO;
    
    __weak __typeof(task) weakTask = task;
    [task addErrorCallback:^(NSError *error) {
        XCTAssertTrue(weakTask.isCompleted, @"Should be completed by the time the first callback fires.");
        XCTAssertEqual(error.code, (NSInteger)1337, @"Unexpected error code");
        XCTAssertEqual(firstErrbackTriggered, NO, @"Errback should only trigger once");
        firstErrbackTriggered = YES;
    } on:callbackQueue];
    [task addCallback:^(id value) {
        XCTAssertTrue(NO, @"Callback should not have triggered");
    } on:callbackQueue];
    [task addErrorCallback:^(NSError *error) {
        XCTAssertEqual(error.code, (NSInteger)1337, @"Unexpected error code");
        XCTAssertEqual(firstErrbackTriggered, YES, @"First errback should have triggered before the second");
        secondErrbackTriggered = YES;
    } on:callbackQueue];
    
    [source failWithError:[NSError errorWithDomain:@"test" code:1337 userInfo:nil]];
    
    // Spin the runloop
    while(!secondErrbackTriggered)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    XCTAssertEqual(firstErrbackTriggered, YES, @"First errback should have triggered");
    XCTAssertEqual(secondErrbackTriggered, YES, @"Second errback should have triggered");
    XCTAssertTrue(task.isCompleted, @"Completion state not altered by callbacks.");
}

- (void)testLateCallback
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    SPTask *task = source.task;
    dispatch_queue_t callbackQueue = dispatch_get_main_queue();
    __block BOOL firstCallbackTriggered = NO;
    __block BOOL secondCallbackTriggered = NO;
    
    [task addCallback:^(id value) {
        XCTAssertEqualObjects(value, @(1337), @"Unexpected value");
        XCTAssertEqual(firstCallbackTriggered, NO, @"Callback should only trigger once");
        firstCallbackTriggered = YES;
    } on:callbackQueue];
    
    [source completeWithValue:@(1337)];

    [task addCallback:^(id value) {
        XCTAssertEqualObjects(value, @(1337), @"Unexpected value");
        secondCallbackTriggered = YES;
    } on:callbackQueue];
    
    
    // Spin the runloop
    while(!secondCallbackTriggered)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    XCTAssertEqual(firstCallbackTriggered, YES, @"First callback should have triggered");
    XCTAssertEqual(secondCallbackTriggered, YES, @"Second callback should have triggered");
}

- (void)testLateErrback
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    SPTask *task = source.task;
    dispatch_queue_t callbackQueue = dispatch_get_main_queue();
    __block BOOL firstErrbackTriggered = NO;
    __block BOOL secondErrbackTriggered = NO;
    
    [task addErrorCallback:^(NSError *error) {
        XCTAssertEqual(error.code, (NSInteger)1337, @"Unexpected value");
        XCTAssertEqual(firstErrbackTriggered, NO, @"Callback should only trigger once");
        firstErrbackTriggered = YES;
    } on:callbackQueue];
    
    [source failWithError:[NSError errorWithDomain:@"test" code:1337 userInfo:nil]];

    [task addErrorCallback:^(NSError *error) {
        XCTAssertEqual(error.code, (NSInteger)1337, @"Unexpected value");
        secondErrbackTriggered = YES;
    } on:callbackQueue];
    
    // Spin the runloop
    while(!secondErrbackTriggered)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    XCTAssertEqual(firstErrbackTriggered, YES, @"First callback should have triggered");
    XCTAssertEqual(secondErrbackTriggered, YES, @"Second callback should have triggered");
}

- (void)testThen
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [source completeWithValue:@(10)];

    __block BOOL done = NO;
    
    [[[source.task then:^id(id value) {
        return @([value intValue]*20);
    } on:dispatch_get_main_queue()] then:^id(id value) {
        return @([value intValue]*30);
    } on:dispatch_get_main_queue()] addCallback:^(id value) {
        XCTAssertEqualObjects(value, @(6000), @"Chain didn't chain as expected");
        done = YES;
    } on:dispatch_get_main_queue()];
    
    while(!done)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

- (void)testRecoverSuccess
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [source failWithError:[NSError errorWithDomain:@"lol" code:4 userInfo:nil]];
    
    SPAssertTaskCompletesWithValueAndTimeout([source.task recover:^SPTask*(NSError *err) {
        return [SPTask completedTask:@6];
    } on:dispatch_get_main_queue()], @6, 0.1);
}

- (void)testRecoverFailure
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    NSError *err = [NSError errorWithDomain:@"lol" code:4 userInfo:nil];
    [source failWithError:err];
    
    SPAssertTaskFailsWithErrorAndTimeout([source.task recover:^SPTask*(NSError *err) {
        return nil;
    } on:dispatch_get_main_queue()], err, 0.1);
}

- (void)testTest
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    [source completeWithValue:@(10)];
    SPAssertTaskCompletesWithValueAndTimeout(source.task, @(10), 0.1);
}

- (void)testAwaitAllSuccess
{
    SPTaskCompletionSource *source1 = [SPTaskCompletionSource new];
    SPTaskCompletionSource *source2 = [SPTaskCompletionSource new];
    SPTaskCompletionSource *nullSource = [SPTaskCompletionSource new];
    
    SPTask *all = [SPTask awaitAll:@[source1.task, source2.task, nullSource.task]];
    id expected = @[@1, @2, [NSNull null]];
    
    [source1 completeWithValue:@1];
    [source2 completeWithValue:@2];
    [nullSource completeWithValue:nil];
    
    SPAssertTaskCompletesWithValueAndTimeout(all, expected, 0.1);
}

- (void)testAwaitAllFailure
{
    SPTaskCompletionSource *source1 = [SPTaskCompletionSource new];
    SPTaskCompletionSource *source2 = [SPTaskCompletionSource new];
    
    SPTask *all = [SPTask awaitAll:@[source1.task, source2.task]];
    
    NSError *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
    [source1 completeWithValue:@1];
    [source2 failWithError:error];
    
    SPAssertTaskFailsWithErrorAndTimeout(all, error, 0.1);
}

- (void)testBasicCancellation
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    
    __block BOOL callbackWasRun = NO;
    [source.task addCallback:^(id value) {
        callbackWasRun = YES;
    } on:dispatch_get_main_queue()];
    
    [source.task cancel];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if(!source.task.cancelled)
            [source completeWithValue:@1];
    });
    
    NSTimeInterval __elapsed = 0;
    static const NSTimeInterval pollInterval = 0.01;
    while(__elapsed < 0.1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:pollInterval]];
        __elapsed += pollInterval;
    }
    
    XCTAssertEqual(callbackWasRun, NO, @"Callback should not have been run");
    XCTAssertEqual(source.task.cancelled, YES, @"Task should be cancelled");
}

- (void)testCallbackCancellation
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    
    __block BOOL cancelled = NO;
    [source addCancellationCallback:^{
        cancelled = YES;
    }];
    
    __block BOOL callbackWasRun = NO;
    [source.task addCallback:^(id value) {
        callbackWasRun = YES;
    } on:dispatch_get_main_queue()];
    
    [source.task cancel];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if(!cancelled)
            [source completeWithValue:@1];
    });
    
    NSTimeInterval __elapsed = 0;
    static const NSTimeInterval pollInterval = 0.01;
    while(__elapsed < 0.1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:pollInterval]];
        __elapsed += pollInterval;
    }
    
    XCTAssertEqual(callbackWasRun, NO, @"Callback should not have been run");
    XCTAssertEqual(cancelled, YES, @"Cancellation callback wasn't run");
    XCTAssertEqual(source.task.cancelled, YES, @"Task should be cancelled");
}

- (void)testCancellationChain
{
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    
    __block BOOL callbackWasRun = NO;
    SPTask *chained = [source.task then:^id(id value) {
        callbackWasRun = YES;
        return nil;
    } on:dispatch_get_main_queue()];
    
    [source.task cancel];
    [source completeWithValue:@1];
        
    NSTimeInterval __elapsed = 0;
    static const NSTimeInterval pollInterval = 0.01;
    while(__elapsed < 0.1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:pollInterval]];
        __elapsed += pollInterval;
    }

    XCTAssertEqual(source.task.cancelled, YES, @"Source task should be cancelled");
    XCTAssertEqual(chained.cancelled, YES, @"Chained task should be cancelled");
    XCTAssertEqual(callbackWasRun, NO, @"Chained callback shouldn't have been called");
}

- (void)testCancellationChainCompleted
{
    // test that a chain that is completed and then cancelled will cancel
    // the created task if it has not been completed yet.
    
    SPTaskCompletionSource *source = [SPTaskCompletionSource new];
    __block SPTask *delayed = nil;
    
    SPTask *chained = [source.task chain:^SPTask *(id value) {
        delayed = [SPTask delay:0.1];
        return delayed;
    } on:dispatch_get_main_queue()];
    
    [source completeWithValue:@1];
    
    SPAssertTaskCompletesWithValueAndTimeout(source.task, @1, 0.1);
    
    [source.task cancel];

    SPAssertTaskCancelledWithTimeout(delayed, 0.2);
    
    XCTAssertTrue(source.task.cancelled, @"Source task should be cancelled");
    XCTAssertTrue(chained.cancelled, @"Chain task should be cancelled");
    XCTAssertTrue(delayed.cancelled, @"Chained task should be cancelled");
}


- (void)testFinally
{
    SPTaskCompletionSource *successSource = [SPTaskCompletionSource new];
    SPTaskCompletionSource *failureSource = [SPTaskCompletionSource new];
    SPTaskCompletionSource *cancellationSource = [SPTaskCompletionSource new];
    __block int i = 0;
    
    [[[successSource.task addCallback:^(id value) {
        XCTAssertEqualObjects(value, @1, @"Task didn't complete with the correct value");
    } on:dispatch_get_main_queue()] addErrorCallback:^(NSError *error) {
        XCTAssertNil(error, @"Task shouldn't have an error");
    } on:dispatch_get_main_queue()] addFinally:^(BOOL cancelled) {
        XCTAssertEqual(cancelled, NO, @"Task should not be cancelled");
        i++;
    } on:dispatch_get_main_queue()];
    
    NSError *expected = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    [[[failureSource.task addCallback:^(id value) {
        XCTAssertEqualObjects(value, nil, @"Task failed and shouldn't have a value");
    } on:dispatch_get_main_queue()] addErrorCallback:^(NSError *error) {
        XCTAssertEqual(error, expected, @"Task should have an error");
    } on:dispatch_get_main_queue()] addFinally:^(BOOL cancelled) {
        XCTAssertEqual(cancelled, NO, @"Task should not be cancelled");
        i++;
    } on:dispatch_get_main_queue()];
    
    [[[cancellationSource.task addCallback:^(id value) {
        XCTAssertEqualObjects(value, nil, @"Task was cancelled and shouldn't have a value");
    } on:dispatch_get_main_queue()] addErrorCallback:^(NSError *error) {
        XCTAssertNil(error, @"Task was cancelled shouldn't have an error");
    } on:dispatch_get_main_queue()] addFinally:^(BOOL cancelled) {
        XCTAssertEqual(cancelled, YES, @"Task should be cancelled");
        i++;
    } on:dispatch_get_main_queue()];
    
    [successSource completeWithValue:@1];
    [failureSource failWithError:expected];
    [cancellationSource.task cancel];
    
    SPTestSpinRunloopWithCondition(i == 3, 0.1);
    XCTAssertEqual(i, 3, @"A finalizer wasn't called");
}

- (void)testAwaitAll_FailThenComplete
{
    SPTaskCompletionSource *successSource = [SPTaskCompletionSource new];
    SPTaskCompletionSource *failureSource = [SPTaskCompletionSource new];
    
    SPTask* awaited = [SPTask awaitAll:@[successSource.task, failureSource.task]];
    
    // when one task in an +awaitAll group fails...
    NSError* error = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
    [failureSource failWithError:error];
    
    // ...then another one resolves, an exception is thrown on the main thread in the +awaitAll callback
    [successSource completeWithValue:@1];
    
    SPAssertTaskFailsWithErrorAndTimeout(awaited, error, 0.1);
    // NOTE: STAssertThrows/NoThrow doesn't help us because the exception is thrown inside a block in +awaitAll
}

- (void)testAwaitAll_FailThenFail
{
    SPTaskCompletionSource *failureSource = [SPTaskCompletionSource new];
    SPTaskCompletionSource *secondFailureSource = [SPTaskCompletionSource new];
    
    SPTask* awaited = [SPTask awaitAll:@[secondFailureSource.task, failureSource.task]];
    
    // when one task in an +awaitAll group fails...
    NSError* error = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
    [failureSource failWithError:error];
    
    // ...then another one fails, a redundant completion assertion is triggered
    [secondFailureSource failWithError:[NSError errorWithDomain:@"test" code:-2 userInfo:nil]];
    
    SPAssertTaskFailsWithErrorAndTimeout(awaited, error, 0.1);
    // NOTE: STAssertThrows/NoThrow doesn't help us because the exception is thrown inside a block in +awaitAll
}

- (void)testAwaitAll_FailThenCancel
{
    SPTaskCompletionSource *failureSource = [SPTaskCompletionSource new];
    SPTaskCompletionSource *canceledSource = [SPTaskCompletionSource new];
    
    SPTask* awaited = [SPTask awaitAll:@[canceledSource.task, failureSource.task]];
    
    // when one task in an +awaitAll group fails...
    NSError* error = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
    [failureSource failWithError:error];
    
    // ...then another one is cancelled
    [canceledSource.task cancel];
    
    SPAssertTaskFailsWithErrorAndTimeout(awaited, error, 0.1);
}

- (void)testAwaitAll_CancelThenComplete
{
    SPTaskCompletionSource *source1 = [SPTaskCompletionSource new];
    SPTaskCompletionSource *source2 = [SPTaskCompletionSource new];
    
    SPTask* awaited = [SPTask awaitAll:@[source2.task, source1.task]];
    
    [source1.task cancel];
    
    [source2 completeWithValue:@1];
    
    SPAssertTaskCancelledWithTimeout(awaited, 0.1);
}

- (void)testAwaitAll_CancelThenFail
{
    SPTaskCompletionSource *source1 = [SPTaskCompletionSource new];
    SPTaskCompletionSource *source2 = [SPTaskCompletionSource new];
    
    SPTask* awaited = [SPTask awaitAll:@[source2.task, source1.task]];
    
    [source1.task cancel];
    
    [source2 failWithError:[NSError errorWithDomain:@"test" code:-1 userInfo:nil]];
    
    SPAssertTaskCancelledWithTimeout(awaited, 0.1);
}

@end
