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

#import "StringValueTransformer.h"


@implementation StringValueTransformer

+ (Class) transformedValueClass
{
	return [NSNumber class];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) initWithTarget: (NSString *) target
{
	self = [super init];
	if(self) {
		_target = [target retain];
	}
	return self;
}

- (void) dealloc
{
	[_target dealloc];
	_target = nil;
	[super dealloc];
}

- (id) transformedValue:(id) value;
{
	BOOL result;
	
	if(nil == value) {
		return nil;		
	}

	if([value isKindOfClass:[NSString class]]) {
		result = [_target isEqualToString: value];
	} 
	else {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Value was not NSString." userInfo:nil];
	}

	return [NSNumber numberWithBool: result];
}

@end
