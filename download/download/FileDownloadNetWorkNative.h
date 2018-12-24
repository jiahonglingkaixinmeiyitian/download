//
//  FileDownloadNetWorkNative.h
//  download
//
//  Created by heartjhl on 2018/12/23.
//  Copyright © 2018年 heartjhl. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FileDownLoadDelegate <NSObject>
@optional
- (void)backDownprogress:(float)progress tag:(NSInteger)tag;
- (void)downSucceed:(NSURL*)url tag:(NSInteger)tag;
- (void)downError:(NSError*)error tag:(NSInteger)tag;
@end

@interface FileDownloadNetWorkNative : NSObject

@property (nonatomic, strong) NSURLSession* session;
@property (nonatomic, strong) NSURLSessionDownloadTask* downloadTask;
@property (nonatomic, strong) NSData* resumeData;
@property (nonatomic, weak) id<FileDownLoadDelegate> myDeleate;
@property (nonatomic, assign) NSInteger tag;//某个文件下载的的标记
///单例
+(instancetype)shareManagerDownLoad;
///fileUrl:下载地址
-(void)downFile:(NSString*)fileUrl;
///暂停或者继续下载
-(void)suspendDownload;
///取消下载
-(void)cancelDownload;

@end
