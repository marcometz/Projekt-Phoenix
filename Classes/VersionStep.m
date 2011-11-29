//
//  VersionStep.m
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

#import "VersionStep.h"
#import "ScriptQueue.h"

@implementation VersionStep

//
// versionStepWithPath:inputStateKey:outputStateKey:
//
// VersionStep is a simple step that gets or sets the value of the
// CFBundleVersion in a specified Info.plist file.
//
// Parameters:
//    aPath - the path to the Info.plist
//    inputKey - the key of a queue state value that will be applied to the
//		CFBundleVersion (may be nil, in which case value remains unchanged)
//    outputKey - will receive the CFBundleVersion (before setting) may be nil
//
// returns the initialized step
//
+ (VersionStep *)versionStepWithPath:(id)aPath
	inputStateKey:(NSString *)inputKey
	outputStateKey:(NSString *)outputKey
{
	VersionStep *result = (VersionStep *)[self blockStepWithBlock:^(BlockStep *step){
		NSString *resolvedPath = [step resolvedScriptValueForValue:aPath];

		NSMutableDictionary *infoPlist =
			[NSMutableDictionary dictionaryWithContentsOfFile:resolvedPath];
		if (!infoPlist)
		{
			NSString *message =
				[NSString stringWithFormat:
					NSLocalizedString(@"Could not open Info.plist at path %@.", nil),
					resolvedPath];
			[step replaceAndApplyErrorToErrorString:message];
			return;
		}
		
		if (outputKey)
		{
			NSString *versionString = [infoPlist valueForKey:@"CFBundleVersion"];
			if (versionString)
			{
				[step.currentQueue
					setStateValue:versionString
					forKey:outputKey];
				[step replaceOutputString:versionString];
			}
		}

		if (inputKey)
		{
			id value = [step.currentQueue stateValueForKey:inputKey];
			if (!value)
			{
				NSString *message = NSLocalizedString(@"Version value must not be nil.", nil);
				[step replaceAndApplyErrorToErrorString:message];
				return;
			}
			
			[infoPlist setObject:value forKey:@"CFBundleVersion"];
		
			if (![infoPlist writeToFile:resolvedPath atomically:YES])
			{
				NSString *message =
					[NSString stringWithFormat:
						NSLocalizedString(@"Could write to Info.plist at path %@.", nil),
						aPath];
				[step replaceAndApplyErrorToErrorString:message];
				return;
			}
		}
	}];
	
	result.title =
		[NSString stringWithFormat:
			inputKey ? NSLocalizedString(@"Update the CFBundleVersion in %@", nil) :
				NSLocalizedString(@"Get the CFBundleVersion from %@", nil), aPath];
	
	return result;
}

@end
