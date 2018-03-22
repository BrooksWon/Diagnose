//
//  QNNHttp.m
//  QNNetworkDiagnose
//
//  Created by bailong on 16/2/10.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import "QNNHttp.h"


@implementation QNNHttpResult

- (NSString *)description {
    NSString *bodySummary = @"";
    if (_body != nil) {
        NSString *str = [[NSString alloc] initWithData:_body encoding:NSUTF8StringEncoding];
        if (str == nil) {
            bodySummary = @"not utf8 string body";
        }
    }

    return [NSString stringWithFormat:@"code:%ld duration:%f body:%@", (long) _code, _duration, bodySummary];
}

- (instancetype)initWithCode:(NSInteger)code duration:(NSTimeInterval)duration headers:(NSDictionary *)headers body:(NSData *)body {
    self = [super init];
    if (self) {
        _code = code;
        _duration = duration;
        _headers = headers;
        _body = body;
    }

    return self;
}

@end

@interface QNNHttp ()
@property (strong, readonly) NSString *url;
@property (weak, readonly) id <QNNOutputDelegate> output;
@property (copy, readonly) QNNHttpCompleteHandler complete;
@end

@implementation QNNHttp

- (instancetype)initWithUrl:(NSString *)url output:(id <QNNOutputDelegate>)output complete:(QNNHttpCompleteHandler)complete {
    self = [super init];
    if (self) {
        _url = url;
        _output = output;
        _complete = complete;
    }

    return self;
}

- (void)run {
    if (_output) {
        [_output write:[NSString stringWithFormat:@"GET %@", _url]];
    }

    NSDate *t1 = [NSDate date];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url]];
    [urlRequest setHTTPMethod:@"GET"];

    NSHTTPURLResponse *response = nil;
    NSError *httpError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&httpError];
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:t1] * 1000;
    if (_output) {
        if (httpError != nil) {
            [_output write:[httpError description]];
        }

        [_output write:[NSString stringWithFormat:@"complete duration:%f status %ld\n", duration, (long) response.statusCode]];

        if (response != nil && response.allHeaderFields != nil) {
            [response.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
                [_output write:[NSString stringWithFormat:@"%@: %@\n", key, obj]];
            }];
        }
    }

    if (_complete == nil) {
        return;
    }

    if (httpError != nil) {
        QNNHttpResult *result = [[QNNHttpResult alloc] initWithCode:httpError.code duration:duration headers:nil body:nil];
        _complete(result);
        return;
    }

    QNNHttpResult *result = [[QNNHttpResult alloc] initWithCode:response.statusCode duration:duration headers:response.allHeaderFields body:data];
    _complete(result);
}

+ (instancetype)start:(NSString *)url output:(id <QNNOutputDelegate>)output complete:(QNNHttpCompleteHandler)complete {
    QNNHttp *http = [[QNNHttp alloc] initWithUrl:url output:output complete:complete];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [http run];
    });

    return http;
}

- (void)stop {

}

@end