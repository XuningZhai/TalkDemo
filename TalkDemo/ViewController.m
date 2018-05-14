//
//  ViewController.m
//  TalkDemo
//
//  Created by aipu on 2018/4/27.
//  Copyright © 2018年 XuningZhai All rights reserved.
//

#import "ViewController.h"
#import "TalkManager.h"
@interface ViewController ()
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UITextField *tf1;
@property (nonatomic, strong) UITextField *tf2;
@property (nonatomic,strong)TalkManager *manager;
@end
#define HOST_IP _tf1.text  // ip
#define HOST_PORT [_tf2.text intValue]   // port
/*定义rtsp url*/
#define RTSP_ADDRESS [NSString stringWithFormat:@"rtsp://%@:%@/hzcms_talk?token=1",_tf1.text,_tf2.text]   // rtsp url
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addBtn];
}

- (void)addBtn {
    _manager = [TalkManager manager];
    _btn = [UIButton buttonWithType:UIButtonTypeSystem];
    _btn.frame = CGRectMake(100, 100, 100, 50);
    [_btn setTitle:@"start" forState:UIControlStateNormal];
    [_btn setTitle:@"stop" forState:UIControlStateSelected];
    [_btn addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
    _tf1 = [[UITextField alloc] initWithFrame:CGRectMake(100, 200, 200, 30)];
    _tf1.borderStyle = UITextBorderStyleRoundedRect;
    _tf1.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    [self.view addSubview:_tf1];
    _tf2 = [[UITextField alloc] initWithFrame:CGRectMake(100, 250, 100, 30)];
    _tf2.borderStyle = UITextBorderStyleRoundedRect;
    _tf2.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    [self.view addSubview:_tf2];
}

- (void)start {
    _manager.ip = HOST_IP;
    _manager.port = HOST_PORT;
    _manager.url = RTSP_ADDRESS;
    _btn.selected = !_btn.selected;
    if (_btn.selected) {
        [_manager startTalk];
    }
    else {
        [_manager stopTalk];
    }
}


@end
