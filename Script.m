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
#import "ReadmeStep.h"

//
// ScriptSteps
//
// returns the array of steps used in the ScriptQueue.
//
NSArray *ScriptSteps()
{
	NSMutableArray *steps = [NSMutableArray array];

    
    //
    // Dialog to name project
    //
    [steps addObject:[PromptStep promptStepWithTitle:@"Project Name"
                                        initialValue:@""
                                      outputStateKey:kIKUProjectName]];
    [[steps lastObject] setTitle:@"Set a project name"];

    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSString *serverString =[step.currentQueue stateValueForKey:kIKUProjectName];// = [ScriptValue scriptValueWithKey:kIKUProjectName];
        [step.currentQueue setStateValue:[NSString stringWithString:[serverString lowercaseString]] forKey:@"downcased-projectname"];
    }]];

    //
    // Build Array/List for CollectionSelectStep
    //
    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSArray *serverArray = [NSArray arrayWithObjects:@"arion", @"taurus", nil];
        [step.currentQueue setStateValue:serverArray forKey:@"serverArray"];
    }]];
    
    //
    // Dialog to select server
    //
    CollectionSelectStep *selectServerStep = [CollectionSelectStep collectionSelectStepWithTitle:@"Bitte Server aussuchen" stateKey:@"serverArray" outputStateKey:kIKUServerName];
    [steps addObject:selectServerStep];
    
    
    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSArray *arrayResult = [[[NSArray alloc] initWithArray:[step.currentQueue stateValueForKey:kIKUServerName]] autorelease];
        __block NSString *serverString;
        [arrayResult enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
         serverString = obj;
     }];
        [step.currentQueue setStateValue:[NSString stringWithString:serverString] forKey:@"servername"];
    }]];

    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"selected-server" andStrings:@"git@", [ScriptValue scriptValueWithKey:@"servername"], nil]];
	[[steps lastObject] setTitle:@"Set selected Server"];

    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"login-string" andStrings:@"ikusei@", [ScriptValue scriptValueWithKey:@"servername"], nil]];

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
    // Create an empty git directory on the server for user GIT
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      [ScriptValue scriptValueWithKey:@"selected-server"],
      @"mkdir",
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
      nil]];
	[[steps lastObject] setTitle:@"Create empty project dir on server (GIT)"];


    //
    // Create an empty git directory on the server
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      [ScriptValue scriptValueWithKey:@"login-string"],
      @"mkdir",
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
      nil]];
	[[steps lastObject] setTitle:@"Create empty project dir on server (USER)"];

    //
    // CD into the project directory on the server 
    // and initialize an empty git repository
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      [ScriptValue scriptValueWithKey:@"selected-server"],
      @"cd",
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
      @"&&",
      @"git init --bare",
      nil]];
	[[steps lastObject] setTitle:@"Create bare git repo on server"];
    

    [steps addObject:
     [BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSString *s = [NSString stringWithFormat:@"%@", [step resolvedScriptValueForValue:[ScriptValue scriptValueWithKey:@"servername"]]];
        if ([s isEqualToString:@"arion"]) {
            [step.currentQueue setStateValue:[NSString stringWithString:@"ree-1.8.7-2011.02"] forKey:kIKURubyVersion];
        } else if ([s isEqualToString:@"taurus"]) {
            [step.currentQueue setStateValue:[NSString stringWithString:@"ruby-1.9.2-p180"] forKey:kIKURubyVersion];
        }
    }]];

    //
    // Create a gemset on the server 
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      [ScriptValue scriptValueWithKey:@"login-string"],
      @"rvm",
      @"use",
      [ScriptValue scriptValueWithKey:kIKURubyVersion],
      @"&&",
      @"rvm",
      @"gemset",
      @"create",
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
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
    
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:kIKUgitAtServer andStrings:@"ssh://git@", [ScriptValue scriptValueWithKey:@"servername"], @"/home/git/", nil]];
    
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:@"clonePath"
      andStrings:
      [ScriptValue scriptValueWithKey:kIKUgitAtServer],
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
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
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
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
      @"1.9.2-p290",
      @"&&",
      [@"~/.rvm/bin/rvm" stringByExpandingTildeInPath],
      @"gemset",
      @"create",
      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
      nil]];
	[[steps lastObject] setTitle:@"Create rvm gemset on server"];
    
    //
    // Create the input for the .rvmrc file
    //
    [steps addObject:
     [ConcatenateStep
      concatenateStepWithOutputKey:@"rvmrcValue"
      andStrings:@"rvm use ", [ScriptValue scriptValueWithKey:kIKURubyVersion], @"@", [ScriptValue scriptValueWithKey:@"downcased-projectname"], nil]];
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
      andStrings:[NSString stringWithFormat:@"%@ use ", [@"~/.rvm/bin/rvm" stringByExpandingTildeInPath]], @"1.9.2-p290", @"@", [ScriptValue scriptValueWithKey:@"downcased-projectname"],
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
      @"rails",
      @"new",
      @".",
      @"-d",
      @"mysql",
      nil]];
	[[steps lastObject] setTitle:@"create new rails app"];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"rm",
      @"public/index.html",
      nil]];
	[[steps lastObject] setTitle:@"Delete index.html"];

    //
    // Add Capistrano and other essential Gems
    //
    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSError *error = nil;
        NSMutableString *gemfile_original = [NSMutableString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Gemfile", [step.currentQueue stateValueForKey:kIKUProjectDirectory]] encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            DLog(@"Failed to save to data store: %@", [error localizedDescription]);
            NSArray* detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
            if(detailedErrors != nil && [detailedErrors count] > 0) {
                for(NSError* detailedError in detailedErrors) {
                    DLog(@"DetailedError: %@", [detailedError userInfo]);
                }
            } else {
                DLog(@"%@", [error userInfo]);
            }
        } else {
            [gemfile_original appendString:@"\ngem 'goldencobra', :git => 'git://github.com/ikusei/Goldencobra.git'"];
            [gemfile_original appendString:@"\ngem 'pry'"];
            [gemfile_original appendString:@"\ngem 'andand'"];
            [gemfile_original appendString:@"\ngem 'capistrano'"];
            [gemfile_original appendString:@"\ngem 'passenger'"];
            NSError *writeError = nil;
            [gemfile_original writeToFile:[NSString stringWithFormat:@"%@/Gemfile", [step.currentQueue stateValueForKey:kIKUProjectDirectory]] atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
            
            if (writeError) {
                DLog(@"Failed to save to data store: %@", [writeError localizedDescription]);
                NSArray* detailedErrors = [[writeError userInfo] objectForKey:NSDetailedErrorsKey];
                if(detailedErrors != nil && [detailedErrors count] > 0) {
                    for(NSError* detailedError in detailedErrors) {
                        DLog(@"DetailedError: %@", [detailedError userInfo]);
                    }
                } else {
                    DLog(@"%@", [writeError userInfo]);
                }
            }
        }
    }]];
    
    //
    // Bundle install the new gems
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
	[[steps lastObject] setTitle:@"bundle install new gems"];
    
    //
    // Capify
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
      @"capify",
      @".",
      nil]];
	[[steps lastObject] setTitle:@"capify"];
    
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
    
    
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"project_name-sed" andStrings:@"'s/project_name/", [ScriptValue scriptValueWithKey:@"downcased-projectname"],@"/g'", nil]];
	[[steps lastObject] setTitle:@"capistrano text replacements"];
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"../masterfiles/templates/capistrano.tmpl",
      @">",
      @"config/deploy2.rb",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    //    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    //
    // Prompt the user to choose a password
    //
    [steps addObject:
     [PromptStep promptStepWithTitle:@"Please choose a password for the database"
                        initialValue:@""
                      outputStateKey:kIKUDBPassword]];
    [[steps lastObject] setTitle:@"Choose DB password"];

    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"database-sed2" andStrings:@"'s/db_password_ersatz/", [ScriptValue scriptValueWithKey:kIKUDBPassword],@"/g'", nil]];
	[[steps lastObject] setTitle:@"Database text replacements"];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/deploy2.rb",
      @">",
      @"config/deploydb_password.rb",
      nil]];
	[[steps lastObject] setTitle:@"Move & adjust deploy.rb"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    //
    // Set the rvm ruby string inside deploy.rb
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"deploy-rvm-ruby-sed" andStrings:@"'s/ruby_string_ersatz/", [ScriptValue scriptValueWithKey:kIKURubyVersion],@"/g'", nil]];
	[[steps lastObject] setTitle:@"deploy.rb text replacements"];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"deploy-rvm-ruby-sed"],
      @"config/deploydb_password.rb",
      @">",
      @"config/deployrvm.rb",
      nil]];
	[[steps lastObject] setTitle:@"Move & adjust deploy.rb"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    
    //
    // Prompt the user for mysql root password
    //
    [steps addObject:
     [PromptStep promptStepWithTitle:@"Please provide the root password for mysql"
                        initialValue:@""
                      outputStateKey:@"root_db_password"]];
    [[steps lastObject] setTitle:@"root password for mysql"];

    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"database-root-sed2" andStrings:@"'s/db_root_password_ersatz/", [ScriptValue scriptValueWithKey:@"root_db_password"],@"/g'", nil]];
	[[steps lastObject] setTitle:@"Database root db_password text replacements"];

    // SED the root db password
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"database-root-sed2"],
      @"config/deployrvm.rb",
      @">",
      @"config/deploy2.rb",
      nil]];
	[[steps lastObject] setTitle:@"Move & adjust deploy.rb step 2"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

#pragma mark - Database YML
    
    //
    // Replace project_name with real project name
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"../masterfiles/templates/database.yml.tmpl",
      @">",
      @"config/database.yml.2",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    
    
    //
    // Replace db_password with proper password
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"rm",
      @"config/database.yml",
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/database.yml.2",
      @">",
      @"config/database.yml",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    
#pragma mark - Server Templates
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/mkdir",
      @"config/templates",
      nil]];
	[[steps lastObject] setTitle:@"Create Server template dir"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    //
    // Server templates #1
    // Replace project_name with real project name
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"../masterfiles/templates/server_templates/create_database.yml",
      @">",
      @"config/templates/create_database.mysql2",
      nil]];
	[[steps lastObject] setTitle:@"Server MySQL template"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"database-sed2"],
      @"config/templates/create_database.mysql2",
      @">",
      @"config/templates/create_database.mysql",
      nil]];
	[[steps lastObject] setTitle:@"mysql password"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    
#pragma mark - Gemfile
    //
    // Copy Gemlistfile to project directory
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/bin/cp",
      @"-v",
      @"../masterfiles/templates/gemfile.tmpl",
      @"Gemfile.tmpl",
      nil]];
	[[steps lastObject] setTitle:@"Customize templates"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    //
    // Build a string for the gemlistpath
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"gemfilepath" andStrings:[ScriptValue scriptValueWithKey:kIKUProjectDirectory], @"/Gemfile.tmpl", nil]];
	[[steps lastObject] setTitle:@"Build path to masterfiles"];
    
    //
    // Build Array/List for CollectionSelectStep
    //
    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSError *error = nil;
        NSString *gemlistString = [NSString stringWithContentsOfFile:[step.currentQueue stateValueForKey:@"gemfilepath"] encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            DLog(@"Failed to save to data store: %@", [error localizedDescription]);
            NSArray* detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
            if(detailedErrors != nil && [detailedErrors count] > 0) {
                for(NSError* detailedError in detailedErrors) {
                    DLog(@"DetailedError: %@", [detailedError userInfo]);
                }
            } else {
                DLog(@"%@", [error userInfo]);
            }
        } else {
            NSArray *gemlistArray = [gemlistString componentsSeparatedByString:@"\n"];
            //            [NSUserDefaults.standardUserDefaults setObject:gemlistArray forKey:@"gemlistArray"];
            [step.currentQueue setStateValue:gemlistArray forKey:@"gemlistArray"];
        }
    }]];
    
    //
    // Show NSPanel with Gem Collection 
    //
    CollectionSelectStep *colStep = [CollectionSelectStep collectionSelectStepWithTitle:@"Bitte gems aussuchen" stateKey:@"gemlistArray" outputStateKey:@"arrayOutput"];
    [steps addObject:colStep];
    
    //
    // Build a path for the final Gemfile
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"finalGemfile" andStrings:[ScriptValue scriptValueWithKey:kIKUProjectDirectory], @"/Gemfile", nil]];
	[[steps lastObject] setTitle:@"Build path to final Gemfile"];
    
    //
    // Write selected Gems into the final Gemfile
    //
    [steps addObject:[BlockStep blockStepWithBlock:^(BlockStep *step) {
        NSArray *gemCollection = [[[NSArray alloc] initWithArray:[step.currentQueue stateValueForKey:@"arrayOutput"]] autorelease];
        NSError *error = nil;
        NSMutableString *gemString = [NSMutableString  stringWithContentsOfFile:[step.currentQueue stateValueForKey:@"finalGemfile"] encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            DLog(@"Failed to save to data store: %@", [error localizedDescription]);
            NSArray* detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
            if(detailedErrors != nil && [detailedErrors count] > 0) {
                for(NSError* detailedError in detailedErrors) {
                    DLog(@"DetailedError: %@", [detailedError userInfo]);
                }
            } else {
                DLog(@"%@", [error userInfo]);
            }
        } else {
            [gemCollection enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                [gemString appendFormat:@"%@\n", obj];
            }];
        }
        //gemstring write to file
        NSError *writeError = nil;
        [gemString writeToFile:[NSString stringWithFormat:@"%@/Gemfile", [step.currentQueue stateValueForKey:kIKUProjectDirectory]] atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        if (writeError) {
            DLog(@"Failed to save to data store: %@", [writeError localizedDescription]);
            NSArray* detailedErrors = [[writeError userInfo] objectForKey:NSDetailedErrorsKey];
            if(detailedErrors != nil && [detailedErrors count] > 0) {
                for(NSError* detailedError in detailedErrors) {
                    DLog(@"DetailedError: %@", [detailedError userInfo]);
                }
            } else {
                DLog(@"%@", [writeError userInfo]);
            }
        }
    }]];
    
 
    //
    // remove the db root password from deploy.rb
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"database-root-remove-sed" andStrings:@"'s/", [ScriptValue scriptValueWithKey:@"root_db_password"], @"/db_root_password/g'", nil]];
	[[steps lastObject] setTitle:@"Database remove root db_password"];

    
    // SED the root db password
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"database-root-remove-sed"],
      @"config/deploy2.rb",
      @">",
      @"config/deploy2tmp.rb",
      nil]];
	[[steps lastObject] setTitle:@"Move & adjust deploy.rb step 2"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"mv",
      @"-fv",
      @"config/deploy2tmp.rb",
      @"config/deploy.rb",
      nil]];
	[[steps lastObject] setTitle:@"deploy.rb rename"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

//    //
//    // Cap Deploy:SETUP
//    //
//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/usr/bin/ssh",
//      @"localhost",
//      @"cd",
//      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
//      @"&&",
//      [ScriptValue scriptValueWithKey:@"gemsetValue"],
//      @"exec",
//      @"bundle",
//      @"exec",
//      @"cap",
//      @"deploy:setup",
//      nil]];
//	[[steps lastObject] setTitle:@"cap deploy:setup"];
//    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
//
//    
//    //
//    // cap deploy:db:setup
//    //
//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/usr/bin/ssh",
//      @"localhost",
//      @"cd",
//      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
//      @"&&",
//      [ScriptValue scriptValueWithKey:@"gemsetValue"],
//      @"exec",
//      @"bundle",
//      @"exec",
//      @"cap",
//      @"deploy:db:setup",
//      @"db:setup",
//      nil]];
//	[[steps lastObject] setTitle:@"cap deploy:db:setup"];
//    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    


    //
    // Dialog for URL
    //
    [steps addObject:[PromptStep promptStepWithTitle:@"Project's URL"
                                        initialValue:@""
                                      outputStateKey:kIKUProjectURL]];
    [[steps lastObject] setTitle:@"Set a project's URL"];

    //
    // Prepare sites-available apache2 config file. push with git to server. enable site. git rm sites-available apache 2 config file from git-repository
    //
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"apache-url-sed" andStrings:@"'s/my_url/", [ScriptValue scriptValueWithKey:kIKUProjectURL], @"/g'", nil]];
	[[steps lastObject] setTitle:@"set url for apache config"];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"apache-url-sed"],
      @"../masterfiles/templates/server_templates/sites-available.tmp",
      @">",
      @"sites-available.tmp",
      nil]];
	[[steps lastObject] setTitle:@"Customize sites-available.tmp"];
    

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/ssh",
      @"localhost",
      @"cd",
      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
      @"&&",
      @"sed",
      [ScriptValue scriptValueWithKey:@"project_name-sed"],
      @"sites-available.tmp",
      @">",
      @"apache2configfile",
      nil]];
	[[steps lastObject] setTitle:@"set project name in apache2 config"];


