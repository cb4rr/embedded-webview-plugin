package com.cb4rr.cordova.plugin;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
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
import android.widget.FrameLayout;
import android.graphics.Color;
import android.util.Log;
import android.net.Uri;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public class EmbeddedWebView extends CordovaPlugin {

    private static final String TAG = "EmbeddedWebView";
    private WebView embeddedWebView;
    private String currentContainerId;
    private List<String> whitelist = new ArrayList<>();
    private boolean allowSubdomains = true;
    private boolean whitelistEnabled = false;

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

    private void create(final String containerId, final String url,
            final JSONObject options, final CallbackContext callbackContext) {

        Log.d(TAG, "Creating WebView for container: " + containerId);
        currentContainerId = containerId;

        try {
            if (options.has("whitelist")) {
                JSONArray whitelistArray = options.getJSONArray("whitelist");
                boolean allowSubs = options.optBoolean("allowSubdomains", true);
                whitelist.clear();
                for (int i = 0; i < whitelistArray.length(); i++) {
                    whitelist.add(whitelistArray.getString(i).toLowerCase());
                }
                allowSubdomains = allowSubs;
                whitelistEnabled = true;
                Log.d(TAG, "Whitelist configured from options: " + whitelist.size() + " domains");
            }
        } catch (JSONException e) {
            Log.w(TAG, "Error reading whitelist from options: " + e.getMessage());
        }

        if (!isUrlAllowed(url)) {
            callbackContext.error("URL not allowed by whitelist: " + url);
            return;
        }

        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    createNativeWebView(url, options, callbackContext);

                } catch (JSONException e) {
                    Log.e(TAG, "Error creating WebView: " + e.getMessage());
                    callbackContext.error("Error creating WebView: " + e.getMessage());
                }
            }
        });
    }

    private void createNativeWebView(
            final String url, final JSONObject options,
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
                                view.evaluateJavascript(
                                        "console.warn('Navigation blocked: " + url + "');",
                                        null);
                                return true;
                            }
                        }
                    });

                    embeddedWebView.setWebChromeClient(new WebChromeClient() {
                        @Override
                        public boolean onConsoleMessage(android.webkit.ConsoleMessage consoleMessage) {
                            Log.d(TAG, "WebView Console: " + consoleMessage.message());
                            return true;
                        }
                    });

                    embeddedWebView.setBackgroundColor(Color.TRANSPARENT);

                    ViewGroup rootView = (ViewGroup) webView.getParent();

                    ViewGroup containerView = findContainerView(rootView, currentContainerId);

                    if (containerView == null) {
                        containerView = new FrameLayout(cordova.getActivity());
                        containerView.setId(View.generateViewId());
                        containerView.setTag(currentContainerId);

                        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                                ViewGroup.LayoutParams.MATCH_PARENT,
                                ViewGroup.LayoutParams.MATCH_PARENT));

                        rootView.addView(containerView);
                    }

                    containerView.addView(embeddedWebView, new FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT));
                    try {
                        if (options.has("headers")) {
                            JSONObject headersJson = options.getJSONObject("headers");
                            Map<String, String> headers = jsonToMap(headersJson);
                            embeddedWebView.loadUrl(url, headers);
                        } else {
                            embeddedWebView.loadUrl(url);
                        }
                    } catch (JSONException e) {
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
                    currentContainerId = null;
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

        if (!isUrlAllowed(url)) {
            callbackContext.error("URL not allowed by whitelist: " + url);
            return;
        }

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

    /**
     * Search recursively for a ViewGroup that matches the containerId.
     */
    private ViewGroup findContainerView(ViewGroup root, String containerId) {
        if (root == null)
            return null;

        Object tag = root.getTag();
        if (tag != null && tag.equals(containerId)) {
            return root;
        }

        for (int i = 0; i < root.getChildCount(); i++) {
            View child = root.getChildAt(i);
            if (child instanceof ViewGroup) {
                ViewGroup found = findContainerView((ViewGroup) child, containerId);
                if (found != null)
                    return found;
            }
        }
        return null;
    }
}