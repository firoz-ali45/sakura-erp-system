// Sakura Portal Mobile App - Main JavaScript

import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { Keyboard } from '@capacitor/keyboard';
import { StatusBar, Style } from '@capacitor/status-bar';
import { SplashScreen } from '@capacitor/splash-screen';

// App Configuration
const CONFIG = {
    dataSource: 'https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec',
    refreshInterval: 60000, // 1 minute
    notifications: true
};

// App State
let appState = {
    currentPage: 'dashboard',
    data: null,
    lastUpdate: null,
    refreshTimer: null
};

// Initialize App
document.addEventListener('DOMContentLoaded', async () => {
    await initializeApp();
});

async function initializeApp() {
    try {
        // Initialize performance optimizations
        initializePerformanceOptimizations();
        
        // Show splash screen immediately
        showSplashScreen();
        
        // Start loading process with visual feedback
        updateLoadingProgress(10, 'Initializing system...');
        
        // Initialize Capacitor plugins (non-blocking)
        if (Capacitor.isNativePlatform()) {
            initializeNativeFeatures().catch(console.error);
        }
        
        updateLoadingProgress(30, 'Loading interface...');
        
        // Initialize UI (non-blocking)
        initializeUI();
        
        updateLoadingProgress(60, 'Connecting to data source...');
        
        // Load initial data (non-blocking)
        loadData().catch(error => {
            console.error('Data loading error:', error);
            updateLoadingProgress(90, 'Loading cached data...');
            // Load cached data if available
            const cachedData = loadCachedData();
            if (cachedData) {
                appState.data = cachedData;
                updateDashboardData(cachedData);
            }
        });
        
        updateLoadingProgress(100, 'Ready!');
        
        // Mark performance metrics
        if (window.performanceMonitor) {
            window.performanceMonitor.markSplashScreenEnd();
        }
        
        // Hide splash screen quickly after minimum display time
        setTimeout(() => {
            hideSplashScreen();
            if (window.performanceMonitor) {
                window.performanceMonitor.markRenderComplete();
            }
        }, PERFORMANCE_CONFIG.loading.splashScreenDuration);
        
    } catch (error) {
        console.error('App initialization error:', error);
        updateLoadingProgress(100, 'Error loading app');
        setTimeout(() => {
            hideSplashScreen();
        }, 1000);
    }
}

function updateLoadingProgress(percent, message) {
    const progressFill = document.querySelector('.progress-fill');
    const loadingText = document.querySelector('.loading-text');
    
    if (progressFill) {
        progressFill.style.width = `${percent}%`;
    }
    
    if (loadingText) {
        loadingText.textContent = message;
    }
}

async function initializeNativeFeatures() {
    try {
        // Configure status bar
        await StatusBar.setStyle({ style: Style.Dark });
        await StatusBar.setBackgroundColor({ color: '#284b44' });
        
        // Hide splash screen
        await SplashScreen.hide();
        
        // Handle app state changes
        App.addListener('appStateChange', ({ isActive }) => {
            if (isActive && appState.refreshTimer) {
                clearInterval(appState.refreshTimer);
                startAutoRefresh();
            }
        });
        
        // Handle back button
        App.addListener('backButton', () => {
            handleBackButton();
        });
        
        // Configure keyboard
        await Keyboard.setAccessoryBarVisible({ isVisible: false });
        
    } catch (error) {
        console.error('Native features initialization error:', error);
    }
}

function initializeUI() {
    // Menu toggle
    const menuToggle = document.getElementById('menu-toggle');
    const sidebar = document.getElementById('sidebar');
    
    menuToggle?.addEventListener('click', () => {
        toggleSidebar();
    });
    
    // Navigation with lazy loading
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.dataset.page;
            if (page) {
                navigateToPage(page);
                closeSidebar();
            }
        });
    });
    
    // Action buttons
    const actionButtons = document.querySelectorAll('.action-btn');
    actionButtons.forEach(button => {
        button.addEventListener('click', () => {
            const page = button.dataset.page;
            if (page) {
                navigateToPage(page);
            }
        });
    });
    
    // Refresh button
    const refreshBtn = document.getElementById('refresh-btn');
    refreshBtn?.addEventListener('click', () => {
        loadData();
    });
    
    // Export data button
    const exportBtn = document.getElementById('export-data');
    exportBtn?.addEventListener('click', () => {
        exportData();
    });
    
    // Settings
    initializeSettings();
    
    // Start auto-refresh (delayed to not interfere with initial load)
    setTimeout(() => {
        startAutoRefresh();
    }, 5000);
    
    // Preload critical resources
    preloadResources();
}

