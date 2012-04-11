//
//  CocoaScriptWindowController.m
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

#import "CocoaScriptWindowController.h"
#import "ScriptQueue.h"
#import "ScriptStep.h"
#import "PrioritySplitViewDelegate.h"

NSArray *ScriptSteps();

@implementation CocoaScriptWindowController

@synthesize steps;
@synthesize scriptQueue;

//
// init
//
// Creates the scriptQueue, sets the display attributes and invokes -start to
// set the steps array and start the queue.
//
// returns the initialized window controller
//
- (id)init
{
	self = [super init];
	if (self)
	{
		scriptQueue = [[ScriptQueue alloc] init];
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(cancel:)
			name:ScriptQueueCancelledNotification
			object:scriptQueue];

		NSFont *inconsolata =
			[[NSFontManager sharedFontManager]
				fontWithFamily:@"Inconsolata"
				traits:0
				weight:5
				size:13];
		NSDictionary *attributes =
			[NSDictionary dictionaryWithObjectsAndKeys:
				inconsolata, NSFontAttributeName,
				[NSColor whiteColor], NSForegroundColorAttributeName,
			nil];
		scriptQueue.textAttributes = attributes;
		
		NSFont *inconsolataBold =
			[[NSFontManager sharedFontManager]
				fontWithFamily:@"Courier"
				traits:NSBoldFontMask
				weight:9
				size:12];
		NSDictionary *errorAttributes =
			[NSDictionary dictionaryWithObjectsAndKeys:
				inconsolataBold, NSFontAttributeName,
				[NSColor colorWithDeviceRed:1.0 green:0.25 blue:0.25 alpha:1.0], NSForegroundColorAttributeName,
			nil];
		scriptQueue.errorAttributes = errorAttributes;
		NSDictionary *warningAttributes =
			[NSDictionary dictionaryWithObjectsAndKeys:
				inconsolataBold, NSFontAttributeName,
				[NSColor colorWithDeviceRed:1.0 green:0.85 blue:0.25 alpha:1.0], NSForegroundColorAttributeName,
			nil];
		scriptQueue.warningAttributes = warningAttributes;
		
		[self start];
	}
	return self;
}

//
// start
//
// Calls the ScriptSteps function to get the array of script steps and then
// adds them all to the queue.
//
- (void)start
{
	NSAssert([[scriptQueue operations] count] == 0,
		@"Start invoked when queue not correctly cleared.");
	
	self.steps = ScriptSteps();
	for (ScriptStep *step in steps)
	{
		[scriptQueue addOperation:step];
	}
	
	state = CocoaScriptQueueRunning;
}

