//
//  CocoaScriptWindowController.h
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

#import <Cocoa/Cocoa.h>

@class ScriptQueue;
@class PrioritySplitViewDelegate;

typedef enum
{
	CocoaScriptQueueRunning,
	CocoaScriptQueueFinished,
	CocoaScriptQueueFailed,
	CocoaScriptQueueCancelled
} CocoaScriptQueueState;

@interface CocoaScriptWindowController : NSWindowController
{
	CocoaScriptQueueState state;
	ScriptQueue *scriptQueue;
	NSArray *steps;
	IBOutlet NSArrayController *stepsController;
	PrioritySplitViewDelegate *splitViewDelegate;
	IBOutlet NSCollectionView *collectionView;
	IBOutlet NSTextField *progressLabel;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSTabView *tabView;
	IBOutlet NSMatrix *tabButtons;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSTextView *outputTextView;
	IBOutlet NSTextView *errorTextView;
	NSInteger lastKnowStepIndex;
}

@property (nonatomic, retain) NSArray *steps;
@property (nonatomic, retain, readonly) ScriptQueue *scriptQueue;

- (id)init;
- (void)start;
- (IBAction)cancel:(id)sender;
- (IBAction)tabButtonChanged:(id)sender;

@end
