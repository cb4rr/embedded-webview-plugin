var exec = require('cordova/exec');

var EmbeddedWebView = {
    /**
     * Crea y muestra un WebView embebido
     * @param {string} containerId - ID del div contenedor en el HTML
     * @param {string} url - URL a cargar
     * @param {object} options - Opciones adicionales
     * @param {object} options.headers - Headers HTTP personalizados (ej: Authorization)
     * @param {boolean} options.enableZoom - Habilitar zoom (default: false)
     * @param {boolean} options.clearCache - Limpiar cache antes de cargar (default: false)
     * @param {string} options.userAgent - User agent personalizado
     * @param {array} options.whitelist - Array de dominios permitidos (ej: ['example.com', '*.google.com'])
     * @param {boolean} options.allowSubdomains - Permitir subdominios automáticamente (default: true)
     * @param {function} successCallback
     * @param {function} errorCallback
     * 
     * @example
     * EmbeddedWebView.create('my-container', 'https://example.com', {
     *     headers: { 'Authorization': 'Bearer token123' },
     *     whitelist: ['example.com', 'api.example.com', '*.google.com'],
     *     allowSubdomains: true
     * }, function(msg) {
     *     console.log('Success:', msg);
     * }, function(err) {
     *     console.error('Error:', err);
     * });
     */
    create: function (containerId, url, options, successCallback, errorCallback) {
        options = options || {};

        // Validaciones
        if (!containerId || typeof containerId !== 'string') {
            errorCallback && errorCallback('containerId must be a non-empty string');
            return;
        }

        if (!url || typeof url !== 'string') {
            errorCallback && errorCallback('url must be a non-empty string');
            return;
        }

        // Verificar que el contenedor existe
        var container = document.getElementById(containerId);
        if (!container) {
            errorCallback && errorCallback('Container element not found: ' + containerId);
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
     * Configura la whitelist de dominios permitidos
     * @param {array} domains - Array de dominios permitidos
     * @param {boolean} allowSubdomains - Permitir subdominios (default: true)
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

        // Permitir llamar sin allowSubdomains
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
     * Limpia la whitelist (permite todos los dominios)
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
     * Destruye el WebView embebido y libera recursos
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
     * Navega a una nueva URL en el WebView embebido
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
     * Ejecuta JavaScript en el contexto del WebView embebido
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
     * Muestra u oculta el WebView embebido
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
     * Recarga la página actual del WebView
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
     * Navega hacia atrás en el historial del WebView
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
     * Navega hacia adelante en el historial del WebView
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
     * Actualiza la posición y tamaño del WebView embebido
     */
    updatePosition: function (x, y, width, height, successCallback, errorCallback) {
        exec(
            successCallback,
            errorCallback,
            'EmbeddedWebView',
            'updatePosition',
            [x, y, width, height]
        );
    },

    /**
     * Helper: Configura un listener para redimensionar automáticamente
     */
    setupAutoResize: function (containerId) {
        var container = document.getElementById(containerId);
        if (!container) {
            console.error('Container not found for auto-resize:', containerId);
            return;
        }

        if (typeof ResizeObserver !== 'undefined') {
            var observer = new ResizeObserver(function (entries) {
                var rect = entries[0].target.getBoundingClientRect();
                EmbeddedWebView.updatePosition(
                    rect.left,
                    rect.top,
                    rect.width,
                    rect.height,
                    function () { console.log('WebView resized'); },
                    function (err) { console.error('Resize error:', err); }
                );
            });
            observer.observe(container);
            this._resizeObserver = observer;
        } else {
            var resizeHandler = function () {
                var rect = container.getBoundingClientRect();
                EmbeddedWebView.updatePosition(
                    rect.left,
                    rect.top,
                    rect.width,
                    rect.height
                );
            };
            window.addEventListener('resize', resizeHandler);
            this._resizeHandler = resizeHandler;
        }
    },

    /**
     * Detiene el auto-resize configurado con setupAutoResize()
     */
    stopAutoResize: function () {
        if (this._resizeObserver) {
            this._resizeObserver.disconnect();
            this._resizeObserver = null;
        }
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
            this._resizeHandler = null;
        }
    },

    /**
     * Helper: Inyecta un token de autenticación en el WebView
     */
    injectAuthToken: function (token, storageType, key, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        key = key || 'authToken';
        var script = storageType + ".setItem('" + key + "', '" + token + "');";
        this.executeScript(script, successCallback, errorCallback);
    },

    /**
     * Helper: Obtiene un valor del storage del WebView
     */
    getStorageValue: function (key, storageType, successCallback, errorCallback) {
        storageType = storageType || 'localStorage';
        var script = storageType + ".getItem('" + key + "');";
        this.executeScript(script, successCallback, errorCallback);
    }
};

module.exports = EmbeddedWebView;