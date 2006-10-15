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

#import "UtilityFunctions.h"

#import "CoreAudioUtilities.h"

#include <Carbon/Carbon.h>
#include <Security/AuthSession.h>

#include <sys/param.h>

#include <sndfile/sndfile.h>
#include <ogg/ogg.h>

static NSDateFormatter		*sDateFormatter			= nil;
static NSString				*sDataDirectory			= nil;
static NSArray				*sAudioExtensions		= nil;
static NSArray				*sLibsndfileExtensions	= nil;
static NSArray				*sBuiltinExtensions		= nil;

NSString *
getApplicationDataDirectory()
{
	@synchronized(sDataDirectory) {
		if(nil == sDataDirectory) {
			BOOL					isDir, result;
			NSFileManager			*manager;
			NSArray					*paths;
			
			manager			= [NSFileManager defaultManager];
			paths			= NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			sDataDirectory	= [[[paths objectAtIndex:0] stringByAppendingString:@"/Max"] retain];
			result			= [manager fileExistsAtPath:sDataDirectory isDirectory:&isDir];
			if(NO == result) {
				result		= [manager createDirectoryAtPath:sDataDirectory attributes:nil];
				NSCAssert(YES == result, NSLocalizedStringFromTable(@"Unable to create the application data directory.", @"Exceptions", @""));
			}
			else {
				NSCAssert(YES == isDir, NSLocalizedStringFromTable(@"Unable to create the application data directory.", @"Exceptions", @""));				
			}
		}
	}
	return [[sDataDirectory retain] autorelease];
}

void 
createDirectoryStructure(NSString *path)
{
	NSString		*pathPart;
	NSArray			*pathComponents		= [path pathComponents];
	
	if(1 < [pathComponents count]) {
		int				i;
		int				directoryCount		= [pathComponents count] - 1;

		// Accept a '/' as the first path
		if(NO == [[pathComponents objectAtIndex:0] isEqualToString:@"/"]) {
			pathPart = makeStringSafeForFilename([pathComponents objectAtIndex:0]);
		}
		else {
			pathPart = [pathComponents objectAtIndex:0];
		}		
		validateAndCreateDirectory(pathPart);
		
		// Iterate through all the components
		for(i = 1; i < directoryCount - 1; ++i) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:i])];				
			validateAndCreateDirectory(pathPart);
		}
		
		// Ignore trailing '/'
		if(NO == [[pathComponents objectAtIndex:directoryCount - 1] isEqualToString:@"/"]) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:directoryCount - 1])];
			validateAndCreateDirectory(pathPart);
		}
	}
}

NSString * 
makeStringSafeForFilename(NSString *string)
{
	NSCharacterSet		*characterSet		= [NSCharacterSet characterSetWithCharactersInString:@"\"\\/<>?:*|"];
	NSMutableString		*result				= [NSMutableString stringWithCapacity:[string length]];
	NSRange				range;
	
	[result setString:string];
	
	range = [result rangeOfCharacterFromSet:characterSet];		
	while(range.location != NSNotFound && range.length != 0) {
		[result replaceCharactersInRange:range withString:@"_"];
		range = [result rangeOfCharacterFromSet:characterSet];		
	}
	
	return [[result retain] autorelease];
}

NSString * 
generateUniqueFilename(NSString *basename, NSString *extension)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	unsigned			num					= 1;
	NSString			*result;
	
	result = [NSString stringWithFormat:@"%@.%@", basename, extension];
	for(;;) {
		if(NO == [manager fileExistsAtPath:result]) {
			break;
		}
		result = [NSString stringWithFormat:@"%@-%u.%@", basename, num, extension];
		++num;
	}
	
	return [[result retain] autorelease];
}

void
validateAndCreateDirectory(NSString *path)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	BOOL				isDir;
	BOOL				result;

	result = [manager fileExistsAtPath:path isDirectory:&isDir];
	if(NO == result) {
		result = [manager createDirectoryAtPath:path attributes:nil];
		NSCAssert(YES == result, NSLocalizedStringFromTable(@"Unable to create directory.", @"Exceptions", @""));
	}
	else {
		NSCAssert(YES == isDir, NSLocalizedStringFromTable(@"Unable to create directory.", @"Exceptions", @""));
	}	
}

NSArray * 
getBuiltinExtensions()
{
	@synchronized(sBuiltinExtensions) {
		if(nil == sBuiltinExtensions) {
			sBuiltinExtensions = [NSArray arrayWithObjects:@"ogg", @"flac", @"oggflac", @"spx", @"ape", @"apl", @"mac", @"wv", @"shn", @"mpc", nil];
			[sBuiltinExtensions retain];
		}
	}
	
	return sBuiltinExtensions;
}

