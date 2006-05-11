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

#import "Track.h"
#import "CompactDiscDocument.h"
#import "MissingResourceException.h"

#include <IOKit/storage/IOCDTypes.h>

@interface Track (Private)
- (NSUndoManager *) undoManager;
@end

@implementation Track

+ (void) initialize 
{
	NSString				*trackDefaultsValuesPath;
    NSDictionary			*trackDefaultsValuesDictionary;
    
	@try {
		trackDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"TrackDefaults" ofType:@"plist"];
		if(nil == trackDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"TrackDefaults.plist" forKey:@"filename"]];
		}
		trackDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:trackDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:trackDefaultsValuesDictionary];
		
		[self setKeys:[NSArray arrayWithObjects:@"artist", @"year", @"genre", nil] triggerChangeNotificationsForDependentKey:@"color"];
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"minute"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"second"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"frame"];
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"size"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"length"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"duration"];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"Track"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id) init
{
	if((self = [super init])) {

		_document			= nil;
		
		_ripInProgress		= NO;
		_activeEncoders		= 0;
		
		_selected			= NO;
		
		_title				= nil;
		_artist				= nil;
		_year				= 0;
		_genre				= nil;
		_composer			= nil;
		_comment			= nil;
		
		_number				= 0;
		_firstSector		= 0;
		_lastSector			= 0;
		_channels			= 0;
		_preEmphasis		= NO;
		_copyPermitted		= NO;
		_ISRC				= nil;
		_dataTrack			= NO;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_document release];
	
	[_title release];
	[_artist release];
	[_genre release];
	[_composer release];

	[_ISRC release];

	[super dealloc];
}

- (NSString *) description
{
	NSString			*discArtist			= [[self document] artist];
	NSString			*trackArtist		= [self artist];
	NSString			*artist;
	NSString			*trackTitle			= [self title];
	
	artist = trackArtist;
	if(nil == artist) {
		artist = discArtist;
		if(nil == artist) {
			artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
		}
	}
	if(nil == trackTitle) {
		trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
	}
	
	
	if([[self document] compilation]) {
		return [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
	}
	else {
		return [NSString stringWithFormat:@"%@", trackTitle];		
	}
}

#pragma mark Accessors

- (unsigned) minute
{
	unsigned	sector		= [self firstSector];
	unsigned	offset		= [self lastSector] - sector + 1;
	
	return (unsigned) (offset / (60 * 75));
}

- (unsigned) second
{
	unsigned	sector		= [self firstSector];
	unsigned	offset		= [self lastSector] - sector + 1;
	
	return (unsigned) ((offset / 75) % 60);
}

- (unsigned) frame
{
	unsigned	sector		= [self firstSector];
	unsigned	offset		= [self lastSector] - sector + 1;
	
	return (unsigned) (offset % 75);
}

- (NSString *)				length				{ return [NSString stringWithFormat:@"%i:%02i", [self minute], [self second]]; }
- (CompactDiscDocument *)	document			{ return _document; }
- (NSUndoManager *)			undoManager			{ return [[self document] undoManager]; }

- (BOOL)					ripInProgress		{ return _ripInProgress; }
- (BOOL)					encodeInProgress	{ return (0 != _activeEncoders); }

- (BOOL)					selected			{ return _selected; }

- (NSString *)				title				{ return _title; }
- (NSString *)				artist				{ return _artist; }
- (unsigned)				year				{ return _year; }
- (NSString *)				genre				{ return _genre; }
- (NSString *)				composer			{ return _composer; }
- (NSString *)				comment				{ return _comment; }

- (unsigned)				size				{ return (([self lastSector] - [self firstSector]) * kCDSectorSizeCDDA); }

- (unsigned)				number				{ return _number; }
- (unsigned)				firstSector			{ return _firstSector; }
- (unsigned)				lastSector			{ return _lastSector; }
- (unsigned)				channels			{ return _channels; }
- (BOOL)					preEmphasis			{ return _preEmphasis; }
- (BOOL)					copyPermitted		{ return _copyPermitted; }
- (NSString *)				ISRC				{ return _ISRC; }
- (BOOL)					dataTrack			{ return _dataTrack; }

- (NSColor *) color
{
	NSData		*data;
	NSColor		*result		= nil;
	
	if(nil != [self artist] || 0 != [self year] || nil != [self genre]) {
		data = [[NSUserDefaults standardUserDefaults] dataForKey:@"customTrackColor"];
		if(nil != data) {
			result = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
		}
	}
	
	return result;
}

#pragma mark Mutators

- (void) setDocument:(CompactDiscDocument *)document	{ [_document release]; _document = [document retain]; }

- (void) setRipInProgress:(BOOL)ripInProgress			{ _ripInProgress = ripInProgress; }

- (void) setSelected:(BOOL)selected						{ _selected = selected; }

- (void) setNumber:(unsigned)number						{ _number = number; }
- (void) setFirstSector:(unsigned)firstSector			{ _firstSector = firstSector; }
- (void) setLastSector:(unsigned)lastSector				{ _lastSector = lastSector; }
- (void) setChannels:(unsigned)channels					{ _channels = channels; }
- (void) setPreEmphasis:(BOOL)preEmphasis				{ _preEmphasis = preEmphasis; }
- (void) setCopyPermitted:(BOOL)copyPermitted			{ _copyPermitted = copyPermitted; }
- (void) setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = [ISRC retain]; }
- (void) setDataTrack:(BOOL)dataTrack					{ _dataTrack = dataTrack; }

