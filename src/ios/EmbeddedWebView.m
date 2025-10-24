#import "EmbeddedWebView.h"

@implementation EmbeddedWebView

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"EmbeddedWebView plugin initialized");
}

- (void)create:(CDVInvokedUrlCommand*)command {
    NSLog(@"Creating WebView");
    
    if (self.embeddedWebView != nil) {
        NSLog(@"WebView already exists, destroying before creating a new one");
        [self destroyWebView];
    }
    
    NSString *urlString = [command.arguments objectAtIndex:0];
    NSDictionary *options = [command.arguments objectAtIndex:1];
    
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            CGFloat topOffset = [[options objectForKey:@"top"] floatValue];
            CGFloat bottomOffset = [[options objectForKey:@"bottom"] floatValue];
            
            NSLog(@"WebView config - URL: %@", urlString);
            NSLog(@"User offsets - Top: %.2fpx, Bottom: %.2fpx", topOffset, bottomOffset);
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            UIView *mainView = weakSelf.viewController.view;
            
            CGFloat safeTop = 0;
            CGFloat safeBottom = 0;
            
            if (@available(iOS 11.0, *)) {
                UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
                
                // Check if Cordova webview consumes safe area
                BOOL cordovaConsumesSafeArea = !weakSelf.webView.scrollView.contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentNever;
                
                if (!cordovaConsumesSafeArea) {
                    safeTop = safeAreaInsets.top;
                    safeBottom = safeAreaInsets.bottom;
                }
            }
            
            NSLog(@"Safe area insets - Top: %.2fpx, Bottom: %.2fpx", safeTop, safeBottom);
            
            CGFloat finalTopMargin = safeTop + topOffset;
            CGFloat finalBottomMargin = safeBottom + bottomOffset;
            
            NSLog(@"Final margins - Top: %.2fpx, Bottom: %.2fpx", finalTopMargin, finalBottomMargin);
            
            // Create WKWebView configuration
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            config.allowsInlineMediaPlayback = YES;
            config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
            
            // Enable storage
            config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
            
            // Calculate frame
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            CGFloat webViewHeight = screenBounds.size.height - finalTopMargin - finalBottomMargin;
            CGRect frame = CGRectMake(0, finalTopMargin, screenBounds.size.width, webViewHeight);
            
            // Create WebView
            weakSelf.embeddedWebView = [[WKWebView alloc] initWithFrame:frame configuration:config];
            weakSelf.embeddedWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            weakSelf.embeddedWebView.backgroundColor = [UIColor clearColor];
            weakSelf.embeddedWebView.opaque = NO;
            
            // Configure scrolling
            weakSelf.embeddedWebView.scrollView.showsHorizontalScrollIndicator = NO;
            weakSelf.embeddedWebView.scrollView.showsVerticalScrollIndicator = NO;
            weakSelf.embeddedWebView.scrollView.bounces = YES;
            
            // Enable zoom if requested
            if ([[options objectForKey:@"enableZoom"] boolValue]) {
                weakSelf.embeddedWebView.scrollView.minimumZoomScale = 1.0;
                weakSelf.embeddedWebView.scrollView.maximumZoomScale = 3.0;
            } else {
                weakSelf.embeddedWebView.scrollView.minimumZoomScale = 1.0;
                weakSelf.embeddedWebView.scrollView.maximumZoomScale = 1.0;
            }
            
            // Clear cache if requested
            if ([[options objectForKey:@"clearCache"] boolValue]) {
                NSSet *dataTypes = [NSSet setWithArray:@[
                    WKWebsiteDataTypeDiskCache,
                    WKWebsiteDataTypeMemoryCache
                ]];
                NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
                [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                                           modifiedSince:dateFrom
                                                       completionHandler:^{}];
            }
            
            // Custom User-Agent
            if ([options objectForKey:@"userAgent"]) {
                NSString *userAgent = [options objectForKey:@"userAgent"];
                weakSelf.embeddedWebView.customUserAgent = userAgent;
            }
            
            // Add to view hierarchy
            [mainView addSubview:weakSelf.embeddedWebView];
            [mainView bringSubviewToFront:weakSelf.embeddedWebView];
            
            // Load URL
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            
            // Add custom headers if provided
            NSDictionary *headers = [options objectForKey:@"headers"];
            if (headers && [headers isKindOfClass:[NSDictionary class]]) {
                for (NSString *key in headers) {
                    [request setValue:[headers objectForKey:key] forHTTPHeaderField:key];
                }
            }
            
            [weakSelf.embeddedWebView loadRequest:request];
            
            NSLog(@"WebView created successfully");
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:@"WebView created successfully"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            
        } @catch (NSException *exception) {
            NSLog(@"Error creating WebView: %@", exception.reason);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:[NSString stringWithFormat:@"Error creating WebView: %@", exception.reason]];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)destroy:(CDVInvokedUrlCommand*)command {
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            [weakSelf destroyWebView];
            NSLog(@"WebView destroyed");
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:@"WebView destroyed"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"No WebView to destroy"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)destroyWebView {
    if (self.embeddedWebView != nil) {
        [self.embeddedWebView stopLoading];
        [self.embeddedWebView removeFromSuperview];
        self.embeddedWebView = nil;
    }
}

- (void)loadUrl:(CDVInvokedUrlCommand*)command {
    NSString *urlString = [command.arguments objectAtIndex:0];
    NSDictionary *headers = command.arguments.count > 1 ? [command.arguments objectAtIndex:1] : nil;
    
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            @try {
                NSURL *url = [NSURL URLWithString:urlString];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                
                if (headers && [headers isKindOfClass:[NSDictionary class]]) {
                    for (NSString *key in headers) {
                        [request setValue:[headers objectForKey:key] forHTTPHeaderField:key];
                    }
                }
                
                [weakSelf.embeddedWebView loadRequest:request];
                
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:[NSString stringWithFormat:@"URL loaded: %@", urlString]];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                
            } @catch (NSException *exception) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:[NSString stringWithFormat:@"Error loading URL: %@", exception.reason]];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)executeScript:(CDVInvokedUrlCommand*)command {
    NSString *script = [command.arguments objectAtIndex:0];
    
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            [weakSelf.embeddedWebView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
                if (error) {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:error.localizedDescription];
                    [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } else {
                    NSString *resultString = result ? [NSString stringWithFormat:@"%@", result] : @"";
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                      messageAsString:resultString];
                    [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)setVisible:(CDVInvokedUrlCommand*)command {
    BOOL visible = [[command.arguments objectAtIndex:0] boolValue];
    
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            weakSelf.embeddedWebView.hidden = !visible;
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:[NSString stringWithFormat:@"Visibility changed to: %@", visible ? @"true" : @"false"]];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)reload:(CDVInvokedUrlCommand*)command {
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            [weakSelf.embeddedWebView reload];
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:@"WebView reloaded"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)goBack:(CDVInvokedUrlCommand*)command {
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            if ([weakSelf.embeddedWebView canGoBack]) {
                [weakSelf.embeddedWebView goBack];
                
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:@"Navigated back"];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"Cannot go back"];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)goForward:(CDVInvokedUrlCommand*)command {
    __weak EmbeddedWebView *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.embeddedWebView != nil) {
            if ([weakSelf.embeddedWebView canGoForward]) {
                [weakSelf.embeddedWebView goForward];
                
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:@"Navigated forward"];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"Cannot go forward"];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)dispose {
    [self destroyWebView];
}

- (void)onReset {
    [self destroyWebView];
}

@end