//
//  DiagnoseViewController.m
//  Diagnose
//
//  Created by Brooks on 2018/3/22.
//  Copyright © 2018年 Brooks. All rights reserved.
//

#import "DiagnoseViewController.h"

#import "QNNetworkDiagnose.h"
#import "OAStackView.h"
#import "Masonry.h"


@interface DiagnoseViewController () <QNNOutputDelegate>

@property (nonatomic, assign) BOOL didSetupConstraints;

@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;

@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) OAStackView *stackView;

@property (nonatomic, strong) UIButton *tcpButton;
@property (nonatomic, strong) UIButton *httpButton;
@property (nonatomic, strong) UIButton *pingButton;
@property (nonatomic, strong) UIButton *nslookupButton;
@property (nonatomic, strong) UIButton *traceRouteButton;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation DiagnoseViewController

- (void)configureWithDeepLink {
    NSArray *availableMethods = @[@"http", @"tcp", @"ping", @"nslookup", @"traceroute"];
    
    NSString *url = @"www.baidu.com";
    NSString *method = @"http";
    
    if (url) {
        self.textField.text = url;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (method && [availableMethods containsObject:method]) {
        NSString *selectorString = [NSString stringWithFormat:@"%@Action:", method];
        if ([self respondsToSelector:NSSelectorFromString(selectorString)]) {
            [self performSelector:NSSelectorFromString(selectorString) withObject:self];
        }
    }
#pragma clang diagnostic pop
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    //    [self configureWithDeepLink];
    
    
    self.navigationItem.title = @"诊断";
    self.navigationItem.leftBarButtonItem = self.leftBarButtonItem;
    self.navigationItem.rightBarButtonItem = self.rightBarButtonItem;
    
    [self.stackView addArrangedSubview:self.httpButton];
    [self.stackView addArrangedSubview:self.tcpButton];
    [self.stackView addArrangedSubview:self.pingButton];
    [self.stackView addArrangedSubview:self.nslookupButton];
    [self.stackView addArrangedSubview:self.traceRouteButton];
    
    
    [self.view addSubview:self.textField];
    [self.view addSubview:self.stackView];
    [self.view addSubview:self.textView];
    
    [self updateViewConstraints];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)updateViewConstraints {
    if (!self.didSetupConstraints) {
        [self.textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.mas_topLayoutGuideBottom);
            make.centerX.and.width.equalTo(self.view);
            make.height.equalTo(@44);
        }];
        
        [self.stackView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.textField.mas_bottom);
            make.centerX.and.width.equalTo(self.view);
            make.height.equalTo(@44);
        }];
        
        [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.stackView.mas_bottom);
            make.centerX.and.width.equalTo(self.view);
            make.bottom.equalTo(self.view);
        }];
        
        self.didSetupConstraints = YES;
    }
    
    [super updateViewConstraints];
}

#pragma mark - delegate

- (void)backAction:(UIButton *)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)shareAction:(UIButton *)sender {
    UIImage *snapshot = [self viewAsImage:self.textView];
    UIImageWriteToSavedPhotosAlbum(snapshot, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (UIImage *)viewAsImage:(UIScrollView *)scrollView {
    UIImage *image = nil;
    
    CGRect originalFrame = scrollView.frame;
    CGRect fullSizeFrame = scrollView.frame;
    
    fullSizeFrame.size.height = scrollView.contentSize.height;
    scrollView.frame = fullSizeFrame;
    
    UIGraphicsBeginImageContextWithOptions(fullSizeFrame.size, false, [UIScreen mainScreen].scale);
    
    [scrollView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    [scrollView.layer renderInContext:UIGraphicsGetCurrentContext()];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    scrollView.frame = originalFrame;
    
    return image;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (!error) {
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:@"保存到相册，请通过微信反馈，谢谢！"
                                   delegate:nil
                          cancelButtonTitle:@"好的" otherButtonTitles: nil] show];
    }
}

- (void)write:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *text = self.textView.text;
        text = [text stringByAppendingString:@"\r\n"];
        text = [text stringByAppendingString:line];
        
        self.textView.text = text;
    });
}

- (void)httpAction:(id)sender {
    [self.textField resignFirstResponder];
    
    NSString *urlString = self.textField.text;
    if (urlString.length == 0) {
        return;
    }
    
    if (![urlString hasPrefix:@"http"]) {
        urlString = [NSString stringWithFormat:@"https://%@", urlString];
    }
    
    [self write:@"==================\r\nBegin HTTP diagnose\r\n==================\r\n"];
    
    [QNNHttp start:urlString output:self complete:^(QNNHttpResult *result) {
        [self write:result.description];
        
        [self write:@"\r\n==================\r\nEnd HTTP diagnose\r\n==================\r\n"];
    }];
}

- (void)tcpAction:(id)sender {
    [self.textField resignFirstResponder];
    
    if (self.textField.text.length == 0) {
        return;
    }
    
    NSString *host = [self hostForUrlString:self.textField.text];
    
    [self write:@"\r\n==================\r\nBegin TCP diagnose\r\n==================\r\n"];
    
    [QNNTcpPing start:host output:self complete:^(QNNTcpPingResult *result) {
        [self write:result.description];
        
        [self write:@"\r\n==================\r\nEnd TCP diagnose\r\n==================\r\n"];
    }];
}