- (void) encodeStarted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	++_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (void) encodeCompleted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	--_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (void) setTitle:(NSString *)title
{
	if(NO == [_title isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Title", @"UndoRedo", @"")];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [_artist isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Artist", @"UndoRedo", @"")];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setYear:(unsigned)year
{
	if(_year != year) {
		[[[self undoManager] prepareWithInvocationTarget:self] setYear:_year];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Year", @"UndoRedo", @"")];
		_year = year;
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [_genre isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Genre", @"UndoRedo", @"")];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [_composer isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Composer", @"UndoRedo", @"")];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [_comment isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Comment", @"UndoRedo", @"")];
		[_comment release];
		_comment = [comment retain];
	}
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:10];
	
//	[result setObject:[NSNumber numberWithBool:[self selected]] forKey:@"selected"];

	[result setValue:[self title] forKey:@"title"];
	[result setValue:[self artist] forKey:@"artist"];
	[result setObject:[NSNumber numberWithUnsignedInt:[self year]] forKey:@"year"];
	[result setValue:[self genre] forKey:@"genre"];
	[result setValue:[self composer] forKey:@"composer"];
	[result setValue:[self comment] forKey:@"comment"];

	[result setObject:[NSNumber numberWithUnsignedInt:[self number]] forKey:@"number"];
	[result setObject:[NSNumber numberWithUnsignedLong:[self firstSector]] forKey:@"firstSector"];
	[result setObject:[NSNumber numberWithUnsignedLong:[self lastSector]] forKey:@"lastSector"];
	[result setObject:[NSNumber numberWithUnsignedInt:[self channels]] forKey:@"channels"];
	[result setObject:[NSNumber numberWithBool:[self preEmphasis]] forKey:@"preEmphasis"];
	[result setObject:[NSNumber numberWithBool:[self copyPermitted]] forKey:@"copyPermitted"];
	[result setValue:[self ISRC] forKey:@"ISRC"];
	[result setObject:[NSNumber numberWithBool:[self dataTrack]] forKey:@"dataTrack"];
	
	return [[result retain] autorelease];
}

- (void) setPropertiesFromDictionary:(NSDictionary *)properties
{	
	[_title release];
	[_artist release];
	[_genre release];
	[_composer release];
	[_comment release];
	
	[_ISRC release];

//	_selected		= [[properties valueForKey:@"selected"] boolValue];

	_title			= [[properties valueForKey:@"title"] retain];
	_artist			= [[properties valueForKey:@"artist"] retain];
	_year			= [[properties valueForKey:@"year"] intValue];
	_genre			= [[properties valueForKey:@"genre"] retain];
	_composer		= [[properties valueForKey:@"composer"] retain];
	_comment		= [[properties valueForKey:@"comment"] retain];
	
	_number			= [[properties valueForKey:@"number"] unsignedIntValue];
	_firstSector	= [[properties valueForKey:@"firstSector"] unsignedLongValue];
	_lastSector		= [[properties valueForKey:@"lastSector"] unsignedLongValue];
	_channels		= [[properties valueForKey:@"channels"] unsignedIntValue];
	_preEmphasis	= [[properties valueForKey:@"preEmphasis"] boolValue];
	_copyPermitted	= [[properties valueForKey:@"copyPermitted"] boolValue];
	_ISRC			= [[properties valueForKey:@"ISRC"] retain];
	_dataTrack		= [[properties valueForKey:@"dataTrack"] boolValue];
}

- (id) copyWithZone:(NSZone *)zone
{
	Track *copy = [[Track allocWithZone:zone] init];
	
	[copy setDocument:[self document]];
	
	[copy setSelected:[self selected]];
	
	[copy setTitle:[self title]];
	[copy setArtist:[self artist]];
	[copy setYear:[self year]];
	[copy setGenre:[self genre]];
	[copy setComposer:[self composer]];
	[copy setComment:[self comment]];
	
	[copy setNumber:[self number]];
	[copy setFirstSector:[self firstSector]];
	[copy setLastSector:[self lastSector]];
	[copy setChannels:[self channels]];
	[copy setPreEmphasis:[self preEmphasis]];
	[copy setCopyPermitted:[self copyPermitted]];
	[copy setISRC:[self ISRC]];
	[copy setDataTrack:[self dataTrack]];

	return copy;
}

- (AudioMetadata *) metadata
{
	AudioMetadata *result = [[AudioMetadata alloc] init];

	[result setTrackNumber:[self number]];
	[result setTrackTitle:[self title]];
	[result setTrackArtist:[self artist]];
	[result setTrackYear:[self year]];
	[result setTrackGenre:[self genre]];
	[result setTrackComposer:[self composer]];
	[result setTrackComment:[self comment]];
	[result setISRC:[self ISRC]];
	
	[result setAlbumTrackCount:[[self document] countOfTracks]];
	[result setAlbumTitle:[[self document] title]];
	[result setAlbumArtist:[[self document] artist]];
	[result setAlbumYear:[[self document] year]];
	[result setAlbumGenre:[[self document] genre]];
	[result setAlbumComposer:[[self document] composer]];
	[result setAlbumComment:[[self document] comment]];
		
	[result setDiscNumber:[[self document] discNumber]];
	[result setDiscTotal:[[self document] discTotal]];
	[result setCompilation:[[self document] compilation]];

	[result setAlbumArt:[[self document] albumArt]];
	
	[result setMCN:[[self document] MCN]];
	
	return [result autorelease];
}

- (void) clearFreeDBData
{
	[self setTitle:nil];
	[self setArtist:nil];
	[self setYear:0];
	[self setGenre:nil];
}

#pragma Scripting

- (NSScriptObjectSpecifier *) objectSpecifier
{
    NSArray		*tracks		= [[self document] valueForKey:@"tracks"];
    unsigned	idx			= [tracks indexOfObjectIdenticalTo:self];

    if(NSNotFound != idx) {
        NSScriptObjectSpecifier *containerRef = [[self document] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"tracks" index:idx] autorelease];
    }
	else {
        return nil;
    }
}

@end
