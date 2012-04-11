//
//  ReadmeStep.h
//  CocoaScript
//
//  Created by Holger Frohloff on 11.04.12.
//  Copyright (c) 2012 ikusei GmbH. All rights reserved.
//

#import "ScriptStep.h"

@interface ReadmeStep : ScriptStep
@property (retain) NSTextView *textView;
@property (retain) id initialValue;

+ (ReadmeStep *)readmeStepWithText:(id)initial;

@end
