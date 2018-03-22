//
//  QNNNslookup.h
//  QNNetworkDiagnose
//
//  Created by bailong on 16/2/2.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNProtocols.h"
#import <Foundation/Foundation.h>


/**
 *  A 记录
 */
extern const int kQNNTypeA;

/**
 *  CNAME 记录
 */
extern const int kQNNTypeCname;

@interface QNNRecord : NSObject
@property (strong, readonly) NSString *value;
@property (assign, readonly) int ttl;
@property (assign, readonly) int type;

- (instancetype)initWithValue:(NSString *)value ttl:(int)ttl type:(int)type;

- (NSString *)description;

@end

typedef void (^QNNNslookupCompleteHandler)(NSArray *);

@interface QNNNslookup : NSObject <QNNStopDelegate>

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNNslookupCompleteHandler)complete;

+ (instancetype)start:(NSString *)host server:(NSString *)server output:(id <QNNOutputDelegate>)output complete:(QNNNslookupCompleteHandler)complete;

@end