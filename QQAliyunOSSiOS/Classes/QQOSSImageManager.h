//
//  QQOSSImageManager.h
//  Pods
//
//  Created by 魏国强 on 2018/10/12.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjc.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    QQOSSImageCompressFormatJPG,
    QQOSSImageCompressFormatPNG,
} QQOSSImageCompressFormat;
@interface ALiOSSBucket : NSObject
@property(nonatomic,copy)NSString            *bucketName;
@property(nonatomic,copy)NSString            *endpoint;
@property(nonatomic,copy)NSString            *path;
@property(nonatomic,copy)NSString            *imageURL;
@property(nonatomic,copy)NSString            *imageName;
@property(nonatomic,copy)NSString            *host;
@property(nonatomic,strong)NSArray            *imageNameArray;
@property(nonatomic,strong)NSArray            *imageURLArray;
@end

@interface QQOSSResult <__covariant ObjectType> : NSObject
@property(nonatomic,copy)NSString            *StatusMsg;
@property(nonatomic,assign)NSInteger            StatusCode;
@property(nonatomic,strong)ObjectType            Body;
@property(nonatomic,strong)NSError            *error;
@end
@interface QQOSSImageManager : NSObject
@property(nonatomic,assign)QQOSSImageCompressFormat            format;///图片压缩类型 <默认 QQOSSImageCompressFormatJPG
@property(nonatomic,assign)CGFloat            maxSize; ///<图片宽高最大值 默认  720
+ (void)registerServerAddress:(NSString*)serverAddress;  ///<获取token的接口地址
+ (void)enableLog;
+ (instancetype)sharedManager;
-(NSString*)randomImageName;

/**
 上传单张图片
 
 @param image 图片对象
 @param bucketName 实例名称  后台传的
 @param endpoint 节点   后台传的
 @param path 图片存放位置   后台传的
 @return 信号
 */
- (RACSignal<QQOSSResult<ALiOSSBucket*>*>*)putImage:(UIImage *)image bucketName:(NSString*)bucketName endpoint:(NSString*)endpoint path:(NSString*)path;

/**
 多图上传模式1   用rac做异步
 
 @param imageArray 图片数组
 @param bucketName 实例名称  后台传的
 @param endpoint 节点   后台传的
 @param path 图片存放位置   后台传的
 @return 信号
 */
- (RACSignal<QQOSSResult<NSArray< ALiOSSBucket*> *> *> *)putImageArray:(NSArray <UIImage*>  *)imageArray bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path:(NSString *)path;
/**
 多图上传模式1   用ossTask做异步
 
 @param imageArray 图片数组
 @param bucketName 实例名称  后台传的
 @param endpoint 节点   后台传的
 @param path 图片存放位置   后台传的
 @return 信号
 */
- (RACSignal<QQOSSResult<ALiOSSBucket *> *> *)putImageArray:(NSArray <UIImage*>  *)imageArray bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path1:(NSString *)path;



@end

NS_ASSUME_NONNULL_END
