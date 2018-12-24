//
//  FileDownLoadNetwork.h
//  download
//
//  Created by heartjhl on 2018/12/19.
//  Copyright © 2018年 heartjhl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking.h>

typedef void (^FileDownLoadSuccessBlock)(NSURL *fileUrlPath ,NSURLResponse *  response );
typedef void (^FileDownLoadFailBlock)(NSError*  error ,NSInteger statusCode);
typedef void (^FileDownLoadProgress)(CGFloat  progress);

@interface FileDownLoadNetwork : NSObject
///单例
+(instancetype)shareManagerDownLoad;
//下载文件
-(NSURLSessionDownloadTask *)downloadFileWithFileUrl:(NSString *)requestUrl progress:(FileDownLoadProgress)progressBlock success:(FileDownLoadSuccessBlock)successBlock failure:(FileDownLoadFailBlock)failBlock;
///根据url取消下载
-(void)cancelDownloadTaskWithUrl:(NSString *)url;
///根据task取消下载
-(void)cancelDownloadTask:(NSURLSessionDownloadTask *)task;
///取消所有的下载任务
- (void)cancelAllCurrentDownLoadTasks;

@end












