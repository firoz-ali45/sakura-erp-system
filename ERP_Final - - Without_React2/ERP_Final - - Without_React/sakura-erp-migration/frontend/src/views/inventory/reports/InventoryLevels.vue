<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-1">{{ $t('inventory.reports.inventoryLevels') }}</h1>
      <p class="text-sm text-gray-600 mb-4">{{ $t('inventory.reports.levelsDesc') }}</p>
      <div class="flex flex-wrap gap-4 items-center">
        <input
          v-model="searchText"
          type="text"
          :placeholder="$t('inventory.stockOverview.filterItem')"
          class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] w-64"
        />
        <button
          type="button"
          @click="load"
          class="px-4 py-2 rounded-lg text-white flex items-center gap-2"
          style="background-color: #284b44;"
        >
          <i class="fas fa-sync-alt"></i>
          {{ $t('common.search') }}
        </button>
      </div>
    </div>

    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.itemName') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">SKU</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.batch') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.currentQty') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="4" class="px-6 py-12"><i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i></td>
          </tr>
          <tr v-else-if="!filteredRows.length" class="text-center">
            <td colspan="4" class="px-6 py-12 text-gray-500">{{ $t('inventory.stockOverview.noData') }}</td>
          </tr>
          <tr v-else v-for="row in filteredRows" :key="row.item_id" class="hover:bg-gray-50">
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.item_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.sku || row.item_code || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ batchDisplay(row) }}</td>
            <td class="px-6 py-4 text-sm text-right font-medium">{{ formatQty(row.total_stock) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const loading = ref(false);
const rows = ref([]);
const searchText = ref('');

const filteredRows = computed(() => {
  let list = rows.value;
  const q = (searchText.value || '').trim().toLowerCase();
  if (!q) return list;
  return list.filter(r =>
    (r.item_name || '').toLowerCase().includes(q) ||
    (r.sku || r.item_code || '').toLowerCase().includes(q) ||
    (rowBatchText(r).toLowerCase().includes(q))
  );
});

function rowBatchText(row) {
  const n = Number(row.batch_count);
  if (n === 1) return row.latest_batch || (Array.isArray(row.batch_numbers) && row.batch_numbers[0]) || '';
  return n > 1 ? `${n} batches` : '';
}

function formatQty(n) {
  const v = Number(n);
  return isNaN(v) ? '0' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

function formatCost(n) {
  const v = Number(n);
  return isNaN(v) ? '0.00' : v.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' SAR';
}

/** Batch display: 1 batch → batch number; >1 → "N batches"; 0 → "—" (DB-driven, no local calc) */
function batchDisplay(row) {
  const n = Number(row.batch_count);
  if (n === 0) return '—';
  if (n === 1) return row.latest_batch || (Array.isArray(row.batch_numbers) && row.batch_numbers[0]) || '—';
  return `${n} batches`;
}

async function load() {
  loading.value = true;
  try {
    const { fetchItemStockFull } = await import('@/services/erpViews.js');
    const data = await fetchItemStockFull();
    rows.value = (data || []).map(r => ({ ...r, sku: r.item_code }));
  } catch (e) {
    console.warn('Inventory Levels load:', e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  load();
});
</script>
