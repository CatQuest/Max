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

#import "FreeDB.h"

#import "MallocException.h"
#import "FreeDBException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include <cddb/cddb_disc.h>
#include <cddb/cddb.h>

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
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"FreeDBDefaults.plist" forKey:@"filename"]];
		}
		cddbDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:cddbDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:cddbDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

- (id) init
{
	NSString *bundleVersion;
	
	if((self = [super init])) {
		
		_freeDB = cddb_new();
		if(NULL == _freeDB) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		cddb_set_server_name(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBServer"] UTF8String]);
		cddb_set_server_port(_freeDB, [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBPort"]);
		
		if(PROTO_HTTP == [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBProtocol"]) {
			cddb_http_enable(_freeDB);
		}
		else {
			cddb_http_disable(_freeDB);
		}
		
		cddb_set_email_address(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"emailAddress"] UTF8String]);

		// Proxy support
		if([[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBUseProxy"]) {
			cddb_http_proxy_enable(_freeDB);
			
			cddb_set_http_proxy_server_name(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyServer"] UTF8String]);
			cddb_set_http_proxy_server_port(_freeDB, [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBProxyPort"]);
			
			if([[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBUseAuthentication"]) {
				cddb_set_http_proxy_username(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyUsername"] UTF8String]);
				cddb_set_http_proxy_password(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyPassword"] UTF8String]);				
			}			
		}
		
		// Client information
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		cddb_set_client(_freeDB, "Max", [bundleVersion UTF8String]);		
		
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
	NSMutableArray			*sites			= [NSMutableArray arrayWithCapacity:20];
	const char				*tempString;
	unsigned int			i;
	float					latitude, longitude;
	NSMutableDictionary		*currentSite;
	
	
	cddb_sites(_freeDB);
	// For some reason, cddb_sites ALWAYS returns 0 (in my testing anyway)
	if(FALSE == cddb_sites(_freeDB)) {
		@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to obtain the list of FreeDB mirrors", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:cddb_errno(_freeDB)], [NSString stringWithCString:cddb_error_str(cddb_errno(_freeDB)) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	site = cddb_first_site(_freeDB);
	while(NULL != site) {
		currentSite = [NSMutableDictionary dictionaryWithCapacity:20];
		
		if(CDDB_ERR_OK == cddb_site_get_address(site, &tempString, &i)) {
			[currentSite setObject:[NSString stringWithCString:tempString encoding:NSASCIIStringEncoding] forKey:@"address"];
			[currentSite setObject:[NSNumber numberWithUnsignedInt:i] forKey:@"port"];
		}
		
		[currentSite setObject:[NSNumber numberWithInt:cddb_site_get_protocol(site)] forKey:@"protocol"];
		
		if(CDDB_ERR_OK == cddb_site_get_description(site, &tempString)) {
			[currentSite setObject:[NSString stringWithCString:tempString encoding:NSASCIIStringEncoding] forKey:@"siteDescription"];
		}
		
		if(CDDB_ERR_OK == cddb_site_get_location(site, &latitude, &longitude)) {
			[currentSite setObject:[NSNumber numberWithFloat:latitude] forKey:@"latitude"];
			[currentSite setObject:[NSNumber numberWithFloat:longitude] forKey:@"longitude"];
		}
		
		[sites addObject:currentSite];
		site = cddb_next_site(_freeDB);
	}
	
	return [[sites retain] autorelease];
}

- (NSArray *) fetchMatches
{
	NSMutableArray			*result			= [NSMutableArray arrayWithCapacity:10];
	cddb_disc_t				*freeDBDisc		= [[_disc disc] freeDBDisc];
	NSMutableDictionary		*currentMatch;
	const char				*artist;
	const char				*title;
	unsigned int			year;
	const char				*genre;
	cddb_cat_t				category;
	unsigned				discid;
	int						matches;
	

	// Run query to find matches
	matches = cddb_query(_freeDB, freeDBDisc);
	if(-1 == matches) {
		@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"FreeDB query failed", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:cddb_errno(_freeDB)], [NSString stringWithCString:cddb_error_str(cddb_errno(_freeDB)) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}

	while(matches > 0) {
		currentMatch = [NSMutableDictionary dictionaryWithCapacity:6];
		
		artist		= cddb_disc_get_artist(freeDBDisc);
		title		= cddb_disc_get_title(freeDBDisc);
		year		= cddb_disc_get_year(freeDBDisc);
		genre		= cddb_disc_get_genre(freeDBDisc);
		category	= cddb_disc_get_category(freeDBDisc);
		discid		= cddb_disc_get_discid(freeDBDisc);
		
		if(NULL != artist) {
			[currentMatch setObject:[NSString stringWithCString:artist encoding:NSASCIIStringEncoding] forKey:@"artist"];
		}
		
		if(NULL != title) {
			[currentMatch setObject:[NSString stringWithCString:title encoding:NSASCIIStringEncoding] forKey:@"title"];
		}
		
		if(0 != year) {
			[currentMatch setObject:[NSNumber numberWithUnsignedInt:year] forKey:@"year"];
		}
		
		if(NULL != genre) {
			[currentMatch setObject:[NSString stringWithCString:genre encoding:NSASCIIStringEncoding] forKey:@"genre"];
		}
		
		if(CDDB_CAT_INVALID != category) {
			[currentMatch setObject:[NSNumber numberWithInt:category] forKey:@"category"];
		}
		
		if(0 != discid) {
			[currentMatch setObject:[NSNumber numberWithUnsignedInt:discid] forKey:@"discid"];
		}

		[result addObject:currentMatch];
		
		--matches;
		if(0 < matches) {
			if(0 == cddb_query_next(_freeDB, freeDBDisc)) {
				@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"FreeDB query index out of bounds", @"Exceptions", @"")
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:cddb_errno(_freeDB)], [NSString stringWithCString:cddb_error_str(cddb_errno(_freeDB)) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
	}
		
	return [[result retain] autorelease];
}

- (void) updateDisc:(NSDictionary *)info
{
	cddb_disc_t				*disc			= NULL;
	cddb_track_t			*track			= NULL;
	const char				*artist;
	const char				*title;
	unsigned int			year;
	const char				*genre;
	const char				*ext_data;
	int						trackNum;
	
	// Create disc structure
	disc = cddb_disc_new();
	if(NULL == disc) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}

	cddb_disc_set_category(disc, [[info valueForKey:@"category"] intValue]);
	cddb_disc_set_discid(disc, [[info valueForKey:@"discid"] unsignedIntValue]);
	
	if(0 == cddb_read(_freeDB, disc)) {
		@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"FreeDB read failed", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:cddb_errno(_freeDB)], [NSString stringWithCString:cddb_error_str(cddb_errno(_freeDB)) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}

	artist		= cddb_disc_get_artist(disc);
	title		= cddb_disc_get_title(disc);
	year		= cddb_disc_get_year(disc);
	genre		= cddb_disc_get_genre(disc);
	ext_data	= cddb_disc_get_ext_data(disc);

	if(NULL != artist) {
		[_disc setArtist:[NSString stringWithCString:artist encoding:NSASCIIStringEncoding]];
	}

	if(NULL != artist) {
		[_disc setTitle:[NSString stringWithCString:title encoding:NSASCIIStringEncoding]];
	}
		
	if(0 != year) {
		[_disc setYear:year];
	}
	
	if(NULL != genre) {
		[_disc setGenre:[NSString stringWithCString:genre encoding:NSASCIIStringEncoding]];
	}
	
	if(NULL != ext_data) {
		[_disc setComment:[NSString stringWithCString:ext_data encoding:NSASCIIStringEncoding]];
	}
	
	
	track = cddb_disc_get_track_first(disc);
	while(NULL != track) {
		
		title		= cddb_track_get_title(track);
		artist		= cddb_track_get_artist(track);
		trackNum	= cddb_track_get_number(track);
		
		// Just skip this track if the number is bogus
		if(-1 == trackNum) {
			track = cddb_disc_get_track_next(disc);
			continue;
		}
		
		if(NULL != title) {
			[[_disc objectInTracksAtIndex:trackNum - 1] setTitle:[NSString stringWithCString:title encoding:NSASCIIStringEncoding]];
		}

		if(NULL != artist && NO == [[NSString stringWithCString:artist encoding:NSASCIIStringEncoding] isEqualToString:[_disc artist]]) {
			[_disc setCompilation:YES];
			[[_disc objectInTracksAtIndex:trackNum - 1] setArtist:[NSString stringWithCString:artist encoding:NSASCIIStringEncoding]];
		}
		
		track = cddb_disc_get_track_next(disc);
	}

	cddb_disc_destroy(disc);
}

- (void) submitDisc
{
	cddb_disc_t			*disc;
	NSString			*title;
	NSString			*artist;
	NSString			*genre;
	unsigned			year;
	NSString			*comment;
	cddb_track_t		*track;
	Track				*currentTrack;
	unsigned			i;

	
	disc = cddb_disc_clone([[_disc disc] freeDBDisc]);
	if(NULL == disc) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}

	genre = [_disc genre];
	if(nil != genre) {
		cddb_disc_set_category_str(disc, [[genre lowercaseString] UTF8String]);
	}
	else {
		cddb_disc_set_category(disc, CDDB_CAT_MISC);
	}
	
	// Fill in the cddb_disc_t with data from the CompactDiscDocument
	title = [_disc title];
	if(nil != title) {
		cddb_disc_set_title(disc, [title UTF8String]);
	}

	artist = [_disc artist];
	if(nil != artist) {
		cddb_disc_set_artist(disc, [artist UTF8String]);
	}

	genre = [_disc genre];
	if(nil != genre) {
		cddb_disc_set_genre(disc, [genre UTF8String]);
	}

	year = [_disc year];
	if(0 != year) {
		cddb_disc_set_year(disc, year);
	}

	comment = [_disc comment];
	if(nil != comment) {
		cddb_disc_set_ext_data(disc, [comment UTF8String]);
	}
			
	for(i = 0; i < [_disc countOfTracks]; ++i) {
		currentTrack	= [_disc objectInTracksAtIndex:i];
		track			= cddb_disc_get_track(disc, i);

		title = [currentTrack title];
		if(nil != title) {
			cddb_track_set_title(track, [title UTF8String]);
		}

		artist = ([_disc compilation] ? [currentTrack artist] : [_disc artist]);
		if(nil != artist) {
			cddb_track_set_artist(track, [artist UTF8String]);
		}
	}

	if(0 == cddb_write(_freeDB, disc)) {
		@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"FreeDB write failed", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:cddb_errno(_freeDB)], [NSString stringWithCString:cddb_error_str(cddb_errno(_freeDB)) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	// Clean up
	cddb_disc_destroy(disc);
}

@end
