<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <h1 class="text-2xl font-bold text-gray-800">Transfers</h1>
      <p class="text-sm text-gray-600 mt-1">Stock transfer execution — TRS numbers, Dispatch & Receive</p>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading...</p>
    </div>

    <div v-else class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Transfer No</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Linked TO</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Source</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Destination</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created date</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="t in transfers" :key="t.id" class="hover:bg-gray-50">
              <td class="px-6 py-3 text-sm font-medium text-gray-900">{{ t.transfer_number || '—' }}</td>
              <td class="px-6 py-3 text-sm text-gray-700">{{ t.to_number || '—' }}</td>
              <td class="px-6 py-3 text-sm text-gray-700">{{ t.from_name || t.from_code || '—' }}</td>
              <td class="px-6 py-3 text-sm text-gray-700">{{ t.to_name || t.to_code || '—' }}</td>
              <td class="px-6 py-3">
                <span :class="['px-2 py-1 rounded text-xs font-medium', statusClass(t.status)]">{{ formatStatus(t.status) }}</span>
              </td>
              <td class="px-6 py-3 text-sm text-gray-600">{{ formatDate(t.created_at) }}</td>
              <td class="px-6 py-3 text-right">
                <router-link :to="`/homeportal/transfer-sending/${t.id}`" class="text-[#284b44] hover:text-[#1e3a36] font-medium">Open</router-link>
              </td>
            </tr>
            <tr v-if="!transfers.length">
              <td colspan="7" class="px-6 py-12 text-center text-gray-500">No transfers. Create a Transfer Order, approve it, then click Send Items.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { fetchStockTransfersList } from '@/services/transferEngine.js';

const transfers = ref([]);
const loading = ref(true);

function formatDate(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString('en-GB'); } catch { return d; }
}
function formatStatus(s) {
  const m = { draft: 'Draft', picked: 'Picked', in_transit: 'In Transit', partially_received: 'Partially Received', completed: 'Completed', cancelled: 'Cancelled' };
  return m[(s || '').toLowerCase()] || s;
}
function statusClass(s) {
  const m = {
    draft: 'bg-gray-100 text-gray-800',
    picked: 'bg-amber-100 text-amber-800',
    in_transit: 'bg-blue-100 text-blue-800',
    partially_received: 'bg-blue-100 text-blue-800',
    completed: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}

async function load() {
  loading.value = true;
  try {
    transfers.value = await fetchStockTransfersList();
  } catch (e) {
    console.warn(e);
    transfers.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => load());
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
