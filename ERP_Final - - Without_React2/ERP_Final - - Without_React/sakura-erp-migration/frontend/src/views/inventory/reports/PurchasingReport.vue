<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6"><h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.reports.purchasing') }}</h1></div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left font-semibold">Invoice</th><th class="px-4 py-2 text-left font-semibold">GRN</th><th class="px-4 py-2 text-left font-semibold">Supplier</th><th class="px-4 py-2 text-left font-semibold">Location</th><th class="px-4 py-2 text-right font-semibold">Grand Total</th><th class="px-4 py-2 text-left font-semibold">Status</th></tr></thead>
        <tbody class="divide-y"><tr v-if="loading"><td colspan="6" class="px-4 py-8 text-center"><i class="fas fa-spinner fa-spin"></i></td></tr><tr v-else-if="!rows.length"><td colspan="6" class="px-4 py-8 text-center text-gray-500">{{ $t('common.noData') }}</td></tr><tr v-else v-for="r in rows" :key="r.id"><td class="px-4 py-2">{{ r.invoice_number || r.purchasing_number }}</td><td class="px-4 py-2">{{ r.grn_number }}</td><td class="px-4 py-2">{{ r.supplier_name }}</td><td class="px-4 py-2">{{ r.location_name }} ({{ r.location_code }})</td><td class="px-4 py-2 text-right">{{ r.grand_total }}</td><td class="px-4 py-2">{{ r.status }}</td></tr></tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
useI18n();
const loading = ref(false);
const rows = ref([]);
async function load() {
  loading.value = true;
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) { rows.value = []; return; }
    const { data } = await supabaseClient.from('v_purchasing_report').select('*').limit(300);
    rows.value = data || [];
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
