/*
 *  $Id: CompactDisc.h 122 2005-11-18 21:57:28Z me $
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

#import <Cocoa/Cocoa.h>

#include "cdparanoia/interface/cdda_interface.h"


@interface CDDrive : NSObject
{
	NSString		*_bsdName;
	cdrom_drive		*_drive;
}

- (id) initWithBSDName:(NSString *) bsdName;

//- (cdrom_drive *) drive;

- (unsigned long) firstSector;
- (unsigned long) lastSector;

- (unsigned) trackCount;
- (unsigned) trackContainingSector:(unsigned long) sector;

- (unsigned long) firstSectorForTrack:(ssize_t) track;
- (unsigned long) lastSectorForTrack:(ssize_t) track;

- (unsigned) channelsForTrack:(ssize_t) track;

- (BOOL) trackContainsAudio:(ssize_t) track;
- (BOOL) trackHasPreEmphasis:(ssize_t) track;
- (BOOL) trackAllowsDigitalCopy:(ssize_t) track;

//- (id < Ripper>) getRipper;

@end
