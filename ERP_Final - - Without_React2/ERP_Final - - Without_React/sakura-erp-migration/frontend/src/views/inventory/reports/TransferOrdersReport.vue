<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.transferOrders') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Transfer orders from v_transfer_orders_report.</p>
      <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
        <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
      </button>
    </div>
    <ReportTable
      :columns="columns"
      :data="rows"
      :loading="loading"
      row-key="id"
      :search-keys="['transfer_number','source_name','dest_name','status']"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchTransferOrdersReport } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);

const columns = computed(() => [
  { key: 'transfer_number', label: 'Transfer #', sortable: true },
  { key: 'source_name', label: 'From', sortable: true },
  { key: 'dest_name', label: 'To', sortable: true },
  { key: 'transfer_date', label: 'Date', sortable: true, format: d => d ? new Date(d).toLocaleDateString() : '—' },
  { key: 'status', label: 'Status', sortable: true }
]);

function doExportExcel() { exportExcel(rows.value, columns.value, 'transfer_orders_report'); }
function doExportPDF() { window.print(); }

async function load() {
  loading.value = true;
  try {
    const data = await fetchTransferOrdersReport();
    rows.value = (data || []).map(r => ({ ...r, source_name: r.source_name || r.source_code, dest_name: r.dest_name || r.dest_code }));
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
