//
//  DecoderAAC.h
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/17.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AACDecoder : NSObject

/* 初始化AAC解码器 */
- (BOOL)initAACDecoderWithSampleRate:(int)sampleRate channel:(int)channel bit:(int)bit ;

/* 解码AAC音频 */
- (void)AACDecoderWithMediaData:(NSData *)mediaData sampleRate:(int)sampleRate completion:(void(^)(uint8_t *out_buffer, size_t out_buffer_size))completion;

/* 释放AAC解码器 */
- (void)releaseAACDecoder;

@end
