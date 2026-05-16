/**
 * Sakura ERP branding. Override per deployment via Vite env.
 */
function _host() {
  try {
    return (typeof window !== 'undefined' && window.location?.hostname)
      ? String(window.location.hostname).toLowerCase()
      : '';
  } catch {
    return '';
  }
}

function _subdomain(hostname) {
  if (!hostname) return '';
  const parts = hostname.split('.').filter(Boolean);
  if (parts.length < 3) return parts[0] || '';
  return parts[0] || '';
}

function _runtimeBrandFromHost() {
  const sub = _subdomain(_host());
  if (sub === 'sakura') {
    return {
      clientId: 'sakura',
      displayName: 'Sakura ERP',
      hubTitle: 'Sakura Management Hub',
      portalFooter: 'Sakura Portal ©',
      aiName: 'Sakura AI Assistant',
      systemName: 'Sakura ERP Management System',
      logoPath: '/sakura-logo.png',
      logoFallback: '/sakura-logo.png'
    };
  }
  return null;
}

const _runtime = _runtimeBrandFromHost();

export const APP_DISPLAY_NAME =
  _runtime?.displayName || import.meta.env.VITE_APP_DISPLAY_NAME || 'Sakura ERP';
export const APP_HUB_TITLE =
  _runtime?.hubTitle || import.meta.env.VITE_APP_HUB_TITLE || 'Sakura Management Hub';
export const APP_PORTAL_FOOTER =
  _runtime?.portalFooter || import.meta.env.VITE_APP_PORTAL_FOOTER || 'Sakura Portal ©';
export const APP_AI_ASSISTANT_NAME =
  _runtime?.aiName || import.meta.env.VITE_APP_AI_NAME || 'Sakura AI Assistant';
export const APP_MANAGEMENT_SYSTEM =
  _runtime?.systemName || import.meta.env.VITE_APP_MANAGEMENT_SYSTEM || 'Sakura ERP Management System';

export const APP_CLIENT_ID =
  _runtime?.clientId ||
  import.meta.env.VITE_APP_CLIENT_ID ||
  import.meta.env.VITE_APP_CLIENT_SLUG ||
  String(import.meta.env.VITE_APP_DISPLAY_NAME || APP_DISPLAY_NAME || 'Sakura ERP')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');

export const APP_LOGO_PATH =
  _runtime?.logoPath || import.meta.env.VITE_APP_LOGO_PATH || '/sakura-logo.png';
export const APP_LOGO_FALLBACK =
  _runtime?.logoFallback || import.meta.env.VITE_APP_LOGO_FALLBACK || '/sakura-logo.png';
