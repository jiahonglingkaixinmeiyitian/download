//
//  ViewController.m
//  download
//
//  Created by heartjhl on 2018/12/19.
//  Copyright © 2018年 heartjhl. All rights reserved.
//

#import "ViewController.h"

#import "FileDownLoadNetwork.h"
#import "QDNetServerDownLoadTool.h"
#import "FileDownloadNetWorkNative.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,FileDownLoadDelegate>
{
    NSString  *downLoadUrl;
    NSURL *fileUrl;
    NSURLSessionDownloadTask *task;
    BOOL downLoadIng;
}
@property (weak, nonatomic) IBOutlet UILabel *label3;
@property (weak, nonatomic) IBOutlet UIButton *textBtn;
@property (weak, nonatomic) IBOutlet UIProgressView *progress;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (nonatomic,strong) dispatch_semaphore_t semaphore;

/**  */
@property (nonatomic,strong) NSURLSessionDownloadTask *task;
/**  */
@property (nonatomic,assign) BOOL jhl;
/**  */
@property (nonatomic,strong) NSMutableArray *muArray;

@end

@implementation ViewController
- (IBAction)addUrlBtn:(id)sender {
    NSLog(@"添加成功");
//    [self test1:0];
    [self jia];
}
#pragma mark 模拟并发下载
-(void)test2:(UITableViewCell *)cell{
    /**
     1.开辟子线程
     2.在子线程中限制并行数
     */
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        [[FileDownLoadNetwork shareManagerDownLoad] downloadFileWithFileUrl:self.muArray[0] progress:^(CGFloat progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
//              NSLog(@"✈️✈️✈️✈️✈️✈️任务");
                cell.textLabel.text = [NSString stringWithFormat:@"%f",progress];
            });
        } success:^(NSURL *fileUrlPath, NSURLResponse *response) {
            NSLog(@"下载成功的文档路径是 %@, ",fileUrlPath);
            dispatch_semaphore_signal(self.semaphore);
            
        } failure:^(NSError *error, NSInteger statusCode) {
            NSLog(@"下载失败%@",error);
            dispatch_semaphore_signal(self.semaphore);
        }];
    });

}
-(void)test1:(int)a{
    
//    for (int i=0; i<2; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
            
            [[FileDownLoadNetwork shareManagerDownLoad] downloadFileWithFileUrl:self.muArray[0] progress:^(CGFloat progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
//                    NSLog(@"✈️✈️✈️✈️✈️✈️任务");
                    if (a==0) {
                        
                        self.label.text = [NSString stringWithFormat:@"%f",progress];
                    }else if(a==1){
                        self.progress.progress = progress;
                    }else{
                        self.label3.text = [NSString stringWithFormat:@"%f",progress];
                    }
                });
            } success:^(NSURL *fileUrlPath, NSURLResponse *response) {
                NSLog(@"下载成功的文档路径是 %@, ",fileUrlPath);
                dispatch_semaphore_signal(self.semaphore);
                
            } failure:^(NSError *error, NSInteger statusCode) {
                NSLog(@"下载失败%@",error);
                dispatch_semaphore_signal(self.semaphore);
            }];
        });
//    }
}

- (IBAction)btn:(id)sender {
//    [self test1:1];
//    [self downData];
    [self downFile];
}

