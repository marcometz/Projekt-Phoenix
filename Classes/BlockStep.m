//
//  BlockStep.m
//  CocoaScript
//
//  Created by Matt Gallagher on 2010/11/04.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "BlockStep.h"


@implementation BlockStep

@synthesize block;
@synthesize runOnMainThread;

//
// blockStepWithBlock:
//
// Block step runs a basic block on either the ScriptQueue thread or the main
// thread.
//
// Parameters:
//    aBlock - the block takes exactly 1 parameter (the step itself so that
//		the ScriptQueue, state and methods can be accessed)
//
// returns the step
//
+ (BlockStep *)blockStepWithBlock:(BlockStepBlock)aBlock
{
	BlockStep *step = [[[self alloc] init] autorelease];
	step.block = Block_copy(aBlock);
	
	return step;
}

//
// runStep
//
// Invoke the block on ScriptQueue thread or main thread
//
- (void)runStep
{
	if (runOnMainThread)
	{
		dispatch_sync(dispatch_get_main_queue(), ^{block(self);});
	}
	else
	{
		block(self);
	}
}

//
// dealloc
//
// Release the block when done
//
- (void)dealloc
{
	Block_release(block);

	[super dealloc];
}


@end
