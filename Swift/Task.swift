//
//  Task.swift
//  SPAsync
//
//  Created by Joachim Bengtsson on 2014-08-14.
//  Copyright (c) 2014 ThirdCog. All rights reserved.
//

import Foundation

public class Task<T> : Cancellable, Equatable
{
	// MARK: Public interface: Callbacks
	
	public func addCallback(callback: (T -> Void)) -> Self
	{
		return addCallback(on:dispatch_get_main_queue(), callback: callback)
	}
	
	public func addCallback(on queue: dispatch_queue_t, callback: (T -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if self.isCompleted {
				if self.completedError == nil {
					dispatch_async(queue) {
						callback(self.completedValue!)
					}
				}
			} else {
				self.callbacks.append(TaskCallbackHolder(on: queue, callback: callback))
			}
		}
		return self
	}
	
	public func addErrorCallback(callback: (NSError! -> Void)) -> Self
	{
		return addErrorCallback(on:dispatch_get_main_queue(), callback:callback)
	}
	public func addErrorCallback(on queue: dispatch_queue_t, callback: (NSError! -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if self.isCompleted {
				if self.completedError != nil {
					dispatch_async(queue) {
						callback(self.completedError!)
					}
				}
			} else {
				self.errbacks.append(TaskCallbackHolder(on: queue, callback: callback))
			}
		}
		return self
	}
	
	public func addFinallyCallback(callback: (Bool -> Void)) -> Self
	{
		return addFinallyCallback(on:dispatch_get_main_queue(), callback:callback)
	}
	public func addFinallyCallback(on queue: dispatch_queue_t, callback: (Bool -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if(self.isCompleted) {
				dispatch_async(queue, { () -> Void in
					callback(self.isCancelled)
				})
			} else {
				self.finallys.append(TaskCallbackHolder(on: queue, callback: callback))
			}
		}
		return self
	}
	
	
	// MARK: Public interface: Advanced callbacks
	
	public func then<T2>(worker: (T -> T2)) -> Task<T2>
	{
		return then(on:dispatch_get_main_queue(), worker: worker)
	}
	public func then<T2>(on queue:dispatch_queue_t, worker: (T -> T2)) -> Task<T2>
	{
		let source = TaskCompletionSource<T2>();
		let then = source.task;
		self.childTasks.append(then)
		
		self.addCallback(on: queue, callback: { (value: T) -> Void in
			let result = worker(value)
			source.completeWithValue(result)
		})
		self.addErrorCallback(on: queue, callback: { (error: NSError!) -> Void in
			source.failWithError(error)
		})
		return then
	}
	
	public func then<T2>(chainer: (T -> Task<T2>)) -> Task<T2>
	{
		return then(on:dispatch_get_main_queue(), chainer: chainer)
	}
	public func then<T2>(on queue:dispatch_queue_t, chainer: (T -> Task<T2>)) -> Task<T2>
	{
		let source = TaskCompletionSource<T2>();
		let chain = source.task;
		self.childTasks.append(chain)
		
		self.addCallback(on: queue, callback: { (value: T) -> Void in
			let workToBeProvided : Task<T2> = chainer(value)
			
			chain.childTasks.append(workToBeProvided)
			source.completeWithTask(workToBeProvided)
		})
		self.addErrorCallback(on: queue, callback: { (error: NSError!) -> Void in
			source.failWithError(error)
		})
		
		return chain;
	}
	
	/// Transforms Task<Task<T2>> into a Task<T2> asynchronously
	// dunno how to do this with static typing...
	/*public func chain<T2>() -> Task<T2>
	{
		return self.then<T.T>({(value: Task<T2>) -> T2 in
			return value
		})
	}*/
	
	
	// MARK: Public interface: Cancellation
	
	public func cancel()
	{
		var shouldCancel = false
		synchronized(callbackLock) { () -> Void in
			shouldCancel = !self.isCancelled
			self.isCancelled = true
		}
		
		if shouldCancel {
			self.source!.cancel()
			// break any circular references between source<> task by removing
			// callbacks and errbacks which might reference the source
			synchronized(callbackLock) {
				self.callbacks.removeAll()
				self.errbacks.removeAll()
				
				for holder in self.finallys {
					dispatch_async(holder.callbackQueue, { () -> Void in
						holder.callback(true)
					})
				}
				
				self.finallys.removeAll()
			}
		}
		
		for child in childTasks {
			child.cancel()
		}
		
	}
	
	public private(set) var isCancelled = false
	
	
	// MARK: Public interface: construction
	
	class func performWork(on queue:dispatch_queue_t, work: Void -> T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		dispatch_async(queue) {
			let value = work()
			source.completeWithValue(value)
		}
		return source.task
	}
	
