//
//  DisplayView.h
//  FocusVision
//
//  Created by aipu on 18/3/31.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "AACEncoder.h"

typedef struct {
    //pcm数据指针
    void *source;
    //pcm数据的长度
    UInt32 sourceSize;
    //声道数
    UInt32 channelCount;
    AudioStreamPacketDescription *packetDescription;
}FillComplexInputParm;

typedef struct {
    AudioConverterRef converter;
    int samplerate;
    int channles;
}ConverterContext;

//AudioConverter的提供数据的回调函数
OSStatus audioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,UInt32 *ioNumberDataPacket,AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription,void *inUserData) {
    //ioData用来接收需要转换的pcm数据給converter进行编码
    FillComplexInputParm *param = (FillComplexInputParm *)inUserData;
    if (param->sourceSize <= 0) {
        *ioNumberDataPacket = 0;
        return -1;
    }
    ioData->mBuffers[0].mData = param->source;
    ioData->mBuffers[0].mDataByteSize = param->sourceSize;
    ioData->mBuffers[0].mNumberChannels = param->channelCount;
    *ioNumberDataPacket = 1;
    param->sourceSize = 0;
    return noErr;
}

@interface AACEncoder () {
    ConverterContext *convertContext;
    dispatch_queue_t encodeQueue;
}

@end
@implementation AACEncoder

- (instancetype)init {
    if ( self = [super init]) {
        encodeQueue = dispatch_queue_create("aipu", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)setUpConverter:(CMSampleBufferRef)sampleBuffer {
    //获取audioformat的描述信息
    CMAudioFormatDescriptionRef audioFormatDes =  (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer);
    //获取输入的asbd的信息
    AudioStreamBasicDescription inAudioStreamBasicDescription = *(CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDes));
    //开始构造输出的asbd
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    //对于压缩格式必须设置为0
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    //设定声道数为1
    outAudioStreamBasicDescription.mChannelsPerFrame = 1;
    //设定采样率为16000
    outAudioStreamBasicDescription.mSampleRate = 16000;
    //设定输出音频的格式
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    //填充输出的音频格式
    UInt32 size = sizeof(outAudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outAudioStreamBasicDescription);
    //选择aac的编码器（用来描述一个已经安装的编解码器）
    AudioClassDescription audioClassDes;
    //初始化为0
    memset(&audioClassDes, 0, sizeof(audioClassDes));
    //获取满足要求的aac编码器的总大小
    UInt32 countSize = 0;
    AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(outAudioStreamBasicDescription.mFormatID), &outAudioStreamBasicDescription.mFormatID, &countSize);
    //用来计算aac的编解码器的个数
    int cout = countSize/sizeof(audioClassDes);
    //创建一个包含有cout个数的编码器数组
    AudioClassDescription descriptions[cout];
    //将编码器数组信息写入到descriptions中
    AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(outAudioStreamBasicDescription.mFormatID), &outAudioStreamBasicDescription.mFormatID, &countSize, descriptions);
    for (int i = 0; i < cout; cout++) {
        AudioClassDescription temp = descriptions[i];
        if (temp.mManufacturer==kAppleSoftwareAudioCodecManufacturer
            &&temp.mSubType==outAudioStreamBasicDescription.mFormatID) {
            audioClassDes = temp;
            break;
        }
    }
    //创建convertcontext用来保存converter的信息
    ConverterContext *context = malloc(sizeof(ConverterContext));
    self->convertContext = context;
    OSStatus result = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, &audioClassDes, &(context->converter));
    if (result == noErr) {
        //创建编解码器成功
        AudioConverterRef converter = context->converter;
        //设置编码器属性
        UInt32 temp = kAudioConverterQuality_High;
        AudioConverterSetProperty(converter, kAudioConverterCodecQuality, sizeof(temp), &temp);
        //设置比特率
        UInt32 bitRate = 32000;
        result = AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate);
        if (result != noErr) {
            NSLog(@"设置比特率失败");
        }
    }else{
        //创建编解码器失败
        free(context);
        context = NULL;
        NSLog(@"创建编解码器失败");
    }
}

