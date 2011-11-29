//
//  PathSelectionStep.m
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

#import "PathSelectionStep.h"
#import "ScriptQueue.h"

@implementation PathSelectionStep

//
// pathSelectionStepWithTitle:outputStateKey:allowedFileTypes:allowDirectories:errorIfCancelled:
//
// PathSelectionStep presents an open file dialog. It can choose directories or
// files based on configuration
//
// Parameters:
//    aTitle - title of the open dialog window
//    outputStateKey - state value into which the resulting path is placed
//    types - the array of file extensions to allow (if nil or count==0 then
//		files are not permitted)
//    directories - whether or not to allow directories
//    errorIfCancelled - whether to set an error code if dialog cancelled
//
// returns the constructed step
//
+ (PathSelectionStep *)pathSelectionStepWithTitle:(NSString *)aTitle
	outputStateKey:(NSString *)outputStateKey
	allowedFileTypes:(NSArray *)types
	allowDirectories:(BOOL)directories
	errorIfCancelled:(BOOL)errorIfCancelled
{
	PathSelectionStep *result = (PathSelectionStep *)[self blockStepWithBlock:^(BlockStep *step){
		NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
		[openPanel setTitle:aTitle];
		if (types && [types count] > 0)
		{
			[openPanel setCanChooseFiles:YES];
			[openPanel setAllowedFileTypes:types];
		}
		if (directories)
		{
			[openPanel setCanChooseDirectories:YES];
		}
		
		NSInteger panelResult = [openPanel runModal];
		if (panelResult == NSFileHandlingPanelOKButton)
		{
			NSString *filePath = [[[openPanel URLs] lastObject] path];
			[step.currentQueue
				setStateValue:filePath
				forKey:outputStateKey];
			[step replaceOutputString:filePath];
		}
		else
		{
			NSString *message = NSLocalizedString(@"No path selected.", nil);
			
			if (!errorIfCancelled)
			{
				[step replaceAndApplyWarningToErrorString:message];
			}
			else
			{
				[step replaceAndApplyErrorToErrorString:message];
			}
		}

	}];
	result.runOnMainThread = YES;
	result.title = aTitle;
	
	return result;
}

@end
