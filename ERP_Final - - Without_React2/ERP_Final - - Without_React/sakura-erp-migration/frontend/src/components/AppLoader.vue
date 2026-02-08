<template>
  <div class="app-loader absolute inset-0 bg-white bg-opacity-95 z-50 flex items-center justify-center" :class="containerClass">
    <div class="flex flex-col items-center gap-4">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin"></div>
      <p v-if="showText" class="text-gray-600 text-sm">{{ $t('common.loading') }}</p>
    </div>
  </div>
</template>

<script setup>
import { useI18n } from '@/composables/useI18n';

const { t } = useI18n();

defineProps({
  showText: {
    type: Boolean,
    default: false
  },
  containerClass: {
    type: String,
    default: ''
  }
});
</script>

<style scoped>
.loading-spinner {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.app-loader {
  backdrop-filter: blur(2px);
}
</style>
