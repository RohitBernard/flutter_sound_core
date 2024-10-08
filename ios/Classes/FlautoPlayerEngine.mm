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


//
//  PlayerEngine.h
//  Pods
//
//  Created by larpoux on 03/09/2020.
//
#import "Flauto.h"
#import "FlautoPlayerEngine.h"
#import "FlautoPlayer.h"

@implementation AudioPlayerFlauto
{
        FlautoPlayer* flautoPlayer; // Owner
        AVAudioPlayer* player;
}

       - (AVAudioPlayer*) getAudioPlayer
       {
                return player;
       }

        - (void) setAudioPlayer: (AVAudioPlayer*)thePlayer
        {
                player = thePlayer;
        }



       - (AudioPlayerFlauto*)init: (FlautoPlayer*)owner
       {
                flautoPlayer = owner;
                return [super init];
       }

       -(void) startPlayerFromBuffer: (NSData*) dataBuffer
       {
                NSError* error = [[NSError alloc] init];
                [self setAudioPlayer:  [[AVAudioPlayer alloc] initWithData: dataBuffer error: &error]];
                [self getAudioPlayer].delegate = flautoPlayer;
       }

       -(void)  startPlayerFromURL: (NSURL*) url codec: (t_CODEC)codec channels: (int)numChannels sampleRate: (long)sampleRate

       {
                [self setAudioPlayer: [[AVAudioPlayer alloc] initWithContentsOfURL: url error: nil] ];
                [self getAudioPlayer].delegate = flautoPlayer;
        }


       -(long)  getDuration
       {
                double duration =  [self getAudioPlayer].duration;
                return (long)(duration * 1000.0);
       }

       -(long)  getPosition
       {
                double position = [self getAudioPlayer].currentTime ;
                return (long)( position * 1000.0);
       }

       -(void)  stop
       {
                [ [self getAudioPlayer] stop];
                [self setAudioPlayer: nil];
       }

        -(bool)  play
        {
                bool b = [ [self getAudioPlayer] play];
                return b;
        }


       -(bool)  resume
       {
                bool b = [ [self getAudioPlayer] play];
                return b;
       }

       -(bool)  pause
       {
                [ [self getAudioPlayer] pause];
                return true;
       }


       -(bool)  setVolume: (double) volume fadeDuration:(NSTimeInterval)fadeDuration // volume is between 0.0 and 1.0
       {
               if (fadeDuration == 0)
                     [ [self getAudioPlayer] setVolume: volume ];
               else
                       [ [self getAudioPlayer] setVolume: volume fadeDuration: fadeDuration];
               return true;
       }


        -(bool)  setSpeed: (double) speed // speed is between 0.0 and 1.0 to go slower
        {
                [self getAudioPlayer].enableRate = true ; // Probably not always !!!!
                [self getAudioPlayer].rate = speed ;
                return true;
        }

       -(bool)  seek: (double) pos
       {
                [self getAudioPlayer].currentTime = pos / 1000.0;
                return true;
       }

       -(t_PLAYER_STATE)  getStatus
       {
                if (  [self getAudioPlayer] == nil )
                        return PLAYER_IS_STOPPED;
                if ( [ [self getAudioPlayer] isPlaying])
                        return PLAYER_IS_PLAYING;
                return PLAYER_IS_PAUSED;
       }


        - (int) feed: (NSData*)data
        {
                return -1;
        }

@end


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------


