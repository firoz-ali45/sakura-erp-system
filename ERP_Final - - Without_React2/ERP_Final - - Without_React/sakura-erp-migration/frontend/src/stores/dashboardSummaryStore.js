import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

/**
 * Dashboard Summary Store
 * 
 * Central shared state for dashboard summary KPIs.
 * Used by HomePortal to display summary data without fetching/recomputing.
 * 
 * Data is populated by:
 * - RMForecasting.vue (when forecasting processing completes)
 * - WarehouseDashboard.vue (when warehouse processing completes)
 * 
 * Data is consumed by:
 * - HomeDashboard.vue (via computed() bindings)
 * 
 * Data persists in localStorage to survive page refreshes.
 */
export const useDashboardSummaryStore = defineStore('dashboardSummary', () => {
  // Load from localStorage on initialization
  let savedRMData = null;
  let savedWarehouseData = null;
  
  try {
    if (typeof window !== 'undefined' && window.localStorage) {
      const savedRM = localStorage.getItem('sakura_rm_summary');
      const savedWH = localStorage.getItem('sakura_warehouse_summary');
      savedRMData = savedRM ? JSON.parse(savedRM) : null;
      savedWarehouseData = savedWH ? JSON.parse(savedWH) : null;
    }
  } catch (e) {
    console.warn('⚠️ [Pinia Store] Error reading from localStorage:', e);
  }

  // Raw Material Forecasting Summary
  const rawMaterialSummary = ref(savedRMData || {
    netPurchaseBudget: 0,
    itemsToPurchase: 0,
    potentialSavings: 0,
    overstockedValue: 0,
    forecastAccuracy: 0
  });

  // Warehouse Management Summary
  const warehouseSummary = ref(savedWarehouseData || {
    totalInventoryValue: 0,
    outOfStockCount: 0,
    lowStockCount: 0,
    transferValue: 0,
    purchaseValue: 0
  });

  // Actions: Update Raw Material Summary
  function updateRawMaterialSummary(data) {
    rawMaterialSummary.value = {
      netPurchaseBudget: Number(data.netPurchaseBudget) || 0,
      itemsToPurchase: Number(data.itemsToPurchase) || 0,
      potentialSavings: Number(data.potentialSavings) || 0,
      overstockedValue: Number(data.overstockedValue) || 0,
      forecastAccuracy: Number(data.forecastAccuracy) || 0
    };
    
    // Persist to localStorage
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.setItem('sakura_rm_summary', JSON.stringify(rawMaterialSummary.value));
      }
    } catch (e) {
      console.warn('⚠️ [Pinia Store] Error saving RM summary to localStorage:', e);
    }
    
    console.log('✅ [Pinia Store] Updated Raw Material Summary:', rawMaterialSummary.value);
  }

  // Actions: Update Warehouse Summary
  function updateWarehouseSummary(data) {
    warehouseSummary.value = {
      totalInventoryValue: Number(data.totalInventoryValue) || 0,
      outOfStockCount: Number(data.outOfStockCount) || 0,
      lowStockCount: Number(data.lowStockCount) || 0,
      transferValue: Number(data.transferValue) || 0,
      purchaseValue: Number(data.purchaseValue) || 0
    };
    
    // Persist to localStorage
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.setItem('sakura_warehouse_summary', JSON.stringify(warehouseSummary.value));
      }
    } catch (e) {
      console.warn('⚠️ [Pinia Store] Error saving warehouse summary to localStorage:', e);
    }
    
    console.log('✅ [Pinia Store] Updated Warehouse Summary:', warehouseSummary.value);
  }

  // Actions: Reset all summaries (for cleanup/refresh)
  function resetSummaries() {
    rawMaterialSummary.value = {
      netPurchaseBudget: 0,
      itemsToPurchase: 0,
      potentialSavings: 0,
      overstockedValue: 0,
      forecastAccuracy: 0
    };
    warehouseSummary.value = {
      totalInventoryValue: 0,
      outOfStockCount: 0,
      lowStockCount: 0,
      transferValue: 0,
      purchaseValue: 0
    };
    console.log('🔄 [Pinia Store] Reset all summaries');
  }

  // Computed: Get raw material summary (read-only)
  const getRawMaterialSummary = computed(() => rawMaterialSummary.value);

  // Computed: Get warehouse summary (read-only)
  const getWarehouseSummary = computed(() => warehouseSummary.value);

  // Computed: Check if summaries have data
  const hasData = computed(() => {
    const hasRMData = rawMaterialSummary.value.netPurchaseBudget > 0 || 
                     rawMaterialSummary.value.itemsToPurchase > 0 ||
                     rawMaterialSummary.value.forecastAccuracy > 0;
    const hasWarehouseData = warehouseSummary.value.totalInventoryValue > 0 ||
                            warehouseSummary.value.outOfStockCount > 0 ||
                            warehouseSummary.value.lowStockCount > 0;
    return hasRMData || hasWarehouseData;
  });

  return {
    // State
    rawMaterialSummary,
    warehouseSummary,
    
    // Computed
    getRawMaterialSummary,
    getWarehouseSummary,
    hasData,
    
    // Actions
    updateRawMaterialSummary,
    updateWarehouseSummary,
    resetSummaries
  };
});
