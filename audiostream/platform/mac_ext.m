#include "mac_ext.h"
#include "Python.h"
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

static AudioComponentInstance audioUnit;
static audio_callback_t audio_callback = NULL;

#define kOutputBus 0
#define kInputBus 1

void audiostream_cy_register(audio_callback_t callback) {
	audio_callback = callback;
}

static OSStatus recordingCallback(void *inRefCon, 
                                  AudioUnitRenderActionFlags *ioActionFlags, 
                                  const AudioTimeStamp *inTimeStamp, 
                                  UInt32 inBusNumber, 
                                  UInt32 inNumberFrames, 
                                  AudioBufferList *ioData) {

	PyGILState_STATE _state = PyGILState_Ensure();

	// Because of the way our audio format (setup below) is chosen:
	// we only need 1 buffer, since it is mono
	// Samples are 16 bits = 2 bytes.
	// 1 frame includes only 1 sample
	//
	AudioBuffer buffer;
	
	buffer.mNumberChannels = 1;
	buffer.mDataByteSize = inNumberFrames * 2;
	buffer.mData = malloc( inNumberFrames * 2 );
	
	// Put buffer in a AudioBufferList
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0] = buffer;
        
    // Then:
    // Obtain recorded samples
        
    OSStatus status;
        
    status = AudioUnitRender(audioUnit,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &bufferList);
	if ( status ) {
		printf("Error in AudioUnitRender(): %d\n",
				status);
		return status;
	}

	// Now, we have the samples we just read sitting in buffers in bufferList
	// Process the new data
	if ( audio_callback ) {
		audio_callback(
			bufferList.mBuffers[0].mData,
			bufferList.mBuffers[0].mDataByteSize);
	}

	// release the malloc'ed data in the buffer we created earlier
	free(bufferList.mBuffers[0].mData);

	PyGILState_Release(_state);

    return noErr;
}

int as_mac_mic_init(int rate, int channels, int encoding) {
	OSStatus status;
	audioUnit = NULL;
	PyEval_InitThreads();


	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_HALOutput;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;

	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);

	// Get audio units
	status = AudioComponentInstanceNew(inputComponent, &audioUnit);
	if ( status ) {
		printf("Error in AudioComponentInstanceNew(): %d\n",
				status);
		return -1;
	}

	// Enable IO for recording
	UInt32 flag = 1;
	status = AudioUnitSetProperty(audioUnit, 
			kAudioOutputUnitProperty_EnableIO, 
			kAudioUnitScope_Input, 
			kInputBus,
			&flag, 
			sizeof(flag));
	if ( status ) {
		printf("Error in AudioUnitSetProperty() (enable io): %d\n",
				status);
		return -1;
	}

#if 1
	// Disable IO for playback
	flag = 0;
	status = AudioUnitSetProperty(audioUnit, 
			kAudioOutputUnitProperty_EnableIO, 
			kAudioUnitScope_Output, 
			kOutputBus,
			&flag, 
			sizeof(flag));
	if ( status ) {
		printf("Error in AudioUnitSetProperty(): %d\n",
				status);
		return -1;
	}
#endif

	// Get the default input device
	AudioDeviceID inputDevice;
	UInt32 devSize = sizeof(AudioDeviceID);
    status = AudioHardwareGetProperty(
    	kAudioHardwarePropertyDefaultInputDevice,
        &devSize,
        &inputDevice);
	if ( status ) {
		printf("Error in AudioHardwareGetProperty(): %d\n",
				status);
		return -1;
	}
    status = AudioUnitSetProperty(
    	audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &inputDevice,
        sizeof(inputDevice));

	// Describe format
	AudioStreamBasicDescription audioFormat;
	UInt32 descSize = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty (audioUnit,
 	    kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        kInputBus,
        &audioFormat,
        &descSize);

#if 0
	printf("audioFormat.mSampleRate = %f\n", audioFormat.mSampleRate);
	printf("audioFormat.mFramesPerPacket = %d\n", audioFormat.mFramesPerPacket);
	printf("audioFormat.mChannelsPerFrame = %d\n", audioFormat.mChannelsPerFrame);
	printf("audioFormat.mBitsPerChannel = %d\n", audioFormat.mBitsPerChannel);
	printf("audioFormat.mBytesPerFrame = %d\n", audioFormat.mBytesPerFrame);
	printf("audioFormat.mBytesPerPacket = %d\n", audioFormat.mBytesPerPacket);
