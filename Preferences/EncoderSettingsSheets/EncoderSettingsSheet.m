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

#import "EncoderSettingsSheet.h"
#import "PreferencesController.h"
#import "MissingResourceException.h"

@implementation EncoderSettingsSheet

+ (NSDictionary *) defaultSettings { return [NSDictionary dictionary]; }

- (id) initWithNibName:(NSString *)nibName settings:(NSDictionary *)settings;
{
	if((self = [super init])) {
		
		// Setup the settings before loading the nib
		_settings		= [[NSMutableDictionary alloc] init];
		[_settings addEntriesFromDictionary:settings];
		
		_searchKey	= nil;
		_userInfo	= nil;

		if(NO == [NSBundle loadNibNamed:nibName owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@.nib", nibName] forKey:@"filename"]];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_settings release];
	[_userInfo release];
	[_searchKey release];
	[super dealloc];
}

- (NSDictionary *)	searchKey									{ return _searchKey; }
- (void)			setSearchKey:(NSDictionary *)searchKey		{ [_searchKey release]; _searchKey = [searchKey retain]; }

- (NSDictionary *)	userInfo									{ return _userInfo; }
- (void)			setUserInfo:(NSDictionary *)userInfo		{ [_userInfo release]; _userInfo = [userInfo retain]; }

- (void) editSettings
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[[PreferencesController sharedPreferences] window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction) ok:(id)sender
{
	NSMutableArray			*formats		= nil;
	NSMutableDictionary		*newFormat		= nil;
	unsigned				idx				= NSNotFound;

	// Swap out the userInfo object in this format's dictionary with the modified one
	formats		= [[[NSUserDefaults standardUserDefaults] arrayForKey:@"outputFormats"] mutableCopy];
	idx			= [formats indexOfObject:[self searchKey]];
	
	if(NSNotFound != idx) {
		newFormat	= [[self searchKey] mutableCopy];
		
		[newFormat setObject:_settings forKey:@"userInfo"];
		[formats replaceObjectAtIndex:idx withObject:newFormat];
		
		// Save changes
		[[NSUserDefaults standardUserDefaults] setObject:formats forKey:@"outputFormats"];
	}

	// We're finished
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

@end
