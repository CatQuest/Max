/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "ApplicationController.h"

#import "ServicesProvider.h"
#import "PreferencesController.h"
#import "ConvertFilesController.h"
#import "AcknowledgmentsController.h"
#import "ComponentVersionsController.h"
#import "MediaController.h"
#import "RipperController.h"
#import "ConverterController.h"
#import "EncoderController.h"
#import "LogController.h"
#import "CoreAudioUtilities.h"
#import "UtilityFunctions.h"
#import "UpdateChecker.h"
#import "MacPADSocket.h"
#import "IOException.h"
#import "MissingResourceException.h"
#import "FileFormatNotSupportedException.h"
#import "FreeDBProtocolValueTransformer.h"
#import "BooleanArrayValueTransformer.h"
#import "NegateBooleanArrayValueTransformer.h"
#import "MultiplicationValueTransformer.h"
#import "BOOLToStringValueTransformer.h"
#import "UppercaseStringValueTransformer.h"
#import "IntegerToBOOLValueTransformer.h"
#import "SelectEncodersSheet.h"

static ApplicationController *sharedController = nil;

@implementation ApplicationController

+ (void) initialize
{
	// Set up the ValueTransformers
	NSValueTransformer			*transformer;
	NSString					*defaultsValuesPath;
    NSDictionary				*defaultsValuesDictionary;
    
	
	transformer = [[[FreeDBProtocolValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"FreeDBProtocolValueTransformer"];

	transformer = [[[BooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BooleanArrayValueTransformer"];

	transformer = [[[NegateBooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NegateBooleanArrayValueTransformer"];

	transformer = [[[MultiplicationValueTransformer alloc] initWithMultiplier:10] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"MultiplyByTenValueTransformer"];

	transformer = [[[BOOLToStringValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BOOLToStringValueTransformer"];

	transformer = [[[UppercaseStringValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"UppercaseStringValueTransformer"];
	
	transformer = [[[IntegerToBOOLValueTransformer alloc] initWithValue:0] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NumberIsZeroValueTransformer"];

	transformer = [[[IntegerToBOOLValueTransformer alloc] initWithValue:1] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NumberIsOneValueTransformer"];
	
	transformer = [[[IntegerToBOOLValueTransformer alloc] initWithValue:2] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NumberIsTwoValueTransformer"];
	
	transformer = [[[IntegerToBOOLValueTransformer alloc] initWithValue:3] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NumberIsThreeValueTransformer"];
		
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ApplicationControllerDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"ApplicationControllerDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ApplicationController"]];
		[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ApplicationController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (ApplicationController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController) {
			sharedController = [[self alloc] init];
		}
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            return [super allocWithZone:zone];
        }
    }
    return sharedController;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (IBAction) showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showWindow:self];
}

- (IBAction) showAcknowledgments:(id)sender
{
	[[AcknowledgmentsController sharedController] showWindow:self];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSArray		*openWindows	= nil;
	
	// Setup MediaController to receive DiskAppeared/DiskDisappeared callbacks
	[MediaController sharedController];
		
	// Check for new version
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"startupVersionCheck"]) {
		[[UpdateChecker sharedController] checkForUpdate:NO];
	}
	
	// Register services
	[[NSApplication sharedApplication] setServicesProvider:[[ServicesProvider alloc] init]];
	
	// Show windows that were left open from last time
	openWindows = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"openWindows"];
	if(nil != openWindows) {
		if([openWindows containsObject:@"Ripper"]) {
			[[[RipperController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"Converter"]) {
			[[[ConverterController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"Encoder"]) {
			[[[EncoderController sharedController] window] orderFront:self];
		}		
		if([openWindows containsObject:@"Log"]) {
			[[[LogController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"ConvertFiles"]) {
			[[[ConvertFilesController sharedController] window] orderFront:self];
		}
	}
	
	// Log startup
	[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"Max successfully launched", @"Log", @"")];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender
{
	NSMutableArray	*openWindows	= nil;
	
	if([[RipperController sharedController] hasTasks] || [[ConverterController sharedController] hasTasks] || [[EncoderController sharedController] hasTasks]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Do you want to quit while there are tasks in progress?", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"The resulting files will be lost if you quit now.", @"General", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return NSTerminateCancel;
		}
		// Remove all tasks
		else {
			[[RipperController sharedController] stopAllTasks:self];
			[[ConverterController sharedController] stopAllTasks:self];
			[[EncoderController sharedController] stopAllTasks:self];
		}
	}
	
	// Save open windows
	openWindows = [NSMutableArray array];
	if([[[RipperController sharedController] window] isVisible]) {
		[openWindows addObject:@"Ripper"];
	}
	if([[[ConverterController sharedController] window] isVisible]) {
		[openWindows addObject:@"Converter"];
	}
	if([[[EncoderController sharedController] window] isVisible]) {
		[openWindows addObject:@"Encoder"];
	}
	if([[[LogController sharedController] window] isVisible]) {
		[openWindows addObject:@"Log"];
	}
	if([[[ConvertFilesController sharedController] window] isVisible]) {
		[openWindows addObject:@"ConvertFiles"];
	}
	[[NSUserDefaults standardUserDefaults] setObject:openWindows forKey:@"openWindows"];

	return NSTerminateNow;
}

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSDocument	*document;
	NSError		*error;
	
	// First try our document types
	document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:YES error:&error];
	
	if(nil != document) {
		return YES;
	}
	else if([getAudioExtensions() containsObject:[filename pathExtension]]) {
		[self encodeFiles:[NSArray arrayWithObject:filename]];
		return YES;
	}		
	
	return NO;
}

- (IBAction) encodeFile:(id)sender
{
	[[ConvertFilesController sharedController] showWindow:self];
//	[[ConvertFilesController sharedController] addFiles:self];
}

- (void) encodeFiles:(NSArray *)filenames
{
	[self encodeFiles:filenames withEncoders:getDefaultOutputFormats()];
}

- (void) encodeFiles:(NSArray *)filenames withEncoders:(NSArray *)encoders
{
	NSFileManager		*manager		= [NSFileManager defaultManager];
	NSString			*filename;
	NSArray				*subpaths;
	BOOL				isDir;
	AudioMetadata		*metadata;
	NSEnumerator		*enumerator;
	NSString			*subpath;
	NSString			*composedPath;
	NSString			*outputDirectory;
	NSDictionary		*userInfo;
	unsigned			i;
	
	// Verify at least one output format is selected
	if(0 == [encoders count]) {
		int		result;
		
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
			[[PreferencesController sharedPreferences] showWindow:self];
		}

		return;
	}

	// Conversion parameters
	outputDirectory		= ([[NSUserDefaults standardUserDefaults] boolForKey:@"convertInPlace"] ? nil : [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath]);
	userInfo			= ([[NSUserDefaults standardUserDefaults] boolForKey:@"deleteAfterConversion"] ? [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"deleteSourceFiles"] : nil);

	for(i = 0; i < [filenames count]; ++i) {
		filename = [filenames objectAtIndex:i];
		
		if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
			if(isDir) {
				subpaths	= [manager subpathsAtPath:filename];
				enumerator	= [subpaths objectEnumerator];
				
				while((subpath = [enumerator nextObject])) {
					composedPath = [NSString stringWithFormat:@"%@/%@", filename, subpath];
					
					// Ignore dotfiles
					if([[subpath lastPathComponent] hasPrefix:@"."]) {
						continue;
					}
					// Ignore files that don't have our extensions
					else if(NO == [getAudioExtensions() containsObject:[subpath pathExtension]]) {
						continue;
					}
					
					// Ignore directories
					if([manager fileExistsAtPath:composedPath isDirectory:&isDir] && NO == isDir) {
						metadata = [AudioMetadata metadataFromFile:composedPath];
						
						@try {
							[[ConverterController sharedController] convertFile:composedPath metadata:metadata withEncoders:encoders toDirectory:outputDirectory userInfo:userInfo];
						}
						
						@catch(FileFormatNotSupportedException *exception) {
							// Just let it go since we are traversing a folder
						}
					}
				}
			}
			else {
				metadata = [AudioMetadata metadataFromFile:filename];						
				[[ConverterController sharedController] convertFile:filename metadata:metadata withEncoders:encoders toDirectory:outputDirectory userInfo:userInfo];
			}
		}
		else {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"The file was not found.", @"Exceptions", @"") userInfo:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];
		}
	}					
}

- (IBAction) showComponentVersions:(id)sender
{
	[[ComponentVersionsController sharedController] showWindow:self];
}

- (IBAction) toggleRipperWindow:(id)sender
{
	NSWindow *ripperWindow = [[RipperController sharedController] window];
	if([ripperWindow isVisible]) {
		[ripperWindow performClose:self];
	}
	else {
		[ripperWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleConverterWindow:(id)sender
{
	NSWindow *converterWindow = [[ConverterController sharedController] window];
	if([converterWindow isVisible]) {
		[converterWindow performClose:self];
	}
	else {
		[converterWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleEncoderWindow:(id)sender
{
	NSWindow *encoderWindow = [[EncoderController sharedController] window];
	if([encoderWindow isVisible]) {
		[encoderWindow performClose:self];
	}
	else {
		[encoderWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleLogWindow:(id)sender
{
	NSWindow *logWindow = [[LogController sharedController] window];
	if([logWindow isVisible]) {
		[logWindow performClose:self];
	}
	else {
		[logWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) checkForUpdate:(id)sender
{
	[[UpdateChecker sharedController] checkForUpdate:YES];
}

- (IBAction) openHomeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sbooth.org/Max/"]];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	BOOL	result		= YES;
	
	if(@selector(encodeFile:) == [item action]) {
		result = ! [[[ConvertFilesController sharedController] window] isVisible];
	}
	
	return result;
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *defaultNotifications = [NSArray arrayWithObjects:
		@"Rip stopped",
		@"Ripping completed",
		@"Convert stopped",
		@"Conversion completed",
		@"Encode stopped",
		@"Encoding completed",
		nil
		];

	NSArray *allNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Ripping completed",
		@"Disc ripping completed",
		@"Convert started",
		@"Convert completed",
		@"Convert stopped",
		@"Conversion completed",
		@"Encode started",
		@"Encode completed",
		@"Encode stopped",
		@"Encoding completed",
		@"Disc encoding completed",
		nil
		];
	
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Max", GROWL_APP_NAME, 
		allNotifications, GROWL_NOTIFICATIONS_ALL, 
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	return regDict;
}

/*- (BOOL) displayAlertIfNoOutputFormats
{
	// Verify at least one output format is selected
	if(NO == outputFormatsSelected()) {
		int		result;
		
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
			[[PreferencesController sharedPreferences] showWindow:self];
		}
		
		return YES;
	}
	
	return NO;
}*/

@end

#pragma mark Scripting

@implementation NSApplication (ScriptingAdditions)

- (id) handleConvertScriptCommand:(NSScriptCommand *)command
{
	id			directParameter			= [command directParameter];
	Class		directParameterClass	= [directParameter class];
	
	@try {
		if([directParameterClass isEqual:[NSURL class]]) {
			NSURL	*url	= (NSURL *)directParameter;
			
			if([url isFileURL]) {
				[[ApplicationController sharedController] encodeFiles:[NSArray arrayWithObject:[url path]]];
			}
			
		}
		else if([directParameterClass isEqual:[NSArray class]]) {
			NSArray			*urlArray;
			NSEnumerator	*enumerator;
			NSURL			*url;
			NSMutableArray	*filenamesArray;
			
			urlArray		= (NSArray *)directParameter;
			filenamesArray	= [NSMutableArray arrayWithCapacity:[urlArray count]];
			enumerator		= [urlArray objectEnumerator];
			
			while((url = [enumerator nextObject])) {
				if([url isFileURL]) {
					[filenamesArray addObject:[url path]];
				}
			}
			
			[[ApplicationController sharedController] encodeFiles:filenamesArray];
		}	
	}
	
	@catch(FileFormatNotSupportedException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		if(nil != [exception userInfo] && nil != [[exception userInfo] objectForKey:@"filename"]) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
			[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		}
		else {
			[alert setMessageText:NSLocalizedStringFromTable(@"An error occurred during file conversion.", @"Exceptions", @"")];
			[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"An error occurred during file conversion.", @"Exceptions", @"")];
		}
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}

	return nil;
}

@end
