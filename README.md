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

SPAwait
-------

Experimental copy of C# 5's "await" keyword, using the preprocessor.

    - (SPTask<NSNumber> *)uploadThing:(NSData*)thing
    {
        // Variables you want to use need to be declared as __block at the top of the method.
        __block NSData *encrypted, *confirmation;
        
        SPAsyncMethodBegin // Start of an async method, similar to 'async' keyword in C#
        
        // Do work like normal
        [self prepareFor:thing];
        
        // When you make a call to something returning an SPTask, you can wait for its value. The method
        // will actually return at this point, and resume on the next line when the encrypted value is available.
        encrypted = SPAsyncAwait([_encryptor encrypt:thing]);
        
        [_network send:encrypted];
        
        confirmation = SPAsyncAwait([_network read:1]);
        
        // Returning will complete the SPTask, sending this value to all the callbacks registered with it
        return @([confirmation bytes][0] == 0);
        
        SPAsyncMethodEnd
    }
