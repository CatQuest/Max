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
	unsigned				_trackNumber;
	NSString				*_trackTitle;
	NSString				*_trackArtist;
	NSString				*_trackComposer;
	unsigned				_trackYear;
	NSString				*_trackGenre;
	NSString				*_trackComment;

	unsigned				_albumTrackCount;
	NSString				*_albumTitle;
	NSString				*_albumArtist;
	NSString				*_albumComposer;
	unsigned				_albumYear;
	NSString				*_albumGenre;
	NSString				*_albumComment;

	BOOL					_compilation;
	unsigned				_discNumber;
	unsigned				_discTotal;

	unsigned				_length;
	
	NSImage					*_albumArt;
	
	NSString				*_MCN;
	NSString				*_ISRC;
	
	NSString				*_playlist;
}

// Attempt to parse metadata from filename
+ (AudioMetadata *)		metadataFromFile:(NSString *)filename;

// Create output file's basename
- (NSString *)			outputBasename;

// Create output file's basename
- (NSString *)			outputBasenameWithSubstitutions:(NSDictionary *)substitutions;

// Substitute our values for {} keywords in string
- (NSString *)			replaceKeywordsInString:(NSString *)namingScheme;

// Accessors
- (unsigned)	trackNumber;
- (NSString *)	trackTitle;
- (NSString *)	trackArtist;
- (NSString	*)	trackComposer;
- (unsigned)	trackYear;
- (NSString	*)	trackGenre;
- (NSString	*)	trackComment;

- (unsigned)	albumTrackCount;
- (NSString	*)	albumTitle;
- (NSString	*)	albumArtist;
- (NSString	*)	albumComposer;
- (unsigned)	albumYear;
- (NSString	*)	albumGenre;
- (NSString	*)	albumComment;

- (BOOL)		compilation;
- (unsigned)	discNumber;
- (unsigned)	discTotal;

- (unsigned)	length;

- (NSString *)	MCN;
- (NSString *)	ISRC;

- (NSImage *)	albumArt;

- (NSString *)	playlist;

// Mutators
- (void)		setTrackNumber:(unsigned)trackNumber;
- (void)		setTrackTitle:(NSString *)trackTitle;
- (void)		setTrackArtist:(NSString *)trackArtist;
- (void)		setTrackComposer:(NSString *)trackComposer;
- (void)		setTrackYear:(unsigned)trackYear;
- (void)		setTrackGenre:(NSString *)trackGenre;
- (void)		setTrackComment:(NSString *)trackComment;

- (void)		setAlbumTrackCount:(unsigned)albumTrackCount;
- (void)		setAlbumTitle:(NSString *)albumTitle;
- (void)		setAlbumArtist:(NSString *)albumArtist;
- (void)		setAlbumComposer:(NSString *)albumComposer;
- (void)		setAlbumYear:(unsigned)albumYear;
- (void)		setAlbumGenre:(NSString *)albumGenre;
- (void)		setAlbumComment:(NSString *)albumComment;

- (void)		setCompilation:(BOOL)compilation;
- (void)		setDiscNumber:(unsigned)discNumber;
- (void)		setDiscTotal:(unsigned)discTotal;

- (void)		setLength:(unsigned)length;

- (void)		setMCN:(NSString *)MCN;
- (void)		setISRC:(NSString *)ISRC;

- (void)		setAlbumArt:(NSImage *)albumArt;

- (void)		setPlaylist:(NSString *)playlist;

@end
