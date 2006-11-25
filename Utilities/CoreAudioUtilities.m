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

#import "CoreAudioUtilities.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <CoreServices/CoreServices.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioUnit/AudioCodec.h>

// Prototypes
static NSMutableArray *			getCoreAudioEncodeFormats();
static BOOL						formatIDValidForOutput(UInt32 formatID);
static NSMutableArray *			getCoreAudioFileDataFormats(OSType filetype);
static NSMutableDictionary *	getCoreAudioFileTypeInfo(OSType filetype);

#pragma mark Implementation

static NSArray *sEncodeFormats		= nil;
static NSArray *sWritableTypes		= nil;
static NSArray *sReadableTypes		= nil;
static NSArray *sAudioExtensions	= nil;

// Returns an array of valid formatIDs for encoding
static NSMutableArray *
getCoreAudioEncodeFormats() 
{
	OSStatus			err;
	UInt32				size;
	UInt32				*writableFormats			= NULL;
	int					numWritableFormats, i;
	NSMutableArray		*result;
	
	@try {
		err					= AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size);
		writableFormats		= malloc(size);
		NSCAssert(NULL != writableFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		numWritableFormats	= size / sizeof(UInt32);
		result				= [NSMutableArray arrayWithCapacity:numWritableFormats];
		err					= AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size, writableFormats);
		
		for(i = 0; i < numWritableFormats; ++i) {
			[result addObject:[NSNumber numberWithUnsignedLong:writableFormats[i]]];		
		}
	}
		
	@finally {
		free(writableFormats);
	}
	
	return [[result retain] autorelease];
}

// Determine if the given formatID is valid for output
static BOOL
formatIDValidForOutput(UInt32 formatID)
{
	@synchronized(sEncodeFormats) {
		if(nil == sEncodeFormats) {
			sEncodeFormats = [getCoreAudioEncodeFormats() retain];
		}
	}

	return (kAudioFormatLinearPCM == formatID || [sEncodeFormats containsObject:[NSNumber numberWithUnsignedLong:formatID]]);
}

