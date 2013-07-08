//
//  SPAwaitTest.m
//  SPAsync
//
//  Created by Joachim Bengtsson on 2013-01-30.
//  
//

#import "SPAwaitTest.h"
#import "SPTaskTest.h"
#import <SPAsync/SPAwait.h>
#import <SPAsync/SPTask.h>

@implementation SPAwaitTest

- (SPTask *)awaitableNumber:(NSNumber*)num
{
    return [SPTask delay:0.01 completeValue:num];
}

- (SPTask *)simple
{
    __block NSNumber *number;
    SPAsyncMethodBegin
    
    number = SPAsyncAwait([self awaitableNumber:@42]);
    
    return @([number intValue]*2);
    
    SPAsyncMethodEnd
}
- (void)testSimple
{
    SPAssertTaskCompletesWithValueAndTimeout([self simple], @(84), 0.1);
}



- (SPTask *)multipleReturns
{
    SPAsyncMethodBegin
    
    if(NO)
        return @2;
    else
        return @3;
    
    STFail(@"Shouldn't reach past return");
    
    SPAsyncMethodEnd
}
- (void)testMultipleReturns
{
    SPAssertTaskCompletesWithValueAndTimeout([self multipleReturns], @(3), 0.1);
}

- (SPTask *)awaitInConditional
{
    __block NSNumber *number;
    SPAsyncMethodBegin
    
    if(NO) {
        number = SPAsyncAwait([self awaitableNumber:@1]);
    } else {
        number = SPAsyncAwait([self awaitableNumber:@2]);
    }
    
    return number;
    
    SPAsyncMethodEnd
}
- (void)testAwaitInConditional
{
    SPAssertTaskCompletesWithValueAndTimeout([self awaitInConditional], @(2), 0.1);
}

- (SPTask*)voidMethod
{
    SPAsyncMethodBegin
    SPAsyncMethodEnd
}
- (void)testVoidMethod
{
    SPAssertTaskCompletesWithValueAndTimeout([self voidMethod], nil, 0.1);
}

@end