//编码samplebuffer数据
- (void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self->convertContext) {
        [self setUpConverter:sampleBuffer];
    }
    ConverterContext *cxt = self->convertContext;
    if (cxt && cxt->converter) {
        //从samplebuffer中提取数据
        CFRetain(sampleBuffer);
        dispatch_async(encodeQueue, ^{
            //从samplebuffer中获取blockbuffer
            CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            size_t pcmLength = 0;
            char *pcmData = NULL;
            //获取blockbuffer中的pcm数据的指针和长度
            OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &pcmLength, &pcmData);
            if (status != noErr) {
                NSLog(@"从block中获取pcm数据失败");
                CFRelease(sampleBuffer);
                return;
            } else {
                //在堆区分配内存用来保存编码后的aac数据
                char *outputBuffer = malloc(pcmLength);
                memset(outputBuffer, 0, pcmLength);
                UInt32 packetSize = 1;
                AudioStreamPacketDescription *outputPacketDes = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) *packetSize);
                //使用fillcomplexinputparm来保存pcm数据
                FillComplexInputParm userParam;
                userParam.source = pcmData;
                userParam.sourceSize = (UInt32)pcmLength;
                userParam.channelCount = 1;
                userParam.packetDescription = NULL;
                //在堆区创建audiobufferlist
                AudioBufferList outputBufferList;
                outputBufferList.mNumberBuffers = 1;
                outputBufferList.mBuffers[0].mData = outputBuffer;
                outputBufferList.mBuffers[0].mDataByteSize = (unsigned int)pcmLength;
                outputBufferList.mBuffers[0].mNumberChannels = 1;
                //编码
                status = AudioConverterFillComplexBuffer(self->convertContext->converter, audioConverterComplexInputDataProc, &userParam, &packetSize, &outputBufferList, outputPacketDes);
                free(outputPacketDes);
                outputPacketDes = NULL;
                if (status == noErr) {
//                    NSLog(@"编码成功");
                    //获取原始的aac数据
                    NSData *rawAAC = [NSData dataWithBytes:outputBufferList.mBuffers[0].mData length:outputBufferList.mBuffers[0].mDataByteSize];
                    free(outputBuffer);
                    outputBuffer = NULL;
                    //设置adts头
                    int headerLength = 0;
                    char *packetHeader = newAdtsDataForPacketLength((int)rawAAC.length, &headerLength);
                    NSData *adtsHeader = [NSData dataWithBytes:packetHeader length:headerLength];
                    free(packetHeader);
                    packetHeader = NULL;
                    NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                    [fullData appendData:rawAAC];
                    //设置私有头
                    char *privateHeader = newPrivate((int)fullData.length);
                    NSData *privateHeaderData = [NSData dataWithBytes:privateHeader length:24];
                    free(privateHeader);
                    privateHeader = NULL;
                    NSMutableData *pFullData = [NSMutableData dataWithData:privateHeaderData];
                    [pFullData appendData:fullData];
                    //设置rtp头
                    char *rtpHeader = newRTPForAAC();
                    NSData *rtpHeaderData = [NSData dataWithBytes:rtpHeader length:12];
                    free(rtpHeader);
                    rtpHeader = NULL;
                    NSMutableData *fullData1 = [NSMutableData dataWithData:rtpHeaderData];
                    [fullData1 appendData:pFullData];
                    //设置rtsp interleaved frame头
                    char *rtspFrameHeader = newRTSPInterleavedFrame((int)fullData1.length);
                    NSData *rtspFrameHeaderData = [NSData dataWithBytes:rtspFrameHeader length:4];
                    free(rtspFrameHeader);
                    rtspFrameHeader = NULL;
                    NSMutableData *fullData2 = [NSMutableData dataWithData:rtspFrameHeaderData];
                    [fullData2 appendData:fullData1];
                    //发送数据
                    [self.delegate sendData:fullData2];
                    fullData2 = nil;
                    fullData1 = nil;
                    fullData = nil;
                    rawAAC = nil;
                }
                free(outputBuffer);
                CFRelease(sampleBuffer);
            }
        });
    }
}



#pragma mark - HEADER
//给aac加上adts头, packetLength 为rawaac的长度
char *newAdtsDataForPacketLength(int packetLength, int *ioHeaderLen) {
    //adts头的长度为固定的7个字节
    int adtsLen = 7;
    //在堆区分配7个字节的内存
    char *packet = malloc(sizeof(char)*adtsLen);
    //选择AAC LC
    int profile = 2;
    //选择采样率对应的下标
    int freqIdx = 8;
    //选择声道数所对应的下标
    int chanCfg = 1;
    //获取adts头和raw aac的总长度
    NSUInteger fullLength = adtsLen+packetLength;
    //设置syncword
    packet[0] = 0xFF;
    packet[1] = 0xF1;
    packet[2] = (char)(((profile-1)<<6)+(freqIdx<<2)+(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6)+(fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF)>>3);
    packet[5] = (char)(((fullLength&7)<<5)+0x1F);
    packet[6] = (char)0xFC;
    *ioHeaderLen = adtsLen;
    return packet;
}