NSMutableArray *
getCoreAudioFileDataFormats(OSType filetype)
{
	OSStatus						err;
	UInt32							size;
	NSMutableArray					*result;
	int								numDataFormats, j, k;
	OSType							*formatIDs					= NULL;
	int								numVariants;
	NSMutableArray					*variantsA;
	AudioStreamBasicDescription		*variants					= NULL;
	AudioFileTypeAndFormatID		tf;
	NSMutableDictionary				*dfi;
	NSString						*description;
	AudioStreamBasicDescription		*desc;
	AudioStreamBasicDescription		inputASBD;
	AudioConverterRef				dummyConverter;
	NSMutableDictionary				*d;
	AudioValueRange					*bitrates					= NULL;
	NSMutableArray					*bitratesA;
	ssize_t							bitrateCount, n;
	UInt32							defaultBitrate, defaultQuality;
	
	
	@try {
		err				= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size);
		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

		numDataFormats	= size / sizeof(OSType);
		formatIDs		= malloc(size);
		NSCAssert(NULL != formatIDs, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		err				= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size, formatIDs);
		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

		result			= [NSMutableArray arrayWithCapacity:numDataFormats];
		
		for(j = 0; j < numDataFormats; ++j) {
			tf.mFileType	= filetype;
			tf.mFormatID	= formatIDs[j];
			dfi				= [NSMutableDictionary dictionaryWithCapacity:5];
			
			[dfi setObject:[NSNumber numberWithUnsignedLong:formatIDs[j]] forKey:@"formatID"];
			
			err				= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size);
			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

			variants		= malloc(size);
			NSCAssert(NULL != variants, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			numVariants		= size / sizeof(AudioStreamBasicDescription);
			variantsA		= [NSMutableArray arrayWithCapacity:numVariants];
			err				= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size, variants);
			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
			
			for(k = 0; k < numVariants; ++k) {
				
				desc	= &variants[k];
				d		= [NSMutableDictionary dictionaryWithCapacity:8];
		
				[d setObject:[NSNumber numberWithDouble:desc->mSampleRate] forKey:@"sampleRate"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc->mFormatID] forKey:@"formatID"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc->mFormatFlags] forKey:@"formatFlags"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc->mBitsPerChannel] forKey:@"bitsPerChannel"];
				[d setObject:[NSNumber numberWithBool:formatIDValidForOutput(desc->mFormatID)] forKey:@"writable"];
				
				// Interleaved 16-bit PCM audio
				inputASBD.mSampleRate			= 44100.f;
				inputASBD.mFormatID				= kAudioFormatLinearPCM;
				inputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
				inputASBD.mBytesPerPacket		= 4;
				inputASBD.mFramesPerPacket		= 1;
				inputASBD.mBytesPerFrame		= 4;
				inputASBD.mChannelsPerFrame		= 2;
				inputASBD.mBitsPerChannel		= 16;
				
				// Create a dummy converter to query
				err = AudioConverterNew(&inputASBD, desc, &dummyConverter);
				if(noErr == err) {

					// Get the available bitrates (CBR)
					err			= AudioConverterGetPropertyInfo(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, NULL);
					bitrates	= malloc(size);
					NSCAssert(NULL != bitrates, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
					
					err			= AudioConverterGetProperty(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, bitrates);
					if(noErr == err) {
						bitrateCount	= size / sizeof(AudioValueRange);
						bitratesA		= [NSMutableArray arrayWithCapacity:bitrateCount];
						for(n = 0; n < bitrateCount; ++n) {
							unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
							if(0 != minRate) {
								[bitratesA addObject:[NSNumber numberWithUnsignedLong: minRate / 1000]];
							}
						}
						
						// For some reason some codec return {0.,0.} as bitrates multiple times (alac)
						if(0 != [bitratesA count]) {
							[d setObject:bitratesA forKey:@"bitrates"];
						}
						
						size	= sizeof(defaultBitrate);
						err		= AudioConverterGetProperty(dummyConverter, kAudioConverterEncodeBitRate, &size, &defaultBitrate);
						if(noErr != err) {
							NSLog(@"kAudioConverterEncodeBitRate failed: err = %@", UTCreateStringForOSType(err));
						}
						[d setObject:[NSNumber numberWithUnsignedLong:defaultBitrate / 1000] forKey:@"bitrate"];
						
						free(bitrates);
						bitrates = NULL;
					}

					// Get the available bitrates (VBR)
					err			= AudioConverterGetPropertyInfo(dummyConverter, kAudioCodecBitRateFormat, &size, NULL);
					if(noErr == err) {
						[d setObject:[NSNumber numberWithBool:YES] forKey:@"vbrAvailable"];

						UInt32 mode		= kAudioCodecBitRateFormat_VBR;
						err			= AudioConverterSetProperty(dummyConverter, kAudioCodecBitRateFormat, sizeof(mode), &mode);
						NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed (%@).", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));

						err			= AudioConverterGetPropertyInfo(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, NULL);

						bitrates	= malloc(size);
						NSCAssert(NULL != bitrates, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
						
						// Determine which bitrates are supported for VBR (if any)
						err			= AudioConverterGetProperty(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, bitrates);
						if(noErr == err) {
							bitrateCount	= size / sizeof(AudioValueRange);
							bitratesA		= [NSMutableArray arrayWithCapacity:bitrateCount];
							for(n = 0; n < bitrateCount; ++n) {
								unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
								if(0 != minRate) {
									[bitratesA addObject:[NSNumber numberWithUnsignedLong: minRate / 1000]];
								}
							}
							
							// For some reason some codec return {0.,0.} as bitrates multiple times (alac)
							if(0 != [bitratesA count]) {
								[d setObject:bitratesA forKey:@"bitratesVBR"];
							}
														
							free(bitrates);
							bitrates = NULL;
						}
					}
				
					// Get the quality settings
					size	= sizeof(defaultQuality);
					err		= AudioConverterGetProperty(dummyConverter, kAudioConverterCodecQuality, &size, &defaultQuality);
					if(noErr == err) {
						[d setObject:[NSNumber numberWithUnsignedLong:defaultQuality] forKey:@"quality"];
					}

					// Cleanup
					err = AudioConverterDispose(dummyConverter);
					NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterDispose", UTCreateStringForOSType(err));
				}

				size	= sizeof(description);
				err		= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), desc, &size, &description);
				if(noErr != err) {
					description = NSLocalizedStringFromTable(@"Unknown", @"General", @"");
				}
				
				[d setObject:description forKey:@"description"];
							
				[variantsA addObject:d];
			}			
			
			[result addObjectsFromArray:variantsA];
			free(variants);
			variants = NULL;
		}
	}
	
	@finally {
		free(bitrates);
		free(variants);
		free(formatIDs);
	}

	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	[result sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	
	return [[result retain] autorelease];
}

static NSMutableDictionary *
getCoreAudioFileTypeInfo(OSType filetype)
{
	OSStatus				err;
	UInt32					size;
	NSMutableDictionary		*result				= [NSMutableDictionary dictionaryWithCapacity:2];
	NSString				*fileTypeName		= nil;
	NSArray					*extensions			= nil;
	
	// file type name
	size = sizeof(fileTypeName);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, sizeof(UInt32), &filetype, &size, &fileTypeName);
	NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

	if(fileTypeName) {
		[result setObject:fileTypeName forKey:@"fileTypeName"];
	}
	
	// file extensions
	size = sizeof(extensions);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType, sizeof(OSType), &filetype, &size, &extensions);
	NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

	if(extensions) {
		[result setObject:extensions forKey:@"extensionsForType"];
	}
	
	[result setObject:getCoreAudioFileDataFormats(filetype) forKey:@"dataFormats"];
	
	return [[result retain] autorelease];
}

