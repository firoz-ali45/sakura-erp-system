<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.stockOverview.title') }}</h1>
      <p class="text-sm text-gray-600 mb-4">{{ $t('inventory.reports.levelsDesc') }}</p>
      <div class="flex flex-wrap gap-4 items-end">
        <div class="min-w-[160px]">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterItem') }}</label>
          <input v-model="filters.itemSearch" type="text" placeholder="Name, SKU" class="w-full px-4 py-2 border rounded-lg" />
        </div>
        <div class="min-w-[160px]">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterLocation') }}</label>
          <select v-model="filters.locationId" class="w-full px-4 py-2 border rounded-lg">
            <option value="">All</option>
            <option v-for="loc in locations" :key="loc.id" :value="loc.id">{{ loc.location_name }}</option>
          </select>
        </div>
        <div class="min-w-[160px]">
          <label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
          <input v-model="filters.category" type="text" placeholder="Category" class="w-full px-4 py-2 border rounded-lg" />
        </div>
        <label class="flex items-center gap-2">
          <input v-model="filters.showZero" type="checkbox" class="rounded" />
          <span class="text-sm">{{ $t('inventory.stockOverview.showZeroStock') }}</span>
        </label>
        <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">
          <i class="fas fa-sync-alt mr-1"></i> {{ $t('common.search') }}
        </button>
      </div>
    </div>

    <ReportTable
      :columns="columns"
      :data="filteredRows"
      :loading="loading"
      row-key="rowId"
      :search-keys="['item_name','sku','location_name','batch_no','category']"
      :exportable="true"
      @export-excel="doExportExcel"
      @export-pdf="doExportPDF"
      @refresh="load"
      @row-click="goToItemHistory"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { fetchInventoryBalance } from '@/services/erpViews.js';
import { useReportExport } from '@/composables/useReportExport.js';
import ReportTable from '@/components/reports/ReportTable.vue';
import { loadInventoryLocations } from '@/composables/useInventoryLocations.js';

const { t } = useI18n();
const router = useRouter();
const { exportExcel } = useReportExport();
const locations = ref([]);

const loading = ref(false);
const rows = ref([]);
const filters = ref({
  itemSearch: '',
  locationId: '',
  category: '',
  showZero: false
});

const columns = computed(() => [
  { key: 'item_name', label: t('inventory.stockOverview.itemName'), sortable: true },
  { key: 'sku', label: t('inventory.stockOverview.itemCode'), sortable: true },
  { key: 'category', label: 'Category', sortable: true },
  { key: 'location_name', label: t('inventory.stockOverview.location'), sortable: true },
  { key: 'batch_no', label: t('inventory.stockOverview.batch'), sortable: true },
  { key: 'current_qty', label: t('inventory.stockOverview.currentQty'), align: 'right', sortable: true, format: formatNum },
  { key: 'avg_cost', label: t('inventory.stockOverview.avgUnitCost'), align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' },
  { key: 'total_value', label: t('inventory.stockOverview.totalValue'), align: 'right', sortable: true, format: v => formatNum(v) + ' SAR' }
]);

const filteredRows = computed(() => {
  let list = rows.value;
  if (filters.value.locationId) list = list.filter(r => r.location_id === filters.value.locationId);
  if (filters.value.category?.trim()) {
    const q = filters.value.category.trim().toLowerCase();
    list = list.filter(r => (r.category || '').toLowerCase().includes(q));
  }
  if (filters.value.itemSearch?.trim()) {
    const q = filters.value.itemSearch.trim().toLowerCase();
    list = list.filter(r =>
      (r.item_name || '').toLowerCase().includes(q) || (r.sku || '').toLowerCase().includes(q)
    );
  }
  if (!filters.value.showZero) list = list.filter(r => Number(r.current_qty) !== 0);
  return list.map((r, i) => ({ ...r, rowId: (r.item_id || '') + (r.location_id || '') + (r.batch_id || '') + i }));
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '0' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

function doExportExcel() {
  exportExcel(filteredRows.value, columns, 'stock_overview');
}

function doExportPDF() {
  window.print();
}

function goToItemHistory(row) {
  if (row?.item_id) router.push({ path: `/homeportal/reports/inventory-history`, query: { item_id: row.item_id } });
}

function onRefreshStock() { load(); }

async function load() {
  loading.value = true;
  try {
    const data = await fetchInventoryBalance();
    rows.value = data || [];
  } catch (e) {
    console.warn('StockOverview load:', e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  locations.value = await loadInventoryLocations(true);
  load();
  window.addEventListener('erp:refresh-stock', onRefreshStock);
});
onUnmounted(() => {
  window.removeEventListener('erp:refresh-stock', onRefreshStock);
});
</script>
