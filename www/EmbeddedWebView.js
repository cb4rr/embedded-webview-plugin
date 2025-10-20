var exec = require('cordova/exec');

var EmbeddedWebView = {
    /**
     * Create and show an embedded WebView
     * @param {string} url - URL to load
     * @param {object} options - Additional options
     * @param {object} options.headers - Custom HTTP headers (e.g: Authorization)
     * @param {boolean} options.enableZoom - Enable zoom (default: false)
     * @param {boolean} options.clearCache - Clear cache before loading (default: false)
     * @param {string} options.userAgent - User agent personalizado
     * @param {array} options.whitelist - Array of allowed domains (e.g: ['example.com', '*.google.com'])
     * @param {boolean} options.allowSubdomains - Allow subdomains automatically (default: true)
     * @param {function} successCallback
     * @param {function} errorCallback
     * 
     * @example 
     * EmbeddedWebView.create('https://example.com', {
     *     headers: { 'Authorization': 'Bearer token123' },
     *     whitelist: ['example.com', 'api.example.com', '*.google.com'],
     *     allowSubdomains: true
     * }, function(msg) {
     *     console.log('Success:', msg);
     * }, function(err) {
     *     console.error('Error:', err);
     * });
     */
    create: function (url, options, successCallback, errorCallback) {
        options = options || {};

        // Validations
        if (!url || typeof url !== 'string') {
            errorCallback && errorCallback('url must be a non-empty string');
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
            [url, options]
        );
    },

    /**
     * Configure the whitelist of allowed domains
     * @param {array} domains - Array of allowed domains
     * @param {boolean} allowSubdomains - Allow subdomains automatically (default: true)
     * @param {function} successCallback
     * @param {function} errorCallback
     * 
     * @example
     * EmbeddedWebView.setWhitelist(
     *     ['example.com', '*.google.com', 'api.myapp.com'],
     *     true,
     *     function() { console.log('Whitelist configured'); },
     *     function(err) { console.error(err); }
     * );
     */
    setWhitelist: function (domains, allowSubdomains, successCallback, errorCallback) {
        if (!Array.isArray(domains)) {
            errorCallback && errorCallback('domains must be an array');
            return;
        }

        // Allow calling without allowSubdomains
        if (typeof allowSubdomains === 'function') {
            errorCallback = successCallback;
            successCallback = allowSubdomains;
            allowSubdomains = true;
        }

        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'setWhitelist',
            [domains, allowSubdomains !== false]
        );
    },

    /**
     * Clear the whitelist (allow all domains)
     * @param {function} successCallback
     * @param {function} errorCallback
     */
    clearWhitelist: function (successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'clearWhitelist',
            []
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