#endif

	size_t bytesPerSample = sizeof (AudioUnitSampleType);

	audioFormat.mSampleRate                 = (float)rate;
	audioFormat.mFormatID                   = kAudioFormatLinearPCM;
	audioFormat.mFormatFlags                = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket    		= 1;
	audioFormat.mChannelsPerFrame   		= channels;
	audioFormat.mBitsPerChannel             = encoding;
	audioFormat.mBytesPerFrame              = 2;
	audioFormat.mBytesPerPacket             = 2;

#if 0
	printf("bytesPerSample = %d\n", bytesPerSample);
	printf("audioFormat.mSampleRate = %f\n", audioFormat.mSampleRate);
	printf("audioFormat.mFramesPerPacket = %d\n", audioFormat.mFramesPerPacket);
	printf("audioFormat.mChannelsPerFrame = %d\n", audioFormat.mChannelsPerFrame);
	printf("audioFormat.mBitsPerChannel = %d\n", audioFormat.mBitsPerChannel);
	printf("audioFormat.mBytesPerFrame = %d\n", audioFormat.mBytesPerFrame);
	printf("audioFormat.mBytesPerPacket = %d\n", audioFormat.mBytesPerPacket);
#endif

    // Get actual buffer size
    //Float32 audioBufferSize;
    //UInt32 size = sizeof (audioBufferSize);
    //status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, &size, &audioBufferSize);
	//printf("AudioSessionGetProperty() (current io duration) status=%d size=%u audioBufferSize=%f\n",
	//		status, size, audioBufferSize);


	// Apply format
	status = AudioUnitSetProperty(audioUnit, 
			kAudioUnitProperty_StreamFormat, 
			kAudioUnitScope_Output, 
			kInputBus, 
			&audioFormat, 
			sizeof(audioFormat));
	if ( status ) {
		printf("Error in AudioUnitSetProperty() (stream format): %d\n",
				status);
		return -1;
	}

#if 0
	status = AudioUnitSetProperty(audioUnit, 
			kAudioUnitProperty_StreamFormat, 
			kAudioUnitScope_Input, 
			kOutputBus, 
			&audioFormat, 
			sizeof(audioFormat));
	if ( status ) {
		printf("Error in AudioUnitSetProperty() (stream format): %d\n",
				status);
		return -1;
	}
#endif

	// Set input callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = recordingCallback;
	callbackStruct.inputProcRefCon = 0;
	//callbackStruct.inputProcRefCon = self;
	status = AudioUnitSetProperty(audioUnit, 
			kAudioOutputUnitProperty_SetInputCallback, 
			kAudioUnitScope_Global, 
			kInputBus, 
			&callbackStruct, 
			sizeof(callbackStruct));
	if ( status ) {
		printf("Error in AudioUnitSetProperty() (callback): %d\n",
				status);
		return -1;
	}

	// Set output callback
#if 0
	callbackStruct.inputProc = playbackCallback;
	callbackStruct.inputProcRefCon = self;
	status = AudioUnitSetProperty(audioUnit, 
			kAudioUnitProperty_SetRenderCallback, 
			kAudioUnitScope_Global, 
			kOutputBus,
			&callbackStruct, 
			sizeof(callbackStruct));
	checkStatus(status);
#endif

	// Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
	/**
	flag = 0;
	status = AudioUnitSetProperty(audioUnit, 
			kAudioUnitProperty_ShouldAllocateBuffer,
			kAudioUnitScope_Output, 
			kInputBus,
			&flag, 
			sizeof(flag));
	if ( status ) {
		printf("Error in AudioUnitSetProperty() (shoud allocate buffer): %d\n",
				status);
		return -1;
	}
	**/

	// Initialize
	status = AudioUnitInitialize(audioUnit);
	if ( status ) {
		printf("Error in AudioUnitInitialize(): %d\n",
				status);
		return -1;
	}

	printf("Audio: microphone successfully initialized.\n");
	return 0;
}

int as_mac_mic_start() {
	OSStatus status = AudioOutputUnitStart(audioUnit);
	if (!status)
		printf("Audio: microphone successfully started.\n");
	return status;
}

int as_mac_mic_stop() {
	OSStatus status = AudioOutputUnitStop(audioUnit);
	return status;
}

void as_mac_mic_deinit() {
	AudioUnitUninitialize(audioUnit);
}
