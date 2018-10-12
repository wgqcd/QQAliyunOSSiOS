//
//  QQOSSImageManager.m
//  Pods
//
//  Created by 魏国强 on 2018/10/12.
//


#define GET_TOKEN_URL  @"http://192.168.1.172:7080"
#define DEFAULT_ENDPOINT @"https://oss-cn-beijing.aliyuncs.com"

#import "QQOSSImageManager.h"
#import <AliyunOSSiOS/AliyunOSSiOS.h>
#import <ReactiveObjC/ReactiveObjc.h>
#import <YYModel/YYModel.h>
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
    NSString *filePath = self.path;
    if ([filePath hasPrefix:@"/"]) {
        filePath = [filePath substringFromIndex:1];
    }
    if (filePath && ![filePath hasSuffix:@"/"]) {
        filePath = [filePath stringByAppendingString:@"/"];
    }
    if (!filePath || ![[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] ) {
        filePath = @"";
    }
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
@end
@implementation QQOSSImageManager

+ (instancetype)sharedManager{
    static QQOSSImageManager *_sharedmanager;
    if (!_sharedmanager) {
        _sharedmanager  = [[QQOSSImageManager alloc]init];
    }
    return _sharedmanager ;
}
- (RACSignal<QQOSSResult< ALiOSSBucket *> *> *)putImageArray:(NSArray <UIImage*> *)imageArray bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path1:(NSString *)path{
    RACSignal *signal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {

        NSString *filePath = path;
        if ([filePath hasPrefix:@"/"]) {
            filePath = [filePath substringFromIndex:1];
        }
        if (filePath && ![filePath hasSuffix:@"/"]) {
            filePath = [filePath stringByAppendingString:@"/"];
        }
        if (!filePath || ![[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] ) {
            filePath = @"";
        }
        NSMutableArray *taskArray = [NSMutableArray arrayWithCapacity:imageArray.count];
        NSMutableArray *requestArray = [NSMutableArray arrayWithCapacity:imageArray.count];
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
        OSSTask *allTask ;
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
- (RACSignal<QQOSSResult<ALiOSSBucket *> *> *)putImage:(UIImage *)image bucketName:(NSString *)bucketName endpoint:(NSString *)endpoint path:(NSString *)path{
    if (!self.ossClient) {
        return [RACSignal  createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
            QQOSSResult *result = [[QQOSSResult alloc]init];
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
    RACSignal *signal = [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        NSString *imageName = [self randomImageName];
        OSSPutObjectRequest *request = [self requestImage:image bucketName:bucketName endpoint:endpoint path:path imageName:imageName];
        OSSTask *task = [self.ossClient putObject:request];
        [task   continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
            QQOSSResult *result = [[QQOSSResult alloc]init];
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
        return [RACDisposable disposableWithBlock:^{
            [request cancel];
            [task description];
        }];
    }];
    return signal;
}

- (OSSPutObjectRequest*)requestImage:(UIImage *)image bucketName:(NSString*)bucketName endpoint:(NSString*)endpoint path:(NSString*)path imageName:(NSString*)imageName{
    NSData *data = UIImagePNGRepresentation([self thumbnailForImage:[self fixOrientation:image]  maxPixelSize:1280]) ;
    if (endpoint) {
        self.ossClient.endpoint = endpoint;
    }
    NSString *filePath = path;
    if ([filePath hasPrefix:@"/"]) {
        filePath = [filePath substringFromIndex:1];
    }
    if (filePath && ![filePath hasSuffix:@"/"]) {
        filePath = [filePath stringByAppendingString:@"/"];
    }
    if (!filePath || ![[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""] ) {
        filePath = @"";
    }
    NSAssert(bucketName, @"bucket不能为空");
    OSSPutObjectRequest  *_putRequest;
    _putRequest = [OSSPutObjectRequest new];
    _putRequest.bucketName = bucketName;
    _putRequest.objectKey = [NSString stringWithFormat:@"%@%@",path,imageName];
    _putRequest.uploadingData = data;
    _putRequest.isAuthenticationRequired = YES;
    return _putRequest  ;
}
- (OSSClient *)ossClient{
    NSDate *date = [self.dateFormatter dateFromString:self.token.Expiration];
    date = [NSDate dateWithTimeInterval:60*60*8 sinceDate:date];
    if (_ossClient == nil || self.token == nil || self.token.Expiration == nil || [date compare:[NSDate date]] ==  NSOrderedAscending) {
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
    
    NSString *time = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString *name = [NSString stringWithFormat:@"%@-%u.png",time,arc4random()%10000];
    NSLog(@"随机名：%@",name);
    return name;
}
- (NSDateFormatter *)dateFormatter  {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc]init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
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
@end
