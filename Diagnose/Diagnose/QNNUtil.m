//
//  QNNUtil.m
//  QNNetworkDiagnose
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNUtil.h"

const int kQNNRequestStopped = -2;

@interface QNNUtil ()

@property (atomic, copy) NSString *ipAddress;

@end

@implementation QNNUtil

@synthesize ipAddress;

+ (QNNUtil *)sharedInstance {
    static dispatch_once_t once;
    static QNNUtil *sharedInstance;

    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *ipAddress = [QNNUtil ipAddressInCurl];
            dispatch_async(dispatch_get_main_queue(), ^{
                sharedInstance.ipAddress = ipAddress;
            });
        });
    });

    return sharedInstance;
}

+ (NSString *)ipAddressInCurl {
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://ip.cn"]];
    [urlRequest setHTTPMethod:@"GET"];
    [urlRequest setValue:@"curl/7.43.0" forHTTPHeaderField:@"User-Agent"];
    [urlRequest setTimeoutInterval:8];

    NSHTTPURLResponse *urlResponse = nil;
    NSError *urlError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                         returningResponse:&urlResponse
                                                     error:&urlError];

    if (urlError != nil || data == nil) {
        return @"0.0.0.0";
    }

    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (result == nil) {
        return @"0.0.0.0";
    }

    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d{1,3}(\\.\\d{1,3}){3}" options:NSRegularExpressionCaseInsensitive error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:result options:0 range:NSMakeRange(0, result.length)];
    if (match == nil) {
        return @"0.0.0.0";
    }

    return [result substringWithRange:match.range];
}

@end
