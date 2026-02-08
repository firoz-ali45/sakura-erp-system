/**
 * Enterprise Data Cache System
 * Prevents duplicate API calls and enables sub-second page loads
 */

const dataCache = new Map();
const CACHE_TTL = 300000; // 5 minutes default TTL (300000ms)

/**
 * Cache entry structure:
 * {
 *   data: any,
 *   timestamp: number,
 *   ttl: number (optional, defaults to CACHE_TTL)
 * }
 */

/**
 * Get cached data if available and not stale
 */
export function getCachedData(key) {
  const entry = dataCache.get(key);
  if (!entry) return null;
  
  const age = Date.now() - entry.timestamp;
  const ttl = entry.ttl || CACHE_TTL;
  
  if (age > ttl) {
    dataCache.delete(key);
    return null;
  }
  
  return entry.data;
}

/**
 * Set data in cache
 */
export function setCachedData(key, data, ttl = CACHE_TTL) {
  dataCache.set(key, {
    data,
    timestamp: Date.now(),
    ttl
  });
}

/**
 * Invalidate cache for a key or pattern
 */
export function invalidateCache(keyOrPattern) {
  if (keyOrPattern.includes('*')) {
    // Pattern matching
    const pattern = new RegExp(keyOrPattern.replace(/\*/g, '.*'));
    for (const key of dataCache.keys()) {
      if (pattern.test(key)) {
        dataCache.delete(key);
      }
    }
  } else {
    dataCache.delete(keyOrPattern);
  }
}

/**
 * Clear all cache
 */
export function clearCache() {
  dataCache.clear();
}

/**
 * Wrapper function for async data fetching with caching
 */
export async function cachedFetch(key, fetchFn, ttl = CACHE_TTL) {
  // Check cache first
  const cached = getCachedData(key);
  if (cached !== null) {
    return cached;
  }
  
  // Fetch and cache
  const data = await fetchFn();
  setCachedData(key, data, ttl);
  return data;
}

/**
 * Batch multiple cache operations
 */
export async function batchCacheOperations(operations) {
  const results = await Promise.all(
    operations.map(async ({ key, fetchFn, ttl }) => {
      return cachedFetch(key, fetchFn, ttl);
    })
  );
  
  return results;
}

/**
 * Cache keys factory for consistent naming
 */
export const cacheKeys = {
  users: () => 'users:all',
  user: (id) => `users:${id}`,
  items: () => 'inventory:items:all',
  item: (id) => `inventory:items:${id}`,
  suppliers: () => 'inventory:suppliers:all',
  supplier: (id) => `inventory:suppliers:${id}`,
  purchaseOrders: () => 'inventory:purchase-orders:all',
  purchaseOrder: (id) => `inventory:purchase-orders:${id}`,
  grns: () => 'inventory:grns:all',
  grn: (id) => `inventory:grns:${id}`,
  categories: () => 'inventory:categories:all',
  pendingUsers: () => 'users:pending',
};
