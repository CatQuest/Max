/*
 *  $Id: RipperTask.m 205 2005-12-05 06:04:34Z me $
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

#import "CoreAudioConverterTask.h"
#import "CoreAudioConverter.h"

@implementation CoreAudioConverterTask

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super initWithInputFilename:inputFilename])) {
		_converter	= [[CoreAudioConverter alloc] initWithInputFilename:inputFilename];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_converter release];
	[super dealloc];
}

@end
