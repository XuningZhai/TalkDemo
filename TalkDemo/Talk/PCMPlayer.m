//
//  AudioQueuePlay.m
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/25.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "PCMPlayer.h"

#define MIN_SIZE_PER_FRAME 2000
#define QUEUE_BUFFER_SIZE 3      //队列缓冲个数

@interface PCMPlayer() {
    AudioQueueRef audioQueue;                                 //音频播放队列
    AudioStreamBasicDescription _audioDescription;
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    BOOL audioQueueBufferUsed[QUEUE_BUFFER_SIZE];             //判断音频缓存是否在使用
    NSLock *sysnLock;
    NSMutableData *tempData;
    OSStatus osState;
    NSMutableString *str;//用于reset
}

@end

@implementation PCMPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        str = [NSMutableString string];
        sysnLock = [[NSLock alloc] init];
        // 播放PCM使用
        if (_audioDescription.mSampleRate <= 0) {
            //设置音频参数
            _audioDescription.mSampleRate = 32000.0;//采样率
            _audioDescription.mFormatID = kAudioFormatLinearPCM;
            // 下面这个是保存音频数据的方式的说明，如可以根据大端字节序或小端字节序，浮点数或整数以及不同体位去保存数据
            _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            //1单声道 2双声道
            _audioDescription.mChannelsPerFrame = 1;
            //每一个packet一帧数据,每个数据包下的帧数，即每个数据包里面有多少帧
            _audioDescription.mFramesPerPacket = 1;
            //每个采样点16bit量化 语音每采样点占用位数
            _audioDescription.mBitsPerChannel = 16;
            _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
            //每个数据包的bytes总数，每帧的bytes数*每个数据包的帧数
            _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;
        }
        // 使用player的内部线程播放 新建输出
        AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, 0, 0, &audioQueue);
        // 设置音量
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
        // 初始化需要的缓冲区
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            audioQueueBufferUsed[i] = false;
            osState = AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
            NSLog(@"AudioQueueAllocateBuffer, osState=%d", osState);
        }
        osState = AudioQueueStart(audioQueue, NULL);
        if (osState != noErr) {
            NSLog(@"AudioQueueStart Error");
        }
    }
    return self;
}

- (void)resetPlay {
    if (audioQueue != nil) {
        AudioQueueReset(audioQueue);
    }
}

// 填充buffer
- (void)playWithData:(NSData *)data {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self->sysnLock lock];
        self->tempData = [NSMutableData new];
        [self->tempData appendData:data];
        // 得到数据
        NSUInteger len = self->tempData.length;
        Byte *bytes = (Byte*)malloc(len);
        [self->tempData getBytes:bytes length:len];
        int i = 0;
        while (true) {
            usleep(1000);//防止cpu过高
            if (!self->audioQueueBufferUsed[i]) {
                self->audioQueueBufferUsed[i] = true;
                break;
            }else {
                i++;
                if (i >= QUEUE_BUFFER_SIZE) {
                    i = 0;
                }
            }
        }
        if (self->str.length < 3) {
            [self->str appendString:[NSString stringWithFormat:@"%d",i]];
        }
        else if (self->str.length == 3) {
            [self->str deleteCharactersInRange:NSMakeRange(0, 1)];
            [self->str appendString:[NSString stringWithFormat:@"%d",i]];
        }
        if ([self->str isEqualToString:@"000"]) {
            [self resetPlay];
        }
        self->audioQueueBuffers[i]->mAudioDataByteSize = (unsigned int)len;
        memcpy(self->audioQueueBuffers[i]->mAudioData, bytes, len);
        free(bytes);
        AudioQueueEnqueueBuffer(self->audioQueue, audioQueueBuffers[i], 0, NULL);//将buffer插入AudioQueue中
        [self->sysnLock unlock];
    });
}

// 回调
static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {
    PCMPlayer *player = (__bridge PCMPlayer*)inUserData;
    [player resetBufferState:audioQueueRef and:audioQueueBufferRef];
}

- (void)resetBufferState:(AudioQueueRef)audioQueueRef and:(AudioQueueBufferRef)audioQueueBufferRef {
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        // 将这个buffer设为未使用
        if (audioQueueBufferRef == audioQueueBuffers[i]) {
            audioQueueBufferUsed[i] = false;
        }
    }
}

- (void)dealloc {
    if (audioQueue != nil) {
        AudioQueueStop(audioQueue,true);
    }
    audioQueue = nil;
    sysnLock = nil;
}

@end
