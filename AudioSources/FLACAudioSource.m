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

#import "FLACAudioSource.h"

@interface FLACAudioSource (Private)

- (void)	setTotalSamples:(FLAC__uint64)totalSamples;

- (void)	setSampleRate:(Float64)sampleRate;
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel;
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame;

@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__FileDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACAudioSource		*source					= (FLACAudioSource *)client_data;

	unsigned			spaceRequired			= 0;
	
	int8_t				*buffer8				= NULL;
	int8_t				*alias8					= NULL;
	int16_t				*buffer16				= NULL;
	int16_t				*alias16				= NULL;
	int32_t				*buffer32				= NULL;
	int32_t				*alias32				= NULL;
	
	unsigned			sample, channel;
	int32_t				audioSample;
		
	// Calculate the number of audio data points contained in the frame (should be one for each channel)
	spaceRequired		= frame->header.blocksize * frame->header.channels * (frame->header.bits_per_sample / 8);
	
	if([[source pcmBuffer] freeSpaceAvailable] < spaceRequired) {
		[[source pcmBuffer] resize:spaceRequired];
	}

	switch(frame->header.bits_per_sample) {
		
		case 8:

			buffer8 = [[source pcmBuffer] exposeBufferForWriting];
			
			// Interleave the audio (no need for byte swapping)
			alias8 = buffer8;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias8++ = (int8_t)buffer[channel][sample];
				}
			}

			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 16:
			
			buffer16 = [[source pcmBuffer] exposeBufferForWriting];

			// Interleave the audio, converting to big endian byte order for the AIFF file
			alias16 = buffer16;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)buffer[channel][sample]);
				}
			}
				
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 24:				
			
			buffer8 = [[source pcmBuffer] exposeBufferForWriting];
			
			// Interleave the audio
			alias8 = buffer8;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					audioSample	= OSSwapHostToBigInt32(buffer[channel][sample]);
					*alias8++	= (int8_t)(audioSample >> 16);
					*alias8++	= (int8_t)(audioSample >> 8);
					*alias8++	= (int8_t)audioSample;
				}
			}
				
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 32:
			
			buffer32 = [[source pcmBuffer] exposeBufferForWriting];
			
			// Interleave the audio, converting to big endian byte order for the AIFF file
			alias32 = buffer32;
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias32++ = OSSwapHostToBigInt32(buffer[channel][sample]);
				}
			}
				
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__FileDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACAudioSource		*source		= (FLACAudioSource *)client_data;
	//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
	//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
	//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
	//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[source setTotalSamples:metadata->data.stream_info.total_samples];
			[source setSampleRate:metadata->data.stream_info.sample_rate];			
			[source setBitsPerChannel:metadata->data.stream_info.bits_per_sample];
			[source setChannelsPerFrame:metadata->data.stream_info.channels];
			break;
			
			/*
			 case FLAC__METADATA_TYPE_CUESHEET:
				 cueSheet = &(metadata->data.cue_sheet);
				 
				 for(i = 0; i < cueSheet->num_tracks; ++i) {
					 currentTrack = &(cueSheet->tracks[i]);
					 
					 FLAC__uint64 offset = currentTrack->offset;
					 
					 for(j = 0; j < currentTrack->num_indices; ++j) {
						 currentIndex = &(currentTrack->indices[j]);					
					 }
				 }
					 break;
				 */
	}
}

static void
errorCallback(const FLAC__FileDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
//	FLACAudioSource		*source		= (FLACAudioSource *)client_data;
	
//	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACAudioSource

- (void)			dealloc
{
	FLAC__bool					result;

	FLAC__file_decoder_finish(_flac);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	FLAC__file_decoder_delete(_flac);		_flac = NULL;
	
	[super dealloc];	
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"FLAC", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return _totalSamples; }
- (SInt64)			currentFrame					{ return -1; }
- (SInt64)			seekToFrame:(SInt64)frame		{ return -1; }

- (void)			finalizeSetup
{
	FLAC__bool					result;
	FLAC__FileDecoderState		state;	
	
	// Create FLAC decoder
	_flac		= FLAC__file_decoder_new();
	NSAssert(NULL != _flac, NSLocalizedStringFromTable(@"Unable to create the FLAC decoder.", @"Exceptions", @""));
	
	result		= FLAC__file_decoder_set_filename(_flac, [[self filename] fileSystemRepresentation]);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	/*
	 // Process cue sheets
	 result = FLAC__file_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET);
	 NSAssert(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	 */
				
	// Setup callbacks
	result		= FLAC__file_decoder_set_write_callback(_flac, writeCallback);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_metadata_callback(_flac, metadataCallback);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_error_callback(_flac, errorCallback);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	result		= FLAC__file_decoder_set_client_data(_flac, self);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Initialize decoder
	state = FLAC__file_decoder_init(_flac);
	NSAssert1(FLAC__FILE_DECODER_OK == state, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Process metadata
	result = FLAC__file_decoder_process_until_end_of_metadata(_flac);
	NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);
	
	// Setup input format descriptor
	_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
	_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
	
//	_pcmFormat.mSampleRate			= FLAC__file_decoder_get_sample_rate(_flac);
//	_pcmFormat.mChannelsPerFrame	= FLAC__file_decoder_get_channels(_flac);
//	_pcmFormat.mBitsPerChannel		= FLAC__file_decoder_get_bits_per_sample(_flac);
	
	_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
	_pcmFormat.mFramesPerPacket		= 1;
	_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	
	NSAssert(8 == _pcmFormat.mBitsPerChannel || 16 == _pcmFormat.mBitsPerChannel || 24 == _pcmFormat.mBitsPerChannel || 32 == _pcmFormat.mBitsPerChannel, @"Sample size not supported");
	
	[super finalizeSetup];
}

- (void)			fillPCMBuffer
{
	CircularBuffer				*buffer				= [self pcmBuffer];
	FLAC__bool					result;
	unsigned					blockSize;
	unsigned					channels;
	unsigned					bitsPerSample;
	unsigned					blockByteSize;

	for(;;) {

		// The only potential SNAFU here is that, on the first iteration, blocksize comes back as 0
		blockSize			= FLAC__file_decoder_get_blocksize(_flac);
		channels			= FLAC__file_decoder_get_channels(_flac);
		bitsPerSample		= FLAC__file_decoder_get_bits_per_sample(_flac); 
		
		blockByteSize		= blockSize * channels * (bitsPerSample / 8);
		
		if([buffer freeSpaceAvailable] >= blockByteSize) {
			result = FLAC__file_decoder_process_single(_flac);
			NSAssert1(YES == result, @"%s", FLAC__FileDecoderStateString[FLAC__file_decoder_get_state(_flac)]);

			if(FLAC__FILE_DECODER_END_OF_FILE == FLAC__file_decoder_get_state(_flac)) {
				break;
			}
		}
		else {
			break;
		}
	}
}

@end

@implementation FLACAudioSource (Private)

- (void)	setTotalSamples:(FLAC__uint64)totalSamples 		{ _totalSamples = totalSamples; }

- (void)	setSampleRate:(Float64)sampleRate				{ _pcmFormat.mSampleRate = sampleRate; }
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel		{ _pcmFormat.mBitsPerChannel = bitsPerChannel; }
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame	{ _pcmFormat.mChannelsPerFrame = channelsPerFrame; }

@end
