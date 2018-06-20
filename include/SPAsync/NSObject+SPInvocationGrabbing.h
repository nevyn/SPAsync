#import <Foundation/Foundation.h>

@interface SPInvocationGrabber : NSObject
-(id)initWithObject:(id)obj;
-(id)initWithObject:(id)obj stacktraceSaving:(BOOL)saveStack;
@property (readonly, retain, nonatomic) id object;
@property (readonly, retain, nonatomic) NSInvocation *invocation;
@property (nonatomic, copy) void(^afterForwardInvocation)(void);
@property BOOL backgroundAfterForward;
@property BOOL onMainAfterForward;
@property BOOL waitUntilDone;
-(void)invoke; // will release object and invocation
-(void)printBacktrace;
-(void)saveBacktrace;
@end

@interface NSObject (SPInvocationGrabbing)
-(id)grab;
-(id)grabWithoutStacktrace;
-(id)invokeAfter:(NSTimeInterval)delta;
-(id)nextRunloop;
-(id)inBackground;
-(id)onMainAsync:(BOOL)async;
@end
