/**
 * Production Logger - Removes console.log in production builds
 * Errors and warnings are kept for debugging
 */

const isDevelopment = import.meta.env.DEV || typeof window !== 'undefined' && window.location.hostname === 'localhost';

export const logger = {
  log: isDevelopment ? console.log.bind(console) : () => {},
  error: console.error.bind(console),
  warn: console.warn.bind(console),
  info: isDevelopment ? console.info.bind(console) : () => {},
  debug: isDevelopment ? console.debug.bind(console) : () => {},
};
