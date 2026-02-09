<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-4">{{ $t('inventory.reports.control') }}</h1>
      <p class="text-sm text-gray-600 mb-4">Ledger-only. Opening / In / Out / Closing from fn_inventory_control_report.</p>
      <div class="flex flex-wrap gap-4 items-end mb-4">
        <div><label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.fromDate') }}</label><input v-model="fromDate" type="date" class="px-4 py-2 border rounded-lg" /></div>
        <div><label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.toDate') }}</label><input v-model="toDate" type="date" class="px-4 py-2 border rounded-lg" /></div>
        <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">{{ $t('common.search') }}</button>
      </div>
    </div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-2 text-left font-semibold">Item</th>
            <th class="px-4 py-2 text-left font-semibold">Location</th>
            <th class="px-4 py-2 text-right font-semibold">Opening Qty</th>
            <th class="px-4 py-2 text-right font-semibold">Opening Cost</th>
            <th class="px-4 py-2 text-right font-semibold">Total In</th>
            <th class="px-4 py-2 text-right font-semibold">Total Out</th>
            <th class="px-4 py-2 text-right font-semibold">Closing Qty</th>
            <th class="px-4 py-2 text-right font-semibold">Closing Cost</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-if="loading"><td colspan="8" class="px-4 py-8 text-center"><i class="fas fa-spinner fa-spin"></i></td></tr>
          <tr v-else-if="!rows.length"><td colspan="8" class="px-4 py-8 text-center text-gray-500">{{ $t('common.noData') }}</td></tr>
          <tr v-else v-for="(r, i) in rows" :key="(r.item_id || '') + (r.location_id || '') + i">
            <td class="px-4 py-2">{{ r.item_name }} ({{ r.sku }})</td>
            <td class="px-4 py-2">{{ r.location_name }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.opening_qty) }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.opening_cost) }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.total_in) }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.total_out) }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.closing_qty) }}</td>
            <td class="px-4 py-2 text-right">{{ formatNum(r.closing_cost) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { fetchInventoryControlReport } from '@/services/erpViews.js';

const { t } = useI18n();
const fromDate = ref(new Date().getFullYear() + '-01-01');
const toDate = ref(new Date().toISOString().split('T')[0]);
const loading = ref(false);
const rows = ref([]);

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 4 });
}

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchInventoryControlReport(fromDate.value, toDate.value);
  } catch (e) {
    console.warn(e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => load());
</script>
