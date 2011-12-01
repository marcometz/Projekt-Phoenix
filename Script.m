//
//  Script.m
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

#import "TaskStep.h"
#import "PathSelectionStep.h"
#import "PromptStep.h"
#import "VersionStep.h"
#import "BlockStep.h"
#import "ScriptQueue.h"
#import "UniqueTemporaryDirectory.h"
#import "RegexConditionalStep.h"
#import "ConcatenateStep.h"
#import "CollectionSelectStep.h"

//
// ScriptSteps
//
// returns the array of steps used in the ScriptQueue.
//
NSArray *ScriptSteps()
{
	NSMutableArray *steps = [NSMutableArray array];
    
    [steps addObject:[CollectionSelectStep collectionSelectStepWithTitle:@"Mein Titel" collection:[NSArray arrayWithObjects:@"Erstens", @"Zweitens", nil] outputStateKey:@"arrayOutput"]];
#warning append to string.
    
//    [steps addObject:
//     [BlockStep blockStepWithBlock:^(BlockStep *step) {
//        NSMutableString *gemfile = [NSMutableString stringWithContentsOfFile:[@"~/Desktop/gemfile" stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:nil];
//        NSLog(@"%@", gemfile);
//        [gemfile appendString:@"tolle neue Zeile"];
//        NSLog(@"%@", gemfile);
//    }]];

    //
    // Dialog to name project
    //
    [steps addObject:[PromptStep promptStepWithTitle:@"Project Name"
                                        initialValue:@""
                                      outputStateKey:kIKUProjectName]];
    [[steps lastObject] setTitle:@"Set a project name"];


    //
	// Check if git is installed at /usr/bin/git
	//
	ConditionalStep *gitExists =
    [ConditionalStep conditionalStepWithBlock:^(ConditionalStep *step){
        BOOL isDirectory;
        if ([[NSFileManager defaultManager]
             fileExistsAtPath:@"/usr/bin/git"
             isDirectory:&isDirectory] && !isDirectory)
        {
            [step.currentQueue setStateValue:@"YES" forKey:@"gitExists"];
            [step replaceOutputString:@"YES"];
            return YES;
        }
        [step replaceOutputString:@"NO"];
        return NO;
    }];
	[steps addObject:gitExists];
	[[steps lastObject] setTitle:@"Check if git is installed"];

    //
    // Create an empty directory on the server
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"git@arion",
      @"mkdir",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Create empty project dir on server"];

    //
    // CD into the project directory on the server 
    // and initialize an empty git repository
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"git@arion",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      @"&&",
      @"git init --bare",
      nil]];
	[[steps lastObject] setTitle:@"Create bare git repo on server"];

    //
    // Create a gemset on the server 
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"ikusei@arion",
      @"rvm",
      @"use",
      @"ree-1.8.7-2011.02",
      @"&&",
      @"rvm",
      @"gemset",
      @"create",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Create rvm gemset on server"];

	//
	// Present a dialog to select a local path for the project
	//
	[steps addObject:
     [PathSelectionStep
      pathSelectionStepWithTitle:@"Wo soll das Projekt lokal angelegt werden?"
      outputStateKey:kIKUProjectPath
      allowedFileTypes:nil
      allowDirectories:YES
      errorIfCancelled:YES]];
    [[steps lastObject] setTitle:@"Ask for local path"];

    //
    // Create the path to the repository on the server
    //
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:@"clonePath"
      andStrings:
      @"ssh://git@arion/home/git/",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Create path to repository"];

    //
    // Clone the repository from the server to the local path
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/git",
      @"clone",
      [ScriptValue scriptValueWithKey:@"clonePath"],
      nil]];
    [gitExists addPredicatedStep:[steps lastObject]];

    [[steps lastObject] setCurrentDirectory:
     [ScriptValue scriptValueWithKey:kIKUProjectPath]];
	[[steps lastObject] setTitle:@"Clone repository from server"];

    //
    // Create a reusable scriptValue with the projects directory and path
    //
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:kIKUProjectDirectory
      andStrings:
      [ScriptValue scriptValueWithKey:kIKUProjectPath],
      @"/",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Find project directory"];

    //
	// Check if rvm is installed at ~/.rvm
	//
	ConditionalStep *rvmExists =
    [ConditionalStep conditionalStepWithBlock:^(ConditionalStep *step){
        BOOL isDirectory;
        if ([[NSFileManager defaultManager]
             fileExistsAtPath:[@"~/.rvm" stringByExpandingTildeInPath]
             isDirectory:&isDirectory] && isDirectory)
        {
            [step.currentQueue setStateValue:@"YES" forKey:@"rvmExists"];
            [step replaceOutputString:@"YES"];
            return YES;
        }
        [step replaceOutputString:@"NO"];
        return NO;
    }];
	[steps addObject:rvmExists];
	[[steps lastObject] setTitle:@"Check if rvm is installed"];
    
    //
    // Use AppleScript to switch the ruby to 1.8.7 without changing the default ruby version
    // Create a gemset with the project name
    // install rails 3.x
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      [@"~/.rvm/bin/rvm" stringByExpandingTildeInPath],
      @"use",
      @"1.8.7",
      @"&&",
      [@"~/.rvm/bin/rvm" stringByExpandingTildeInPath],
      @"gemset",
      @"create",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Create rvm gemset on server"];

    //
    // Create the input for the .rvmrc file
    //
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:@"rvmrcValue"
      andStrings:
      @"rvm use 1.8.7@",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Set .rvmrc value"];
    
    //
    // Set the right value into .rvmrc
    //
    [steps addObject:
     [BlockStep blockStepWithBlock:^(BlockStep *step) {
        [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@", [step.currentQueue stateValueForKey:kIKUProjectDirectory]]
                                                contents:[[NSString stringWithFormat:@"%@", [step.currentQueue stateValueForKey:@"rvmrcValue"]] dataUsingEncoding:NSUTF8StringEncoding] 
                                              attributes:nil];
        
    }]];

    //
    // Create the input for the .rvmrc file
    //
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:@"gemsetValue"
      andStrings:
      [NSString stringWithFormat:@"%@ use 1.8.7@", [@"~/.rvm/bin/rvm" stringByExpandingTildeInPath]],
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
	[[steps lastObject] setTitle:@"Set .rvmrc value"];

    //
    // Install rails
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      [ScriptValue scriptValueWithKey:@"gemsetValue"],
      @"exec",
      @"gem",
      @"install",
      @"rails",
      @"--no-rdoc",
      @"--no-ri",
      nil]];
	[[steps lastObject] setTitle:@"install rails"];

    //
    // Bundle install
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      [ScriptValue scriptValueWithKey:@"gemsetValue"],
      @"exec",
      @"bundle",
      @"install",
      nil]];
	[[steps lastObject] setTitle:@"bundle install"];

    //
    // Create a new rails app in the project dir with MySQL as database
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      [ScriptValue scriptValueWithKey:@"gemsetValue"],
      @"exec",
      @"bundle",
      @"exec",
      @"rails",
      @"new",
      @".",
      @"-d",
      @"mysql",
      nil]];
	[[steps lastObject] setTitle:@"create new rails app"];

