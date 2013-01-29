#import <SPAsync/SPAgent.h>
#import <SPAsync/NSObject+SPInvocationGrabbing.h>
#import <SPAsync/SPTask.h>

@implementation NSObject (SPAgentDo)
- (instancetype)sp_agentAsync
{
    SPInvocationGrabber *grabber = [self grabWithoutStacktrace];
    __weak SPInvocationGrabber *weakGrabber = grabber;
    
    SPTaskCompletionSource *completionSource = [SPTaskCompletionSource new];
    SPTask *task = completionSource.task;
    __block void *unsafeTask = (__bridge void *)(task);
    
    grabber.afterForwardInvocation = ^{
        NSInvocation *invocation = [weakGrabber invocation];
        
        // Let the caller get the result of the invocation as a task.
        // Block guarantees lifetime of 'task', so just bridge it here.
        BOOL hasObjectReturn = strcmp([invocation.methodSignature methodReturnType], @encode(id)) == 0;
        if(hasObjectReturn)
            [invocation setReturnValue:&unsafeTask];
        
        dispatch_async([(id)self workQueue], ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            // "invoke" will break the cycle, and the block must hold on to grabber
            // until this moment so that it survives (nothing else is holding the grabber)
            [grabber invoke];
#pragma clang diagnostic pop
            if(hasObjectReturn) {
                __unsafe_unretained id result = nil;
                [invocation getReturnValue:&result];
                [completionSource completeWithValue:result];
            }
        });
    };
    return grabber;
}

@end