function preloadResources() {
    // Preload external libraries
    const preloadPromises = [];
    
    // Preload Chart.js if not already loaded
    if (typeof Chart === 'undefined') {
        const chartScript = document.createElement('script');
        chartScript.src = 'https://cdn.jsdelivr.net/npm/chart.js';
        chartScript.async = true;
        document.head.appendChild(chartScript);
    }
    
    // Preload XLSX library if not already loaded
    if (typeof XLSX === 'undefined') {
        const xlsxScript = document.createElement('script');
        xlsxScript.src = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js';
        xlsxScript.async = true;
        document.head.appendChild(xlsxScript);
    }
}

function initializeSettings() {
    const refreshInterval = document.getElementById('refresh-interval');
    const notificationsEnabled = document.getElementById('notifications-enabled');
    
    // Load saved settings
    const savedSettings = loadSettings();
    if (refreshInterval) {
        refreshInterval.value = savedSettings.refreshInterval || CONFIG.refreshInterval;
        refreshInterval.addEventListener('change', (e) => {
            CONFIG.refreshInterval = parseInt(e.target.value);
            saveSettings();
            startAutoRefresh();
        });
    }
    
    if (notificationsEnabled) {
        notificationsEnabled.checked = savedSettings.notifications !== false;
        notificationsEnabled.addEventListener('change', (e) => {
            CONFIG.notifications = e.target.checked;
            saveSettings();
        });
    }
}

function showSplashScreen() {
    const splashScreen = document.getElementById('splash-screen');
    const app = document.getElementById('app');
    
    if (splashScreen) {
        splashScreen.classList.remove('hidden');
    }
    if (app) {
        app.style.display = 'none';
    }
}

function hideSplashScreen() {
    const splashScreen = document.getElementById('splash-screen');
    const app = document.getElementById('app');
    
    if (splashScreen) {
        splashScreen.classList.add('hidden');
        setTimeout(() => {
            splashScreen.style.display = 'none';
        }, 500);
    }
    if (app) {
        app.style.display = 'block';
    }
}

function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.querySelector('.main-content');
    
    if (sidebar && mainContent) {
        sidebar.classList.toggle('open');
        mainContent.classList.toggle('sidebar-open');
    }
    
    // Haptic feedback
    if (Capacitor.isNativePlatform()) {
        Haptics.impact({ style: ImpactStyle.Light });
    }
}

function closeSidebar() {
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.querySelector('.main-content');
    
    if (sidebar && mainContent) {
        sidebar.classList.remove('open');
        mainContent.classList.remove('sidebar-open');
    }
}

function navigateToPage(pageId) {
    // Update active nav item
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.classList.remove('active');
        if (item.dataset.page === pageId) {
            item.classList.add('active');
        }
    });
    
    // Update active page
    const pages = document.querySelectorAll('.page');
    pages.forEach(page => {
        page.classList.remove('active');
    });
    
    const targetPage = document.getElementById(`${pageId}-page`);
    if (targetPage) {
        targetPage.classList.add('active');
        appState.currentPage = pageId;
        
        // Load page-specific content
        loadPageContent(pageId);
        
        // Haptic feedback
        if (Capacitor.isNativePlatform()) {
            Haptics.impact({ style: ImpactStyle.Light });
        }
    }
}

async function loadPageContent(pageId) {
    switch (pageId) {
        case 'dashboard':
            await loadDashboardData();
            break;
        case 'payable':
            await loadPayableContent();
            break;
        case 'forecasting':
            await loadForecastingContent();
            break;
        case 'warehouse':
            await loadWarehouseContent();
            break;
    }
}

