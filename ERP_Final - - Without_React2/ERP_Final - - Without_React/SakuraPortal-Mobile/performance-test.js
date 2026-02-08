// Performance testing for Sakura Portal
const performanceTest = {
    // Test app load time
    testAppLoadTime() {
        const start = performance.now();
        return new Promise((resolve) => {
            window.addEventListener('load', () => {
                const end = performance.now();
                const loadTime = end - start;
                console.log('App load time:', loadTime + 'ms');
                resolve(loadTime);
            });
        });
    },
    
    // Test data loading performance
    async testDataLoadTime() {
        const start = performance.now();
        try {
            await fetch('/api/test');
            const end = performance.now();
            const loadTime = end - start;
            console.log('Data load time:', loadTime + 'ms');
            return loadTime;
        } catch (error) {
            console.error('Data load test failed:', error);
            return null;
        }
    },
    
    // Test memory usage
    testMemoryUsage() {
        if ('memory' in performance) {
            const memory = performance.memory;
            console.log('Memory usage:', {
                used: Math.round(memory.usedJSHeapSize / 1024 / 1024) + 'MB',
                total: Math.round(memory.totalJSHeapSize / 1024 / 1024) + 'MB',
                limit: Math.round(memory.jsHeapSizeLimit / 1024 / 1024) + 'MB'
            });
        }
    },
    
    // Run all tests
    async runAllTests() {
        console.log('🧪 Running performance tests...');
        
        const results = {
            appLoadTime: await this.testAppLoadTime(),
            dataLoadTime: await this.testDataLoadTime(),
            memoryUsage: this.testMemoryUsage()
        };
        
        console.log('📊 Performance test results:', results);
        return results;
    }
};

// Export for use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = performanceTest;
} else if (typeof window !== 'undefined') {
    window.performanceTest = performanceTest;
}