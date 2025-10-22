#import "EmbeddedWebView.h"

@interface EmbeddedWebView () <WKNavigationDelegate, WKUIDelegate>
@end

@implementation EmbeddedWebView

- (void)pluginInitialize {
    [super pluginInitialize];
    self.whitelistDomains = [[NSMutableArray alloc] init];
    self.allowSubdomains = YES;
    self.whitelistEnabled = NO;
    self.autoResizeEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

#pragma mark - Whitelist Management

- (void)setWhitelist:(CDVInvokedUrlCommand*)command {
    NSArray *domains = [command.arguments objectAtIndex:0];
    BOOL allowSubs = [[command.arguments objectAtIndex:1] boolValue];
    
    if (![domains isKindOfClass:[NSArray class]]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:@"domains must be an array"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    
    [self.whitelistDomains removeAllObjects];
    for (NSString *domain in domains) {
        [self.whitelistDomains addObject:[domain lowercaseString]];
    }
    
    self.allowSubdomains = allowSubs;
    self.whitelistEnabled = YES;
    
    NSString *message = [NSString stringWithFormat:@"Whitelist configured with %lu domains", (unsigned long)self.whitelistDomains.count];
    NSLog(@"[EmbeddedWebView] %@", message);
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                messageAsString:message];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)clearWhitelist:(CDVInvokedUrlCommand*)command {
    [self.whitelistDomains removeAllObjects];
    self.whitelistEnabled = NO;
    
    NSLog(@"[EmbeddedWebView] Whitelist cleared");
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                messageAsString:@"Whitelist cleared"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (BOOL)isUrlAllowed:(NSString *)urlString {
    if (!self.whitelistEnabled || self.whitelistDomains.count == 0) {
        return YES;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = [[url host] lowercaseString];
    
    if (!host) {
        return NO;
    }
    
    NSLog(@"[EmbeddedWebView] Checking URL: %@ (host: %@)", urlString, host);
    
    for (NSString *allowedDomain in self.whitelistDomains) {
        if ([allowedDomain hasPrefix:@"*."]) {
            NSString *baseDomain = [allowedDomain substringFromIndex:2];
            if ([host isEqualToString:baseDomain] || [host hasSuffix:[@"." stringByAppendingString:baseDomain]]) {
                NSLog(@"[EmbeddedWebView] URL allowed by wildcard: %@", allowedDomain);
                return YES;
            }
        } else if ([host isEqualToString:allowedDomain]) {
            NSLog(@"[EmbeddedWebView] URL allowed by exact match: %@", allowedDomain);
            return YES;
        } else if (self.allowSubdomains && [host hasSuffix:[@"." stringByAppendingString:allowedDomain]]) {
            NSLog(@"[EmbeddedWebView] URL allowed by subdomain: %@", allowedDomain);
            return YES;
        }
    }
    
    NSLog(@"[EmbeddedWebView] URL blocked by whitelist: %@", urlString);
    return NO;
}

#pragma mark - WebView Creation

- (void)create:(CDVInvokedUrlCommand*)command {
    NSLog(@"[EmbeddedWebView] Creating WebView");
    
    if (self.embeddedWebView != nil) {
        NSLog(@"[EmbeddedWebView] WebView already exists, destroying before creating a new one");
        [self destroyWebView];
    }
    
    NSString *containerId = [command.arguments objectAtIndex:0];
    NSString *urlString = [command.arguments objectAtIndex:1];
    NSDictionary *options = [command.arguments objectAtIndex:2];
    
    // Configure whitelist from options
    if (options[@"whitelist"]) {
        NSArray *whitelistArray = options[@"whitelist"];
        BOOL allowSubs = [options[@"allowSubdomains"] boolValue];
        if (allowSubs == NO && options[@"allowSubdomains"] == nil) {
            allowSubs = YES; // default
        }
        
        [self.whitelistDomains removeAllObjects];
        for (NSString *domain in whitelistArray) {
            [self.whitelistDomains addObject:[domain lowercaseString]];
        }
        
        self.allowSubdomains = allowSubs;
        self.whitelistEnabled = YES;
        NSLog(@"[EmbeddedWebView] Whitelist configured from options: %lu domains", (unsigned long)self.whitelistDomains.count);
    }
    
    self.autoResizeEnabled = YES;
    if (options[@"autoResize"] && [options[@"autoResize"] isKindOfClass:[NSNumber class]]) {
        self.autoResizeEnabled = [options[@"autoResize"] boolValue];
    }
    
    self.containerIdentifier = containerId;
    
    if (![self isUrlAllowed:urlString]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:[NSString stringWithFormat:@"URL not allowed by whitelist: %@", urlString]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    
    [self getContainerBounds:containerId completion:^(CGRect bounds) {
        if (CGRectIsNull(bounds)) {
            NSLog(@"[EmbeddedWebView] Container not found: %@", containerId);
            return;
        }
        
        [self createNativeWebView:urlString options:options bounds:bounds callbackId:command.callbackId];
    }];
}

- (WKWebView *)getCordovaWebView {
    // Fix access to Cordova WKWebView
    if ([self.webView isKindOfClass:[WKWebView class]]) {
        return (WKWebView *)self.webView;
    }
    return nil;
}

- (void)getContainerBounds:(NSString *)containerId completion:(void (^)(CGRect))completion {
    NSString *script = [NSString stringWithFormat:
        @"(function() {"
        @"  var container = document.getElementById('%@');"
        @"  if (container) {"
        @"    var rect = container.getBoundingClientRect();"
        @"    return JSON.stringify({"
        @"      x: rect.left,"
        @"      y: rect.top,"
        @"      width: rect.width,"
        @"      height: rect.height"
        @"    });"
        @"  }"
        @"  return null;"
        @"})();", containerId];
    
    WKWebView *cordovaWebView = [self getCordovaWebView];
    if (!cordovaWebView) {
        NSLog(@"[EmbeddedWebView] Could not get Cordova WKWebView");
        completion(CGRectNull);
        return;
    }
    
    [cordovaWebView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || !result || [result isEqual:[NSNull null]]) {
            completion(CGRectNull);
            return;
        }
        
        NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *bounds = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        if (bounds) {
            CGFloat x = [bounds[@"x"] doubleValue];
            CGFloat y = [bounds[@"y"] doubleValue];
            CGFloat width = [bounds[@"width"] doubleValue];
            CGFloat height = [bounds[@"height"] doubleValue];
            
            completion(CGRectMake(x, y, width, height));
        } else {
            completion(CGRectNull);
        }
    }];
}

- (void)createNativeWebView:(NSString *)urlString options:(NSDictionary *)options bounds:(CGRect)bounds callbackId:(NSString *)callbackId {
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.allowsInlineMediaPlayback = YES;
        
        self.embeddedWebView = [[WKWebView alloc] initWithFrame:bounds configuration:config];
        self.embeddedWebView.navigationDelegate = self;
        self.embeddedWebView.UIDelegate = self;
        self.embeddedWebView.opaque = NO;
        self.embeddedWebView.backgroundColor = [UIColor whiteColor];
        
        // Apply options
        if (options[@"enableZoom"] && ![options[@"enableZoom"] boolValue]) {
            NSString *js = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'); document.getElementsByTagName('head')[0].appendChild(meta);";
            WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
            [self.embeddedWebView.configuration.userContentController addUserScript:script];
        }
        
        [self positionWebView:bounds];
        
        // Load URL
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        
        if (options[@"headers"]) {
            NSDictionary *headers = options[@"headers"];
            for (NSString *key in headers) {
                [request setValue:headers[key] forHTTPHeaderField:key];
            }
        }
        
        if (options[@"userAgent"]) {
            self.embeddedWebView.customUserAgent = options[@"userAgent"];
        }
        
        [self.embeddedWebView loadRequest:request];
        
        NSLog(@"[EmbeddedWebView] WebView created successfully");
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                    messageAsString:@"WebView created successfully"];
        [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    });
}

