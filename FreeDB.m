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

#import "FreeDB.h"

#import "FreeDBSite.h"
#import "FreeDBMatch.h"
#import "MallocException.h"
#import "FreeDBException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include "cddb/cddb_disc.h"
#include "cddb/cddb.h"

@implementation FreeDB

+ (void) initialize
{
	NSString				*cddbDefaultsValuesPath;
    NSDictionary			*cddbDefaultsValuesDictionary;
    
	@try {
		cddbDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"FreeDBDefaults" ofType:@"plist"];
		if(nil == cddbDefaultsValuesPath) {
			// Hardcode default value to avoid a crash
			NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"freedb.freedb.org", @"8880", @"1", nil] forKeys:[NSArray arrayWithObjects:@"freeDBServer", @"freeDBPort", @"freeDBProtocol", nil]];
			[[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
			@throw [MissingResourceException exceptionWithReason:@"Unable to load FreeDBDefaults.plist" userInfo:nil];
		}
		cddbDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:cddbDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:cddbDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) init
{
	if((self = [super init])) {
		_freeDB = cddb_new();
		if(NULL == _freeDB) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		cddb_set_server_name(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBServer"] UTF8String]);
		cddb_set_server_port(_freeDB, [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBPort"]);
		if(PROTO_HTTP == [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBProtocol"]) {
			cddb_http_enable(_freeDB);
		}
		else {
			cddb_http_disable(_freeDB);
		}
		
		cddb_cache_disable(_freeDB);

		return self;
	}
	return nil;
}

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)disc;
{
	if((self = [self init])) {
		_disc = [disc retain];
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	cddb_destroy(_freeDB);
	[_disc release];
	[super dealloc];
}

- (NSArray *) fetchSites
{
	const cddb_site_t		*site			= NULL;
	NSMutableArray			*result			= [[NSMutableArray alloc] initWithCapacity:20];

	cddb_sites(_freeDB);
	// For some reason, cddb_sites ALWAYS returns 0 (in my testing anyway)
	if(FALSE == cddb_sites(_freeDB)) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"Unable to obtain list of FreeDB mirrors.\nlibcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}
	
	site = cddb_first_site(_freeDB);
	while(NULL != site) {
		[result addObject:[FreeDBSite createFromFreeDBSite:site]];
		site = cddb_next_site(_freeDB);
	}
	
	return [[result retain] autorelease];
}

- (NSArray *) fetchMatches
{
	NSMutableArray			*result			= [[NSMutableArray alloc] initWithCapacity:10];
	cddb_disc_t				*freeDBDisc		= [[_disc getDisc] getFreeDBDisc];
	int						matches;
	

	// Run query to find matches
	matches = cddb_query(_freeDB, freeDBDisc);
	if(-1 == matches) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"libcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}

	while(matches > 0) {
		[result addObject:[FreeDBMatch createFromFreeDBDisc:freeDBDisc]];
		
		--matches;
		if(0 < matches) {
			if(0 == cddb_query_next(_freeDB, freeDBDisc)) {
				@throw [FreeDBException exceptionWithReason:@"Query index out of bounds" userInfo:nil];
			}
		}
	}
		
	return [[result retain] autorelease];
}

- (void) updateDisc:(FreeDBMatch *)info
{
	cddb_disc_t				*disc			= NULL;
	cddb_track_t			*track			= NULL;
	const char				*tempString;
	int						tempInt;
	
	// Create disc structure
	disc = cddb_disc_new();
	if(NULL == disc) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}

	cddb_disc_set_category(disc, [[info valueForKey:@"category"] intValue]);
	cddb_disc_set_discid(disc, [[info valueForKey:@"discid"] unsignedIntValue]);
	
	if(0 == cddb_read(_freeDB, disc)) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"libcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}

	tempString = cddb_disc_get_title(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithCString:tempString] forKey:@"title"];
	}
	
	tempString = cddb_disc_get_artist(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithCString:tempString] forKey:@"artist"];		
	}
	
	tempString = cddb_disc_get_genre(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithCString:tempString] forKey:@"genre"];		
	}
	
	tempInt = cddb_disc_get_year(disc);
	if(0 != tempInt) {
		[_disc setValue:[NSNumber numberWithUnsignedInt:tempInt] forKey:@"year"];
	}

	tempString = cddb_disc_get_ext_data(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithCString:tempString] forKey:@"comment"];		
	}
	
	track = cddb_disc_get_track_first(disc);
	while(NULL != track) {
		
		tempString = cddb_track_get_title(track);
		if(NULL != tempString) {
			[[[_disc valueForKey:@"tracks"] objectAtIndex:cddb_track_get_number(track) - 1] setValue:[NSString stringWithCString:tempString] forKey:@"title"];
		}

		tempString = cddb_track_get_artist(track);
		if(NULL != tempString && NO == [[NSString stringWithCString:tempString] isEqualToString:[_disc valueForKey:@"artist"]]) {
			[_disc setValue:[NSNumber numberWithBool:YES] forKey:@"multiArtist"];
			[[[_disc valueForKey:@"tracks"] objectAtIndex:cddb_track_get_number(track) - 1] setValue:[NSString stringWithCString:tempString] forKey:@"artist"];
		}
		
		track = cddb_disc_get_track_next(disc);
	}

	cddb_disc_destroy(disc);
}

@end
