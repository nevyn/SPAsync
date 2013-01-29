SPAsync
=======
by Joachim Bengtsson <joachimb@gmail.com>

Tools for abstracting asynchrony in Objective-C. Read [the introductory blog entry](http://overooped.com/post/41803252527/methods-of-concurrency) for much more detail.

SPTask
------

System.Threading.Tasks.Task in .Net is very nice. It's a standard library class representing any asynchronous operation that yields a single value. This is deceivingly simple, and gives you much more power of abstraction than you would initially believe.

SPTask is a minimal copy of .Net Task in Objective-C, with functionality to chain multiple asynchronous operations. You can think of it as an extremely lightweight ReactiveCocoa.

SPAgent
-------

An experimental multithreading primitive. The goal is to make every "manager" style class multithreaded with its own work queue, and then make communication between these agents trivial.