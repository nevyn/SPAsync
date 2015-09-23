import Foundation

func slowAddition(a: Int, b: Int, callback: (sum: Int, error: NSError?) -> Void) {
	let sum = a + b
	callback(sum: sum, error: nil)
}

func taskize<P1, P2, R1> (
	asyncFunc: (
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
		asyncFunc(p1: p1, p2: p2, { (r1: R1, error: NSError?) -> Void in
			source.completeWithValue(r1)
		})
		return source.task
	}
}

class Hello {
	func slowAddition(a: Int, b: Int, callback: (sum: Int, error: NSError?) -> Void) {
		let sum = a + b
		callback(sum: sum, error: nil)
	}
}

// Calling a function with three parameters: two ints and a callback.
slowAddition(4, 5) { (sum: Int, error: NSError?) -> Void in
	println("Look ma, callback summarized! \(sum)")
}

// Creating and calling a function with two parameters (two ints) that returns a task!
taskize(slowAddition)(4, 5).addCallback({ (sum: Int) -> () in
	println("Look ma, future summarized! \(sum)")
})

let taskedAddition = taskize(slowAddition)
let task1 = taskedAddition(4, 5)
let task2 = taskedAddition(7, 8)
Task<Int>.awaitAll([task1, task2]).addCallback({ (sums: [Any]) -> Void in
	println("The sums! \(sums)")
})


let hello = Hello()
taskize(hello.slowAddition)(4, 6).addCallback({ (sum: Int) -> () in
	println("From an object even! \(sum)")
})

NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))