//
//  ViewController.m
//  Diagnose
//
//  Created by Brooks on 2018/3/22.
//  Copyright © 2018年 Brooks. All rights reserved.
//

#import "ViewController.h"
#import "DiagnoseKit.h"

@interface ViewController ()

@end

@implementation ViewController
- (IBAction)btnAction:(id)sender {
    
    [DiagnoseKit helloDiagnoseKit];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}



@end
