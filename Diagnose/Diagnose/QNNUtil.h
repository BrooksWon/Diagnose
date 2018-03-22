//
//  QNNUtil.h
//  QNNetworkDiagnose
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QNNUtil : NSObject

+ (QNNUtil *)sharedInstance;

/**
 * 获取外部 IP 地址
 */
- (nonnull NSString *)ipAddress;

@end
