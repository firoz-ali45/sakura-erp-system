/**
 * Platform branding (Nexora ERP SaaS). Override per tenant via Vite env, e.g.
 * VITE_APP_DISPLAY_NAME="Client Name ERP", VITE_APP_LOGO_PATH=/client-logo.png
 */
export const APP_DISPLAY_NAME = import.meta.env.VITE_APP_DISPLAY_NAME || 'Nexora ERP';
export const APP_HUB_TITLE = import.meta.env.VITE_APP_HUB_TITLE || 'Nexora Management Hub';
export const APP_PORTAL_FOOTER = import.meta.env.VITE_APP_PORTAL_FOOTER || 'Nexora Portal ©';
export const APP_AI_ASSISTANT_NAME = import.meta.env.VITE_APP_AI_NAME || 'Nexora AI Assistant';
export const APP_MANAGEMENT_SYSTEM = import.meta.env.VITE_APP_MANAGEMENT_SYSTEM || 'Nexora ERP Management System';
/**
 * Client/tenant identity for white-label builds.
 * If this changes between deployments, we auto-clear saved login state so users don't "auto-login"
 * into the wrong client (common when switching Sakura vs Nexora on same browser).
 */
export const APP_CLIENT_ID =
  import.meta.env.VITE_APP_CLIENT_ID ||
  import.meta.env.VITE_APP_CLIENT_SLUG ||
  String(import.meta.env.VITE_APP_DISPLAY_NAME || 'Nexora ERP')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
/** Default logo assets (replace files in /public or set VITE_APP_LOGO_PATH). */
export const APP_LOGO_PATH = import.meta.env.VITE_APP_LOGO_PATH || '/nexora-brand-logo.png';
export const APP_LOGO_FALLBACK = import.meta.env.VITE_APP_LOGO_FALLBACK || '/nexora-logo-fallback.png';