@implementation AudioEngine
{
        FlautoPlayer* flutterSoundPlayer; // Owner
        AVAudioEngine* engine;
        AVAudioPlayerNode* playerNode;
        AVAudioFormat* inputFormat;
        AVAudioFormat* outputFormat;
        AVAudioOutputNode* outputNode;
        AVAudioConverter* converter;
        CFTimeInterval mStartPauseTime ; // The time when playback was paused
	CFTimeInterval systemTime ; //The time when  StartPlayer() ;
        double mPauseTime ; // The number of seconds during the total Pause mode
        NSData* waitingBlock;
        long m_sampleRate ;
        int  m_numChannels;
}

       - (AudioEngine*)init: (FlautoPlayer*)owner
       {
                flutterSoundPlayer = owner;
                waitingBlock = nil;
                engine = [[AVAudioEngine alloc] init];
                outputNode = [engine outputNode];
           
                if (@available(iOS 13.0, *)) {
                    if ([flutterSoundPlayer isVoiceProcessingEnabled]) {
                        NSError* err;
                        if (![outputNode setVoiceProcessingEnabled:YES error:&err]) {
                           [flutterSoundPlayer logDebug:[NSString stringWithFormat:@"error enabling voiceProcessing => %@", err]];
                        } else {
                            [flutterSoundPlayer logDebug: @"VoiceProcessing enabled"];
                        }
                    }
                } else {
                   [flutterSoundPlayer logDebug: @"WARNING! VoiceProcessing is only available on iOS13+"];
                }
               
                outputFormat = [outputNode inputFormatForBus: 0];
           
               NSLog(@"Sample Rate: %f", outputFormat.sampleRate);
               NSLog(@"Channels: %u", outputFormat.channelCount);
               if (outputFormat.commonFormat == AVAudioPCMFormatFloat32) {
                   NSLog(@"Format: PCM Float32");
               } else if (outputFormat.commonFormat == AVAudioPCMFormatInt16) {
                   NSLog(@"Format: PCM Int16");
               } else if (outputFormat.commonFormat == AVAudioPCMFormatInt32) {
                   NSLog(@"Format: PCM Int32");
               } else {
                   NSLog(@"Format: Unknown");
               }
           
            NSLog(@"Is Interleaved: %@", outputFormat.interleaved ? @"Yes" : @"No");
           
            outputFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:48000 // Use a standard sample rate like 44.1kHz
                                                             channels:1      // Set to stereo or appropriate number of channels
                                                          interleaved:YES];

             
           
                playerNode = [[AVAudioPlayerNode alloc] init];

                [engine attachNode: playerNode];

                [engine connect: playerNode to: outputNode format: outputFormat];
                bool b = [engine startAndReturnError: nil];
                if (!b)
                {
                        [flutterSoundPlayer logDebug: @"Cannot start the audio engine"];
                }

                mPauseTime = 0.0; // Total number of seconds in pause mode
		mStartPauseTime = -1; // Not in paused mode
		systemTime = CACurrentMediaTime(); // The time when started
                return [super init];
       }

       -(void) startPlayerFromBuffer: (NSData*) dataBuffer
       {
                 [self feed: dataBuffer] ;
       }
        static int ready = 0;

       -(void)  startPlayerFromURL: (NSURL*) url codec: (t_CODEC)codec channels: (int)numChannels sampleRate: (long)sampleRate
       {
                assert(url == nil || url ==  (id)[NSNull null]);
                m_sampleRate = sampleRate;
                m_numChannels= numChannels;
                ready = 0;
       }


       -(long)  getDuration
       {
		return [self getPosition]; // It would be better if we add what is in the input buffers and not still played
       }

       -(long)  getPosition
       {
		double time ;
		if (mStartPauseTime >= 0) // In pause mode
			time =   mStartPauseTime - systemTime - mPauseTime ;
		else
			time = CACurrentMediaTime() - systemTime - mPauseTime;
		return (long)(time * 1000);
       }

       -(void)  stop
       {

                if (engine != nil)
                {
                        if (playerNode != nil)
                        {
                                [playerNode stop];
                                // Does not work !!! // [engine detachNode:  playerNode];
                                playerNode = nil;
                         }
                        [engine stop];
                        engine = nil;
                    
                        if (converter != nil)
                        {
                            converter = nil; // ARC will dealloc the converter (I hope ;-) )
                        }
                }
       }

        -(bool) play
        {
                [playerNode play];
                return true;

        }
       -(bool)  resume
       {
		if (mStartPauseTime >= 0)
			mPauseTime += CACurrentMediaTime() - mStartPauseTime;
		mStartPauseTime = -1;

		[playerNode play];
                return true;
       }

       -(bool)  pause
       {
		mStartPauseTime = CACurrentMediaTime();
		[playerNode pause];
                return true;
       }


       -(bool)  seek: (double) pos
       {
                return false;
       }

       -(int)  getStatus
       {
                if (engine == nil)
                        return PLAYER_IS_STOPPED;
                if (mStartPauseTime > 0)
                        return PLAYER_IS_PAUSED;
                if ( [playerNode isPlaying])
                        return PLAYER_IS_PLAYING;
                return PLAYER_IS_PLAYING; // ??? Not sure !!!
       }

        - (NSData*) convertPCMInt16ToFloat32: (NSData*) int16Data
        {
            // Get the number of samples in the int16Data buffer
            NSInteger sampleCount = int16Data.length / sizeof(int16_t);
            
            // Allocate a buffer for float32 data
            float* float32Buffer = (float*)malloc(sampleCount * sizeof(float));
            
            // Cast the input NSData to int16_t* for processing
            const int16_t* int16Buffer = (const int16_t*)[int16Data bytes];
            
            // Normalize and convert each int16 sample to float32
            for (NSInteger i = 0; i < sampleCount; i++) {
                float32Buffer[i] = int16Buffer[i] / 32768.0f; // Normalize from [-32768, 32767] to [-1.0, 1.0]
            }
            
            // Create NSData from the float32 buffer
            NSData* float32Data = [NSData dataWithBytes: float32Buffer length: sampleCount * sizeof(float)];
            
            // Free the allocated memory
            free(float32Buffer);
            
            return float32Data;
        }

