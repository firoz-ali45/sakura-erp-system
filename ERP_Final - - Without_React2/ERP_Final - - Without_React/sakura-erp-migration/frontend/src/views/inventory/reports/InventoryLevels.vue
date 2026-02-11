<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.inventoryLevels') }}</h1>
      <p class="text-sm text-gray-600 mb-4">{{ $t('inventory.reports.levelsDesc') }}</p>
      <div class="flex flex-wrap gap-4 items-center">
        <input v-model="searchText" type="text" :placeholder="$t('inventory.stockOverview.filterItem')" class="px-4 py-2 border rounded-lg w-64" />
        <button type="button" @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
          <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
        </button>
      </div>
    </div>

    <ReportTable
      :columns="matrixColumns"
      :data="matrixRows"
      :loading="loading"
      row-key="item_id"
      :searchable="true"
      :exportable="true"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchInventoryBalance } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';

const { t } = useI18n();
const { exportExcel } = useReportExport();
const loading = ref(false);
const rows = ref([]);
const searchText = ref('');

// Pivot: item -> { item_name, sku, [loc_name]: qty, total }
const matrixRows = computed(() => {
  const list = rows.value;
  const q = (searchText.value || '').trim().toLowerCase();
  const filtered = q ? list.filter(r => (r.item_name || '').toLowerCase().includes(q) || (r.sku || '').toLowerCase().includes(q)) : list;
  const byItem = {};
  for (const r of filtered) {
    const key = r.item_id || '';
    if (!byItem[key]) {
      byItem[key] = { item_id: key, item_name: r.item_name, sku: r.sku, _locs: {} };
    }
    const loc = r.location_name || 'Other';
    byItem[key]._locs[loc] = (byItem[key]._locs[loc] || 0) + Number(r.current_qty || 0);
  }
  const locs = [...new Set(filtered.map(r => r.location_name || 'Other'))].sort();
  return Object.values(byItem).map(row => {
    const r = { item_id: row.item_id, item_name: row.item_name, sku: row.sku };
    let total = 0;
    for (const loc of locs) {
      const qty = row._locs[loc] || 0;
      r[loc] = qty;
      total += qty;
    }
    r.total = total;
    return r;
  });
});

const matrixColumns = computed(() => {
  const locs = [...new Set(rows.value.map(r => r.location_name || 'Other'))].sort();
  const cols = [
    { key: 'item_name', label: t('inventory.stockOverview.itemName'), sortable: true },
    { key: 'sku', label: 'SKU', sortable: true }
  ];
  for (const loc of locs) cols.push({ key: loc, label: loc, align: 'right', sortable: true, format: formatNum });
  cols.push({ key: 'total', label: 'Total', align: 'right', sortable: true, format: formatNum });
  return cols;
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '0' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

function doExportExcel() {
  exportExcel(matrixRows.value, matrixColumns.value, 'inventory_levels');
}

function doExportPDF() {
  window.print();
}

async function load() {
  loading.value = true;
  try {
    const data = await fetchInventoryBalance();
    rows.value = data || [];
  } catch (e) {
    console.warn('Inventory Levels load:', e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => load());
</script>
