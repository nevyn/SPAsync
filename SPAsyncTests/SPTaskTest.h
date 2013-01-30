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
    NSTimeInterval __duration = 0; \
    while(!__triggered && __duration < timeout) {\
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]]; \
        __duration += 0.01; \
    } \
    STAssertTrue(__triggered, @"Timeout reached without completion"); \
})
