//
//  DisplayView.h
//  FocusVision
//
//  Created by aipu on 18/3/31.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger,CapturePreset) {
    CapturePreset640x480,
    CapturePresetiFrame960x540,
    CapturePreset1280x720,
};

@protocol PCMCaptureDelegate <NSObject>
- (void)audioWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@interface PCMCapture : NSObject
@property(nonatomic,strong)id<PCMCaptureDelegate>delegate;
@property(nonatomic,strong)AVCaptureSession *session;//管理对象

- (instancetype)initCaptureWithPreset:(CapturePreset)preset;
- (void)start;
- (void)stop;

@end