//-(void)downData:(NSString *)url
-(void)downData
{
    
    NSURLSessionDownloadTask *task = [[FileDownLoadNetwork shareManagerDownLoad] downloadFileWithFileUrl:self.muArray[1] progress:^(CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
                self.progress.progress = progress;
        });
    } success:^(NSURL *fileUrlPath, NSURLResponse *response) {
        NSLog(@"下载的文档路径是 %@, ",fileUrlPath);
        
    } failure:^(NSError *error, NSInteger statusCode) {
        NSLog(@"下载失败%@",error);
    }];
    self.task = task;
    
    NSLog(@"🕘🕘🕘🕘🕘🕘：%@",task);
    NSLog(@"哈哈哈：%lu",(unsigned long)task.taskIdentifier);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"断点续传通知"
                                                    message:[NSString stringWithFormat:@"%lu",(unsigned long)self.task.taskIdentifier]
                                                   delegate:nil
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
//    [alert show];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
//    [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
//        NSLog(@"8**** 取消了 ****");
//    }];
//    [self jia];
//    [self test1:3];
//    [[FileDownLoadNetwork shareManagerDownLoad] cancelDownloadTaskWithUrl:self.muArray[0]];
    [[FileDownloadNetWorkNative shareManagerDownLoad] cancelDownload];
    
}
-(void)jia{
    
    [[FileDownLoadNetwork shareManagerDownLoad] downloadFileWithFileUrl:self.muArray[0] progress:^(CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
           
                self.label3.text = [NSString stringWithFormat:@"%f",progress];
        });
    } success:^(NSURL *fileUrlPath, NSURLResponse *response) {
        NSLog(@"下载成功的文档路径是 %@, ",fileUrlPath);
        
    } failure:^(NSError *error, NSInteger statusCode) {
        NSLog(@"下载失败%@",error);
    }];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSArray *arr = @[@"https://pic.ibaotu.com/00/48/71/79a888piCk9g.mp4",@"https://www.apple.com/105/media/cn/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7/films/feature/iphone-x-feature-cn-20170912_1280x720h.mp4",@"https://pic.ibaotu.com/00/48/71/79a888piCk9g.mp4"];
    self.muArray = [NSMutableArray arrayWithArray:arr];
    _jhl = YES;
    [FileDownLoadNetwork shareManagerDownLoad];//提前初始化目的：走通知方法downloadData:进而存储系统帮忙存储的resumeData，以便在下载时能够实现断点续传
    self.semaphore = dispatch_semaphore_create(2);
    [FileDownloadNetWorkNative shareManagerDownLoad];

//    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
//    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"jhl"];
//    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
//    tableView.dataSource = self;
//    tableView.delegate = self;
//    tableView.backgroundColor=[UIColor redColor];
//    [self.view addSubview:tableView];
    
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"jhl" forIndexPath:indexPath];
    cell.textLabel.text = @"贾红领";
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.textLabel.text = @"等待下载";
    [self test2:cell];
    
    NSLog(@"点击了%ld",(long)indexPath.row);
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}


-(void)downFile{
    FileDownloadNetWorkNative *download = [FileDownloadNetWorkNative shareManagerDownLoad];
    download.myDeleate = self;
    [download downFile:self.muArray[0]];
}

//进度返回   每一个数据包回来调用一次
- (void)backDownprogress:(float)progress tag:(NSInteger)tag{
    
    self.progress.progress = progress;
    self.label.text = [NSString stringWithFormat:@"%0.1f%@",progress*100,@"%"];
}

//下载成功
- (void)downSucceed:(NSURL*)url tag:(NSInteger)tag{
    NSLog(@"下载成功,准备播放");
    self.progress.progress = 1;
    self.label.text = @"100.0%";
    [self paly: url];
//    self.fileDownloadNetwork = nil;
}

//下载失败
- (void)downError:(NSError*)error tag:(NSInteger)tag{
    
//    self.fileDownloadNetwork = nil;
    self.progress.progress = 0;
    self.label.text = @"0.0%";
    NSLog(@"下载失败,请再次下载 :%@",error);
}



//传入本地url 进行视频播放
-(void)paly:(NSURL*)playUrl{
    
    //系统的视频播放器
    AVPlayerViewController *controller = [[AVPlayerViewController alloc]init];
    //播放器的播放类
    AVPlayer * player = [[AVPlayer alloc]initWithURL:playUrl];
    controller.player = player;
    //自动开始播放
    [controller.player play];
    //推出视屏播放器
    [self  presentViewController:controller animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
