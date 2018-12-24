//
//  FileDownloadNetWorkNative.m
//  download
//
//  Created by heartjhl on 2018/12/23.
//  Copyright © 2018年 heartjhl. All rights reserved.
//

#import "FileDownloadNetWorkNative.h"
#import <CommonCrypto/CommonDigest.h>

@interface FileDownloadNetWorkNative ()<NSURLSessionDelegate>
@property (nonatomic) BOOL  mIsSuspend;

@end

@implementation FileDownloadNetWorkNative

//闪退或者强制退出 初始化该方法会走didCompleteWithError代理方法
+(instancetype)shareManagerDownLoad{
    static FileDownloadNetWorkNative *shareManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[self alloc] init];
    });
    return shareManager;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.lingxin.app2"];
//         允许蜂窝网络: 你可以做偏好设置
        config.allowsCellularAccess = YES;
        config.timeoutIntervalForRequest = 30;
//        创建一个下载线程
        self.session = [NSURLSession sessionWithConfiguration:config
                                                     delegate:self
                                                delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

-(void)downFile:(NSString *)fileUrl{
    if (!fileUrl || fileUrl.length == 0 || ![self checkIsUrlAtString:fileUrl]) {
        NSLog(@"fileUrl 无效");
        return ;
    }
    NSURL *url = [NSURL URLWithString:fileUrl];
    NSURLSessionDownloadTask   *downloadTask = nil;
    NSData *resumeData = [self getResumeData:fileUrl];
    if (resumeData.length>0) {//断点续传
        downloadTask = [self.session downloadTaskWithResumeData:resumeData];
    }else{//重新开始下载
        downloadTask = [self.session downloadTaskWithURL:url];
    }
    self.downloadTask = downloadTask;
    [downloadTask resume];
}

#pragma mark - NSURLSessionDelegate
/* 下载过程中调用，用于跟踪下载进度
 * bytesWritten为单次下载大小
 * totalBytesWritten为当当前一共下载大小
 * totalBytesExpectedToWrite为文件大小
 */
//每次传一个包 调用一次该函数 512M
-(void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    float dowProgeress = 1.0 * totalBytesWritten / totalBytesExpectedToWrite;
//        NSLog(@"🍎🍎🍎进度：%f",dowProgeress);
    if (self.myDeleate && [self.myDeleate respondsToSelector:@selector(backDownprogress:tag:)]) {
        [self.myDeleate backDownprogress:dowProgeress tag:self.tag];
    }
}

/*
 2.下载完成之后调用该方法
 */
-(void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location{
    NSString *url = downloadTask.currentRequest.URL.absoluteString;
//    文件储存路径
    NSString *storagePath = [self downLoadSuccessDataDiskTmpPath:url];
    //创建文件管理器
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath: storagePath]) {
        //如果文件夹下有同名文件  则将其删除
        [manager removeItemAtPath:storagePath error:nil];
    }
    NSError *saveError;
//    把缓存文件移动到指定的沙盒路径
    [manager moveItemAtURL:location toURL:[NSURL fileURLWithPath:storagePath] error:&saveError];
    
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = [[NSURL alloc]initFileURLWithPath:storagePath];
            if(self.myDeleate && [self.myDeleate respondsToSelector:@selector(downSucceed:tag:)])
                [self.myDeleate downSucceed:url tag:self.tag];
        });
    NSString *resumeDataPath = [self resumeDataDiskTmpPath:url];
    if ([manager fileExistsAtPath:resumeDataPath]) {//删除磁盘中的缓存数据
        [manager removeItemAtPath:resumeDataPath error:nil];
    }
}
/* 在任务下载完成、下载失败
 * 或者是应用被杀掉后，重新启动应用并创建相关identifier的Session时调用
 */
//下载失败和完成都会调用，cancel时错误为-999
-(void)URLSession:(nonnull NSURLSession *)session task:(nonnull NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error{
    NSString *url = task.currentRequest.URL.absoluteString;
    NSString *resumeDataPath = [self resumeDataDiskTmpPath:url];
    if (error) {
        
        if(error && self.myDeleate && [self.myDeleate respondsToSelector:@selector(downError:tag:)] && error.code != -999){//回调非取消时的错误
            [self.myDeleate downError:error tag:self.tag];
        }
        NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
        [resumeData writeToFile:resumeDataPath atomically:NO];
        
    }else{//成功时调用
        if (self.myDeleate && [self.myDeleate respondsToSelector:@selector(backDownprogress:tag:)]) {
            [self.myDeleate backDownprogress:1 tag:self.tag];//解决后台情况下下载完成后进度条没有更新的问题
        }
    }
}
/* 应用在后台，而且后台所有下载任务完成后，
 * 在所有其他NSURLSession和NSURLSessionDownloadTask委托方法执行完后回调，
 * 可以在该方法中做下载数据管理和UI刷新
 *最好将handleEventsForBackgroundURLSession中completionHandler保存，在该方法中待所有载数据管理和UI刷新做完后，再调用completionHandler()
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
// 调用在 -application:handleEventsForBackgroundURLSession: 中保存的 handler
    NSLog(@"所有后台任务已经完成: %@",session.configuration.identifier);
    
}
/* 下载恢复时调用
 * 在使用downloadTaskWithResumeData:方法获取到对应NSURLSessionDownloadTask，
 * 并该task调用resume的时候调用
 */
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    
}



#pragma mark - private
//暂停下载
-(void)suspendDownload{
    
    if (self.mIsSuspend) {
        [self.downloadTask resume];
    }else{
        [self.downloadTask suspend];
    }
    self.mIsSuspend = !self.mIsSuspend;
}

//取消下载
-(void)cancelDownload{
    
    __weak typeof(self) weakSelf = self;
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
//        weakSelf.downloadTask  = nil;
//        [resumeData writeToFile:[self resumeDataDiskTmpPath:url] atomically:NO];
    }];
    
    
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

- (BOOL)checkIsUrlAtString:(NSString *)url {
    NSString *pattern = @"http(s)?://([\\w-]+\\.)+[\\w-]+(/[\\w- ./?%&=]*)?";
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
    NSArray *regexArray = [regex matchesInString:url options:0 range:NSMakeRange(0, url.length)];
    
    if (regexArray.count > 0) {
        return YES;
    }else {
        return NO;
    }
}

- (void)dealloc
{
    [self.session invalidateAndCancel];
    self.session = nil;
    [self.downloadTask cancel];
    self.downloadTask = nil;
}

/**
 AppDelegate 中要实现- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler//在应用处于后台，且后台下载的所有任务完成后才会调用
 在后台情况下才会执行-(void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location方法，-(void)URLSession:(nonnull NSURLSession *)session task:(nonnull NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error方法，- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session方法
 */

@end