	class func fetchWork(on queue:dispatch_queue_t, work: Void -> Task<T>) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		dispatch_async(queue) {
			let value = work()
			source.completeWithTask(value)
		}
		return source.task

	}
	
	class func delay(interval: NSTimeInterval, value : T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
			source.completeWithValue(value)
		}
		return source.task
	}
	
	class func completedTask(value: T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		source.completeWithValue(value)
		return source.task
	}
	
	class func failedTask(error: NSError!) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		source.failWithError(error)
		return source.task
	}
	
	
	// MARK: Public interface: other convenience
	
	class func awaitAll(tasks: [Task]) -> Task<[Any]>
	{
		let source = TaskCompletionSource<[Any]>()
		
		if tasks.count == 0 {
			source.completeWithValue([])
			return source.task;
		}
		
		var values : [Any] = []
		var remainingTasks : [Task] = tasks
		
		var i : Int = 0
		for task in tasks {
			source.task.childTasks.append(task)
			weak var weakTask = task
			
			values.append(NSNull())
			task.addCallback(on: dispatch_get_main_queue(), callback: { (value: Any) -> Void in
				values[i] = value
				remainingTasks.removeAtIndex(find(remainingTasks, weakTask!)!)
				if remainingTasks.count == 0 {
					source.completeWithValue(values)
				}
			}).addErrorCallback(on: dispatch_get_main_queue(), callback: { (error: NSError!) -> Void in
				if remainingTasks.count == 0 {
					// ?? how could this happen?
					return
				}
				
				remainingTasks.removeAtIndex(find(remainingTasks, weakTask!)!)
				source.failWithError(error)
				for task in remainingTasks {
					task.cancel()
				}
				remainingTasks.removeAll()
				values.removeAll()

			}).addFinallyCallback(on: dispatch_get_main_queue(), callback: { (canceled: Bool) -> Void in
				if canceled {
					source.task.cancel()
				}
			})
			
			i++;
		}
		return source.task;
	}

	
	// MARK: Private implementation
	
	var callbacks : [TaskCallbackHolder<T -> Void>] = []
	var errbacks : [TaskCallbackHolder<NSError! -> Void>] = []
	var finallys : [TaskCallbackHolder<Bool -> Void>] = []
	var callbackLock : NSLock = NSLock()
	
	var isCompleted = false
	var completedValue : T? = nil
	var completedError : NSError? = nil
	weak var source : TaskCompletionSource<T>?
	var childTasks : [Cancellable] = []
	
	internal init()
	{
		// temp
	}
	
	internal init(source: TaskCompletionSource<T>)
	{
		self.source = source
	}
	
	func completeWithValue(value: T)
	{
		assert(self.isCompleted == false, "Can't complete a task twice")
		if self.isCompleted {
			return
		}
		
		if self.isCancelled {
			return
		}
		
		synchronized(callbackLock) {
			self.isCompleted = true
			self.completedValue = value
			let copiedCallbacks = self.callbacks
			let copiedFinallys = self.finallys
			
			for holder in copiedCallbacks {
				dispatch_async(holder.callbackQueue) {
					if !self.isCancelled {
						holder.callback(value)
					}
				}
			}
			for holder in copiedFinallys {
				dispatch_async(holder.callbackQueue) {
					holder.callback(self.isCancelled)
				}
			}
			
			self.callbacks.removeAll()
			self.errbacks.removeAll()
			self.finallys.removeAll()
		}

	}
	func failWithError(error: NSError!)
	{
		assert(self.isCompleted == false, "Can't complete a task twice")
		if self.isCompleted {
			return
		}
		
		if self.isCancelled {
			return
		}

		synchronized(callbackLock) {
			self.isCompleted = true
			self.completedError = error
			let copiedErrbacks = self.errbacks
			let copiedFinallys = self.finallys
			
			for holder in copiedErrbacks {
				dispatch_async(holder.callbackQueue) {
					if !self.isCancelled {
						holder.callback(error)
					}
				}
			}
			for holder in copiedFinallys {
				dispatch_async(holder.callbackQueue) {
					holder.callback(self.isCancelled)
				}
			}

			self.callbacks.removeAll()
			self.errbacks.removeAll()
			self.finallys.removeAll()
		}

	}
}

public func ==<T>(lhs: Task<T>, rhs: Task<T>) -> Bool
{
	return lhs === rhs
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
	public func failWithError(error: NSError!)
	{
		self.task.failWithError(error)
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
		for callback in handlers {
			callback()
		}
	}
}

protocol Cancellable {
	func cancel() -> Void
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

func synchronized(on: NSLock, closure: () -> Void) {
	on.lock()
	closure()
	on.unlock()
}

func synchronized<T>(on: NSLock, closure: () -> T) -> T {
	on.lock()
	let r = closure()
	on.unlock()
	return r
}