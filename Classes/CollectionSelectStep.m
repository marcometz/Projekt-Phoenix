//
//  CollectionSelectStep.m
//  CocoaScript
//
//  Created by Holger Frohloff on 01.12.11.
//  Copyright (c) 2011 ikusei GmbH. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "CollectionSelectStep.h"
#import "ScriptQueue.h"

@implementation CollectionSelectStep
@synthesize outputStateKey = _outputStateKey;
@synthesize collection = _collection;
@synthesize selection = _selection;
@synthesize inputStateKey = _inputStateKey;

+ (CollectionSelectStep *)collectionSelectStepWithTitle:(NSString *)aTitle collection:(NSArray *)collection outputStateKey:(NSString *)key;
{
    CollectionSelectStep *step = [[[self alloc] init] autorelease];
    step.title = aTitle;
    step.outputStateKey = key;
    step.collection = collection;
    NSLog(@"array wird übergeben: %@", step.collection);
    return step;
}

+ (CollectionSelectStep *)collectionSelectStepWithTitle:(NSString *)aTitle stateKey:(NSString *)stateKey outputStateKey:(NSString *)key;
{
    CollectionSelectStep *step = [[[self alloc] init] autorelease];
    step.title = aTitle;
    step.outputStateKey = key;
    step.inputStateKey = stateKey;
    return step;
}

- (void)recordSelection:(id)sender
{
    [sender state] ? [_selection addObject:[_collection objectAtIndex:[sender tag]]] : [_selection removeObject:[_collection objectAtIndex:[sender tag]]];
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
     setStateValue:self.selection
     forKey:_outputStateKey];
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
    _collection = [[[NSArray alloc] initWithArray:[currentQueue stateValueForKey:_inputStateKey]] autorelease];
    _selection = [[[NSMutableArray alloc] init] autorelease];
    int height = 22 * [_collection count];
    NSPanel *panel =
    [[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 300, [[NSNumber numberWithInt:height] floatValue] + 59 + 17 + 10)
                                styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO]
     autorelease];
    
	NSTextField *titleLabel =
    [[[NSTextField alloc] initWithFrame:NSMakeRect(20, [[NSNumber numberWithInt:height] floatValue] + 59+5, 360, 17)] autorelease];
	[titleLabel setEditable:NO];
	[titleLabel setStringValue:title];
	[titleLabel setDrawsBackground:NO];
	[titleLabel setBordered:NO];
	[titleLabel setBezeled:NO];
	[[panel contentView] addSubview:titleLabel];
	
    [_collection enumerateObjectsUsingBlock:^(NSString *value, NSUInteger idx, BOOL *stop) {
        int height_value = 27 * idx;
        NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 40 + [[NSNumber numberWithInt:height_value] floatValue], 200, 22)] autorelease];
        [button setButtonType:NSSwitchButton];
        [button setTag:idx];
        [button setTitle:value];
        [button setTarget:self];
        [button setAction:@selector(recordSelection:)];
        [[panel contentView] addSubview:button];
    }];
	
	NSButton *okButton = [[[NSButton alloc] init] autorelease];
	[okButton setBezelStyle:NSRoundedBezelStyle];
	[okButton setButtonType:NSMomentaryPushInButton];
	[okButton setTitle:NSLocalizedString(@"OK", nil)];
	[okButton setFrame:NSMakeRect(200, 12, 90, 24)];
	[okButton setTarget:self];
	[okButton setAction:@selector(ok:)];
	[okButton setKeyEquivalent:@"\r"];
	[[panel contentView] addSubview:okButton];
    
	NSButton *cancelButton = [[[NSButton alloc] init] autorelease];
	[cancelButton setBezelStyle:NSRoundedBezelStyle];
	[cancelButton setButtonType:NSMomentaryPushInButton];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", nil)];
	[cancelButton setFrame:NSMakeRect(100, 12, 90, 24)];
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
	[_outputStateKey release], _collection = nil;
    [_collection release], _collection = nil;
	[super dealloc];
}

@end
