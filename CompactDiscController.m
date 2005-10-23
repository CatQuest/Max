/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "CompactDiscController.h"

#import "Track.h"
#import "CDDB.h"
#import "CDDBMatchSheet.h"
#import "Genres.h"
#import "Encoder.h"
#import "Tagger.h"

#import "CDDBException.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

@implementation CompactDiscController

+ (void)initialize
{
	BOOL					isDir;
	NSFileManager			*manager;
	NSArray					*paths;
	NSString				*compactDiscControllerDefaultsValuesPath;
    NSDictionary			*compactDiscControllerDefaultsValuesDictionary;
	
	@try {
		// Set up defaults
		compactDiscControllerDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"CompactDiscControllerDefaults" ofType:@"plist"];
		if(nil == compactDiscControllerDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load CompactDiscControllerDefaults.plist" userInfo:nil];
		}
		compactDiscControllerDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscControllerDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscControllerDefaultsValuesDictionary];
		
		// Create application data directory if needed
		manager		= [NSFileManager defaultManager];
		paths		= NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		gDataDir	= [[[paths objectAtIndex:0] stringByAppendingString:@"/Max"] retain];
		if(NO == [manager fileExistsAtPath:gDataDir isDirectory:&isDir]) {
			if(NO == [manager createDirectoryAtPath:gDataDir attributes:nil]) {
				@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
			}
		}
		else if(FALSE == isDir) {
			@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
		}
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}	
}

- (NSArray *)genres
{
	return [Genres sharedGenres];
}

- (id)init
{
	return [self initWithDisc: [[[CompactDisc alloc] init] autorelease]];
}

