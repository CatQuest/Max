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

#import "OggVorbisEncoder.h"

#include <Vorbis/vorbisenc.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "VorbisException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

// My (semi-arbitrary) list of supported vorbis bitrates
static int sVorbisBitrates [14] = { 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 };

@interface OggVorbisEncoder (Private)
- (void)	parseSettings;
@end

@implementation OggVorbisEncoder

- (void) parseSettings
{
	NSDictionary *settings	= [[self delegate] userInfo];
	
	_mode		= [[settings objectForKey:@"mode"] intValue];
	_quality	= [[settings objectForKey:@"quality"] floatValue];
	_bitrate	= sVorbisBitrates[[[settings objectForKey:@"bitrate"] intValue]] * 1000;
	_cbr		= [[settings objectForKey:@"useConstantBitrate"] boolValue];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime							= [NSDate date];	
	ogg_packet					header;
	ogg_packet					header_comm;
	ogg_packet					header_code;
	
	ogg_stream_state			os;
	ogg_page					og;
	ogg_packet					op;
	
	vorbis_info					vi;
	vorbis_comment				vc;
	
	vorbis_dsp_state			vd;
	vorbis_block				vb;
		
	float						**buffer;
	
	int8_t						*buffer8							= NULL;
	int16_t						*buffer16							= NULL;
	int32_t						*buffer32							= NULL;
	unsigned					wideSample;
	unsigned					sample, channel;
	
	BOOL						eos									= NO;

	AudioBufferList				bufferList;
	ssize_t						bufferLen							= 0;
	OSStatus					err;
	FSRef						ref;
	ExtAudioFileRef				extAudioFileRef						= NULL;
	AudioStreamBasicDescription asbd;
	SInt64						totalFrames, framesToRead;
	UInt32						size, frameCount;
	
	int							bytesWritten;
	
	unsigned long				iterations							= 0;
	

	// Parse the encoder settings
	[self parseSettings];

	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		bufferList.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileOpen"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(asbd);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileDataFormat, &size, &asbd);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		[self setSampleRate:asbd.mSampleRate];
		[self setBitsPerChannel:asbd.mBitsPerChannel];
		[self setChannelsPerFrame:asbd.mChannelsPerFrame];
		
		size	= sizeof(totalFrames);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFrames;
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= [self channelsPerFrame];
		
		// Allocate the buffer that will hold the interleaved audio data
		bufferLen									= 1024;
		switch([self bitsPerChannel]) {
			
			case 8:				
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int8_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int8_t);
				break;
				
			case 16:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int16_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int16_t);
				break;
				
			case 24:
			case 32:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int32_t));
				bufferList.mBuffers[0].mDataByteSize	= bufferLen * sizeof(int32_t);
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
		
		if(NULL == bufferList.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Open the output file
		_out = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Check if we should stop, and if so throw an exception
		if([_delegate shouldStop]) {
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Setup the encoder
		vorbis_info_init(&vi);
		
		// Use quality-based VBR
		if(VORBIS_MODE_QUALITY == _mode) {
			if(vorbis_encode_init_vbr(&vi, [self channelsPerFrame], [self sampleRate], _quality)) {
				@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize the Ogg Vorbis encoder.", @"Exceptions", @"") userInfo:nil];
			}
		}
		else if(VORBIS_MODE_BITRATE == _mode) {
			if(vorbis_encode_init(&vi, [self channelsPerFrame], [self sampleRate], (_cbr ? _bitrate : -1), _bitrate, (_cbr ? _bitrate : -1))) {
				@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize the Ogg Vorbis encoder.", @"Exceptions", @"") userInfo:nil];
			}
		}
		else {
			@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized vorbis mode" userInfo:nil];
		}
		
		vorbis_comment_init(&vc);
		
		vorbis_analysis_init(&vd, &vi);
		vorbis_block_init(&vd, &vb);
		
		// Use the current time as the stream id
		srand(time(NULL));
		if(-1 == ogg_stream_init(&os, rand())) {
			@throw [VorbisException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize the ogg stream.", @"Exceptions", @"") userInfo:nil];
		}
		
		// Write stream headers	
		vorbis_analysis_headerout(&vd, &vc, &header, &header_comm, &header_code);
		ogg_stream_packetin(&os, &header);
		ogg_stream_packetin(&os, &header_comm);
		ogg_stream_packetin(&os, &header_code);
		
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			bytesWritten = write(_out, og.header, og.header_len);
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			bytesWritten = write(_out, og.body, og.body_len);
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Iteratively get the PCM data and encode it
		while(NO == eos) {
			
			// Read a chunk of PCM input
			frameCount	= bufferList.mBuffers[0].mDataByteSize / [self bytesPerFrame];
			err			= ExtAudioFileRead(extAudioFileRef, &frameCount, &bufferList);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileRead"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
						
			// Expose the buffer to submit data
			buffer = vorbis_analysis_buffer(&vd, frameCount);
			
			// Split PCM data into channels and convert to 32-bit float samples for Vorbis
			switch([self bitsPerChannel]) {
				
				case 8:
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = buffer8[sample] / 128.f;
						}
					}
					break;
					
				case 16:
					buffer16 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = ((int16_t)OSSwapBigToHostInt16(buffer16[sample])) / 32768.f;
						}
					}
					break;
					
				case 24:
					buffer32 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = ((int32_t)OSSwapBigToHostInt32(buffer32[sample])) / 8388608.f;
						}
					}
					break;

				case 32:
					buffer32 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount; ++wideSample) {
						for(channel = 0; channel < bufferList.mBuffers[0].mNumberChannels; ++channel, ++sample) {
							buffer[channel][wideSample] = ((int32_t)OSSwapBigToHostInt32(buffer32[sample])) / 2147483648.f;
						}
					}
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;
			}
			
			// Tell the library how much data we actually submitted
			vorbis_analysis_wrote(&vd, frameCount);
			
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
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
			
			while(1 == vorbis_analysis_blockout(&vd, &vb)){
				
				vorbis_analysis(&vb, NULL);
				vorbis_bitrate_addblock(&vb);
				
				while(vorbis_bitrate_flushpacket(&vd, &op)) {
					
					ogg_stream_packetin(&os, &op);
					
					// Write out pages (if any)
					while(NO == eos) {
						
						if(0 == ogg_stream_pageout(&os, &og)) {
							break;
						}
						
						bytesWritten = write(_out, og.header, og.header_len);
						if(-1 == bytesWritten) {
							@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
						}
						
						bytesWritten = write(_out, og.body, og.body_len);
						if(-1 == bytesWritten) {
							@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
						}
						
						if(ogg_page_eos(&og)) {
							eos = YES;
						}
					}
				}
			}
		}
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
				
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		if(-1 == close(_out)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Clean up
		ogg_stream_clear(&os);
		vorbis_block_clear(&vb);
		vorbis_dsp_clear(&vd);
		vorbis_comment_clear(&vc);
		vorbis_info_clear(&vi);

		free(bufferList.mBuffers[0].mData);
		
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];
}

- (NSString *) settings
{
	switch(_mode) {
		case VORBIS_MODE_QUALITY:
			return [NSString stringWithFormat:@"libVorbis settings: VBR(q=%f)", _quality * 10.f];
			break;
			
		case VORBIS_MODE_BITRATE:
			return [NSString stringWithFormat:@"libVorbis settings: %@(%l kbps)", (_cbr ? @"CBR" : @"VBR"), _bitrate / 1000];
			break;
			
		default:
			return nil;
			break;
	}
}

@end