//    //
//    // cap deploy:apache_setup
//    //
//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/usr/bin/ssh",
//      @"localhost",
//      @"cd",
//      [ScriptValue scriptValueWithKey:kIKUProjectDirectory],
//      @"&&",
//      [ScriptValue scriptValueWithKey:@"gemsetValue"],
//      @"exec",
//      @"bundle",
//      @"exec",
//      @"cap",
//      @"deploy:apache_setup",
//      nil]];
//	[[steps lastObject] setTitle:@"cap deploy:apache_setup"];
//    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    
    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"apache-copy" andStrings:[ScriptValue scriptValueWithKey:@"login-string"], @":/home/ikusei/",[ScriptValue scriptValueWithKey:@"downcased-projectname"], @"/", [ScriptValue scriptValueWithKey:@"downcased-projectname"], nil]];
	[[steps lastObject] setTitle:@"set string for apache2 config"];


    //
    // Log in on server and move apache2 config
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/scp",
      @"apache2configfile",
      [ScriptValue scriptValueWithKey:@"apache-copy"],
      nil]];
	[[steps lastObject] setTitle:@"copy apache config to server"];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];

    //
    // commit changes and push
    //
    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/git",
      @"add",
      @".",
      nil]];
    [gitExists addPredicatedStep:[steps lastObject]];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
	[[steps lastObject] setTitle:@"git: add all files"];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/git",
      @"commit",
      @"-am",
      @"'Initial commit with apache2 config'",
      nil]];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    [gitExists addPredicatedStep:[steps lastObject]];
	[[steps lastObject] setTitle:@"git commit: Initial commit"];

    [steps addObject:
     [TaskStep taskStepWithCommandLine:
      @"/usr/bin/git",
      @"push",
      @"origin",
      @"master",
      nil]];
    [[steps lastObject] setCurrentDirectory:[ScriptValue scriptValueWithKey:kIKUProjectDirectory]];
    [gitExists addPredicatedStep:[steps lastObject]];
	[[steps lastObject] setTitle:@"git push"];


    [steps addObject:[ConcatenateStep concatenateStepWithOutputKey:@"readme-string" andStrings:@"Vorbereitung erfolgreich.\nBitte führe jetzt folgende Schritte im Terminal aus:\n1. cap deploy\n2. cap deploy:db:setup\n3. cap deploy:apache_setup\n4. Es gibt keinen vierten Schritt. Wieviel willst du denn noch selbst machen? :-)\n\n- Wir haben jetzt auf dem Server 'Arion' ein git-repository.\n- Auf dem gewählten Server ein Projektverzeichnis, das den gewählten Projektnamen hat.\n- Lokal ein Projektverzeichnis, das das Git-Repository hat.\n\nDu musst noch die gewählte URL bei planetary-networks registrieren.\n\nhttps://robot.planetary-networks.de/", nil]];
    
    [steps addObject:[ReadmeStep readmeStepWithText:[ScriptValue scriptValueWithKey:@"readme-string"]]];
    
    
