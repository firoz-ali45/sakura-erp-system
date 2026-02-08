/**
 * CENTRALIZED NUMBER FORMATTING UTILITY
 * Single source of truth for all number formatting
 * 
 * CRITICAL: Numbers must always be passed as raw numbers/strings
 * Formatting ONLY happens at display time in templates
 * 
 * Arabic locale uses 'ar-SA-u-nu-arab' to force Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩)
 * English locale uses 'en-US' for Western numerals (0123456789)
 */

/**
 * Format number based on locale
 * @param {number|string|null|undefined} value - Raw number (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @param {object} options - Intl.NumberFormat options
 * @returns {string} Formatted number string with correct numerals
 */
export function formatNumber(value, locale = 'en', options = {}) {
  // Handle null/undefined/empty
  if (value === null || value === undefined || value === '') {
    return locale === 'ar' ? '٠' : '0';
  }
  
  // Parse if string (remove any formatting)
  let num;
  if (typeof value === 'string') {
    // Remove all non-numeric characters except decimal point and minus
    const cleaned = value.replace(/[^\d.-]/g, '').replace(/,/g, '');
    num = parseFloat(cleaned);
  } else {
    num = Number(value);
  }
  
  // Validate
  if (isNaN(num)) {
    return locale === 'ar' ? '٠' : '0';
  }
  
  // CRITICAL: Use 'ar-SA-u-nu-arab' for Arabic-Indic numerals
  // 'u-nu-arab' is the Unicode extension for Arabic-Indic numbering system
  const localeCode = locale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US';
  
  const defaultOptions = {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
    useGrouping: true,
    ...options
  };
  
  return new Intl.NumberFormat(localeCode, defaultOptions).format(num);
}

/**
 * Format currency based on locale
 * @param {number|string|null|undefined} value - Raw number (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @returns {string} Formatted currency string (SAR) with correct numerals
 */
export function formatCurrency(value, locale = 'en') {
  if (value === null || value === undefined || value === '') {
    return locale === 'ar' ? '٠ ر.س.' : '0 SAR';
  }
  
  let num;
  if (typeof value === 'string') {
    const cleaned = value.replace(/[^\d.-]/g, '').replace(/,/g, '');
    num = parseFloat(cleaned);
  } else {
    num = Number(value);
  }
  
  if (isNaN(num)) {
    return locale === 'ar' ? '٠ ر.س.' : '0 SAR';
  }
  
  // Use formatNumber to ensure correct numerals
  const formatted = formatNumber(Math.abs(num), locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  });
  
  return locale === 'ar' ? `${formatted} ر.س.` : `SAR ${formatted}`;
}

/**
 * Format percentage based on locale
 * @param {number|string|null|undefined} value - Raw number (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @returns {string} Formatted percentage string with correct numerals
 */
export function formatPercentage(value, locale = 'en') {
  if (value === null || value === undefined || value === '') {
    return locale === 'ar' ? '٠%' : '0%';
  }
  
  let num;
  if (typeof value === 'string') {
    const cleaned = value.replace(/[^\d.-]/g, '').replace(/,/g, '');
    num = parseFloat(cleaned);
  } else {
    num = Number(value);
  }
  
  if (isNaN(num)) {
    return locale === 'ar' ? '٠%' : '0%';
  }
  
  // Use formatNumber to ensure correct numerals
  const formatted = formatNumber(num, locale, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1
  });
  
  return `${formatted}%`;
}

/**
 * Parse currency string to number
 * @param {string} currencyStr - Currency string (e.g., "SAR 1,234.56" or "١,٢٣٤.٥٦ ر.س.")
 * @returns {number} Parsed number
 */
export function parseCurrency(currencyStr) {
  if (!currencyStr || typeof currencyStr !== 'string') return 0;
  
  // Remove currency symbols and Arabic text
  const cleaned = currencyStr
    .replace(/ر\.س\.|SAR|ريال|ريال سعودي/gi, '')
    .replace(/[^\d.,-]/g, '')
    .replace(/,/g, '');
  
  return parseFloat(cleaned) || 0;
}