- (void)positionWebView:(CGRect)bounds {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.embeddedWebView) {
            NSLog(@"[EmbeddedWebView] positionWebView called but embeddedWebView is nil");
            return;
        }
        
        UIView *parentView = self.webView.superview;
        if (!parentView) {
            parentView = self.viewController.view;
        }
        
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect deviceBounds = CGRectMake(
            bounds.origin.x * scale,
            bounds.origin.y * scale,
            bounds.size.width * scale,
            bounds.size.height * scale
        );
        
        NSLog(@"[EmbeddedWebView] Positioning WebView - CSS: [%.0f,%.0f,%.0f,%.0f] Device: [%.0f,%.0f,%.0f,%.0f]",
              bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height,
              deviceBounds.origin.x, deviceBounds.origin.y, deviceBounds.size.width, deviceBounds.size.height);
        
        self.embeddedWebView.frame = bounds;
        
        if (!self.embeddedWebView.superview) {
            [parentView addSubview:self.embeddedWebView];
        }
    });
}

- (void)updateWebViewPosition {
    if (!self.embeddedWebView || !self.containerIdentifier) {
        return;
    }
    
    [self getContainerBounds:self.containerIdentifier completion:^(CGRect bounds) {
        if (!CGRectIsNull(bounds)) {
            NSLog(@"[EmbeddedWebView] Updating WebView bounds");
            [self positionWebView:bounds];
        }
    }];
}

