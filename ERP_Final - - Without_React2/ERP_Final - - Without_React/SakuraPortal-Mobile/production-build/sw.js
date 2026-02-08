// Service Worker for Sakura Portal Mobile App

const CACHE_NAME = 'sakura-portal-v1.0.0';
const PERFORMANCE_CONFIG = {
  "cacheMaxAge": 86400,
  "cacheStaleWhileRevalidate": 3600,
  "preloadCriticalResources": true,
  "lazyLoadImages": true,
  "minifyAssets": true,
  "codeSplitting": true,
  "treeShaking": true,
  "aggressiveCaching": true,
  "backgroundSync": true
};
const STATIC_CACHE = 'sakura-portal-static-v1';
const DYNAMIC_CACHE = 'sakura-portal-dynamic-v1';

// Files to cache on install
const STATIC_FILES = [
    '/',
    '/index.html',
    '/styles.css',
    '/app.js',
    '/manifest.json',
    'https://cdn.tailwindcss.com',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css',
    'https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap',
    'https://cdn.jsdelivr.net/npm/chart.js',
    'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js'
];

// Install event - cache static files
self.addEventListener('install', (event) => {
    console.log('Service Worker: Installing...');
    
    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then((cache) => {
                console.log('Service Worker: Caching static files');
                return cache.addAll(STATIC_FILES);
            })
            .then(() => {
                console.log('Service Worker: Static files cached');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('Service Worker: Error caching static files', error);
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('Service Worker: Activating...');
    
    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames.map((cacheName) => {
                        if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
                            console.log('Service Worker: Deleting old cache', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            })
            .then(() => {
                console.log('Service Worker: Activated');
                return self.clients.claim();
            })
    );
});

// Fetch event - serve cached content when offline
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);
    
    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }
    
    // Handle different types of requests
    if (request.destination === 'document') {
        // Handle HTML requests
        event.respondWith(handleDocumentRequest(request));
    } else if (request.destination === 'style' || 
               request.destination === 'script' || 
               request.destination === 'image' ||
               request.destination === 'font') {
        // Handle static assets
        event.respondWith(handleStaticRequest(request));
    } else if (url.pathname.includes('/api/') || url.hostname.includes('script.google.com')) {
        // Handle API requests
        event.respondWith(handleApiRequest(request));
    } else {
        // Handle other requests
        event.respondWith(handleOtherRequest(request));
    }
});