- (CompactDiscController *)initWithDisc: (CompactDisc *) disc
{
	@try {
		self = [super init];
		if(self) {
			
			_disc = [disc retain];

			_stop = [NSNumber numberWithBool:FALSE];
			
			if(NO == [NSBundle loadNibNamed:@"CompactDisc" owner:self])  {
				@throw [MissingResourceException exceptionWithReason:@"Unable to load CompactDisc.nib" userInfo:nil];
			}
			
			// Load data from file if it exists
			NSFileManager	*manager	= [NSFileManager defaultManager];
			NSString		*discPath	= [NSString stringWithFormat:@"%@/0x%.8x.xml", gDataDir, [_disc cddb_id]];
			if([manager fileExistsAtPath:discPath isDirectory:nil]) {
				NSData					*xmlData	= [manager contentsAtPath:discPath];
				NSDictionary			*discInfo;
				NSPropertyListFormat	format;
				NSString				*error;
				
				discInfo = [NSPropertyListSerialization propertyListFromData:xmlData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
				if(nil != discInfo) {
					[_disc setPropertiesFromDictionary:discInfo];
				}
				else {
					[error release];
				}					
				[_window setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
				[_window makeKeyAndOrderFront:nil];
			}
			// Otherwise query cddb
			else {
				[_window setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
				[_window makeKeyAndOrderFront:nil];
				[self getCDInformation:nil];
			}
		}
	}
	
	@catch(NSException *exception) {
		[self release];
		@throw;
	}
	
	@finally {
		
	}
	
	return self;
}

- (void)dealloc
{
	[_disc release];
	[super dealloc];
}

- (void) discUnmounted
{
	[_window performClose:nil];
}

- (IBAction)showTrackInfo:(id)sender
{
	[_trackDrawer toggle:self];
}

- (IBAction) selectAll:(id)sender
{
	int			i;
	NSArray		*tracks = [_disc valueForKey:@"tracks"];
	
	for(i = 0; i < [tracks count]; ++i) {
		[[tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:YES] forKey:@"selected"];
	}
}

- (IBAction) selectNone:(id)sender
{
	int			i;
	NSArray		*tracks = [_disc valueForKey:@"tracks"];
	
	for(i = 0; i < [tracks count]; ++i) {
		[[tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
	}
}

- (IBAction)encode:(id)sender
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	NSString		*filename;
	
	@try {		
		// Do nothing for empty selection
		if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:@"Please select one or more tracks to encode." userInfo:nil];
		}

		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [_disc selectedTracks];
		enumerator		= [selectedTracks objectEnumerator];

		// Create output directory (should exist but could have been deleted/moved)
		validateAndCreateDirectory([[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"]);
		
		while(track = [enumerator nextObject]) {

			// Use custom naming scheme
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.useCustomNaming"]) {
				
				NSMutableString		*customPath			= [[NSMutableString alloc] initWithCapacity:100];
				NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.customNamingScheme"];
				NSString			*path;
				
				// Get the elements needed to build the pathname
				NSNumber			*discNumber			= [_disc valueForKey:@"discNumber"];
				NSNumber			*discsInSet			= [_disc valueForKey:@"discsInSet"];
				NSString			*discArtist			= [_disc valueForKey:@"artist"];
				NSString			*discTitle			= [_disc valueForKey:@"title"];
				NSString			*discGenre			= [_disc valueForKey:@"genre"];
				NSNumber			*discYear			= [_disc valueForKey:@"year"];
				NSNumber			*trackNumber		= [track valueForKey:@"number"];
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				NSString			*trackGenre			= [track valueForKey:@"genre"];
				NSNumber			*trackYear			= [track valueForKey:@"year"];
				
				// Fallback to disc if specified in preferences
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.customNamingUseFallback"]) {
					if(nil == trackArtist) {
						trackArtist = discArtist;
					}
					if(nil == trackGenre) {
						trackGenre = discGenre;
					}
					if(nil == trackYear) {
						trackYear = discYear;
					}
				}
				
				if(nil == customNamingScheme) {
					@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string." userInfo:nil];
				}
				else {
					[customPath setString:customNamingScheme];
				}
				
				if(nil == discNumber) {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[discNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discsInSet) {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[discsInSet stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discArtist) {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:makeStringSafeForFilename(discArtist) options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discTitle) {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:makeStringSafeForFilename(discTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discGenre) {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:makeStringSafeForFilename(discGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discYear) {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:[discYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackNumber) {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[trackNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackArtist) {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackTitle) {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:makeStringSafeForFilename(trackTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackGenre) {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:makeStringSafeForFilename(trackGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackYear) {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}

				// Create the directory structure
				NSArray *pathComponents = [customPath pathComponents];

				// pathComponents will always contain at least 1 element since customNamingScheme was not nil
				path = [NSString stringWithFormat:@"%@/%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"], makeStringSafeForFilename([pathComponents objectAtIndex:0])]; 

				if(1 < [pathComponents count]) {
					int				i;
					int				directoryCount		= [pathComponents count] - 1;
					
					validateAndCreateDirectory(path);
					for(i = 1; i < directoryCount; ++i) {						
						path = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
						validateAndCreateDirectory(path);
					}
					
					filename = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
				}
				else {
					filename = path;
				}
				[customPath release];
			}
			// Use standard iTunes style naming: "{Track|Disc}Artist/Album/DiscNumber TrackNumber TrackTitle.mp3"
			// TODO: compilations
			else {
				NSString			*path;
				
				NSString			*discArtist			= [_disc valueForKey:@"artist"];
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*artist;
				NSString			*discTitle			= [_disc valueForKey:@"title"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				
				artist = trackArtist;
				if(nil == artist) {
					artist = discArtist;
					if(nil == artist) {
						artist = @"Unknown Artist";
					}
				}
				if(nil == discTitle) {
					discTitle = @"Unknown Album";
				}
				if(nil == trackTitle) {
					discTitle = @"Unknown Track";
				}
				
				// Create the directory structure
				path = [NSString stringWithFormat:@"%@/%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"], makeStringSafeForFilename(artist)]; 
				validateAndCreateDirectory(path);
				
				path = [NSString stringWithFormat:@"%@/%@/%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"], makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
				validateAndCreateDirectory(path);
				
				if(nil == [_disc valueForKey:@"discNumber"]) {
					filename = [NSString stringWithFormat:@"%@/%02u %@.mp3", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
				else {
					filename = [NSString stringWithFormat:@"%@/%i-%02u %@.mp3", path, [[_disc valueForKey:@"discNumber"] intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
			}
						
			// Create the encoder
			// TODO(?): add other types of encoders (PCM/WAV/AIFF would be trivial)
			Ripper		*source		= [[[Ripper alloc] initWithDisc:_disc forTrack:track] autorelease];
			Encoder		*encoder	= [[[Encoder alloc] initWithController:self usingSource:source forDisc:_disc forTrack:track toFile:filename] autorelease];

			// Spawn each encoder in a separate thread
			[NSThread detachNewThreadSelector:@selector(doIt:) toTarget:encoder withObject:self];
		}
	}

	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}

	@finally {
		
	}
}

- (IBAction) skip:(id)sender
{
	_stop = [NSNumber numberWithBool:TRUE];
}

- (IBAction)stop:(id)sender
{
	[_stopButton setEnabled:FALSE];
	_stop = [NSNumber numberWithBool:TRUE];
}

- (IBAction)getCDInformation:(id)sender
{
	CDDB				*cddb				= nil;
	NSArray				*matches			= nil;
	CDDBMatchSheet		*sheet				= nil;

	@try {
		
		cddb = [[[CDDB alloc] init] autorelease];
		[cddb setValue:_disc forKey:@"disc"];
		
		matches = [cddb fetchMatches];
		
		if(0 == [matches count]) {
			@throw [CDDBException exceptionWithReason:@"No matches found for this disc." userInfo:nil];
		}
		else if(1 == [matches count]) {
			[self updateDiscFromCDDB:[matches objectAtIndex:0]];
		}
		else {
			sheet = [[[CDDBMatchSheet alloc] init] autorelease];
			[sheet setValue:matches forKey:@"matches"];
			[sheet setValue:self forKey:@"controller"];
			[sheet showCDDBMatchSheet];
		}
	}
	
	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}
	
	@finally {
	}
}

- (void) updateDiscFromCDDB:(CDDBMatch *)info
{
	CDDB *cddb;
	
	@try {
		cddb = [[CDDB alloc] init];
		[cddb setValue:_disc forKey:@"disc"];
		
		[cddb updateDisc:info];
	}

	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}
	
	@finally {
		[cddb release];		
	}
	
}

- (BOOL)emptySelection
{
	return (0 == [[_disc selectedTracks] count]);
}

- (void) displayExceptionSheet:(NSException *)exception
{
	displayExceptionSheet(exception, _window, self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}

#pragma mark Encoder callbacks

- (void) encodeDidStart:(id) object
{
	NSString *trackString;
	
	[_encodeButton setEnabled:FALSE];
	[_stopButton setEnabled:TRUE];
	[_statusDrawer openOnEdge:NSMinYEdge];	

	trackString = @"Track ";
	[_ripTrack setStringValue:[trackString stringByAppendingString: (NSString *)object]];
}

- (void) encodeDidStop:(id) object
{
	[_statusDrawer close];
	[_stopButton setEnabled:TRUE];
	[_encodeButton setEnabled:TRUE];
	_stop = [NSNumber numberWithBool:FALSE];
}

- (void) encodeDidComplete:(id) object
{
	Encoder *encoder = (Encoder *)object;
	
	// Write ID3 tags
	[Tagger tagFile:[encoder valueForKey:@"filename"] fromTrack:[encoder valueForKey:@"track"]];
	
	[_statusDrawer close];
	[_stopButton setEnabled:TRUE];
	[_encodeButton setEnabled:TRUE];
	[[encoder valueForKey:@"track"] setValue:[NSNumber numberWithBool:FALSE] forKey:@"selected"];
}

- (void) updateEncodeProgress:(id) object
{
	[_ripProgressIndicator setDoubleValue:[(NSNumber *)object doubleValue]];
}

#pragma mark NSDrawer delegate methods

- (void)drawerDidClose:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Show Track Info"];
	}
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Hide Track Info"];
	}
}

#pragma mark NSWindow delegate methods

- (void) windowWillClose:(NSNotification *) aNotification
{
	// Save data from file if it exists
	NSFileManager			*manager	= [NSFileManager defaultManager];
	NSString				*discPath	= [NSString stringWithFormat:@"%@/0x%.8x.xml", gDataDir, [_disc cddb_id]];
	NSData					*xmlData;
	NSString				*error;
	
	if(! [manager fileExistsAtPath:discPath isDirectory:nil]) {
		[manager createFileAtPath:discPath contents:nil attributes:nil];
	}
	
	xmlData = [NSPropertyListSerialization dataFromPropertyList:[_disc getDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	if(nil != xmlData) {
		[xmlData writeToFile:discPath atomically:YES];
	}
	else {
		[error release];
	}
}

@end
