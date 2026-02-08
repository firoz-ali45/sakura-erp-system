import axios from 'axios';

// Detect production environment (Surge deployment)
const isProduction = window.location.hostname.includes('surge.sh') || 
                     window.location.hostname.includes('vercel.app') ||
                     window.location.hostname.includes('netlify.app') ||
                     import.meta.env.PROD;

// Get API URL - prioritize environment variable, then detect production
const getApiUrl = () => {
  // If environment variable is set, use it
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL;
  }
  
  // If production (deployed on Surge), backend API is optional
  // System uses Supabase for most features, backend is only for AI features
  if (isProduction) {
    // Return a placeholder URL that will fail gracefully
    // System will use Supabase for authentication and data
    // Backend can be deployed separately to a public URL if needed
    return 'https://sakura-erp-backend.onrender.com/api'; // Placeholder - can be updated when backend is deployed
  }
  
  // Development - use localhost
  return 'http://localhost:3000/api';
};

const api = axios.create({
  baseURL: getApiUrl(),
  headers: {
    'Content-Type': 'application/json'
  },
  timeout: 5000, // 5 second timeout - fail fast if backend unavailable
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Handle network errors gracefully in production (backend might not be available)
    if (isProduction && (error.code === 'ERR_NETWORK' || error.code === 'ECONNREFUSED' || error.message?.includes('Network Error'))) {
      // In production, backend API is optional - system uses Supabase
      // Only log error, don't throw for non-critical endpoints
      const isCriticalEndpoint = error.config?.url?.includes('/auth/login') || error.config?.url?.includes('/auth/signup');
      if (!isCriticalEndpoint) {
        console.warn('Backend API unavailable (optional feature). Using Supabase fallback.');
        // Return a rejected promise but don't break the app
        return Promise.reject(error);
      }
    }
    
    if (error.response?.status === 401) {
      // Only redirect if it's an actual authentication error (not a missing endpoint)
      // Check if error is from auth endpoint or if token exists
      const token = localStorage.getItem('token');
      const sakuraLoggedIn = localStorage.getItem('sakura_logged_in') === 'true';
      const hasUser = !!localStorage.getItem('sakura_current_user');
      const isAuthEndpoint = error.config?.url?.includes('/auth/');
      const isSupabaseAuth = token?.startsWith('supabase_');
      
      // Don't redirect if:
      // 1. Using Supabase auth (token starts with 'supabase_') - Supabase handles its own auth
      // 2. No token and not auth endpoint - might be missing endpoint
      // 3. Error is from a non-critical endpoint (like optional API calls)
      
      // Only redirect if:
      // 1. It's an auth endpoint (login/signup) AND we have auth state, OR
      // 2. We have a real JWT token (not Supabase token) AND it's a critical endpoint
      const shouldRedirect = (isAuthEndpoint && (token || sakuraLoggedIn)) || 
                            (token && !isSupabaseAuth && !error.config?.url?.includes('/optional'));
      
      if (shouldRedirect) {
        console.warn('401 Unauthorized - redirecting to login. URL:', error.config?.url);
        // Only clear auth if it's a real auth failure
        if (isAuthEndpoint || !isSupabaseAuth) {
          localStorage.removeItem('token');
          localStorage.removeItem('sakura_logged_in');
          localStorage.removeItem('sakura_current_user');
          sessionStorage.removeItem('sakura_tab_login');
        }
        // Use router if available, otherwise window.location
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
      } else {
        // No redirect needed - might be missing endpoint or Supabase auth
        console.warn('401 Unauthorized but not redirecting. URL:', error.config?.url, 'isSupabase:', isSupabaseAuth);
      }
    }
    return Promise.reject(error);
  }
);

export default api;

