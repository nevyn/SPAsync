# Promise, it's async!
## SLUG Lightning 2015-09-24
### @nevyn, @lookback

---

# [Fit] SPAsync

---

# Nested scopes
```swift
💩.fetchFromNetwork(input) { intermediate in 
	💩.parseResponse(intermediate) { again in
		dispatch_async(dispatch_get_main_queue()) {
			updateUI(output)
		}
	}
}
```

---

## Error handling 
```swift
💩.fetchFromNetwork(input, callback: { intermediate in 
	💩.parseResponse(intermediate, callback: { again in
		dispatch_async(dispatch_get_main_queue()) {
			updateUI(output)
		}
	}, errback: { error in
		displayError("when parsing response, ", error)
	})
}, errback: { error in
	// This error is VERY far away from fetchFromNetwork!
	displayError("when fetching from network, ", error)
})
```

---

## Cancellation 
```swift
var cancelled = false
block var cancellable : Cancellable?
let operation = 💩.fetchFromNetwork(input, callback: { intermediate in 
	if(cancelled) return
	cancellable = 💩.parseResponse(intermediate, callback: { again in
		if(cancelled) return
		...
	})
})

func cancel() {
	cancelled = true
	operation.cancel()
	cancellable?.stopOperation()
}
```

---

## Dependencies

``` swift
func 💩()...
```

---

# Four async concepts

* A-value-in-the-future
* Error handler
* Cancellation
* Dependencies

---

# [Fit] GCD?
# [Fit] NSOperation?

---

# [Fit] ReactiveCocoa?

---

# [Fit] C♯

---

# [Fit] Task
## [Fit] / "promise" / "future"


---

# Help me Apple, you're my only hope!

* A-value-in-the-future
* Error handler
* Cancellation
* Dependencies

... IN FOUNDATION

---

# SPTask.swift 1/4

```swift

class TaskCompletionSource<T> {
	public let task: Task<T>
	func completeWithValue(value: T)
	func failWithError(error: NSError!)
}

```

---

# SPTask.swift 2/4

```swift
class Task<T> {
	public func addCallback(
		on queue: dispatch_queue_t,
		callback: (T -> Void)
	) -> Self
	
	public func addErrorCallback(
		on queue: dispatch_queue_t,
		callback: (NSError! -> Void)
	) -> Self
	
	public func addFinallyCallback(
		on queue: dispatch_queue_t,
		callback: (Bool -> Void)
	) -> Self
}
```

---

## Callback example

```swift

// Two of these three are executed immediately after each other
network.fetch(resource).addCallback { json in
	let modelObject = parse(json)
	updateUI(modelObject)
}.addErrback { error in
	displayDialog(error)
}.addFinally { cancelled in
	if !cancelled {
		viewController.dismiss()
	}
}

```


---

# SPTask.swift 3/4

```swift
class Task<T> {
	public func then<T2>(on queue:dispatch_queue_t, worker: (T -> T2)) -> Task<T2>
	public func then<T2>(chainer: (T -> Task<T2>)) -> Task<T2>
}
```

---

## Chaining example

```swift

// A: inline background parsing on _worker_queue
func parse<T>(json) -> T

network.fetch(resource)
	.then(on: _worker_queue) { json in
		// First this function runs, running parse on _worker_queue...
		return parse<MyModel>(json)
	}.addCallback { modelObject in
		// ... and when it's done, this function runs on main
		updateUI(modelObject)
	}.addErrorCallback { ... }

// B: background parsing on Parser's own thread with async method
class Parser {
	func parse<T>(json) -> Task<T>
}

network.fetch(resource)
	.then(_parser.parse) // parser is responsible for doing async work on its own
	.addCallback(updateUI) // and then updateUI is called with the model object
	.addErrorCallback(displayError)
```

---

# SPTask.swift 4/4

```swift
class Task<T> {	
	public func cancel()
	
	static func awaitAll(tasks: [Task]) -> Task<[Any]>
}
```

---

## cancel and awaitAll example

```swift

let imagesTask = Task.awaitAll(network.fetchImages(resource)).then { imageDatas in
	return Task.awaitAll(imageDatas.map { data in 
		return parseImage(data)
	})
}.addCallback { images in
	showImages(image)
}

func viewDidDisappear()
{
	
	// All downloading and parsing is cancelled
	imagesTask.cancel()
}

```

---

# [Fit] Grand finale

---

# [Fit] Task.wrap()

---

```swift

class NSURLConnection {
	func sendAsynchronousRequest(
		request: NSURLRequest,
		queue: NSOperationQueue,
		completionHandler: (NSURLResponse?, NSError?) -> Void
	)
}

extension NSURLConnection {
	// : (NSURLRequest, queue) -> Task<NSURLResponse?>
	let asyncTaskRequest = Task.wrap(NSURLConnection.sendAsynchronousRequest)
}

NSURLConnection.asyncTaskRequest(myRequest, mainQueue)
	.then(_parser.parse)
	.then(_db.store)
	.then(_ui.update)
```


---

```swift

extension Task {
	func wrap<P1, P2, R1> (
		asyncFunction: (
			p1: P1,
			p2: P2,
			callback: (
				r1: R1,
				err: NSError?
			) -> Void
		) -> Void
	) -> (P1, P2) -> Task<R1>
}
```

---

```swift

extension Task {
	func wrap<P1, P2, R1> (
		asyncFunction: (
			p1: P1,
			p2: P2,
			callback: (
				r1: R1,
				err: NSError?
			) -> Void
		) -> Void
	) -> (P1, P2) -> Task<R1>
	{
		let source = TaskCompletionSource<R1>()
	
		return { (p1: P1, p2: P2) -> Task<R1> in
			asyncFunc(p1: p1, p2: p2, callback: { (r1: R1, error: NSError?) -> Void in
				if let error = error {
					source.failWithError(error)
				} else {
					source.completeWithValue(r1)
				}
			})
			return source.task
		}
	}
}
```

---

# Functional Task?

Monads? Applicatives? Huh?!

---

# Blog: Methods of Concurrency
#  
# [Fit] http://bit.do/concurrency

http://overooped.com/post/41803252527/methods-of-concurrency

---


![150% original](http://promisekit.org/public/img/tight-header.png)

---


# [fit] Thank you

# @nevyn
##  nevyn@lookback.io
