//
//  SPAgentTest.m
//  Moriarty
//
//  Created by Joachim Bengtsson on 2012-12-26.
//
//

#import "SPAgentTest.h"
#import <SPAsync/SPAgent.h>
#import <SPAsync/SPTask.h>

@interface TestAgent : NSObject <SPAgent>
- (id)leet;
@end

@implementation SPAgentTest

- (void)testAgentAsyncTask
{
    TestAgent *agent = [TestAgent new];
    
    SPTask *leetTask = [[agent sp_agentAsync] leet];
    __block BOOL gotLeet = NO;
    [leetTask addCallback:^(id value) {
        STAssertEqualObjects(value, @(1337), @"Got an unexpected value");
        gotLeet = YES;
    } on:dispatch_get_main_queue()];
    
    // Spin the runloop
    while(!gotLeet)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    STAssertEquals(gotLeet, YES, @"Expected to have gotten leet by now");
}

@end

@implementation TestAgent
{
    dispatch_queue_t _workQueue;
}
- (id)init
{
    if(!(self = [super init]))
        return nil;
    
    _workQueue = dispatch_queue_create("moriarty.testworkqueue", DISPATCH_QUEUE_SERIAL);
    
    return self;
}

- (void)dealloc
{
    dispatch_release(_workQueue);
}

- (dispatch_queue_t)workQueue
{
    return _workQueue;
}

- (id)leet
{
    NSAssert(_workQueue == dispatch_get_current_queue(), @"Expected getter to be called on work queue");
    return @(1337);
}
@end