#pragma mark - Masterfiles
    //
    // Fetch masterfile-templates from github git://github.com/ikuseiGmbH/masterfiles.git
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/git",
      @"clone",
      @"git://github.com/ikuseiGmbH/masterfiles.git",
      nil]];
	[[steps lastObject] setTitle:@"Checkout master templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectPath]];

    //
    // Create the input for the .rvmrc file
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:kIKUMasterFilesPath andStrings:[ScriptValue scriptValueWithKey:kIKUProjectDirectory], @"/../masterfiles/templates/", nil]];
	[[steps lastObject] setTitle:@"Build path to masterfiles"];

#pragma mark - .gitignore
    //
    // Customize the templates
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/.gitignore.tmpl",
      @".gitignore",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/capistrano.tmpl",
      @"deploy.rb",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"project_name-sed" andStrings:@"'s/project_name/", [ScriptValue scriptValueWithKey:kIKUProjectName],@"/g'", nil]];
	[[steps lastObject] setTitle:@"capistrano text replacements"];
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"config/deploy.rb",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

#pragma mark - Database YML
    //
    // Copy database tmpl
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/database.yml.tmpl",
      @"config/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    //
    // Replace project_name with real project name
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"config/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];

    //
    // Prompt the user to choose a password
    //
    [steps addObject:
     [PromptStep promptStepWithTitle:@"Please choose a password for the database"
                        initialValue:@""
                      outputStateKey:kIKUDBPassword]];
    [[steps lastObject] setTitle:@"Choose DB password"];
    
    //
    // Replace db_password with proper password
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"database-sed2" andStrings:@"'s/db_password/", [ScriptValue scriptValueWithKey:kIKUDBPassword],@"/g'", nil]];
	[[steps lastObject] setTitle:@"Database text replacements"];
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

