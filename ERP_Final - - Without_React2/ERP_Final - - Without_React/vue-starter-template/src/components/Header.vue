<template>
  <v-app-bar
    class="gradient-header"
    dark
    elevation="2"
    style="background: linear-gradient(135deg, #284b44 0%, #956c2a 100%);"
  >
    <div class="d-flex align-center" style="flex: 1; justify-content: flex-start;">
      <v-btn icon variant="text" class="d-md-none">
        <i class="fas fa-bars"></i>
      </v-btn>
    </div>

    <div class="d-flex align-center justify-center gap-3" style="flex: 1;">
      <img 
        src="https://images.deliveryhero.io/image/hungerstation/restaurant/logo/8556a1377e5154c66adf844d9c5ecb9f.jpg" 
        alt="Sakura Logo" 
        class="rounded-circle"
        style="width: 40px; height: 40px; object-fit: cover; border: 1px solid rgba(255,255,255,0.5);"
      />
      <h2 class="text-h6 font-weight-bold text-white">Sakura Management Hub</h2>
      <div class="d-flex align-center gap-1 text-xs text-white" style="opacity: 0.8;">
        <i class="fas fa-shield-alt text-success"></i>
        <span>Consistent</span>
      </div>
    </div>

    <div class="d-flex align-center" style="flex: 1; justify-content: flex-end;">
      <div class="text-caption text-white d-none d-md-block" style="opacity: 0.9;">
        {{ currentDateTime }}
      </div>
    </div>
  </v-app-bar>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const currentDateTime = ref('')

function updateDateTime() {
  const now = new Date()
  currentDateTime.value = now.toLocaleString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  })
}

onMounted(() => {
  updateDateTime()
  const interval = setInterval(updateDateTime, 60000) // Update every minute
  onUnmounted(() => clearInterval(interval))
})
</script>