#define NB_BUFFERS 4
- (int) feed: (NSData*)data
{
    if (ready < NB_BUFFERS)
    {
        int ln = (int)[data length];  // Length in bytes
        int frameLn = ln / 2;  // Since each int16_t is 2 bytes, divide by 2
        int frameLength = frameLn;  // For float32 output, 1 frame = 1 float

        // Create input format for Int16 data
        inputFormat = [[AVAudioFormat alloc] initWithCommonFormat: AVAudioPCMFormatInt16
                                                       sampleRate: (double)m_sampleRate
                                                         channels: m_numChannels
                                                      interleaved: YES];

        // Create a buffer for the incoming Int16 data
        AVAudioPCMBuffer* thePCMInputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat: inputFormat frameCapacity: frameLn];
        memcpy((unsigned char*)(thePCMInputBuffer.int16ChannelData[0]), [data bytes], ln);
        thePCMInputBuffer.frameLength = frameLn;

        // Conversion from int16 to float32
        AVAudioPCMBuffer* thePCMOutputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat: outputFormat frameCapacity: frameLn];
        thePCMOutputBuffer.frameLength = frameLn;

        // Conversion loop: converting each int16 to float32
        int16_t* inputPtr = thePCMInputBuffer.int16ChannelData[0];
        float* outputPtr = thePCMOutputBuffer.floatChannelData[0];

        for (int i = 0; i < frameLn; i++) {
            // Convert int16 to float32
            outputPtr[i] = (float)inputPtr[i] / 32767.0f;
        }

        static bool hasData = true;
        hasData = true;

        AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer*(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus* outStatus)
        {
            *outStatus = hasData ? AVAudioConverterInputStatus_HaveData : AVAudioConverterInputStatus_NoDataNow;
            hasData = false;
            return thePCMInputBuffer;
        };

        // Ensure converter is properly initialized
        if (converter == nil)
        {
            converter = [[AVAudioConverter alloc] initFromFormat: inputFormat toFormat: outputFormat];
        }

        NSError* error;
        [converter convertToBuffer: thePCMOutputBuffer error: &error withInputFromBlock: inputBlock];

        if (true) // You can replace 'true' with actual condition if needed
        {
            ++ready;
            [playerNode scheduleBuffer: thePCMOutputBuffer completionHandler:
            ^(void)
            {
                dispatch_async(dispatch_get_main_queue(),
                ^{
                    --ready;
                    assert(ready < NB_BUFFERS);
                    if (self->waitingBlock != nil)
                    {
                        NSData* blk = self->waitingBlock;
                        self->waitingBlock = nil;
                        int ln = (int)[blk length];
                        int l = [self feed: blk]; // Recursion here
                        assert(l == ln);
                        [self->flutterSoundPlayer needSomeFood: ln];
                    }
                });
            }];
            return ln;
        }
    }
    else
    {
        assert(ready == NB_BUFFERS);
        assert(waitingBlock == nil);
        waitingBlock = data;
        return 0;
    }
}


