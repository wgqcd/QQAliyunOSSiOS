//
//  QQOSSImageManager.m
//  Pods
//
//  Created by 魏国强 on 2018/10/12.
//


//#define GET_TOKEN_URL  @"http://192.168.1.172:7080"
#define DEFAULT_ENDPOINT @"https://oss-cn-beijing.aliyuncs.com"

#import "QQOSSImageManager.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>

#import <YYModel/YYModel.h>

static NSString *GET_TOKEN_URL;
@implementation ALiOSSBucket
- (NSString *)host{
    NSString *endpoint = self.endpoint;
    if ([endpoint hasPrefix:@"https://"]) {
        endpoint = [endpoint substringFromIndex:8];
    }
    return [NSString stringWithFormat:@"https://%@.%@",self.bucketName,endpoint];
}
- (NSString *)imageURL{
    NSString *endpoint = self.endpoint;
    if ([endpoint hasPrefix:@"https://"]) {
        endpoint = [endpoint substringFromIndex:8];
    }
    NSString *filePath = [QQOSSImageManager pathWithString:self.path];
    return [NSString stringWithFormat:@"https://%@.%@/%@%@",self.bucketName,endpoint,filePath,self.imageName];
}
- (NSString *)description{
    
    if (self.imageName) {
        return [NSString stringWithFormat:@"imageURL:%@",self.imageURL];
    }else if (self.imageURLArray){
        return [NSString stringWithFormat:@"%@",self.imageURLArray];
    }else{
        return @"无任何数据";
    }
    
}
@end
@interface ALOSSToken : NSObject
@property(nonatomic,copy)NSString            *StatusCode;
@property(nonatomic,copy)NSString            *AccessKeyId;
@property(nonatomic,copy)NSString            *AccessKeySecret;
@property(nonatomic,copy)NSString            *SecurityToken;
@property(nonatomic,copy)NSString            *Expiration;
@end
@implementation ALOSSToken



@end
@implementation QQOSSResult
@end;
@interface QQOSSImageManager ()
@property(nonatomic,strong)NSDateFormatter            *dateFormatter;
@property(nonatomic,strong)OSSClient            *ossClient;
@property(nonatomic,strong)ALOSSToken            *token;
@property(nonatomic,assign)BOOL            enableLog;

@end
@implementation QQOSSImageManager
+ (void)enableLog{
    [OSSLog enableLog];
    [QQOSSImageManager sharedManager].enableLog = YES;
}

