<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div v-if="loadError" class="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6 text-amber-800">
      <p class="font-medium">Could not load production data.</p>
      <p class="text-sm mt-1">{{ loadError }}</p>
      <p class="text-sm mt-2">Ensure the manufacturing migrations are applied in Supabase (v_production_orders_full, production_orders, etc.).</p>
    </div>
    <div class="flex justify-between items-center mb-6">
      <div class="bg-white rounded-xl shadow-md p-6 flex-1">
        <h1 class="text-2xl font-bold text-gray-800">Inventory Production</h1>
        <p class="text-sm text-gray-600 mt-1">Production orders and raw material consumption</p>
      </div>
      <button
        @click="openNewProduction"
        class="px-6 py-3 rounded-lg text-white font-semibold flex items-center gap-2 ml-4"
        style="background-color: #284b44;"
      >
        <i class="fas fa-plus"></i> New Production
      </button>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading...</p>
    </div>

    <div v-else class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="flex gap-6 border-b border-gray-200 px-6 pt-4">
        <button
          v-for="tab in tabs"
          :key="tab.value"
          :class="['pb-3 text-sm font-medium border-b-2 transition', activeTab === tab.value ? 'border-[#284b44] text-[#284b44]' : 'border-transparent text-gray-500 hover:text-gray-700']"
          @click="activeTab = tab.value"
        >
          {{ tab.label }}
        </button>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reference</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Branch</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Business Date</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="row in filteredOrders" :key="row.id" class="hover:bg-gray-50">
              <td class="px-6 py-3 text-sm font-medium text-gray-900">{{ row.production_number || '—' }}</td>
              <td class="px-6 py-3 text-sm text-gray-700">{{ row.branch_name ?? row.branch_code ?? '—' }}</td>
              <td class="px-6 py-3">
                <span :class="['px-2 py-1 rounded text-xs font-medium', statusClass(row.status)]">{{ row.status }}</span>
              </td>
              <td class="px-6 py-3 text-sm text-gray-600">{{ formatDate(row.production_date) }}</td>
              <td class="px-6 py-3 text-sm text-gray-600">{{ formatDateTime(row.created_at) }}</td>
              <td class="px-6 py-3 text-right">
                <router-link :to="`/homeportal/production/${row.id}`" class="text-[#284b44] hover:text-[#1e3a36] font-medium">Open</router-link>
              </td>
            </tr>
            <tr v-if="!filteredOrders.length">
              <td colspan="6" class="px-6 py-12 text-center text-gray-500">No production orders. Click New Production to create one.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- New Production modal -->
    <div v-if="showNewModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showNewModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">New Production</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Branch *</label>
            <select v-model="newForm.branch_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg" required>
              <option value="">Select branch...</option>
              <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.branch_name }} ({{ b.branch_code }})</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Business date</label>
            <input v-model="newForm.production_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" @click="showNewModal = false" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Close</button>
          <button type="button" @click="createProduction" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { fetchProductionOrdersList, createProductionOrder, fetchBranches } from '@/services/productionService';

const router = useRouter();
const loading = ref(true);
const loadError = ref('');
const orders = ref([]);
const branches = ref([]);
const activeTab = ref('all');
const showNewModal = ref(false);
const newForm = ref({ branch_id: '', production_date: '' });

const tabs = [
  { value: 'all', label: 'All' },
  { value: 'draft', label: 'Draft' },
  { value: 'released', label: 'Released' },
  { value: 'closed', label: 'Closed' }
];

const filteredOrders = computed(() => {
  if (activeTab.value === 'all') return orders.value;
  return orders.value.filter((o) => o.status === activeTab.value);
});

function statusClass(s) {
  if (s === 'closed') return 'bg-gray-200 text-gray-700';
  if (s === 'released') return 'bg-blue-100 text-blue-800';
  return 'bg-amber-100 text-amber-800';
}

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString();
}

function formatDateTime(d) {
  if (!d) return '—';
  return new Date(d).toLocaleString();
}

function openNewProduction() {
  newForm.value = { branch_id: '', production_date: new Date().toISOString().slice(0, 10) };
  showNewModal.value = true;
}

async function createProduction() {
  if (!newForm.value.branch_id) return;
  try {
    const order = await createProductionOrder({
      branch_id: newForm.value.branch_id,
      production_date: newForm.value.production_date || null
    });
    showNewModal.value = false;
    router.push(`/homeportal/production/${order.id}`);
  } catch (e) {
    alert(e?.message || 'Failed to create production order');
  }
}

onMounted(async () => {
  try {
    loadError.value = '';
    const [list, br] = await Promise.all([fetchProductionOrdersList(), fetchBranches()]);
    orders.value = Array.isArray(list) ? list : [];
    branches.value = Array.isArray(br) ? br : [];
  } catch (e) {
    orders.value = [];
    branches.value = [];
    loadError.value = (e?.message || String(e)).slice(0, 200);
  } finally {
    loading.value = false;
  }
});
</script>