/* #warning Cleanup im dev mode */
//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/usr/bin/ssh",
//      [ScriptValue scriptValueWithKey:@"selected-server"],
//      @"rm -R",
//      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
//      nil]];
//	[[steps lastObject] setTitle:@"Delete project dir on server (GIT)"];

//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/usr/bin/ssh",
//      [ScriptValue scriptValueWithKey:@"login-string"],
//      @"rm -R",
//      [ScriptValue scriptValueWithKey:@"downcased-projectname"],
//      nil]];
//	[[steps lastObject] setTitle:@"Delete project dir on server (USER)"];

    //    [steps addObject:
    //     [TaskStep taskStepWithCommandLine:
    //      @"/bin/rm",
    //      @"-Rf",
    //      [ScriptValue scriptValueWithKey:kIKUProjectName],
    //      nil]];
    //    [[steps lastObject] setCurrentDirectory:
    //     [ScriptValue scriptValueWithKey:kIKUProjectPath]];
    
//    [steps addObject:
//     [TaskStep taskStepWithCommandLine:
//      @"/bin/rm",
//      @"-Rf",
//      @"masterfiles",
//      nil]];
//    [[steps lastObject] setCurrentDirectory:
//     [ScriptValue scriptValueWithKey:kIKUProjectPath]];
    
    
	return steps;
}
