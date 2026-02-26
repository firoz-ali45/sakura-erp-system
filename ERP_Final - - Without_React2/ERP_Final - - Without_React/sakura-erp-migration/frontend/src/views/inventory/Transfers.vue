<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex justify-between items-center mb-6">
      <div class="bg-white rounded-xl shadow-md p-6 flex-1">
        <h1 class="text-2xl font-bold text-gray-800">Transfers</h1>
        <p class="text-sm text-gray-600 mt-1">Stock transfer execution — TRS numbers, Dispatch & Receive</p>
      </div>
      <button
        @click="openNewTransferModal"
        class="px-6 py-3 rounded-lg text-white font-semibold flex items-center gap-2 ml-4"
        style="background-color: #284b44;"
      >
        <i class="fas fa-plus"></i> New Transfer
      </button>
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
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Transfer No (TRS)</th>
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
              <td colspan="7" class="px-6 py-12 text-center text-gray-500">No transfers. Create from Transfer Order (Send Items) or use + New Transfer for direct transfer.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- New Transfer Modal (Direct, without TO) -->
    <div v-if="showNewTransferModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showNewTransferModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">New Transfer (Direct)</h3>
        <p class="text-sm text-gray-600 mb-4">Create transfer without Transfer Order. Add items after creation.</p>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Source warehouse *</label>
            <select v-model="newTransferForm.from_location_id" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Select...</option>
              <option v-for="loc in sourceLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }} ({{ loc.location_code }})</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Destination warehouse *</label>
            <select v-model="newTransferForm.to_location_id" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Select...</option>
              <option v-for="loc in destLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }} ({{ loc.location_code }})</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Business date</label>
            <input v-model="newTransferForm.business_date" type="date" class="w-full px-3 py-2 border rounded-lg" />
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showNewTransferModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button
            @click="createDirectTransfer"
            :disabled="creating || !newTransferForm.from_location_id || !newTransferForm.to_location_id || newTransferForm.from_location_id === newTransferForm.to_location_id"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            {{ creating ? 'Creating...' : 'Create' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { getCurrentUserUUID } from '@/utils/uuidUtils';
import { fetchStockTransfersList, createDirectTransfer as createDirectTransferApi } from '@/services/transferEngine.js';
import { loadTransferSourceLocations, loadTransferDestLocations } from '@/composables/useInventoryLocations.js';
import { showNotification } from '@/utils/notifications';

const router = useRouter();
const transfers = ref([]);
const loading = ref(true);
const showNewTransferModal = ref(false);
const creating = ref(false);
const sourceLocations = ref([]);
const destLocations = ref([]);
const newTransferForm = ref({
  from_location_id: '',
  to_location_id: '',
  business_date: new Date().toISOString().slice(0, 10)
});

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

async function openNewTransferModal() {
  showNewTransferModal.value = true;
  sourceLocations.value = await loadTransferSourceLocations();
  destLocations.value = await loadTransferDestLocations();
  newTransferForm.value = {
    from_location_id: '',
    to_location_id: '',
    business_date: new Date().toISOString().slice(0, 10)
  };
}

function getCurrentUserName() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (u) { const d = JSON.parse(u); return d.name || d.email?.split('@')[0] || 'user'; }
  } catch (_) {}
  return 'user';
}

async function createDirectTransfer() {
  const f = newTransferForm.value;
  if (!f.from_location_id || !f.to_location_id || f.from_location_id === f.to_location_id) return;
  creating.value = true;
  try {
    const result = await createDirectTransferApi(f.from_location_id, f.to_location_id, f.business_date, getCurrentUserUUID());
    if (result?.ok && result.transfer_id) {
      showNotification('Transfer created: ' + (result.transfer_number || ''), 'success');
      showNewTransferModal.value = false;
      await load();
      router.push(`/homeportal/transfer-sending/${result.transfer_id}`);
    } else {
      showNotification(result?.error || 'Create failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    creating.value = false;
  }
}

onMounted(() => load());
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
