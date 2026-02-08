<template>
    <!-- Skeleton Loader (shown during initial load) -->
    <div v-if="loading" class="p-6 space-y-6">
      <SkeletonLoader :lines="3" variant="card" container-class="mb-6" />
      <div class="insights-grid">
        <SkeletonLoader :lines="2" variant="card" v-for="n in 4" :key="n" />
      </div>
    </div>
    
    <!-- Main Dashboard Content -->
    <div id="home-screen" v-if="!loading" class="dashboard-container">
    <div class="mb-6">
      <h2 class="dashboard-title">{{ $t('homePortal.erpCommandCenterTitle') }}</h2>
      <p class="dashboard-subtitle">{{ $t('homePortal.erpCommandCenterSubtitle') }}</p>

      <div class="dashboard-top-grid">
        <!-- Working Capital Health -->
        <div class="bg-white p-4 rounded-lg shadow-lg flex flex-col items-center justify-center">
          <h3 class="font-bold text-gray-700 mb-2">{{ $t('homePortal.healthScoreTitle') }}</h3>
          <div class="relative">
            <div id="health-gauge" class="health-gauge relative">
              <div class="health-score-text flex items-center justify-center flex-col">
                <span id="health-score-value">{{ healthScore }}</span>
                <span class="text-xs font-normal">{{ $t('homePortal.scoreOutOf100') }}</span>
              </div>
            </div>
          </div>
          <p class="text-xs text-center text-gray-500 mt-2">{{ $t('homePortal.healthScoreDesc') }}</p>
        </div>

        <!-- Payables Aging Analysis -->
        <div class="bg-white p-4 rounded-lg shadow-lg">
          <h3 class="font-bold text-gray-700 mb-3">{{ $t('homePortal.agingAnalysisTitle') }}</h3>
          <div class="space-y-3">
            <div>
              <div class="flex justify-between text-sm mb-1">
                <span class="font-semibold text-green-700">{{ $t('homePortal.currentDues') }}</span>
                <span class="font-mono text-xs sm:text-sm">{{ agingCurrent }}</span>
              </div>
              <div class="aging-bar-bg w-full h-4 rounded-full overflow-hidden">
                <div id="aging-bar-current" class="aging-bar h-full bg-green-500" :style="{ width: agingCurrentPercent + '%' }"></div>
              </div>
            </div>
            <div>
              <div class="flex justify-between text-sm mb-1">
                <span class="font-semibold text-red-700">{{ $t('homePortal.overdueDues') }}</span>
                <span class="font-mono text-xs sm:text-sm">{{ agingOverdue }}</span>
              </div>
              <div class="aging-bar-bg w-full h-4 rounded-full overflow-hidden">
                <div id="aging-bar-overdue" class="aging-bar h-full bg-red-500" :style="{ width: agingOverduePercent + '%' }"></div>
              </div>
            </div>
          </div>
        </div>

        <!-- Recommendation Engine -->
        <div class="bg-white p-4 rounded-lg shadow-lg">
          <h3 class="font-bold text-gray-700 mb-2">{{ $t('homePortal.recommendationTitle') }}</h3>
          <div class="flex items-start gap-3 bg-yellow-50 border border-yellow-200 p-3 rounded-lg h-full">
            <i class="fas fa-lightbulb text-2xl md:text-3xl text-yellow-500 mt-1"></i>
            <div>
              <p id="recommendation-text" class="text-sm text-gray-700" v-html="recommendationText"></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Advanced ERP Insights -->
      <div class="insights-grid">
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-brain text-3xl md:text-4xl text-indigo-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.operationalIntelligence') }}</h3>
            <p class="text-lg md:text-xl font-bold text-indigo-600">{{ insights.operationalIQ }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.operationalIQDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-shield-alt text-3xl md:text-4xl text-red-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.riskExposure') }}</h3>
            <p class="text-lg md:text-xl font-bold text-red-600">{{ insights.riskExposure }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.riskExposureDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-rocket text-3xl md:text-4xl text-green-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.growthPotential') }}</h3>
            <p class="text-lg md:text-xl font-bold text-green-600">{{ insights.growthPotential }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.growthPotentialDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-cogs text-3xl md:text-4xl text-orange-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.processOptimization') }}</h3>
            <p class="text-lg md:text-xl font-bold text-orange-600">{{ insights.processOptimization }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.processOptimizationDesc') }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Key Financial Metrics -->
    <div class="mb-6">
      <h3 class="text-xl font-bold text-gray-700">{{ $t('homePortal.keyMetricsTitle') }}</h3>
      <div class="metrics-grid mt-3">
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-coins text-3xl md:text-4xl text-yellow-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.cashOutflowTitle') }}</h3>
            <p class="text-2xl md:text-3xl font-bold text-red-600">{{ metrics.cashOutflow }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.cashOutflowDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-lock text-3xl md:text-4xl text-blue-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.capitalEfficiencyTitle') }}</h3>
            <p class="text-2xl md:text-3xl font-bold text-blue-600">{{ metrics.nonProductiveCapital }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.capitalEfficiencyDesc') }}</p>
          </div>
        </div>
      </div>

      <!-- Advanced Financial Intelligence -->
      <div class="insights-grid mt-4">
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-chart-pie text-3xl md:text-4xl text-purple-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.profitabilityIndex') }}</h3>
            <p class="text-lg md:text-xl font-bold text-purple-600">{{ metrics.profitability }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.profitabilityDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-balance-scale text-3xl md:text-4xl text-teal-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.financialStability') }}</h3>
            <p class="text-lg md:text-xl font-bold text-teal-600">{{ metrics.financialStability }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.financialStabilityDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-trending-up text-3xl md:text-4xl text-emerald-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.revenueOptimization') }}</h3>
            <p class="text-lg md:text-xl font-bold text-emerald-600">{{ metrics.revenueOptimization }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.revenueOptimizationDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-piggy-bank text-3xl md:text-4xl text-amber-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.costEfficiency') }}</h3>
            <p class="text-lg md:text-xl font-bold text-amber-600">{{ metrics.costEfficiency }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.costEfficiencyDesc') }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Detailed Performance Indicators -->
    <div class="mb-8">
      <h3 class="section-title">{{ $t('homePortal.detailedKPIsTitle') }}</h3>
      <div class="kpi-detail-grid">
        <div class="analysis-card border-orange-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.overdueRatioTitle') }}</h4>
          <p class="value text-orange-500">{{ kpis.overdueRatio }}</p>
        </div>
        <div class="analysis-card border-teal-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.accuracyImpactTitle') }}</h4>
          <p class="value text-teal-500">{{ kpis.accuracyImpact }}</p>
        </div>
        <div class="analysis-card border-purple-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.savingsPowerTitle') }}</h4>
          <p class="value text-purple-500">{{ kpis.savingsPower }}</p>
        </div>
        <div class="analysis-card border-gray-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.avgDebtTitle') }}</h4>
          <p class="value text-gray-600">{{ kpis.avgDebt }}</p>
        </div>
      </div>

      <!-- Advanced Performance Analytics -->
      <div class="kpi-detail-grid mt-4">
        <div class="analysis-card border-indigo-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.supplyChainEfficiency') }}</h4>
          <p class="value text-indigo-500">{{ kpis.supplyChainEfficiency }}</p>
        </div>
        <div class="analysis-card border-emerald-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.vendorPerformance') }}</h4>
          <p class="value text-emerald-500">{{ kpis.vendorPerformance }}</p>
        </div>
        <div class="analysis-card border-rose-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.demandAccuracy') }}</h4>
          <p class="value text-rose-500">{{ kpis.demandAccuracy }}</p>
        </div>
        <div class="analysis-card border-cyan-400 text-center">
          <h4 class="font-semibold text-sm text-gray-600">{{ $t('homePortal.operationalExcellence') }}</h4>
          <p class="value text-cyan-500">{{ kpis.operationalExcellence }}</p>
        </div>
      </div>
    </div>

    <!-- Cross-Dashboard Business Insights -->
    <div class="mb-8">
      <h2 class="text-xl md:text-2xl font-bold text-gray-800">{{ $t('homePortal.crossDataInsights') }}</h2>
      <div class="insights-grid-three mt-4">
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-link text-3xl md:text-4xl text-blue-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.cashFlowOptimization') }}</h3>
            <p class="text-lg md:text-xl font-bold text-blue-600">{{ insights.cashFlow }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.cashFlowDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-chart-line text-3xl md:text-4xl text-green-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.inventoryEfficiency') }}</h3>
            <p class="text-lg md:text-xl font-bold text-green-600">{{ insights.inventoryEfficiency }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.inventoryEfficiencyDesc') }}</p>
          </div>
        </div>
        <div class="insight-card rounded-lg p-4 shadow-md flex items-start gap-4">
          <i class="fas fa-target text-3xl md:text-4xl text-purple-500 mt-1"></i>
          <div>
            <h3 class="font-semibold text-gray-800">{{ $t('homePortal.procurementAlignment') }}</h3>
            <p class="text-lg md:text-xl font-bold text-purple-600">{{ insights.procurement }}</p>
            <p class="text-xs text-gray-600">{{ $t('homePortal.procurementDesc') }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Accounts Payable Summary -->
    <div class="mb-6">
      <h2 class="section-title-large">{{ $t('homePortal.payableSummary') }}</h2>
      <div class="kpi-summary-grid">
        <div class="kpi-card">
          <div class="icon bg-red-500">
            <i class="fas fa-dollar-sign"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.totalDues') }}</p>
            <div id="kpi-payable-dues" class="value">{{ formatCurrencyLocale(payableSummary.totalDues) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-blue-500">
            <i class="fas fa-users"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.totalSuppliers') }}</p>
            <div id="kpi-payable-suppliers" class="value">{{ formatNumberLocale(payableSummary.totalSuppliers) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-orange-500">
            <i class="fas fa-exclamation-triangle"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.overdues') }}</p>
            <div id="kpi-payable-overdues" class="value">{{ formatCurrencyLocale(payableSummary.overdues) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-purple-500">
            <i class="fas fa-file-invoice"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.totalTransactions') }}</p>
            <div id="kpi-payable-tx" class="value">{{ formatNumberLocale(payableSummary.totalTransactions) }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Raw Material Forecasting Summary -->
    <div class="mb-6">
      <h2 class="section-title-large">{{ $t('homePortal.forecastingSummary') }}</h2>
      <div class="kpi-summary-grid forecast-grid">
        <div class="kpi-card">
          <div class="icon" style="background-color: #956c2a;">
            <i class="fas fa-wallet"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.netPurchaseBudget') }}</p>
            <div id="kpi-forecast-budget" class="value">{{ formatCurrencyLocale(forecastSummary.netPurchaseBudget) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon" style="background-color: #284b44;">
            <i class="fas fa-shopping-cart"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.itemsToPurchase') }}</p>
            <div id="kpi-forecast-items" class="value">{{ formatNumberLocale(forecastSummary.itemsToPurchase) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-green-500">
            <i class="fas fa-piggy-bank"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.potentialSavings') }}</p>
            <div id="kpi-forecast-savings" class="value">{{ formatCurrencyLocale(forecastSummary.potentialSavings) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-yellow-500">
            <i class="fas fa-box-open"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.overstockedValue') }}</p>
            <div id="kpi-forecast-overstock" class="value">{{ formatCurrencyLocale(forecastSummary.overstockedValue) }}</div>
          </div>
        </div>
        <div class="kpi-card col-span-2 md:col-span-1">
          <div class="icon" style="background-color: #ea8990;">
            <i class="fas fa-bullseye"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.forecastAccuracy') }}</p>
            <div id="kpi-forecast-accuracy" class="value">{{ formatPercentageLocale(forecastSummary.forecastAccuracy) }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Warehouse Management Summary -->
    <div class="mb-6">
      <h2 class="section-title-large">{{ $t('homePortal.warehouseSummary') }}</h2>
      <div class="kpi-summary-grid forecast-grid">
        <div class="kpi-card">
          <div class="icon" style="background-color: #284b44;">
            <i class="fas fa-boxes"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.totalInventoryValue') }}</p>
            <div id="kpi-warehouse-inventory" class="value">{{ formatCurrencyLocale(warehouseSummary.totalInventoryValue) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-red-500">
            <i class="fas fa-exclamation-triangle"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.outOfStock') }}</p>
            <div id="kpi-warehouse-outstock" class="value">{{ formatNumberLocale(warehouseSummary.outOfStock) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-orange-500">
            <i class="fas fa-exclamation-circle"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.lowStock') }}</p>
            <div id="kpi-warehouse-lowstock" class="value">{{ formatNumberLocale(warehouseSummary.lowStock) }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-green-500">
            <i class="fas fa-truck"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.transferValue') }}</p>
            <div id="kpi-warehouse-transfers" class="value">{{ formatCurrencyLocale(warehouseSummary.transferValue) }}</div>
          </div>
        </div>
        <div class="kpi-card col-span-2 md:col-span-1">
          <div class="icon" style="background-color: #956c2a;">
            <i class="fas fa-shopping-cart"></i>
          </div>
          <div>
            <p class="title">{{ $t('homePortal.purchaseValue') }}</p>
            <div id="kpi-warehouse-purchases" class="value">{{ formatCurrencyLocale(warehouseSummary.purchaseValue) }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from '@/composables/useI18n';
import { formatCurrency, formatNumber, formatPercentage } from '@/utils/numberFormat';
import { useDashboardSummaryStore } from '@/stores/dashboardSummaryStore';
import SkeletonLoader from '@/components/ui/SkeletonLoader.vue';

const route = useRoute();

const { t, locale } = useI18n();
const summaryStore = useDashboardSummaryStore();

// Dashboard Data
const loading = ref(true);
const healthScore = ref('--');
const agingCurrent = ref('...');
const agingOverdue = ref('...');
const agingCurrentPercent = ref(0);
const agingOverduePercent = ref(0);
const recommendationText = ref('Analyzing data...');

const insights = ref({
  operationalIQ: '...',
  riskExposure: '...',
  growthPotential: '...',
  processOptimization: '...',
  cashFlow: '...',
  inventoryEfficiency: '...',
  procurement: '...'
});

const metrics = ref({
  cashOutflow: '...',
  nonProductiveCapital: '...',
  profitability: '...',
  financialStability: '...',
  revenueOptimization: '...',
  costEfficiency: '...'
});

const kpis = ref({
  overdueRatio: '...',
  accuracyImpact: '...',
  savingsPower: '...',
  avgDebt: '...',
  supplyChainEfficiency: '...',
  vendorPerformance: '...',
  demandAccuracy: '...',
  operationalExcellence: '...'
});

// CRITICAL: Store raw numbers only, never formatted strings
const payableSummary = ref({
  totalDues: 0, // Raw number
  totalSuppliers: 0, // Raw number
  overdues: 0, // Raw number
  totalTransactions: 0 // Raw number
});

// CRITICAL: Use computed() to read from Pinia store (single source of truth)
// HomePortal reads KPIs ONLY from Pinia, does NOT fetch Google Sheets, does NOT recompute logic
// Access rawMaterialSummary directly (it's a ref, Pinia makes it reactive)
const forecastSummary = computed(() => summaryStore.rawMaterialSummary);

const warehouseSummary = computed(() => {
  const wh = summaryStore.warehouseSummary;
  return {
    totalInventoryValue: wh.totalInventoryValue,
    outOfStock: wh.outOfStockCount,
    lowStock: wh.lowStockCount,
    transferValue: wh.transferValue,
    purchaseValue: wh.purchaseValue
  };
});

// Helper function to ensure value is a number (for backward compatibility)
const ensureNumber = (value) => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    // Parse if string (backward compatibility with old cached data)
    const cleaned = value.replace(/[^0-9.-]+/g, '').replace(/,/g, '');
    return parseFloat(cleaned) || 0;
  }
  return 0;
};

// Format numbers based on locale
const formatNumberLocale = (value) => formatNumber(value, locale.value);
const formatCurrencyLocale = (value) => formatCurrency(value, locale.value);
const formatPercentageLocale = (value) => formatPercentage(value, locale.value);

// Update all insights with calculations
// CRITICAL: All data is now raw numbers, no parsing needed
const updateAllInsights = (payableData, forecastingData, warehouseData) => {
  // Only calculate if we have minimum required data
  if (!payableData) return;
  
  // Data is already raw numbers from services - use ensureNumber for backward compatibility
  const totalDues = ensureNumber(payableData.totalDues);
  const overdues = ensureNumber(payableData.overdues);
  const totalSuppliers = ensureNumber(payableData.totalSuppliers);
  const purchaseBudget = forecastingData ? ensureNumber(forecastingData.kpiTotalBudget) : 0;
  const potentialSavings = forecastingData ? ensureNumber(forecastingData.kpiSavings) : 0;
  const overstockValue = forecastingData ? ensureNumber(forecastingData.kpiOverstock) : 0;
  const forecastAccuracy = forecastingData ? ensureNumber(forecastingData.kpiForecastAccuracy) : 0;
  
  // Calculate warehouse metrics
  let inventoryValue = 0, transferValue = 0, purchaseValue = 0, outOfStock = 0, lowStock = 0;
  if (warehouseData) {
    inventoryValue = ensureNumber(warehouseData.totalInventoryValue);
    transferValue = ensureNumber(warehouseData.transferValue);
    purchaseValue = ensureNumber(warehouseData.purchaseValue);
    outOfStock = ensureNumber(warehouseData.outOfStock);
    lowStock = ensureNumber(warehouseData.lowStock);
  }
  
  // Calculate all derived metrics
  const overdueRatio = totalDues > 0 ? (overdues / totalDues) * 100 : 0;
  let score = 100 - (overdueRatio * 1.5) + ((forecastAccuracy - 85) * 1) - ((totalDues > 0 ? ((overdues + overstockValue) / totalDues) * 100 : 0) * 0.5);
  score = Math.max(0, Math.min(100, score));
  const currentDues = totalDues - overdues;
  const currentPercent = totalDues > 0 ? (currentDues / totalDues) * 100 : 100;
  const overduePercent = totalDues > 0 ? (overdues / totalDues) * 100 : 0;
  const totalOutflow = totalDues + purchaseBudget;
  const nonProductiveCapital = overdues + overstockValue;
  const savingsImpact = totalDues > 0 ? (potentialSavings / totalDues) * 100 : 0;
  const avgDebt = totalSuppliers > 0 ? totalDues / totalSuppliers : 0;
  const forecastInaccuracy = 100 - forecastAccuracy;
  const savingsPerPercent = forecastInaccuracy > 0 ? (overstockValue / forecastInaccuracy) : 0;
  
  // Update health score
  healthScore.value = Math.round(score);
  
  // Update aging analysis (use locale-aware formatting)
  agingCurrent.value = formatCurrencyLocale(currentDues);
  agingOverdue.value = formatCurrencyLocale(overdues);
  agingCurrentPercent.value = currentPercent;
  agingOverduePercent.value = overduePercent;
  
  // Update recommendation (use locale-aware formatting)
  if (overdues > 0 && potentialSavings > 0) {
    const clearablePercent = (potentialSavings / overdues) * 100;
    recommendationText.value = locale.value === 'ar' 
      ? `يمكنك سداد ${formatCurrencyLocale(potentialSavings)} من المدفوعات المتأخرة، وهو ${formatNumberLocale(Math.min(100, clearablePercent))}% من إجمالي المتأخرات.`
      : `You can clear ${formatCurrencyLocale(potentialSavings)} of overdue payments, which is ${formatNumberLocale(Math.min(100, clearablePercent))}% of total overdues.`;
  } else if (nonProductiveCapital > (totalDues * 0.2)) {
    recommendationText.value = locale.value === 'ar'
      ? `لديك ${formatCurrencyLocale(nonProductiveCapital)} محجوزة في رأس المال غير المنتج. فكر في التحسين.`
      : `You have ${formatCurrencyLocale(nonProductiveCapital)} tied up in non-productive capital. Consider optimizing.`;
  } else {
    recommendationText.value = locale.value === 'ar'
      ? 'صحة رأس المال العامل جيدة. استمر في المراقبة للحصول على أداء مثالي.'
      : 'Your working capital health is good. Continue monitoring for optimal performance.';
  }
  
  // Update metrics (use locale-aware formatting)
  metrics.value = {
    cashOutflow: formatCurrencyLocale(totalOutflow),
    nonProductiveCapital: formatCurrencyLocale(nonProductiveCapital),
    profitability: formatPercentageLocale(Math.min(100, forecastAccuracy + (potentialSavings > 100000 ? 20 : 0) + (warehouseData ? 15 : 0))),
    financialStability: formatPercentageLocale(Math.min(100, score + (forecastAccuracy > 90 ? 10 : 0))),
    revenueOptimization: formatPercentageLocale(Math.min(100, forecastAccuracy + (potentialSavings > 150000 ? 25 : 0))),
    costEfficiency: formatPercentageLocale(Math.min(100, forecastAccuracy + (totalDues > 0 ? (potentialSavings / totalDues * 100) : 0)))
  };
  
  // Update insights (use locale-aware formatting)
  insights.value = {
    operationalIQ: formatPercentageLocale(Math.min(100, (forecastAccuracy + (100 - overdueRatio) + (warehouseData ? 85 : 70)) / 3)),
    riskExposure: formatPercentageLocale(Math.min(100, overdueRatio + (100 - forecastAccuracy) + (warehouseData ? 15 : 30))),
    growthPotential: formatPercentageLocale(Math.min(100, forecastAccuracy + (100 - overdueRatio) + (potentialSavings > 100000 ? 20 : 0))),
    processOptimization: formatPercentageLocale(Math.min(100, forecastAccuracy + (100 - overdueRatio) + (warehouseData ? 80 : 60))),
    cashFlow: formatCurrencyLocale(totalDues + purchaseBudget + inventoryValue),
    inventoryEfficiency: formatPercentageLocale(warehouseData ? Math.min(100, forecastAccuracy + 20) : Math.min(100, forecastAccuracy)),
    procurement: formatPercentageLocale(warehouseData ? Math.min(100, ((purchaseValue / (purchaseBudget || 1)) * 100 + (totalDues > 0 ? Math.max(0, 100 - ((totalDues - purchaseValue) / totalDues) * 100) : 100)) / 2) : 0)
  };
  
  // Update KPIs (use locale-aware formatting)
  kpis.value = {
    overdueRatio: overdueRatio > 0 ? formatPercentageLocale(overdueRatio) : formatPercentageLocale(0),
    accuracyImpact: savingsPerPercent > 0 ? `≈ ${formatCurrencyLocale(Math.round(savingsPerPercent))}` : formatCurrencyLocale(0),
    savingsPower: savingsImpact > 0 ? formatPercentageLocale(savingsImpact) : formatPercentageLocale(0),
    avgDebt: avgDebt > 0 ? formatCurrencyLocale(Math.round(avgDebt)) : formatCurrencyLocale(0),
    supplyChainEfficiency: formatPercentageLocale(warehouseData ? Math.min(100, forecastAccuracy + 20) : Math.min(100, forecastAccuracy)),
    vendorPerformance: formatPercentageLocale(Math.min(100, forecastAccuracy + (100 - overdueRatio) + (totalSuppliers > 200 ? 10 : 0))),
    demandAccuracy: formatPercentageLocale(forecastAccuracy),
    operationalExcellence: formatPercentageLocale(Math.min(100, (forecastAccuracy + (100 - overdueRatio) + (warehouseData ? 85 : 70)) / 3))
  };
};

// Update summary from data object
// CRITICAL: Store raw numbers only, format happens in templates
const updateSummariesFromData = (data) => {
  // Update payable summary - ensure raw numbers
  if (data?.accountsPayable) {
    payableSummary.value = {
      totalDues: ensureNumber(data.accountsPayable.totalDues) || payableSummary.value.totalDues || 0,
      totalSuppliers: ensureNumber(data.accountsPayable.totalSuppliers) || payableSummary.value.totalSuppliers || 0,
      overdues: ensureNumber(data.accountsPayable.overdues) || payableSummary.value.overdues || 0,
      totalTransactions: ensureNumber(data.accountsPayable.totalTransactions) || payableSummary.value.totalTransactions || 0
    };
  }
  
  // CRITICAL: HomePortal reads from Pinia store only, does NOT update local refs
  // Individual dashboards (RMForecasting, Warehouse) update Pinia store
  // This ensures single source of truth and no data duplication
  
  // Note: forecastSummary and warehouseSummary are now computed() from Pinia store
  // They automatically update when Pinia store updates
  
  // Update insights with calculations
  // Map data format to what updateAllInsights expects (raw numbers)
  const payableDataForInsights = data?.accountsPayable ? {
    totalDues: ensureNumber(data.accountsPayable.totalDues),
    totalSuppliers: ensureNumber(data.accountsPayable.totalSuppliers),
    overdues: ensureNumber(data.accountsPayable.overdues),
    totalTransactions: ensureNumber(data.accountsPayable.totalTransactions)
  } : payableSummary.value;
  
  // CRITICAL: Read from Pinia store (computed values) for insights calculation
  const forecastingDataForInsights = {
    kpiTotalBudget: ensureNumber(forecastSummary.value.netPurchaseBudget),
    kpiItemsToOrder: ensureNumber(forecastSummary.value.itemsToPurchase),
    kpiSavings: ensureNumber(forecastSummary.value.potentialSavings),
    kpiOverstock: ensureNumber(forecastSummary.value.overstockedValue),
    kpiForecastAccuracy: ensureNumber(forecastSummary.value.forecastAccuracy)
  };
  
  // Read warehouse data from Pinia store (computed values)
  const warehouseDataForInsights = {
    totalInventoryValue: ensureNumber(warehouseSummary.value.totalInventoryValue),
    transferValue: ensureNumber(warehouseSummary.value.transferValue),
    purchaseValue: ensureNumber(warehouseSummary.value.purchaseValue),
    outOfStock: ensureNumber(warehouseSummary.value.outOfStock),
    lowStock: ensureNumber(warehouseSummary.value.lowStock)
  };
  
  updateAllInsights(
    payableDataForInsights,
    forecastingDataForInsights,
    warehouseDataForInsights
  );
};

const loadDashboardData = async () => {
  // Fast initial load: get cached data immediately (non-blocking)
  const { getSummaryData } = await import('@/services/homeSummaryService');
  const { immediate, refresh } = getSummaryData();
  
  // Render cached data immediately if available (non-blocking)
  if (immediate) {
    updateSummariesFromData(immediate);
    loading.value = false; // UI is ready immediately
  } else {
    // If no cache, show skeleton for < 1 second, then render empty state
    setTimeout(() => {
      loading.value = false;
    }, 800);
  }
  
  // Background refresh: update when fresh data arrives (non-blocking)
  refresh.then(freshData => {
    if (freshData) {
      updateSummariesFromData(freshData);
    }
  }).catch(error => {
    console.error('Error refreshing dashboard data:', error);
    // Keep cached data visible, don't show errors
  });
};

// Helper function to parse formatted values (currency, percentages) to numbers
const parseIframeValue = (value) => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    // Remove currency symbols, spaces, commas, % signs
    const cleaned = value.replace(/[^0-9.-]+/g, '').replace(/,/g, '');
    return parseFloat(cleaned) || 0;
  }
  return 0;
};

// Listen for postMessage updates from iframe dashboards (real-time sync)
// CRITICAL: HomeDashboard ALSO listens for RM/Warehouse messages to update Pinia store
// This ensures store is updated even if user navigates to HomeDashboard before visiting dashboards
const handleDashboardMessage = async (event) => {
  if (!event.data || typeof event.data !== 'object') return;
  
  // Handle Accounts Payable messages
  if (event.data.type === 'PAYABLE_DATA' && event.data.payload) {
  const { updateSummaryFromMessage } = await import('@/services/homeSummaryService');
    const updatedData = updateSummaryFromMessage('PAYABLE_DATA', event.data.payload);
    if (updatedData) {
      updateSummariesFromData(updatedData);
      console.log('✅ [HomeDashboard] Updated Accounts Payable summary from iframe');
    }
  }
  
  // Handle RM Forecasting messages - Update Pinia store directly
  // CRITICAL: HomeDashboard also listens to ensure store is updated even if user hasn't visited RM Forecasting page
  if (event.data.type === 'FORECASTING_DATA' && event.data.payload) {
    const kpis = event.data.payload;
    if (kpis && typeof kpis === 'object') {
      console.log('📊 [HomeDashboard] Received FORECASTING_DATA from iframe:', kpis);
      
      const rawMaterialSummaryData = {
        netPurchaseBudget: parseIframeValue(kpis.kpiTotalBudget),
        itemsToPurchase: parseIframeValue(kpis.kpiItemsToOrder),
        potentialSavings: parseIframeValue(kpis.kpiSavings),
        overstockedValue: parseIframeValue(kpis.kpiOverstock),
        forecastAccuracy: parseIframeValue(kpis.kpiForecastAccuracy)
      };
      
      // Use already imported summaryStore
      summaryStore.updateRawMaterialSummary(rawMaterialSummaryData);
      console.log('✅ [HomeDashboard] Updated Pinia store with RM summary:', rawMaterialSummaryData);
    }
  }
  
  // Handle Warehouse messages - Update Pinia store directly
  // CRITICAL: HomeDashboard also listens to ensure store is updated even if user hasn't visited Warehouse page
  if (event.data.type === 'WAREHOUSE_DATA' && event.data.payload) {
    const kpis = event.data.payload;
    if (kpis && typeof kpis === 'object') {
      console.log('📊 [HomeDashboard] Received WAREHOUSE_DATA from iframe:', kpis);
      
      const warehouseSummaryData = {
        totalInventoryValue: parseIframeValue(kpis.totalInventoryValue),
        outOfStockCount: parseIframeValue(kpis.outOfStock) || 0,
        lowStockCount: parseIframeValue(kpis.lowStock) || 0,
        transferValue: parseIframeValue(kpis.transferValue),
        purchaseValue: parseIframeValue(kpis.purchaseValue)
      };
      
      // Use already imported summaryStore
      summaryStore.updateWarehouseSummary(warehouseSummaryData);
      console.log('✅ [HomeDashboard] Updated Pinia store with Warehouse summary:', warehouseSummaryData);
    }
  }
};

onMounted(() => {
  loadDashboardData();
  // Listen for real-time updates from iframe dashboards
  window.addEventListener('message', handleDashboardMessage);
});

onUnmounted(() => {
  // Clean up message listener
  window.removeEventListener('message', handleDashboardMessage);
});

// Watch for route changes to reload data when returning to dashboard
// This ensures data reloads even if component is reused
watch(
  () => route.path,
  (newPath) => {
    if (newPath === '/homeportal/dashboard' || newPath === '/homeportal') {
      loadDashboardData();
    }
  },
  { immediate: false }
);
</script>

<style scoped>
/* Mobile-First Fluid Typography */
.dashboard-container {
  width: 100%;
  padding: clamp(0.75rem, 2vw, 1.5rem);
  max-width: 100%;
  overflow-x: hidden;
}

.dashboard-title {
  font-size: clamp(1.25rem, 4vw, 1.875rem);
  font-weight: 700;
  color: #1f2937;
  line-height: 1.3;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

.dashboard-subtitle {
  font-size: clamp(0.75rem, 2.5vw, 0.875rem);
  color: #6b7280;
  margin-top: clamp(0.25rem, 1vw, 0.5rem);
  line-height: 1.5;
  word-wrap: break-word;
}

.section-title-large {
  font-size: clamp(1.125rem, 3.5vw, 1.5rem);
  font-weight: 700;
  color: #1f2937;
  line-height: 1.3;
  margin-bottom: clamp(0.75rem, 2vw, 1rem);
  word-wrap: break-word;
}

.section-title {
  font-size: clamp(1rem, 3vw, 1.25rem);
  font-weight: 700;
  color: #374151;
  line-height: 1.3;
  margin-bottom: clamp(0.5rem, 1.5vw, 0.75rem);
  word-wrap: break-word;
}

/* Mobile-First Responsive Grids */
.dashboard-top-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: clamp(0.75rem, 2vw, 1.5rem);
  margin-top: clamp(0.75rem, 2vw, 1rem);
}

@media (min-width: 1024px) {
  .dashboard-top-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

.metrics-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: clamp(0.75rem, 2vw, 1rem);
}

@media (min-width: 640px) {
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

.insights-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: clamp(0.75rem, 2vw, 1rem);
  margin-top: clamp(1rem, 3vw, 1.5rem);
}

@media (min-width: 640px) {
  .insights-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .insights-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.insights-grid-three {
  display: grid;
  grid-template-columns: 1fr;
  gap: clamp(0.75rem, 2vw, 1rem);
  margin-top: clamp(0.75rem, 2vw, 1rem);
}

@media (min-width: 640px) {
  .insights-grid-three {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .insights-grid-three {
    grid-template-columns: repeat(3, 1fr);
  }
}

.kpi-summary-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: clamp(0.75rem, 2vw, 1rem);
  margin-top: clamp(0.75rem, 2vw, 1rem);
}

@media (min-width: 640px) {
  .kpi-summary-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 768px) {
  .kpi-summary-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (min-width: 1024px) {
  .kpi-summary-grid:not(.forecast-grid) {
    grid-template-columns: repeat(4, 1fr);
  }
  
  .kpi-summary-grid.forecast-grid {
    grid-template-columns: repeat(5, 1fr);
  }
}

.kpi-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: clamp(0.5rem, 1.5vw, 1rem);
}

@media (min-width: 768px) {
  .kpi-detail-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.aging-bar-bg {
  background-color: #e5e7eb;
}

.aging-bar {
  transition: width 0.5s ease;
}

.insight-card {
  background: white;
  border: 1px solid #e5e7eb;
  min-height: 120px; /* Normalize card height */
  display: flex;
  align-items: flex-start;
  gap: clamp(0.75rem, 2vw, 1rem);
  padding: clamp(0.75rem, 2vw, 1rem);
  border-radius: 0.5rem;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

@media (hover: hover) {
  .insight-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }
}

.analysis-card {
  background: white;
  border: 2px solid;
  border-radius: clamp(0.375rem, 1vw, 0.5rem);
  padding: clamp(0.75rem, 2vw, 1rem);
  min-height: 100px; /* Normalize height */
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
}

.analysis-card .value {
  font-size: clamp(1.125rem, 3vw, 1.5rem);
  font-weight: 700;
  margin-top: clamp(0.25rem, 1vw, 0.5rem);
  word-break: break-word;
  overflow-wrap: break-word;
}

.kpi-card {
  background: linear-gradient(145deg, #f0e1cd 0%, #e8d5c0 100%);
  border-radius: clamp(0.5rem, 1.5vw, 0.75rem);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  padding: clamp(1rem, 3vw, 1.5rem);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
  border: 1px solid rgba(149, 108, 42, 0.2);
  position: relative;
  overflow: hidden;
  transition: all 0.3s ease;
  min-height: 140px; /* Normalize KPI card height */
  width: 100%;
}

.kpi-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, #284b44, #956c2a, #ea8990);
  opacity: 0.8;
  transition: all 0.3s ease;
}

.kpi-card .value {
  font-size: clamp(1.25rem, 4vw, 1.75rem);
  font-weight: 700;
  color: #284b44;
  margin-top: clamp(0.25rem, 1vw, 0.5rem);
  min-height: clamp(28px, 8vw, 36px);
  display: flex;
  align-items: center;
  justify-content: center;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  word-break: break-word;
  overflow-wrap: break-word;
  line-height: 1.2;
  text-align: center;
}

.kpi-card .title {
  color: #284b44;
  font-weight: 600;
  font-size: clamp(0.75rem, 2.5vw, 0.875rem);
  margin-bottom: clamp(0.25rem, 1vw, 0.5rem);
  word-break: break-word;
  overflow-wrap: break-word;
  line-height: 1.3;
  text-align: center;
}

.kpi-card .icon {
  width: clamp(40px, 12vw, 48px);
  height: clamp(40px, 12vw, 48px);
  min-width: 44px; /* Touch target minimum */
  min-height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: clamp(1.125rem, 3.5vw, 1.5rem);
  margin-bottom: clamp(0.5rem, 1.5vw, 0.75rem);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  flex-shrink: 0;
}

.health-gauge {
  width: clamp(100px, 30vw, 120px);
  height: clamp(100px, 30vw, 120px);
  min-width: 100px;
  min-height: 100px;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    #ef4444 0deg 90deg,
    #f59e0b 90deg 180deg,
    #10b981 180deg 360deg
  );
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  margin: 0 auto;
}

.health-gauge::before {
  content: '';
  position: absolute;
  width: clamp(70px, 20vw, 80px);
  height: clamp(70px, 20vw, 80px);
  border-radius: 50%;
  background: white;
}

.health-score-text {
  position: relative;
  z-index: 1;
  font-size: clamp(1.125rem, 3.5vw, 1.5rem);
  font-weight: 700;
  color: #284b44;
}

/* RTL Support */
[dir="rtl"] .dashboard-title,
[dir="rtl"] .section-title-large,
[dir="rtl"] .section-title {
  text-align: right;
}

[dir="rtl"] .insight-card {
  flex-direction: row-reverse;
}

[dir="rtl"] .kpi-card {
  direction: rtl;
}

/* Prevent text overflow */
.insight-card h3,
.insight-card p {
  word-break: break-word;
  overflow-wrap: break-word;
  hyphens: auto;
}

/* Fluid Typography for Text Elements */
.insight-card h3 {
  font-size: clamp(0.875rem, 2.5vw, 1rem);
  font-weight: 600;
  line-height: 1.4;
}

.insight-card p {
  font-size: clamp(0.75rem, 2vw, 0.875rem);
  line-height: 1.5;
}

.insight-card .text-lg,
.insight-card .text-xl,
.insight-card .text-2xl,
.insight-card .text-3xl {
  font-size: clamp(1rem, 3vw, 1.5rem) !important;
}

/* Mobile Touch Improvements */
@media (max-width: 767px) {
  .insight-card {
    padding: clamp(0.75rem, 2vw, 1rem);
    gap: clamp(0.5rem, 1.5vw, 0.75rem);
    min-height: 110px;
  }
  
  .insight-card i {
    font-size: clamp(1.75rem, 8vw, 2.25rem) !important;
    min-width: 44px;
    min-height: 44px;
    flex-shrink: 0;
  }
  
  .kpi-card {
    padding: clamp(0.875rem, 2.5vw, 1rem) clamp(0.625rem, 2vw, 0.75rem);
    min-height: 130px;
  }
  
  .analysis-card {
    min-height: 90px;
    padding: clamp(0.625rem, 1.5vw, 0.75rem);
  }
  
  /* Improve spacing for touch */
  .dashboard-top-grid,
  .metrics-grid,
  .insights-grid,
  .kpi-summary-grid {
    gap: clamp(0.625rem, 1.5vw, 0.875rem);
  }
}

/* Prevent horizontal scroll */
.dashboard-container,
#home-screen {
  max-width: 100vw;
  overflow-x: hidden;
  width: 100%;
}

/* Ensure all content containers respect max-width */
.dashboard-container > * {
  max-width: 100%;
  overflow-x: hidden;
}

/* Tablet optimizations */
@media (min-width: 768px) and (max-width: 1023px) {
  .insight-card {
    min-height: 140px;
  }
  
  .kpi-card {
    min-height: 160px;
  }
  
  .dashboard-top-grid {
    gap: clamp(1rem, 2.5vw, 1.5rem);
  }
}

/* Desktop: Maintain current layout */
@media (min-width: 1024px) {
  .dashboard-container {
    padding: 1.5rem;
  }
  
  .insight-card {
    min-height: 150px;
  }
  
  .kpi-card {
    min-height: 180px;
  }
}

/* Skeleton Loader Improvements - Prevent CLS */
.skeleton-loader {
  min-height: 120px;
  background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.5s ease-in-out infinite;
  border-radius: 0.5rem;
}

@keyframes skeleton-loading {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}
</style>

