//
//  QQViewController.m
//  QQAliyunOSSiOS
//
//  Created by 魏国强 on 10/12/2018.
//  Copyright (c) 2018 魏国强. All rights reserved.
//

#import "QQViewController.h"
#import <QQAliyunOSSiOS/QQOSSImageManager.h>
#import <ReactiveObjC/RACSignal.h>
@interface QQViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *urlLabel;
@property(nonatomic,strong)UIImagePickerController            *picker;
@property(nonatomic,strong)NSString            *imageURL;
@property(nonatomic,strong)UIImage            *image;
@end

@implementation QQViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
//    [QQOSSImageManager enableLog];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    self.image = image;
    self.imageView.image = image;
}
- (IBAction)selectImage:(UIButton *)sender {
    [self presentViewController:self.picker animated:YES completion:nil];
}
- (IBAction)jmpWeb:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.imageURL] options:@{} completionHandler:^(BOOL success) {
        
    }];
}
- (IBAction)submit:(UIButton *)sender {
    
    if (self.image == nil) {
        NSLog(@"无图片");
        return;
    }
    [[[QQOSSImageManager sharedManager] putImage:self.image bucketName:@"common-rxjy" endpoint:@"https://oss-cn-beijing.aliyuncs.com" path:@""] subscribeNext:^(QQOSSResult<ALiOSSBucket *> * _Nullable x) {
        if (x.error) {
            NSLog(@"%@",x.error);
            return ;
        }
        self.urlLabel.text = x.Body.imageURL;
        self.imageURL = x.Body.imageURL;
        NSLog(@"%@",self.imageURL);
    }];
//
//    [[[QQOSSImageManager sharedManager] putImageArray:@[self.image] bucketName:@"common-rxjy" endpoint:@"https://oss-cn-beijing.aliyuncs.com" path1:@"test"] subscribeNext:^(QQOSSResult<ALiOSSBucket *> * _Nullable x) {
//        if (x.error) {
//            NSLog(@"%@",x.error);
//            return ;
//        }
//        self.urlLabel.text = x.Body.imageURLArray.firstObject;
//        self.imageURL = x.Body.imageURLArray.firstObject;
//        NSLog(@"%@",self.imageURL);
//    }];
    
//    [[[QQOSSImageManager sharedManager] putImageArray:@[self.image] bucketName:@"common-rxjy" endpoint:@"https://oss-cn-beijing.aliyuncs.com" path:@""] subscribeNext:^(QQOSSResult<NSArray< ALiOSSBucket*> *> * _Nullable x) {
//        if (x.error) {
//            NSLog(@"%@",x.error);
//            return ;
//        }
//        self.urlLabel.text = x.Body.firstObject.imageURL;
//        self.imageURL = x.Body.firstObject.imageURL;
//        NSLog(@"%@",self.imageURL);
//    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (UIImagePickerController *)picker{
    if (!_picker) {
        _picker = [[UIImagePickerController alloc]init];
        _picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        _picker.delegate = self;
    }
    return _picker;
}
@end
