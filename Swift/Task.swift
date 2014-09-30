//
//  Task.swift
//  SPAsync
//
//  Created by Joachim Bengtsson on 2014-08-14.
//  Copyright (c) 2014 ThirdCog. All rights reserved.
//

import Foundation

public class Task<T> : NSObject {
	
	// public
	func addCallback(callback: (T -> Void)) -> Self
	{
		return addCallback(on:dispatch_get_main_queue(), callback: callback)
	}
	
	func addCallback(on queue: dispatch_queue_t, callback: (T -> Void)) -> Self
	{
		return self
	}
	
	func addErrorCallback(callback: (NSError! -> Void)) -> Self
	{
		return addErrorCallback(on:dispatch_get_main_queue(), callback:callback)
	}
	func addErrorCallback(on queue: dispatch_queue_t, callback: (NSError! -> Void)) -> Self
	{
		return self
	}
	
	// private
	var callbacks : [(T -> Void)] = []
	var errbacks : [(NSError! -> Void)] = []
	var finallys : [(Bool -> Void)] = []
	var isCompleted = false
	var isCancelled = false
	var completedValue : T? = nil // !! crashes compiler
	var completedError : NSError? = nil
	weak var source : TaskCompletionSource<T>?
	
	func completeWithValue(value: T)
	{
	
	}
	func failWithError(err: NSError!)
	{
	
	}
}

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

func synchronized(on: AnyObject, closure: () -> Void) {
	objc_sync_enter(on)
	closure()
	objc_sync_exit(on)
}