/**
 * CENTRALIZED DATE/TIME FORMATTING UTILITY
 * Single source of truth for all date/time formatting
 * 
 * CRITICAL: Dates must always be passed as Date objects or valid date strings
 * Formatting ONLY happens at display time in templates
 * 
 * Arabic locale uses 'ar-SA-u-nu-arab' to force Arabic-Indic numerals in dates
 * English locale uses 'en-US' for Western numerals
 */

import { formatNumber } from './numberFormat';

/**
 * Format date based on locale
 * @param {Date|string|number} date - Raw date (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @param {object} options - Intl.DateTimeFormat options
 * @returns {string} Formatted date string with correct numerals
 */
export function formatDate(date, locale = 'en', options = {}) {
  const dateObj = date instanceof Date ? date : new Date(date);
  
  if (isNaN(dateObj.getTime())) return '';
  
  // CRITICAL: Use 'ar-SA-u-nu-arab' for Arabic-Indic numerals in dates
  const localeCode = locale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US';
  
  const defaultOptions = {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    ...options
  };
  
  return new Intl.DateTimeFormat(localeCode, defaultOptions).format(dateObj);
}

/**
 * Format date and time based on locale
 * @param {Date|string|number} date - Raw date (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @returns {string} Formatted date and time string with correct numerals
 */
export function formatDateTime(date, locale = 'en') {
  const dateObj = date instanceof Date ? date : new Date(date);
  
  if (isNaN(dateObj.getTime())) return '';
  
  // CRITICAL: Use 'ar-SA-u-nu-arab' for Arabic-Indic numerals in date/time
  const localeCode = locale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US';
  
  return new Intl.DateTimeFormat(localeCode, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    numberingSystem: locale === 'ar' ? 'arab' : 'latn'
  }).format(dateObj);
}

/**
 * Format time only based on locale
 * @param {Date|string|number} date - Raw date (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @returns {string} Formatted time string with correct numerals
 */
export function formatTime(date, locale = 'en') {
  const dateObj = date instanceof Date ? date : new Date(date);
  
  if (isNaN(dateObj.getTime())) return '';
  
  // CRITICAL: Use 'ar-SA-u-nu-arab' for Arabic-Indic numerals in time
  const localeCode = locale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US';
  
  return new Intl.DateTimeFormat(localeCode, {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    numberingSystem: locale === 'ar' ? 'arab' : 'latn'
  }).format(dateObj);
}

/**
 * Format relative time (e.g., "2 hours ago")
 * @param {Date|string|number} date - Raw date (never pre-formatted)
 * @param {string} locale - Locale code ('ar' or 'en')
 * @returns {string} Formatted relative time string with correct numerals
 */
export function formatRelativeTime(date, locale = 'en') {
  const dateObj = date instanceof Date ? date : new Date(date);
  const now = new Date();
  const diffMs = now - dateObj;
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);
  
  if (locale === 'ar') {
    if (diffSecs < 60) return 'الآن';
    if (diffMins < 60) return `منذ ${formatNumber(diffMins, locale)} دقيقة`;
    if (diffHours < 24) return `منذ ${formatNumber(diffHours, locale)} ساعة`;
    if (diffDays < 7) return `منذ ${formatNumber(diffDays, locale)} يوم`;
    return formatDate(dateObj, locale);
  } else {
    if (diffSecs < 60) return 'Just now';
    if (diffMins < 60) return `${formatNumber(diffMins, locale)} minute${diffMins > 1 ? 's' : ''} ago`;
    if (diffHours < 24) return `${formatNumber(diffHours, locale)} hour${diffHours > 1 ? 's' : ''} ago`;
    if (diffDays < 7) return `${formatNumber(diffDays, locale)} day${diffDays > 1 ? 's' : ''} ago`;
    return formatDate(dateObj, locale);
  }
}
