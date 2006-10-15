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

#import "CoreAudioEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

#import "CoreAudioEncoderTask.h"
#import "StopException.h"

@interface CoreAudioEncoder (Private)

- (AudioFileTypeID)		fileType;
- (UInt32)				formatID;

@end

@implementation CoreAudioEncoder

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime							= [NSDate date];
	NSDictionary					*settings							= nil;
	OSStatus						err;
	AudioBufferList					bufferList;
	ssize_t							bufferLen							= 0;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	UInt32							bitrate, quality, mode;
	FSRef							ref;
	AudioFileID						audioFile							= NULL;
	ExtAudioFileRef					extAudioFile						= NULL;
	AudioStreamBasicDescription		asbd;
	AudioConverterRef				converter							= NULL;
	CFArrayRef						converterPropertySettings			= NULL;
	unsigned long					iterations							= 0;
	double							percentComplete;
	NSTimeInterval					interval;
	unsigned						secondsRemaining;
				
	@try {
		bufferList.mBuffers[0].mData = NULL;
		
		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		[[self decoder] finalizeSetup];
		
		// Parse the encoder settings
		settings				= [[self delegate] encoderSettings];
		
		// Desired output
		bzero(&asbd, sizeof(AudioStreamBasicDescription));
		asbd.mFormatID			= [self formatID];
		asbd.mFormatFlags		= [[settings objectForKey:@"formatFlags"] unsignedLongValue];
		
		//asbd.mSampleRate		= [[settings objectForKey:@"sampleRate"] doubleValue];
		asbd.mBitsPerChannel	= [[settings objectForKey:@"bitsPerChannel"] unsignedLongValue];
		
		asbd.mSampleRate		= [[self decoder] pcmFormat].mSampleRate;			
		asbd.mChannelsPerFrame	= [[self decoder] pcmFormat].mChannelsPerFrame;

		// Flesh out output structure for PCM formats
		if(kAudioFormatLinearPCM == asbd.mFormatID) {
			asbd.mFramesPerPacket	= 1;
			asbd.mBytesPerPacket	= asbd.mChannelsPerFrame * (asbd.mBitsPerChannel / 8);
			asbd.mBytesPerFrame		= asbd.mBytesPerPacket * asbd.mFramesPerPacket;
		}
		
		// Open the output file
		// There is no convenient ExtAudioFile API for wiping clean an existing file, so use AudioFile
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		NSAssert1(noErr == err, NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @""), UTCreateStringForOSType(err));
		
		err = AudioFileInitialize(&ref, [self fileType], &asbd, 0, &audioFile);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize", UTCreateStringForOSType(err));

		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFile);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID", UTCreateStringForOSType(err));
		
		asbd = [[self decoder] pcmFormat];
		err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty", UTCreateStringForOSType(err));
		
		// Tweak converter settings
		size	= sizeof(converter);
		err		= ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioConverter, &size, &converter);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty", UTCreateStringForOSType(err));
		
		// Only adjust settings if a converter exists
		if(NULL != converter) {
			// Bitrate
			if(nil != [settings objectForKey:@"bitrate"]) {
				bitrate		= [[settings objectForKey:@"bitrate"] intValue] * 1000;
				err			= AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitrate), &bitrate);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Quality
			if(nil != [settings objectForKey:@"quality"]) {
				quality		= [[settings objectForKey:@"quality"] intValue];
				err			= AudioConverterSetProperty(converter, kAudioConverterCodecQuality, sizeof(quality), &quality);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Bitrate mode (this is a semi-hack)
			if(nil != [settings objectForKey:@"vbrAvailable"]) {
				mode		= [[settings objectForKey:@"useVBR"] boolValue] ? kAudioCodecBitRateFormat_VBR : kAudioCodecBitRateFormat_CBR;
				err			= AudioConverterSetProperty(converter, kAudioCodecBitRateFormat, sizeof(mode), &mode);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Update
			size	= sizeof(converterPropertySettings);
			err		= AudioConverterGetProperty(converter, kAudioConverterPropertySettings, &size, &converterPropertySettings);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterGetProperty", UTCreateStringForOSType(err));
			
			err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ConverterConfig, size, &converterPropertySettings);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty", UTCreateStringForOSType(err));
		}					
				
		// Allocate buffer
		bufferLen						= 10 * 1024;
		bufferList.mNumberBuffers		= 1;
		bufferList.mBuffers[0].mData	= calloc(bufferLen, sizeof(uint8_t));
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		totalFrames						= [[self decoder] totalFrames];
		framesToRead					= totalFrames;
		
		// Iteratively get the data and save it to the file
		for(;;) {

			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [[self decoder] pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= bufferLen;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [[self decoder] pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount		= [[self decoder] readAudio:&bufferList frameCount:frameCount];

			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Write the data, encoding/converting in the process
			err = ExtAudioFileWrite(extAudioFile, frameCount, &bufferList);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite", UTCreateStringForOSType(err));
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([[self delegate] shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				percentComplete		= ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				interval			= -1.0 * [startTime timeIntervalSinceNow];
				secondsRemaining	= (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				
				[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
			}
			
			++iterations;
		}
	}

	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		NSException		*exception;
		
		// Close the output file
		if(NULL != extAudioFile) {
			err = ExtAudioFileDispose(extAudioFile);
			if(noErr != err) {
				exception = [NSException exceptionWithName:@"CoreAudioException" 
													reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}
		}

		if(NULL != audioFile) {
			err = AudioFileClose(audioFile);
			if(noErr != err) {
				exception = [NSException exceptionWithName:@"CoreAudioException"
													reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}
		}
		
		free(bufferList.mBuffers[0].mData);
	}

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (NSString *) settingsString
{
	NSDictionary	*settings;
	NSString		*bitrateString;
	NSString		*qualityString;
	int				bitrate			= -1;
	int				quality			= -1;
	
	settings = [[self delegate] encoderSettings];
	
	// Bitrate
	if(nil != [settings objectForKey:@"bitrate"]) {
		bitrate		= [[settings objectForKey:@"bitrate"] intValue];
	}
	
	// Quality
	if(nil != [settings objectForKey:@"quality"]) {
		quality		= [[settings objectForKey:@"quality"] intValue];
	}
	
	bitrateString = (-1 == bitrate ? @"" : [NSString stringWithFormat:@"bitrate=%u", bitrate]);
	qualityString = (-1 == quality ? @"" : [NSString stringWithFormat:@"quality=%u", quality]);

	if(-1 == bitrate && -1 == quality) {
		return [NSString stringWithFormat:@"Core Audio '%@' codec", UTCreateStringForOSType([self formatID])];
	}
	else {
		return [NSString stringWithFormat:@"Core Audio '%@' codec settings: %@ %@", UTCreateStringForOSType([self formatID]), bitrateString, qualityString];
	}
}

@end

@implementation CoreAudioEncoder (Private)

- (AudioFileTypeID)		fileType		{ return [[[[self delegate] encoderSettings] objectForKey:@"fileType"] unsignedLongValue]; }
- (UInt32)				formatID		{ return [[[[self delegate] encoderSettings] objectForKey:@"formatID"] unsignedLongValue]; }

@end
