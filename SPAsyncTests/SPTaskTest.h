//
//  SPTaskTest.h
//  SPAsync
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import <SenTestingKit/SenTestingKit.h>

@interface SPTaskTest : SenTestCase

@end

#define SPTestSpinRunloopWithCondition(condition, timeout) ({ \
    NSTimeInterval __elapsed = 0; \
    static const NSTimeInterval pollInterval = 0.01; \
    while(!(condition) && __elapsed < timeout) { \
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:pollInterval]]; \
        __elapsed += pollInterval; \
    } \
    STAssertTrue(__elapsed < timeout, @"Timeout reached without completion"); \
})


#define SPAssertTaskCompletesWithValueAndTimeout(task, expected, timeout) ({ \
    __block BOOL __triggered = NO; \
    [task addCallback:^(id value) {\
        STAssertEqualObjects(expected, value, @"Wrong value completed"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    [task addErrback:^(NSError *error) {\
        STFail(@"Didn't expect task to fail"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    SPTestSpinRunloopWithCondition(__triggered, timeout); \
    STAssertTrue(__triggered, @"Timeout reached without completion"); \
})

#define SPAssertTaskFailsWithErrorAndTimeout(task, expected, timeout) ({ \
    __block BOOL __triggered = NO; \
    [task addCallback:^(id value) {\
        STFail(@"Task should have failed"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    [task addErrback:^(NSError *error) {\
        STAssertEqualObjects(error, expected, @"Not the expected error"); \
        __triggered = YES; \
    } on:dispatch_get_main_queue()]; \
    SPTestSpinRunloopWithCondition(__triggered, timeout); \
    STAssertTrue(__triggered, @"Timeout reached without completion"); \
})