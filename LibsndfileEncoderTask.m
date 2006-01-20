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

#import "LibsndfileEncoderTask.h"
#import "LibsndfileEncoder.h"

@implementation LibsndfileEncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task formatInfo:(NSDictionary *)formatInfo
{
	if((self = [super initWithTask:task])) {
		_formatInfo		= [formatInfo retain];
		_encoderClass	= [LibsndfileEncoder class];

		[[task metadata] setValue:[self outputType] forKey:@"fileFormat"];

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_formatInfo release];
	[super dealloc];
}

- (void)			writeTags						{}
- (int)				getFormat						{ return [[_formatInfo valueForKey:@"sndfileFormat"] intValue]; }
- (NSString *)		extension						{ return [_formatInfo valueForKey:@"extension"]; }
- (NSString *)		outputType						{ return [_formatInfo valueForKey:@"type"]; }

@end