async function loadData() {
    // Don't show loading overlay for initial load
    const isInitialLoad = !appState.data;
    
    if (!isInitialLoad) {
        showLoading();
    }
    
    try {
        // Use AbortController for timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
        
        const response = await fetch(CONFIG.dataSource, {
            signal: controller.signal,
            cache: 'no-cache',
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        appState.data = data;
        appState.lastUpdate = new Date();
        
        // Update UI with new data
        updateDashboardData(data);
        updateLastUpdatedTime();
        
        // Cache the data for offline use
        saveCachedData(data);
        
        if (!isInitialLoad) {
            showToast('Data updated successfully', 'success');
        }
        
    } catch (error) {
        console.error('Error loading data:', error);
        
        if (!isInitialLoad) {
            showToast('Failed to load data', 'error');
        }
        
        // Load cached data if available
        const cachedData = loadCachedData();
        if (cachedData) {
            appState.data = cachedData;
            updateDashboardData(cachedData);
            
            if (!isInitialLoad) {
                showToast('Using cached data', 'warning');
            }
        }
    } finally {
        if (!isInitialLoad) {
            hideLoading();
        }
    }
}

function updateDashboardData(data) {
    if (!data) return;
    
    // Update KPI cards
    const payableData = data.payableData || {};
    updateKPICard('total-dues', payableData.totalDues || 'N/A');
    updateKPICard('total-suppliers', payableData.totalSuppliers || '0');
    updateKPICard('overdues', payableData.overdues || 'N/A');
    updateKPICard('total-transactions', payableData.totalTransactions || '0');
}

function updateKPICard(elementId, value) {
    const element = document.getElementById(elementId);
    if (element) {
        element.textContent = value;
    }
}

function updateLastUpdatedTime() {
    const lastUpdatedElement = document.getElementById('last-updated');
    if (lastUpdatedElement && appState.lastUpdate) {
        lastUpdatedElement.textContent = appState.lastUpdate.toLocaleTimeString();
    }
}

async function loadDashboardData() {
    if (appState.data) {
        updateDashboardData(appState.data);
    }
}

async function loadPayableContent() {
    const content = document.getElementById('payable-content');
    if (!content) return;
    
    content.innerHTML = `
        <div class="card">
            <h3>Accounts Payable Dashboard</h3>
            <p>Loading payable data...</p>
        </div>
    `;
    
    // Load payable-specific content
    if (appState.data?.payableData) {
        // Implement payable dashboard content
        content.innerHTML = createPayableDashboard(appState.data.payableData);
    }
}

async function loadForecastingContent() {
    const content = document.getElementById('forecasting-content');
    if (!content) return;
    
    content.innerHTML = `
        <div class="card">
            <h3>Forecasting Dashboard</h3>
            <p>Loading forecasting data...</p>
        </div>
    `;
    
    // Load forecasting-specific content
    if (appState.data?.forecastingData) {
        content.innerHTML = createForecastingDashboard(appState.data.forecastingData);
    }
}

async function loadWarehouseContent() {
    const content = document.getElementById('warehouse-content');
    if (!content) return;
    
    content.innerHTML = `
        <div class="card">
            <h3>Warehouse Dashboard</h3>
            <p>Loading warehouse data...</p>
        </div>
    `;
    
    // Load warehouse-specific content
    if (appState.data?.warehouseData) {
        content.innerHTML = createWarehouseDashboard(appState.data.warehouseData);
    }
}

function createPayableDashboard(data) {
    return `
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-file-invoice-dollar"></i>
                </div>
                <div class="kpi-content">
                    <h3>Total Dues</h3>
                    <div class="kpi-value">${data.totalDues || 'N/A'}</div>
                    <p class="kpi-subtitle">Outstanding Payments</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-users"></i>
                </div>
                <div class="kpi-content">
                    <h3>Total Suppliers</h3>
                    <div class="kpi-value">${data.totalSuppliers || '0'}</div>
                    <p class="kpi-subtitle">Active Vendors</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-exclamation-triangle"></i>
                </div>
                <div class="kpi-content">
                    <h3>Overdues</h3>
                    <div class="kpi-value">${data.overdues || 'N/A'}</div>
                    <p class="kpi-subtitle">Pending Payments</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-receipt"></i>
                </div>
                <div class="kpi-content">
                    <h3>Transactions</h3>
                    <div class="kpi-value">${data.totalTransactions || '0'}</div>
                    <p class="kpi-subtitle">Total Records</p>
                </div>
            </div>
        </div>
    `;
}

function createForecastingDashboard(data) {
    return `
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-calculator"></i>
                </div>
                <div class="kpi-content">
                    <h3>Total Budget</h3>
                    <div class="kpi-value">${data.kpiTotalBudget || 'N/A'}</div>
                    <p class="kpi-subtitle">Purchase Budget</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-shopping-cart"></i>
                </div>
                <div class="kpi-content">
                    <h3>Items to Order</h3>
                    <div class="kpi-value">${data.kpiItemsToOrder || '0'}</div>
                    <p class="kpi-subtitle">Required Items</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-piggy-bank"></i>
                </div>
                <div class="kpi-content">
                    <h3>Savings</h3>
                    <div class="kpi-value">${data.kpiSavings || 'N/A'}</div>
                    <p class="kpi-subtitle">Potential Savings</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-chart-line"></i>
                </div>
                <div class="kpi-content">
                    <h3>Forecast Accuracy</h3>
                    <div class="kpi-value">${data.kpiForecastAccuracy || 'N/A'}</div>
                    <p class="kpi-subtitle">Accuracy Rate</p>
                </div>
            </div>
        </div>
    `;
}

function createWarehouseDashboard(data) {
    return `
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-boxes"></i>
                </div>
                <div class="kpi-content">
                    <h3>Inventory Value</h3>
                    <div class="kpi-value">${data.totalInventoryValue || 'N/A'}</div>
                    <p class="kpi-subtitle">Total Value</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-exclamation-circle"></i>
                </div>
                <div class="kpi-content">
                    <h3>Out of Stock</h3>
                    <div class="kpi-value">${data.outOfStock || '0'}</div>
                    <p class="kpi-subtitle">Items</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-exclamation-triangle"></i>
                </div>
                <div class="kpi-content">
                    <h3>Low Stock</h3>
                    <div class="kpi-value">${data.lowStock || '0'}</div>
                    <p class="kpi-subtitle">Items</p>
                </div>
            </div>
            <div class="kpi-card">
                <div class="kpi-icon">
                    <i class="fas fa-truck"></i>
                </div>
                <div class="kpi-content">
                    <h3>Transfer Value</h3>
                    <div class="kpi-value">${data.transferValue || 'N/A'}</div>
                    <p class="kpi-subtitle">Total Transfers</p>
                </div>
            </div>
        </div>
    `;
}

function startAutoRefresh() {
    if (appState.refreshTimer) {
        clearInterval(appState.refreshTimer);
    }
    
    appState.refreshTimer = setInterval(() => {
        loadData();
    }, CONFIG.refreshInterval);
}

function showLoading() {
    const overlay = document.getElementById('loading-overlay');
    if (overlay) {
        overlay.classList.add('show');
    }
}

function hideLoading() {
    const overlay = document.getElementById('loading-overlay');
    if (overlay) {
        overlay.classList.remove('show');
    }
}

function showToast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    if (!container) return;
    
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <div class="toast-content">
            <p>${message}</p>
        </div>
    `;
    
    container.appendChild(toast);
    
    // Auto remove after 3 seconds
    setTimeout(() => {
        toast.remove();
    }, 3000);
    
    // Haptic feedback
    if (Capacitor.isNativePlatform()) {
        Haptics.impact({ style: ImpactStyle.Light });
    }
}

function exportData() {
    if (!appState.data) {
        showToast('No data available to export', 'warning');
        return;
    }
    
    try {
        const dataStr = JSON.stringify(appState.data, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `sakura-portal-data-${new Date().toISOString().split('T')[0]}.json`;
        link.click();
        
        URL.revokeObjectURL(url);
        showToast('Data exported successfully', 'success');
        
    } catch (error) {
        console.error('Export error:', error);
        showToast('Failed to export data', 'error');
    }
}

function handleBackButton() {
    if (document.getElementById('sidebar').classList.contains('open')) {
        closeSidebar();
    } else {
        App.exitApp();
    }
}

function loadSettings() {
    try {
        const settings = localStorage.getItem('sakura-portal-settings');
        return settings ? JSON.parse(settings) : {};
    } catch (error) {
        console.error('Error loading settings:', error);
        return {};
    }
}

function saveSettings() {
    try {
        const settings = {
            refreshInterval: CONFIG.refreshInterval,
            notifications: CONFIG.notifications
        };
        localStorage.setItem('sakura-portal-settings', JSON.stringify(settings));
    } catch (error) {
        console.error('Error saving settings:', error);
    }
}

function loadCachedData() {
    try {
        const cached = localStorage.getItem('sakura-portal-cache');
        return cached ? JSON.parse(cached) : null;
    } catch (error) {
        console.error('Error loading cached data:', error);
        return null;
    }
}

function saveCachedData(data) {
    try {
        localStorage.setItem('sakura-portal-cache', JSON.stringify(data));
    } catch (error) {
        console.error('Error saving cached data:', error);
    }
}

// Save data to cache when loaded
document.addEventListener('DOMContentLoaded', () => {
    const originalLoadData = loadData;
    loadData = async function() {
        await originalLoadData();
        if (appState.data) {
            saveCachedData(appState.data);
        }
    };
});
