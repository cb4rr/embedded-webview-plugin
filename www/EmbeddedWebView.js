var exec = require('cordova/exec');

var EmbeddedWebView = {
    /**
     * Create and show an embedded WebView
     * @param {string} containerId - ID of the container element (default: 'webview-container')
     * @param {string} url - URL to load
     * @param {object} options - Additional options
     * @param {object} options.headers - Custom HTTP headers (e.g: Authorization)
     * @param {boolean} options.enableZoom - Enable zoom (default: false)
     * @param {boolean} options.clearCache - Clear cache before loading (default: false)
     * @param {string} options.userAgent - User agent personalizado
     * @param {function} successCallback
     * @param {function} errorCallback
     * 
     * @example 
     * EmbeddedWebView.create('webview-container', 'https://example.com', {
     *     headers: { 'Authorization': 'Bearer token123' },
     * }, function(msg) {
     *     console.log('Success:', msg);
     * }, function(err) {
     *     console.error('Error:', err);
     * });
     */
    create: function (containerId, url, options, successCallback, errorCallback) {
        options = options || {};

        // Validations
        if (!containerId || typeof containerId !== 'string') {
            errorCallback && errorCallback('containerId must be a non-empty string');
            return;
        }

        if (!url || typeof url !== 'string') {
            errorCallback && errorCallback('url must be a non-empty string');
            return;
        }

        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'create',
            [containerId, url, options]
        );
    },

    /**
     * Destroy the embedded WebView and release resources
     */
    destroy: function (successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'destroy',
            []
        );
    },

    /**
     * Navigate to a new URL in the embedded WebView
     */
    loadUrl: function (url, headers, successCallback, errorCallback) {
        if (typeof headers === 'function') {
            errorCallback = successCallback;
            successCallback = headers;
            headers = null;
        }

        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'loadUrl',
            [url, headers]
        );
    },

    /**
     * Execute JavaScript in the embedded WebView context
     */
    executeScript: function (script, successCallback, errorCallback) {
        if (!script || typeof script !== 'string') {
            errorCallback && errorCallback('script must be a non-empty string');
            return;
        }

        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'executeScript',
            [script]
        );
    },

    /**
     * Show or hide the embedded WebView
     */
    setVisible: function (visible, successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'setVisible',
            [!!visible]
        );
    },

    /**
     * Reload the current page of the WebView
     */
    reload: function (successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'reload',
            []
        );
    },

    /**
     * Navigate back in the WebView history
     */
    goBack: function (successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'goBack',
            []
        );
    },

    /**
     * Navigate forward in the WebView history
     */
    goForward: function (successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'goForward',
            []
        );
    },

    /**
     * Helper: Inject an authentication token into the WebView
     */
    injectAuthToken: function (token, storageType, key, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        key = key || 'authToken';
        var script = storageType + ".setItem('" + key + "', '" + token + "');";
        this.executeScript(script, successCallback, errorCallback);
    },

    /**
     * Helper: Get a value from the WebView storage
     */
    getStorageValue: function (key, storageType, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        var script = storageType + ".getItem('" + key + "');";
        this.executeScript(script, successCallback, errorCallback);
    }
};

module.exports = EmbeddedWebView;