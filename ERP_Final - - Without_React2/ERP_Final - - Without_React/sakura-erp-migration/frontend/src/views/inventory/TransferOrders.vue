<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.transferOrders.title') }}</h1>
        <button
          @click="openCreate"
          class="px-6 py-2 rounded-lg text-white flex items-center gap-2"
          style="background-color: #284b44;"
        >
          <i class="fas fa-plus"></i>
          Create Transfer
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl shadow-md p-4 mb-6 grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
        <input
          v-model="filterDate"
          type="date"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg"
        />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
        <select v-model="filterStatus" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
          <option value="">All</option>
          <option value="draft">Draft</option>
          <option value="submitted">Submitted</option>
          <option value="level1_approved">Level 1 Approved</option>
          <option value="level2_approved">Level 2 Approved</option>
          <option value="dispatched">Dispatched</option>
          <option value="partially_received">Partially Received</option>
          <option value="closed">Closed</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
        <select v-model="filterLocation" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
          <option value="">All</option>
          <option v-for="loc in allLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }}</option>
        </select>
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
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Transfer #</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">From</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">To</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Requested</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Dispatched</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Received</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Variance</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-if="loading" v-for="n in 5" :key="'sk-' + n" class="animate-pulse">
              <td colspan="10" class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded w-3/4"></div>
              </td>
            </tr>
            <tr v-else-if="filteredRows.length === 0">
              <td colspan="10" class="px-6 py-12 text-center text-gray-500">
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
              <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ row.transfer_number }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ row.from_name || row.from_code || '—' }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ row.to_name || row.to_code || '—' }}</td>
              <td class="px-6 py-4">
                <span :class="['px-2 py-1 rounded-full text-xs font-semibold', statusClass(row.status)]">
                  {{ formatStatus(row.status) }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-right">{{ formatNum(row.requested_total) }}</td>
              <td class="px-6 py-4 text-sm text-right">{{ formatNum(row.dispatched_total) }}</td>
              <td class="px-6 py-4 text-sm text-right">{{ formatNum(row.received_total) }}</td>
              <td class="px-6 py-4 text-sm text-right" :class="row.variance_total > 0 ? 'text-amber-600' : ''">
                {{ formatNum(row.variance_total) }}
              </td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ formatDate(row.created_at) }}</td>
              <td class="px-6 py-4" @click.stop>
                <button
                  @click="openTransfer(row)"
                  class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                >
                  Open
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Create Transfer Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="closeCreate">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-2xl m-4 max-h-[90vh] overflow-y-auto">
        <div class="sticky top-0 bg-white border-b p-6 flex justify-between">
          <h2 class="text-xl font-bold">Create Transfer Order</h2>
          <button @click="closeCreate" class="text-gray-500 hover:text-gray-700"><i class="fas fa-times"></i></button>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-2 gap-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">From Location <span class="text-red-500">*</span></label>
              <select v-model="form.from_location_id" required class="w-full px-4 py-2 border rounded-lg">
                <option value="">Select...</option>
                <option v-for="loc in sourceLocations" :key="loc.id" :value="loc.id">
                  {{ loc.location_name }} ({{ loc.location_code }})
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">To Location <span class="text-red-500">*</span></label>
              <select v-model="form.to_location_id" required class="w-full px-4 py-2 border rounded-lg">
                <option value="">Select...</option>
                <option v-for="loc in destLocations" :key="loc.id" :value="loc.id">
                  {{ loc.location_name }} ({{ loc.location_code }})
                </option>
              </select>
            </div>
          </div>
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">Items <span class="text-red-500">*</span></label>
            <div class="flex gap-2 mb-2">
              <select v-model="newItem.item_id" class="flex-1 px-4 py-2 border rounded-lg">
                <option value="">Select item...</option>
                <option v-for="it in inventoryItems" :key="it.id" :value="it.id">
                  {{ it.name }} ({{ it.sku }})
                </option>
              </select>
              <input v-model.number="newItem.qty" type="number" min="0.01" step="0.01" placeholder="Qty" class="w-24 px-4 py-2 border rounded-lg" />
              <button
                @click="addItem"
                class="px-4 py-2 rounded-lg text-white"
                style="background-color: #284b44;"
              >
                Add
              </button>
            </div>
            <div class="border rounded-lg overflow-hidden">
              <table class="w-full">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500">Item</th>
                    <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Qty</th>
                    <th class="px-4 py-2 w-12"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(it, idx) in form.items" :key="idx" class="border-t">
                    <td class="px-4 py-2 text-sm">{{ getItemName(it.item_id) }}</td>
                    <td class="px-4 py-2 text-sm text-right">{{ it.requested_qty }}</td>
                    <td class="px-4 py-2">
                      <button @click="removeItem(idx)" class="text-red-600 hover:text-red-800"><i class="fas fa-trash"></i></button>
                    </td>
                  </tr>
                  <tr v-if="form.items.length === 0">
                    <td colspan="3" class="px-4 py-4 text-center text-gray-500 text-sm">No items added</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div class="flex justify-end gap-3 pt-4 border-t">
            <button @click="closeCreate" class="px-6 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
            <button
              @click="saveDraft"
              :disabled="saving"
              class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
              style="background-color: #284b44;"
            >
              {{ saving ? 'Saving...' : 'Save Draft' }}
            </button>
            <button
              @click="saveAndSubmit"
              :disabled="saving"
              class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
              style="background-color: #1e3a36;"
            >
              {{ saving ? 'Saving...' : 'Save & Submit' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { fetchTransferOrdersFull, createTransferDraft, submitTransfer } from '@/services/transferEngine.js';
import { loadTransferSourceLocations, loadTransferDestLocations, loadInventoryLocations } from '@/composables/useInventoryLocations.js';
import { showNotification } from '@/utils/notifications';
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

const router = useRouter();
const loading = ref(false);
const rows = ref([]);
const filterDate = ref('');
const filterStatus = ref('');
const filterLocation = ref('');
const allLocations = ref([]);
const sourceLocations = ref([]);
const destLocations = ref([]);
const inventoryItems = ref([]);
const showCreateModal = ref(false);
const saving = ref(false);

const form = ref({
  from_location_id: '',
  to_location_id: '',
  items: []
});

const newItem = ref({ item_id: '', qty: 1 });

const filteredRows = computed(() => {
  let list = rows.value;
  if (filterDate.value) {
    const d = filterDate.value;
    list = list.filter(r => r.created_at && r.created_at.startsWith(d));
  }
  if (filterStatus.value) list = list.filter(r => (r.status || '').toLowerCase() === filterStatus.value.toLowerCase());
  if (filterLocation.value) {
    list = list.filter(r => r.from_location_id === filterLocation.value || r.to_location_id === filterLocation.value);
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

function formatStatus(s) {
  const m = {
    draft: 'Draft',
    submitted: 'Submitted',
    level1_approved: 'L1 Approved',
    level2_approved: 'L2 Approved',
    dispatched: 'Dispatched',
    partially_dispatched: 'Partially Dispatched',
    partially_received: 'Partially Received',
    completed: 'Completed',
    closed: 'Closed',
    rejected: 'Rejected'
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
    partially_received: 'bg-purple-100 text-purple-800',
    closed: 'bg-gray-100 text-gray-800',
    rejected: 'bg-red-100 text-red-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}

function getItemName(id) {
  const it = inventoryItems.value.find(i => i.id === id);
  return it ? `${it.name} (${it.sku})` : id || '—';
}

function addItem() {
  if (!newItem.value.item_id || !newItem.value.qty || newItem.value.qty <= 0) {
    showNotification('Select item and enter quantity', 'warning');
    return;
  }
  const existing = form.value.items.find(i => i.item_id === newItem.value.item_id);
  if (existing) {
    existing.requested_qty = (existing.requested_qty || 0) + Number(newItem.value.qty);
  } else {
    form.value.items.push({ item_id: newItem.value.item_id, requested_qty: Number(newItem.value.qty) });
  }
  newItem.value = { item_id: '', qty: 1 };
}

function removeItem(idx) {
  form.value.items.splice(idx, 1);
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
  form.value = { from_location_id: '', to_location_id: '', items: [] };
  newItem.value = { item_id: '', qty: 1 };
  showCreateModal.value = true;
}

function closeCreate() {
  showCreateModal.value = false;
}

async function saveDraft() {
  if (!form.value.from_location_id || !form.value.to_location_id) {
    showNotification('Select From and To locations', 'warning');
    return;
  }
  if (form.value.items.length === 0) {
    showNotification('Add at least one item', 'warning');
    return;
  }
  const userName = getCurrentUserName();
  saving.value = true;
  try {
    const result = await createTransferDraft({
      from_location_id: form.value.from_location_id,
      to_location_id: form.value.to_location_id,
      requested_by: userName,
      items: form.value.items
    });
    if (result.success && result.data) {
      showNotification('Transfer order saved as draft', 'success');
      closeCreate();
      await load();
      router.push(`/homeportal/transfer-order-detail/${result.data.id}`);
    } else {
      showNotification(result.error || 'Failed to save', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    saving.value = false;
  }
}

async function saveAndSubmit() {
  if (!form.value.from_location_id || !form.value.to_location_id) {
    showNotification('Select From and To locations', 'warning');
    return;
  }
  if (form.value.items.length === 0) {
    showNotification('Add at least one item', 'warning');
    return;
  }
  const userName = getCurrentUserName();
  saving.value = true;
  try {
    const result = await createTransferDraft({
      from_location_id: form.value.from_location_id,
      to_location_id: form.value.to_location_id,
      requested_by: userName,
      items: form.value.items
    });
    if (!result.success || !result.data) {
      showNotification(result.error || 'Failed to save', 'error');
      return;
    }
    const subResult = await submitTransfer(result.data.id);
    if (subResult.ok) {
      showNotification('Transfer order created and submitted', 'success');
      closeCreate();
      await load();
      router.push(`/homeportal/transfer-order-detail/${result.data.id}`);
    } else {
      showNotification(subResult.error || 'Submit failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    saving.value = false;
  }
}

function openTransfer(row) {
  router.push(`/homeportal/transfer-order-detail/${row.id}`);
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

onMounted(async () => {
  sourceLocations.value = await loadTransferSourceLocations();
  destLocations.value = await loadTransferDestLocations();
  allLocations.value = await loadInventoryLocations(true);
  const ready = await ensureSupabaseReady();
  if (ready && supabaseClient) {
    const { data } = await supabaseClient.from('inventory_items').select('id, name, sku').or('deleted.eq.false,deleted.is.null').order('name');
    inventoryItems.value = data || [];
  }
  load();
});
</script>
