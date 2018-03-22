//
//  QNNPing.h
//  QNNetworkDiagnose
//
//  Created by bailong on 15/12/30.
//  Copyright © 2015年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNProtocols.h"
#import <Foundation/Foundation.h>


extern const int kQNNInvalidPingResponse;

@interface QNNPingResult : NSObject

@property (assign, readonly) NSInteger code;
@property (assign, readonly) NSTimeInterval maxRtt;
@property (assign, readonly) NSTimeInterval minRtt;
@property (assign, readonly) NSTimeInterval avgRtt;
@property (assign, readonly) NSInteger loss;
@property (assign, readonly) NSInteger count;
@property (assign, readonly) NSTimeInterval totalTime;
@property (assign, readonly) NSTimeInterval standardDeviation; // 标准差

- (NSString *)description;

@end

typedef void (^QNNPingCompleteHandler)(QNNPingResult *);

@interface QNNPing : NSObject <QNNStopDelegate>

+ (instancetype)start:(NSString *)host output:(id<QNNOutputDelegate>)output complete:(QNNPingCompleteHandler)complete;

+ (instancetype)start:(NSString *)host
               output:(id<QNNOutputDelegate>)output
             complete:(QNNPingCompleteHandler)complete
             interval:(NSInteger)interval
                count:(NSInteger)count;

@end
