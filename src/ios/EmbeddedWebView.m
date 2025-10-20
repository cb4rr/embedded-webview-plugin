#import "EmbeddedWebView.h"

@implementation EmbeddedWebView

static NSString *const TAG = @"EmbeddedWebView";

- (void)pluginInitialize {
    [super pluginInitialize];
    NSLog(@"%@: Plugin initialized", TAG);
    self.whitelist = [[NSMutableArray alloc] init];
    self.allowSubdomains = YES;
    self.whitelistEnabled = NO;
}

#pragma mark - Whitelist Methods

- (void)setWhitelist:(CDVInvokedUrlCommand*)command {
    NSArray *domains = [command.arguments objectAtIndex:0];
    BOOL allowSubs = [[command.arguments objectAtIndex:1] boolValue];
    
    if (![domains isKindOfClass:[NSArray class]]) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:@"domains must be an array"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    [self.whitelist removeAllObjects];
    for (NSString *domain in domains) {
        [self.whitelist addObject:[domain lowercaseString]];
    }
    
    self.allowSubdomains = allowSubs;
    self.whitelistEnabled = YES;
    
    NSLog(@"%@: Whitelist configured with %lu domains", TAG, (unsigned long)self.whitelist.count);
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
        messageAsString:[NSString stringWithFormat:@"Whitelist configured with %lu domains", (unsigned long)self.whitelist.count]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)clearWhitelist:(CDVInvokedUrlCommand*)command {
    [self.whitelist removeAllObjects];
    self.whitelistEnabled = NO;
    
    NSLog(@"%@: Whitelist cleared", TAG);
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
        messageAsString:@"Whitelist cleared"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (BOOL)isUrlAllowed:(NSString *)urlString {
    if (!self.whitelistEnabled || self.whitelist.count == 0) {
        return YES;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = [[url host] lowercaseString];
    
    if (!host) {
        return NO;
    }
    
    NSLog(@"%@: Checking URL: %@ (host: %@)", TAG, urlString, host);
    
    for (NSString *allowedDomain in self.whitelist) {
        // Support for wildcards (*.example.com)
        if ([allowedDomain hasPrefix:@"*."]) {
            NSString *baseDomain = [allowedDomain substringFromIndex:2];
            if ([host isEqualToString:baseDomain] || [host hasSuffix:[NSString stringWithFormat:@".%@", baseDomain]]) {
                NSLog(@"%@: URL allowed by wildcard: %@", TAG, allowedDomain);
                return YES;
            }
        }
        // Exact match
        else if ([host isEqualToString:allowedDomain]) {
            NSLog(@"%@: URL allowed by exact match: %@", TAG, allowedDomain);
            return YES;
        }
        // Allow subdomains if enabled
        else if (self.allowSubdomains && [host hasSuffix:[NSString stringWithFormat:@".%@", allowedDomain]]) {
            NSLog(@"%@: URL allowed by subdomain: %@", TAG, allowedDomain);
            return YES;
        }
    }
    
    NSLog(@"%@: URL blocked by whitelist: %@", TAG, urlString);
    return NO;
}

#pragma mark - Main Methods

- (void)create:(CDVInvokedUrlCommand*)command {
    NSString *containerId = [command.arguments objectAtIndex:0];
    NSString *urlString = [command.arguments objectAtIndex:1];
    NSDictionary *options = [command.arguments objectAtIndex:2];
    
    NSLog(@"%@: Creating WebView for container: %@", TAG, containerId);
    self.currentContainerId = containerId;
    self.callbackId = command.callbackId;
    
    if (options[@"whitelist"]) {
        NSArray *whitelistArray = options[@"whitelist"];
        BOOL allowSubs = options[@"allowSubdomains"] ? [options[@"allowSubdomains"] boolValue] : YES;
        
        [self.whitelist removeAllObjects];
        for (NSString *domain in whitelistArray) {
            [self.whitelist addObject:[domain lowercaseString]];
        }
        self.allowSubdomains = allowSubs;
        self.whitelistEnabled = YES;
        NSLog(@"%@: Whitelist configured from options: %lu domains", TAG, (unsigned long)self.whitelist.count);
    }
    
    if (![self isUrlAllowed:urlString]) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:@"URL not allowed by whitelist: %@", urlString]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *js = [NSString stringWithFormat:
        @"(function() {"
        @"  var el = document.getElementById('%@');"
        @"  if (!el) {"
        @"    console.error('Container not found: %@');"
        @"    return null;"
        @"  }"
        @"  var rect = el.getBoundingClientRect();"
        @"  console.log('Container found:', rect);"
        @"  return JSON.stringify({"
        @"    x: rect.left,"
        @"    y: rect.top,"
        @"    width: rect.width,"
        @"    height: rect.height"
        @"  });"
        @"})();", containerId, containerId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webViewEngine evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"%@: Error executing JS: %@", TAG, error.localizedDescription);
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:[NSString stringWithFormat:@"Error finding container: %@", error.localizedDescription]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            NSLog(@"%@: JS result: %@", TAG, result);
            
            if (!result || [result isEqual:[NSNull null]]) {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:[NSString stringWithFormat:@"Container not found: %@", containerId]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            NSString *jsonString = (NSString *)result;
            NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *parseError;
            NSDictionary *rect = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&parseError];
            
            if (parseError || !rect) {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:@"Error parsing container dimensions"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            CGFloat x = [[rect objectForKey:@"x"] doubleValue];
            CGFloat y = [[rect objectForKey:@"y"] doubleValue];
            CGFloat width = [[rect objectForKey:@"width"] doubleValue];
            CGFloat height = [[rect objectForKey:@"height"] doubleValue];
            
            NSLog(@"%@: Position: x=%.2f, y=%.2f, w=%.2f, h=%.2f", TAG, x, y, width, height);
            
            [self createNativeWebViewAtX:x y:y width:width height:height url:urlString options:options command:command];
        }];
    });
}

