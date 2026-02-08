/**
 * GLOBAL LANGUAGE STORE
 * ====================
 * 
 * Single source of truth for language and direction in the entire ERP system.
 * 
 * This store:
 * - Manages current language (en | ar)
 * - Manages direction (ltr | rtl)
 * - Persists to localStorage
 * - Syncs with Vue i18n
 * - Updates document direction globally
 * 
 * USAGE:
 * ```js
 * import { useLanguageStore } from '@/stores/language';
 * 
 * const languageStore = useLanguageStore();
 * languageStore.setLanguage('ar'); // Changes to Arabic + RTL
 * ```
 */

import { defineStore } from 'pinia';
import { ref, computed, watch } from 'vue';
import i18n from '@/i18n';
import { updateDocumentDirection } from '@/i18n';

const STORAGE_KEY = 'sakura_language';

export const useLanguageStore = defineStore('language', () => {
  // Get initial language from storage or default to 'ar' (as per user requirement)
  function getInitialLanguage() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY) || 
                     localStorage.getItem('portalLang') || 
                     localStorage.getItem('sakura_lang') ||
                     (window.currentLang && window.currentLang !== 'undefined' ? window.currentLang : null);
      
      // Validate it's a supported locale
      if (stored && (stored === 'en' || stored === 'ar')) {
        return stored;
      }
    } catch (e) {
      console.warn('Could not read language from storage:', e);
    }
    
    return 'ar'; // Default to Arabic as per ERP standard
  }

  // State
  const language = ref(getInitialLanguage());
  const direction = computed(() => language.value === 'ar' ? 'rtl' : 'ltr');
  const isRTL = computed(() => language.value === 'ar');

  /**
   * Set language and update everything
   */
  function setLanguage(newLang) {
    if (newLang !== 'en' && newLang !== 'ar') {
      console.warn(`Unsupported language: ${newLang}. Falling back to 'ar'.`);
      newLang = 'ar';
    }

    // Update store
    language.value = newLang;

    // Update Vue i18n
    if (i18n.global) {
      i18n.global.locale.value = newLang;
    }

    // Persist to storage (all possible keys for compatibility)
    try {
      localStorage.setItem(STORAGE_KEY, newLang);
      localStorage.setItem('portalLang', newLang);
      localStorage.setItem('sakura_lang', newLang);
      if (window.currentLang !== undefined) {
        window.currentLang = newLang;
      }
    } catch (e) {
      console.warn('Could not persist language to storage:', e);
    }

    // Update document direction globally
    updateDocumentDirection(newLang);

    // Broadcast change for iframes and cross-tab communication
    try {
      window.dispatchEvent(new CustomEvent('locale-changed', { 
        detail: { locale: newLang, direction: direction.value } 
      }));
      
      // Post message to iframes
      if (window.parent && window.parent !== window) {
        window.parent.postMessage({ 
          type: 'locale-changed', 
          locale: newLang,
          direction: direction.value 
        }, '*');
      }

      // Send to all iframes in current window
      document.querySelectorAll('iframe').forEach(iframe => {
        try {
          if (iframe.contentWindow) {
            iframe.contentWindow.postMessage({ 
              type: 'SET_LANGUAGE', 
              lang: newLang 
            }, '*');
            iframe.contentWindow.postMessage({ 
              type: 'LANGUAGE_CHANGE', 
              language: newLang 
            }, '*');
          }
        } catch (error) {
          console.warn('Could not send language message to iframe:', error);
        }
      });
    } catch (e) {
      console.warn('Could not broadcast language change:', e);
    }

    console.log(`🌐 Language changed to: ${newLang} (${direction.value})`);
  }

  /**
   * Initialize language on store creation
   */
  function initialize() {
    const initialLang = getInitialLanguage();
    if (initialLang !== language.value) {
      setLanguage(initialLang);
    } else {
      // Still update document direction even if language hasn't changed
      updateDocumentDirection(initialLang);
    }
  }

  /**
   * Watch for external language changes (from other tabs, localStorage, etc.)
   */
  if (typeof window !== 'undefined') {
    // Listen for storage events (cross-tab)
    window.addEventListener('storage', (e) => {
      if (e.key === STORAGE_KEY || e.key === 'portalLang' || e.key === 'sakura_lang') {
        const newLang = e.newValue;
        if (newLang && (newLang === 'en' || newLang === 'ar') && newLang !== language.value) {
          setLanguage(newLang);
        }
      }
    });

    // Listen for custom locale-changed events
    window.addEventListener('locale-changed', (e) => {
      if (e.detail && e.detail.locale && e.detail.locale !== language.value) {
        setLanguage(e.detail.locale);
      }
    });

    // Listen for postMessage events (from iframes/parent windows)
    window.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'SET_LANGUAGE' && event.data.lang) {
        const newLang = event.data.lang;
        if ((newLang === 'en' || newLang === 'ar') && newLang !== language.value) {
          setLanguage(newLang);
        }
      }
    });
  }

  // Initialize on store creation
  initialize();

  return {
    language,
    direction,
    isRTL,
    setLanguage,
    initialize
  };
});

