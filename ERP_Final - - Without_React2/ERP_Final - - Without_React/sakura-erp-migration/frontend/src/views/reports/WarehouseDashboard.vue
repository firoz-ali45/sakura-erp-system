<template>
  <div class="reports-page-container">
    <iframe
      id="warehouse-dashboard-frame"
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
import { useDashboardSummaryStore } from '@/stores/dashboardSummaryStore';

const { locale } = useI18n();
const summaryStore = useDashboardSummaryStore();
const loading = ref(true);
const iframeSrc = ref('/sakura-accounts-payable-dashboard/Warehouse.html');

const handleIframeLoad = () => {
  loading.value = false;
  
  // Send language to iframe
  setTimeout(() => {
    const iframe = document.getElementById('warehouse-dashboard-frame');
    if (iframe && iframe.contentWindow) {
      const lang = locale.value || 'en';
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: lang }, '*');
      // Auto-load warehouse data
      setTimeout(() => {
        iframe.contentWindow.postMessage({ type: 'AUTO_LOAD_DATA' }, '*');
      }, 1000);
    }
  }, 500);
};

const handleIframeError = () => {
  loading.value = false;
  console.error('Failed to load Warehouse Dashboard');
};

// Helper function to parse currency/formatted values to numbers
const parseValue = (value) => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    // Remove currency symbols, spaces, commas
    const cleaned = value.replace(/[^0-9.-]+/g, '').replace(/,/g, '');
    return parseFloat(cleaned) || 0;
  }
  return 0;
};

// Listen for messages from iframe (language changes + KPI updates)
const handleIframeMessage = (event) => {
  // Handle language changes
  if (event.data && event.data.type === 'LANGUAGE_CHANGE') {
    const iframe = document.getElementById('warehouse-dashboard-frame');
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang: event.data.language }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: event.data.language }, '*');
    }
  }
  
  // Handle Warehouse KPI updates from iframe
  // CRITICAL: When Warehouse dashboard finishes processing, compute warehouse KPIs and save to Pinia store
  if (event.data && event.data.type === 'WAREHOUSE_DATA' && event.data.payload) {
    const kpis = event.data.payload;
    if (kpis && typeof kpis === 'object') {
      console.log('📊 [WarehouseDashboard] Received KPIs from iframe:', kpis);
      
      // Parse formatted values (iframe may send "SAR 1,000" strings) to numbers
      const warehouseSummaryData = {
        totalInventoryValue: parseValue(kpis.totalInventoryValue),
        outOfStockCount: parseValue(kpis.outOfStock) || 0,
        lowStockCount: parseValue(kpis.lowStock) || 0,
        transferValue: parseValue(kpis.transferValue),
        purchaseValue: parseValue(kpis.purchaseValue)
      };
      
      // Update Pinia store (single source of truth)
      summaryStore.updateWarehouseSummary(warehouseSummaryData);
      console.log('✅ [WarehouseDashboard] Updated Pinia store with warehouse summary:', warehouseSummaryData);
    }
  }
};

onMounted(() => {
  window.addEventListener('message', handleIframeMessage);
});

onUnmounted(() => {
  window.removeEventListener('message', handleIframeMessage);
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
