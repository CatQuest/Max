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

#import <Cocoa/Cocoa.h>

#import "CompactDisc.h"
#import "Track.h"

@interface CompactDiscDocument : NSDocument 
{
    IBOutlet NSArrayController		*_trackController;
    IBOutlet NSDrawer				*_trackDrawer;
    IBOutlet NSDrawer				*_artDrawer;
    IBOutlet NSTableView			*_trackTable;

	CompactDisc						*_disc;
	BOOL							_discInDrive;
	int								_discID;
	BOOL							_freeDBQueryInProgress;
	BOOL							_freeDBQuerySuccessful;
		
	// Disc information
	NSString						*_title;
	NSString						*_artist;
	unsigned						_year;
	NSString						*_genre;
	NSString						*_composer;
	NSString						*_comment;

	NSImage							*_albumArt;
	
	NSDate							*_albumArtDownloadDate;

	// Other disc info
	unsigned						_discNumber;
	unsigned						_discTotal;
	BOOL							_compilation;
	
	NSString						*_MCN;
	
	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (NSArray *)		genres;

// State
- (BOOL)			encodeAllowed;
- (BOOL)			queryFreeDBAllowed;
- (BOOL)			submitToFreeDBAllowed;
- (BOOL)			ejectDiscAllowed;

- (BOOL)			emptySelection;
- (BOOL)			ripInProgress;
- (BOOL)			encodeInProgress;

// Action methods
- (IBAction)		selectAll:(id) sender;
- (IBAction)		selectNone:(id) sender;
- (IBAction)		encode:(id) sender;
- (IBAction)		ejectDisc:(id) sender;
- (IBAction)		queryFreeDB:(id) sender;
- (IBAction)		submitToFreeDB:(id) sender;
- (IBAction)		toggleTrackInformation:(id) sender;
- (IBAction)		toggleAlbumArt:(id) sender;
- (IBAction)		selectNextTrack:(id) sender;
- (IBAction)		selectPreviousTrack:(id) sender;
- (IBAction)		fetchAlbumArt:(id) sender;
- (IBAction)		selectAlbumArt:(id) sender;

// FreeDB
- (void)			clearFreeDBData;
- (void)			updateDiscFromFreeDB:(NSDictionary *) info;

// Miscellaneous
- (void)			encodeToPlaylist:(NSString *)playlist;
- (void)			discEjected;
- (NSArray *)		selectedTracks;

- (CompactDisc *)	disc;
- (void)			setDisc:(CompactDisc *)disc;

- (BOOL)			discInDrive;
- (void)			setDiscInDrive:(BOOL)discInDrive;

- (int)				discID;
- (void)			setDiscID:(int)discID;

- (BOOL)			freeDBQueryInProgress;
- (void)			setFreeDBQueryInProgress:(BOOL)freeDBQueryInProgress;

- (BOOL)			freeDBQuerySuccessful;
- (void)			setFreeDBQuerySuccessful:(BOOL)freeDBQuerySuccessful;

// Metadata
- (NSString *)		title;
- (void)			setTitle:(NSString *)title;

- (NSString *)		artist;
- (void)			setArtist:(NSString *)artist;

- (unsigned)		year;
- (void)			setYear:(unsigned)year;

- (NSString *)		genre;
- (void)			setGenre:(NSString *)genre;

- (NSString *)		composer;
- (void)			setComposer:(NSString *)composer;

- (NSString *)		comment;
- (void)			setComment:(NSString *)comment;

- (NSImage *)		albumArt;
- (void)			setAlbumArt:(NSImage *)albumArt;

- (NSDate *)		albumArtDownloadDate;
- (void)			setAlbumArtDownloadDate:(NSDate *)albumArtDownloadDate;

- (unsigned)		albumArtWidth;
- (unsigned)		albumArtHeight;

- (unsigned)		discNumber;
- (void)			setDiscNumber:(unsigned)discNumber;

- (unsigned)		discTotal;
- (void)			setDiscTotal:(unsigned)discTotal;

- (BOOL)			compilation;
- (void)			setCompilation:(BOOL)compilation;

- (NSString *)		MCN;
- (void)			setMCN:(NSString *)MCN;

// KVC methods
- (unsigned)		countOfTracks;
- (Track *)			objectInTracksAtIndex:(unsigned)index;

- (void)			insertObject:(Track *)track inTracksAtIndex:(unsigned)index;
- (void)			removeObjectFromTracksAtIndex:(unsigned)index;

@end

@interface CompactDiscDocument (ScriptingAdditions)
- (id) handleEncodeScriptCommand:(NSScriptCommand *)command;
- (id) handleEjectDiscScriptCommand:(NSScriptCommand *)command;
- (id) handleQueryFreeDBScriptCommand:(NSScriptCommand *)command;
- (id) handleSubmitToFreeDBScriptCommand:(NSScriptCommand *)command;
- (id) handleToggleTrackInformationScriptCommand:(NSScriptCommand *)command;
- (id) handleToggleAlbumArtScriptCommand:(NSScriptCommand *)command;
- (id) handleFetchAlbumArtScriptCommand:(NSScriptCommand *)command;
@end