//添加私有头
char *newPrivate(int packetLength) {
    //私有头的长度为固定的24个字节
    int adtsLen = 24;
    //在堆区分配24个字节的内存
    char *packet = malloc(sizeof(char)*adtsLen);
    //帧标识
    packet[0] = 0x00;
    packet[1] = 0x00;
    packet[2] = 0x01;
    packet[3] = 0xEA;
    //编码格式
    packet[4] = 0x00;
    //通道
    packet[5] = 0x00;
    //帧率
    packet[6] = 0x00;
    //帧序号
    packet[7] = 0x00;
    //宽度
    packet[8] = 0x11;//音频属性
    packet[9] = 0x01;//声道数
    //高度
    packet[10] = 0x04;//采样率
    packet[11] = 0x10;//采样位深
    //时间
    packet[12] = 0x00;
    packet[13] = 0x00;
    packet[14] = 0x00;
    packet[15] = 0x00;
    //时间毫秒
    packet[16] = 0x00;
    packet[17] = 0x00;
    //扩展头长度
    packet[18] = 0x00;
    packet[19] = 0x00;
    //数据长度
    NSString *lengthStr = [NSString stringWithFormat:@"%d",packetLength];
    long long lengthL = [lengthStr longLongValue];
    NSString *length16 = [NSString stringWithFormat:@"%08llx",lengthL];
    NSRange r1 = {2,2};
    NSRange r2 = {4,2};
    NSString *s16_1 = [length16 substringToIndex:2];
    NSString *s16_2 = [length16 substringWithRange:r1];
    NSString *s16_3 = [length16 substringWithRange:r2];
    NSString *s16_4 = [length16 substringFromIndex:6];
    unsigned long res1 = strtoul([s16_1 UTF8String],0,16);
    unsigned long res2 = strtoul([s16_2 UTF8String],0,16);
    unsigned long res3 = strtoul([s16_3 UTF8String],0,16);
    unsigned long res4 = strtoul([s16_4 UTF8String],0,16);
    packet[20] = res4;
    packet[21] = res3;
    packet[22] = res2;
    packet[23] = res1;
    return packet;
}

//添加RTP头
char *newRTPForAAC() {
    //RTP头长度为固定的12个字节
    int rtpLen = 12;
    //在堆区分配12个字节的内存
    char *packet = malloc(sizeof(char)*rtpLen);
    //设置syncword
    packet[0] = 0x80;//V_P_X_CC
    packet[1] = 0x88;//M_PT
    //Sequence
    packet[2] = 0x00;
    packet[3] = 0xDA;
    //timestamp
    packet[4] = 0x00;
    packet[5] = 0x01;
    packet[6] = 0x98;
    packet[7] = 0xC0;
    //SSRC
    packet[8] = 0x00;
    packet[9] = 0x00;
    packet[10] = 0x00;
    packet[11] = 0x00;
    return packet;
}

unsigned long arc16() {
    int arc = arc4random()%255;
    NSString *str = [NSString stringWithFormat:@"%d",arc];
    long long l = [str longLongValue];
    NSString *s16_arc = [NSString stringWithFormat:@"%02llx",l];
    unsigned long data_arc = strtoul([s16_arc UTF8String],0,16);
    return data_arc;
}

char *newRTSPInterleavedFrame(int packetLength) {
    //RTP头长度为固定的4个字节
    int rtpLen = 4;
    //在堆区分配4个字节的内存
    char *packet = malloc(sizeof(char)*rtpLen);
    //设置syncword
    packet[0] = 0x24;
    packet[1] = 0x00;
    NSString *str = [NSString stringWithFormat:@"%d",packetLength];
    long long l = [str longLongValue];
    NSString *s16 = [NSString stringWithFormat:@"%04llx",l];
    NSString *s16_1 = [s16 substringToIndex:2];
    NSString *s16_2 = [s16 substringFromIndex:2];
    unsigned long res1 = strtoul([s16_1 UTF8String],0,16);
    unsigned long res2 = strtoul([s16_2 UTF8String],0,16);
    packet[2] = res1;
    packet[3] = res2;
    return packet;
}




@end
