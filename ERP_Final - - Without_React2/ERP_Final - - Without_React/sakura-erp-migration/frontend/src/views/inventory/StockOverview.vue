<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-4">{{ $t('inventory.stockOverview.title') }}</h1>
      <div class="flex flex-wrap gap-4 items-end">
        <div class="flex-1 min-w-[180px]">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterItem') }}</label>
          <input v-model="filters.itemSearch" type="text" placeholder="Code or name" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]" />
        </div>
        <div class="w-48">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterLocation') }}</label>
          <select v-model="filters.locationId" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]">
            <option value="">{{ $t('common.all') }}</option>
            <option v-for="loc in locationList" :key="loc.id" :value="loc.id">{{ loc.location_name }} ({{ loc.location_code }})</option>
          </select>
        </div>
        <div class="w-48">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.stockOverview.filterBatch') }}</label>
          <input v-model="filters.batchSearch" type="text" placeholder="Optional" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]" />
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
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.location') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.batch') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.currentQty') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.avgUnitCost') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.totalValue') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="7" class="px-6 py-12"><i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i></td>
          </tr>
          <tr v-else-if="!filteredRows.length" class="text-center">
            <td colspan="7" class="px-6 py-12 text-gray-500">{{ $t('inventory.stockOverview.noData') }}</td>
          </tr>
          <tr v-else v-for="row in filteredRows" :key="rowKey(row)" class="hover:bg-gray-50">
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.item_code || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.item_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.location_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.batch_number != null && row.batch_number !== '' ? row.batch_number : '—' }}</td>
            <td class="px-6 py-4 text-sm text-right font-medium">{{ formatQty(row.current_qty) }}</td>
            <td class="px-6 py-4 text-sm text-right">{{ formatCost(row.avg_unit_cost) }}</td>
            <td class="px-6 py-4 text-sm text-right">{{ formatCost(row.total_value) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { loadInventoryLocations } from '@/composables/useInventoryLocations';

const { t } = useI18n();
const loading = ref(false);
const balanceRows = ref([]);
const itemsMap = ref({});
const locationsMap = ref({});
const batchesMap = ref({});
const locationList = ref([]);
const filters = ref({
  itemSearch: '',
  locationId: '',
  batchSearch: '',
  showZero: false
});
const filteredRows = computed(() => {
  let rows = balanceRows.value;
  if (filters.value.itemSearch.trim()) {
    const q = filters.value.itemSearch.trim().toLowerCase();
    rows = rows.filter(r => (r.item_code || '').toLowerCase().includes(q) || (r.item_name || '').toLowerCase().includes(q));
  }
  if (filters.value.locationId) rows = rows.filter(r => r.location_id === filters.value.locationId);
  if (filters.value.batchSearch.trim()) {
    const q = filters.value.batchSearch.trim().toLowerCase();
    rows = rows.filter(r => (r.batch_number || '').toLowerCase().includes(q));
  }
  if (!filters.value.showZero) rows = rows.filter(r => Number(r.current_qty) !== 0);
  return rows;
});

function rowKey(row) {
  return `${row.item_id}-${row.location_id}-${row.batch_id || 'x'}`;
}

function formatQty(n) {
  const v = Number(n);
  return isNaN(v) ? '0' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

function formatCost(n) {
  const v = Number(n);
  return isNaN(v) ? '0.00' : v.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' SAR';
}

async function load() {
  loading.value = true;
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) {
      balanceRows.value = [];
      return;
    }
    const [balanceRes, itemsRes, locsRes, batchesRes] = await Promise.all([
      supabaseClient.from('v_inventory_balance').select('*'),
      supabaseClient.from('inventory_items').select('id, sku, name').eq('deleted', false),
      supabaseClient.from('inventory_locations').select('id, location_code, location_name'),
      supabaseClient.from('inventory_batches').select('id, batch_number')
    ]);
    const balance = balanceRes.data || [];
    const items = itemsRes.data || [];
    const locs = locsRes.data || [];
    const batches = batchesRes.data || [];
    itemsMap.value = Object.fromEntries(items.map(i => [i.id, i]));
    locationsMap.value = Object.fromEntries(locs.map(l => [l.id, l]));
    batchesMap.value = Object.fromEntries(batches.map(b => [b.id, b]));
    locationList.value = locs;
    balanceRows.value = balance.map(b => {
      const item = itemsMap.value[b.item_id];
      const loc = locationsMap.value[b.location_id];
      const batch = b.batch_id ? batchesMap.value[b.batch_id] : null;
      return {
        ...b,
        item_code: item?.sku || item?.name,
        item_name: item?.name || item?.sku,
        location_name: loc ? `${loc.location_name} (${loc.location_code})` : null,
        batch_number: b.batch_number != null && b.batch_number !== '' ? b.batch_number : null
      };
    });
  } catch (e) {
    console.warn('StockOverview load:', e);
    balanceRows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  load();
});
</script>
