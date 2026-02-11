<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.control') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Ledger-only. Opening / In / Out / Closing from fn_inventory_control_report.</p>
      <div class="flex flex-wrap gap-4 items-end">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.fromDate') }}</label>
          <input v-model="fromDate" type="date" class="px-4 py-2 border rounded-lg" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.toDate') }}</label>
          <input v-model="toDate" type="date" class="px-4 py-2 border rounded-lg" />
        </div>
        <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
          <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
        </button>
      </div>
    </div>

    <ReportTable
      :columns="columns"
      :data="rowsWithId"
      :loading="loading"
      row-key="rowId"
      :search-keys="['item_name','sku','location_name']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchInventoryControlReport } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const fromDate = ref(new Date().getFullYear() + '-01-01');
const toDate = ref(new Date().toISOString().split('T')[0]);
const loading = ref(false);
const rows = ref([]);

const rowsWithId = computed(() => rows.value.map((r, i) => ({ ...r, rowId: (r.item_id || '') + (r.location_id || '') + i })));

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

const columns = computed(() => [
  { key: 'item_name', label: 'Item', sortable: true },
  { key: 'sku', label: 'SKU', sortable: true },
  { key: 'location_name', label: 'Location', sortable: true },
  { key: 'opening_qty', label: 'Opening Qty', align: 'right', sortable: true, format: formatNum },
  { key: 'opening_cost', label: 'Opening Cost', align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' },
  { key: 'total_in', label: 'Total In', align: 'right', sortable: true, format: formatNum },
  { key: 'total_out', label: 'Total Out', align: 'right', sortable: true, format: formatNum },
  { key: 'closing_qty', label: 'Closing Qty', align: 'right', sortable: true, format: formatNum },
  { key: 'closing_cost', label: 'Closing Cost', align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' }
]);

function doExportExcel() {
  exportExcel(rowsWithId.value, columns.value, 'inventory_control');
}

function doExportPDF() {
  window.print();
}

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchInventoryControlReport(fromDate.value, toDate.value);
  } catch (e) {
    console.warn(e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => load());
</script>
