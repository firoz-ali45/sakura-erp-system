/**
 * ENTERPRISE-GRADE i18n SYSTEM
 * =============================
 * 
 * This is the CENTRALIZED, UNIFIED internationalization system for Sakura ERP.
 * 
 * CORE PRINCIPLES:
 * 1. NO hardcoded user-facing text anywhere
 * 2. ALL text comes from locale JSON files
 * 3. Language selection controls: text, direction, alignment, formatting
 * 4. Scalable for future languages
 * 
 * USAGE:
 * - In templates: {{ $t('inventory.items.title') }}
 * - In script: const { t } = useI18n(); t('inventory.items.title')
 * - For statuses: $t(`status.${statusKey}`)
 * 
 * NEVER use:
 * - Hardcoded strings in templates
 * - Conditional language logic in components
 * - Direct locale object access
 */

import { createI18n } from 'vue-i18n';
import en from '../locales/en.json';
import ar from '../locales/ar.json';

/**
 * Get initial locale from storage or default to 'ar' (ERP standard)
 */
function getInitialLocale() {
  try {
    if (typeof window === 'undefined') return 'ar'; // SSR safety
    
    // Check multiple sources for language preference
    let stored = null;
    if (window.localStorage) {
      stored = localStorage.getItem('sakura_language') ||
               localStorage.getItem('portalLang') || 
               localStorage.getItem('sakura_lang');
    }
    
    if (!stored && window.currentLang && window.currentLang !== 'undefined') {
      stored = window.currentLang;
    }
    
    // Validate it's a supported locale
    if (stored && (stored === 'en' || stored === 'ar')) {
      return stored;
    }
  } catch (e) {
    console.warn('Could not read locale from storage:', e);
  }
  
  return 'ar'; // Default to Arabic as per ERP standard
}

/**
 * Configure i18n instance
 */
const i18n = createI18n({
  legacy: false, // Use Composition API mode
  locale: getInitialLocale(),
  fallbackLocale: 'en',
  messages: {
    en,
    ar
  },
  // Global properties
  globalInjection: true, // Makes $t available in all components
  warnHtmlMessage: false, // Disable HTML warning for security
  silentTranslationWarn: false, // Show warnings for missing keys in dev
  silentFallbackWarn: false
});

/**
 * GLOBAL RTL/LTR HANDLER
 * ======================
 * 
 * This function updates the document direction and body classes
 * when the locale changes. It should be called:
 * 1. On initial load
 * 2. When locale changes
 * 
 * DO NOT handle RTL/LTR in individual components.
 * 
 * This is the ONLY place where document direction is set.
 */
export function updateDocumentDirection(locale) {
  try {
    if (typeof document === 'undefined') return; // SSR safety
    if (!document.documentElement || !document.body) return; // DOM not ready
    
    const isRTL = locale === 'ar';
    const direction = isRTL ? 'rtl' : 'ltr';
    
    // Update HTML element (CRITICAL - this affects entire page)
    if (document.documentElement) {
      document.documentElement.setAttribute('dir', direction);
      document.documentElement.setAttribute('lang', locale);
      
      // Add CSS custom property for direction (for advanced styling)
      document.documentElement.style.setProperty('--direction', direction);
      document.documentElement.style.setProperty('--text-align', isRTL ? 'right' : 'left');
    }
    
    // Update body element
    if (document.body) {
      document.body.setAttribute('dir', direction);
      
      // Update body classes (for CSS targeting)
      document.body.classList.remove('rtl', 'ltr', 'rtl-mode', 'ltr-mode', 'text-left', 'text-right');
      document.body.classList.add(direction, `${direction}-mode`);
      document.body.classList.add(isRTL ? 'text-right' : 'text-left');
    }
    
    console.log(`🌐 Document direction updated: ${direction} (locale: ${locale})`);
  } catch (error) {
    console.warn('Error updating document direction:', error);
  }
}

/**
 * Watch for locale changes in Vue i18n and update direction
 */
if (typeof window !== 'undefined' && i18n.global && i18n.global.locale) {
  try {
    // Initialize direction on load
    updateDocumentDirection(i18n.global.locale.value);
  } catch (error) {
    console.warn('Could not initialize document direction:', error);
  }
}

// Export the i18n instance
export default i18n;

// Export helper functions
export { getInitialLocale };

