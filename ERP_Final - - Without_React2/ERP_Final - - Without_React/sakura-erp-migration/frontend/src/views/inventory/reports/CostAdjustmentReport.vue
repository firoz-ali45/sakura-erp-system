<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.costAdjustment') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Cost adjustments from v_cost_adjustment_history (ledger movement_type in ADJUSTMENT, COST_ADJUSTMENT, etc.).</p>
      <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
        <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
      </button>
    </div>
    <ReportTable
      :columns="columns"
      :data="rows"
      :loading="loading"
      row-key="id"
      :search-keys="['item_name','sku','barcode','branch','reference','created_by','submitted_by']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchCostAdjustmentHistory } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);

function formatCost(v) {
  const n = Number(v);
  return isNaN(n) ? '—' : '₹ ' + n.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

const columns = computed(() => [
  { key: 'item_name', label: 'Name', sortable: true },
  { key: 'sku', label: 'SKU', sortable: true },
  { key: 'barcode', label: 'Barcode', sortable: true, format: v => v || '—' },
  { key: 'storage_unit', label: 'Storage Unit', sortable: true, format: v => v || '—' },
  { key: 'branch', label: 'Branch', sortable: true },
  { key: 'reference', label: 'Reference', sortable: true, format: v => (v && String(v).trim()) || '—' },
  { key: 'original_cost_per_unit', label: 'Original Cost per Unit', align: 'right', sortable: true, format: formatCost },
  { key: 'new_cost_per_unit', label: 'New Cost per Unit', align: 'right', sortable: true, format: formatCost },
  { key: 'created_by', label: 'Created By', sortable: true, format: v => v || '—' },
  { key: 'submitted_by', label: 'Submitted By', sortable: true, format: v => v || '—' },
  { key: 'submitted_at', label: 'Submitted At', sortable: true, format: d => d ? new Date(d).toLocaleString() : '—' }
]);

function doExportExcel() { exportExcel(rows.value, columns.value, 'cost_adjustment_history'); }
function doExportPDF() { window.print(); }

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchCostAdjustmentHistory();
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
