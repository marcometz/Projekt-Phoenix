//
//  TaskStep.m
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

#import "TaskStep.h"
#import "TaskHandler.h"
#import "ScriptQueue.h"

@implementation TaskStep

@synthesize outputStateKey;
@synthesize errorStateKey;
@synthesize currentDirectory;
@synthesize environment;
@synthesize launchPath;
@synthesize argumentsArray;
@synthesize outputStringErrorPattern;
@synthesize errorStringErrorPattern;
@synthesize outputStringWarningPattern;
@synthesize errorStringWarningPattern;
@synthesize trimNewlines;

//
// taskStepWithCommandLine:
//
// TaskStep runs a process as a task. The parameters to this method are the
// arguments.
// 
// There are a few options that are possible with TaskStep
//	- it can process the stdout or stderr strings for errors or warnings
//	- you can pipe into another TaskStep (which must be scheduled in the
//		queue ahead of this step)
//	- you can trim newlines off the stdout (useful for many command line
//		processes which output a trailing newline
//	- environement variables and current directory can also be set for the task
//
// Parameters:
//    aLaunchPath - the path to the executable
//    ... - the parameters to the executable
//
// returns the initialized TaskStep
//
+ (TaskStep *)taskStepWithCommandLine:(NSString *)aLaunchPath, ...
{
    NSMutableArray *anArgumentsArray = [[NSMutableArray alloc] init];

    va_list args;
    va_start(args, aLaunchPath);
    for (NSString *arg = va_arg(args, NSString*);
		arg != nil;
		arg = va_arg(args, NSString*))
    {
        [anArgumentsArray addObject:arg];
    }
    va_end(args);

	TaskStep *step = [[[self alloc] init] autorelease];
	step.launchPath = aLaunchPath;
	step.argumentsArray = anArgumentsArray;
	step->taskStartedCondition = [[NSCondition alloc] init];
	
	[anArgumentsArray release];
	
	return step;
}

//
// title
//
// returns the title as a concatenation of the command line
//
- (NSString *)title
{
	NSMutableString *commandLine = [NSMutableString stringWithString:launchPath];
	for (NSString *argument in [self resolvedScriptArrayForArray:argumentsArray])
	{
		[commandLine appendString:@" "];
		[commandLine appendString:argument];
	}
	return commandLine;
}

//
// runStep
//
// Creates the TaskHandler, launches the task, runs until it terminates (or
// this step is cancelled).
//
- (void)runStep
{
	if (self.concurrentStep)
	{
		[NSThread sleepForTimeInterval:5.0];
	}
	taskHandler =
		[[TaskHandler alloc]
			initWithLaunchPath:launchPath
			arguments:[self resolvedScriptArrayForArray:argumentsArray]
			terminationReceiver:self
			selector:@selector(taskComplete:)];
	if (environment)
	{
		[[taskHandler task] setEnvironment:
			[self resolvedScriptDictionaryForDictionary:environment]];
	}
	if (currentDirectory)
	{
		[[taskHandler task] setCurrentDirectoryPath:
			[self resolvedScriptValueForValue:currentDirectory]];
	}
	[taskHandler
		setOutputReceiver:self
		selector:@selector(receiveOutputData:fromTaskHandler:)];
	[taskHandler
		setErrorReceiver:self
		selector:@selector(receiveErrorData:fromTaskHandler:)];
	[taskHandler launch];
	
	[taskStartedCondition lock];
	[taskStartedCondition broadcast];
	[taskStartedCondition unlock];
	
	while (![self isCancelled] && taskHandler)
	{
		[[NSRunLoop currentRunLoop]
			runMode:NSDefaultRunLoopMode
			beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
	}
	
	if ([self isCancelled])
	{
		[taskHandler terminate];
	}
}

//
// receiveInputData:
//
// Push data to the task's stdin (used when piping)
//
// Parameters:
//    data - the data to send to stdin
//
- (void)receiveInputData:(NSData *)data
{
	[taskStartedCondition lock];
	if ([taskHandler taskState] == TaskHandlerNotLaunched)
	{
		while (![taskStartedCondition
			waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]])
		{
			if ([self isCancelled])
			{
				return;
			}
		}
	}
	[taskStartedCondition unlock];
	[taskHandler appendInputData:data];
}

//
// receiveOutputData:fromTaskHandler:
//
// Invoked from the TaskHandler when data is received on stdout. Data is
// appended to the output string.
//
// Parameters:
//    data - the stdout data
//    handler - the TaskHandler
//
- (void)receiveOutputData:(NSData *)data fromTaskHandler:(TaskHandler *)handler
{
	NSString *newString =
		[[[NSString alloc]
			initWithData:data
			encoding:NSUTF8StringEncoding]
		autorelease];
	if (newString)
	{
		[self appendOutputString:newString];
	}
	
	[outputPipe receiveInputData:data];
}

//
// receiveErrorData:fromTaskHandler:
//
// Invoked from the TaskHandler when data is received on stderr. Data is
// appended to the error string.
//
// Parameters:
//    data - the stderr data
//    handler - the TaskHandler
//
- (void)receiveErrorData:(NSData *)data fromTaskHandler:(TaskHandler *)handler
{
	NSString *newString =
		[[[NSString alloc]
			initWithData:data
			encoding:NSUTF8StringEncoding]
		autorelease];
	
	if (newString)
	{
		[self appendErrorString:newString];
	}
	
	[errorPipe receiveInputData:data];
}

//
// pipeErrorInto:
//
// Configures this step to pipe its stderr into another TaskStep. The other
// TaskStep should be added to the queue *before* this one
//
// Parameters:
//    destination - the destination of the pipe
//
- (void)pipeErrorInto:(TaskStep *)destination
{
	[errorPipe autorelease];
	errorPipe = [destination retain];
	errorPipe.concurrentStep = self;
}

