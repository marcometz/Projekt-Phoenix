//
//  UniqueTemporaryDirectory.m
//  ServeToMe
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

#import "UniqueTemporaryDirectory.h"

NSString *UniqueTemporaryDirectory()
{
	NSString *temporaryDirectory = NSTemporaryDirectory();
	NSString *tempDirectoryTemplate =
		[temporaryDirectory stringByAppendingPathComponent:@"CocoaScript.XXXXXX"];
	const char *tempDirectoryTemplateCString =
		[tempDirectoryTemplate fileSystemRepresentation];
	char *tempDirectoryNameCString =
		(char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
	strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);

	char *result = mkdtemp(tempDirectoryNameCString);
	if (!result)
	{
		NSAlert *alert =
			[NSAlert
				alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"%@ Error", @""),
					[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]]
				defaultButton:NSLocalizedString(@"OK", @"")
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:
					NSLocalizedString(@"Unable to create temporary directory\n\n%s", nil),
					tempDirectoryNameCString];
		[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:NO];
		free(tempDirectoryNameCString);
		return nil;
	}
	
	NSString *tempDirectoryName =
		[NSString stringWithUTF8String:result];
	free(tempDirectoryNameCString);

	return tempDirectoryName;
}