- (void)createNativeWebViewAtX:(CGFloat)x 
                              y:(CGFloat)y 
                          width:(CGFloat)width 
                         height:(CGFloat)height 
                            url:(NSString *)urlString 
                        options:(NSDictionary *)options 
                        command:(CDVInvokedUrlCommand *)command {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            config.allowsInlineMediaPlayback = YES;
            config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
            
            if (options[@"userAgent"]) {
                config.applicationNameForUserAgent = options[@"userAgent"];
            }
            
            self.embeddedWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
            self.embeddedWebView.navigationDelegate = self;
            self.embeddedWebView.UIDelegate = self;
            self.embeddedWebView.translatesAutoresizingMaskIntoConstraints = NO;
            self.embeddedWebView.opaque = NO;
            self.embeddedWebView.backgroundColor = [UIColor clearColor];
            
            if (options[@"enableZoom"]) {
                BOOL enableZoom = [options[@"enableZoom"] boolValue];
                if (!enableZoom) {
                    NSString *js = @"var meta = document.createElement('meta');"
                                   @"meta.name = 'viewport';"
                                   @"meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
                                   @"document.getElementsByTagName('head')[0].appendChild(meta);";
                    WKUserScript *script = [[WKUserScript alloc] initWithSource:js 
                                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd 
                                                               forMainFrameOnly:YES];
                    [config.userContentController addUserScript:script];
                }
            }
            
            if (options[@"clearCache"] && [options[@"clearCache"] boolValue]) {
                NSSet *dataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeDiskCache, 
                                                         WKWebsiteDataTypeMemoryCache]];
                NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
                [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes 
                                                           modifiedSince:dateFrom 
                                                       completionHandler:^{
                    NSLog(@"%@: Cache cleared", TAG);
                }];
            }
            
            CGRect frame = CGRectMake(x, y, width, height);
            self.embeddedWebView.frame = frame;
            
            UIView *mainView = self.webView.superview;
            if (mainView) {
                [mainView addSubview:self.embeddedWebView];
                
                NSURL *url = [NSURL URLWithString:urlString];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                
                if (options[@"headers"]) {
                    NSDictionary *headers = options[@"headers"];
                    for (NSString *key in headers) {
                        [request setValue:headers[key] forHTTPHeaderField:key];
                    }
                    NSLog(@"%@: Loading URL with custom headers: %@", TAG, urlString);
                } else {
                    NSLog(@"%@: Loading URL: %@", TAG, urlString);
                }
                
                [self.embeddedWebView loadRequest:request];
                
                NSLog(@"%@: WebView created successfully", TAG);
            } else {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:@"Could not find main view to attach WebView"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        } @catch (NSException *exception) {
            NSLog(@"%@: Exception creating WebView: %@", TAG, exception.reason);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:[NSString stringWithFormat:@"Error creating WebView: %@", exception.reason]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)destroy:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            [self.embeddedWebView removeFromSuperview];
            [self.embeddedWebView stopLoading];
            self.embeddedWebView.navigationDelegate = nil;
            self.embeddedWebView.UIDelegate = nil;
            self.embeddedWebView = nil;
            self.currentContainerId = nil;
            self.callbackId = nil;
            
            NSLog(@"%@: WebView destroyed", TAG);
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                messageAsString:@"WebView destroyed"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"No WebView to destroy"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)loadUrl:(CDVInvokedUrlCommand*)command {
    NSString *urlString = [command.arguments objectAtIndex:0];
    NSDictionary *headers = nil;
    
    if ([command.arguments count] > 1 && ![[command.arguments objectAtIndex:1] isEqual:[NSNull null]]) {
        headers = [command.arguments objectAtIndex:1];
    }
    
    // Check if URL is allowed
    if (![self isUrlAllowed:urlString]) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:@"URL not allowed by whitelist: %@", urlString]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            
            if (headers) {
                for (NSString *key in headers) {
                    [request setValue:headers[key] forHTTPHeaderField:key];
                }
                NSLog(@"%@: Loading URL with headers: %@", TAG, urlString);
            } else {
                NSLog(@"%@: Loading URL: %@", TAG, urlString);
            }
            
            [self.embeddedWebView loadRequest:request];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                messageAsString:[NSString stringWithFormat:@"URL loaded: %@", urlString]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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
                    NSString *resultString = result ? [NSString stringWithFormat:@"%@", result] : @"";
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        messageAsString:resultString];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)setVisible:(CDVInvokedUrlCommand*)command {
    BOOL visible = [[command.arguments objectAtIndex:0] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            self.embeddedWebView.hidden = !visible;
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                messageAsString:[NSString stringWithFormat:@"Visibility changed to: %@", visible ? @"true" : @"false"]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)reload:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            [self.embeddedWebView reload];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                messageAsString:@"WebView reloaded"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)goBack:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            if ([self.embeddedWebView canGoBack]) {
                [self.embeddedWebView goBack];
                
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                    messageAsString:@"Navigated back"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:@"Cannot go back"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

- (void)goForward:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.embeddedWebView) {
            if ([self.embeddedWebView canGoForward]) {
                [self.embeddedWebView goForward];
                
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                    messageAsString:@"Navigated forward"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                    messageAsString:@"Cannot go forward"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"WebView not initialized"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    });
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"%@: Page finished loading: %@", TAG, webView.URL.absoluteString);
    
    // Send success callback only once (on initial creation)
    if (self.callbackId) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
            messageAsString:[NSString stringWithFormat:@"WebView created and page loaded: %@", webView.URL.absoluteString]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        self.callbackId = nil; // Clear to avoid multiple callbacks
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%@: Navigation failed: %@", TAG, error.localizedDescription);
    
    if (self.callbackId) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:@"Error loading page: %@", error.localizedDescription]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        self.callbackId = nil;
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%@: Provisional navigation failed: %@", TAG, error.localizedDescription);
    
    if (self.callbackId) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:[NSString stringWithFormat:@"Error loading page: %@", error.localizedDescription]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        self.callbackId = nil;
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction 
                                                      decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *urlString = navigationAction.request.URL.absoluteString;
    NSLog(@"%@: Navigation to: %@", TAG, urlString);
    
    // Check whitelist before allowing navigation
    if ([self isUrlAllowed:urlString]) {
        NSLog(@"%@: Navigation allowed to: %@", TAG, urlString);
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        NSLog(@"%@: Navigation blocked by whitelist: %@", TAG, urlString);
        
        // Notify user via console
        NSString *js = [NSString stringWithFormat:@"console.warn('Navigation blocked: %@');", urlString];
        [webView evaluateJavaScript:js completionHandler:nil];
        
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message 
                                                       initiatedByFrame:(WKFrameInfo *)frame 
                                                      completionHandler:(void (^)(void))completionHandler {
    // Handle JavaScript alerts
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Alert" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message 
                                                          initiatedByFrame:(WKFrameInfo *)frame 
                                                         completionHandler:(void (^)(BOOL))completionHandler {
    // Handle JavaScript confirm dialogs
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Confirm" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" 
                                              style:UIAlertActionStyleCancel 
                                            handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController 
       didReceiveScriptMessage:(WKScriptMessage *)message {
    // Handle messages from JavaScript
    NSLog(@"%@: Received message from WebView: %@", TAG, message.body);
}

#pragma mark - Lifecycle

- (void)dispose {
    if (self.embeddedWebView) {
        [self.embeddedWebView removeFromSuperview];
        [self.embeddedWebView stopLoading];
        self.embeddedWebView.navigationDelegate = nil;
        self.embeddedWebView.UIDelegate = nil;
        self.embeddedWebView = nil;
    }
    [super dispose];
}

@end