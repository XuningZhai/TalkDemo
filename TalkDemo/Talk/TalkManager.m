//
//  TalkManager.m
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/16.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "TalkManager.h"
#import "GCDAsyncSocket.h"
#import "AACEncoder.h"
#import "PCMCapture.h"
#import "AACDecoder.h"
#import "PCMPlayer.h"

#define SAMPLE_RATE 16000
#define BIT_RATE SAMPLE_RATE*16

@interface TalkManager ()<GCDAsyncSocketDelegate,PCMCaptureDelegate,AACSendDelegate>
@property (nonatomic,retain) GCDAsyncSocket *socket;
@property (nonatomic, strong) AACEncoder *aac;
@property (nonatomic, strong) PCMCapture *captureSession;
@property (nonatomic, strong) AACDecoder *decoder;
@property (nonatomic, strong) PCMPlayer *aqplayer;
@end

@implementation TalkManager

+ (instancetype)manager {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    if ( self = [super init]) {
        [self initEncoder];
        _decoder = [[AACDecoder alloc] init];
    }
    return self;
}

- (void)initEncoder {
    _aac = [[AACEncoder alloc] init];
    _captureSession = [[PCMCapture alloc] initCaptureWithPreset:CapturePreset640x480];
    _captureSession.delegate = self;
    _aac.delegate = self;
}

- (void)startTalk {
    [_decoder initAACDecoderWithSampleRate:SAMPLE_RATE channel:1 bit:BIT_RATE];
    [self connectServer:self.ip port:self.port];
    _aqplayer = [[PCMPlayer alloc] init];
}

- (void)stopTalk {
    [_captureSession stop];
    [self doTeardown:self.url];
    self.socket = nil;
    [_decoder releaseAACDecoder];
    _aqplayer = nil;
}

- (int)connectServer:(NSString *)hostIP port:(int)hostPort {
    if (_socket == nil) {
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        NSError *err = nil;
        int t = [_socket connectToHost:hostIP onPort:hostPort error:&err];
        if (!t) {
            return 0;
        }else{
            return 1;
        }
    }else {
        [_socket readDataWithTimeout:-1 tag:0];
        return 1;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    BOOL state = [self.socket isConnected];
    if (state) {
        [self sendCmd];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    BOOL state = [_socket isConnected];
    NSLog(@"disconnect,state=%d",state);
    self.socket = nil;
}

- (void)sendCmd
{
    [self doSetup:self.url];
}

- (void)doSetup:(NSString *)url {
    NSMutableString *dataString = [NSMutableString string];
    [dataString appendString:[NSString stringWithFormat:@"SETUP %@ RTSP/1.0\r\n", url]];
    [dataString appendString:@"Content-Length: 0\r\n"];
    [dataString appendFormat:@"CSeq: 0\r\n"];
    [dataString appendString:@"Transport: RTP/AVP/DHTP;unicast\r\n"];
    [dataString appendString:@"\r\n"];
    NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:-1 tag:0];
    [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)doPlay:(NSString *)url {
    NSMutableString *dataString = [NSMutableString string];
    [dataString appendString:[NSString stringWithFormat:@"PLAY %@ RTSP/1.0\r\n", url]];
    [dataString appendString:@"Content-Length: 0\r\n"];
    [dataString appendFormat:@"CSeq: 1\r\n"];
    [dataString appendString:@"\r\n"];
    NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:-1 tag:1];
    [self.socket readDataWithTimeout:-1 tag:1];
}

- (void)doTeardown:(NSString *)url {
    NSMutableString *dataString = [NSMutableString string];
    [dataString appendString:[NSString stringWithFormat:@"TEARDOWN %@ RTSP/1.0\r\n", url]];
    [dataString appendString:@"Content-Length: 0\r\n"];
    [dataString appendString:@"CSeq: 2\r\n"];
    [dataString appendString:@"\r\n"];
    NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:-1 tag:2];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    switch (tag) {
        case 0:
            [self doPlay:self.url];
            break;
        case 1:
            [self startCapture];
            break;
        case 200:
            if (!dataString) {
                [self getPayload:data];
            }
            break;
        default:
            break;
    }
    [sock readDataWithTimeout:-1 tag:200];
}

- (void)getPayload:(NSData *)data {
    NSMutableData *payload = [NSMutableData dataWithData:data];
    [payload replaceBytesInRange:NSMakeRange(0, 40) withBytes:NULL length:0];//4+12+24
    [self decoderAAC:payload];
}

- (void)decoderAAC:(NSMutableData *)data {
    [_decoder AACDecoderWithMediaData:data sampleRate:SAMPLE_RATE completion:^(uint8_t *out_buffer, size_t out_buffer_size) {
        NSData *pcm = [NSData dataWithBytes:out_buffer length:out_buffer_size];
        [self->_aqplayer playWithData:pcm];
    }];
}

- (void)startCapture {
    [_captureSession start];
}

- (void)audioWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [_aac encodeSmapleBuffer:sampleBuffer];
}

- (void)sendData:(NSMutableData *)data {
    [self.socket writeData:data withTimeout:-1 tag:100];
}




@end