// Return an array of information on valid formats for output
NSArray *
getCoreAudioWritableTypes()
{
	OSStatus			err;
	UInt32				size;
	UInt32				*fileFormats			= NULL;
	unsigned			numFileFormats, i, j;
	NSMutableArray		*result;
	NSSortDescriptor	*sd;
	
	@synchronized(sWritableTypes) {
		if(nil == sWritableTypes) {
			@try {
				err					= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size);
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

				fileFormats			= malloc(size);
				NSCAssert(NULL != fileFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

				numFileFormats		= size / sizeof(UInt32);
				result				= [NSMutableArray arrayWithCapacity:numFileFormats];
				err					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size, fileFormats);
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
				
				for(i = 0; i < numFileFormats; ++i) {
					NSMutableDictionary		*d					= [NSMutableDictionary dictionaryWithCapacity:3];
					NSMutableArray			*dataFormats;
					NSMutableIndexSet		*indexesToRemove	= [NSMutableIndexSet indexSet];
					BOOL					writable			= NO;
					unsigned				dataFormatsCount;
					
					[d setObject:[NSNumber numberWithUnsignedLong:fileFormats[i]] forKey:@"fileType"];
					[d addEntriesFromDictionary:getCoreAudioFileTypeInfo(fileFormats[i])];
					
					dataFormats			= [d valueForKey:@"dataFormats"];
					dataFormatsCount	= [dataFormats count];
					
					// Iterate through dataFormats and remove non-writable ones if desired
					for(j = 0; j < dataFormatsCount; ++j) {
						if(NO == [[[dataFormats objectAtIndex:j] valueForKey:@"writable"] boolValue]) {
							[indexesToRemove addIndex:j];
						}
						else {
							writable = YES;
						}
					}
					
					[dataFormats removeObjectsAtIndexes:indexesToRemove];
					
					// Only add this file type if one of more of the dataFormats are writable
					if(writable) {
						[result addObject:d];		
					}
				}
				
				sd				= [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
				sWritableTypes	= [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];
				
				[sWritableTypes retain];
			}
			
			@finally {
				free(fileFormats);
			}
		}
	}
	
	return sWritableTypes;
}

// Return an array of information on valid formats for input
NSArray *
getCoreAudioReadableTypes()
{
	OSStatus			err;
	UInt32				size;
	UInt32				*fileFormats			= NULL;
	unsigned			numFileFormats, i;
	NSMutableArray		*result;
	NSSortDescriptor	*sd;
	
	@synchronized(sReadableTypes) {
		if(nil == sReadableTypes) {
			@try {
				err					= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_ReadableTypes, 0, NULL, &size);
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

				fileFormats			= malloc(size);
				NSCAssert(NULL != fileFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

				numFileFormats		= size / sizeof(UInt32);
				result				= [NSMutableArray arrayWithCapacity:numFileFormats];
				err					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ReadableTypes, 0, NULL, &size, fileFormats);
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
				
				for(i = 0; i < numFileFormats; ++i) {
					NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:3];
					
					[d setObject:[NSNumber numberWithUnsignedLong:fileFormats[i]] forKey:@"fileType"];
					[d addEntriesFromDictionary:getCoreAudioFileTypeInfo(fileFormats[i])];
					
					[result addObject:d];		
				}
				
				sd				= [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
				sReadableTypes	= [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];

				[sReadableTypes retain];
			}
					
			@finally {
				free(fileFormats);
			}
		}		
	}

	return sReadableTypes;
}

// Return an array of valid audio file extensions recognized by Core Audio
NSArray *
getCoreAudioExtensions()
{
	OSStatus			err;
	UInt32				size;
	
	@synchronized(sAudioExtensions) {
		if(nil == sAudioExtensions) {
			size	= sizeof(sAudioExtensions);
			err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllExtensions, 0, NULL, &size, &sAudioExtensions);
			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
			
			[sAudioExtensions retain];
		}
	}
	
	return sAudioExtensions;
}

// Set the format name
NSString * 
getCoreAudioOutputFormatName(AudioFileTypeID fileType, UInt32 formatID, UInt32 formatFlags)
{
	OSStatus						result;
	UInt32							specifierSize;
	UInt32							dataSize;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat				= nil;
	NSString						*audioFormat			= nil;
	NSString						*name					= nil;
	
	// Determine the name of the file (container) type
	specifierSize			= sizeof(fileType);
	dataSize				= sizeof(fileFormat);
	result					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, specifierSize, &fileType, &dataSize, &fileFormat);
	
	NSCAssert1(noErr == result, @"AudioFileGetGlobalInfo failed: %@", UTCreateStringForOSType(result));
	
	// Determine the name of the format contained in the file (if specified)
	if(0 != formatID) {
		bzero(&asbd, sizeof(AudioStreamBasicDescription));
		
		asbd.mFormatID			= formatID;
		asbd.mFormatFlags		= formatFlags;
		
		specifierSize			= sizeof(audioFormat);
		result					= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &audioFormat);
		
		NSCAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	}
	
	name = [NSString stringWithFormat:@"%@ (%@)", [fileFormat autorelease], [audioFormat autorelease]];
	
	return [[name retain] autorelease];
}
