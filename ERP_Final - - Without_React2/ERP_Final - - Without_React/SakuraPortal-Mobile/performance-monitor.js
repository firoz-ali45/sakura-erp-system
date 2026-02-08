
// Performance monitoring for Sakura Portal
class PerformanceMonitor {
    constructor() {
        this.metrics = {};
        this.startTime = performance.now();
        this.init();
    }
    
    init() {
        // Monitor Core Web Vitals
        this.monitorLCP();
        this.monitorFID();
        this.monitorCLS();
        
        // Monitor app-specific metrics
        this.monitorAppLoad();
        this.monitorDataLoad();
    }
    
    monitorLCP() {
        new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const lastEntry = entries[entries.length - 1];
            this.metrics.lcp = lastEntry.startTime;
            console.log('LCP:', lastEntry.startTime);
        }).observe({ entryTypes: ['largest-contentful-paint'] });
    }
    
    monitorFID() {
        new PerformanceObserver((list) => {
            const entries = list.getEntries();
            entries.forEach((entry) => {
                this.metrics.fid = entry.processingStart - entry.startTime;
                console.log('FID:', this.metrics.fid);
            });
        }).observe({ entryTypes: ['first-input'] });
    }
    
    monitorCLS() {
        let clsValue = 0;
        new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
                if (!entry.hadRecentInput) {
                    clsValue += entry.value;
                }
            }
            this.metrics.cls = clsValue;
            console.log('CLS:', clsValue);
        }).observe({ entryTypes: ['layout-shift'] });
    }
    
    monitorAppLoad() {
        window.addEventListener('load', () => {
            this.metrics.appLoadTime = performance.now() - this.startTime;
            console.log('App load time:', this.metrics.appLoadTime);
        });
    }
    
    monitorDataLoad() {
        // Monitor data loading performance
        const originalFetch = window.fetch;
        window.fetch = async (...args) => {
            const start = performance.now();
            try {
                const response = await originalFetch(...args);
                const end = performance.now();
                console.log('Data fetch time:', end - start);
                return response;
            } catch (error) {
                console.error('Fetch error:', error);
                throw error;
            }
        };
    }
    
    getMetrics() {
        return this.metrics;
    }
}

// Initialize performance monitoring
if (typeof window !== 'undefined') {
    window.performanceMonitor = new PerformanceMonitor();
}