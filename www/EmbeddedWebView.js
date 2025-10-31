let exec = require('cordova/exec');

let EmbeddedWebView = {
    /**
     * Create and show an embedded WebView
     * @param {string} url - URL to load
     * @param {object} options - Layout and configuration options
     * @param {number} options.top - Top offset in pixels (distance from top of screen)
     * @param {number} options.height - Height in pixels (visible area for the WebView)
     * @param {object} [options.headers] - Optional custom HTTP headers
     * @param {object} [options.progressColor] - Optional progress bar color
     * @param {object} [options.progressHeight] - Optional progress bar height
     * @param {boolean} [options.enableZoom=false] - Enable zoom controls
     * @param {boolean} [options.clearCache=false] - Clear cache before loading
     * @param {string} [options.userAgent] - Custom User-Agent string
     * @param {function} [successCallback]
     * @param {function} [errorCallback]
     * 
     * @example
     * const nav = document.querySelector('.navbar');
     * const bottom = document.querySelector('.bottom-bar');
     * const topOffset = nav.offsetHeight;
     * const availableHeight = window.innerHeight - (nav.offsetHeight + bottom.offsetHeight);
     * 
     * EmbeddedWebView.create('https://example.com', {
     *     top: topOffset,
     *     height: availableHeight,
     *     headers: { Authorization: 'Bearer token123' },
     *     progressColor: '#2196F3',
     *     progressHeight: 5,
     * }, msg => console.log('Success:', msg), err => console.error('Error:', err));
     */
    create: function (url, options, successCallback, errorCallback) {
        options = options || {};

        // Validations
        if (!url || typeof url !== 'string') {
            errorCallback && errorCallback('URL must be a non-empty string');
            return;
        }

        if (typeof options.top !== 'number') {
            options.top = 0;
        }

        if (typeof options.height !== 'number') {
            options.height = window.innerHeight;
        }

        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'create',
            [url, options]
        );
    },

    /** Destroy the embedded WebView */
    destroy: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'EmbeddedWebView', 'destroy', []);
    },

    /** Navigate to a new URL in the WebView */
    loadUrl: function (url, headers, successCallback, errorCallback) {
        if (typeof headers === 'function') {
            errorCallback = successCallback;
            successCallback = headers;
            headers = null;
        }

        exec(successCallback, errorCallback, 'EmbeddedWebView', 'loadUrl', [url, headers]);
    },

    /** Execute JavaScript in the embedded WebView */
    executeScript: function (script, successCallback, errorCallback) {
        if (!script || typeof script !== 'string') {
            errorCallback && errorCallback('script must be a non-empty string');
            return;
        }

        exec(successCallback, errorCallback, 'EmbeddedWebView', 'executeScript', [script]);
    },

    /** Show or hide the WebView */
    setVisible: function (visible, successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'EmbeddedWebView', 'setVisible', [!!visible]);
    },

    /** Reload the WebView */
    reload: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'EmbeddedWebView', 'reload', []);
    },

    /** Go back in history */
    goBack: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'EmbeddedWebView', 'goBack', []);
    },

    /** Go forward in history */
    goForward: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'EmbeddedWebView', 'goForward', []);
    },

    /** Helper: Inject authentication token */
    injectAuthToken: function (token, storageType, key, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        key = key || 'authToken';
        let script = `${storageType}.setItem('${key}', '${token}');`;
        this.executeScript(script, successCallback, errorCallback);
    },

    /** Helper: Get a storage value */
    getStorageValue: function (key, storageType, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        let script = `${storageType}.getItem('${key}');`;
        this.executeScript(script, successCallback, errorCallback);
    },

    /**
     * Add event listener for WebView events
     * @param {string} eventName - Event name (loadStart, loadStop, loadError, navigationStateChanged, canGoBackChanged, canGoForwardChanged)
     * @param {function} callback - Callback function
     * 
     * @example
     * // Listen for navigation state changes
     * EmbeddedWebView.addEventListener('navigationStateChanged', function(event) {
     *     console.log('Can go back:', event.detail.canGoBack);
     *     console.log('Can go forward:', event.detail.canGoForward);
     * });
     * 
     * // Listen when page starts loading
     * EmbeddedWebView.addEventListener('loadStart', function(event) {
     *     console.log('Started loading:', event.detail);
     * });
     * 
     * // Listen when page finishes loading
     * EmbeddedWebView.addEventListener('loadStop', function(event) {
     *     console.log('Finished loading:', event.detail);
     * });
     * 
     * // Listen for load errors
     * EmbeddedWebView.addEventListener('loadError', function(event) {
     *     console.error('Error loading:', event.detail);
     * });
     * 
     * // Listen for back button availability changes
     * EmbeddedWebView.addEventListener('canGoBackChanged', function(event) {
     *     let canGoBack = event.detail === 'true';
     *     console.log('Can go back:', canGoBack);
     *     // Update UI button state
     * });
     * 
     * // Listen for forward button availability changes
     * EmbeddedWebView.addEventListener('canGoForwardChanged', function(event) {
     *     let canGoForward = event.detail === 'true';
     *     console.log('Can go forward:', canGoForward);
     *     // Update UI button state
     * });
     */
    addEventListener: function (eventName, callback) {
        if (typeof callback !== 'function') {
            console.error('Callback must be a function');
            return;
        }

        let eventFullName = 'embeddedwebview.' + eventName;
        document.addEventListener(eventFullName, callback, false);
    },

    /**
     * Remove event listener
     * @param {string} eventName - Event name
     * @param {function} callback - Callback function to remove
     */
    removeEventListener: function (eventName, callback) {
        let eventFullName = 'embeddedwebview.' + eventName;
        document.removeEventListener(eventFullName, callback, false);
    }
};

module.exports = EmbeddedWebView;
