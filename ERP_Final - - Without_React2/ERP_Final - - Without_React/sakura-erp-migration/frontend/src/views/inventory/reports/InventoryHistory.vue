<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.history') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Full ledger audit. Every movement from inventory_stock_ledger.</p>
      <div class="flex flex-wrap gap-4 items-center">
        <input v-model="searchText" type="text" :placeholder="$t('common.search')" class="px-4 py-2 border rounded-lg w-64" />
        <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
          <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
        </button>
      </div>
    </div>

    <ReportTable
      :columns="columns"
      :data="filteredRows"
      :loading="loading"
      row-key="id"
      :search-keys="['item_name','sku','location','transaction_type','reference','reason','created_by']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchInventoryHistory } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);
const searchText = ref('');

function formatDate(d) {
  if (!d) return '—';
  const x = new Date(d);
  return isNaN(x.getTime()) ? '—' : x.toLocaleString();
}

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

const columns = computed(() => [
  { key: 'created_at', label: 'Date', sortable: true, format: formatDate },
  { key: 'item_name', label: 'Item', sortable: true },
  { key: 'sku', label: 'SKU', sortable: true },
  { key: 'location', label: 'Location', sortable: true },
  { key: 'transaction_type', label: 'Type', sortable: true },
  { key: 'reference', label: 'Reference', sortable: true },
  { key: 'qty', label: 'Qty', align: 'right', sortable: true, format: formatNum },
  { key: 'cost', label: 'Cost', align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' },
  { key: 'reason', label: 'Reason', sortable: true },
  { key: 'created_by', label: 'User', sortable: true }
]);

const filteredRows = computed(() => rows.value);

function doExportExcel() {
  exportExcel(filteredRows.value, columns.value, 'inventory_history');
}

function doExportPDF() {
  window.print();
}

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchInventoryHistory();
  } catch (e) {
    console.warn(e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => load());
</script>
