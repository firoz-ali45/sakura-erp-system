<template>
  <div class="reports-page-container">
    <iframe
      id="food-quality-frame"
      :src="iframeSrc"
      class="reports-iframe"
      @load="handleIframeLoad"
      @error="handleIframeError"
    ></iframe>
    <div v-if="loading" class="absolute inset-0 bg-white z-10">
      <div class="h-full w-full flex items-center justify-center">
        <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin"></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from '@/composables/useI18n';

const { locale } = useI18n();
const loading = ref(true);
const iframeSrc = ref('/quality-traceability/quality-dashboard.html');

const handleIframeLoad = () => {
  loading.value = false;
  
  // Send language to iframe
  setTimeout(() => {
    const iframe = document.getElementById('food-quality-frame');
    if (iframe && iframe.contentWindow) {
      const lang = locale.value || 'en';
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: lang }, '*');
    }
  }, 500);
};

const handleIframeError = () => {
  loading.value = false;
  console.error('Failed to load Food Quality Traceability dashboard');
};

// Listen for language changes
const handleLanguageChange = (event) => {
  if (event.data && event.data.type === 'LANGUAGE_CHANGE') {
    const iframe = document.getElementById('food-quality-frame');
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang: event.data.language }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: event.data.language }, '*');
    }
  }
};

onMounted(() => {
  window.addEventListener('message', handleLanguageChange);
});

onUnmounted(() => {
  window.removeEventListener('message', handleLanguageChange);
});
</script>

<style scoped>
.reports-page-container {
  width: 100%;
  height: auto;
  min-height: 100%;
  position: relative;
}

.reports-iframe {
  width: 100%;
  height: 100vh;
  min-height: 800px;
  border: 0;
  display: block;
}

.loading-spinner {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
