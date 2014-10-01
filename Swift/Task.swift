//
//  Task.swift
//  SPAsync
//
//  Created by Joachim Bengtsson on 2014-08-14.
//  Copyright (c) 2014 ThirdCog. All rights reserved.
//

import Foundation

public class Task<T>
{
	// MARK: Public interface: Callbacks
	
	public func addCallback(callback: (T -> Void)) -> Self
	{
		return addCallback(on:dispatch_get_main_queue(), callback: callback)
	}
	
	public func addCallback(on queue: dispatch_queue_t, callback: (T -> Void)) -> Self
	{
		return self
	}
	
	public func addErrorCallback(callback: (NSError! -> Void)) -> Self
	{
		return addErrorCallback(on:dispatch_get_main_queue(), callback:callback)
	}
	public func addErrorCallback(on queue: dispatch_queue_t, callback: (NSError! -> Void)) -> Self
	{
		return self
	}
	
	public func addFinallyCallback(callback: (Bool -> Void)) -> Self
	{
		return addFinallyCallback(on:dispatch_get_main_queue(), callback:callback)
	}
	public func addFinallyCallback(on queue: dispatch_queue_t, callback: (Bool -> Void)) -> Self
	{
		return self
	}
	
	
	// MARK: Public interface: Advanced callbacks
	
	public func then<T2>(callback: (T -> T2)) -> Task<T2>
	{
		return then(on:dispatch_get_main_queue(), callback: callback)
	}
	public func then<T2>(on queue:dispatch_queue_t, callback: (T -> T2)) -> Task<T2>
	{
		return Task<T2>()
	}
	
	public func then<T2>(callback: (T -> Task<T2>)) -> Task<T2>
	{
		return then(on:dispatch_get_main_queue(), callback: callback)
	}
	public func then<T2>(on queue:dispatch_queue_t, callback: (T -> Task<T2>)) -> Task<T2>
	{
		return Task<T2>()
	}
	
	/// Transforms Task<Task<T2>> into a Task<T2> asynchronously
	public func chain<T2>() -> Task<T2>
	{
		return Task<T2>()
	}
	
	
	// MARK: Public interface: Cancellation
	
	public func cancel()
	{
		var shouldCancel = false
		synchronized(self) { () -> Void in
			shouldCancel = !self.isCancelled
			self.isCancelled = true
		}
		
		if shouldCancel {
			self.source!.cancel()
			// break any circular references between source<> task by removing
			// callbacks and errbacks which might reference the source
			synchronized(self) {
				self.callbacks.removeAll(keepCapacity: false)
				self.errbacks.removeAll(keepCapacity: false)
				
			}

		}
		
	}
	
	public private(set) var isCancelled = false
	
	
	// MARK: Public interface: construction
	
	class func performWork(on queue:dispatch_queue_t, work: Void -> T) -> Task<T>
	{
		return Task<T>()
	}
	
	class func fetchWork(on queue:dispatch_queue_t, work: Void -> Task<T>) -> Task<T>
	{
		return Task<T>()
	}
	
	class func delay(interval: NSTimeInterval, value : T) -> Task<T>
	{
		return Task<T>()
	}
	
	class func completedTask(value: T) -> Task<T>
	{
		return Task<T>()
	}
	
	class func failedTask(error: NSError!) -> Task<T>
	{
		return Task<T>()
	}
	
	
	// MARK: Private implementation
	
	var callbacks : [TaskCallbackHolder<T -> Void>] = []
	var errbacks : [TaskCallbackHolder<NSError! -> Void>] = []
	var finallys : [TaskCallbackHolder<Bool -> Void>] = []
	var isCompleted = false

	var completedValue : T? = nil
	var completedError : NSError? = nil
	weak var source : TaskCompletionSource<T>?
	
	func completeWithValue(value: T)
	{
		
	}
	func failWithError(err: NSError!)
	{
	
	}
}

// MARK:
public class TaskCompletionSource<T> : NSObject {
	public override init()
	{
		
	}
	
	public let task = Task<T>()
	private var cancellationHandlers : [(() -> Void)] = []

	/** Signal successful completion of the task to all callbacks */
	public func completeWithValue(value: T)
	{
		self.task.completeWithValue(value)
	}
	
	/** Signal failed completion of the task to all errbacks */
	public func failWithError(err: NSError!)
	{
		self.task.failWithError(err)
	}

	/** Signal completion for this source's task based on another task. */
	public func completeWithTask(task: Task<T>)
	{
		task.addCallback(on:dispatch_get_global_queue(0, 0), callback: {
			(v: T) -> Void in
				self.task.completeWithValue(v)
		}).addErrorCallback(on:dispatch_get_global_queue(0, 0), callback: {
			(e: NSError!) -> Void in
				self.task.failWithError(e)
		})
	}

	/** If the task is cancelled, your registered handlers will be called. If you'd rather
    poll, you can ask task.cancelled. */
	public func onCancellation(callback: () -> Void)
	{
		synchronized(self) {
			self.cancellationHandlers.append(callback)
		}
	}
	
	func cancel() {
		var handlers: [()->()] = []
		synchronized(self) { () -> Void in
			handlers = self.cancellationHandlers
		}
		for callback: () -> Void in handlers {
			callback()
		}
	}
}

class TaskCallbackHolder<T>
{
	init(on queue:dispatch_queue_t, callback: T) {
		callbackQueue = queue
		self.callback = callback
	}
	
	var callbackQueue : dispatch_queue_t
	var callback : T
}

func synchronized(on: AnyObject, closure: () -> Void) {
	objc_sync_enter(on)
	closure()
	objc_sync_exit(on)
}