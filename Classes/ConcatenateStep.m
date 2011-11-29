//
//  ConcatenateStep.m
//  CocoaScript
//
//  Created by Matt Gallagher on 2010/11/12.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "ConcatenateStep.h"
#import "ScriptQueue.h"

@implementation ConcatenateStep

+ (ConcatenateStep *)concatenateStepWithOutputKey:(NSString *)outputKey
	andStrings:(id)firstString, ...
{
    NSMutableArray *argumentsArray = [[NSMutableArray alloc] init];
	[argumentsArray addObject:firstString];

    va_list args;
    va_start(args, firstString);
    for (NSString *arg = va_arg(args, NSString*);
		arg != nil;
		arg = va_arg(args, NSString*))
    {
        [argumentsArray addObject:arg];
    }
    va_end(args);

	ConcatenateStep *result = (ConcatenateStep *)[self blockStepWithBlock:^(BlockStep *step){
		NSMutableString *concatenation = [NSMutableString string];
		for (NSString *value in argumentsArray)
		{
			NSString *resolvedString = [step resolvedScriptValueForValue:value];
			if ([resolvedString isKindOfClass:[NSString class]])
			{
				[concatenation appendString:resolvedString];
			}
		}
		[step.currentQueue setStateValue:concatenation forKey:outputKey];
		[step replaceOutputString:concatenation];
	}];
	
	result.title =
		[NSString stringWithFormat:NSLocalizedString(@"Generate %@", nil), outputKey];
	
	return result;
}

@end
