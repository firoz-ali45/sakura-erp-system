<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6 sticky top-0 z-10">
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.transferOrders.title') }}</h1>
        <div class="flex gap-3">
          <button
            @click="exportExcel"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-file-excel"></i>
            Export Excel
          </button>
          <button
            @click="openCreate"
            class="px-6 py-2 rounded-lg text-white flex items-center gap-2"
            style="background-color: #284b44;"
          >
            <i class="fas fa-plus"></i>
            Create Transfer Order
          </button>
        </div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="bg-white rounded-xl shadow-md mb-4 overflow-x-auto">
      <div class="flex border-b border-gray-200 min-w-max">
        <button
          v-for="tab in tabs"
          :key="tab.value"
          @click="activeTab = tab.value"
          :class="[
            'px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors',
            activeTab === tab.value
              ? 'border-[#284b44] text-[#284b44]'
              : 'border-transparent text-gray-600 hover:text-gray-800'
          ]"
        >
          {{ tab.label }}
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl shadow-md p-4 mb-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Date From</label>
        <input v-model="filterDateFrom" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Date To</label>
        <input v-model="filterDateTo" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">From Warehouse</label>
        <select v-model="filterFrom" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
          <option value="">All</option>
          <option v-for="loc in allLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">To Warehouse</label>
        <select v-model="filterTo" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
          <option value="">All</option>
          <option v-for="loc in allLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
        <input
          v-model="filterSearch"
          type="text"
          placeholder="Reference, Created by..."
          class="w-full px-3 py-2 border border-gray-300 rounded-lg"
        />
      </div>
      <div class="flex items-end">
        <button
          @click="load"
          class="px-4 py-2 rounded-lg text-white"
          style="background-color: #284b44;"
        >
          <i class="fas fa-search mr-1"></i> Search
        </button>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50 sticky top-0">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reference</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">From Location</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">To Location</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Total Items</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created By</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created At</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Last Action</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-if="loading" v-for="n in 5" :key="'sk-' + n" class="animate-pulse">
              <td colspan="9" class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded w-3/4"></div>
              </td>
            </tr>
            <tr v-else-if="filteredRows.length === 0">
              <td colspan="9" class="px-6 py-12 text-center text-gray-500">
                No transfer orders found
              </td>
            </tr>
            <tr
              v-else
              v-for="row in filteredRows"
              :key="row.id"
              class="hover:bg-gray-50 cursor-pointer"
              @click="openTransfer(row)"
            >
              <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.transfer_number || 'Draft' }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ row.from_name || row.from_code || '—' }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ row.to_name || row.to_code || '—' }}</td>
              <td class="px-6 py-4">
                <span :class="['px-2 py-1 rounded-full text-xs font-semibold', statusClass(row.status)]">
                  {{ formatStatus(row.status) }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-right">{{ formatNum(row.requested_total) }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ row.requested_by_name || row.requested_by || '—' }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ formatDateTime(row.created_at) }}</td>
              <td class="px-6 py-4 text-sm text-gray-600">{{ lastAction(row) }}</td>
              <td class="px-6 py-4" @click.stop>
                <button
                  @click="openTransfer(row)"
                  class="text-[#284b44] hover:underline text-sm font-medium"
                >
                  Open
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- STEP 1: Minimal Create Popup — Source, Destination only -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="closeCreate">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md p-6">
        <h2 class="text-xl font-bold mb-4">Create Transfer Order</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Source Location <span class="text-red-500">*</span></label>
            <select v-model="form.from_location_id" required @change="onSourceChange" class="w-full px-4 py-2 border rounded-lg">
              <option value="">Choose...</option>
              <option v-for="loc in sourceLocations" :key="loc.id" :value="loc.id">
                {{ loc.location_name }} ({{ loc.location_code }})
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Destination <span class="text-red-500">*</span></label>
            <select v-model="form.to_location_id" required class="w-full px-4 py-2 border rounded-lg">
              <option value="">Choose...</option>
              <option v-for="loc in filteredDestLocations" :key="loc.id" :value="loc.id">
                {{ loc.location_name }} ({{ loc.location_code }})
              </option>
            </select>
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-6 pt-4 border-t">
          <button @click="closeCreate" class="px-6 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
          <button
            @click="saveDraft"
            :disabled="saving"
            class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
            style="background-color: #284b44;"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { getCurrentUserUUID } from '@/utils/uuidUtils';
import { fetchTransferOrdersFull, createTransferDraft } from '@/services/transferEngine.js';
import { loadTransferSourceLocations, loadTransferDestLocations, loadInventoryLocations } from '@/composables/useInventoryLocations.js';
import { showNotification } from '@/utils/notifications';
import { useReportExport } from '@/composables/useReportExport.js';
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

const router = useRouter();
const loading = ref(false);
const rows = ref([]);
const activeTab = ref('all');
const filterDateFrom = ref('');
const filterDateTo = ref('');
const filterFrom = ref('');
const filterTo = ref('');
const filterSearch = ref('');
const allLocations = ref([]);
const sourceLocations = ref([]);
const destLocations = ref([]);
const showCreateModal = ref(false);
const saving = ref(false);

const tabs = [
  { value: 'all', label: 'All' },
  { value: 'draft', label: 'Draft' },
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'declined', label: 'Declined' },
  { value: 'sent', label: 'Sent' },
  { value: 'closed', label: 'Closed' }
];

