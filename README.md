# SPAsync

by Nevyn Joachim Bengtsson <nevyn.jpg@gmail.com>

Tools for abstracting asynchrony in Objective-C. Read [the introductory blog post](http://overooped.com/post/41803252527/methods-of-concurrency) for much more detail. SPTask is the most interesting tool in here.

## SPTask

Wraps any asynchronous operation or value that someone might want to know the result of, or get the value of, in the future.
    
You can use SPTask in any place where you'd traditionally use a callback.

Instead of doing a Pyramid Of Doom like this:

    [thing fetchNetworkThingie:url callback:^(NSData *data) {
        [AsyncJsonParser parse:data callback:^(NSDictionary *parsed) {
            [_database updateWithData:parsed callback:^(NSError *err) {
                if(err)
                    ... and it just goes on...
            }];
            // don't forget error handling here
        }];
        // don't forget error handling here too
    }];

you can get a nice chain of things like this:

    [[[[[thing fetchNetworkThingie:url] chain:^(NSData *data) {
        return [AsyncJsonParser parse:data];
    }] chain:^(NSDictionary *parsed) {
        return [_database updateWithData:data];
    }] addCallback:^{
        NSLog(@"Yay!");
    }] addErrorCallback:^(NSError *error) {
        NSLog(@"An error caught anywhere along the line can be handled here in this one place: %@", error);
    }];

That's nicer, yeah?

By using task trees like this, you can make your interfaces prettier, make cancellation easier, centralize your
error handling, make it easier to work with dispatch_queues, and so on.


SPTask is basically a copy of System.Threading.Tasks.Task in .Net. It's a standard library class representing any asynchronous operation that yields a single value. This is deceivingly simple, and gives you much more power of abstraction than you would initially believe. You can think of it as an extremely lightweight ReactiveCocoa, in a single file.


## SPAgent

An experimental multithreading primitive. The goal is to make every "manager" style class multithreaded with its own work queue, and then make communication between these agents trivial.

## SPAwait

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


Extensions
----------

In the Extensions folder you'll find extensions to other libraries, making them compatible with SPTask in various ways. You'll have to compile these in on your own when you need them; otherwise they would become dependencies for this library.