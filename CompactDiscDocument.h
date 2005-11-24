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

#import <Cocoa/Cocoa.h>

#import "CDDrive.h"
#import "Track.h"
#import "FreeDBMatch.h"


@interface CompactDiscDocument : NSDocument 
{
    IBOutlet NSDrawer				*_trackDrawer;
    IBOutlet NSButton				*_trackInfoButton;

	// Related data structures
	CDDrive							*_drive;
	
	// ID3 tags
	NSString						*_title;			// TALB
	NSString						*_artist;			// TPE1
	NSNumber						*_year;				// TYER
	NSNumber						*_genre;			// TCON
	NSString						*_comment;			// COMM
	
	NSNumber						*_partOfSet;		// TPOS

	// Other disc info
	NSNumber						*_discNumber;
	NSNumber						*_discsInSet;
	NSNumber						*_multiArtist;
	
	NSNumber						*_stop;

	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (void)			setBSDName:(NSString *) bsdName;

- (void)			displayException:(NSException *)exception;

- (NSArray *)		selectedTracks;
- (BOOL)			emptySelection;
- (IBAction)		selectAll:(id) sender;
- (IBAction)		selectNone:(id) sender;
- (IBAction)		encode:(id) sender;

- (IBAction)		getCDInformation:(id) sender;
- (void)			updateDiscFromFreeDB:(FreeDBMatch *) info;


- (NSString *)		length;


// Save/Restore
- (NSDictionary *)	getDictionary;
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;

@end
