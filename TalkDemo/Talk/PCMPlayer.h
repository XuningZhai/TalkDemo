//
//  AudioQueuePlay.h
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/25.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface PCMPlayer : NSObject

// 播放
- (void)playWithData:(NSData *)data;

@end
