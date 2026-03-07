<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex justify-between items-center mb-6 sticky top-0 z-20 bg-[#f0e1cd] py-2 -mx-6 px-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-[#284b44] hover:text-[#1e3a36] flex items-center gap-2 font-medium">
          <i class="fas fa-arrow-left"></i>
          Back
        </button>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ order?.transfer_number || 'Transfer Order' }}</h1>
          <span v-if="order" :class="['px-3 py-1 rounded-full text-sm font-semibold', statusClass(order.status)]">
            {{ formatStatus(order.status) }}
          </span>
        </div>
      </div>
      <!-- STEP 2: Top right buttons by stage -->
      <div class="flex gap-2 flex-wrap">
        <!-- Draft -->
        <template v-if="order?.status === 'draft'">
          <button @click="deletePermanently" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
            Delete Permanently
          </button>
          <button
            @click="printOrder"
            :disabled="true"
            class="px-4 py-2 border border-gray-300 rounded-lg opacity-50 cursor-not-allowed"
            title="Print disabled until TO number generated"
          >
            <i class="fas fa-print"></i> Print
          </button>
          <button @click="showEditModal = true" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            Edit
          </button>
          <button
            @click="submitForReview"
            :disabled="submitting"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Submit for review
          </button>
        </template>
        <!-- Pending (submitted) -->
        <template v-else-if="order?.status === 'submitted'">
          <button @click="doDecline" :disabled="declining" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
            Decline
          </button>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doAccept"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Accept
          </button>
        </template>
        <!-- Approved + can dispatch -->
        <template v-else-if="canDispatch">
          <button @click="doDecline" :disabled="declining" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
            Decline
          </button>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="sendItems"
            :disabled="sending"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Send Items
          </button>
        </template>
        <!-- Approved but not yet fully (e.g. L1 only) — show Decline, Print, Accept for L2 -->
        <template v-else-if="isApprovedNotDispatchable">
          <button @click="doDecline" :disabled="declining" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
            Decline
          </button>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doAccept"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Accept
          </button>
        </template>
        <!-- Sent/Closed: Print only -->
        <template v-else>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
        </template>
      </div>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading...</p>
    </div>

    <div v-else-if="error" class="bg-white rounded-xl shadow-md p-6">
      <p class="text-red-600 mb-4">{{ error }}</p>
      <button @click="goBack" class="px-4 py-2 bg-gray-200 rounded-lg">← Go Back</button>
    </div>

    <template v-else-if="order">
      <!-- STEP 2: Top card layout like Foodics -->
      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
          <div>
            <label class="block text-sm text-gray-500 mb-1">Source</label>
            <p class="font-medium">{{ order.from_name || order.from_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Destination</label>
            <p class="font-medium">{{ order.to_name || order.to_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Business Date</label>
            <p class="font-medium">{{ order.business_date ? formatDate(order.business_date) : formatDate(today) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created at</label>
            <p class="font-medium">{{ formatDateTime(order.created_at) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created by</label>
            <p class="font-medium">{{ order.requested_by_name || order.requested_by || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Status</label>
            <p><span :class="['px-2 py-1 rounded text-sm font-medium', statusClass(order.status)]">{{ formatStatus(order.status) }}</span></p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Number of items</label>
            <p class="font-medium">{{ items.length }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total Qty</label>
            <p class="font-medium">{{ formatNum(totalRequested) }}</p>
          </div>
        </div>
      </div>

      <!-- Document Flow: TO → Transfer → Receiving -->
      <DocumentFlow
        v-if="order?.id"
        flow-type="transfer"
        doc-type="to"
        :doc-id="order.id"
        :current-number="order.transfer_number || order.to_number"
      />

      <!-- STEP 7: Warning banner (informational only — submit allowed; dispatch blocked until stock available) -->
      <div
        v-if="order.status === 'draft' && hasStockWarning"
        class="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6 flex items-center gap-3"
      >
        <i class="fas fa-exclamation-triangle text-amber-600"></i>
        <div>
          <p class="text-amber-800 font-medium">Transferred quantity exceeds available quantity</p>
          <p class="text-amber-700 text-sm mt-1">TO is a demand document. You can submit for approval. Dispatch will be blocked until stock is available.</p>
        </div>
      </div>

      <!-- STEP 3: Items section -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-bold text-gray-800">Items</h2>
          <div v-if="order.status === 'draft'" class="flex gap-2 flex-wrap">
            <label class="flex items-center gap-2 px-3 py-2 border rounded-lg text-sm cursor-pointer hover:bg-gray-50">
              <input v-model="storageUnitToggle" type="checkbox" class="rounded" />
              <span>Storage Unit</span>
            </label>
            <button
              @click="showEditQuantities = !showEditQuantities"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Edit Quantities
            </button>
            <button
              @click="showImportModal = true"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-file-excel"></i>
              Import Items
            </button>
            <button
              @click="showAddModal = true"
              class="px-6 py-2 rounded-lg text-white flex items-center gap-2"
              style="background-color: #284b44;"
            >
              <i class="fas fa-plus"></i>
              Add Items
            </button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50 sticky top-0">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Item Name</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">SKU</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Quantity</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Available Quantity</th>
                <th v-if="order.status === 'draft'" class="px-4 py-3 text-right text-xs font-medium text-gray-500 w-12"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr
                v-for="it in enrichedItems"
                :key="it.id"
                class="hover:bg-gray-50 cursor-pointer"
                @click="order.status === 'draft' ? openEditItem(it) : null"
              >
                <td class="px-4 py-3 text-sm text-gray-900">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.requested_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.available_qty) }}</td>
                <td v-if="order.status === 'draft'" class="px-4 py-3 text-right">
                  <button
                    @click.stop="removeItem(it)"
                    class="text-red-600 hover:text-red-800"
                    title="Remove"
                  >
                    <i class="fas fa-trash"></i>
                  </button>
                </td>
              </tr>
              <tr v-if="!items.length">
                <td :colspan="order.status === 'draft' ? 5 : 4" class="px-4 py-8 text-center text-gray-500">No data to display!</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Edit Transfer Order modal -->
    <div v-if="showEditModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showEditModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Edit Transfer Order</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Source Location *</label>
            <select v-model="editForm.from_location_id" class="w-full px-3 py-2 border rounded-lg" @change="onEditSourceChange">
              <option value="">Choose...</option>
              <option v-for="loc in sourceLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }} ({{ loc.location_code }})</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Destination *</label>
            <select v-model="editForm.to_location_id" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Choose...</option>
              <option v-for="loc in filteredDestLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }} ({{ loc.location_code }})</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
            <textarea v-model="editForm.remarks" rows="2" class="w-full px-3 py-2 border rounded-lg"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showEditModal = false" class="px-4 py-2 border rounded-lg">Close</button>
          <button @click="saveEdit" :disabled="editSaving" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
        </div>
      </div>
    </div>

    <AddItemModal
      v-if="showAddModal"
      :from-location-id="order?.from_location_id"
      @close="showAddModal = false"
      @save="onAddItem"
    />
    <EditItemModal
      v-if="showEditItemModal"
      :item="editItem"
      @close="showEditItemModal = false"
      @save="onSaveEditItem"
      @delete="onDeleteEditItem"
    />
    <ImportItemsModal
      v-if="showImportModal"
      :from-location-id="order?.from_location_id"
      @close="showImportModal = false"
      @import="onImportItems"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getTransferOrderById,
  fetchTransferItemsFlow,
  fetchStockMapForItems,
  fetchTransferDispatches,
  fetchTransferReceipts,
  fetchTransferApprovals,
  getNextTransferApprovalStep,
  canDispatchTransfer,
  submitTransfer,
  approveTransferLevel,
  rejectTransfer,
  createTransferFromTo,
  deleteTransferDraft,
  updateTransferDraft,
  addItemsToTransferOrder,
  updateTransferItemQty,
  removeTransferItem,
  importTransferItemsFromRows
} from '@/services/transferEngine.js';
import { getUsers } from '@/services/supabase.js';
import { getCurrentUserUUID } from '@/utils/uuidUtils';
import { showNotification } from '@/utils/notifications';
import { forceInventoryViewsRefresh } from '@/services/erpViews.js';
import { loadTransferSourceLocations, loadTransferDestLocations } from '@/composables/useInventoryLocations.js';
import { printTransferOrder } from '@/services/pdfPrintService.js';
import AddItemModal from '@/components/transfer/AddItemModal.vue';
import EditItemModal from '@/components/transfer/EditItemModal.vue';
import ImportItemsModal from '@/components/transfer/ImportItemsModal.vue';
import DocumentFlow from '@/components/common/DocumentFlow.vue';

const route = useRoute();
const router = useRouter();
const order = ref(null);
const items = ref([]);
const stockMap = ref({});
const loading = ref(true);
const error = ref(null);
const submitting = ref(false);
const approving = ref(false);
const declining = ref(false);
const sending = ref(false);
const editSaving = ref(false);
const showEditModal = ref(false);
const showAddModal = ref(false);
const showEditItemModal = ref(false);
const showImportModal = ref(false);
const showEditQuantities = ref(false);
const storageUnitToggle = ref(false);
const editForm = ref({ from_location_id: '', to_location_id: '', remarks: '' });
const sourceLocations = ref([]);
const destLocations = ref([]);
const editItem = ref(null);
const canDispatch = ref(false);


const today = new Date().toISOString().slice(0, 10);
const totalRequested = computed(() => items.value.reduce((s, it) => s + (Number(it.requested_qty) || 0), 0));
const isApprovedNotDispatchable = computed(() => {
  const s = (order.value?.status || '').toLowerCase();
  return ['level1_approved', 'level2_approved'].includes(s) && !canDispatch.value;
});
const enrichedItems = computed(() => {
  return items.value.map((it) => {
    const stock = stockMap.value[it.item_id] || {};
    const avail = stock.available_qty ?? 0;
    const avgCost = stock.avg_cost ?? 0;
    const req = Number(it.requested_qty) || 0;
    return {
      ...it,
      available_qty: avail,
      avg_cost: avgCost,
      total_cost: req * avgCost,
      exceedsStock: req > avail && avail >= 0
    };
  });
});
const hasStockWarning = computed(() => enrichedItems.value.some((it) => it.exceedsStock));

const filteredDestLocations = computed(() => {
  const src = editForm.value.from_location_id;
  if (!src) return destLocations.value;
  return destLocations.value.filter((loc) => loc.id !== src);
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function formatDate(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString('en-GB'); } catch { return d; }
}
function formatDateTime(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-GB'); } catch { return d; }
}
function formatStatus(s) {
  const m = {
    draft: 'Draft',
    submitted: 'Pending',
    level1_approved: 'L1 Approved',
    level2_approved: 'L2 Approved',
    rejected: 'Declined',
    dispatched: 'Sent',
    partially_dispatched: 'Partially Sent',
    partially_received: 'Partially Received',
    completed: 'Completed',
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
    rejected: 'bg-red-100 text-red-800',
    dispatched: 'bg-green-100 text-green-800',
    partially_dispatched: 'bg-green-100 text-green-800',
    partially_received: 'bg-blue-100 text-blue-800',
    completed: 'bg-green-100 text-green-800',
    closed: 'bg-gray-100 text-gray-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}
function getCurrentUserName() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (u) { const d = JSON.parse(u); return d.name || d.email?.split('@')[0] || 'user'; }
  } catch (_) {}
  return 'user';
}

async function load() {
  const id = route.params.id;
  if (!id) { error.value = 'No transfer ID'; loading.value = false; return; }
  loading.value = true;
  error.value = null;
  try {
    order.value = await getTransferOrderById(id);
    items.value = await fetchTransferItemsFlow(id);
    const itemIds = items.value.map((it) => it.item_id).filter(Boolean);
    if (itemIds.length && order.value?.from_location_id) {
      stockMap.value = await fetchStockMapForItems(order.value.from_location_id, itemIds);
    } else {
      stockMap.value = {};
    }
    if (order.value?.status === 'draft') {
      sourceLocations.value = await loadTransferSourceLocations();
      destLocations.value = await loadTransferDestLocations();
      editForm.value = { from_location_id: order.value.from_location_id, to_location_id: order.value.to_location_id, remarks: order.value.remarks || '' };
    }
    canDispatch.value = await canDispatchTransfer(id);
  } catch (e) {
    console.warn(e);
    error.value = e?.message || 'Failed to load';
  } finally {
    loading.value = false;
  }
}

function onEditSourceChange() {
  if (editForm.value.to_location_id === editForm.value.from_location_id) editForm.value.to_location_id = '';
}

function goBack() {
  router.push('/homeportal/transfer-orders');
}

async function saveEdit() {
  if (!order.value?.id || order.value.status !== 'draft') return;
  if (!editForm.value.from_location_id || !editForm.value.to_location_id) {
    showNotification('Source and destination required', 'warning');
    return;
  }
  if (editForm.value.from_location_id === editForm.value.to_location_id) {
    showNotification('Source and destination must be different', 'warning');
    return;
  }
  editSaving.value = true;
  try {
    const r = await updateTransferDraft(order.value.id, {
      from_location_id: editForm.value.from_location_id,
      to_location_id: editForm.value.to_location_id,
      remarks: editForm.value.remarks
    });
    if (r.success) {
      showNotification('Saved', 'success');
      showEditModal.value = false;
      await load();
    } else {
      showNotification(r.error || 'Save failed', 'error');
    }
  } finally {
    editSaving.value = false;
  }
}

async function submitForReview() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Submit for Review', message: 'Are you sure you want to submit this?', confirmText: 'Confirm', cancelText: 'Cancel', type: 'info' });
  if (!ok) return;
  submitting.value = true;
  try {
    const result = await submitTransfer(order.value.id);
    if (result.ok) {
      showNotification('Submitted. TO number generated.', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Submit failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    submitting.value = false;
  }
}

async function doAccept() {
  approving.value = true;
  try {
    const nextStep = await getNextTransferApprovalStep(order.value.id);
    const step = nextStep?.next_level ?? 1;
    const result = await approveTransferLevel(order.value.id, step, getCurrentUserUUID());
    if (result.ok) {
      showNotification('Transfer approved', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Approval failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    approving.value = false;
  }
}

async function doDecline() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Decline', message: 'Are you sure you want to decline this transfer?', type: 'danger' });
  if (!ok) return;
  declining.value = true;
  try {
    const result = await rejectTransfer(order.value.id, getCurrentUserUUID());
    if (result.ok) {
      showNotification('Transfer declined', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Decline failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    declining.value = false;
  }
}

async function sendItems() {
  sending.value = true;
  try {
    const result = await createTransferFromTo(order.value.id);
    if (result.ok && result.transfer_id) {
      showNotification('Transfer created: ' + (result.transfer_number || ''), 'success');
      await forceInventoryViewsRefresh();
      router.push(`/homeportal/transfer-sending/${result.transfer_id}`);
    } else {
      showNotification(result.error || 'Create transfer failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    sending.value = false;
  }
}

async function deletePermanently() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Delete Permanently', message: 'Delete transfer order permanently?', confirmText: 'Yes', type: 'danger' });
  if (!ok) return;
  try {
    const result = await deleteTransferDraft(order.value.id);
    if (result.success) {
      showNotification('Transfer deleted', 'success');
      goBack();
    } else {
      showNotification(result.error || 'Delete failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  }
}

function printOrder() {
  if (!order.value?.transfer_number) {
    showNotification('Print available after TO number is generated', 'warning');
    return;
  }
  printTransferOrder(order.value, enrichedItems.value);
}

function openEditItem(it) {
  editItem.value = it;
  showEditItemModal.value = true;
}

async function onSaveEditItem(qty) {
  const r = await updateTransferItemQty(order.value.id, editItem.value.item_id, qty);
  if (r.success) {
    showNotification('Quantity updated', 'success');
    await load();
  } else {
    showNotification(r.error || 'Update failed', 'error');
  }
}

async function onDeleteEditItem() {
  const r = await removeTransferItem(order.value.id, editItem.value.item_id);
  if (r.success) {
    showNotification('Item removed', 'success');
    await load();
  } else {
    showNotification(r.error || 'Remove failed', 'error');
  }
}

async function onAddItem(payload) {
  const r = await addItemsToTransferOrder(order.value.id, [payload]);
  if (r.success) {
    showNotification('Item added', 'success');
    await load();
  } else {
    showNotification(r.error || 'Add failed', 'error');
  }
}

async function onImportItems(rows) {
  const result = await importTransferItemsFromRows(order.value.id, order.value.from_location_id, rows);
  if (result.success) {
    showNotification(`Imported ${result.added.length} items`, 'success');
    await load();
  } else {
    showNotification(result.errors?.[0] || 'Import failed', 'error');
  }
}

async function removeItem(it) {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Remove Item', message: `Remove ${it.item_name} from transfer?`, type: 'warning' });
  if (!ok) return;
  const r = await removeTransferItem(order.value.id, it.item_id);
  if (r.success) {
    showNotification('Item removed', 'success');
    await load();
  } else {
    showNotification(r.error || 'Remove failed', 'error');
  }
}

watch(() => route.params.id, () => load(), { immediate: false });

onMounted(() => load());
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
