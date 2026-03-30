/**
 * Platform branding (Nexora ERP SaaS). Override per tenant via Vite env, e.g.
 * VITE_APP_DISPLAY_NAME="Client Name ERP", VITE_APP_LOGO_PATH=/client-logo.png
 */
function _host() {
  try {
    return (typeof window !== 'undefined' && window.location?.hostname) ? String(window.location.hostname).toLowerCase() : '';
  } catch {
    return '';
  }
}

function _subdomain(hostname) {
  if (!hostname) return '';
  // e.g. sakura.nexoraerp.com -> sakura, admin.nexoraerp.com -> admin
  const parts = hostname.split('.').filter(Boolean);
  if (parts.length < 3) return parts[0] || ''; // vercel.app has 3+, localhost has 1
  return parts[0] || '';
}

function _runtimeBrandFromHost() {
  const h = _host();
  const sub = _subdomain(h);
  const looksSakura = sub === 'sakura' || h.includes('sakura');
  const looksAdmin = sub === 'admin' || sub === 'platform';
  if (looksAdmin) {
    return {
      clientId: 'nexora-admin',
      displayName: 'Nexora ERP',
      hubTitle: 'Nexora Admin Console',
      portalFooter: 'Nexora ©',
      aiName: 'Nexora AI Assistant',
      systemName: 'Nexora ERP Management System',
      logoPath: '/nexora-brand-logo.png',
      logoFallback: '/nexora-logo-fallback.png'
    };
  }
  if (looksSakura) {
    return {
      clientId: 'sakura',
      displayName: 'Sakura ERP',
      hubTitle: 'Sakura Management Hub',
      portalFooter: 'Sakura Portal ©',
      aiName: 'Sakura AI Assistant',
      systemName: 'Sakura ERP Management System',
      // Allow overriding logos via env, otherwise fallback to Nexora assets (can be replaced with Sakura assets later)
      logoPath: '/nexora-brand-logo.png',
      logoFallback: '/nexora-logo-fallback.png'
    };
  }
  return null;
}

const _runtime = _runtimeBrandFromHost();

// Runtime host branding takes precedence. If not matched, fall back to env → defaults.
export const APP_DISPLAY_NAME = _runtime?.displayName || import.meta.env.VITE_APP_DISPLAY_NAME || 'Nexora ERP';
export const APP_HUB_TITLE = _runtime?.hubTitle || import.meta.env.VITE_APP_HUB_TITLE || 'Nexora Management Hub';
export const APP_PORTAL_FOOTER = _runtime?.portalFooter || import.meta.env.VITE_APP_PORTAL_FOOTER || 'Nexora Portal ©';
export const APP_AI_ASSISTANT_NAME = _runtime?.aiName || import.meta.env.VITE_APP_AI_NAME || 'Nexora AI Assistant';
export const APP_MANAGEMENT_SYSTEM = _runtime?.systemName || import.meta.env.VITE_APP_MANAGEMENT_SYSTEM || 'Nexora ERP Management System';
/**
 * Client/tenant identity for white-label builds.
 * If this changes between deployments, we auto-clear saved login state so users don't "auto-login"
 * into the wrong client (common when switching Sakura vs Nexora on same browser).
 */
export const APP_CLIENT_ID =
  _runtime?.clientId ||
  import.meta.env.VITE_APP_CLIENT_ID ||
  import.meta.env.VITE_APP_CLIENT_SLUG ||
  String(import.meta.env.VITE_APP_DISPLAY_NAME || APP_DISPLAY_NAME || 'Nexora ERP')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
/** Default logo assets (replace files in /public or set VITE_APP_LOGO_PATH). */
export const APP_LOGO_PATH = _runtime?.logoPath || import.meta.env.VITE_APP_LOGO_PATH || '/nexora-brand-logo.png';
export const APP_LOGO_FALLBACK = _runtime?.logoFallback || import.meta.env.VITE_APP_LOGO_FALLBACK || '/nexora-logo-fallback.png';
