import Foundation

println("Hello, World!")

let task = SPTask.completedTask(5)
task.addCallback({
	(x: AnyObject!) -> () in
	println("Look ma: \(x)")
}, on:dispatch_get_main_queue())


NSRunLoop.mainRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 1))