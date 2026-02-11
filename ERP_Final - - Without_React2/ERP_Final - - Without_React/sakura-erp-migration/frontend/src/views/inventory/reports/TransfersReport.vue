<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.transfers') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Actual stock movement from v_transfers_report (TRANSFER_IN/OUT — ledger only).</p>
      <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
        <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
      </button>
    </div>
    <ReportTable
      :columns="columns"
      :data="rows"
      :loading="loading"
      row-key="id"
      :search-keys="['item_name','sku','location_name','movement_type']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchTransfersReport } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

const columns = computed(() => [
  { key: 'item_name', label: 'Item', sortable: true },
  { key: 'sku', label: 'SKU', sortable: true },
  { key: 'location_name', label: 'Location', sortable: true },
  { key: 'movement_type', label: 'Type', sortable: true },
  { key: 'qty_in', label: 'Qty In', align: 'right', sortable: true, format: formatNum },
  { key: 'qty_out', label: 'Qty Out', align: 'right', sortable: true, format: formatNum },
  { key: 'total_cost', label: 'Cost', align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' },
  { key: 'created_at', label: 'Date', sortable: true, format: d => d ? new Date(d).toLocaleString() : '—' }
]);

function doExportExcel() { exportExcel(rows.value, columns.value, 'transfers_report'); }
function doExportPDF() { window.print(); }

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchTransfersReport();
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
