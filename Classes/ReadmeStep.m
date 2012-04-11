//
//  ReadmeStep.m
//  CocoaScript
//
//  Created by Holger Frohloff on 11.04.12.
//  Copyright (c) 2012 ikusei GmbH. All rights reserved.
//

#import "ReadmeStep.h"

@implementation ReadmeStep
@synthesize textView = _textView;
@synthesize initialValue = _initialValue;

+ (ReadmeStep *)readmeStepWithText:(id)initial;
{
    ReadmeStep *step = [[[self alloc] init] autorelease];
    step.initialValue = initial;
    return step;
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
//	[currentQueue setStateValue:[self.textField stringValue] forKey:outputStateKey];
//	[self replaceOutputString:[self.textField stringValue]];
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
    NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 400, 415) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
    
	NSTextField *titleLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 356, 360, 17)] autorelease];
	[titleLabel setEditable:NO];
	[titleLabel setStringValue:@"Was jetzt zu tun ist."];
	[titleLabel setDrawsBackground:NO];
	[titleLabel setBordered:NO];
	[titleLabel setBezeled:NO];
    [titleLabel setFont:[NSFont boldSystemFontOfSize:16.0]];
	[[panel contentView] addSubview:titleLabel];
	
	self.textView = [[[NSTextView alloc] initWithFrame:NSMakeRect(20, 48, 360, 300)] autorelease];
	[self.textView insertText:[self resolvedScriptValueForValue:self.initialValue]];
	[[panel contentView] addSubview:self.textView];
	
	NSButton *okButton = [[[NSButton alloc] init] autorelease];
	[okButton setBezelStyle:NSRoundedBezelStyle];
	[okButton setButtonType:NSMomentaryPushInButton];
	[okButton setTitle:NSLocalizedString(@"OK", nil)];
	[okButton setFrame:NSMakeRect(296, 12, 90, 24)];
	[okButton setTarget:self];
	[okButton setAction:@selector(ok:)];
	[okButton setKeyEquivalent:@"\r"];
	[[panel contentView] addSubview:okButton];
    
//	NSButton *cancelButton = [[[NSButton alloc] init] autorelease];
//	[cancelButton setBezelStyle:NSRoundedBezelStyle];
//	[cancelButton setButtonType:NSMomentaryPushInButton];
//	[cancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
//	[cancelButton setFrame:NSMakeRect(200, 12, 90, 24)];
//	[cancelButton setTarget:self];
//	[cancelButton setAction:@selector(cancel:)];
//	[cancelButton setKeyEquivalent:@"\e"];
//	[[panel contentView] addSubview:cancelButton];
	
	[[NSApplication sharedApplication] runModalForWindow:panel];
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
    [_textView release], _textView = nil;
	[super dealloc];
}

@end
