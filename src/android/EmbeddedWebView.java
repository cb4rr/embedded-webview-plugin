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
import android.view.ViewTreeObserver;
import android.widget.FrameLayout;
import android.graphics.Color;
import android.util.Log;
import android.net.Uri;
import android.content.res.Configuration;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class EmbeddedWebView extends CordovaPlugin {

    private static final String TAG = "EmbeddedWebView";
    private WebView embeddedWebView;
    private List<String> whitelist = new ArrayList<>();
    private boolean allowSubdomains = true;
    private boolean whitelistEnabled = false;
    private org.apache.cordova.CordovaWebView cordovaWebView;

    private String containerIdentifier;
    private ViewTreeObserver.OnGlobalLayoutListener layoutListener;
    private boolean autoResizeEnabled = false;
    private int lastOrientation = -1;
    private Runnable orientationCheckRunnable;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        this.cordovaWebView = webView;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)
            throws JSONException {

        if (action.equals("create")) {
            String containerId = args.getString(0);
            String url = args.getString(1);
            JSONObject options = args.getJSONObject(2);
            this.create(containerId, url, options, callbackContext);
            return true;
        }

        if (action.equals("setWhitelist")) {
            JSONArray domains = args.getJSONArray(0);
            boolean allowSubs = args.getBoolean(1);
            this.setWhitelist(domains, allowSubs, callbackContext);
            return true;
        }

        if (action.equals("clearWhitelist")) {
            this.clearWhitelist(callbackContext);
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

    private void setWhitelist(JSONArray domains, boolean allowSubs, CallbackContext callbackContext) {
        try {
            whitelist.clear();
            for (int i = 0; i < domains.length(); i++) {
                String domain = domains.getString(i);
                whitelist.add(domain.toLowerCase());
            }
            allowSubdomains = allowSubs;
            whitelistEnabled = true;
            Log.d(TAG, "Whitelist configured with " + whitelist.size() + " domains");
            callbackContext.success("Whitelist configured with " + whitelist.size() + " domains");
        } catch (JSONException e) {
            callbackContext.error("Error configuring whitelist: " + e.getMessage());
        }
    }

    private void clearWhitelist(CallbackContext callbackContext) {
        whitelist.clear();
        whitelistEnabled = false;
        Log.d(TAG, "Whitelist cleared");
        callbackContext.success("Whitelist cleared");
    }

    private boolean isUrlAllowed(String url) {
        if (!whitelistEnabled || whitelist.isEmpty()) {
            return true;
        }

        try {
            Uri uri = Uri.parse(url);
            String host = uri.getHost();
            if (host == null) {
                return false;
            }

            host = host.toLowerCase();
            Log.d(TAG, "Checking URL: " + url + " (host: " + host + ")");

            for (String allowedDomain : whitelist) {
                if (allowedDomain.startsWith("*.")) {
                    String baseDomain = allowedDomain.substring(2);
                    if (host.equals(baseDomain) || host.endsWith("." + baseDomain)) {
                        Log.d(TAG, "URL allowed by wildcard: " + allowedDomain);
                        return true;
                    }
                } else if (host.equals(allowedDomain)) {
                    Log.d(TAG, "URL allowed by exact match: " + allowedDomain);
                    return true;
                } else if (allowSubdomains && host.endsWith("." + allowedDomain)) {
                    Log.d(TAG, "URL allowed by subdomain: " + allowedDomain);
                    return true;
                }
            }

            Log.w(TAG, "URL blocked by whitelist: " + url);
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Error parsing URL: " + e.getMessage());
            return false;
        }
    }

    private void create(final String containerId, final String url, final JSONObject options,
            final CallbackContext callbackContext) {
        Log.d(TAG, "Creating WebView");

        if (embeddedWebView != null) {
            Log.w(TAG, "WebView already exists, destroying before creating a new one");
            destroy(callbackContext);
        }

        try {
            if (options.has("whitelist")) {
                Object whitelistObj = options.get("whitelist");

                if (whitelistObj instanceof JSONArray) {
                    JSONArray whitelistArray = (JSONArray) whitelistObj;
                    boolean allowSubs = options.optBoolean("allowSubdomains", true);
                    whitelist.clear();
                    for (int i = 0; i < whitelistArray.length(); i++) {
                        whitelist.add(whitelistArray.getString(i).toLowerCase());
                    }
                    allowSubdomains = allowSubs;
                    whitelistEnabled = true;
                    Log.d(TAG, "Whitelist configured from options: " + whitelist.size() + " domains");
                } else if (whitelistObj instanceof String) {
                    String whitelistStr = (String) whitelistObj;
                    Log.w(TAG, "Whitelist received as string, attempting to parse: " + whitelistStr);

                    if (whitelistStr.trim().isEmpty()) {
                        Log.d(TAG, "Empty whitelist string, disabling whitelist");
                        whitelistEnabled = false;
                        whitelist.clear();
                    }

                    try {
                        JSONArray whitelistArray = new JSONArray(whitelistStr);
                        whitelist.clear();
                        for (int i = 0; i < whitelistArray.length(); i++) {
                            whitelist.add(whitelistArray.getString(i).toLowerCase());
                        }
                        boolean allowSubs = options.optBoolean("allowSubdomains", true);
                        allowSubdomains = allowSubs;
                        whitelistEnabled = true;
                        Log.d(TAG, "Whitelist parsed from string: " + whitelist.size() + " domains");
                    } catch (JSONException parseError) {
                        Log.w(TAG, "Could not parse whitelist string as JSON, treating as single domain");
                        whitelist.clear();
                        whitelist.add(whitelistStr.toLowerCase());
                        whitelistEnabled = true;
                    }
                } else {
                    Log.w(TAG, "Whitelist has unexpected type: " + whitelistObj.getClass().getName());
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Error reading options: " + e.getMessage());
            e.printStackTrace();
        }

        autoResizeEnabled = options.optBoolean("autoResize", true);

        containerIdentifier = containerId;

        //if (!isUrlAllowed(url)) {
        //    callbackContext.error("URL not allowed by whitelist: " + url);
        //    return;
        //}

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                String script = "(function() {" +
                        "  var container = document.getElementById('" + containerIdentifier + "');" +
                        "  if (container) {" +
                        "    var rect = container.getBoundingClientRect();" +
                        "    return JSON.stringify({" +
                        "      x: rect.left," +
                        "      y: rect.top," +
                        "      width: rect.width," +
                        "      height: rect.height" +
                        "    });" +
                        "  }" +
                        "  return null;" +
                        "})()";

                View view = cordovaWebView.getView();
                WebView systemWebView = null;

                if (view instanceof WebView) {
                    systemWebView = (WebView) view;
                } else if (view instanceof ViewGroup) {
                    ViewGroup group = (ViewGroup) view;
                    for (int i = 0; i < group.getChildCount(); i++) {
                        View child = group.getChildAt(i);
                        if (child instanceof WebView) {
                            systemWebView = (WebView) child;
                            break;
                        }
                    }
                }

                if (systemWebView == null) {
                    Log.e(TAG, "WebView not found to execute script");
                    callbackContext.error("Cannot access main WebView");
                    return;
                }

                systemWebView.evaluateJavascript(script, new ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String result) {
                        try {
                            if (result == null || result.equals("null")) {
                                Log.w(TAG, "Container not found: " + containerIdentifier);
                                return;
                            }

                            result = result.trim();
                            if (result.startsWith("\"") && result.endsWith("\"")) {
                                result = result.substring(1, result.length() - 1);
                            }
                            result = result.replace("\\\"", "\"");

                            JSONObject bounds = new JSONObject(result);

                            int x = bounds.getInt("x");
                            int y = bounds.getInt("y");
                            int width = bounds.getInt("width");
                            int height = bounds.getInt("height");

                            Log.d(TAG, "Updating WebView bounds: " + bounds.toString());
                            createNativeWebView(url, options, x, y, width, height, callbackContext);
                        } catch (Exception e) {
                            Log.e(TAG, "Error updating WebView position: " + e.getMessage());
                        }
                    }

                });
            }
        });
    }

    private void createNativeWebView(final String url, final JSONObject options,
            final int x, final int y, final int width, final int height,
            final CallbackContext callbackContext) {

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    embeddedWebView = new WebView(cordova.getActivity());

                    WebSettings settings = embeddedWebView.getSettings();
                    settings.setJavaScriptEnabled(true);
                    settings.setDomStorageEnabled(true);
                    settings.setDatabaseEnabled(true);
                    settings.setAllowFileAccess(true);
                    settings.setAllowContentAccess(true);
                    settings.setLoadWithOverviewMode(true);
                    settings.setUseWideViewPort(true);
                    settings.setBuiltInZoomControls(false);
                    settings.setDisplayZoomControls(false);

                    try {
                        if (options.has("enableZoom")) {
                            boolean enableZoom = options.getBoolean("enableZoom");
                            settings.setBuiltInZoomControls(enableZoom);
                            settings.setDisplayZoomControls(enableZoom);
                        }

                        if (options.has("clearCache") && options.getBoolean("clearCache")) {
                            embeddedWebView.clearCache(true);
                        }

                        if (options.has("userAgent")) {
                            settings.setUserAgentString(options.getString("userAgent"));
                        }
                    } catch (JSONException e) {
                        Log.w(TAG, "Error applying options: " + e.getMessage());
                    }

                    embeddedWebView.setWebViewClient(new WebViewClient() {
                        @Override
                        public void onPageFinished(WebView view, String url) {
                            Log.d(TAG, "Page loaded: " + url);
                        }

                        @Override
                        public void onReceivedError(WebView view, int errorCode,
                                String description, String failingUrl) {
                            Log.e(TAG, "Error loading page: " + description);
                        }

                        @Override
                        public boolean shouldOverrideUrlLoading(WebView view, String url) {
                            if (isUrlAllowed(url)) {
                                view.loadUrl(url);
                                Log.d(TAG, "Navigation allowed to: " + url);
                                return true;
                            } else {
                                Log.w(TAG, "Navigation blocked by whitelist: " + url);
                                return true;
                            }
                        }
                    });

                    embeddedWebView.setWebChromeClient(new WebChromeClient() {
                        @Override
                        public boolean onConsoleMessage(android.webkit.ConsoleMessage consoleMessage) {
                            Log.d(TAG, "Embedded WebView Console: " + consoleMessage.message());
                            return true;
                        }
                    });

                    embeddedWebView.setBackgroundColor(Color.WHITE);

                    positionWebView(x, y, width, height);

                    if (autoResizeEnabled) {
                        setupAutoResize();
                    }
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
            }
        });
    }

    private void positionWebView(int x, int y, int width, int height) {
        ViewGroup rootView = (ViewGroup) cordova.getActivity()
                .findViewById(android.R.id.content);

        if (embeddedWebView == null) {
            Log.w(TAG, "positionWebView called but embeddedWebView is null");
            return;
        }

        float density = cordova.getActivity().getResources().getDisplayMetrics().density;
        int deviceX = Math.round(x * density);
        int deviceY = Math.round(y * density);
        int deviceWidth = Math.round(width * density);
        int deviceHeight = Math.round(height * density);

        Log.d(TAG, String.format("Positioning WebView - CSS: [%d,%d,%d,%d] Device: [%d,%d,%d,%d]",
                x, y, width, height, deviceX, deviceY, deviceWidth, deviceHeight));

        if (embeddedWebView.getParent() != null) {
            FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) embeddedWebView.getLayoutParams();
            params.width = deviceWidth;
            params.height = deviceHeight;
            params.leftMargin = deviceX;
            params.topMargin = deviceY;
            embeddedWebView.setLayoutParams(params);
            embeddedWebView.requestLayout();
        } else {
            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                    deviceWidth, deviceHeight);
            params.leftMargin = deviceX;
            params.topMargin = deviceY;

            rootView.addView(embeddedWebView, params);
        }
    }

    private void setupAutoResize() {
        Log.d(TAG, "Setting up auto-resize listener");

        if (layoutListener != null) {
            View rootView = cordova.getActivity().findViewById(android.R.id.content);
            rootView.getViewTreeObserver().removeOnGlobalLayoutListener(layoutListener);
        }

        layoutListener = new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                updateWebViewPosition();
            }
        };

        View rootView = cordova.getActivity().findViewById(android.R.id.content);
        rootView.getViewTreeObserver().addOnGlobalLayoutListener(layoutListener);
    }

    private void updateWebViewPosition() {
        if (embeddedWebView == null || cordovaWebView == null) {
            return;
        }

        String script = "(function() {" +
                "  var container = document.getElementById('" + containerIdentifier + "');" +
                "  if (container) {" +
                "    var rect = container.getBoundingClientRect();" +
                "    return JSON.stringify({" +
                "      x: rect.left," +
                "      y: rect.top," +
                "      width: rect.width," +
                "      height: rect.height" +
                "    });" +
                "  }" +
                "  return null;" +
                "})()";

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                View view = cordovaWebView.getView();
                WebView systemWebView = null;

                if (view instanceof WebView) {
                    systemWebView = (WebView) view;
                } else if (view instanceof ViewGroup) {
                    ViewGroup group = (ViewGroup) view;
                    for (int i = 0; i < group.getChildCount(); i++) {
                        View child = group.getChildAt(i);
                        if (child instanceof WebView) {
                            systemWebView = (WebView) child;
                            break;
                        }
                    }
                }

                if (systemWebView == null) {
                    Log.e(TAG, "WebView not found to execute script");
                    return;
                }

                systemWebView.evaluateJavascript(script, new ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String result) {
                        try {
                            if (result == null || result.equals("null")) {
                                Log.w(TAG, "Container not found: " + containerIdentifier);
                                return;
                            }

                            result = result.trim();
                            if (result.startsWith("\"") && result.endsWith("\"")) {
                                result = result.substring(1, result.length() - 1);
                            }
                            result = result.replace("\\\"", "\"");

                            JSONObject bounds = new JSONObject(result);

                            int x = bounds.getInt("x");
                            int y = bounds.getInt("y");
                            int width = bounds.getInt("width");
                            int height = bounds.getInt("height");

                            Log.d(TAG, "Updating WebView bounds: " + bounds.toString());
                            positionWebView(x, y, width, height);
                        } catch (Exception e) {
                            Log.e(TAG, "Error updating WebView position: " + e.getMessage());
                        }
                    }
                });

            }
        });

    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        Log.d(TAG, "Configuration changed (rotation/resize)");

        if (embeddedWebView != null && autoResizeEnabled) {
            embeddedWebView.postDelayed(new Runnable() {
                @Override
                public void run() {
                    updateWebViewPosition();
                }
            }, 100);
        }
    }

    private void destroy(final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (layoutListener != null) {
                    View rootView = cordova.getActivity().findViewById(android.R.id.content);
                    if (rootView != null) {
                        rootView.getViewTreeObserver().removeOnGlobalLayoutListener(layoutListener);
                    }
                    layoutListener = null;
                }

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

        //if (!isUrlAllowed(url)) {
        //    callbackContext.error("URL not allowed by whitelist: " + url);
        //    return;
        //}

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
        if (layoutListener != null) {
            View rootView = cordova.getActivity().findViewById(android.R.id.content);
            if (rootView != null) {
                rootView.getViewTreeObserver().removeOnGlobalLayoutListener(layoutListener);
            }
        }
        if (embeddedWebView != null) {
            embeddedWebView.destroy();
            embeddedWebView = null;
        }
        super.onDestroy();
    }

    @Override
    public void onReset() {
        if (layoutListener != null) {
            View rootView = cordova.getActivity().findViewById(android.R.id.content);
            if (rootView != null) {
                rootView.getViewTreeObserver().removeOnGlobalLayoutListener(layoutListener);
            }
        }
        if (embeddedWebView != null) {
            embeddedWebView.destroy();
            embeddedWebView = null;
        }
        super.onReset();
    }
}