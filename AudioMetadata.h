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

@interface AudioMetadata : NSObject
{
	NSNumber				*_trackNumber;
	NSString				*_trackTitle;
	NSString				*_trackArtist;
	NSString				*_trackComposer;
	NSNumber				*_trackYear;
	NSString				*_trackGenre;
	NSString				*_trackComment;

	NSNumber				*_albumTrackCount;
	NSString				*_albumTitle;
	NSString				*_albumArtist;
	NSString				*_albumComposer;
	NSNumber				*_albumYear;
	NSString				*_albumGenre;
	NSString				*_albumComment;

	NSNumber				*_multipleArtists;
	NSNumber				*_discNumber;
	NSNumber				*_discsInSet;

	NSNumber				*_length;
	
	NSBitmapImageRep		*_albumArt;
	
	NSString				*_MCN;
	NSString				*_ISRC;
}

// Attempt to parse metadata from filename
+ (AudioMetadata *)		metadataFromFile:(NSString *)filename;

// Create output file's basename
- (NSString *)			outputBasename;

// Create output file's basename
- (NSString *)			outputBasenameWithSubstitutions:(NSDictionary *)substitutions;

@end
