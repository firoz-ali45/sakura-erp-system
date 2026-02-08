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
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.items.storageUnit') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.location') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.batch') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.currentQty') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.avgUnitCost') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.stockOverview.totalValue') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="8" class="px-6 py-12"><i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i></td>
          </tr>
          <tr v-else-if="!filteredRows.length" class="text-center">
            <td colspan="8" class="px-6 py-12 text-gray-500">{{ $t('inventory.stockOverview.noData') }}</td>
          </tr>
          <tr v-else v-for="row in filteredRows" :key="rowKey(row)" class="hover:bg-gray-50">
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.item_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.sku || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.storage_unit || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.location_name || '—' }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ row.batch_number || '—' }}</td>
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
    (r.sku || '').toLowerCase().includes(q) ||
    (r.location_name || '').toLowerCase().includes(q) ||
    (r.batch_number || '').toLowerCase().includes(q)
  );
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
      rows.value = [];
      return;
    }
    const { data, error } = await supabaseClient
      .from('v_inventory_balance')
      .select('*')
      .order('item_name', { ascending: true });
    if (error) throw error;
    rows.value = data || [];
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
