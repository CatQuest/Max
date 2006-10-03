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

@class MusicBrainzHelperData;

// Following the design of libmusicbrainz, all indexes in this object are one-based
@interface MusicBrainzHelper : NSObject
{
	MusicBrainzHelperData		*_data;
	CompactDisc					*_disc;
}

- (id)				initWithCompactDisc:(CompactDisc *)disc;

// MusicBrainz disc ID (does not go to server)
- (NSString *)		discID;

// Hits the server for the requested disc
- (IBAction)		performQuery:(id)sender;

// Number of matches found for the disc
- (unsigned)		matchCount;
- (void)			selectMatch:(unsigned)matchIndex;

// Retrieve values from the selected match
- (NSString *)		albumTitle;
- (NSString *)		albumArtist;
- (BOOL)			isVariousArtists;

- (unsigned)		releaseDate;

// Number of tracks contained in the disc
- (unsigned)		trackCount;

- (NSString *)		trackTitle:(unsigned)trackIndex;
- (NSString *)		trackArtist:(unsigned)trackIndex;

@end