NSArray *
getLibsndfileExtensions()
{
	SF_FORMAT_INFO			formatInfo;
	SF_INFO					info;
	int						i, majorCount = 0;

	@synchronized(sLibsndfileExtensions) {
		if(nil == sLibsndfileExtensions) {

			sf_command(NULL, SFC_GET_FORMAT_MAJOR_COUNT, &majorCount, sizeof(int)) ;

			sLibsndfileExtensions = [NSMutableArray arrayWithCapacity:majorCount];
			
			// Generic defaults
			info.channels		= 1 ;
			info.samplerate		= 0;
			
			// Loop through each major mode
			for(i = 0; i < majorCount; ++i) {	
				formatInfo.format = i;
				sf_command(NULL, SFC_GET_FORMAT_MAJOR, &formatInfo, sizeof(formatInfo));
				[(NSMutableArray *)sLibsndfileExtensions addObject:[NSString stringWithCString:formatInfo.extension encoding:NSASCIIStringEncoding]];
			}
			
			[sLibsndfileExtensions retain];
		}
	}
	
	return sLibsndfileExtensions;
}

NSArray *
getAudioExtensions()
{
	@synchronized(sAudioExtensions) {
		if(nil == sAudioExtensions) {
			sAudioExtensions = [NSMutableArray arrayWithArray:getCoreAudioExtensions()];
			[(NSMutableArray *)sAudioExtensions addObjectsFromArray:getLibsndfileExtensions()];
			[(NSMutableArray *)sAudioExtensions addObjectsFromArray:getBuiltinExtensions()];
			[sAudioExtensions retain];
		}
	}
	
	return sAudioExtensions;
}

