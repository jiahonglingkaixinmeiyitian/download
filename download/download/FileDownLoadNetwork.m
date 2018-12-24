//
//  FileDownLoadNetwork.m
//  download
//
//  Created by heartjhl on 2018/12/19.
//  Copyright © 2018年 heartjhl. All rights reserved.
//

#import "FileDownLoadNetwork.h"
#import <CommonCrypto/CommonDigest.h>

@interface FileDownLoadNetwork()
/**  */
@property (nonatomic,strong) AFURLSessionManager *manager;
/** 为了解决后台情况下下载完成后，进度条不能及时更新的问题 ，如果AF的版本是3.0.0-3.1.0则不用使用该字典，这些版本在后台下载完成后，progress的block能够回调，3.2.0以上的版本在后台下载完成后，progress的block不回调，不能及时更新进度条，所以要使用该字典解决*/
@property (nonatomic,strong) NSMutableDictionary *blockDic;
/**  */
//@property (nonatomic,assign) BOOL progressBlockTag;


@end

@implementation FileDownLoadNetwork
- (NSMutableDictionary *)blockDic{
    if (!_blockDic) {
        _blockDic = [[NSMutableDictionary alloc]init];
    }
    return _blockDic;
}
+(instancetype)shareManagerDownLoad{
    
    static FileDownLoadNetwork *shareManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[self alloc] init];
    });
    return shareManager;
}
/**
 后台下载
 下载完成之后杀死app，再创建任务时taskIdentifier为1
 未下载完成就杀死app，再创建任务时taskIdentifier在上个taskIdentifier的基础上增加，比如杀死前taskIdentifier的最大值为3，那么创建时taskIdentifier为4
 默认下载
 只要杀死app，再创建任务时taskIdentifier为1
 */
- (instancetype)init{
    self = [super init];
    if (self) {
//        配置（可以后台下载）
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.lingxin.app"];
        configuration.timeoutIntervalForRequest = 30;
//        是否允许蜂窝网络
        configuration.allowsCellularAccess = YES;
        self.manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
        NSLog(@"👩‍🍳👩‍🍳👩‍🍳👩‍🍳👩‍🍳👩‍🍳初始化单例");
        NSURLSessionDownloadTask *task;
//        下载完成，取消，下载失败的通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadData:)
                                                     name:AFNetworkingTaskDidCompleteNotification
                                                   object:task];
    }
    return  self;
}

- (NSURLSessionDownloadTask *)downloadFileWithFileUrl:(NSString *)requestUrl progress:(FileDownLoadProgress)progressBlock success:(FileDownLoadSuccessBlock)successBlock failure:(FileDownLoadFailBlock)failBlock{
    
    [self.blockDic setObject:progressBlock forKey:requestUrl];
    NSURLSessionDownloadTask   *downloadTask = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    NSData *resumeData = [self getResumeData:requestUrl];
    NSLog(@"本地存储的需要续传的数据长度为： %ld",resumeData.length);
    if (resumeData.length>0) {//断点续传
        NSLog(@"断点续传下载");
        downloadTask = [self.manager downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) {
                progressBlock(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
                NSLog(@"jhl断点续传任务进度：%F",(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount));
            }
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
//        targetPath:缓存路径，在沙盒里的library/cache中，下载成功后targetPath下的缓存数据会被删除，下载的文件进入到了返回的存储路径下
            return [NSURL fileURLWithPath:[self downLoadSuccessDataDiskTmpPath:requestUrl]];//返回文件存储路径
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
//            filePath：文件存储路径
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if ([httpResponse statusCode] == 404) {
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            if (error) {////取消也会报错 statusCode为206 error的code为-999
                if (failBlock) {
                    failBlock(error,[httpResponse statusCode]);
                }
            }else{
                if (successBlock) {
                    successBlock(filePath,response);
                }
            }
        }];
        
    }else{//从头开始下载
        NSLog(@"重新开始下载");
        downloadTask = [self.manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) {
                progressBlock(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            }
            NSLog(@"jhl新任务进度：%F",(1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount));
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:[self downLoadSuccessDataDiskTmpPath:requestUrl]];

        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if ([httpResponse statusCode] == 404) {
                [[NSFileManager defaultManager] removeItemAtURL:filePath error:nil];
            }
            if (error) {
                if (failBlock) {//取消也会报错 statusCode为206 error的code为-999
                    failBlock(error,[httpResponse statusCode]);
                }
            }else{
                if (successBlock) {
                    successBlock(filePath,response);
                }
            }
        }];
    }
    [downloadTask resume];
    return downloadTask;
}
/**
 什么时候收到通知
 1.下载成功时，此时error为nil
 2.下载失败时，如果是取消了，错误code为-999，如果是网络原因，错误code为-1001
 3.任务还未下载完成，app强制退出或者闪退后，再次进入app初始化season时，此时收到通知，保存app强制退出或者闪退时系统帮忙存储的resumedata，以便断点续传时使用。
 app杀死后系统帮忙存储resumeData条件：
 配置必须使用backgroundSessionConfigurationWithIdentifier:方法
 */
