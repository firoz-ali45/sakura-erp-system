<template>
  <div class="min-h-screen bg-[#f0e1cd] flex items-center justify-center p-6">
    <div class="bg-white rounded-lg shadow-lg p-8 w-full max-w-md">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-[#284b44] mb-2">Sakura ERP</h1>
        <p class="text-gray-600">Sign in to your account</p>
        <p class="text-sm text-gray-500 mt-2">
          Don't have an account? 
          <a href="#" @click.prevent="showSignup = true" class="text-[#284b44] hover:underline">Sign up</a>
        </p>
      </div>

      <!-- Login Form -->
      <form v-if="!showSignup" @submit.prevent="handleLogin" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Email
          </label>
          <input
            v-model="email"
            type="email"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="your@email.com"
          >
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Password
          </label>
          <input
            v-model="password"
            type="password"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="••••••••"
          >
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
          {{ error }}
        </div>

        <button
          type="submit"
          :disabled="loading"
          class="w-full px-6 py-3 bg-[#284b44] text-white rounded-lg hover:bg-[#3d6b5f] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <span v-if="loading">Signing in...</span>
          <span v-else>Sign In</span>
        </button>
      </form>

      <!-- Sign Up Form -->
      <form v-else @submit.prevent="handleSignup" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Full Name
          </label>
          <input
            v-model="signupName"
            type="text"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="Your Name"
          >
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Email
          </label>
          <input
            v-model="signupEmail"
            type="email"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="your@email.com"
          >
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Password
          </label>
          <input
            v-model="signupPassword"
            type="password"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="••••••••"
          >
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Confirm Password
          </label>
          <input
            v-model="signupConfirmPassword"
            type="password"
            required
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            placeholder="••••••••"
          >
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
          {{ error }}
        </div>

        <div class="flex gap-3">
          <button
            type="button"
            @click="showSignup = false; error = ''"
            class="flex-1 px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 font-semibold"
          >
            Back to Login
          </button>
          <button
            type="submit"
            :disabled="loading"
            class="flex-1 px-6 py-3 bg-[#284b44] text-white rounded-lg hover:bg-[#3d6b5f] font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span v-if="loading">Creating...</span>
            <span v-else>Sign Up</span>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import api from '@/services/api';

const router = useRouter();
const authStore = useAuthStore();

// Tab-specific login persistence (like original index.html)
const TAB_ID_KEY = 'sakura_tab_id';
const TAB_LOGIN_KEY = 'sakura_tab_login';
const LOGIN_KEY = 'sakura_logged_in';

// Check if user is already logged in (same tab)
onMounted(() => {
  // Generate or get tab ID
  let currentTabId = sessionStorage.getItem(TAB_ID_KEY);
  if (!currentTabId) {
    currentTabId = 'tab_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    sessionStorage.setItem(TAB_ID_KEY, currentTabId);
  }
  
  // Check if this tab is logged in
  const tabLoginState = sessionStorage.getItem(TAB_LOGIN_KEY);
  const isThisTabLoggedIn = tabLoginState === currentTabId;
  const isLoggedIn = localStorage.getItem(LOGIN_KEY) === 'true';
  
  // If same tab and logged in, auto-redirect
  if (isThisTabLoggedIn && isLoggedIn && authStore.isAuthenticated) {
    console.log('⚡ Same tab - auto-login');
    router.push('/homeportal');
  }
});

const email = ref('');
const password = ref('');
const loading = ref(false);
const error = ref('');
const showSignup = ref(false);

// Sign up form fields
const signupName = ref('');
const signupEmail = ref('');
const signupPassword = ref('');
const signupConfirmPassword = ref('');

const handleLogin = async () => {
  loading.value = true;
  error.value = '';

  try {
    const result = await authStore.login(email.value, password.value);
    
    if (result.success) {
      // Mark as logged in (general)
      localStorage.setItem(LOGIN_KEY, 'true');
      
      // Ultra-fast: Mark this tab as logged in
      let tabId = sessionStorage.getItem(TAB_ID_KEY);
      if (!tabId) {
        tabId = 'tab_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        sessionStorage.setItem(TAB_ID_KEY, tabId);
      }
      sessionStorage.setItem(TAB_LOGIN_KEY, tabId);
      
      router.push('/homeportal');
    } else {
      error.value = result.error || 'Login failed. Please check your credentials.';
    }
  } catch (err) {
    console.error('Login error:', err);
    // Error message is already set from authStore.login result
    error.value = result?.error || err.response?.data?.error || 'Login failed. Please check your credentials.';
  } finally {
    loading.value = false;
  }
};

const handleSignup = async () => {
  if (signupPassword.value !== signupConfirmPassword.value) {
    error.value = 'Passwords do not match';
    return;
  }

  if (signupPassword.value.length < 6) {
    error.value = 'Password must be at least 6 characters';
    return;
  }

  loading.value = true;
  error.value = '';

  try {
    const response = await api.post('/auth/signup', {
      name: signupName.value,
      email: signupEmail.value,
      password: signupPassword.value
    });
    
    if (response.data.success) {
      error.value = 'Account created! Please wait for admin approval.';
      setTimeout(() => {
        showSignup.value = false;
        error.value = '';
      }, 3000);
    }
  } catch (err) {
    error.value = err.response?.data?.error || 'Sign up failed. Please try again.';
  } finally {
    loading.value = false;
  }
};
</script>