const form = ref({
  from_location_id: '',
  to_location_id: ''
});

const filteredDestLocations = computed(() => {
  const src = form.value.from_location_id;
  if (!src) return destLocations.value;
  return destLocations.value.filter((loc) => loc.id !== src);
});

const filteredRows = computed(() => {
  let list = rows.value;

  if (activeTab.value !== 'all') {
    const s = activeTab.value;
    if (s === 'approved') {
      list = list.filter((r) => ['level1_approved', 'level2_approved'].includes((r.status || '').toLowerCase()));
    } else if (s === 'pending') {
      list = list.filter((r) => (r.status || '').toLowerCase() === 'submitted');
    } else if (s === 'declined') {
      list = list.filter((r) => (r.status || '').toLowerCase() === 'rejected');
    } else if (s === 'sent') {
      list = list.filter((r) => ['dispatched', 'partially_dispatched'].includes((r.status || '').toLowerCase()));
    } else {
      list = list.filter((r) => (r.status || '').toLowerCase() === s);
    }
  }

  if (filterDateFrom.value) {
    list = list.filter((r) => r.created_at && r.created_at >= filterDateFrom.value);
  }
  if (filterDateTo.value) {
    list = list.filter((r) => r.created_at && r.created_at.slice(0, 10) <= filterDateTo.value);
  }
  if (filterFrom.value) list = list.filter((r) => r.from_location_id === filterFrom.value);
  if (filterTo.value) list = list.filter((r) => r.to_location_id === filterTo.value);
  if (filterSearch.value) {
    const q = filterSearch.value.toLowerCase().trim();
    list = list.filter(
      (r) =>
        (r.transfer_number || '').toLowerCase().includes(q) ||
        (r.requested_by_name || '').toLowerCase().includes(q) ||
        (r.requested_by || '').toLowerCase().includes(q)
    );
  }
  return list;
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

function formatDate(d) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleDateString('en-GB');
  } catch {
    return d;
  }
}

function formatDateTime(d) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return d;
  }
}

function formatStatus(s) {
  const m = {
    draft: 'Draft',
    submitted: 'Pending',
    level1_approved: 'Approved',
    level2_approved: 'Approved',
    dispatched: 'Sent',
    partially_dispatched: 'Sent',
    rejected: 'Declined',
    closed: 'Closed'
  };
  return m[(s || '').toLowerCase()] || s;
}

function statusClass(s) {
  const m = {
    draft: 'bg-gray-100 text-gray-800',
    submitted: 'bg-amber-100 text-amber-800',
    level1_approved: 'bg-blue-100 text-blue-800',
    level2_approved: 'bg-blue-100 text-blue-800',
    dispatched: 'bg-green-100 text-green-800',
    partially_dispatched: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    closed: 'bg-gray-100 text-gray-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}

function lastAction(row) {
  if (row.rejected_by) return `Declined by ${row.rejected_by_name || row.rejected_by || '—'}`;
  if (row.approved_by_level2) return `Approved by ${row.approved_by_level2_name || row.approved_by_level2 || '—'}`;
  if (row.approved_by_level1) return `Approved by ${row.approved_by_level1_name || row.approved_by_level1 || '—'}`;
  if (row.requested_by) return `Submitted by ${row.requested_by_name || row.requested_by || '—'}`;
  return '—';
}

function onSourceChange() {
  if (form.value.to_location_id === form.value.from_location_id) {
    form.value.to_location_id = '';
  }
}

async function load() {
  loading.value = true;
  try {
    rows.value = await fetchTransferOrdersFull();
  } catch (e) {
    console.warn(e);
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  form.value = { from_location_id: '', to_location_id: '' };
  showCreateModal.value = true;
}

function closeCreate() {
  showCreateModal.value = false;
}

async function saveDraft() {
  if (!form.value.from_location_id || !form.value.to_location_id) {
    showNotification('Select Source and Destination locations', 'warning');
    return;
  }
  if (form.value.from_location_id === form.value.to_location_id) {
    showNotification('Source and Destination must be different', 'warning');
    return;
  }
  saving.value = true;
  try {
    const result = await createTransferDraft({
      from_location_id: form.value.from_location_id,
      to_location_id: form.value.to_location_id,
      requested_by: getCurrentUserUUID(),
      items: []
    });
    if (result.success && result.data) {
      showNotification('Transfer order created', 'success');
      closeCreate();
      router.push(`/homeportal/transfer-order-detail/${result.data.id}`);
    } else {
      showNotification(result.error || 'Save failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    saving.value = false;
  }
}

function getCurrentUserName() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (u) {
      const d = JSON.parse(u);
      return d.name || d.email?.split('@')[0] || 'user';
    }
  } catch (_) {}
  return 'user';
}

function openTransfer(row) {
  router.push(`/homeportal/transfer-order-detail/${row.id}`);
}

async function exportExcel() {
  const { exportToExcel } = useReportExport();
  const headers = {
    transfer_number: 'Reference',
    from_name: 'From Location',
    to_name: 'To Location',
    status: 'Status',
    requested_total: 'Total Items',
    requested_by_name: 'Created By',
    created_at: 'Created At'
  };
  exportToExcel(filteredRows.value, headers, 'Transfer_Orders');
}

onMounted(async () => {
  await load();
  allLocations.value = await loadInventoryLocations(true);
  sourceLocations.value = await loadTransferSourceLocations();
  destLocations.value = await loadTransferDestLocations();
});
</script>
