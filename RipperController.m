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

#import "RipperController.h"

#import "TaskMaster.h"
#import "IOException.h"

#include <paths.h>			//_PATH_TMP
#include <sys/param.h>		// statfs
#include <sys/mount.h>

static RipperController *sharedController = nil;

@interface RipperController (Private)
- (void) updateFreeSpace:(NSTimer *)theTimer;
@end

@implementation RipperController

- (id) init
{
	if((self = [super initWithWindowNibName:@"Ripper"])) {
		
		_timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateFreeSpace:) userInfo:nil repeats:YES];

		return self;
	}
	
	return nil;
}

+ (RipperController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController) {
			sharedController = [[self alloc] init];
		}
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            return [super allocWithZone:zone];
        }
    }
    return sharedController;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Ripper"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) updateFreeSpace:(NSTimer *)theTimer
{
	const char				*tmpDir;
	struct statfs			buf;
	unsigned long long		bytesFree;
	long double				freeSpace;
	unsigned				divisions;
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
		tmpDir = [[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] UTF8String];
	}
	else {
		tmpDir = _PATH_TMP;
	}
	
	if(-1 == statfs(tmpDir, &buf)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to get file system statistics (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	bytesFree	= (unsigned long long) buf.f_bsize * (unsigned long long) buf.f_bfree;
	freeSpace	= (long double) bytesFree;
	divisions	= 0;
	
	while(1024 < freeSpace) {
		freeSpace /= 1024;
		++divisions;
	}
	
	switch(divisions) {
		case 0:	[self setValue:[NSString stringWithFormat:@"%.2f B", freeSpace] forKey:@"freeSpace"];	break;
		case 1:	[self setValue:[NSString stringWithFormat:@"%.2f KB", freeSpace] forKey:@"freeSpace"];	break;
		case 2:	[self setValue:[NSString stringWithFormat:@"%.2f MB", freeSpace] forKey:@"freeSpace"];	break;
		case 3:	[self setValue:[NSString stringWithFormat:@"%.2f GB", freeSpace] forKey:@"freeSpace"];	break;
		case 4:	[self setValue:[NSString stringWithFormat:@"%.2f TB", freeSpace] forKey:@"freeSpace"];	break;
		case 5:	[self setValue:[NSString stringWithFormat:@"%.2f PB", freeSpace] forKey:@"freeSpace"];	break;
	}
}

@end
