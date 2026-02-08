<template>
  <div class="min-h-screen bg-[#f0e1cd] p-6">
    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-800" data-key="manage">Manage</h1>
    </div>

    <!-- Cards Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <!-- Delivery Zones Card -->
      <div 
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer"
        @click="navigateTo('delivery-zones')"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <i class="fas fa-map-marker-alt text-blue-600 text-xl"></i>
            </div>
            <div>
              <h3 class="font-semibold text-gray-800 text-lg">Delivery Zones</h3>
            </div>
          </div>
          <i class="fas fa-chevron-right text-gray-400"></i>
        </div>
      </div>

      <!-- Tags Card -->
      <div 
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer"
        @click="navigateTo('tags')"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <i class="fas fa-tags text-purple-600 text-xl"></i>
            </div>
            <div>
              <h3 class="font-semibold text-gray-800 text-lg" data-key="tags">Tags</h3>
            </div>
          </div>
          <i class="fas fa-chevron-right text-gray-400"></i>
        </div>
      </div>

      <!-- Online Ordering Card -->
      <div 
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer"
        @click="navigateTo('online-ordering')"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <i class="fas fa-shopping-cart text-green-600 text-xl"></i>
            </div>
            <div>
              <h3 class="font-semibold text-gray-800 text-lg">Online Ordering</h3>
            </div>
          </div>
          <i class="fas fa-chevron-right text-gray-400"></i>
        </div>
      </div>

      <!-- Notifications Card -->
      <div 
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer relative"
        @click="navigateTo('notifications')"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
              <i class="fas fa-bell text-yellow-600 text-xl"></i>
            </div>
            <div>
              <h3 class="font-semibold text-gray-800 text-lg">Notifications</h3>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span class="bg-green-500 text-white text-xs font-bold px-2 py-1 rounded-full">New!</span>
            <i class="fas fa-chevron-right text-gray-400"></i>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue';
import { translatePage } from '@/utils/i18n';

const navigateTo = (route) => {
  if (route === 'tags') {
    // Navigate to Tags page
    if (window.parent && window.parent.loadDashboard) {
      window.parent.loadDashboard('manage-tags');
    } else if (window.loadDashboard) {
      window.loadDashboard('manage-tags');
    } else {
      // Fallback: use postMessage
      window.parent.postMessage({ type: 'LOAD_DASHBOARD', dashboard: 'manage-tags' }, '*');
    }
  } else {
    // Other routes - to be implemented
    showNotification(`${route} functionality - To be implemented`, 'info');
  }
};

const showNotification = (message, type = 'info', duration = 3000) => {
  if (window.showNotification) {
    window.showNotification(message, type, duration);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

onMounted(() => {
  // Initialize language
  const savedLang = localStorage.getItem('portalLang') || 'en';
  translatePage(savedLang);
});
</script>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}
</style>