#pragma mark - Server Templates
    //
    // Server templates #1
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/server_templates/create_database.yml",
      @"config/templates/create_database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    //
    // Replace project_name with real project name
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"config/templates/create_database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/templates/create_database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/gemfile.plist",
      @"GEMFILE.plist",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    //
    // Server templates #2
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/server_templates/database.yml",
      @"config/templates/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    //
    // Replace project_name with real project name
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"config/templates/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/templates/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
#pragma mark - Gemfile
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/gemfile.plist",
      @"GEMFILE.plist",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    /*
 
 <VirtualHost *:80>    
 ServerName mercedes.ikusei.de    
 DocumentRoot /home/ikusei/mercedes_charity/current/public    
 RackBaseURI /    
 <Directory /home/ikusei/mercedes_charity/public>       
 AllowOverride all       
 Options -MultiViews   
 </Directory>
 </VirtualHost>

 */

    
#warning Cleanup im dev mode
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"git@arion",
      @"rm -R",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/rm",
      @"-Rf",
      [ScriptValue scriptValueWithKey:kIKUProjectName],
      nil]];
    [[steps lastObject] setCurrentDirectory:
     [ScriptValue scriptValueWithKey:kIKUProjectPath]];

    


//    //
//	// Get the path of the directory that contains the xcodeproj file
//	//
//	[steps addObject:
//		[TaskStep taskStepWithCommandLine:
//			@"/usr/bin/dirname",
//			[ScriptValue scriptValueWithKey:kIKUProjectPath], 
//         nil]];
//	[[steps lastObject] setTrimNewlines:YES];
//	[[steps lastObject] setOutputStateKey:@"xcodeDirectory"];
//
//	//
//	// Get the project name minus filename extension
//	//
//	// NOTE: we presume a few things related to this name.
//	//
//	// 1) The default target in the project has the same name as the project
//	// 2) The Info.plist is named <projectname>-Info.plist
//	// 3) The application built by the project is named <projectname>.app
//	//
//	// These points are true of the Cocoa Application Template I used for this
//	// project but your mileage may vary.
//	//
//	[steps addObject:
//		[TaskStep taskStepWithCommandLine:
//			@"/usr/bin/basename",
//			@"-s",
//			@".xcodeproj",
//			[ScriptValue scriptValueWithKey:@"xcodeProjectPath"],
//		nil]];
//	[[steps lastObject] setTrimNewlines:YES];
//	[[steps lastObject] setOutputStateKey:@"xcodeProjectName"];
	
	
	//
	// Check that the project is fully committed into git
	//
	// Error if there are uncommitted, modified or added files waiting to be
	// committed. However, no error if git has a different kind of fatal error.
	//
	// This step is "predicated" on whether git exists (i.e. only runs if the
	// gitExists conditional returns YES)
	//
