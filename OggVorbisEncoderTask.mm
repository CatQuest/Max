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

#import "OggVorbisEncoderTask.h"
#import "OggVorbisEncoder.h"
#import "IOException.h"

#include <TagLib/vorbisfile.h>			// TagLib::Ogg::Vorbis::File
#include <TagLib/tag.h>					// TagLib::Tag

@implementation OggVorbisEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super initWithTask:task])) {
		_encoderClass = [OggVorbisEncoder class];
		return self;
	}
	return nil;
}

- (void) writeTags
{
	AudioMetadata								*metadata				= [_task metadata];
	unsigned									trackNumber				= 0;
	unsigned									trackTotal				= 0;
	unsigned									discNumber				= 0;
	unsigned									discTotal				= 0;
	BOOL										compilation				= NO;
	NSString									*album					= nil;
	NSString									*artist					= nil;
	NSString									*composer				= nil;
	NSString									*title					= nil;
	unsigned									year					= 0;
	NSString									*genre					= nil;
	NSString									*comment				= nil;
	NSString									*isrc					= nil;
	NSString									*mcn					= nil;
	TagLib::Ogg::Vorbis::File					f						([_outputFilename fileSystemRepresentation], false);

	
	if(NO == f.isValid()) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the output file for tagging", @"Exceptions", @"") userInfo:nil];
	}

	// Album title
	album = [metadata albumTitle];
	if(nil != album) {
		f.tag()->setAlbum(TagLib::String([album UTF8String], TagLib::String::UTF8));
	}
	
	// Artist
	artist = [metadata trackArtist];
	if(nil == artist) {
		artist = [metadata albumArtist];
	}
	if(nil != artist) {
		f.tag()->setArtist(TagLib::String([artist UTF8String], TagLib::String::UTF8));
	}

	// Composer
	composer = [metadata trackComposer];
	if(nil == composer) {
		composer = [metadata albumComposer];
	}
	if(nil != composer) {
		f.tag()->addField("COMPOSER", TagLib::String([composer UTF8String], TagLib::String::UTF8));
	}
	
	// Genre
	genre = [metadata trackGenre];
	if(nil == genre) {
		genre = [metadata albumGenre];
	}
	if(nil != genre) {
		f.tag()->setGenre(TagLib::String([genre UTF8String], TagLib::String::UTF8));
	}
	
	// Year
	year = [metadata trackYear];
	if(0 == year) {
		year = [metadata albumYear];
	}
	if(0 != year) {
		f.tag()->setYear(year);
	}
	
	// Comment
	comment = [metadata albumComment];
	if(_writeSettingsToComment) {
		comment = (nil == comment ? [self settings] : [NSString stringWithFormat:@"%@\n%@", comment, [self settings]]);
	}
	if(nil != comment) {
		f.tag()->setComment(TagLib::String([comment UTF8String], TagLib::String::UTF8));
	}
	
	// Track title
	title = [metadata trackTitle];
	if(nil != title) {
		f.tag()->setTitle(TagLib::String([title UTF8String], TagLib::String::UTF8));
	}
	
	// Track number
	trackNumber = [metadata trackNumber];
	if(0 != trackNumber) {
		f.tag()->setTrack(trackNumber);
	}

	// Track total
	trackTotal = [metadata albumTrackCount];
	if(0 != trackTotal) {
		f.tag()->addField("TRACKTOTAL", TagLib::String([[NSString stringWithFormat:@"%u", trackTotal] UTF8String], TagLib::String::UTF8));
	}

	// Disc number
	discNumber = [metadata discNumber];
	if(0 != discNumber) {
		f.tag()->addField("DISCNUMBER", TagLib::String([[NSString stringWithFormat:@"%u", discNumber] UTF8String], TagLib::String::UTF8));
	}
	
	// Discs in set
	discTotal = [metadata discTotal];
	if(0 != discTotal) {
		f.tag()->addField("DISCTOTAL", TagLib::String([[NSString stringWithFormat:@"%u", discTotal] UTF8String], TagLib::String::UTF8));
	}

	// Compilation
	compilation = [metadata compilation];
	if(compilation) {
		f.tag()->addField("COMPILATION", TagLib::String([@"1" UTF8String], TagLib::String::UTF8));
	}
	
	// ISRC
	isrc = [metadata ISRC];
	if(nil != isrc) {
		f.tag()->addField("ISRC", TagLib::String([isrc UTF8String], TagLib::String::UTF8));
	}

	// MCN
	mcn = [metadata MCN];
	if(nil != mcn) {
		f.tag()->addField("MCN", TagLib::String([mcn UTF8String], TagLib::String::UTF8));
	}
	
	// Encoder settings
	f.tag()->addField("ENCODING", TagLib::String([[self settings] UTF8String], TagLib::String::UTF8));
	
	f.save();
}

- (NSString *)		extension						{ return @"ogg"; }
- (NSString *)		outputFormat					{ return NSLocalizedStringFromTable(@"Ogg Vorbis", @"General", @""); }

@end