//
// pipeOutputInto:
//
// Configures this step to pipe its stdout into another TaskStep. The other
// TaskStep should be added to the queue *before* this one
//
// Parameters:
//    destination - the destination of the pipe
//
- (void)pipeOutputInto:(TaskStep *)destination
{
	[outputPipe autorelease];
	outputPipe = [destination retain];
	outputPipe.concurrentStep = self;
}

//
// parseWarningsAndErrors
//
// Performs line-by-line parsing of the stderr and stdout. Each line is
// compared to the error and warning patterns to see if there are any errors
// or warnings for this task.
//
- (void)parseWarningsAndErrors
{
	NSInteger errors = 0;
	NSInteger warnings = 0;
	
	if (outputStringErrorPattern || outputStringWarningPattern)
	{
		NSPredicate *errorPredicate = [NSComparisonPredicate
			predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject]
			rightExpression:[NSExpression expressionForConstantValue:outputStringErrorPattern]
			modifier:NSDirectPredicateModifier
			type:NSMatchesPredicateOperatorType
			options:0];
		NSPredicate *warningPredicate = [NSComparisonPredicate
			predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject]
			rightExpression:[NSExpression expressionForConstantValue:outputStringWarningPattern]
			modifier:NSDirectPredicateModifier
			type:NSMatchesPredicateOperatorType
			options:0];
	
		NSString *outputString = [self outputString];

		NSUInteger length = [outputString length];
		NSUInteger paraStart = 0;
		NSUInteger paraEnd = 0;
		NSUInteger contentsEnd = 0;
		NSRange currentRange;
		while (paraEnd < length)
		{
			[outputString
				getParagraphStart:&paraStart
				end:&paraEnd
				contentsEnd:&contentsEnd
				forRange:NSMakeRange(paraEnd, 0)];
			currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
			NSString *paragraph = [outputString substringWithRange:currentRange];

			if ([errorPredicate evaluateWithObject:paragraph])
			{
				[self applyErrorAttributesToOutputStringStorageRange:currentRange];
				errors++;
			}
			else if ([warningPredicate evaluateWithObject:paragraph])
			{
				[self applyWarningAttributesToOutputStringStorageRange:currentRange];
				warnings++;
			}
		}
	}

	if (errorStringErrorPattern || errorStringWarningPattern)
	{
		NSPredicate *errorPredicate = [NSComparisonPredicate
			predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject]
			rightExpression:[NSExpression expressionForConstantValue:errorStringErrorPattern]
			modifier:NSDirectPredicateModifier
			type:NSMatchesPredicateOperatorType
			options:0];
		NSPredicate *warningPredicate = [NSComparisonPredicate
			predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject]
			rightExpression:[NSExpression expressionForConstantValue:errorStringWarningPattern]
			modifier:NSDirectPredicateModifier
			type:NSMatchesPredicateOperatorType
			options:0];
		
		NSString *errorString = [self errorString];

		NSUInteger length = [errorString length];
		NSUInteger paraStart = 0;
		NSUInteger paraEnd = 0;
		NSUInteger contentsEnd = 0;
		NSRange currentRange;
		while (paraEnd < length)
		{
			[errorString
				getParagraphStart:&paraStart
				end:&paraEnd
				contentsEnd:&contentsEnd
				forRange:NSMakeRange(paraEnd, 0)];
			currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
			NSString *paragraph = [errorString substringWithRange:currentRange];

			if ([errorPredicate evaluateWithObject:paragraph])
			{
				[self applyErrorAttributesToErrorStringStorageRange:currentRange];
				errors++;
			}
			else if ([warningPredicate evaluateWithObject:paragraph])
			{
				[self applyWarningAttributesToErrorStringStorageRange:currentRange];
				warnings++;
			}
		}
	}
	
	self.errorCount = errors;
	self.warningCount = warnings;
}

//
// taskComplete:
//
// Invoked when the task is terminated and both stderr and stdout are closed.
//
// Closes pipes, saves outputs, trims newlines, sets errors, etc.
//
// Parameters:
//    aTaskHandler - the TaskHandler running the task
//
- (void)taskComplete:(TaskHandler *)aTaskHandler
{
	[outputPipe receiveInputData:nil];
	[errorPipe receiveInputData:nil];
	
	if (outputStateKey)
	{
		NSString *string = [self outputString];
		if (trimNewlines)
		{
			string = [string stringByTrimmingCharactersInSet:
				[NSCharacterSet newlineCharacterSet]];
		}
		
		[currentQueue setStateValue:string forKey:outputStateKey];
	}
	if (errorStateKey)
	{
		[currentQueue setStateValue:[self errorString] forKey:errorStateKey];
	}
	
	if (aTaskHandler.taskState == TaskHandlerCouldNotBeLaunched)
	{
		NSString *message =
			[NSString stringWithFormat:
				NSLocalizedString(@"Could not launch task %@", ""),
				[self title]];
		[self replaceAndApplyErrorToErrorString:message];
	}
	else
	{
		[self parseWarningsAndErrors];
	}

	[taskHandler release];
	taskHandler = nil;
}

//
// dealloc
//
// Release instance data.
//
- (void)dealloc
{
	[taskStartedCondition release];
	[taskHandler release];
	[launchPath release];
	[argumentsArray release];
	[environment release];
	[currentDirectory release];
	[outputStateKey release];
	[errorStateKey release];
	[outputStringErrorPattern release];
	[errorStringErrorPattern release];
	[outputStringWarningPattern release];
	[errorStringWarningPattern release];

	[super dealloc];
}

@end
