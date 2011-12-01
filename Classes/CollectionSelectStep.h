//
//  CollectionSelectStep.h
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

#import "ScriptStep.h"

@interface CollectionSelectStep : ScriptStep
@property (copy) NSString *outputStateKey;
@property (retain) NSArray *collection;
@property (retain) NSMutableArray *selection;

+ (CollectionSelectStep *)collectionSelectStepWithTitle:(NSString *)aTitle collection:(NSArray *)collection outputStateKey:(NSString *)key;
@end
