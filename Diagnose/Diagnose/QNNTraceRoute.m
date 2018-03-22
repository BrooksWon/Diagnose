//
//  QNNTraceRoute.m
//  QNNetworkDiagnose
//
//  Created by bailong on 16/1/26.
//  Copyright © 2016年 Qiniu Cloud Storage. All rights reserved.
//

#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#import <netinet/in.h>
#import <netinet/tcp.h>

#import <sys/select.h>
#import <sys/time.h>

#import "QNNTraceRoute.h"


@interface QNNTraceRouteRecord : NSObject
@property (assign, readonly) NSInteger hop;
@property (strong) NSString *ip;
@property (assign) NSTimeInterval *durations; // ms
@property (assign, readonly) NSInteger count;
@end

@implementation QNNTraceRouteRecord

- (instancetype)initWithHop:(NSInteger)hop count:(NSInteger)count {
    self = [super init];
    if (self) {
        _ip = nil;
        _hop = hop;
        _durations = (NSTimeInterval *) calloc(count, sizeof(NSTimeInterval));
        _count = count;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *record = [[NSMutableString alloc] initWithCapacity:20];

    [record appendFormat:@"%ld\t", (long) _hop];

    if (_ip == nil) {
        [record appendFormat:@" \t"];
    } else {
        [record appendFormat:@"%@\t", _ip];
    }

    for (int i = 0; i < _count; i++) {
        if (_durations[i] <= 0) {
            [record appendFormat:@"*\t"];
        } else {
            [record appendFormat:@"%.3f ms\t", _durations[i] * 1000];
        }
    }

    return record;
}

- (void)dealloc {
    free(_durations);
}

@end

@implementation QNNTraceRouteResult

- (instancetype)initWithCode:(NSInteger)code {
    self = [super init];
    if (self) {
        _code = code;
    }

    return self;
}

@end

@interface QNNTraceRoute ()
@property (strong, readonly) NSString *host;
@property (weak, readonly) id <QNNOutputDelegate> output;
@property (copy, readonly) QNNTraceRouteCompleteHandler complete;
@property (assign, readonly) NSInteger maxTTL;
@property (atomic, assign) NSInteger stopped;
@end

@implementation QNNTraceRoute

- (instancetype)initWithHost:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTraceRouteCompleteHandler)complete maxTTL:(NSInteger)maxTTL {
    self = [super init];
    if (self) {
        _host = host;
        _output = output;
        _complete = complete;
        _maxTTL = maxTTL;
        _stopped = NO;
    }

    return self;
}

static const int TraceRouteMaxAttempts = 3;

- (NSInteger)sendAndRecv:(int)sendSock recv:(int)icmpSock addr:(struct sockaddr_in *)addr ttl:(int)ttl ip:(in_addr_t *)ipOut {
    int err = 0;
    struct sockaddr_in storageAddr;
    socklen_t n = sizeof(struct sockaddr);
    static char cmsg[] = "renrenche network diagnose\n";
    char buff[100];

    QNNTraceRouteRecord *record = [[QNNTraceRouteRecord alloc] initWithHop:ttl count:TraceRouteMaxAttempts];
    for (int try = 0; try < TraceRouteMaxAttempts; try++) {
        NSDate *startTime = [NSDate date];
        ssize_t sent = sendto(sendSock, cmsg, sizeof(cmsg), 0, (struct sockaddr *) addr, sizeof(struct sockaddr));
        if (sent != sizeof(cmsg)) {
            err = errno;
            NSLog(@"error %s", strerror(err));
            [self.output write:[NSString stringWithFormat:@"send error %s\n", strerror(err)]];
            break;
        }

        struct timeval tv;
        fd_set readfds;
        tv.tv_sec = 3;
        tv.tv_usec = 0;
        FD_ZERO(&readfds);
        FD_SET(icmpSock, &readfds);
        select(icmpSock + 1, &readfds, NULL, NULL, &tv);
        if (FD_ISSET(icmpSock, &readfds) > 0) {
            ssize_t res = recvfrom(icmpSock, buff, sizeof(buff), 0, (struct sockaddr *) &storageAddr, &n);
            if (res < 0) {
                err = errno;
                [self.output write:[NSString stringWithFormat:@"recv error %s\n", strerror(err)]];
                break;
            } else {
                NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
                char ip[16] = {0};
                inet_ntop(AF_INET, &storageAddr.sin_addr.s_addr, ip, sizeof(ip));
                *ipOut = storageAddr.sin_addr.s_addr;
                NSString *remoteAddress = [NSString stringWithFormat:@"%s", ip];
                record.ip = remoteAddress;
                record.durations[try] = duration;
            }
        }

        if (_stopped) {
            break;
        }
    }

    [self.output write:[NSString stringWithFormat:@"%@\n", record]];

    return err;
}

- (void)run {
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(30002);
    addr.sin_addr.s_addr = inet_addr([_host UTF8String]);
    [self.output write:[NSString stringWithFormat:@"traceroute to %@ ...\n", _host]];
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent *host = gethostbyname([_host UTF8String]);
        if (host == NULL || host->h_addr == NULL) {
            [self.output write:@"problem accessing the DNS server"];
            if (_complete != nil) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    QNNTraceRouteResult *result = [[QNNTraceRouteResult alloc] initWithCode:-1006];
                    _complete(result);
                });
            }
            return;
        }
        addr.sin_addr = *(struct in_addr *) host->h_addr;
        [self.output write:[NSString stringWithFormat:@"traceroute to ip %s ...\n", inet_ntoa(addr.sin_addr)]];
    }

    int recv_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (-1 == fcntl(recv_sock, F_SETFL, O_NONBLOCK)) {
        NSLog(@"fcntl socket error!");
        if (_complete != nil) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                QNNTraceRouteResult *result = [[QNNTraceRouteResult alloc] initWithCode:-1];
                _complete(result);
            });
        }
        close(recv_sock);
        return;
    }

    int send_sock = socket(AF_INET, SOCK_DGRAM, 0);

    int ttl = 1;
    in_addr_t ip = 0;
    do {
        int t = setsockopt(send_sock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl));
        if (t < 0) {
            NSLog(@"error %s\n", strerror(t));
        }
        [self sendAndRecv:send_sock recv:recv_sock addr:&addr ttl:ttl ip:&ip];
    } while (++ttl <= _maxTTL && !_stopped && ip != addr.sin_addr.s_addr);

    close(send_sock);
    close(recv_sock);

    NSInteger code = 0;
    if (_stopped) {
        code = kQNNRequestStopped;
    }

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        QNNTraceRouteResult *result = [[QNNTraceRouteResult alloc] initWithCode:code];
        _complete(result);
    });
}

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTraceRouteCompleteHandler)complete {
    return [QNNTraceRoute start:host output:output complete:complete maxTTL:30];
}

+ (instancetype)start:(NSString *)host output:(id <QNNOutputDelegate>)output complete:(QNNTraceRouteCompleteHandler)complete maxTTL:(NSInteger)maxTTL {
    QNNTraceRoute *traceRoute = [[QNNTraceRoute alloc] initWithHost:host output:output complete:complete maxTTL:maxTTL];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [traceRoute run];
    });

    return traceRoute;
}

- (void)stop {
    _stopped = YES;
}

@end
