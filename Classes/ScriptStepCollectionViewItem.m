//
//  ScriptStepCollectionViewItem.m
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

#import "ScriptStepCollectionViewItem.h"
#import "ScriptStepView.h"
#import "ScriptStep.h"

@implementation ScriptStepCollectionViewItem

//
// setSelected:
//
// When the CollectionViewItem changes selection state, apply that state to the
// view
//
// Parameters:
//    flag - the new selection state
//
- (void)setSelected:(BOOL)flag
{
    [super setSelected:flag];
	
    [(ScriptStepView *)[self view] setSelected:flag];
}

//
// updateStateForView
//
// Set the state on the view according to the state of the represented object
//
- (void)updateStateForView
{
	ScriptStep *step = [self representedObject];
	ScriptStepView *view = (ScriptStepView *)[self view];
	if ([step isExecuting])
	{
		[view setState:ScriptStepActive];
	}
	else if ([step isFinished])
	{
		[view setErrorsWarningsString:[NSString stringWithFormat:
			NSLocalizedString(@"%ld errors, %ld warnings", @""),
			[step errorCount], [step warningCount]]];
		if ([step errorCount] != 0)
		{
			[view setState:ScriptStepFailed];
		}
		else if ([step warningCount] != 0)
		{
			[view setState:ScriptStepSuccessWithWarnings];
		}
		else if ([step isCancelled])
		{
			[view setState:ScriptStepCancelled];
		}
		else
		{
			[view setState:ScriptStepSuccess];
		}
	}
	else
	{
		[view setState:ScriptStepPending];
	}
}

//
// setRepresentedObject:
//
// When the represented object changes, begin observing the new object
//
// Parameters:
//    representedObject - the new object
//
- (void)setRepresentedObject:(ScriptStep *)representedObject
{
	ScriptStep *previous = [self representedObject];
	if (previous)
	{
		[previous removeObserver:self forKeyPath:@"isExecuting"];
		[previous removeObserver:self forKeyPath:@"isFinished"];
	}
	
	[super setRepresentedObject:representedObject];
	
	if (representedObject)
	{
		[representedObject addObserver:self forKeyPath:@"isExecuting" options:0 context:NULL];
		[representedObject addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
	}

	[self updateStateForView];
}

//
// observeValueForKeyPath:ofObject:change:context:
//
// When elements affecting view state change on the represented object, pass
// these on to the view
//
// Parameters:
//    keyPath - the property
//    object - the object
//    change - the change
//    context - the context
//
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
	change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqual:@"isExecuting"] ||
		[keyPath isEqual:@"isFinished"])
	{
		[self updateStateForView];
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change
		context:context];
}

//
// dealloc
//
// Need to stop observing when dealloc'd
//
- (void)dealloc
{
	[self setRepresentedObject:nil];
	[super dealloc];
}


@end
