#import <Foundation/Foundation.h>

/**
 Experimental multithreading primitive: An object conforming to SPAgent is not thread safe,
 but it runs in its own thread. To perform any of the methods on it, you must first dispatch to its
 workQueue.
 */
@protocol SPAgent <NSObject>
@property(nonatomic,readonly) dispatch_queue_t workQueue;
@end

/// Returns invocation grabber; resulting invocation will be performed on workQueue. Proxied invocation returns an SPTask.
@interface NSObject (SPAgentDo)
- (instancetype)sp_agentAsync;
@end