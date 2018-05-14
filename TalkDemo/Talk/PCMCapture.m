//
//  DisplayView.h
//  FocusVision
//
//  Created by aipu on 18/3/31.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "PCMCapture.h"

@interface PCMCapture()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic ,strong) AVCaptureDevice *audioDevice;//设备
@property (nonatomic ,strong) AVCaptureDeviceInput *audioInput;//输入对象
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;//输出对象
@property (nonatomic, assign) CapturePreset definePreset;
@end
@implementation PCMCapture

- (instancetype)initCaptureWithPreset:(CapturePreset)preset {
    if ([super init]) {
        [self initAVcaptureSession];
        _definePreset = preset;
    }
    return self;
}

- (void)initAVcaptureSession {
    //初始化AVCaptureSession
    _session = [[AVCaptureSession alloc] init];
    //开始配置
    [_session beginConfiguration];
    NSError *error;
    //获取音频设备对象
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //初始化捕获输入对象
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&error];
    if (error) {
        NSLog(@"录音设备出错");
    }
    //添加音频输入对象到session
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    //初始化输出捕获对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    //添加音频输出对象到session
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    //创建设置音频输出代理所需要的线程队列
    dispatch_queue_t audioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    [self.audioOutput setSampleBufferDelegate:self queue:audioQueue];
    //提交配置
    [self.session commitConfiguration];
}

- (void)start {
    [self.session startRunning];
}

- (void)stop {
    [self.session stopRunning];
}

//AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == self.audioOutput) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(audioWithSampleBuffer:)]) {
            [self.delegate audioWithSampleBuffer:sampleBuffer];
        }
    }
}

@end
