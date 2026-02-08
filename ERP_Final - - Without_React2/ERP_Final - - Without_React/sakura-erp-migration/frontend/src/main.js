import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import i18n from './i18n';
import { useLanguageStore } from './stores/language';
import './style.css';

// Error handling to prevent blank screen
(function() {
  try {
    console.log('🚀 Starting Vue app initialization...');
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initApp);
    } else {
      // DOM already ready
      setTimeout(initApp, 0);
    }
    
    function initApp() {
      try {
        console.log('📦 Creating Vue app...');
        const app = createApp(App);
        const pinia = createPinia();

        console.log('🔌 Installing plugins...');
        // Install plugins in order
        app.use(pinia);
        app.use(router);
        app.use(i18n); // i18n must be installed for $t to work globally

        console.log('🌐 Initializing language store...');
        // Initialize language store AFTER pinia is installed
        // This ensures language is set before app mounts
        try {
          const languageStore = useLanguageStore();
          languageStore.initialize();
        } catch (langError) {
          console.warn('⚠️ Language store initialization warning:', langError);
          // Continue anyway - language will default
        }

        console.log('🔍 Checking app element...');
        // Ensure app element exists before mounting
        const appElement = document.getElementById('app');
        if (!appElement) {
          console.error('❌ App element #app not found in DOM');
          showError('App element not found. Please refresh the page.');
          return;
        }

        console.log('⚡ Mounting Vue app...');
        app.mount('#app');
        console.log('✅ Vue app mounted successfully');
        
        // Hide loading screen after mount
        setTimeout(() => {
          const loading = document.getElementById('app-loading');
          if (loading) {
            loading.classList.add('hidden');
            console.log('✅ Loading screen hidden');
          }
        }, 100);
      } catch (error) {
        console.error('❌ Error in initApp:', error);
        showError(`Failed to initialize app: ${error.message}`, error);
      }
    }
    
    function showError(message, error = null) {
      const loading = document.getElementById('app-loading');
      if (loading) {
        loading.innerHTML = `
          <div style="text-align: center; font-family: Arial, sans-serif;">
            <h1 style="color: #dc2626; margin-bottom: 10px;">Application Error</h1>
            <p style="color: #666; margin-bottom: 20px;">${message}</p>
            ${error ? `<p style="color: #999; font-size: 12px; margin-bottom: 20px;">Error: ${error.message}</p>` : ''}
            <button onclick="window.location.reload()" style="padding: 10px 20px; background: #284b44; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 14px;">Refresh Page</button>
            <p style="color: #999; font-size: 11px; margin-top: 20px;">Check browser console for details</p>
          </div>
        `;
      } else {
        document.body.innerHTML = `
          <div style="padding: 20px; text-align: center; font-family: Arial, sans-serif; background: #f8f4f0; min-height: 100vh; display: flex; align-items: center; justify-content: center;">
            <div>
              <h1 style="color: #dc2626; margin-bottom: 10px;">Application Error</h1>
              <p style="color: #666; margin-bottom: 20px;">${message}</p>
              ${error ? `<p style="color: #999; font-size: 12px;">Error: ${error.message}</p>` : ''}
              <button onclick="window.location.reload()" style="margin-top: 20px; padding: 10px 20px; background: #284b44; color: white; border: none; border-radius: 5px; cursor: pointer;">Refresh Page</button>
            </div>
          </div>
        `;
      }
    }
  } catch (error) {
    console.error('❌ Fatal error in main.js:', error);
    // Show error message instead of blank screen
    const loading = document.getElementById('app-loading');
    if (loading) {
      loading.innerHTML = `
        <div style="text-align: center; font-family: Arial, sans-serif;">
          <h1 style="color: #dc2626; margin-bottom: 10px;">Fatal Error</h1>
          <p style="color: #666; margin-bottom: 20px;">Failed to load application. Please refresh the page.</p>
          <p style="color: #999; font-size: 12px; margin-bottom: 20px;">Error: ${error.message}</p>
          <button onclick="window.location.reload()" style="padding: 10px 20px; background: #284b44; color: white; border: none; border-radius: 5px; cursor: pointer;">Refresh Page</button>
        </div>
      `;
    } else {
      document.body.innerHTML = `
        <div style="padding: 20px; text-align: center; font-family: Arial, sans-serif; background: #f8f4f0; min-height: 100vh; display: flex; align-items: center; justify-content: center;">
          <div>
            <h1 style="color: #dc2626; margin-bottom: 10px;">Fatal Error</h1>
            <p style="color: #666; margin-bottom: 20px;">Failed to load application. Please refresh the page.</p>
            <p style="color: #999; font-size: 12px;">Error: ${error.message}</p>
            <button onclick="window.location.reload()" style="margin-top: 20px; padding: 10px 20px; background: #284b44; color: white; border: none; border-radius: 5px; cursor: pointer;">Refresh Page</button>
          </div>
        </div>
      `;
    }
  }
})();

