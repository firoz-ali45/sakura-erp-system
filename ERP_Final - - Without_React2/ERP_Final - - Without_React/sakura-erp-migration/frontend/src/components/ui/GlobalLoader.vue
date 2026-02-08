<template>
  <div 
    v-if="visible"
    :class="['global-loader', containerClass]"
    :style="{ 
      position: fullScreen ? 'fixed' : 'relative',
      width: fullScreen ? '100%' : 'auto',
      height: fullScreen ? '100%' : 'auto'
    }"
  >
    <div class="loader-content">
      <div class="loader-ring"></div>
      <p v-if="text" class="loader-text">{{ text }}</p>
    </div>
  </div>
</template>

<script setup>
import { defineProps } from 'vue';

const props = defineProps({
  visible: {
    type: Boolean,
    default: true
  },
  text: {
    type: String,
    default: ''
  },
  fullScreen: {
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
.global-loader {
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.global-loader.fixed {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(4px);
}

.loader-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
}

.loader-ring {
  width: 48px;
  height: 48px;
  border: 4px solid rgba(40, 75, 68, 0.1);
  border-top-color: #284b44;
  border-radius: 50%;
  animation: spin 1s ease-in-out infinite;
}

.loader-text {
  font-size: 14px;
  color: #6b7280;
  margin: 0;
  text-align: center;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

/* Variant sizes */
.global-loader.small .loader-ring {
  width: 24px;
  height: 24px;
  border-width: 3px;
}

.global-loader.large .loader-ring {
  width: 64px;
  height: 64px;
  border-width: 5px;
}

/* Variant colors */
.global-loader.white .loader-ring {
  border-color: rgba(255, 255, 255, 0.3);
  border-top-color: white;
}

.global-loader.white .loader-text {
  color: white;
}
</style>
