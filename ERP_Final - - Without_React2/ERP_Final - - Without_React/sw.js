// Service Worker for caching and offline support
// Updated for modular architecture and user data persistence
const CACHE_VERSION = 'v2.0.0';
const CACHE_NAME = `sakura-portal-${CACHE_VERSION}`;

// Assets to cache on install
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/js/config.js',
    '/js/i18n.js',
    '/js/user-data.js',
    '/js/dashboard-loader.js',
    '/css/core.css',
    '/unified-styles.css',
    '/sakura-accounts-payable-dashboard/payable.html',
    '/sakura-accounts-payable-dashboard/forecasting.html',
    '/sakura-accounts-payable-dashboard/Warehouse.html',
    '/quality-traceability/quality-dashboard.html',
    '/ADVANCED_ERP_JS_FEATURES.js',
    'https://cdn.tailwindcss.com',
    'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker...');
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[SW] Caching static assets');
                return cache.addAll(STATIC_ASSETS.map(url => {
                    try {
                        return new Request(url, { mode: 'no-cors' });
                    } catch (e) {
                        return url;
                    }
                }));
            })
            .catch((err) => {
                console.error('[SW] Cache failed:', err);
            })
    );
    self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('[SW] Activating service worker...');
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames
                    .filter((name) => name !== CACHE_NAME)
                    .map((name) => {
                        console.log('[SW] Deleting old cache:', name);
                        return caches.delete(name);
                    })
            );
        })
    );
    return self.clients.claim();
});

// Fetch event - serve from cache, fallback to network
// Strategy: Cache First for static assets, Network First for API calls
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);

    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }

    // Skip cross-origin requests (except CDN)
    if (url.origin !== location.origin && !url.href.includes('cdn')) {
        return;
    }

    // Skip Supabase API calls (always use network)
    if (url.href.includes('supabase.co')) {
        return fetch(request);
    }

    // Cache First strategy for static assets
    event.respondWith(
        caches.match(request)
            .then((cachedResponse) => {
                // Return cached version if available (ultra-fast)
                if (cachedResponse) {
                    return cachedResponse;
                }

                // Otherwise fetch from network
                return fetch(request)
                    .then((response) => {
                        // Don't cache non-successful responses
                        if (!response || response.status !== 200 || response.type !== 'basic') {
                            return response;
                        }

                        // Clone the response for caching
                        const responseToCache = response.clone();

                        // Cache the response for future requests
                        caches.open(CACHE_NAME).then((cache) => {
                            cache.put(request, responseToCache);
                        });

                        return response;
                    })
                    .catch(() => {
                        // Return offline page if available
                        if (request.headers.get('accept') && request.headers.get('accept').includes('text/html')) {
                            return caches.match('/index.html');
                        }
                    });
            })
    );
});

// Message handler for cache updates
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
});
