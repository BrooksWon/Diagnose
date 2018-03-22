//
//  QNNNslookup.m
//  QNNetworkDiagnose
//
//  Created by bailong on 16/2/2.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#include <arpa/inet.h>
#include <resolv.h>
#include <string.h>


#import "QNNNslookup.h"


const int kQNNTypeA = 1;
const int kQNNTypeCname = 5;

@implementation QNNRecord

- (instancetype)initWithValue:(NSString *)value ttl:(int)ttl type:(int)type {
    self = [super init];
    if (self) {
        _ttl = ttl;
        _value = value;
        _type = type;
    }

    return self;
}

- (NSString *)description {
    NSString *type;
    if (_type == kQNNTypeA) {
        type = @"A";
    } else if (_type == kQNNTypeCname) {
        type = @"CNAME";
    } else {
        type = [NSString stringWithFormat:@"TYPE-%d", _type];
    }

    return [NSString stringWithFormat:@"%d IN %@ %@", _ttl, type, _value];
}

@end

static NSArray *query_ip(res_state res, const char *host) {
    u_char answer[1500];
    int len = res_nquery(res, host, ns_c_in, ns_t_a, answer, sizeof(answer));

    ns_msg handle;
    ns_initparse(answer, len, &handle);

    int count = ns_msg_count(handle, ns_s_an);
    if (count <= 0) {
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:count];
    char buf[32];
    char cnameBuf[NS_MAXDNAME];
    memset(cnameBuf, 0, sizeof(cnameBuf));
    for (int i = 0; i < count; i++) {
        ns_rr rr;

        if (ns_parserr(&handle, ns_s_an, i, &rr) != 0) {
            return nil;
        }

        int t = ns_rr_type(rr);
        int ttl = ns_rr_ttl(rr);
        NSString *val;

        if (t == ns_t_a) {
            const char *p = inet_ntop(AF_INET, ns_rr_rdata(rr), buf, 32);
            val = [NSString stringWithUTF8String:p];
        } else if (t == ns_t_cname) {
            int x = ns_name_uncompress(answer, &(answer[len]), ns_rr_rdata(rr), cnameBuf, sizeof(cnameBuf));
            if (x <= 0) {
                continue;
            }
            val = [NSString stringWithUTF8String:cnameBuf];
            memset(cnameBuf, 0, sizeof(cnameBuf));
        } else {
            continue;
        }

        QNNRecord *record = [[QNNRecord alloc] initWithValue:val ttl:ttl type:t];
        [array addObject:record];
    }

    res_ndestroy(res);

    return array;
}

static int setup_dns_server(res_state res, const char *dns_server) {
    int r = res_ninit(res);
    if (r != 0) {
        return r;
    }
    if (dns_server == NULL) {
        return 0;
    }
    struct in_addr addr;
    r = inet_aton(dns_server, &addr);
    if (r == 0) {
        return -1;
    }

    res->nsaddr_list[0].sin_addr = addr;
    res->nsaddr_list[0].sin_family = AF_INET;
    res->nsaddr_list[0].sin_port = htons(NS_DEFAULTPORT);
    res->nscount = 1;

    return 0;
}

@interface QNNNslookup ()

@property (strong, readonly) NSString *host;
@property (strong, readonly) NSString *server;
@property (weak, readonly) id <QNNOutputDelegate> output;
@property (copy, readonly) QNNNslookupCompleteHandler complete;
@property (atomic, assign) BOOL stopped;

@end

@implementation QNNNslookup

- (instancetype)init:(NSString *)host server:(NSString *)server output:(id <QNNOutputDelegate>)output complete:(QNNNslookupCompleteHandler)complete {
    self = [super init];
    if (self) {
        _host = host;
        _server = server;
        _output = output;
        _complete = complete;
        _stopped = NO;
    }

    return self;
}

- (void)run {
    if (_output) {
        [_output write:[NSString stringWithFormat:@"query host: %@", _host]];

        if (_server == nil) {
            [_output write:@"system dns server\n"];
        } else {
            [_output write:[NSString stringWithFormat:@"custom dns server: %@", _server]];
        }
    }

    struct __res_state res;

    int r;
    NSDate *t1 = [NSDate date];
    if (_server == nil) {
        r = setup_dns_server(&res, NULL);
    } else {
        r = setup_dns_server(&res, [_server cStringUsingEncoding:NSASCIIStringEncoding]);
    }

    if (r != 0) {
        return;
    }

    NSArray *records = query_ip(&res, [_host cStringUsingEncoding:NSUTF8StringEncoding]);
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:t1];
    if (_output) {
        [_output write:[NSString stringWithFormat:@"query time: %f msec\n", duration * 1000]];

        for (QNNRecord *record in records) {
            [_output write:[NSString stringWithFormat:@"%@\n", record]];
        }
    }

    if (_complete) {
        _complete(records);
    }
}

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNNslookupCompleteHandler)complete {
    return [QNNNslookup start:host server:nil output:output complete:complete];
}

+ (instancetype)start:(NSString *)host server:(NSString *)server output:(id <QNNOutputDelegate>)output complete:(QNNNslookupCompleteHandler)complete {
    QNNNslookup *nslookup = [[QNNNslookup alloc] init:host server:server output:output complete:complete];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [nslookup run];
    });

    return nslookup;
}

- (void)stop {
    _stopped = YES;
}

@end
