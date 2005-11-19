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

#import "EncoderTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp

@implementation EncoderTask

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"EncoderTask::init called" userInfo:nil];
}

- (id) initWithSource:(NSString *) source target:(NSString *) target trackName:(NSString *) trackName;
{
	if((self = [super init])) {
		_target = [target retain];
		
		[self setValue:trackName forKey:@"trackName"];
		
		_encoder = [[Encoder alloc] initWithSource:source];
	}
	return self;
}

- (void) dealloc
{
	[_target release];
	
	[_encoder release];
	
	[super dealloc];
}

- (void) removeOutputFile
{
	if(-1 == unlink([_target UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}	
}

- (void) run:(id) object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		[_encoder encodeToFile:_target];		
	}
	
	@catch(StopException *exception) {
		[self removeOutputFile];
	}
	
	@catch(NSException *exception) {
		[self removeOutputFile];
		//[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStop:) withObject:self waitUntilDone:TRUE];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		[pool release];
	}
}

- (void) stop
{
	[_encoder requestStop];
}

@end
