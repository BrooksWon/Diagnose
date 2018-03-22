//
//  DiagnoseKit.m
//  Diagnose
//
//  Created by Brooks on 2018/3/22.
//  Copyright © 2018年 Brooks. All rights reserved.
//

#import "DiagnoseKit.h"
#import "DiagnoseViewController.h"

@implementation DiagnoseKit

+ (void)helloDiagnoseKit
{
    UINavigationController *navgationVC = [[UINavigationController alloc] initWithRootViewController:DiagnoseViewController.new];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:navgationVC
                                                                                 animated:YES completion:nil];
}

@end
