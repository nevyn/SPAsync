//
//  SPKVOTaskTest.m
//  SPAsync
//
//  Created by Joachim Bengtsson on 2014-08-25.
//  Copyright (c) 2014 Spotify. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <SPAsync/SPKVOTask.h>
#import "SPTaskTest.h"

@interface SPKVOTaskTest : XCTestCase
@end

@interface Dummy : NSObject
@property(nonatomic) id value;
@property(nonatomic) float primitive;
@end
@implementation Dummy
@end

@implementation SPKVOTaskTest

- (void)testAwaitObject
{
	Dummy *dummy = [Dummy new];
	__block BOOL found = NO;
	
	[[SPKVOTask awaitValue:@"hello" onObject:dummy forKeyPath:@"value"] addCallback:^(id value) {
		found = YES;
	} on:dispatch_get_main_queue()];
	
	dummy.value = @"world";
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertFalse(found, @"Didn't expect to get callback when changing to this value");

	dummy.value = @"hello";
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertTrue(found, @"Expected callback to have run");
}

- (void)testPrimitive
{
	Dummy *dummy = [Dummy new];
	__block BOOL found = NO;
	
	[[SPKVOTask awaitValue:@(3.0) onObject:dummy forKeyPath:@"primitive"] addCallback:^(id value) {
		found = YES;
	} on:dispatch_get_main_queue()];
	
	dummy.primitive = 2.0;
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertFalse(found, @"Didn't expect to get callback when changing to this value");

	dummy.primitive = 3.0;
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertTrue(found, @"Expected callback to have run");
}

- (void)testInitial
{
	Dummy *dummy = [Dummy new];
	__block BOOL found = NO;
	
	dummy.value = @"hello";
	
	[[SPKVOTask awaitValue:@"hello" onObject:dummy forKeyPath:@"value"] addCallback:^(id value) {
		found = YES;
	} on:dispatch_get_main_queue()];
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertTrue(found, @"Expected callback to have run");
}

- (void)testCancellation
{
	Dummy *dummy = [Dummy new];
	__block BOOL found = NO;
	SPTask *task = [[SPKVOTask awaitValue:@"hello" onObject:dummy forKeyPath:@"value"] addCallback:^(id value) {
		found = YES;
	} on:dispatch_get_main_queue()];
	[task cancel];
	
	// Ok, don't crash now!
	dummy.value = @"hello";
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	XCTAssertFalse(found, @"Task was cancelled, callback should not have been run");

}

@end
