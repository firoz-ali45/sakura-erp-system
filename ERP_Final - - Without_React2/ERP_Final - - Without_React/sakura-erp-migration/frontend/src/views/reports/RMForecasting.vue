<template>
  <div class="reports-page-container">
    <iframe
      id="rm-forecasting-frame"
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
const iframeSrc = ref('/sakura-accounts-payable-dashboard/forecasting.html');

const handleIframeLoad = () => {
  loading.value = false;
  
  // Send language to iframe
  setTimeout(() => {
    const iframe = document.getElementById('rm-forecasting-frame');
    if (iframe && iframe.contentWindow) {
      const lang = locale.value || 'en';
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: lang }, '*');
    }
  }, 500);
};

const handleIframeError = () => {
  loading.value = false;
  console.error('Failed to load RM Forecasting dashboard');
};

// Helper function to parse formatted values (currency, percentages) to numbers
const parseValue = (value) => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    // Remove currency symbols, spaces, commas, % signs
    const cleaned = value.replace(/[^0-9.-]+/g, '').replace(/,/g, '');
    return parseFloat(cleaned) || 0;
  }
  return 0;
};

// Listen for messages from iframe (language changes + KPI updates)
// CRITICAL: When RM Forecasting finishes processing (completeRMForecast ready),
// compute summary KPIs ONCE and save them into Pinia store
const handleIframeMessage = (event) => {
  // Handle language changes
  if (event.data && event.data.type === 'LANGUAGE_CHANGE') {
    const iframe = document.getElementById('rm-forecasting-frame');
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang: event.data.language }, '*');
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: event.data.language }, '*');
    }
  }
  
  // Handle RM Forecasting KPI updates from iframe
  // Iframe sends FORECASTING_DATA with kpiTotalBudget, kpiItemsToOrder, etc.
  if (event.data && event.data.type === 'FORECASTING_DATA' && event.data.payload) {
    const kpis = event.data.payload;
    if (kpis && typeof kpis === 'object') {
      console.log('📊 [RMForecasting] Received FORECASTING_DATA from iframe:', kpis);
      
      // Map iframe payload format to store format (parse formatted strings to numbers)
      const rawMaterialSummaryData = {
        netPurchaseBudget: parseValue(kpis.kpiTotalBudget),
        itemsToPurchase: parseValue(kpis.kpiItemsToOrder),
        potentialSavings: parseValue(kpis.kpiSavings),
        overstockedValue: parseValue(kpis.kpiOverstock),
        forecastAccuracy: parseValue(kpis.kpiForecastAccuracy)
      };
      
      // Update Pinia store (single source of truth)
      summaryStore.updateRawMaterialSummary(rawMaterialSummaryData);
      console.log('✅ [RMForecasting] Updated Pinia store with RM summary:', rawMaterialSummaryData);
    }
  }
  
  // Also handle RM_FORECASTING_SUMMARY for backward compatibility (if iframe sends it)
  if (event.data && event.data.type === 'RM_FORECASTING_SUMMARY' && event.data.payload) {
    const kpis = event.data.payload;
    if (kpis && typeof kpis === 'object') {
      console.log('📊 [RMForecasting] Received RM_FORECASTING_SUMMARY from iframe:', kpis);
      summaryStore.updateRawMaterialSummary({
        netPurchaseBudget: parseValue(kpis.netPurchaseBudget),
        itemsToPurchase: parseValue(kpis.itemsToPurchase),
        potentialSavings: parseValue(kpis.potentialSavings),
        overstockedValue: parseValue(kpis.overstockedValue),
        forecastAccuracy: parseValue(kpis.forecastAccuracy)
      });
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
