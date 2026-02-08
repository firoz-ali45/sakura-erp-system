import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../services/api';
import { loginWithSupabase, initSupabase, supabaseClient, USE_SUPABASE } from '../services/supabase';

export const useAuthStore = defineStore('auth', () => {
  // Restore user from localStorage on initialization - safe check
  let savedUser = null;
  let initialUser = null;
  let savedToken = null;
  let sakuraLoggedIn = false;
  let tabLogin = null;
  
  try {
    if (typeof window !== 'undefined' && window.localStorage) {
      savedUser = localStorage.getItem('sakura_current_user');
      initialUser = savedUser ? JSON.parse(savedUser) : null;
      savedToken = localStorage.getItem('token') || null;
      sakuraLoggedIn = localStorage.getItem('sakura_logged_in') === 'true';
    }
    if (typeof window !== 'undefined' && window.sessionStorage) {
      tabLogin = sessionStorage.getItem('sakura_tab_login');
    }
  } catch (e) {
    console.warn('⚠️ Error reading from storage:', e);
  }
  
  const user = ref(initialUser);
  const token = ref(savedToken);

  // User is authenticated if:
  // 1. Token exists AND user exists, OR
  // 2. sakura_logged_in is true (for Supabase/localStorage auth)
  const isAuthenticated = computed(() => {
    if (token.value && user.value) return true;
    if (sakuraLoggedIn && (tabLogin || user.value)) return true;
    return false;
  });

  // Set auth token
  function setToken(newToken) {
    token.value = newToken;
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        if (newToken) {
          localStorage.setItem('token', newToken);
          if (api && api.defaults && api.defaults.headers) {
            api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`;
          }
        } else {
          localStorage.removeItem('token');
          if (api && api.defaults && api.defaults.headers) {
            delete api.defaults.headers.common['Authorization'];
          }
        }
      }
    } catch (e) {
      console.warn('⚠️ Error setting token:', e);
    }
  }

  // Set user
  function setUser(userData) {
    user.value = userData;
    // Persist user to localStorage
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        if (userData) {
          localStorage.setItem('sakura_current_user', JSON.stringify(userData));
        } else {
          localStorage.removeItem('sakura_current_user');
        }
      }
    } catch (e) {
      console.warn('⚠️ Error setting user:', e);
    }
  }

  // Login - Try Supabase first, fallback to API (only in development)
  async function login(email, password) {
    // Check if we're on production (Surge) - safe check
    const isProduction = typeof window !== 'undefined' && 
                        window.location && 
                        window.location.hostname && (
      window.location.hostname.includes('surge.sh') ||
      window.location.hostname.includes('vercel.app') ||
      window.location.hostname.includes('netlify.app')
    );
    
    // Try Supabase login first (always)
    try {
      const supabaseResult = await loginWithSupabase(email, password);
      if (supabaseResult.success && supabaseResult.user) {
        // Create a token for compatibility (use user ID as token)
        const token = `supabase_${supabaseResult.user.id}`;
        setToken(token);
        setUser(supabaseResult.user);
        // Set session persistence flags
        localStorage.setItem('sakura_logged_in', 'true');
        const tabId = sessionStorage.getItem('sakura_tab_id') || `tab_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        if (!sessionStorage.getItem('sakura_tab_id')) {
          sessionStorage.setItem('sakura_tab_id', tabId);
        }
        sessionStorage.setItem('sakura_tab_login', tabId);
        return { success: true };
      } else if (supabaseResult.error) {
        // In production, only use Supabase - don't try API
        if (isProduction) {
          return {
            success: false,
            error: supabaseResult.error || 'Login failed. Please check your credentials.'
          };
        }
        // In development, try API fallback
        console.warn('Supabase login failed, trying API:', supabaseResult.error);
      }
    } catch (error) {
      // In production, only use Supabase - don't try API
      if (isProduction) {
        return {
          success: false,
          error: error.message || 'Login failed. Please check your credentials.'
        };
      }
      // In development, try API fallback
      console.warn('Supabase login error, trying API:', error);
    }
    
    // Fallback to API login (ONLY in development)
    if (isProduction) {
      // In production, Supabase is the only authentication method
      return {
        success: false,
        error: 'Login failed. Please check your credentials.'
      };
    }
    
    try {
      const response = await api.post('/auth/login', { email, password });
      
      if (response.data.success && response.data.data) {
        const { user: userData, token: authToken } = response.data.data;
        
        setToken(authToken);
        setUser(userData);
        // Set session persistence flags
        localStorage.setItem('sakura_logged_in', 'true');
        const tabId = sessionStorage.getItem('sakura_tab_id') || `tab_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        if (!sessionStorage.getItem('sakura_tab_id')) {
          sessionStorage.setItem('sakura_tab_id', tabId);
        }
        sessionStorage.setItem('sakura_tab_login', tabId);
        
        return { success: true };
      } else {
        return {
          success: false,
          error: response.data.error || 'Login failed'
        };
      }
    } catch (error) {
      console.error('Login API error:', error);
      
      let errorMessage = 'Login failed. Please check your credentials.';
      
      if (error.code === 'ECONNREFUSED' || error.message?.includes('Network Error') || error.code === 'ERR_NETWORK') {
        errorMessage = 'Backend server not running. Please start the backend server on port 3000, or use Supabase authentication.';
      } else if (error.response?.data?.error) {
        errorMessage = error.response.data.error;
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      return {
        success: false,
        error: errorMessage
      };
    }
  }

  // Logout
  async function logout() {
    setToken(null);
    setUser(null);
    // Clear login state
    localStorage.removeItem('sakura_logged_in');
    localStorage.removeItem('sakura_current_user');
    localStorage.removeItem('token');
    sessionStorage.removeItem('sakura_tab_login');
    sessionStorage.removeItem('sakura_tab_id');

    // Best-effort Supabase sign-out (if auth was ever initialized)
    try {
      await initSupabase();
      if (USE_SUPABASE && supabaseClient?.auth?.signOut) {
        await supabaseClient.auth.signOut();
      }
    } catch (err) {
      console.warn('Supabase sign-out skipped:', err?.message || err);
    }
  }

  // Ensure the current session user still exists and is active in Supabase/local store
  async function ensureUserStillExists() {
    if (!user.value?.email) return true;

    // Try Supabase first
    try {
      await initSupabase();
      if (USE_SUPABASE && supabaseClient) {
        const { data, error } = await supabaseClient
          .from('users')
          .select('status')
          .eq('email', user.value.email.toLowerCase())
          .single();

        const notFound = error?.code === 'PGRST116' || error?.details?.includes('Results contain 0 rows');
        if (error && !notFound) {
          throw error;
        }
        if (!data || notFound || (data.status && data.status !== 'active')) {
          await logout();
          return false;
        }
        return true;
      }
    } catch (err) {
      console.warn('ensureUserStillExists supabase check skipped:', err?.message || err);
    }

    // Fallback: if we rely on localStorage users, ensure user is still present
    try {
      const users = JSON.parse(localStorage.getItem('sakura_users') || '[]');
      const exists = users.some(
        (u) => u.email?.toLowerCase() === user.value.email.toLowerCase() && (u.status || 'active') === 'active'
      );
      if (!exists) {
        await logout();
        return false;
      }
    } catch (err) {
      console.warn('ensureUserStillExists local check skipped:', err?.message || err);
    }

    return true;
  }

  // Get current user
  async function fetchCurrentUser() {
    try {
      const response = await api.get('/auth/me');
      setUser(response.data.data.user);
      return { success: true };
    } catch (error) {
      logout();
      return { success: false };
    }
  }

  // Initialize auth from localStorage
  if (token.value) {
    api.defaults.headers.common['Authorization'] = `Bearer ${token.value}`;
    // Only fetch if user is not already restored from localStorage
    if (!user.value) {
      fetchCurrentUser();
    }
  } else if (sakuraLoggedIn && user.value) {
    // Supabase/localStorage auth - user already restored, just verify session
    console.log('✅ Restored user session from localStorage:', user.value.email);
  }

  return {
    user,
    token,
    isAuthenticated,
    login,
    logout,
    ensureUserStillExists,
    fetchCurrentUser,
    setToken,
    setUser
  };
});

