// Performance Configuration for Sakura Portal Mobile App

const PERFORMANCE_CONFIG = {
    // Loading optimizations
    loading: {
        splashScreenDuration: 1500, // Reduced from 2000ms
        dataLoadTimeout: 10000, // 10 seconds timeout
        preloadDelay: 5000, // Delay auto-refresh
        cacheExpiry: 300000 // 5 minutes cache expiry
    },
    
    // Animation settings
    animations: {
        pageTransition: 400, // Page transition duration
        kpiCardDelay: 100, // Staggered KPI card animations
        hoverScale: 1.02, // Hover scale factor
        easingFunction: 'cubic-bezier(0.4, 0, 0.2, 1)' // Material Design easing
    },
    
    // Resource optimization
    resources: {
        lazyLoadImages: true,
        preloadCriticalScripts: true,
        compressAssets: true,
        enableServiceWorker: true
    },
    
    // Data management
    data: {
        batchSize: 100, // Process data in batches
        debounceDelay: 300, // Debounce user interactions
        retryAttempts: 3, // Network retry attempts
        offlineFallback: true
    }
};

// Performance monitoring
class PerformanceMonitor {
    constructor() {
        this.metrics = {
            appStartTime: 0,
            splashScreenTime: 0,
            dataLoadTime: 0,
            renderTime: 0
        };
        
        this.startMonitoring();
    }
    
    startMonitoring() {
        this.metrics.appStartTime = performance.now();
        
        // Monitor Core Web Vitals
        this.observeLCP();
        this.observeFID();
        this.observeCLS();
    }
    
    observeLCP() {
        if ('PerformanceObserver' in window) {
            const observer = new PerformanceObserver((list) => {
                const entries = list.getEntries();
                const lastEntry = entries[entries.length - 1];
                console.log('LCP:', lastEntry.startTime);
            });
            observer.observe({ entryTypes: ['largest-contentful-paint'] });
        }
    }
    
    observeFID() {
        if ('PerformanceObserver' in window) {
            const observer = new PerformanceObserver((list) => {
                const entries = list.getEntries();
                entries.forEach(entry => {
                    console.log('FID:', entry.processingStart - entry.startTime);
                });
            });
            observer.observe({ entryTypes: ['first-input'] });
        }
    }
    
    observeCLS() {
        if ('PerformanceObserver' in window) {
            let clsValue = 0;
            const observer = new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    if (!entry.hadRecentInput) {
                        clsValue += entry.value;
                    }
                }
                console.log('CLS:', clsValue);
            });
            observer.observe({ entryTypes: ['layout-shift'] });
        }
    }
    
    markSplashScreenEnd() {
        this.metrics.splashScreenTime = performance.now() - this.metrics.appStartTime;
        console.log(`Splash screen duration: ${this.metrics.splashScreenTime}ms`);
    }
    
    markDataLoadComplete() {
        this.metrics.dataLoadTime = performance.now() - this.metrics.appStartTime;
        console.log(`Data load time: ${this.metrics.dataLoadTime}ms`);
    }
    
    markRenderComplete() {
        this.metrics.renderTime = performance.now() - this.metrics.appStartTime;
        console.log(`Total render time: ${this.metrics.renderTime}ms`);
        
        // Send metrics to analytics if available
        this.sendMetricsToAnalytics();
    }
    
    sendMetricsToAnalytics() {
        // Send performance metrics to your analytics service
        if (typeof gtag !== 'undefined') {
            gtag('event', 'performance_metrics', {
                'app_start_time': this.metrics.appStartTime,
                'splash_screen_time': this.metrics.splashScreenTime,
                'data_load_time': this.metrics.dataLoadTime,
                'total_render_time': this.metrics.renderTime
            });
        }
    }
}

// Resource preloader
class ResourcePreloader {
    constructor() {
        this.preloadedResources = new Set();
        this.preloadQueue = [];
    }
    
    preloadScript(src) {
        if (this.preloadedResources.has(src)) {
            return Promise.resolve();
        }
        
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = src;
            script.async = true;
            script.onload = () => {
                this.preloadedResources.add(src);
                resolve();
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }
    
    preloadStylesheet(href) {
        if (this.preloadedResources.has(href)) {
            return Promise.resolve();
        }
        
        return new Promise((resolve, reject) => {
            const link = document.createElement('link');
            link.rel = 'preload';
            link.as = 'style';
            link.href = href;
            link.onload = () => {
                link.rel = 'stylesheet';
                this.preloadedResources.add(href);
                resolve();
            };
            link.onerror = reject;
            document.head.appendChild(link);
        });
    }
    
    preloadImage(src) {
        if (this.preloadedResources.has(src)) {
            return Promise.resolve();
        }
        
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => {
                this.preloadedResources.add(src);
                resolve();
            };
            img.onerror = reject;
            img.src = src;
        });
    }
    
    async preloadCriticalResources() {
        const criticalResources = [
            'https://cdn.jsdelivr.net/npm/chart.js',
            'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js',
            'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js'
        ];
        
        try {
            await Promise.all(criticalResources.map(resource => 
                this.preloadScript(resource)
            ));
            console.log('Critical resources preloaded');
        } catch (error) {
            console.error('Failed to preload critical resources:', error);
        }
    }
}

// Debounce utility for performance
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Throttle utility for performance
function throttle(func, limit) {
    let inThrottle;
    return function() {
        const args = arguments;
        const context = this;
        if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// Lazy loading utility
class LazyLoader {
    constructor() {
        this.observer = null;
        this.init();
    }
    
    init() {
        if ('IntersectionObserver' in window) {
            this.observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        this.loadElement(entry.target);
                        this.observer.unobserve(entry.target);
                    }
                });
            }, {
                rootMargin: '50px 0px',
                threshold: 0.1
            });
        }
    }
    
    observe(element) {
        if (this.observer) {
            this.observer.observe(element);
        } else {
            // Fallback for browsers without IntersectionObserver
            this.loadElement(element);
        }
    }
    
    loadElement(element) {
        const src = element.dataset.src;
        if (src) {
            if (element.tagName === 'IMG') {
                element.src = src;
            } else if (element.tagName === 'SCRIPT') {
                const script = document.createElement('script');
                script.src = src;
                script.async = true;
                element.parentNode.replaceChild(script, element);
            }
            element.classList.add('loaded');
        }
    }
}

// Initialize performance optimizations
function initializePerformanceOptimizations() {
    // Start performance monitoring
    window.performanceMonitor = new PerformanceMonitor();
    
    // Initialize resource preloader
    window.resourcePreloader = new ResourcePreloader();
    
    // Initialize lazy loader
    window.lazyLoader = new LazyLoader();
    
    // Preload critical resources
    window.resourcePreloader.preloadCriticalResources();
    
    console.log('Performance optimizations initialized');
}

// Export for use in main app
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        PERFORMANCE_CONFIG,
        PerformanceMonitor,
        ResourcePreloader,
        debounce,
        throttle,
        LazyLoader,
        initializePerformanceOptimizations
    };
} else {
    // Make available globally
    window.PERFORMANCE_CONFIG = PERFORMANCE_CONFIG;
    window.PerformanceMonitor = PerformanceMonitor;
    window.ResourcePreloader = ResourcePreloader;
    window.debounce = debounce;
    window.throttle = throttle;
    window.LazyLoader = LazyLoader;
    window.initializePerformanceOptimizations = initializePerformanceOptimizations;
}







