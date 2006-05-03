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

#import <Cocoa/Cocoa.h>

#import "PCMGeneratingTask.h"
#import "EncoderTask.h"

// List of the converter/encoder components available in Max
enum {
	kComponentCoreAudio			= 0,
	kComponentLibsndfile		= 1,
	
	kComponentFLAC				= 2,
	kComponentOggFLAC			= 3,
	kComponentWavPack			= 4,
	kComponentMonkeysAudio		= 5,
	kComponentOggVorbis			= 6,
	kComponentMP3				= 7,
	kComponentSpeex				= 8
};

@interface EncoderController : NSWindowController
{
	IBOutlet NSTableView		*_taskTable;
	IBOutlet NSArrayController	*_tasksController;
	
	NSArray						*_tasks;
	NSTimer						*_timer;
	NSString					*_freeSpace;
	BOOL						_freeze;
}

+ (EncoderController *)	sharedController;

// Functionality
- (void)			runEncodersForTask:(PCMGeneratingTask *)task;

- (BOOL)			documentHasEncoderTasks:(CompactDiscDocument *)document;
- (void)			stopEncoderTasksForDocument:(CompactDiscDocument *)document;

- (BOOL)			hasTasks;
- (unsigned)		countOfTasks;

// Action methods
- (IBAction)		stopSelectedTasks:(id)sender;
- (IBAction)		stopAllTasks:(id)sender;

// Callbacks
- (void)			encoderTaskDidStart:(EncoderTask *)task;
- (void)			encoderTaskDidStop:(EncoderTask *)task;
- (void)			encoderTaskDidComplete:(EncoderTask *)task;

@end
