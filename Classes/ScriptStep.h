//
//  ScriptStep.h
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

@interface ScriptStep : NSOperation
{
	ScriptQueue *currentQueue;
	ScriptStep *concurrentStep;
	NSTextStorage *outputStringStorage;
	NSTextStorage *errorStringStorage;
	NSInteger errorCount;
	NSInteger warningCount;
	NSString *title;
}

@property (copy) NSString *title;
@property (readonly) NSTextStorage *outputStringStorage;
@property (readonly) NSTextStorage *errorStringStorage;
@property (retain) ScriptQueue *currentQueue;
@property (retain) ScriptStep *concurrentStep;
@property (readwrite) NSInteger errorCount;
@property (readwrite) NSInteger warningCount;

- (NSString *)outputString;
- (NSString *)errorString;

- (NSArray *)resolvedScriptArrayForArray:(NSArray *)array;
- (NSDictionary *)resolvedScriptDictionaryForDictionary:(NSDictionary *)dictionary;
- (NSString *)resolvedScriptValueForValue:(id)value;

- (void)appendOutputString:(NSString *)string;
- (void)replaceOutputString:(NSString *)string;

- (void)appendErrorString:(NSString *)string;
- (void)replaceErrorString:(NSString *)string;

- (void)appendAttributedOutputString:(NSAttributedString *)string;
- (void)replaceAttributedOutputString:(NSAttributedString *)string;

- (void)appendAttributedErrorString:(NSAttributedString *)string;
- (void)replaceAttributedErrorString:(NSAttributedString *)string;

- (void)applyErrorAttributesToOutputStringStorageRange:(NSRange)aRange;
- (void)applyWarningAttributesToOutputStringStorageRange:(NSRange)aRange;

- (void)applyErrorAttributesToErrorStringStorageRange:(NSRange)aRange;
- (void)applyWarningAttributesToErrorStringStorageRange:(NSRange)aRange;

- (void)replaceAndApplyErrorToOutputString:(NSString *)string;
- (void)replaceAndApplyWarningToOutputString:(NSString *)string;

- (void)replaceAndApplyErrorToErrorString:(NSString *)string;
- (void)replaceAndApplyWarningToErrorString:(NSString *)string;

@end

@interface ScriptValue : NSObject
{
	NSString *stateKey;
}

@property (nonatomic, copy) NSString *stateKey;
+ (ScriptValue *)scriptValueWithKey:(NSString *)stateKey;
@end
