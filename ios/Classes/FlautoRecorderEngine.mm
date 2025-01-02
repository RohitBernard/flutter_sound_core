//
//  AudioRecorder.m
//  flutter_sound
//
//  Created by larpoux on 02/05/2020.
//
/*
 * Copyright 2018, 2019, 2020, 2021 Dooboolab.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the Mozilla Public License version 2 (MPL2.0),
 * as published by the Mozilla organization.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * MPL General Public License for more details.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */



#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "Flauto.h"
#import "FlautoRecorderEngine.h"


//-------------------------------------------------------------------------------------------------------------------------------------------


/* ctor */ AudioRecorderEngine::AudioRecorderEngine(t_CODEC coder, NSString* path, NSMutableDictionary* audioSettings, FlautoRecorder* owner )
{
        NSDate *startTime = [NSDate date];
        
        flautoRecorder = owner;
        engine = [[AVAudioEngine alloc] init];
        dateCumul = 0;
        previousTS = 0;
        status = 0;

        // Force audio session configuration
        // NSLog(@"Starting audio session configuration...");
        // NSDate *sessionStartTime = [NSDate date];
        
        // // Set preferred sample rate
        // AVAudioSession *session = [AVAudioSession sharedInstance];
        // NSError *error = nil;
        
        // Set preferred sample rate
        double preferredSampleRate = [[audioSettings objectForKey:AVSampleRateKey] doubleValue];
        // [session setPreferredSampleRate:(double)preferredSampleRate error:&error];
        // if (error) {
        // NSLog(@"Failed to set preferred sample rate");
        // }
        
        // // Set audio session category and mode
        // [session setCategory:AVAudioSessionCategoryPlayAndRecord 
        //         mode:AVAudioSessionModeVoiceChat
        //         options:AVAudioSessionCategoryOptionAllowBluetooth|
        //                 AVAudioSessionCategoryOptionAllowBluetoothA2DP|
        //                 AVAudioSessionCategoryOptionDefaultToSpeaker
        //         error:&error];
        // if (error) {
        // NSLog(@"Failed to set audio session category");
        // }
        
        // [session setActive:YES error:&error];
        // if (error) {
        // NSLog(@"Failed to activate audio session");
        // }

        // NSLog(@"[AudioEngine] Audio session configuration took: %.3f ms", 
        // [[NSDate date] timeIntervalSinceDate:sessionStartTime] * 1000);

        // Get input format
        NSLog(@"Setting up audio format...");
        NSDate *formatStartTime = [NSDate date];
        
        // Get input node
        NSLog(@"Getting input node...");
        NSDate *inputNodeStartTime = [NSDate date];
        AVAudioInputNode* inputNode = [engine inputNode];
        NSLog(@"Getting input node took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:inputNodeStartTime] * 1000);
        
        // // Setup voice processing if available
        // NSLog(@"Setting up voice processing...");
        // NSDate *voiceProcessingStartTime = [NSDate date];

        // if (@available(iOS 13.0, *)) {
        //     NSError* vpError = nil;
        //     if (![inputNode setVoiceProcessingEnabled:YES error:&vpError]) {
        //         NSLog(@"Failed to enable voice processing: %@", vpError.localizedDescription);
        //     } else {
        //         NSLog(@"Voice processing enabled successfully");
        //     }
        // } else {
        //     NSLog(@"WARNING! Voice processing is only available on iOS 13+");
        // }

        NSLog(@"Voice processing setup took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:voiceProcessingStartTime] * 1000);

        // Get input format
        NSLog(@"Getting input format...");
        NSDate *inputFormatStartTime = [NSDate date];
        AVAudioFormat* inputFormat = [inputNode outputFormatForBus: 0];
        double actualSampleRate = [inputFormat sampleRate];
        AVAudioChannelLayout* layout = [inputFormat channelLayout];
        NSLog(@"Getting input format took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:inputFormatStartTime] * 1000);
        
        // Validate format
        NSLog(@"Validating format...");
        NSDate *validateStartTime = [NSDate date];
        if (actualSampleRate == 0 || layout == nil)
        {
                [NSException raise:@"Invalid Audio Session state" format:@"The Audio Session is not in a correct state to do Recording."];
        }
        NSLog(@"Format validation took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:validateStartTime] * 1000);

        // Log sample rates
        NSLog(@"Preferred sample rate: %f, Actual: %f", 
              preferredSampleRate, actualSampleRate);

        // Get audio settings
        NSLog(@"Getting audio settings...");
        NSDate *settingsStartTime = [NSDate date];
        NSNumber* nbChannels = audioSettings [AVNumberOfChannelsKey];
        NSNumber* sampleRate = audioSettings [AVSampleRateKey];
        NSLog(@"Getting audio settings took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:settingsStartTime] * 1000);
        
        // Create recording format
        NSLog(@"Creating recording format...");
        NSDate *recordingFormatStartTime = [NSDate date];
        AVAudioFormat* recordingFormat = [[AVAudioFormat alloc] 
                                        initWithCommonFormat: AVAudioPCMFormatInt16 
                                        sampleRate: sampleRate.doubleValue 
                                        channels: (unsigned int)(nbChannels.unsignedIntegerValue) 
                                        interleaved: YES];
        NSLog(@"Creating recording format took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:recordingFormatStartTime] * 1000);
        
        NSLog(@"Total audio format setup took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:formatStartTime] * 1000);

        // Setup converter
        NSLog(@"Setting up audio converter...");
        NSDate *converterStartTime = [NSDate date];
        
        AVAudioConverter* converter = [[AVAudioConverter alloc] initFromFormat:inputFormat 
                                                   toFormat:recordingFormat];
        
        if (actualSampleRate != sampleRate.doubleValue) {
            [converter setSampleRateConverterQuality:AVAudioQualityHigh];
        }

        NSLog(@"Audio converter setup took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:converterStartTime] * 1000);

        // File setup
        NSLog(@"Setting up file handling...");
        NSDate *fileStartTime = [NSDate date];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSURL* fileURL = nil;
        if (path != nil && path != (id)[NSNull null])
        {
                [fileManager removeItemAtPath:path error:nil];
                [fileManager createFileAtPath: path contents:nil attributes:nil];
                fileURL = [[NSURL alloc] initFileURLWithPath: path];
                fileHandle = [NSFileHandle fileHandleForWritingAtPath: path];
        } else
        {
                fileHandle = nil;
        }

        NSLog(@"File setup took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:fileStartTime] * 1000);

        // Install tap
        NSLog(@"Installing audio tap...");
        NSDate *tapStartTime = [NSDate date];
        
        [inputNode installTapOnBus: 0 bufferSize: 320 format: inputFormat block:
        ^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when)
        {
                // Calculate frame capacity based on sample rate and channel count ratios
                UInt32 capacity = (UInt32(recordingFormat.sampleRate) * recordingFormat.channelCount * buffer.frameLength) / 
                                 (UInt32(buffer.format.sampleRate) * buffer.format.channelCount);
                
                // Create converted buffer with calculated capacity
                AVAudioPCMBuffer* convertedBuffer = [[AVAudioPCMBuffer alloc]
                                                   initWithPCMFormat: recordingFormat 
                                                   frameCapacity: capacity];
                
                // Simplified input block that always returns the input buffer
                AVAudioConverterInputBlock inputBlock =
                ^AVAudioBuffer*(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus)
                {
                        *outStatus = AVAudioConverterInputStatus_HaveData;
                        return buffer;
                };

                NSError* error;
                [converter convertToBuffer: convertedBuffer error: &error withInputFromBlock: inputBlock];
                if (error != nil)
                {
                        NSString *errorMessage = [NSString stringWithFormat: @"[converter convertToBuffer:] error: %@", error.localizedDescription];
                        [flautoRecorder logDebug: errorMessage];
                        return;
                }

                // Rest of the processing remains the same, but now uses convertedBuffer
                int n = [convertedBuffer frameLength];
                int16_t *const bb = [convertedBuffer int16ChannelData][0];
                NSData* b = [[NSData alloc] initWithBytes: bb length: n * 2];
                
                if (n > 0)
                {
                        if (fileHandle != nil)
                        {
                                [fileHandle writeData: b];
                        } else
                        {
                                [flautoRecorder recordingData: b];
                        }
                        
                        int16_t* pt = [convertedBuffer int16ChannelData][0];
                        for (int i = 0; i < [convertedBuffer frameLength]; ++pt, ++i)
                        {
                                short curSample = *pt;
                                if (curSample > maxAmplitude)
                                {
                                        maxAmplitude = curSample;
                                }
                        }
                }
        }];

        NSLog(@"Audio tap installation took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:tapStartTime] * 1000);

        NSLog(@"Total initialization took: %.3f ms", 
              [[NSDate date] timeIntervalSinceDate:startTime] * 1000);
}
 
void AudioRecorderEngine::startRecorder()
{
        [engine startAndReturnError: nil];
        previousTS = CACurrentMediaTime() * 1000;
        status = 2;
}

void AudioRecorderEngine::stopRecorder()
{
        [engine stop];
        [fileHandle closeFile];
        if (previousTS != 0)
        {
                dateCumul += CACurrentMediaTime() * 1000 - previousTS;
                previousTS = 0;
        }
        status = 0;
        engine = nil;
}

void AudioRecorderEngine::resumeRecorder()
{
        [engine startAndReturnError: nil];
        previousTS = CACurrentMediaTime() * 1000;
        status = 2;
 
}

void AudioRecorderEngine::pauseRecorder()
{
        [engine pause];
        if (previousTS != 0)
        {
                dateCumul += CACurrentMediaTime() * 1000 - previousTS;
                previousTS = 0;
        }
        status = 1;
 
}

NSNumber* AudioRecorderEngine::recorderProgress()
{
        long r = dateCumul;
        if (previousTS != 0)
        {
                r += CACurrentMediaTime() * 1000 - previousTS;
        }
        return [NSNumber numberWithInt: (int)r];
}

NSNumber* AudioRecorderEngine::dbPeakProgress()
{
        double max = (double)maxAmplitude;
        maxAmplitude = 0;
        if (max == 0.0)
        {
                // if the microphone is off we get 0 for the amplitude which causes
                // db to be infinite.
                return [NSNumber numberWithDouble: 0.0];
        }
        

        // Calculate db based on the following article.
        // https://stackoverflow.com/questions/10655703/what-does-androids-getmaxamplitude-function-for-the-mediarecorder-actually-gi
        //
        double ref_pressure = 51805.5336;
        double p = max / ref_pressure;
        double p0 = 0.0002;
        double l = log10(p / p0);

        double db = 20.0 * l;

        return [NSNumber numberWithDouble: db];
}


int AudioRecorderEngine::getStatus()
{
     return status;
}



//-----------------------------------------------------------------------------------------------------------------------------------------
/* ctor */ avAudioRec::avAudioRec( t_CODEC codec, NSString* path, NSMutableDictionary *audioSettings, FlautoRecorder* owner)
{
        flautoRecorder = owner;
        isPaused = false;

        NSURL *audioFileURL;
        {
                audioFileURL = [NSURL fileURLWithPath: path];
        }

        audioRecorder = [[AVAudioRecorder alloc]
                        initWithURL:audioFileURL
                        settings:audioSettings
                        error:nil];
}

/* dtor */ avAudioRec::~avAudioRec()
{
        [audioRecorder stop];
        isPaused = false;
}

void avAudioRec::startRecorder()
{
          [audioRecorder setDelegate: flautoRecorder];
          [audioRecorder record];
          [audioRecorder setMeteringEnabled: YES];
          isPaused = false;
}

void avAudioRec::stopRecorder()
{
        isPaused = false;
        [audioRecorder stop];
}

void avAudioRec::resumeRecorder()
{
        [audioRecorder record];
        isPaused = false;
}

void avAudioRec::pauseRecorder()
{
        [audioRecorder pause];
        isPaused = true;

}

NSNumber* avAudioRec::recorderProgress()
{
        NSNumber* duration =    [NSNumber numberWithLong: (long)(audioRecorder.currentTime * 1000 )];

        
        [audioRecorder updateMeters];
        return duration;
}

NSNumber* avAudioRec::dbPeakProgress()
{
        NSNumber* normalizedPeakLevel = [NSNumber numberWithDouble:MIN(pow(10.0, [audioRecorder peakPowerForChannel:0] / 20.0) * 160.0, 160.0)];
        return normalizedPeakLevel;

}

int avAudioRec::getStatus()
{
     if ( [audioRecorder isRecording] )
        return 2;
     else if (isPaused)
        return 1;
     return 0;
}


