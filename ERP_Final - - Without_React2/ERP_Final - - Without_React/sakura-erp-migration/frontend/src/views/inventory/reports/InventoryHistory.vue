<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6"><h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.reports.history') }}</h1></div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50"><tr><th class="px-4 py-2 text-left font-semibold">Item</th><th class="px-4 py-2 text-left font-semibold">Location</th><th class="px-4 py-2 text-left font-semibold">Type</th><th class="px-4 py-2 text-left font-semibold">Reference</th><th class="px-4 py-2 text-right font-semibold">Qty In</th><th class="px-4 py-2 text-right font-semibold">Qty Out</th><th class="px-4 py-2 text-right font-semibold">Cost</th><th class="px-4 py-2 text-left font-semibold">Created</th></tr></thead>
        <tbody class="divide-y"><tr v-if="loading"><td colspan="8" class="px-4 py-8 text-center"><i class="fas fa-spinner fa-spin"></i></td></tr><tr v-else-if="!rows.length"><td colspan="8" class="px-4 py-8 text-center text-gray-500">{{ $t('common.noData') }}</td></tr><tr v-else v-for="r in rows" :key="r.id"><td class="px-4 py-2">{{ r.item_name }} ({{ r.sku }})</td><td class="px-4 py-2">{{ r.location }}</td><td class="px-4 py-2">{{ r.transaction_type }}</td><td class="px-4 py-2">{{ r.reference }}</td><td class="px-4 py-2 text-right">{{ r.qty_in }}</td><td class="px-4 py-2 text-right">{{ r.qty_out }}</td><td class="px-4 py-2 text-right">{{ r.cost }}</td><td class="px-4 py-2">{{ formatDate(r.created_at) }}</td></tr></tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
const { t } = useI18n();
const loading = ref(false);
const rows = ref([]);
function formatDate(d) { if (!d) return '—'; const x = new Date(d); return isNaN(x.getTime()) ? '—' : x.toLocaleString(); }
async function load() {
  loading.value = true;
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) { rows.value = []; return; }
    const { data } = await supabaseClient.from('v_inventory_history').select('*').limit(500);
    rows.value = data || [];
  } catch (e) { console.warn(e); rows.value = []; }
  finally { loading.value = false; }
}
onMounted(() => load());
</script>
