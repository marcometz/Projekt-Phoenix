//
//  PromptStep.m
//  CocoaScript
//
//  Created by Matt Gallagher on 2010/11/03.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "PromptStep.h"
#import "ScriptQueue.h"

@implementation PromptStep

@synthesize initialValue;
@synthesize textField;
@synthesize outputStateKey;

//
// promptStepWithTitle:initialValue:outputStateKey:
//
// PromptStep presents a dialog with a text field. The user can edit the text
// field and press OK or cancel.
//
// Parameters:
//    aTitle - the label presented above the text field
//    initial - the initial value for the text field
//    key - identifies the state value into which the result will be placed
//
// returns the initialized step
//
+ (PromptStep *)promptStepWithTitle:(NSString *)aTitle initialValue:(id)initial outputStateKey:(NSString *)key
{
	PromptStep *step = [[[self alloc] init] autorelease];
	step.title = aTitle;
	step.outputStateKey = key;
	step.initialValue = initial;
	
	return step;
}

//
// cancel:
//
// If cancel is pressed, set an error
//
// Parameters:
//    sender - the cancel button
//
- (void)cancel:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:0];
	NSString *message = NSLocalizedString(@"Prompt window cancelled.", nil);
	[self replaceAndApplyErrorToErrorString:message];
}

//
// ok:
//
// If the OK button is pressed in the panel, set the appropriate state value
// to the string value
//
// Parameters:
//    sender - the button
//
- (void)ok:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:1];
	[currentQueue
		setStateValue:[self.textField stringValue]
		forKey:outputStateKey];
	[self replaceOutputString:[self.textField stringValue]];
}

//
// runPanelOnMainThread
//
// Present the panel and run modal until it is dismissed.
//
// The panel is constructed in code (for no reason I can think of -- XIB would
// have been easier).
//
- (void)runPanelOnMainThread
{
    NSPanel *panel =
		[[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 400, 115)
			styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO]
				autorelease];

	NSTextField *titleLabel =
		[[[NSTextField alloc] initWithFrame:NSMakeRect(20, 78, 360, 17)] autorelease];
	[titleLabel setEditable:NO];
	[titleLabel setStringValue:title];
	[titleLabel setDrawsBackground:NO];
	[titleLabel setBordered:NO];
	[titleLabel setBezeled:NO];
	[[panel contentView] addSubview:titleLabel];
	
	self.textField =
		[[[NSTextField alloc] initWithFrame:NSMakeRect(20, 48, 360, 22)] autorelease];
	[textField setStringValue:[self resolvedScriptValueForValue:initialValue]];
	[[panel contentView] addSubview:textField];
	
	NSButton *okButton = [[[NSButton alloc] init] autorelease];
	[okButton setBezelStyle:NSRoundedBezelStyle];
	[okButton setButtonType:NSMomentaryPushInButton];
	[okButton setTitle:NSLocalizedString(@"OK", nil)];
	[okButton setFrame:NSMakeRect(296, 12, 90, 24)];
	[okButton setTarget:self];
	[okButton setAction:@selector(ok:)];
	[okButton setKeyEquivalent:@"\r"];
	[[panel contentView] addSubview:okButton];

	NSButton *cancelButton = [[[NSButton alloc] init] autorelease];
	[cancelButton setBezelStyle:NSRoundedBezelStyle];
	[cancelButton setButtonType:NSMomentaryPushInButton];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
	[cancelButton setFrame:NSMakeRect(200, 12, 90, 24)];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(cancel:)];
	[cancelButton setKeyEquivalent:@"\e"];
	[[panel contentView] addSubview:cancelButton];
	
	[[NSApplication sharedApplication]
		runModalForWindow:panel];
}

//
// runStep
//
// Run the dialog on the main thread since it requires user interaction.
//
- (void)runStep
{
	[self
		performSelectorOnMainThread:@selector(runPanelOnMainThread)
		withObject:nil
		waitUntilDone:YES];
}

//
// dealloc
//
// Release instance memory
//
- (void)dealloc
{
	[outputStateKey release];
	[textField release];
	[initialValue release];

	[super dealloc];
}

@end
