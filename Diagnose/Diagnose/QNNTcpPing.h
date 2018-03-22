//
//  QNNTcpPing.h
//  QNNetworkDiagnose
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNProtocols.h"
#import <Foundation/Foundation.h>


@interface QNNTcpPingResult : NSObject

@property (assign, readonly) NSInteger code;
@property (assign, readonly) NSTimeInterval maxTime;
@property (assign, readonly) NSTimeInterval minTime;
@property (assign, readonly) NSTimeInterval avgTime;
@property (assign, readonly) NSInteger count;

- (NSString *)description;

@end

typedef void (^QNNTcpPingCompleteHandler)(QNNTcpPingResult *);

@interface QNNTcpPing : NSObject <QNNStopDelegate>

/**
 *    default port is 80
 *
 *    @param host     domain or ip
 *    @param output   output logger
 *    @param complete complete callback, maybe null
 *
 *    @return QNNTcpping instance, could be stop
 */
+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTcpPingCompleteHandler)complete;

+ (instancetype)start:(NSString *)host
                 port:(NSUInteger)port
                count:(NSUInteger)count
               output:(id <QNNOutputDelegate>)output
             complete:(QNNTcpPingCompleteHandler)complete;

@end