- (void)pingAction:(id)sender {
    [self.textField resignFirstResponder];
    
    if (self.textField.text.length == 0) {
        return;
    }
    
    NSString *host = [self hostForUrlString:self.textField.text];
    
    [self write:@"==================\r\nBegin ping diagnose\r\n==================\r\n"];
    
    [QNNPing start:host output:self complete:^(QNNPingResult *result) {
        [self write:result.description];
        
        [self write:@"\r\n==================\r\nEnd ping diagnose\r\n==================\r\n"];
    }];
}

- (void)nslookupAction:(id)sender {
    [self.textField resignFirstResponder];
    
    if (self.textField.text.length == 0) {
        return;
    }
    
    NSString *host = [self hostForUrlString:self.textField.text];
    
    [self write:@"==================\r\nBegin nslookup diagnose\r\n==================\r\n"];
    
    [QNNNslookup start:host output:self complete:^(NSArray *array) {
        [self write:@"\r\n==================\r\nEnd nslookup diagnose\r\n==================\r\n"];
    }];
}

- (void)tracerouteAction:(id)sender {
    [self.textField resignFirstResponder];
    
    if (self.textField.text.length == 0) {
        return;
    }
    
    NSString *host = [self hostForUrlString:self.textField.text];
    
    [self write:@"==================\r\nBegin traceroute diagnose\r\n==================\r\n"];
    
    [QNNTraceRoute start:host output:self complete:^(QNNTraceRouteResult *result) {
        [self write:result.description];
        
        [self write:@"\r\n==================\r\nEnd traceroute diagnose\r\n==================\r\n"];
    }];
}

- (NSString *)hostForUrlString:(NSString *)urlString {
    if (!urlString) {
        return nil;
    }
    
    if (![urlString hasPrefix:@"http"]) {
        urlString = [NSString stringWithFormat:@"https://%@", urlString];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    return url.host;
}

#pragma mark - private methods

- (UIBarButtonItem *)leftBarButtonItem {
    if (!_leftBarButtonItem) {
        _leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(backAction:)];
    }
    
    return _leftBarButtonItem;
}

- (UIBarButtonItem *)rightBarButtonItem {
    if (!_rightBarButtonItem) {
        _rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"分享"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(shareAction:)];
    }
    
    return _rightBarButtonItem;
}

- (UITextField *)textField {
    if (!_textField) {
        _textField = [UITextField new];
        _textField.backgroundColor = [UIColor whiteColor];
        _textField.font = [UIFont systemFontOfSize:12];
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.placeholder = @"URL / Domain / IP";
        
        _textField.leftViewMode = UITextFieldViewModeAlways;
        _textField.leftView = [[UIView alloc] init];
        _textField.leftView.contentMode = UIViewContentModeLeft;
        _textField.leftView.frame = CGRectMake(_textField.leftView.frame.origin.x, _textField.leftView.frame.origin.y, _textField.leftView.frame.size.width+12, _textField.leftView.frame.size.height);
        
        _textField.layer.masksToBounds = YES;
        _textField.layer.borderColor = [UIColor grayColor].CGColor;
        _textField.layer.borderWidth = 1.0f / [UIScreen mainScreen].scale;
    }
    
    return _textField;
}

- (OAStackView *)stackView {
    if (!_stackView) {
        _stackView = [OAStackView new];
        _stackView.axis = UILayoutConstraintAxisHorizontal;
        _stackView.alignment = OAStackViewAlignmentFill;
        _stackView.distribution = OAStackViewDistributionFillProportionally;
    }
    
    return _stackView;
}

- (UIButton *)httpButton {
    if (!_httpButton) {
        _httpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _httpButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_httpButton setTitle:@"HTTP" forState:UIControlStateNormal];
        [_httpButton addTarget:self action:@selector(httpAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _httpButton;
}

- (UIButton *)tcpButton {
    if (!_tcpButton) {
        _tcpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _tcpButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_tcpButton setTitle:@"TCP" forState:UIControlStateNormal];
        [_tcpButton addTarget:self action:@selector(tcpAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _tcpButton;
}

- (UIButton *)pingButton {
    if (!_pingButton) {
        _pingButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _pingButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_pingButton setTitle:@"ping" forState:UIControlStateNormal];
        [_pingButton addTarget:self action:@selector(pingAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _pingButton;
}

- (UIButton *)nslookupButton {
    if (!_nslookupButton) {
        _nslookupButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _nslookupButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_nslookupButton setTitle:@"nslookup" forState:UIControlStateNormal];
        [_nslookupButton addTarget:self action:@selector(nslookupAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _nslookupButton;
}

- (UIButton *)traceRouteButton {
    if (!_traceRouteButton) {
        _traceRouteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _traceRouteButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_traceRouteButton setTitle:@"traceroute" forState:UIControlStateNormal];
        [_traceRouteButton addTarget:self action:@selector(tracerouteAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _traceRouteButton;
}


- (UITextView *)textView {
    if (!_textView) {
        _textView = [[UITextView alloc] init];
        _textView.editable = NO;
    }
    
    return _textView;
}

@end

