#import <Cordova/CDVPlugin.h>
#import <WebKit/WebKit.h>

@interface EmbeddedWebView : CDVPlugin <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *embeddedWebView;
@property (nonatomic, strong) NSString *currentContainerId;
@property (nonatomic, strong) NSString *callbackId;
@property (nonatomic, strong) NSMutableArray<NSString *> *whitelist;
@property (nonatomic, assign) BOOL allowSubdomains;
@property (nonatomic, assign) BOOL whitelistEnabled;

- (void)create:(CDVInvokedUrlCommand*)command;
- (void)destroy:(CDVInvokedUrlCommand*)command;
- (void)loadUrl:(CDVInvokedUrlCommand*)command;
- (void)executeScript:(CDVInvokedUrlCommand*)command;
- (void)setVisible:(CDVInvokedUrlCommand*)command;
- (void)reload:(CDVInvokedUrlCommand*)command;
- (void)goBack:(CDVInvokedUrlCommand*)command;
- (void)goForward:(CDVInvokedUrlCommand*)command;
- (void)setWhitelist:(CDVInvokedUrlCommand*)command;
- (void)clearWhitelist:(CDVInvokedUrlCommand*)command;
- (BOOL)isUrlAllowed:(NSString *)urlString;

@end