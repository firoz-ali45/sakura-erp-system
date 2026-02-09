<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-4">{{ $t('inventory.stockOverview.title') }}</h1>
      <div class="flex flex-wrap gap-4 items-end">
        <div class="flex-1 min-w-[180px]">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterItem') }}</label>
          <input v-model="filters.itemSearch" type="text" placeholder="Code or name" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]" />
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

    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.itemCode') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.itemName') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.currentQty') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.batch') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">Batch count</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="5" class="px-6 py-12"><i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i></td>
          </tr>
          <tr v-else-if="!filteredRows.length" class="text-center">
            <td colspan="5" class="px-6 py-12 text-gray-500">{{ $t('inventory.stockOverview.noData') }}</td>
          </tr>
          <tr v-else v-for="row in filteredRows" :key="row.item_id" class="hover:bg-gray-50">
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.item_code || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.item_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-right font-medium">{{ formatQty(row.total_stock) }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ batchDisplay(row) }}</td>
            <td class="px-6 py-4 text-sm text-right">{{ row.batch_count ?? 0 }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchItemStockFull } from '@/services/erpViews.js';

const { t } = useI18n();

/** Listen for global refresh after any PR/PO/GRN/Purchase/Payment action — no cached state */
function onRefreshStock() {
  load();
}
const loading = ref(false);
const rows = ref([]);
const filters = ref({
  itemSearch: '',
  showZero: false
});

const filteredRows = computed(() => {
  let list = rows.value;
  if (filters.value.itemSearch.trim()) {
    const q = filters.value.itemSearch.trim().toLowerCase();
    list = list.filter(r =>
      (r.item_code || '').toLowerCase().includes(q) ||
      (r.item_name || '').toLowerCase().includes(q)
    );
  }
  if (!filters.value.showZero) list = list.filter(r => Number(r.total_stock) !== 0);
  return list;
});

/** Batch column: 1 batch → show batch number; >1 → "N batches"; 0 → "—" */
function batchDisplay(row) {
  const n = Number(row.batch_count);
  if (n === 0) return '—';
  if (n === 1) return row.latest_batch || (Array.isArray(row.batch_numbers) && row.batch_numbers[0]) || '—';
  return `${n} batches`;
}

function formatQty(n) {
  const v = Number(n);
  return isNaN(v) ? '0' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchItemStockFull();
  } catch (e) {
    console.warn('StockOverview load:', e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  load();
  window.addEventListener('erp:refresh-stock', onRefreshStock);
});
onUnmounted(() => {
  window.removeEventListener('erp:refresh-stock', onRefreshStock);
});
</script>
