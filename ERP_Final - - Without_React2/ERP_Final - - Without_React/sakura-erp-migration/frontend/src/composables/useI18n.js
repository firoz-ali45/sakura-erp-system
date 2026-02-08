/**
 * COMPOSABLE: useI18n
 * ====================
 * 
 * This composable provides a consistent way to use i18n in components.
 * It integrates with the global language store for single source of truth.
 * 
 * USAGE:
 * ```vue
 * <script setup>
 * import { useI18n } from '@/composables/useI18n';
 * 
 * const { t, locale, setLocale, isRTL } = useI18n();
 * 
 * // Use in template or script
 * const title = t('inventory.items.title');
 * 
 * // Change language (updates entire system)
 * setLocale('ar');
 * 
 * // Check direction
 * if (isRTL.value) { ... }
 * </script>
 * ```
 * 
 * This ensures:
 * - Consistent API across all components
 * - Single source of truth (language store)
 * - Automatic RTL/LTR handling
 * - Easy testing
 * - No direct i18n instance access
 */

import { computed } from 'vue';
import { useI18n as useVueI18n } from 'vue-i18n';
import { useLanguageStore } from '@/stores/language';

export function useI18n() {
  const { t: vueT, locale: vueLocale } = useVueI18n();
  const languageStore = useLanguageStore();
  
  /**
   * Enhanced translation function
   * Handles nested keys like 'inventory.items.title'
   */
  const t = (key, params = {}) => {
    try {
      return vueT(key, params);
    } catch (error) {
      console.warn(`Translation key not found: ${key}`, error);
      return key; // Fallback to key itself
    }
  };
  
  /**
   * Enhanced locale setter
   * Uses the global language store to ensure consistency
   */
  const setLocale = (newLocale) => {
    languageStore.setLanguage(newLocale);
  };
  
  /**
   * Get current locale from store (single source of truth)
   */
  const locale = computed(() => languageStore.language);
  
  /**
   * Computed property for RTL check
   */
  const isRTL = computed(() => languageStore.isRTL);
  
  /**
   * Computed property for direction
   */
  const direction = computed(() => languageStore.direction);
  
  /**
   * Computed property for text alignment class
   */
  const textAlign = computed(() => isRTL.value ? 'text-right' : 'text-left');
  
  /**
   * Computed property for flex direction
   */
  const flexDirection = computed(() => isRTL.value ? 'flex-row-reverse' : 'flex-row');
  
  return {
    t,
    locale,
    setLocale,
    isRTL,
    direction,
    textAlign,
    flexDirection
  };
}

