/*
 *  $Id: Encoder.m 180 2005-11-27 22:04:47Z me $
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

#import "Encoder.h"

@implementation Encoder

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Encoder::init called" userInfo:nil];
}

- (id) initWithSource:(NSString *) source
{
	if((self = [super init])) {
		_sourceFilename = [source retain];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_sourceFilename release];
	[super dealloc];
}

- (void) requestStop
{
	@synchronized(self) {
		if([_started boolValue]) {
			_shouldStop = [NSNumber numberWithBool:YES];			
		}
		else {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		}
	}
}

- (ssize_t) encodeToFile:(NSString *) filename
{
	return 0;
}

- (NSString *) description
{
	return nil;
}

@end
