<template>
  <div id="app">
    <router-view />
    <SakuraAIAssistant />
    
    <!-- Global Notification System -->
    <div class="fixed top-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
      <transition-group name="toast">
        <div 
          v-for="note in notifications" 
          :key="note.id" 
          class="pointer-events-auto min-w-[300px] max-w-md p-4 rounded-lg shadow-lg border-l-4 transform transition-all duration-300 ease-in-out flex items-start gap-3 backdrop-blur-sm"
          :class="{
            'bg-white/95 border-blue-500 text-gray-800': note.type === 'info',
            'bg-white/95 border-green-500 text-gray-800': note.type === 'success',
            'bg-white/95 border-yellow-500 text-gray-800': note.type === 'warning',
            'bg-white/95 border-red-500 text-gray-800': note.type === 'error'
          }"
        >
          <div :class="{
            'text-blue-500': note.type === 'info',
            'text-green-500': note.type === 'success',
            'text-yellow-500': note.type === 'warning',
            'text-red-500': note.type === 'error'
          }">
            <i class="fas" :class="{
              'fa-info-circle': note.type === 'info',
              'fa-check-circle': note.type === 'success',
              'fa-exclamation-triangle': note.type === 'warning',
              'fa-times-circle': note.type === 'error'
            }"></i>
          </div>
          <div class="flex-1 text-sm font-medium">{{ note.message }}</div>
          <button @click="removeNotification(note.id)" class="text-gray-400 hover:text-gray-600">
            <i class="fas fa-times"></i>
          </button>
        </div>
      </transition-group>
    </div>
  </div>
</template>

<script setup>
import SakuraAIAssistant from '@/components/SakuraAIAssistant.vue';
import { ref, onMounted } from 'vue';

// Main App component - router handles all navigation

// Notification System
const notifications = ref([]);
let nextId = 0;

const showNotification = (message, type = 'info') => {
  const id = nextId++;
  notifications.value.push({ id, message, type });
  
  // Auto remove after 5 seconds
  setTimeout(() => {
    removeNotification(id);
  }, 5000);
};

const removeNotification = (id) => {
  const index = notifications.value.findIndex(n => n.id === id);
  if (index !== -1) {
    notifications.value.splice(index, 1);
  }
};

onMounted(() => {
  // Expose to window for global access
  window.showNotification = showNotification;
  console.log('🔔 Global notification system initialized');
});
</script>

<style scoped>
/* Layout handled by global style.css */

/* Toast Transitions */
.toast-enter-active,
.toast-leave-active {
  transition: all 0.3s ease;
}

.toast-enter-from {
  opacity: 0;
  transform: translateX(30px);
}

.toast-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
</style>

