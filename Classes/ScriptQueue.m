//
//  ScriptQueue.m
//  CocoaScript
//
//  Created by Matt Gallagher on 2010/11/01.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "ScriptQueue.h"
#import "ScriptStep.h"

NSString * const ScriptQueueCancelledNotification = @"ScriptQueueCancelledNotification";

@implementation ScriptQueue

@synthesize textAttributes;
@synthesize errorAttributes;
@synthesize warningAttributes;

//
// init
//
// returns the initialized ScriptQueue
//
- (id)init
{
	self = [super init];
	if (self != nil)
	{
		queueState = [[NSMutableDictionary alloc] init];
		cleanupSteps = [[NSMutableArray alloc] init];
		textAttributes = [[NSDictionary alloc] init];
		errorAttributes = [[NSDictionary alloc] init];
		warningAttributes = [[NSDictionary alloc] init];
	}
	return self;
}


//
// setStateValue:forKey:
//
// Set a value in the state dictionary
//
// Parameters:
//    value - value in the dictionary
//    key - key in the dictionary
//
- (void)setStateValue:(id)value forKey:(NSString *)key
{
	@synchronized(self)
	{
		[queueState setValue:value forKey:key];
	}
}

//
// stateValueForKey:
//
// Get a value from the state dictionary
//
// Parameters:
//    key - the key for the value
//
// returns the value
//
- (id)stateValueForKey:(NSString *)key
{
	id value = nil;
	@synchronized(self)
	{
		value = [[[queueState valueForKey:key] retain] autorelease];
	}
	return value;
}

//
// postCancelledNotification
//
// Invoked on the main thread to send a ScriptQueueCancelled notification
// (important to notify observers when the cancellation comes from within)
//
- (void)postCancelledNotification
{
	[[NSNotificationCenter defaultCenter]
		postNotificationName:ScriptQueueCancelledNotification
		object:self];
}

//
// cancelAllOperations
//
// Override of the cancel method to ensure that cleanup steps are inserted into
// the queue after a cancellation and the notification about cancellation is
// sent out.
//
- (void)cancelAllOperations
{
	@synchronized(self)
	{
		[super cancelAllOperations];
	
		for (ScriptStep *cleanupStep in cleanupSteps)
		{
			[self addOperation:cleanupStep];
		}
		[cleanupSteps removeAllObjects];
	}

	[self
		performSelectorOnMainThread:@selector(postCancelledNotification)
		withObject:nil
		waitUntilDone:NO];
}

//
// insertStepToRunImmediately:blockingDependentsOfStep:
//
// Used to ensure, while the queue is running that the provided scriptStep is
// the immediate next step to execute.
//
// To ensure that subsequent steps don't try to run simulaneously with this new
// high priority step, you can provide a dependeeStep whose dependents will all
// be made dependent upon the new scriptStep (forcing them to block until the
// scriptStep is complete).
//
// Parameters:
//    scriptStep - new high priority script step
//    dependeeStep - step whose dependents should block until after scriptStep
//
- (void)insertStepToRunImmediately:(ScriptStep *)scriptStep
	blockingDependentsOfStep:(ScriptStep *)dependeeStep
{
	for (NSOperation *dependency in [[[scriptStep dependencies] copy] autorelease])
	{
		[scriptStep removeDependency:dependency];
	}
	[scriptStep setConcurrentStep:scriptStep];
	[scriptStep setQueuePriority:NSOperationQueuePriorityVeryHigh];

	if (dependeeStep)
	{
		for (NSOperation *operation in [self operations])
		{
			if ([[operation dependencies] containsObject:dependeeStep])
			{
				[operation addDependency:scriptStep];
			}
		}
	}

	[self addOperation:scriptStep];
}

//
// addOperation:
//
// Override of operation to change the default concurrency behavior.
//
// For regular NSOperationQueues, the default is no dependency between steps.
//
// For ScriptQueue, the default is that a new step is always made dependent on
// the previous step in the queue.
//
// This default can be changed by setting the "concurrentStep" -- where all the
// dependencies of the "concurrentStep" are used as dependencies instead.
//
// If the "concurrentStep" is equal to the "scriptStep" then no dependencies are
// added to the "scriptStep".
//
// Parameters:
//    scriptStep - the step to add to the queue.
//
- (void)addOperation:(ScriptStep *)scriptStep
{
	ScriptStep *simultaneousStep = [scriptStep concurrentStep];
	if (simultaneousStep && simultaneousStep != scriptStep)
	{
		NSInteger stepIndex = [[self operations] indexOfObject:simultaneousStep];
		if (stepIndex != NSNotFound)
		{
			for (ScriptStep *dependency in [simultaneousStep dependencies])
			{
				[scriptStep addDependency:dependency];
			}
		}
	}
	else if (!simultaneousStep)
	{
		ScriptStep *lastStep = [[self operations] lastObject];
		if (lastStep)
		{
			[scriptStep addDependency:lastStep];
		}
	}
	
	[super addOperation:scriptStep];
}

//
// addCleanupStep:
//
// Adds a step to run if the queue is cancelled
//
// Parameters:
//    cleanupStep - the step to run
//
- (void)addCleanupStep:(ScriptStep *)cleanupStep
{
	@synchronized(self)
	{
		[cleanupSteps addObject:cleanupStep];
	}
}

//
// pushCleanupStep:
//
// Adds a step to the front of the cleanupSteps array to run if the queue is
// cancelled.
//
// Parameters:
//    cleanupStep - the step to run
//
- (void)pushCleanupStep:(ScriptStep *)cleanupStep
{
	@synchronized(self)
	{
		[cleanupSteps insertObject:cleanupStep atIndex:0];
	}
}

//
// removeCleanupStep:
//
// Removes a step from the cleanupSteps
//
// Parameters:
//    cleanupStep - the step to remove
//
- (void)removeCleanupStep:(ScriptStep *)cleanupStep
{
	@synchronized(self)
	{
		[cleanupSteps removeObject:cleanupStep];
	}
}

//
// clearState
//
// Resets the queueState and cleanupSteps containers.
//
- (void)clearState
{
	@synchronized(self)
	{
		[queueState removeAllObjects];
		[cleanupSteps removeAllObjects];
	}
}

//
// dealloc
//
// Release instance storage.
//
- (void)dealloc
{
	[queueState release];
	[cleanupSteps release];
	[textAttributes release];
	[errorAttributes release];
	[warningAttributes release];
	[super dealloc];
}

@end
