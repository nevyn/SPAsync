//
//  SPTaskTest.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import <XCTest/XCTest.h>

@interface SPTaskTest : XCTestCase

@end

#define SPTestSpinRunloopWithCondition(condition, timeout) ({ \
    NSTimeInterval __elapsed = 0; \
    static const NSTimeInterval pollInterval = 0.01; \
    while(!(condition) && __elapsed < timeout) { \
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:pollInterval]]; \
        __elapsed += pollInterval; \
    } \
    XCTAssertTrue(__elapsed < timeout, @"Timeout reached without completion"); \
})


#define SPAssertTaskCompletesWithValueAndTimeout(task, expected, timeout) ({ \
    __block BOOL __triggered = NO; \
    [task addCallback:^(id value) {\
        XCTAssertEqualObjects(expected, value, @"Wrong value completed"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    [task addErrorCallback:^(NSError *error) {\
        XCTFail(@"Didn't expect task to fail"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    SPTestSpinRunloopWithCondition(__triggered, timeout); \
    XCTAssertTrue(__triggered, @"Timeout reached without completion"); \
})

#define SPAssertTaskFailsWithErrorAndTimeout(task, expected, timeout) ({ \
    __block BOOL __triggered = NO; \
    [task addCallback:^(id value) {\
        XCTFail(@"Task should have failed"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    [task addErrorCallback:^(NSError *error) {\
        XCTAssertEqualObjects(error, expected, @"Not the expected error"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    SPTestSpinRunloopWithCondition(__triggered, timeout); \
    XCTAssertTrue(__triggered, @"Timeout reached without completion"); \
})

#define SPAssertTaskCancelledWithTimeout(task, timeout) ({ \
    __block BOOL __triggered = NO; \
    [task addCallback:^(id value) {\
        XCTFail(@"Didn't expect task to complete"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    [task addErrorCallback:^(NSError *error) {\
        XCTFail(@"Didn't expect task to fail"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    SPTestSpinRunloopWithCondition(!__triggered, timeout); \
    XCTAssertFalse(__triggered, @"Timeout reached with completion"); \
})
