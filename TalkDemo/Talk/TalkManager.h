//
//  TalkManager.h
//  GCDAsyncSocketDemo
//
//  Created by aipu on 2018/4/16.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TalkManager : NSObject

@property (nonatomic,copy)NSString *ip;
@property (nonatomic,assign)int port;
@property (nonatomic,copy)NSString *url;

+ (instancetype)manager;
- (void)startTalk;
- (void)stopTalk;

@end