NSString *
getID3v2Timestamp()
{
	@synchronized(sDateFormatter) {
		if(nil == sDateFormatter) {
			[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
			sDateFormatter = [[NSDateFormatter alloc] init];
			[sDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
			[sDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
		}
	}
	return [sDateFormatter stringFromDate:[NSDate date]];
}

void
addVorbisComment(FLAC__StreamMetadata		*block,
				 NSString					*key,
				 NSString					*value)
{
	NSString									*string;
	FLAC__StreamMetadata_VorbisComment_Entry	entry;
	
	string			= [NSString stringWithFormat:@"%@=%@", key, value];
	entry.entry		= (unsigned char *)strdup([string UTF8String]);
	NSCAssert(NULL != entry.entry, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
	
	entry.length	= strlen((const char *)entry.entry);
	if(NO == FLAC__metadata_object_vorbiscomment_append_comment(block, entry, NO)) {
		free(entry.entry);
		@throw [NSException exceptionWithName:@"FLACException"
									   reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"FLAC__metadata_object_vorbiscomment_append_comment"]
									 userInfo:nil];
	}	
}

OggStreamType 
oggStreamType(NSString *filename)
{
	OggStreamType			streamType				= kOggStreamTypeInvalid;
	
	int						fd						= -1;
	int						result;
	ssize_t					bytesRead;

	ogg_sync_state			oy;
	ogg_page				og;
	ogg_packet				op;
	ogg_stream_state		os;

	char					*data					= NULL;

	
	// Open the input file
	fd			= open([filename fileSystemRepresentation], O_RDONLY);
	NSCAssert1(-1 != fd, @"Unable to open the input file (%s).", strerror(errno));
		
	// Initialize Ogg data struct
	ogg_sync_init(&oy);
	
	// Get the ogg buffer for writing
	data		= ogg_sync_buffer(&oy, 4096);
	
	// Read bitstream from input file
	bytesRead	= read(fd, data, 4096);
	NSCAssert1(-1 != bytesRead, @"Unable to read from the input file (%s).", strerror(errno));
			
	// Tell the sync layer how many bytes were written to its internal buffer
	result		= ogg_sync_wrote(&oy, bytesRead);
	NSCAssert(-1 != result, @"Ogg decoding error (ogg_sync_wrote).");
	
	// Turn the data we wrote into an ogg page
	result		= ogg_sync_pageout(&oy, &og);
	NSCAssert(1 == result, @"The file does not appear to be an Ogg bitstream.");

	// Upgrade the stream type from invalid to unknown
	streamType	= kOggStreamTypeUnknown;
	
	// Initialize the stream and grab the serial number
	ogg_stream_init(&os, ogg_page_serialno(&og));

	result		= ogg_stream_pagein(&os, &og);
	NSCAssert(0 == result, @"Error reading first page of Ogg bitstream data.");
	
	result		= ogg_stream_packetout(&os, &op);
	NSCAssert(1 == result, @"Error reading initial Ogg packet header.");
	
	// Check to see if the content is Vorbis
	if(kOggStreamTypeUnknown == streamType) {
		oggpack_buffer		opb;
		char				buffer[6];
		int					packtype;
		unsigned			i;
		
		memset(buffer, 0, 6);
		oggpack_readinit(&opb, op.packet, op.bytes);
		
		packtype		= oggpack_read(&opb, 8);
		for(i = 0; i < 6; ++i) {
			buffer[i] = oggpack_read(&opb, 8);
		}
		
		if(0 == memcmp(buffer, "vorbis", 6)) {
			streamType = kOggStreamTypeVorbis;
		}
	}
		
	// Check to see if the content is Speex
	if(kOggStreamTypeUnknown == streamType) {
		if(0 == memcmp(op.packet, "Speex   ", 8)) {
			streamType = kOggStreamTypeSpeex;
		}
	}
	
	// Check to see if the content is FLAC
	// This code "borrowed" from ogg_decoder_aspect.c in libOggFLAC
	if(kOggStreamTypeUnknown == streamType) {
		uint8_t			*bytes			= (uint8_t *)op.packet;
		unsigned		headerLength	= 
			1 /*OggFLAC__MAPPING_PACKET_TYPE_LENGTH*/ +
			4 /*OggFLAC__MAPPING_MAGIC_LENGTH*/ +
			1 /*OggFLAC__MAPPING_VERSION_MAJOR_LENGTH*/ +
			1 /*OggFLAC__MAPPING_VERSION_MINOR_LENGTH*/ +
			2 /*OggFLAC__MAPPING_NUM_HEADERS_LENGTH*/;
		
		if(op.bytes >= (long)headerLength) {
			bytes += 1 /*OggFLAC__MAPPING_PACKET_TYPE_LENGTH*/;
			if(0 == memcmp(bytes, "FLAC" /*OggFLAC__MAPPING_MAGIC*/, 4 /*OggFLAC__MAPPING_MAGIC_LENGTH*/)) {
				streamType = kOggStreamTypeFLAC;
			}
		}		
	}
	
	// Clean up
	result = close(fd);
	NSCAssert1(-1 != result, @"Unable to close the input file (%s).", strerror(errno));

	ogg_stream_clear(&os);
	ogg_sync_clear(&oy);

	return streamType;
}

NSData *
getPNGDataForImage(NSImage *image)
{
	return getBitmapDataForImage(image, NSPNGFileType); 
}

NSData *
getBitmapDataForImage(NSImage					*image,
					  NSBitmapImageFileType		type)
{
	NSCParameterAssert(nil != image);

	NSEnumerator		*enumerator					= nil;
	NSImageRep			*currentRepresentation		= nil;
	NSBitmapImageRep	*bitmapRep					= nil;
	NSSize				size;
	
	enumerator = [[image representations] objectEnumerator];
	while((currentRepresentation = [enumerator nextObject])) {
		if([currentRepresentation isKindOfClass:[NSBitmapImageRep class]]) {
			bitmapRep = (NSBitmapImageRep *)currentRepresentation;
		}
	}
	
	// Create a bitmap representation if one doesn't exist
	if(nil == bitmapRep) {
		size = [image size];
		[image lockFocus];
		bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)] autorelease];
		[image unlockFocus];
	}
	
	return [bitmapRep representationUsingType:type properties:nil]; 
}

NSImage *
getIconForFile(NSString *filename, NSSize iconSize)
{
	// Thanks to Matt Neuberg <matt@tidbits.com> for this
	NSImage			*icon			= nil;
	NSImage			*newIcon		= nil;
	NSEnumerator	*enumerator		= nil;
	NSImageRep		*imageRep		= nil;
	BOOL			hasSize			= NO;
	

	// Grab the file's icon
	icon = (nil != filename ? [[NSWorkspace sharedWorkspace] iconForFile:filename] : [[NSWorkspace sharedWorkspace] iconForFileType:@""]);
	[icon setSize:iconSize];
	
	// Check the image reps for one matching the desired size
	enumerator = [[icon representations] objectEnumerator];
	while((imageRep = [enumerator nextObject])) {
		if(NSEqualSizes([imageRep size], iconSize)) {
			hasSize = YES;
			break;
		}
	}
	
	// If no matching image rep was found, scale the icon
	if(NO == hasSize) {
		newIcon = [[[NSImage alloc] initWithSize:iconSize] autorelease];
		[newIcon lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[icon drawInRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) fromRect:NSMakeRect(0, 0, [icon size].width, [icon size].height) operation:NSCompositeCopy fraction:1.0];
		[newIcon unlockFocus];
		icon = newIcon;
	}
	
	return [[icon retain] autorelease];
}

