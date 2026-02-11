<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.purchasing') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Purchase analytics from v_purchasing_report (ledger-validated).</p>
      <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
        <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
      </button>
    </div>
    <ReportTable
      :columns="columns"
      :data="rows"
      :loading="loading"
      row-key="id"
      :search-keys="['invoice_number','grn_number','supplier_name','location_name']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchPurchasingReport } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

const columns = computed(() => [
  { key: 'invoice_number', label: 'Invoice', sortable: true },
  { key: 'grn_number', label: 'GRN', sortable: true },
  { key: 'supplier_name', label: 'Supplier', sortable: true },
  { key: 'location_name', label: 'Location', sortable: true },
  { key: 'grand_total', label: 'Grand Total', align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' },
  { key: 'status', label: 'Status', sortable: true }
]);

function doExportExcel() { exportExcel(rows.value, columns.value, 'purchasing_report'); }
function doExportPDF() { window.print(); }

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchPurchasingReport();
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
