package com.cb4rr.cordova.plugin;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.widget.FrameLayout;
import android.graphics.Color;
import android.util.Log;
import android.util.DisplayMetrics;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class EmbeddedWebView extends CordovaPlugin {

    private static final String TAG = "EmbeddedWebView";
    private WebView embeddedWebView;
    private org.apache.cordova.CordovaWebView cordovaWebView;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        this.cordovaWebView = webView;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)
            throws JSONException {

        if (action.equals("create")) {
            String url = args.getString(0);
            JSONObject options = args.getJSONObject(1);
            this.create(url, options, callbackContext);
            return true;
        }

        if (action.equals("destroy")) {
            this.destroy(callbackContext);
            return true;
        }

        if (action.equals("loadUrl")) {
            String url = args.getString(0);
            JSONObject headers = args.optJSONObject(1);
            this.loadUrl(url, headers, callbackContext);
            return true;
        }

        if (action.equals("executeScript")) {
            String script = args.getString(0);
            this.executeScript(script, callbackContext);
            return true;
        }

        if (action.equals("setVisible")) {
            boolean visible = args.getBoolean(0);
            this.setVisible(visible, callbackContext);
            return true;
        }

        if (action.equals("reload")) {
            this.reload(callbackContext);
            return true;
        }

        if (action.equals("goBack")) {
            this.goBack(callbackContext);
            return true;
        }

        if (action.equals("goForward")) {
            this.goForward(callbackContext);
            return true;
        }

        return false;
    }

    @Override
    public boolean onBackPressed() {
        if (embeddedWebView != null && embeddedWebView.canGoBack()) {
            cordova.getActivity().runOnUiThread(() -> {
                embeddedWebView.goBack();
                Log.d(TAG, "Back button intercepted - navigated back in WebView");
            });
            return true;
        }
        return false;
    }

    private void create(final String url, final JSONObject options, final CallbackContext callbackContext) {
        Log.d(TAG, "Creating WebView");

        if (embeddedWebView != null) {
            Log.w(TAG, "WebView already exists, destroying before creating a new one");
            destroy(callbackContext);
        }

        cordova.getActivity().runOnUiThread(() -> {
            try {
                int topOffset = options.optInt("top", 0);
                int bottomOffset = options.optInt("bottom", 0);

                Log.d(TAG, "WebView config - URL: " + url);
                Log.d(TAG, "User offsets - Top: " + topOffset + "px, Bottom: " + bottomOffset + "px");

                ViewGroup decorView = (ViewGroup) cordova.getActivity().getWindow().getDecorView();
                int safeTop = 0;
                int safeBottom = 0;

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    WindowInsets insets = decorView.getRootWindowInsets();
                    if (insets != null) {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                            android.view.DisplayCutout cutout = insets.getDisplayCutout();
                            if (cutout != null) {
                                safeTop = cutout.getSafeInsetTop();
                                safeBottom = cutout.getSafeInsetBottom();
                            }
                        }
                        safeTop = Math.max(safeTop, insets.getSystemWindowInsetTop());
                        safeBottom = Math.max(safeBottom, insets.getSystemWindowInsetBottom());
                    }
                }

                Log.d(TAG, "Safe area insets - Top: " + safeTop + "px, Bottom: " + safeBottom + "px");

                int finalTopMargin = safeTop + topOffset;
                int finalBottomMargin = safeBottom + bottomOffset;

                Log.d(TAG, "Final margins - Top: " + finalTopMargin + "px, Bottom: " + finalBottomMargin + "px");

                embeddedWebView = new WebView(cordova.getActivity());

                WebSettings settings = embeddedWebView.getSettings();
                settings.setJavaScriptEnabled(true);
                settings.setDomStorageEnabled(true);
                settings.setDatabaseEnabled(true);
                settings.setAllowFileAccess(true);
                settings.setAllowContentAccess(true);
                settings.setLoadWithOverviewMode(true);
                settings.setUseWideViewPort(true);

                if (options.optBoolean("enableZoom", false)) {
                    settings.setBuiltInZoomControls(true);
                    settings.setDisplayZoomControls(false);
                }

                if (options.optBoolean("clearCache", false)) {
                    embeddedWebView.clearCache(true);
                }

                if (options.has("userAgent")) {
                    settings.setUserAgentString(options.getString("userAgent"));
                }

                // Performance
                settings.setRenderPriority(WebSettings.RenderPriority.HIGH);
                settings.setCacheMode(WebSettings.LOAD_DEFAULT);
                settings.setEnableSmoothTransition(true);

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
                    embeddedWebView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
                } else {
                    embeddedWebView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
                }

                // Scrollbars
                embeddedWebView.setVerticalScrollBarEnabled(false);
                embeddedWebView.setHorizontalScrollBarEnabled(false);
                embeddedWebView.setScrollbarFadingEnabled(true);
                embeddedWebView.setOverScrollMode(WebView.OVER_SCROLL_NEVER);

                // Smooth scrolling
                embeddedWebView.setWebViewClient(new WebViewClient() {
                    @Override
                    public void onPageFinished(WebView view, String url) {
                        String css = "html, body { scroll-behavior: smooth !important; }";
                        String js = "var style = document.createElement('style');"
                                  + "style.innerHTML = `" + css + "`;"
                                  + "document.head.appendChild(style);";
                        view.evaluateJavascript(js, null);
                    }
                });                
                embeddedWebView.setWebChromeClient(new WebChromeClient());
                embeddedWebView.setBackgroundColor(Color.TRANSPARENT);

                ViewGroup contentView = (ViewGroup) decorView.findViewById(android.R.id.content);

                FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT);

                params.topMargin = finalTopMargin;
                params.bottomMargin = finalBottomMargin;

                contentView.addView(embeddedWebView, params);

                embeddedWebView.bringToFront();

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    embeddedWebView.setElevation(10f);
                    embeddedWebView.setTranslationZ(10f);
                }

                contentView.invalidate();
                contentView.requestLayout();

                if (options.has("headers")) {
                    JSONObject headersJson = options.getJSONObject("headers");
                    Map<String, String> headers = jsonToMap(headersJson);
                    embeddedWebView.loadUrl(url, headers);
                } else {
                    embeddedWebView.loadUrl(url);
                }

                Log.d(TAG, "WebView created successfully");
                callbackContext.success("WebView created successfully");

            } catch (Exception e) {
                Log.e(TAG, "Error creating WebView: " + e.getMessage());
                e.printStackTrace();
                callbackContext.error("Error creating WebView: " + e.getMessage());
            }
        });
    }

    private void destroy(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    ViewGroup parent = (ViewGroup) embeddedWebView.getParent();
                    if (parent != null) {
                        parent.removeView(embeddedWebView);
                    }
                    embeddedWebView.destroy();
                    embeddedWebView = null;
                    Log.d(TAG, "WebView destroyed");
                    callbackContext.success("WebView destroyed");
                } else {
                    callbackContext.error("No WebView to destroy");
                }
            }
        });
    }

    private void loadUrl(final String url, final JSONObject headers,
            final CallbackContext callbackContext) {

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    try {
                        if (headers != null && headers.length() > 0) {
                            Map<String, String> headerMap = jsonToMap(headers);
                            embeddedWebView.loadUrl(url, headerMap);
                        } else {
                            embeddedWebView.loadUrl(url);
                        }
                        callbackContext.success("URL loaded: " + url);
                    } catch (Exception e) {
                        callbackContext.error("Error loading URL: " + e.getMessage());
                    }
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void executeScript(final String script, final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    embeddedWebView.evaluateJavascript(script, new ValueCallback<String>() {
                        @Override
                        public void onReceiveValue(String result) {
                            callbackContext.success(result);
                        }
                    });
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void setVisible(final boolean visible, final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    embeddedWebView.setVisibility(visible ? View.VISIBLE : View.GONE);
                    callbackContext.success("Visibility changed to: " + visible);
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void reload(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    embeddedWebView.reload();
                    callbackContext.success("WebView reloaded");
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void goBack(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    if (embeddedWebView.canGoBack()) {
                        embeddedWebView.goBack();
                        callbackContext.success("Navigated back");
                    } else {
                        callbackContext.error("Cannot go back");
                    }
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void canGoBack(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    boolean canGoBack = embeddedWebView.canGoBack();
                    callbackContext.success(canGoBack ? 1 : 0);
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private void goForward(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (embeddedWebView != null) {
                    if (embeddedWebView.canGoForward()) {
                        embeddedWebView.goForward();
                        callbackContext.success("Navigated forward");
                    } else {
                        callbackContext.error("Cannot go forward");
                    }
                } else {
                    callbackContext.error("WebView not initialized");
                }
            }
        });
    }

    private Map<String, String> jsonToMap(JSONObject json) throws JSONException {
        Map<String, String> map = new HashMap<>();
        Iterator<String> keys = json.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            map.put(key, json.getString(key));
        }
        return map;
    }

    @Override
    public void onDestroy() {
        if (embeddedWebView != null) {
            embeddedWebView.destroy();
            embeddedWebView = null;
        }
        super.onDestroy();
    }

    @Override
    public void onReset() {
        if (embeddedWebView != null) {
            embeddedWebView.destroy();
            embeddedWebView = null;
        }
        super.onReset();
    }
}