void
addFileToiTunesLibrary(NSString *filename, AudioMetadata *metadata)
{
	NSCParameterAssert(nil != filename);
	NSCParameterAssert(nil != metadata);
	
	NSDictionary				*errors				= [NSDictionary dictionary];
	NSString					*path				= nil;
	NSAppleScript				*appleScript		= nil;
	NSAppleEventDescriptor		*parameters			= nil;
	ProcessSerialNumber			psn					= { 0, kCurrentProcess };
	NSAppleEventDescriptor		*target				= nil;
	NSAppleEventDescriptor		*handler			= nil;
	NSAppleEventDescriptor		*event				= nil;
	NSAppleEventDescriptor		*result				= nil;
	NSString					*artist				= nil;
	NSString					*composer			= nil;
	NSString					*genre				= nil;
	unsigned					year				= 0;
	NSString					*comment			= nil;
	
	
	path = [[NSBundle mainBundle] pathForResource:@"Add to iTunes Library" ofType:@"scpt"];
	NSCAssert1(nil != path, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"Add to iTunes Library.scpt");
	
	appleScript = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&errors] autorelease];
	NSCAssert(nil != appleScript, @"Unable to setup AppleScript.");
	
	// Metadata fallback
	artist		= (nil == [metadata trackArtist] ? [metadata albumArtist] : [metadata trackArtist]);
	composer	= (nil == [metadata trackComposer] ? [metadata albumComposer] : [metadata trackComposer]);
	genre		= (nil == [metadata trackGenre] ? [metadata albumGenre] : [metadata trackGenre]);
	year		= (0 == [metadata trackYear] ? [metadata albumYear] : [metadata trackYear]);
	comment		= (nil == [metadata albumComment] ? [metadata trackComment] : (nil == [metadata trackComment] ? [metadata albumComment] : [NSString stringWithFormat:@"%@\n%@", [metadata trackComment], [metadata albumComment]]));
	
	parameters		= [NSAppleEventDescriptor listDescriptor];
	
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:filename]															atIndex:1];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata playlist] ? @"" : [metadata playlist])]			atIndex:2];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata albumTitle] ? @"" : [metadata albumTitle])]		atIndex:3];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == artist ? @"" : artist)]									atIndex:4];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == composer ? @"" : composer)]								atIndex:5];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == genre ? @"" : genre)]										atIndex:6];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:year]																atIndex:7];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == comment ? @"" : comment)]									atIndex:8];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithString:(nil == [metadata trackTitle] ? @"" : [metadata trackTitle])]		atIndex:9];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata trackNumber]]											atIndex:10];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata trackTotal]]												atIndex:11];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithBoolean:[metadata compilation]]											atIndex:12];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata discNumber]]												atIndex:13];
	[parameters insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:[metadata discTotal]]												atIndex:14];
	
	target			= [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(psn)];
	handler			= [NSAppleEventDescriptor descriptorWithString:[@"add_file_to_itunes_library" lowercaseString]];
	event			= [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	
	[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
	[event setParamDescriptor:parameters forKeyword:keyDirectObject];
	
	// Call the event in AppleScript
	result = [appleScript executeAppleEvent:event error:&errors];
	if(nil == result) {
		@throw [NSException exceptionWithName:@"AppleScriptError" reason:[errors objectForKey:NSAppleScriptErrorMessage] userInfo:errors];
	}
}

NSString *
generateTemporaryFilename(NSString *directory, NSString *extension)
{
	NSString				*pathString;
	OSStatus				result;
	int						intResult;
	SecuritySessionId		sessionID;
	SessionAttributeBits	sessionInfo;
	char					path [MAXPATHLEN];
	int						fd;
	
	if(nil == directory) {
		directory = NSTemporaryDirectory();
	}
	
	NSCParameterAssert(nil != directory);
	NSCParameterAssert(nil != extension);
	
	// Get the current session id for constructing the pathname
	result		= SessionGetInfo(callerSecuritySession, &sessionID, &sessionInfo);
	NSCAssert1(noErr == result, @"SessionGetInfo failed: %@", UTCreateStringForOSType(result));

	// Build the pathname
	// Should look like [directory]/[applicationName]-[sessionID]-[XXXXXXXX].[extension]
	pathString	= [NSString stringWithFormat:@"%@/%@-%.8x-XXXXXXXX.%@", directory, @"Max", sessionID, extension];
	strlcpy(path, [pathString fileSystemRepresentation], MAXPATHLEN); 
	
	fd			= mkstemps(path, 1 + [extension length]);
	NSCAssert1(-1 != fd, @"Unable to create a temporary file: %s", strerror(errno));
	
	intResult = close(fd);
	NSCAssert1(0 == intResult, @"Unable to close the temporary file: %s", strerror(errno));
	
	return [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
}