#pragma mark - Orientation Change

- (void)orientationChanged:(NSNotification *)notification {
    if (self.embeddedWebView && self.autoResizeEnabled) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateWebViewPosition];
        });
    }
}

#pragma mark - WebView Actions

- (void)destroy:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self destroyWebView];
        
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                    messageAsString:@"WebView destroyed"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    });
}

- (void)destroyWebView {
    if (self.embeddedWebView) {
        [self.embeddedWebView removeFromSuperview];
        [self.embeddedWebView stopLoading];
        self.embeddedWebView.navigationDelegate = nil;
        self.embeddedWebView.UIDelegate = nil;
        self.embeddedWebView = nil;
        NSLog(@"[EmbeddedWebView] WebView destroyed");
    }
}

- (void)loadUrl:(CDVInvokedUrlCommand*)command {
    NSString *urlString = [command.arguments objectAtIndex:0];
    NSDictionary *headers = nil;
    
    if (command.arguments.count > 1 && [command.arguments objectAtIndex:1] != [NSNull null]) {
        headers = [command.arguments objectAtIndex:1];
    }
    
    if (![self isUrlAllowed:urlString]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:[NSString stringWithFormat:@"URL not allowed by whitelist: %@", urlString]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            
            if (headers) {
                for (NSString *key in headers) {
                    [request setValue:headers[key] forHTTPHeaderField:key];
                }
            }
            
            [self.embeddedWebView loadRequest:request];
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:[NSString stringWithFormat:@"URL loaded: %@", urlString]];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)executeScript:(CDVInvokedUrlCommand*)command {
    NSString *script = [command.arguments objectAtIndex:0];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            [self.embeddedWebView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
                if (error) {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:error.localizedDescription];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } else {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                     messageAsString:[NSString stringWithFormat:@"%@", result ?: @""]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)setVisible:(CDVInvokedUrlCommand*)command {
    BOOL visible = [[command.arguments objectAtIndex:0] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            self.embeddedWebView.hidden = !visible;
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:[NSString stringWithFormat:@"Visibility changed to: %@", visible ? @"true" : @"false"]];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)reload:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            [self.embeddedWebView reload];
            
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:@"WebView reloaded"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)goBack:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            if ([self.embeddedWebView canGoBack]) {
                [self.embeddedWebView goBack];
                
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:@"Navigated back"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"Cannot go back"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

- (void)goForward:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            if ([self.embeddedWebView canGoForward]) {
                [self.embeddedWebView goForward];
                
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:@"Navigated forward"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:@"Cannot go forward"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"[EmbeddedWebView] Page loaded: %@", webView.URL.absoluteString);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"[EmbeddedWebView] Error loading page: %@", error.localizedDescription);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *urlString = navigationAction.request.URL.absoluteString;
    
    if ([self isUrlAllowed:urlString]) {
        NSLog(@"[EmbeddedWebView] Navigation allowed to: %@", urlString);
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        NSLog(@"[EmbeddedWebView] Navigation blocked by whitelist: %@", urlString);
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

#pragma mark - Cleanup

- (void)dispose {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self destroyWebView];
}

- (void)dealloc {
    [self dispose];
}

@end