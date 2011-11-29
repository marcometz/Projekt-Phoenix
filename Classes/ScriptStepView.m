//
//  ScriptStepView.m
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

#import "ScriptStepView.h"


@implementation ScriptStepView

@synthesize state;
@synthesize selected;

//
// initWithCoder:
//
// When views uses by CollectionViewItems are duplication, the IBOutlets are
// not reconnected. This implementation of initWithCoder ensures that the
// IBOutlets we need are reconnected.
//
// Parameters:
//    decoder - the coder
//
// returns the initialized view (with our outlets set)
//
- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	if (self)
	{
	    progressIndicator = [decoder decodeObjectForKey:@"progressIndicator"];
	    imageView = [decoder decodeObjectForKey:@"imageView"];
	    errorsWarningsLabel = [decoder decodeObjectForKey:@"errorsWarningsLabel"];
	}
	return self;
}

//
// encodeWithCoder:
//
// Preserve IBOutlets we require across archiving/dearchiving
//
// Parameters:
//    encoder - the coder
//
- (void)encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeObject:progressIndicator forKey:@"progressIndicator"];
    [encoder encodeObject:imageView forKey:@"imageView"];
    [encoder encodeObject:errorsWarningsLabel forKey:@"errorsWarningsLabel"];
}

//
// setSelected:
//
// Overridden to ensure that the view is updated when its selection state
// changes.
//
// Parameters:
//    flag - the new selection state
//
- (void)setSelected:(BOOL)flag
{
	selected = flag;
	[self setNeedsDisplay:YES];
}

//
// setState:
//
// Update the state and visibility of elements, images and whatever. 
//
// Parameters:
//    newState - the state to apply
//
- (void)setState:(ScriptStepState)newState
{
	if (newState == ScriptStepActive && state != ScriptStepActive)
	{
		[progressIndicator setHidden:NO];
		[progressIndicator startAnimation:self];
	}
	else if (state == ScriptStepActive && newState != ScriptStepActive)
	{
		[progressIndicator setHidden:YES];
		[progressIndicator stopAnimation:nil];
	}
	
	if (newState == ScriptStepSuccess)
	{
		[imageView setImage:[NSImage imageNamed:@"checkmark"]];
		[imageView setHidden:NO];
		[errorsWarningsLabel setHidden:YES];
	}
	else if (newState == ScriptStepFailed)
	{
		[imageView setImage:[NSImage imageNamed:@"cross"]];
		[imageView setHidden:NO];
		[errorsWarningsLabel setHidden:NO];
	}
	else if (newState == ScriptStepSuccessWithWarnings)
	{
		[imageView setImage:[NSImage imageNamed:@"warn"]];
		[imageView setHidden:NO];
		[errorsWarningsLabel setHidden:NO];
	}
	else // cancelled and pending
	{
		[imageView setHidden:YES];
		[errorsWarningsLabel setHidden:YES];
	}

	state = newState;

	[self setNeedsDisplay:YES];
}

//
// setErrorsWarningsString:
//
// Update the label. Invoked from the ScriptStepCollectionViewItem
//
// Parameters:
//    string - the label to apply
//
- (void)setErrorsWarningsString:(NSString *)string
{
	[errorsWarningsLabel setStringValue:string];
}

//
// currentGradientColors
//
// returns orange-y colors when active, otherwise gray colors
//
- (NSArray *)currentGradientColors
{
	if (state == ScriptStepActive)
	{
		return [NSArray arrayWithObjects:
			[NSColor colorWithDeviceRed:1.0 green:0.70 blue:0.0 alpha:1.0],
			[NSColor colorWithDeviceRed:1.0 green:0.85 blue:0.0 alpha:1.0],
		nil];
	}
	
	return [NSArray arrayWithObjects:
		[NSColor colorWithDeviceWhite:0.80 alpha:1.0],
		[NSColor colorWithDeviceWhite:0.98 alpha:1.0],
	nil];
}

//
// drawRect:
//
// Draw the background of the view using a round rect, some gradients and a
// shadow. The gradient colors are dependent on the "state"
//
// Parameters:
//    rect - the area to update
//
- (void)drawRect:(NSRect)rect
{
	NSBezierPath *frame = [NSBezierPath
		bezierPathWithRoundedRect:NSOffsetRect(NSInsetRect([self bounds], 2.5, 2.5), -1, 1)
		xRadius:4
		yRadius:4];

	NSArray *gradientColors = [self currentGradientColors];
	
	if (selected && state != ScriptStepActive)
	{
		gradientColors = [NSArray arrayWithObjects:
			[[gradientColors objectAtIndex:0] blendedColorWithFraction:0.4 ofColor:[NSColor selectedControlColor]],
			[[gradientColors objectAtIndex:1] blendedColorWithFraction:0.4 ofColor:[NSColor selectedControlColor]],
		nil];
	}

	[[NSGraphicsContext currentContext] saveGraphicsState];
	NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0 alpha:0.35]];
	[shadow setShadowOffset:NSMakeSize(1.5, selected ? 0.5 : -1.5)];
	[shadow setShadowBlurRadius:2];
	[shadow set];
	[frame fill];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[frame addClip];
	NSGradient *gradient =
		[[[NSGradient alloc]
			initWithColors:gradientColors]
		autorelease];
	[gradient drawInRect:[self bounds] angle:90];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	[frame setLineWidth:selected ? 1.25 : 1.0];
	[(selected ? [NSColor colorWithDeviceRed:0.5 green:0 blue:0 alpha:1.0] : [NSColor darkGrayColor])
		setStroke];
	[frame stroke];
}

@end