/*	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/git",
			@"status",
			@"-s",
		nil]];
	[[steps lastObject] setCurrentDirectory:
		[ScriptValue scriptValueWithKey:@"xcodeDirectory"]];
	[[steps lastObject] setOutputStringErrorPattern:@"(\\?\\?| M|A | D).*"];
	[[steps lastObject] setErrorStringErrorPattern:@".+"];
	[gitExists addPredicatedStep:[steps lastObject]];
	
	//
	// Build the path to the Info.plist file to use with the version updating
	// actions
	//
	[steps addObject:
		[ConcatenateStep
			concatenateStepWithOutputKey:@"infoPlistPath"
			andStrings:
				[ScriptValue scriptValueWithKey:@"xcodeDirectory"],
				@"/",
				[ScriptValue scriptValueWithKey:@"xcodeProjectName"],
				@"-Info.plist",
		nil]];

	//
	// Get the existing CFBundleVersion from the info plist file
	//
	[steps addObject:
		[VersionStep
			versionStepWithPath:[ScriptValue scriptValueWithKey:@"infoPlistPath"]
			inputStateKey:nil
			outputStateKey:@"currentVersion"]];

	//
	// Prompt for a new version string
	//
	[steps addObject:
		[PromptStep
			promptStepWithTitle:@"Enter the version number"
			initialValue:[ScriptValue scriptValueWithKey:@"currentVersion"]
			outputStateKey:@"versionNumber"]];

	//
	// Update the version string
	//
	[steps addObject:
		[VersionStep
			versionStepWithPath:[ScriptValue scriptValueWithKey:@"infoPlistPath"]
			inputStateKey:@"versionNumber"
			outputStateKey:nil]];
	
	//
	// Generate a commit message for committing the updated Info.plist file
	//
	[steps addObject:
		[ConcatenateStep
			concatenateStepWithOutputKey:@"commitMessage"
			andStrings:
				@"Updated Info.plist to version ",
				[ScriptValue scriptValueWithKey:@"versionNumber"],
		nil]];

	//
	// Commit the udpated Info.plist file.
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/git",
			@"commit",
			@"-m",
			[ScriptValue scriptValueWithKey:@"commitMessage"],
			[ScriptValue scriptValueWithKey:@"infoPlistPath"],
		nil]];
	[[steps lastObject] setErrorStringErrorPattern:@"fatal:.*"];
	[[steps lastObject] setErrorStringWarningPattern:@".+"];
	[[steps lastObject] setCurrentDirectory:
		[ScriptValue scriptValueWithKey:@"xcodeDirectory"]];
	[gitExists addPredicatedStep:[steps lastObject]];

	//
	// Clean the Release build
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/xcodebuild",
			@"-configuration",
			@"Release",
			@"-target",
			[ScriptValue scriptValueWithKey:@"xcodeProjectName"],
			@"clean",
		nil]];
	[[steps lastObject] setCurrentDirectory:
		[ScriptValue scriptValueWithKey:@"xcodeDirectory"]];

	//
	// Build the Release build
	//
	// (Check for build errors and warnings)
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/xcodebuild",
			@"-configuration",
			@"Release",
			@"-target",
			[ScriptValue scriptValueWithKey:@"xcodeProjectName"],
			@"build",
		nil]];
	[[steps lastObject] setCurrentDirectory:
		[ScriptValue scriptValueWithKey:@"xcodeDirectory"]];
	[[steps lastObject] setOutputStringErrorPattern:@".* error:.*"];
	[[steps lastObject] setOutputStringWarningPattern:@".* (warning|note):.*"];
	
	//
	// Generate a tag name from the version number
	//
	[steps addObject:
		[ConcatenateStep
			concatenateStepWithOutputKey:@"tagName"
			andStrings:
				@"version-",
				[ScriptValue scriptValueWithKey:@"versionNumber"],
		nil]];
	[gitExists addPredicatedStep:[steps lastObject]];

	//
	// Tag the git repository with the version number
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/git",
			@"tag",
			@"-f",
			[ScriptValue scriptValueWithKey:@"tagName"],
		nil]];
	[[steps lastObject] setErrorStringErrorPattern:@"fatal:.*"];
	[[steps lastObject] setErrorStringWarningPattern:@".+"];
	[[steps lastObject] setCurrentDirectory:
		[ScriptValue scriptValueWithKey:@"xcodeDirectory"]];
	[gitExists addPredicatedStep:[steps lastObject]];

	//
	// Create a step that will run if the build is aborted from this point.
	// This step is added to the queue at runtime inside the next block.
	//
	TaskStep *cleanupTempDirectoryStep = 
		[TaskStep taskStepWithCommandLine:
			@"/bin/rm",
			@"-Rf",
			[ScriptValue scriptValueWithKey:@"tempDirectory"],
		nil];
	
	//
	// Create the directory tree for the disk image in a temporary directory
	//
	[steps addObject:
		[BlockStep blockStepWithBlock:^(BlockStep *step){
			//
			// Create a unique temp directory to work in
			//
			NSString *tempDirectory = UniqueTemporaryDirectory();
			[step.currentQueue
				setStateValue:tempDirectory
				forKey:@"tempDirectory"];
			[step replaceOutputString:tempDirectory];
			
			//
			// Now that the tempDirectory is created, add the temp directory
			// cleanup step in case the queue is cancelled
			//
			[step.currentQueue addCleanupStep:cleanupTempDirectoryStep];
			
			//
			// Create the paths we need
			//
			NSString *diskImageSourcePath = [tempDirectory stringByAppendingPathComponent:
					[step.currentQueue stateValueForKey:@"xcodeProjectName"]];
			[step.currentQueue
				setStateValue:diskImageSourcePath
				forKey:@"diskImageSourcePath"];
			[step.currentQueue
				setStateValue:[diskImageSourcePath stringByAppendingString:@"-rw.dmg"]
				forKey:@"diskImageReadWritePath"];
			[step.currentQueue
				setStateValue:[[[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]
					stringByAppendingPathComponent:[step.currentQueue stateValueForKey:@"xcodeProjectName"]]
						stringByAppendingString:@".dmg"]
				forKey:@"diskImageDestinationPath"];
			
			//
			// Create directory inside the temp directory that will actually
			// be the disk image folder.
			//
			NSError *error = nil;
			BOOL success = [[NSFileManager defaultManager]
				createDirectoryAtPath:diskImageSourcePath
				withIntermediateDirectories:NO
				attributes:nil
				error:&error];
			if (!success || error)
			{
				[step replaceAndApplyErrorToErrorString:[error localizedDescription]];
				return;
			}

			//
			// Copy the application into the disk image path
			//
			NSString *buildPath = [[[[step.currentQueue stateValueForKey:@"xcodeDirectory"]
				stringByAppendingPathComponent:@"build/Release"]
					stringByAppendingPathComponent:[step.currentQueue stateValueForKey:@"xcodeProjectName"]]
						stringByAppendingString:@".app"];
			NSString *tempCopy = [[diskImageSourcePath
					stringByAppendingPathComponent:[step.currentQueue stateValueForKey:@"xcodeProjectName"]]
						stringByAppendingString:@".app"];
			success = [[NSFileManager defaultManager]
				copyItemAtPath:buildPath
				toPath:tempCopy
				error:&error];
			if (!success || error)
			{
				[[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:NULL];
				[step replaceAndApplyErrorToErrorString:[error localizedDescription]];
				return;
			}

			//
			// Create a symlink to the /Applications folder in the disk image
			// (this will be used to prompt the user to "install" the application)
			//
			NSString *applicationSymLink =
				[diskImageSourcePath stringByAppendingPathComponent:@"Applications"];
			success = [[NSFileManager defaultManager]
				createSymbolicLinkAtPath:applicationSymLink
				withDestinationPath:@"/Applications"
				error:&error];
			if (!success || error)
			{
				[[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:NULL];
				[step replaceAndApplyErrorToErrorString:[error localizedDescription]];
				return;
			}

			//
			// If a background.png file exists in the project's folder, copy
			// that into the disk image folder too (it will be used for the
			// disk image folder background)
			//
			NSString *sourceBackgroundPath =
				[[step.currentQueue stateValueForKey:@"xcodeDirectory"]
					stringByAppendingPathComponent:@"background.png"];
			NSString *diskImageBackgroundPath =
				[diskImageSourcePath stringByAppendingPathComponent:@"background.png"];
			BOOL isDirectory;
			if ([[NSFileManager defaultManager]
				fileExistsAtPath:sourceBackgroundPath
				isDirectory:&isDirectory] && !isDirectory)
			{
				[step.currentQueue
					setStateValue:diskImageBackgroundPath
					forKey:@"diskImageBackgroundPath"];
				[[NSFileManager defaultManager]
					copyItemAtPath:sourceBackgroundPath
					toPath:diskImageBackgroundPath
					error:&error];
				if (error)
				{
					[[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:NULL];
					[step replaceAndApplyErrorToErrorString:[error localizedDescription]];
					return;
				}
			}
		}]];
	[[steps lastObject] setTitle:@"Create the disk image source folder"];

	//
	// Create a read-write disk image from the diskImageSourcePath (piping
	// output into the next step).
	//
	TaskStep *hdiutilTask =
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/hdiutil",
			@"create",
			@"-srcfolder",
			[ScriptValue scriptValueWithKey:@"diskImageSourcePath"],
			@"-format",
			@"UDRW",
			@"-attach",
			[ScriptValue scriptValueWithKey:@"diskImageReadWritePath"],
		nil];
	[steps addObject:hdiutilTask];
	[[steps lastObject] setErrorStringErrorPattern:@".+"];

	//
	// This is the destination of the pipe operation
	//
	// This step processes the hdiutil output to find the name of the volume
	// directory where the disk image is attached
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/sed",
			@"-n",
			@"s/.*\\(\\/Volumes\\/.*\\)/\\1/p",
		nil]];
	[[steps lastObject] setTrimNewlines:YES];
	[[steps lastObject] setOutputStateKey:@"volumeMountPath"];

	//
	// Connect the pipe
	//
	[hdiutilTask pipeOutputInto:[steps lastObject]];

	//
	// From this point onwards, we need another cleanup step -- we need to
	// unmount the disk image if we are aborted.
	//
	// We push the cleanup step onto the front of the queue's cleanup steps
	// at runtime (in the start of the next block)
	//
	TaskStep *cleanupDiskImageStep =
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/hdiutil",
			@"eject",
			[ScriptValue scriptValueWithKey:@"volumeMountPath"],
		nil];

	//
	// Use Applescript to set the desired arrangement/layout of the disk image's
	// folder. We need to do this on the mounted read-write disk image (not
	// the source folder) because view settings of the source folder are not
	// copied.
	//
	// NOTE: I couldn't be bothered calculating positions based on the backgroud
	// image's actual size, so the background image is presumed to be 400x300px
	// and the folder and icons are sized/placed accordingly.
	//
	[steps addObject:
		[BlockStep blockStepWithBlock:^(BlockStep *step){
			[step.currentQueue pushCleanupStep:cleanupDiskImageStep];

			BOOL backgroundImageExists =
				[[step.currentQueue
					stateValueForKey:@"diskImageBackgroundPath"] length] > 0;
			NSAppleScript* applescript = [[[NSAppleScript alloc] initWithSource:
				[NSString stringWithFormat:
					@"tell application \"Finder\"\n"
					@"  open (\"%@\" as POSIX file)\n"
					@"	set statusbar visible of front window to false\n"
					@"	set toolbar visible of front window to false\n"
					@"	set view_options to the icon view options of front window\n"
					@"	set icon size of view_options to 96\n"
					@"	set arrangement of view_options to not arranged\n"
					@"	set the bounds of front window to {100, 100, 500, 400}\n"
					@"	set app_icon to item \"%@\" of front window\n"
					@"	set app_folder to item \"Applications\" of front window\n"
					@"	%@"
					@"	%@"
					@"	%@"
					@"	set position of app_icon to {120, 100}\n"
					@"	set position of app_folder to {280, 100}\n"
					@"	set current view of front window to icon view\n"
					@"end tell\n",
					[step.currentQueue stateValueForKey:@"volumeMountPath"],
					[[step.currentQueue stateValueForKey:@"xcodeProjectName"] stringByAppendingString:@".app"],
					backgroundImageExists ? @"set background_image to item \"background.png\" of front window\n" : @"",
					backgroundImageExists ? @"set background picture of view_options to item \"background.png\" of front window\n" : @"",
					backgroundImageExists ? @"set position of background_image to {200, 200}\n" : @""]]
				autorelease];
			NSDictionary *errorDict = nil;
			[applescript executeAndReturnError:&errorDict];
			if (errorDict)
			{
				[step replaceAndApplyErrorToErrorString:[errorDict description]];
				return;
			}
		}]];
	[[steps lastObject] setTitle:@"AppleScript: configure disk image folder settings."];
	
	//
	// If the diskImageBackgroundPath exists then we need to set the background
	// image to be invisible
	//
	RegexConditionalStep *backgroundImageConditional =
		[RegexConditionalStep
			regexConditionalStepWithStateKey:@"diskImageBackgroundPath"
			pattern:@".+"
			negate:NO];
	[steps addObject:backgroundImageConditional];
	
	//
	// Generate a path to the background image on the mounted volume
	//
	[steps addObject:
		[ConcatenateStep
			concatenateStepWithOutputKey:@"volumeMountBackgroundPath"
			andStrings:
				[ScriptValue scriptValueWithKey:@"volumeMountPath"],
				@"/background.png",
		nil]];

	//
	// Make the background image invisible
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/SetFile",
			@"-a",
			@"V",
			[ScriptValue scriptValueWithKey:@"volumeMountBackgroundPath"],
		nil]];
	[[steps lastObject] setErrorStringErrorPattern:@".+"];
	[backgroundImageConditional addPredicatedStep:[steps lastObject]];

	//
	// We're done with the disk image, so we remove the cleanup step for the
	// disk image from the list of cleanup steps and instead insert it into
	// the queue for immediate execution.
	//
	// This cleanup (eject) needs to happen before the hdiutil convert step
	// that happens next, so we are careful to block the dependents of this
	// step (i.e. the next step) until the cleanup has finished
	//
	[steps addObject:
		[BlockStep blockStepWithBlock:^(BlockStep *step){
			[step.currentQueue removeCleanupStep:cleanupDiskImageStep];
			[step.currentQueue
				insertStepToRunImmediately:cleanupDiskImageStep
				blockingDependentsOfStep:step];
		}]];
	[[steps lastObject] setTitle:@"Clean up the disk image."];
	
	//
	// Convert the readwrite disk image to a BZ2 compressed disk image on
	// the Desktop (this will fail if a file already exists at the destination)
	//
	[steps addObject:
		[TaskStep taskStepWithCommandLine:
			@"/usr/bin/hdiutil",
			@"convert",
			[ScriptValue scriptValueWithKey:@"diskImageReadWritePath"],
			@"-format",
			@"UDBZ",
			@"-o",
			[ScriptValue scriptValueWithKey:@"diskImageDestinationPath"],
		nil]];
	[[steps lastObject] setErrorStringErrorPattern:@".+"];
	
	//
	// Run the cleanup step for the temporary directory
	//
	[steps addObject:
		[BlockStep blockStepWithBlock:^(BlockStep *step){
			[step.currentQueue removeCleanupStep:cleanupTempDirectoryStep];
			[step.currentQueue insertStepToRunImmediately:cleanupTempDirectoryStep
				blockingDependentsOfStep:nil];
		}]];
	[[steps lastObject] setTitle:@"Clean up the temp folder."];
*/	
	return steps;
}
