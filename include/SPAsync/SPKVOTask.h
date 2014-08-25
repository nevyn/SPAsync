#import <SPAsync/SPAsync.h>

@interface SPA_NS(KVOTask) : SPA_NS(Task)
 /**
 *  Create a task that will complete once 'keypath' on 'object' becomes 'value'.
 *
 *  @param value   Value to await. Task will complete when [object valueForKeyPath:keypath isEqual:value]
 *  @param object  Object to observe. Will be retained.
 *  @param keyPath keyPath to check for changes.
 */
+ (id)awaitValue:(id)value onObject:(id)object forKeyPath:(NSString*)keyPath;
@end