-(bool)  setVolume: (double) volume fadeDuration: (NSTimeInterval)fadeDuration// TODO
{
        return true; // TODO
}

- (bool) setSpeed: (double) speed
{
        return true; // TODO
}


@end

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------


@implementation AudioEngineFromMic
{
        FlautoPlayer* flutterSoundPlayer; // Owner
        AVAudioEngine* engine;
        AVAudioPlayerNode* playerNode;
        AVAudioFormat* playerFormat;
        AVAudioFormat* outputFormat;
        AVAudioOutputNode* outputNode;
        CFTimeInterval mStartPauseTime ; // The time when playback was paused
	CFTimeInterval systemTime ; //The time when  StartPlayer() ;
        double mPauseTime ; // The number of seconds during the total Pause mode
        NSData* waitingBlock;
        long m_sampleRate ;
        int  m_numChannels;
}

       - (AudioEngineFromMic*)init: (FlautoPlayer*)owner
       {
                flutterSoundPlayer = owner;
                waitingBlock = nil;
                engine = [[AVAudioEngine alloc] init];
                
                AVAudioInputNode* inputNode = [engine inputNode];
                outputNode = [engine outputNode];
                outputFormat = [outputNode inputFormatForBus: 0];
                
                [engine connect: inputNode to: outputNode format: outputFormat];
                return [super init];
       }
       

       -(void) startPlayerFromBuffer: (NSData*) dataBuffer
       {
       }
        static int ready2 = 0;

       -(long)  getDuration
       {
		return [self getPosition]; // It would be better if we add what is in the input buffers and not still played
       }

       -(long)  getPosition
       {
		double time ;
		if (mStartPauseTime >= 0) // In pause mode
			time =   mStartPauseTime - systemTime - mPauseTime ;
		else
			time = CACurrentMediaTime() - systemTime - mPauseTime;
		return (long)(time * 1000);
       }

       -(void)  startPlayerFromURL: (NSURL*) url codec: (t_CODEC)codec channels: (int)numChannels sampleRate: (long)sampleRate
       {
                assert(url == nil || url ==  (id)[NSNull null]);

                m_sampleRate = sampleRate;
                m_numChannels= numChannels;

                mPauseTime = 0.0; // Total number of seconds in pause mode
		mStartPauseTime = -1; // Not in paused mode
		systemTime = CACurrentMediaTime(); // The time when started
                ready2 = 0;
       }


       -(void)  stop
       {

                if (engine != nil)
                {
                         [engine stop];
                        engine = nil;
                }
       }

        -(bool) play
        {
                bool b = [engine startAndReturnError: nil];
                if (!b)
                {
                        [flutterSoundPlayer logDebug: @"Cannot start the audio engine"];
                }
                return b;
        }

       -(bool)  resume
       {
                return false;
       }

       -(bool)  pause
       {
                return false;
       }


       -(bool)  seek: (double) pos
       {
                return false;
       }

       -(int)  getStatus
       {
                if (engine == nil)
                        return PLAYER_IS_STOPPED;
                return PLAYER_IS_PLAYING; // ??? Not sure !!!
       }


        -(bool)  setVolume: (double) volume fadeDuration: (NSTimeInterval) fadeDuration // TODO
        {
                return true; // TODO
        }

        -(bool)  setSpeed: (double) speed // TODO
        {
                return true; // TODO
        }

      - (int) feed: (NSData*)data
       {
        return 0;
       }


//-------------------------------------------------------------------------------------------------------------------------------------------



@end