//
// updateProgressDisplay
//
// Update the progress text and progress indicator. Possibly update the
// cancel/restart button if we've reached the end of the queue
//
- (void)updateProgressDisplay
{
	NSInteger total = [steps count];
	NSArray *operations = [scriptQueue operations];
	NSInteger remaining = [operations count];
	
	//
	// Try to get the remaining count as it corresponds to the "steps" array as
	// the actual scriptQueue may have changed due to cancelled steps or other
	// dynamic changes.
	//
	if (remaining > 0)
	{
		NSInteger stepsIndex = [steps indexOfObject:[operations objectAtIndex:0]];
		if (stepsIndex != NSNotFound)
		{
			remaining = total - stepsIndex;
		}
	}
	
	if (remaining == 0)
	{
		switch (state)
		{
			case CocoaScriptQueueRunning:
			case CocoaScriptQueueFinished:
				[progressLabel setStringValue:NSLocalizedString(@"All steps complete.", nil)];
				break;
			case CocoaScriptQueueFailed:
				[progressLabel setStringValue:NSLocalizedString(@"Failed with error.", nil)];
				break;
			case CocoaScriptQueueCancelled:
				[progressLabel setStringValue:NSLocalizedString(@"Cancelled.", nil)];
				break;
		}
		[progressIndicator setDoubleValue:0];
		[cancelButton setTitle:NSLocalizedString(@"Restart", nil)];
	}
	else
	{
		[cancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
		[progressLabel setStringValue:
			[NSString stringWithFormat:
				NSLocalizedString(@"Finished step %ld of %ld", nil),
				total - remaining,
				total]];
		[progressIndicator setMaxValue:(double)total];
		[progressIndicator setDoubleValue:(double)(total - remaining)];
	}
	
	//
	// If the step that just finished was selected, advance the selection to the
	// next running step
	//
	if ([stepsController selectionIndex] == lastKnowStepIndex &&
		remaining != 0)
	{
		[stepsController setSelectionIndex:total - remaining];
	}
	lastKnowStepIndex = total - remaining;
}

//
// cancel:
//
// Cancels the queue (if operations count is > 0) and waits for all operations
// to be cleared correctly.
// If operations count == 0, restarts the queue.
//
// Parameters:
//    parameter - this method may be invoked in 3 situations (distinguished by
//		this parameter)
//		1) Notification from the ScriptQueue that cancelAllOperations was invoked
//			(generally due to error)
//		2) NSButton (user action). This may restart the queue.
//		3) nil (when the window controller is being deleted)
//
- (IBAction)cancel:(id)parameter
{
	if ([[scriptQueue operations] count] > 0)
	{
		if ([parameter isKindOfClass:[NSNotification class]])
		{
			state = CocoaScriptQueueFailed;
		}
		else
		{
			state = CocoaScriptQueueCancelled;
		}

		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:ScriptQueueCancelledNotification
			object:scriptQueue];
		[scriptQueue cancelAllOperations];
		while ([[scriptQueue operations] count] > 0)
		{
			[[NSRunLoop currentRunLoop]
				runMode:NSDefaultRunLoopMode
				beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		}
		[scriptQueue clearState];
		[self updateProgressDisplay];
	}
	else if ([parameter isKindOfClass:[NSButton class]])
	{
		[self start];
	}
	else
	{
		state = CocoaScriptQueueFailed;
	}
}

//
// tabButtonChanged:
//
// Switch between the output and error views
//
// Parameters:
//    sender - ignored
//
- (IBAction)tabButtonChanged:(id)sender
{
	NSInteger buttonIndex = [tabButtons selectedColumn];
	[tabView selectTabViewItemAtIndex:buttonIndex];
}

//
// updateTextStorage
//
// Switch between text storages when the selected step changes.
//
- (void)updateTextStorage
{
	NSTextStorage *outputTextStorage = [[[stepsController selectedObjects] lastObject] outputStringStorage];
	
    if (!outputTextStorage)
	{
		outputTextStorage = [[[NSTextStorage alloc] init] autorelease];
	}
	
    NSLayoutManager *outputLayoutManager = [[outputTextView textContainer] layoutManager];
	NSTextStorage *previousOutputTextStorage = [outputLayoutManager textStorage];
	
    if (previousOutputTextStorage != outputTextStorage)
	{
		[outputTextView setSelectedRange:NSMakeRange(0, 0)];
		[[previousOutputTextStorage autorelease] removeLayoutManager:outputLayoutManager];
		[[outputTextStorage retain] addLayoutManager:outputLayoutManager];
	}

	NSTextStorage *errorTextStorage = [[[stepsController selectedObjects] lastObject] errorStringStorage];
    
	if (!errorTextStorage)
	{
		errorTextStorage = [[[NSTextStorage alloc] init] autorelease];
	}
    
	NSLayoutManager *errorLayoutManager = [[errorTextView textContainer] layoutManager];
	NSTextStorage *previousErrorTextStorage = [errorLayoutManager textStorage];
    
	if (previousErrorTextStorage != errorTextStorage)
	{
		[errorTextView setSelectedRange:NSMakeRange(0, 0)];
		[[previousErrorTextStorage autorelease] removeLayoutManager:errorLayoutManager];
		[[errorTextStorage retain] addLayoutManager:errorLayoutManager];
	}
}

//
// awakeFromNib
//
// Set the initial label states and the split view thresholds
//
- (void)awakeFromNib
{
	NSInteger total = [steps count];
	NSInteger remaining = [scriptQueue operationCount];
	[stepsController setSelectionIndex:total - remaining];

	[scriptQueue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
	[self updateProgressDisplay];

	[stepsController addObserver:self forKeyPath:@"selectionIndex" options:0 context:NULL];
	[self updateTextStorage];
	
	[tabButtons selectCellAtRow:0 column:0];
	[collectionView setMinItemSize:NSMakeSize(198, 54)];
	[collectionView setMaxItemSize:NSMakeSize(CGFLOAT_MAX, 54)];

	splitViewDelegate = [[PrioritySplitViewDelegate alloc] init];
	[splitViewDelegate setPriority:2 forViewAtIndex:0];
	[splitViewDelegate setMinimumLength:200 forViewAtIndex:0];
	[splitViewDelegate setPriority:1 forViewAtIndex:1];
	[splitViewDelegate setMinimumLength:200 forViewAtIndex:1];
	[splitView setDelegate:splitViewDelegate];
}

//
// observeValueForKeyPath:ofObject:change:context:
//
// Reponds to changes in the ScriptQueue steps or the selected step
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
	if ([keyPath isEqual:@"operationCount"])
	{
		[self performSelectorOnMainThread:@selector(updateProgressDisplay)
			withObject:nil waitUntilDone:NO];
		return;
	}
	else if ([keyPath isEqual:@"selectionIndex"])
	{
		[self performSelectorOnMainThread:@selector(updateTextStorage)
			withObject:nil waitUntilDone:NO];
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change
		context:context];
}

//
// windowWillClose:
//
// Quit the application when this window closes
//
// Parameters:
//    notification - ignored
//
- (void)windowWillClose:(NSNotification *)notification
{
	[[NSApplication sharedApplication] terminate:nil];
}

//
// windowNibName
//
// returns the name for the window's nib file
//
- (NSString *)windowNibName
{
	return @"CocoaScriptWindow";
}

//
// dealloc
//
// Cancel and cleanup
//
- (void)dealloc
{
	[self cancel:nil];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:ScriptQueueCancelledNotification
		object:scriptQueue];
	[scriptQueue cancelAllOperations];
	[scriptQueue removeObserver:self forKeyPath:@"operationCount"];
	[scriptQueue release];
	scriptQueue = nil;

	[stepsController removeObserver:self forKeyPath:@"selectionIndex"];
	
	[splitViewDelegate release];
	splitViewDelegate = nil;

	[steps release];
	steps = nil;

	[super dealloc];
}

@end
