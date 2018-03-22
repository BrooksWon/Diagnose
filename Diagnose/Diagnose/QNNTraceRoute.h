//
//  QNNTraceRoute.h
//  QNNetworkDiagnose
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNProtocols.h"
#import <Foundation/Foundation.h>


@interface QNNTraceRouteResult : NSObject

@property (assign, readonly) NSInteger code;

@end

typedef void (^QNNTraceRouteCompleteHandler)(QNNTraceRouteResult *);

@interface QNNTraceRoute : NSObject <QNNStopDelegate>

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTraceRouteCompleteHandler)complete;

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTraceRouteCompleteHandler)complete maxTTL:(NSInteger)maxTTL;

@end