<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800 mb-4">{{ $t('inventory.reports.control') }}</h1>
      <div class="flex flex-wrap gap-4 items-end mb-4">
        <div><label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.fromDate') }}</label><input v-model="fromDate" type="date" class="px-4 py-2 border rounded-lg" /></div>
        <div><label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.reports.toDate') }}</label><input v-model="toDate" type="date" class="px-4 py-2 border rounded-lg" /></div>
        <button @click="load" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">{{ $t('common.search') }}</button>
      </div>
    </div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left font-semibold">Item</th><th class="px-4 py-2 text-left font-semibold">Location</th><th class="px-4 py-2 text-left font-semibold">Date</th><th class="px-4 py-2 text-left font-semibold">Type</th><th class="px-4 py-2 text-right font-semibold">Qty In</th><th class="px-4 py-2 text-right font-semibold">Qty Out</th><th class="px-4 py-2 text-right font-semibold">Cost</th></tr></thead>
        <tbody class="divide-y"><tr v-if="loading"><td colspan="7" class="px-4 py-8 text-center"><i class="fas fa-spinner fa-spin"></i></td></tr><tr v-else-if="!rows.length"><td colspan="7" class="px-4 py-8 text-center text-gray-500">{{ $t('common.noData') }}</td></tr><tr v-else v-for="r in rows" :key="r.item_id + r.location_id + r.report_date + r.movement_type"><td class="px-4 py-2">{{ r.item_name }} ({{ r.sku }})</td><td class="px-4 py-2">{{ r.location }}</td><td class="px-4 py-2">{{ r.report_date }}</td><td class="px-4 py-2">{{ r.movement_type }}</td><td class="px-4 py-2 text-right">{{ r.qty_in }}</td><td class="px-4 py-2 text-right">{{ r.qty_out }}</td><td class="px-4 py-2 text-right">{{ r.total_cost }}</td></tr></tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
const { t } = useI18n();
const fromDate = ref(new Date().getFullYear() + '-01-01');
const toDate = ref(new Date().toISOString().split('T')[0]);
const loading = ref(false);
const rows = ref([]);
async function load() {
  loading.value = true;
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) { rows.value = []; return; }
    let q = supabaseClient.from('v_inventory_control').select('*').order('report_date', { ascending: false }).limit(500);
    if (fromDate.value) q = q.gte('report_date', fromDate.value);
    if (toDate.value) q = q.lte('report_date', toDate.value);
    const { data } = await q;
    rows.value = data || [];
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