// Handle document requests (HTML pages)
async function handleDocumentRequest(request) {
    try {
        // Try network first
        const networkResponse = await fetch(request);
        
        // Cache successful responses
        if (networkResponse.ok) {
            const cache = await caches.open(DYNAMIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.log('Service Worker: Network failed for document, trying cache');
        
        // Try cache
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        
        // Return offline page or index.html
        return caches.match('/index.html');
    }
}

// Handle static asset requests
async function handleStaticRequest(request) {
    try {
        // Try cache first for better performance
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        
        // Try network
        const networkResponse = await fetch(request);
        
        // Cache successful responses
        if (networkResponse.ok) {
            const cache = await caches.open(STATIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.log('Service Worker: Failed to fetch static asset', request.url);
        
        // Return a fallback response if needed
        return new Response('Asset not available offline', {
            status: 404,
            statusText: 'Not Found'
        });
    }
}

// Handle API requests
async function handleApiRequest(request) {
    try {
        // Try network first
        const networkResponse = await fetch(request);
        
        // Cache successful responses
        if (networkResponse.ok) {
            const cache = await caches.open(DYNAMIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.log('Service Worker: Network failed for API, trying cache');
        
        // Try cache
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            // Return cached data with a warning header
            const response = cachedResponse.clone();
            response.headers.set('X-Cache-Status', 'stale');
            return response;
        }
        
        // Return offline data response
        return new Response(JSON.stringify({
            error: 'No internet connection',
            message: 'Please check your connection and try again',
            offline: true
        }), {
            status: 503,
            statusText: 'Service Unavailable',
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }
}

// Handle other requests
async function handleOtherRequest(request) {
    try {
        const networkResponse = await fetch(request);
        return networkResponse;
    } catch (error) {
        const cachedResponse = await caches.match(request);
        return cachedResponse || new Response('Resource not available', {
            status: 404,
            statusText: 'Not Found'
        });
    }
}

// Background sync for offline actions
self.addEventListener('sync', (event) => {
    console.log('Service Worker: Background sync triggered');
    
    if (event.tag === 'data-sync') {
        event.waitUntil(syncData());
    }
});

// Sync data when back online
async function syncData() {
    try {
        // Get pending actions from IndexedDB
        const pendingActions = await getPendingActions();
        
        for (const action of pendingActions) {
            try {
                await fetch(action.url, action.options);
                await removePendingAction(action.id);
            } catch (error) {
                console.error('Service Worker: Failed to sync action', action, error);
            }
        }
        
        // Notify clients that sync is complete
        const clients = await self.clients.matchAll();
        clients.forEach(client => {
            client.postMessage({
                type: 'SYNC_COMPLETE',
                data: { synced: pendingActions.length }
            });
        });
        
    } catch (error) {
        console.error('Service Worker: Sync failed', error);
    }
}

// Message handling
self.addEventListener('message', (event) => {
    const { type, data } = event.data;
    
    switch (type) {
        case 'SKIP_WAITING':
            self.skipWaiting();
            break;
            
        case 'CACHE_DATA':
            cacheData(data);
            break;
            
        case 'GET_CACHE_STATUS':
            getCacheStatus().then(status => {
                event.ports[0].postMessage(status);
            });
            break;
            
        default:
            console.log('Service Worker: Unknown message type', type);
    }
});

// Cache data for offline use
async function cacheData(data) {
    try {
        const cache = await caches.open(DYNAMIC_CACHE);
        const response = new Response(JSON.stringify(data), {
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        await cache.put('/api/data', response);
        console.log('Service Worker: Data cached successfully');
    } catch (error) {
        console.error('Service Worker: Error caching data', error);
    }
}

// Get cache status
async function getCacheStatus() {
    try {
        const cacheNames = await caches.keys();
        const status = {};
        
        for (const cacheName of cacheNames) {
            const cache = await caches.open(cacheName);
            const keys = await cache.keys();
            status[cacheName] = keys.length;
        }
        
        return status;
    } catch (error) {
        console.error('Service Worker: Error getting cache status', error);
        return {};
    }
}

// Helper functions for IndexedDB (simplified)
async function getPendingActions() {
    // In a real implementation, you would use IndexedDB
    // For now, return empty array
    return [];
}

async function removePendingAction(id) {
    // In a real implementation, you would remove from IndexedDB
    console.log('Service Worker: Removing pending action', id);
}

// Push notification handling
self.addEventListener('push', (event) => {
    console.log('Service Worker: Push notification received');
    
    const options = {
        body: 'New data is available',
        icon: '/assets/icons/icon-192x192.png',
        badge: '/assets/icons/icon-72x72.png',
        vibrate: [100, 50, 100],
        data: {
            dateOfArrival: Date.now(),
            primaryKey: 1
        },
        actions: [
            {
                action: 'explore',
                title: 'View Data',
                icon: '/assets/icons/icon-96x96.png'
            },
            {
                action: 'close',
                title: 'Close',
                icon: '/assets/icons/icon-96x96.png'
            }
        ]
    };
    
    event.waitUntil(
        self.registration.showNotification('Sakura Portal', options)
    );
});

// Notification click handling
self.addEventListener('notificationclick', (event) => {
    console.log('Service Worker: Notification clicked');
    
    event.notification.close();
    
    if (event.action === 'explore') {
        event.waitUntil(
            clients.openWindow('/')
        );
    }
});

console.log('Service Worker: Loaded successfully');

// Aggressive caching for performance
const AGGRESSIVE_CACHE_STRATEGY = {
    static: 'cache-first',
    api: 'stale-while-revalidate',
    images: 'cache-first'
};

// Performance monitoring
function measurePerformance() {
    if ('performance' in window) {
        const perfData = performance.getEntriesByType('navigation')[0];
        console.log('Page load time:', perfData.loadEventEnd - perfData.loadEventStart);
    }
}