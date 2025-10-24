#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>

@interface EmbeddedWebView : CDVPlugin

@property (nonatomic, strong) WKWebView *embeddedWebView;

- (void)create:(CDVInvokedUrlCommand*)command;
- (void)destroy:(CDVInvokedUrlCommand*)command;
- (void)loadUrl:(CDVInvokedUrlCommand*)command;
- (void)executeScript:(CDVInvokedUrlCommand*)command;
- (void)setVisible:(CDVInvokedUrlCommand*)command;
- (void)reload:(CDVInvokedUrlCommand*)command;
- (void)goBack:(CDVInvokedUrlCommand*)command;
- (void)goForward:(CDVInvokedUrlCommand*)command;

@end