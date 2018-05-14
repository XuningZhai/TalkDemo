//
//  DisplayView.h
//  FocusVision
//
//  Created by aipu on 18/3/31.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACSendDelegate <NSObject>
- (void)sendData:(NSMutableData *)data;
@end

@interface AACEncoder : NSObject
@property (nonatomic,strong) id<AACSendDelegate>delegate;
-(void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
