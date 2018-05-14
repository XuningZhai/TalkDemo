//
//  DecoderAAC.m
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/17.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "AACDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "libavcodec/avcodec.h"
#import "libswscale/swscale.h"
#include <libavformat/avformat.h>
#include "libswresample/swresample.h"

@interface AACDecoder ()
@property (assign, nonatomic) AVFrame *aacFrame;
@property (assign, nonatomic) AVCodec *aacCodec;
@property (assign, nonatomic) AVCodecContext *aacCodecCtx;
@property (assign, nonatomic) AVPacket aacPacket;
@end

@implementation AACDecoder

- (BOOL)initAACDecoderWithSampleRate:(int)sampleRate channel:(int)channel bit:(int)bit {
    av_register_all();
    avformat_network_init();
    self.aacCodec = avcodec_find_decoder(AV_CODEC_ID_AAC);
    av_init_packet(&_aacPacket);
    if (self.aacCodec != nil) {
        self.aacCodecCtx = avcodec_alloc_context3(self.aacCodec);
        // 初始化codecCtx
        self.aacCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
        self.aacCodecCtx->sample_rate = sampleRate;
        self.aacCodecCtx->channels = channel;
        self.aacCodecCtx->bit_rate = bit;
        self.aacCodecCtx->channel_layout = AV_CH_LAYOUT_STEREO;
        // 打开codec
        if (avcodec_open2(self.aacCodecCtx, self.aacCodec, NULL) >= 0) {
            self.aacFrame = av_frame_alloc();
        }
    }
    return (BOOL)self.aacFrame;
}

- (void)AACDecoderWithMediaData:(NSData *)mediaData sampleRate:(int)sampleRate completion:(void (^)(uint8_t *, size_t))completion {
    _aacPacket.data = (uint8_t *)mediaData.bytes;
    _aacPacket.size = (int)mediaData.length;
    if (!self.aacCodecCtx) {
        return;
    }
    if (&_aacPacket) {
        avcodec_send_packet(self.aacCodecCtx, &_aacPacket);
        int result = avcodec_receive_frame(self.aacCodecCtx, self.aacFrame);
        /*int gotframe = 0;
        int result = avcodec_decode_audio4(self.aacCodecCtx,
                                           self.aacFrame,
                                           &gotframe,
                                           &_aacPacket);*/
        if (result == 0) {
            struct SwrContext *au_convert_ctx = swr_alloc();
            au_convert_ctx = swr_alloc_set_opts(au_convert_ctx,
                                                AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, sampleRate,
                                                self.aacCodecCtx->channel_layout, self.aacCodecCtx->sample_fmt, self.aacCodecCtx->sample_rate,
                                                0, NULL);
            swr_init(au_convert_ctx);
            int out_linesize;
            int out_buffer_size = av_samples_get_buffer_size(&out_linesize, self.aacCodecCtx->channels,self.aacCodecCtx->frame_size,self.aacCodecCtx->sample_fmt, 1);
            uint8_t *out_buffer = (uint8_t *)av_malloc(out_buffer_size);
            // 解码
            swr_convert(au_convert_ctx, &out_buffer, out_linesize, (const uint8_t **)self.aacFrame->data , self.aacFrame->nb_samples);
            swr_free(&au_convert_ctx);
            au_convert_ctx = NULL;
            if (completion) {
                completion(out_buffer, out_linesize);
            }
            av_free(out_buffer);
        }
    }
}

- (void)releaseAACDecoder {
    if(self.aacCodecCtx) {
        avcodec_close(self.aacCodecCtx);
        avcodec_free_context(&_aacCodecCtx);
        self.aacCodecCtx = NULL;
    }
    if(self.aacFrame) {
        av_frame_free(&_aacFrame);
        self.aacFrame = NULL;
    }
}



@end




