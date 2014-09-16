import Foundation

func slowAddition(a: Int, b: Int, callback: (sum: NSNumber, error: NSError?) -> Void) {
	let sum = a + b
	callback(sum: NSNumber(integer: sum), error: nil)
}

func taskize<P1, P2, R1 : AnyObject> (
	asyncFunc: (
		p1: P1,
		p2: P2,
		callback: (
			r1: R1,
			err: NSError?
		) -> Void
	) -> Void
) -> (P1, P2) -> SPTask
{
	let source = SPTaskCompletionSource()
	
	return { (p1: P1, p2: P2) -> SPTask in
		asyncFunc(p1: p1, p2: p2, { (r1: R1, error: NSError?) -> Void in
			source.completeWithValue(r1)
		})
		return source.task()
	}
}

// Calling a function with three parameters: two ints and a callback.
slowAddition(4, 5) { (sum: NSNumber, error: NSError?) -> Void in
	println("Look ma, callback summarized! \(sum)")
}

// Creating and calling a function with two parameters (two ints) that returns a task!
taskize(slowAddition)(4, 5).addCallback({ (sum: AnyObject!) -> () in
	println("Look ma, future summarized! \(sum)")
})

NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))