-(void)downloadData:(NSNotification *)notify{
    if ([notify.object isKindOfClass:[ NSURLSessionDownloadTask class]]) {
        NSURLSessionDownloadTask *task = notify.object;
        NSString *url = [task.currentRequest.URL absoluteString];
        NSError *error  = [notify.userInfo objectForKey:AFNetworkingTaskDidCompleteErrorKey] ;
        NSString *resumeDataPath = [self resumeDataDiskTmpPath:url];
        NSLog(@"通知里的🍎🍎🍎：%@",error);
        
        if (error) {
//        code为-1是The request timed out
            if (error.code == -1001) {//网络原因
                
            }else if (error.code == -999){//取消时的错误
                
                NSData *resumeData = [error.userInfo objectForKey:@"NSURLSessionDownloadTaskResumeData"];
                //            存储强制退出或者闪退后系统帮忙存储的resumedata数据
                [resumeData writeToFile:resumeDataPath atomically:NO];
            }

        }else{//下载成功
            FileDownLoadProgress progressBlock = [self.blockDic objectForKey:url];
            if (progressBlock) {
                NSLog(@"🍊🍊🍊🍊🍊：%@",[self.blockDic allValues]);
                progressBlock(1.0);//更新进度
                [self.blockDic removeObjectForKey:url];
            }
            NSFileManager *manager = [NSFileManager defaultManager];
            if ([manager fileExistsAtPath:resumeDataPath]) {
//                移除缓存文件，只有app取消，闪退，强制退出时resumeDataPath路径下的文件才会存在
                [manager removeItemAtPath:resumeDataPath error:nil];
                NSLog(@"缓冲的resumeData文件已经被移除");
            }
        }
    }
}
//获取resumedata数据
-(NSData *)getResumeData:(NSString *)url{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSData *datas     = [fm contentsAtPath:[self resumeDataDiskTmpPath:url]];
    return datas;
}
//resumeData数据临时路径，在library中
-(NSString *)resumeDataDiskTmpPath:(NSString *)url{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *tmpPath = [NSString stringWithFormat:@"%@/resumeDataTmpFile",libraryPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDir = NO;
//    判断storePath路径下文件是否存在，以及storePath路径是否是存在的目录
    BOOL exist = [manager fileExistsAtPath:tmpPath isDirectory:&isDir];
    if (!(isDir == YES && exist == YES)) {
        [manager createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *filePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp",[self md5:url]]];//resumeDataTmpFile/
    return filePath;
}
//下载成功的数据存储路径，在document中
-(NSString *)downLoadSuccessDataDiskTmpPath:(NSString *)url{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) firstObject];
    NSString *storePath = [NSString stringWithFormat:@"%@/downLoadSuccessFile",documentPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDir = NO;
//    判断storePath路径下文件是否存在，以及storePath路径是否是存在的目录
   BOOL exist = [manager fileExistsAtPath:storePath isDirectory:&isDir];
    if (!(isDir == YES && exist == YES)) {
        [manager createDirectoryAtPath:storePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *filePath = [storePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",[self md5:url]]];//downLoadSuccessFile/
    return filePath;
}

//用url获取文件名称 (MD5加密)
- (NSString *)md5:(NSString *)string{
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}
//根据url取消下载
-(void)cancelDownloadTaskWithUrl:(NSString *)url{
    for (NSURLSessionDownloadTask *task in self.manager.downloadTasks) {
        if ([task.currentRequest.URL.absoluteString isEqualToString:url]) {
            if (task.state == NSURLSessionTaskStateRunning) {
                
                [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    
                }];
            }
        }
    }
}
//根据task取消下载
-(void)cancelDownloadTask:(NSURLSessionDownloadTask *)task{
    if (task.state == NSURLSessionTaskStateRunning) {
        [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            //       这里也可以存储resumeData，通知方法downloadData：中也可以存储
        }];
    }
}
//停止当前所有的下载任务
- (void)cancelAllCurrentDownLoadTasks{
    if ([[self.manager downloadTasks] count]  == 0) {
        return;
    }
    for (NSURLSessionDownloadTask *task in  [self.manager downloadTasks]) {
        if (task.state == NSURLSessionTaskStateRunning) {
            [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                
            }];
        }
    }
}
- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}
//获取当前时间 下载id标识用
- (NSString *)currentDateStr{
    NSDate *currentDate = [NSDate date];//获取当前时间，日期
    NSTimeInterval timeInterval = [currentDate timeIntervalSince1970];
    return [NSString stringWithFormat:@"%.f",timeInterval];
}
/**
 AppDelegate 中要实现- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler//在应用处于后台，且后台下载的所有任务完成后才会调用
 app才能在后台情况下，执行通知和block代码块，不实现的话，当app进入前台时才能执行通知和block代码块
 */

@end












