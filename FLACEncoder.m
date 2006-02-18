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

#import "FLACEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "FLACException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

@interface FLACEncoder (Private)
- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
@end

@implementation FLACEncoder

- (id) initWithPCMFilename:(NSString *)inputFilename
{	
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		_flac					= NULL;
		
		_exhaustiveModelSearch	= [[NSUserDefaults standardUserDefaults] boolForKey:@"flacExhaustiveModelSearch"];
		_enableMidSide			= [[NSUserDefaults standardUserDefaults] boolForKey:@"flacEnableMidSide"];
		_enableLooseMidSide		= [[NSUserDefaults standardUserDefaults] boolForKey:@"flacLooseEnableMidSide"];
		_QLPCoeffPrecision		= [[NSUserDefaults standardUserDefaults] integerForKey:@"flacQLPCoeffPrecision"];
		_minPartitionOrder		= [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMinPartitionOrder"];
		_maxPartitionOrder		= [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMaxPartitionOrder"];
		_maxLPCOrder			= [[NSUserDefaults standardUserDefaults] integerForKey:@"flacMaxLPCOrder"];
		_padding				= [[NSUserDefaults standardUserDefaults] integerForKey:@"flacPadding"];
		
		return self;	
	}
	
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate							*startTime					= [NSDate date];
	unsigned long					iterations					= 0;
	AudioBufferList					buf;
	ssize_t							buflen						= 0;
	FLAC__StreamMetadata			padding;
	FLAC__StreamMetadata			*metadata [1];
	OSStatus						err;
	FSRef							ref;
	ExtAudioFileRef					extAudioFileRef				= NULL;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		buf.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}

		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileOpen failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);;
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileGetProperty failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Allocate the input buffer
		buflen								= 1024;
		buf.mNumberBuffers					= 1;
		buf.mBuffers[0].mNumberChannels		= 2;
		buf.mBuffers[0].mDataByteSize		= buflen * sizeof(int16_t);
		buf.mBuffers[0].mData				= calloc(buflen, sizeof(int16_t));;
		if(NULL == buf.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Create the FLAC encoder
		_flac = FLAC__file_encoder_new();
		if(NULL == _flac) {
			@throw [FLACException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create FLAC encoder", @"Exceptions", @"") userInfo:nil];
		}

		// Setup FLAC encoder
		if(NO == FLAC__file_encoder_set_do_exhaustive_model_search(_flac, _exhaustiveModelSearch)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_do_mid_side_stereo(_flac, _enableMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_loose_mid_side_stereo(_flac, _enableLooseMidSide)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_qlp_coeff_precision(_flac, _QLPCoeffPrecision)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_min_residual_partition_order(_flac, _minPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_max_residual_partition_order(_flac, _maxPartitionOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_max_lpc_order(_flac, _maxLPCOrder)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}

		// Create the padding metadata block if desired
		if(0 < _padding) {
			padding.type		= FLAC__METADATA_TYPE_PADDING;
			padding.is_last		= NO;
			padding.length		= _padding;
			metadata[0]			= &padding;
			
			if(NO == FLAC__file_encoder_set_metadata(_flac, metadata, 1)) {
				@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
			}
		}
		
		// Initialize the FLAC encoder
		if(NO == FLAC__file_encoder_set_total_samples_estimate(_flac, totalFrames)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(NO == FLAC__file_encoder_set_filename(_flac, [filename UTF8String])) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
		if(FLAC__FILE_ENCODER_OK != FLAC__file_encoder_init(_flac)) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}		

		// Iteratively get the PCM data and encode it
		for(;;) {
			
			// Read a chunk of PCM input
			frameCount	= buf.mBuffers[0].mDataByteSize / _inputASBD.mBytesPerPacket;
			err			= ExtAudioFileRead(extAudioFileRef, &frameCount, &buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileRead failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// We're finished if no frames were returned
			if(0 == frameCount) {
				break;
			}
			
			// Encode the PCM data
			[self encodeChunk:&buf frameCount:frameCount];
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up the encoding process
		FLAC__file_encoder_finish(_flac);
	}
	
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException *exception;

		if(NULL != _flac) {
			FLAC__file_encoder_delete(_flac);
		}

		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithUTF8String:GetMacOSStatusErrorString(err)], [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
				
		free(buf.mBuffers[0].mData);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) encodeChunk:(const AudioBufferList *)chunk frameCount:(UInt32)frameCount;
{
	FLAC__bool		flacResult;
	int32_t			*rawPCM [2];
	int32_t			*left, *right;
	int16_t			*iter, *limit;
	
	@try {
		rawPCM[0] = NULL;
		rawPCM[1] = NULL;
		rawPCM[0] = calloc(frameCount, sizeof(int32_t));
		rawPCM[1] = calloc(frameCount, sizeof(int32_t));
		if(NULL == rawPCM[0] || NULL == rawPCM[1]) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Split PCM into channels and convert to 32-bits
		iter	= chunk->mBuffers[0].mData;
		limit	= iter + (chunk->mBuffers[0].mNumberChannels * frameCount);
		left	= rawPCM[0];
		right	= rawPCM[1];
		while(iter < limit) {
			*left++		= *iter++;
			*right++	= *iter++;
		}
		
		// Encode the chunk
		flacResult = FLAC__file_encoder_process(_flac, (const int32_t * const *)rawPCM, frameCount);
		
		if(NO == flacResult) {
			@throw [FLACException exceptionWithReason:[NSString stringWithUTF8String:FLAC__FileEncoderStateString[FLAC__file_encoder_get_state(_flac)]] userInfo:nil];
		}
	}
		
	@finally {
		free(rawPCM[0]);
		free(rawPCM[1]);
	}
}	

- (NSString *) settings
{
	return [NSString stringWithFormat:@"FLAC settings: exhaustiveModelSearch:%i midSideStereo:%i looseMidSideStereo:%i QPLCoeffPrecision:%i, minResidualPartitionOrder:%i, maxResidualPartitionOrder:%i, maxLPCOrder:%i", 
		_exhaustiveModelSearch, _enableMidSide, _enableLooseMidSide, _QLPCoeffPrecision, _minPartitionOrder, _maxPartitionOrder, _maxLPCOrder];
}

@end