+ (instancetype)sharedManager{
    static QQOSSImageManager *_sharedmanager;
    if (!_sharedmanager) {
        _sharedmanager  = [[QQOSSImageManager alloc]init];
        _sharedmanager.format = QQOSSImageCompressFormatJPG;
        _sharedmanager.maxSize = 720;
    }
    return _sharedmanager ;
}
- (RACSignal<QQOSSResult< ALiOSSBucket *> *> *)putImageArray:(NSArray <UIImage*> *)imageArray bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path1:(NSString *)path{
    if ([self validationImageArray:imageArray] == NO) {
        return [self noImageErrorSignal];
    }
    RACSignal *signal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        NSMutableArray *requestArray = [NSMutableArray arrayWithCapacity:imageArray.count];
        __block OSSTask *allTask ;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSString *filePath = [QQOSSImageManager pathWithString:path];
            NSMutableArray *taskArray = [NSMutableArray arrayWithCapacity:imageArray.count];
            
            NSMutableArray *imageNameArray = [NSMutableArray arrayWithCapacity:imageArray.count];
            NSMutableArray *imageURLArray = [NSMutableArray arrayWithCapacity:imageArray.count];
            OSSPutObjectRequest *request;
            OSSTask *task;
            
            for (UIImage *image in imageArray) {
                @autoreleasepool {
                    NSString *imageName = [self randomImageName];
                    request = [self requestImage:image bucketName:bucketName endpoint:endpoint path:filePath imageName:imageName];
                    [requestArray addObject:request];
                    task = [self.ossClient putObject:request];
                    [taskArray addObject:task];
                    [imageNameArray addObject: imageName];
                    NSString *aEndpoint = endpoint;
                    if ([aEndpoint hasPrefix:@"https://"]) {
                        aEndpoint = [aEndpoint substringFromIndex:8];
                    }
                    NSString *imageURL = [NSString stringWithFormat:@"https://%@.%@/%@%@", bucketName,aEndpoint,filePath,imageName];
                    [imageURLArray addObject:imageURL];
                }
                
            }
            ALiOSSBucket *bucket = [[ALiOSSBucket alloc]init];
            bucket.bucketName = bucketName;
            bucket.endpoint = endpoint;
            bucket.path = path;
            bucket.imageURLArray = imageURLArray;
            bucket.imageNameArray = imageNameArray;
            
            allTask =   [OSSTask taskForCompletionOfAllTasks:taskArray];
            [allTask continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
                QQOSSResult *result = [[QQOSSResult alloc]init];
                if (task.error) {
                    result.error = task.error;
                    result.StatusCode = -1;
                    result.StatusMsg = task.error.domain;
                }else{
                    result.StatusMsg = @"上传成功";
                    result.Body =  bucket;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [subscriber sendNext:result];
                    [subscriber sendCompleted];
                });
                return task;
            }];
        });
        return [RACDisposable disposableWithBlock:^{
            for (OSSRequest *req in requestArray) {
                if (!req.isCancelled) {
                    [req cancel];
                }
            }
            [allTask description];
        }];
    }];
    return signal;
}
- (RACSignal<QQOSSResult<NSArray< ALiOSSBucket*> *> *> *)putImageArray:(NSArray <UIImage*> *)imageArray bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path:(NSString *)path{
    if ([self validationImageArray:imageArray] == NO) {
        return [self noImageErrorSignal];
    }
    NSMutableArray *signalArray = [NSMutableArray arrayWithCapacity:imageArray.count];
    for (UIImage *image in imageArray) {
        RACSignal *signal = [self putImage:image  bucketName:bucketName endpoint:endpoint path:path];
        [signalArray addObject:signal];
    }
    RACSignal *signal = [[RACSignal combineLatest:signalArray] map:^id _Nullable(RACTuple * _Nullable value) {
        NSArray *array = [[value rac_sequence] array];
        for (QQOSSResult *result  in array) {
            if (result.error) {
                return result;
            }
        }
        QQOSSResult *result = [[QQOSSResult alloc]init];
        result.Body = [[[array rac_sequence] map:^id _Nullable(QQOSSResult  *value) {
            return value.Body;
        }] array];
        return result;
    }];
    
    return signal;
}
- (BOOL)validationImage:(UIImage*)image{
    return image && [image isKindOfClass:[UIImage class]];
}
- (BOOL)validationImageArray:(NSArray< UIImage*>*)imageArray{
    if (imageArray == nil || imageArray.count == 0) {
        return NO;
    }
    for (UIImage *image in imageArray) {
        if (![image isKindOfClass:[UIImage class]]) {
            return NO;
        }
    }
    return YES;
}
- (RACSignal<QQOSSResult*>*)noImageErrorSignal{
    return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        QQOSSResult *result = [[QQOSSResult alloc]init];
        result.error = [NSError errorWithDomain:@"未添加图片" code:-1 userInfo:nil];
        result.StatusMsg = @"未添加图片";
        result.StatusCode = -1;
        [subscriber sendNext:result];
        [subscriber sendCompleted];
        return nil;
    }];
}
- (RACSignal<QQOSSResult<ALiOSSBucket *> *> *)putImage:(UIImage *)image bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path:(NSString *)path{
    if ([self validationImage:image] == NO) {
        return [self noImageErrorSignal];
    }
     QQOSSResult *result = [[QQOSSResult alloc]init];
    if (!self.ossClient) {
        return [RACSignal  createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
           
            result.StatusCode = -1;
            result.StatusMsg = @"阿里云token认证失败";
            result.error = [NSError errorWithDomain:result.StatusMsg code:-1 userInfo:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [subscriber sendNext:result];
                [subscriber sendCompleted];
            });
            return nil;
        }];
    }
     if (self.enableLog) {
        NSLog(@"加载client%f",[[NSDate date] timeIntervalSince1970]);
     }
    RACSignal *signal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
       __block OSSTask *task;
        __block OSSPutObjectRequest *request;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (self.enableLog) {
                NSLog(@"开始创建任务%f",[[NSDate date] timeIntervalSince1970]);
            }
            NSString *imageName = [self randomImageName];
            request = [self requestImage:image bucketName:bucketName endpoint:endpoint path:path imageName:imageName];
             task = [self.ossClient putObject:request];
            if (self.enableLog) {
                NSLog(@"执行任务%f",[[NSDate date] timeIntervalSince1970]);
            }
            [task   continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
                if (self.enableLog) {
                    NSLog(@"结果%f",[[NSDate date] timeIntervalSince1970]);
                }
                if (task.error) {
                    result.error = task.error;
                    result.StatusCode = -1;
                    result.StatusMsg = task.error.domain;
                }else{
                    ALiOSSBucket *bucket = [[ALiOSSBucket alloc]init];
                    bucket.bucketName = bucketName;
                    bucket.endpoint = endpoint;
                    bucket.path = path;
                    bucket.imageName = imageName;
                    result.StatusMsg = @"上传成功";
                    result.Body =  bucket;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [subscriber sendNext:result];
                    [subscriber sendCompleted];
                });
                return task;
            }];
        });
    
        return [RACDisposable disposableWithBlock:^{
            [request cancel];
            [task description];
        }];
    }];
     if (self.enableLog) {
        NSLog(@"返回%f",[[NSDate date] timeIntervalSince1970]);
     }
    return signal;
}

