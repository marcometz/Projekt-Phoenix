//
//  RegexConditionalStep.m
//  CocoaScript
//
//  Created by Matt Gallagher on 2010/11/04.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "RegexConditionalStep.h"
#import "ScriptQueue.h"

@implementation RegexConditionalStep

//
// regexConditionalStepWithStateKey:pattern:negate:
//
// A simple conditional step that returns YES/NO based on whether a value within
// the ScriptQueue state matches a given pattern.
//
// Parameters:
//    key - the key identifying the queue state value
//    pattern - the regex pattern to match against the state value
//    negate - whether the result should be negated
//
// returns the configured step.
//
+ (RegexConditionalStep *)regexConditionalStepWithStateKey:(NSString *)key
	pattern:(NSString *)pattern
	negate:(BOOL)negate
{
	RegexConditionalStep *result = (RegexConditionalStep *)[self conditionalStepWithBlock:^(ConditionalStep *step){
		BOOL condition = negate;
		NSString *value = [step.currentQueue stateValueForKey:key];
		if ([value length] != 0)
		{
			NSPredicate *predicate = [NSPredicate predicateWithFormat:
				@"self matches %@", pattern];
			if ([predicate evaluateWithObject:value])
			{
				condition = !condition;
			}
		}
		
		[step replaceOutputString:
			[NSString stringWithFormat:
				NSLocalizedString(@"Value tested: %@\n%@", nil),
				value,
				condition ? NSLocalizedString(@"Condition true", nil) :
					NSLocalizedString(@"Condition false", nil)]];

		return condition;
	}];

	result.title = [NSString stringWithFormat:
		NSLocalizedString(@"Test if %@ matches %@\"%@\"", nil),
		key, negate ? @"NOT " : @"", pattern];
	
	return result;
}

@end