- (OSSPutObjectRequest*)requestImage:(UIImage *)image bucketName:(NSString*)bucketName endpoint:(NSString*)endpoint path:(NSString*)path imageName:(NSString*)imageName{
    UIImage *thumbnailImage = [self thumbnailForImage:[self fixOrientation:image]  maxPixelSize:self.maxSize];
    NSData *data;
    if (self.format == QQOSSImageCompressFormatJPG) {
        data = UIImageJPEGRepresentation(thumbnailImage, .51);
    }else{
        data = UIImagePNGRepresentation(thumbnailImage) ;
    }

    if (endpoint) {
        self.ossClient.endpoint = endpoint;
    }
    NSString *filePath = [QQOSSImageManager pathWithString:path];
    NSAssert(bucketName, @"bucket不能为空");
    OSSPutObjectRequest  *_putRequest;
    _putRequest = [OSSPutObjectRequest new];
    _putRequest.bucketName = bucketName;
    _putRequest.objectKey = [NSString stringWithFormat:@"%@%@",filePath,imageName];
    _putRequest.uploadingData = data;
    _putRequest.isAuthenticationRequired = YES;
    
    return _putRequest  ;
}
+ (NSString *)pathWithString:(NSString*)path{
    NSString *filePath = path;
    if ([filePath hasPrefix:@"/"]) {
        filePath = [filePath substringFromIndex:1];
    }
    if (filePath && ![[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]  && ![filePath hasSuffix:@"/"]) {
        filePath = [filePath stringByAppendingString:@"/"];
    }
    if (!filePath || [[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] ) {
        filePath = @"";
    }
    return filePath;
}
- (OSSClient *)ossClient{
    NSAssert(GET_TOKEN_URL, @"请注册获取token的服务器地址");
    self.dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSDate *date = [self.dateFormatter dateFromString:self.token.Expiration];
    NSTimeInterval interval = [date timeIntervalSinceNow] + 60*60*8;
    if (_ossClient == nil || self.token == nil || self.token.Expiration == nil || interval < 0) {
        NSString *url = GET_TOKEN_URL;
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url] options:NSDataReadingMappedAlways error:&error];
        ALOSSToken *token = [ALOSSToken yy_modelWithJSON:data];
        self.token = token;
        if (![token.StatusCode isEqualToString: @"200"]) {
            NSLog(@"token获取失败");
            return nil;
        }
        id <OSSCredentialProvider> provider = [[OSSStsTokenCredentialProvider alloc]initWithAccessKeyId:token.AccessKeyId secretKeyId:token.AccessKeySecret securityToken:token.SecurityToken];
        _ossClient = [[OSSClient alloc]initWithEndpoint:DEFAULT_ENDPOINT credentialProvider:provider];
        
    }
    return _ossClient;
}
-(NSString*)randomImageName{
    self.dateFormatter.dateFormat = @"yyyyMMddHHmmssSSS";
    NSString *time = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString *name = [NSString stringWithFormat:@"%@%u.%@",time,arc4random(),self.format == QQOSSImageCompressFormatJPG ? @"jpg":@"png"];
    NSLog(@"随机名：%@",name);
    return name;
}

- (NSDateFormatter *)dateFormatter  {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc]init];
    }
    return _dateFormatter;
}
- (UIImage *)thumbnailForImage:(UIImage*)image maxPixelSize:(NSUInteger)size {
    UIImage *fixImage = [self fixOrientation:image];
    NSData *data = UIImagePNGRepresentation(fixImage);
    CFDataRef ref = (__bridge CFDataRef)data;
    CGImageSourceRef source = CGImageSourceCreateWithData(ref, nil);
    CFMutableDictionaryRef options = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(options, kCGImageSourceCreateThumbnailFromImageAlways, kCFBooleanTrue);
    CFDictionaryAddValue(options, kCGImageSourceThumbnailMaxPixelSize, CFNumberCreate(CFAllocatorGetDefault(), kCFNumberNSIntegerType, &size));
    CFDictionaryAddValue(options, kCGImageSourceCreateThumbnailWithTransform, kCFBooleanTrue);
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0,options);
    CFRelease(source);
    if (!imageRef) {
        return nil;
    }
    UIImage *toReturn = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    return toReturn;
}
- (UIImage *)fixOrientation:(UIImage *)aImage {
    if (aImage.imageOrientation ==UIImageOrientationUp)
        return aImage;
    CGAffineTransform transform =CGAffineTransformIdentity;
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width,0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage), CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
        default:
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}
+ (void)registerServerAddress:(NSString *)serverAddress{
    GET_TOKEN_URL = serverAddress;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [[QQOSSImageManager sharedManager] ossClient];
    });
}
@end
