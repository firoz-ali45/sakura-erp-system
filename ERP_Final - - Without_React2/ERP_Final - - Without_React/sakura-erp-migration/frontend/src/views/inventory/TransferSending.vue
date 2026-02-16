<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex justify-between items-center mb-6 sticky top-0 z-20 bg-[#f0e1cd] py-2 -mx-6 px-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-[#284b44] hover:text-[#1e3a36] flex items-center gap-2 font-medium">
          <i class="fas fa-arrow-left"></i>
          Back
        </button>
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ transfer?.transfer_number || 'Transfer' }}</h1>
          <span v-if="transfer?.to_number" class="text-sm text-gray-600">Linked TO: {{ transfer.to_number }}</span>
          <span v-if="transfer" :class="['px-3 py-1 rounded-full text-sm font-semibold', statusClass(transfer.status)]">
            {{ formatStatus(transfer.status) }}
          </span>
        </div>
      </div>
      <div class="flex gap-2 flex-wrap">
        <!-- Draft: Delete, Print, Start Picking -->
        <template v-if="transfer?.status === 'draft'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doStartPicking"
            :disabled="picking"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Start Picking
          </button>
        </template>
        <!-- Picked: Print, Dispatch to Logistics -->
        <template v-else-if="transfer?.status === 'picked'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doDispatch"
            :disabled="dispatching || hasInsufficientStock"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Dispatch to Logistics
          </button>
        </template>
        <!-- In Transit / Partially Received: Print, Receive Items -->
        <template v-else-if="['in_transit', 'partially_received'].includes(transfer?.status)">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="openReceiveModal"
            :disabled="receiving"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Receive Items
          </button>
        </template>
        <!-- Completed: Print only -->
        <template v-else>
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
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

    <template v-else-if="transfer">
      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-6">
          <div>
            <label class="block text-sm text-gray-500 mb-1">Transfer No</label>
            <p class="font-medium">{{ transfer.transfer_number || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Linked TO</label>
            <p class="font-medium">{{ transfer.to_number || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Source Warehouse</label>
            <p class="font-medium">{{ transfer.from_name || transfer.from_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Destination Warehouse</label>
            <p class="font-medium">{{ transfer.to_name || transfer.to_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Status</label>
            <p><span :class="['px-2 py-1 rounded text-sm font-medium', statusClass(transfer.status)]">{{ formatStatus(transfer.status) }}</span></p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created by</label>
            <p class="font-medium">{{ transfer.created_by || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created date</label>
            <p class="font-medium">{{ formatDateTime(transfer.created_at) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total items</label>
            <p class="font-medium">{{ items.length }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total qty</label>
            <p class="font-medium">{{ formatNum(transfer.total_qty) }}</p>
          </div>
        </div>
      </div>

      <div v-if="hasInsufficientStock && transfer?.status === 'picked'" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 text-red-800">
        <i class="fas fa-exclamation-triangle mr-2"></i>
        Insufficient stock in source warehouse. Cannot dispatch.
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">Timeline</h3>
        <div class="space-y-3">
          <div v-for="a in audit" :key="a.id" class="flex items-center gap-3">
            <span :class="['w-2 h-2 rounded-full', auditDotClass(a.action)]"></span>
            <span class="text-sm text-gray-600">{{ formatAuditAction(a.action) }} by {{ a.performed_by }} — {{ formatDateTime(a.performed_at) }}</span>
          </div>
          <div v-if="!audit.length" class="text-sm text-gray-500">No timeline entries yet.</div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md overflow-hidden">
        <div class="p-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-800">Items</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Item</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">SKU</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Batch</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Expiry</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Transfer Qty</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Picked Qty</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Received Qty</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Damaged</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Variance</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="it in items" :key="it.id" :class="(it.variance_qty || 0) > 0 ? 'bg-red-50' : ''">
                <td class="px-4 py-3 text-sm text-gray-900">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm text-gray-600">{{ it.batch_no || it.lot_no || '—' }}</td>
                <td class="px-4 py-3 text-sm" :class="isExpired(it) ? 'text-red-600 font-semibold' : ''">{{ formatDate(it.batch_expiry || it.expiry_date) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.transfer_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.picked_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.received_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right text-amber-600">{{ formatNum(it.damaged_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right" :class="(it.variance_qty || 0) > 0 ? 'text-red-600 font-semibold' : ''">{{ formatNum(it.variance_qty) }}</td>
              </tr>
              <tr v-if="!items.length">
                <td colspan="9" class="px-4 py-8 text-center text-gray-500">No items</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Receive Modal -->
    <div v-if="showReceiveModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showReceiveModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <h3 class="text-lg font-bold mb-4">Receive Items</h3>
        <div class="overflow-x-auto flex-1 overflow-y-auto">
          <table class="w-full">
            <thead class="bg-gray-50 sticky top-0">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Item</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Picked</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Receive</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Damaged</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Rejected</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="it in receiveRows" :key="it.id">
                <td class="px-4 py-2 text-sm text-gray-900">{{ it.item_name }} ({{ it.sku }})</td>
                <td class="px-4 py-2 text-sm text-right">{{ formatNum(it.picked_qty || it.transfer_qty) }}</td>
                <td class="px-4 py-2">
                  <input v-model.number="it.receive_qty" type="number" min="0" :max="it.picked_qty || it.transfer_qty" step="0.01" class="w-24 px-2 py-1 border rounded text-right" />
                </td>
                <td class="px-4 py-2">
                  <input v-model.number="it.damage_qty" type="number" min="0" step="0.01" class="w-20 px-2 py-1 border rounded text-right" />
                </td>
                <td class="px-4 py-2">
                  <input v-model.number="it.reject_qty" type="number" min="0" step="0.01" class="w-20 px-2 py-1 border rounded text-right" />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="flex justify-end gap-2 mt-6 pt-4 border-t">
          <button @click="showReceiveModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button
            @click="confirmReceive"
            :disabled="receiving || !canConfirmReceive"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Confirm Receive
          </button>
        </div>
      </div>
    </div>

    <!-- Start Picking / Dispatch confirm modals -->
    <div v-if="showPickingConfirm" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showPickingConfirm = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Confirm Picking</h3>
        <p class="text-gray-600 mb-6">Confirm that items have been picked? Status will change to Picked. No stock movement yet.</p>
        <div class="flex justify-end gap-2">
          <button @click="showPickingConfirm = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button @click="confirmPicking" :disabled="picking" class="px-6 py-2 rounded-lg text-white font-semibold" style="background-color: #284b44;">Confirm</button>
        </div>
      </div>
    </div>

    <div v-if="showDispatchConfirm" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showDispatchConfirm = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Dispatch to Logistics</h3>
        <p class="text-gray-600 mb-6">Stock will be deducted from source warehouse. Transfer status: In Transit.</p>
        <div class="flex justify-end gap-2">
          <button @click="showDispatchConfirm = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button @click="confirmDispatch" :disabled="dispatching" class="px-6 py-2 rounded-lg text-white font-semibold" style="background-color: #284b44;">Confirm</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getStockTransferById,
  fetchStockTransferItems,
  fetchStockMapForItems,
  confirmPickingStockTransfer,
  dispatchStockTransfer,
  receiveStockTransferItem,
  fetchStockTransferAudit
} from '@/services/transferEngine.js';
import { showNotification } from '@/utils/notifications';
import { printStockTransfer } from '@/services/pdfPrintService.js';

const route = useRoute();
const router = useRouter();
const transfer = ref(null);
const items = ref([]);
const stockMap = ref({});
const audit = ref([]);
const loading = ref(true);
const error = ref(null);
const picking = ref(false);
const dispatching = ref(false);
const receiving = ref(false);
const showReceiveModal = ref(false);
const showPickingConfirm = ref(false);
const showDispatchConfirm = ref(false);

const transferId = computed(() => route.params.id);

const hasInsufficientStock = computed(() => {
  if (transfer.value?.status !== 'picked') return false;
  const qty = (it) => Number(it.picked_qty || it.transfer_qty) || 0;
  return items.value.some((it) => {
    const avail = stockMap.value[it.item_id]?.available_qty ?? 0;
    return qty(it) > avail;
  });
});

const receiveRows = computed(() =>
  items.value
    .filter((it) => (Number(it.picked_qty || it.transfer_qty) || 0) > 0)
    .map((it) => ({
      ...it,
      receive_qty: Number(it.received_qty) || Number(it.picked_qty || it.transfer_qty) || 0,
      damage_qty: Number(it.damaged_qty) || 0,
      reject_qty: Number(it.rejected_qty) || 0
    }))
);

const canConfirmReceive = computed(() =>
  receiveRows.value.some((it) => (it.receive_qty || 0) > 0)
);

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
function formatAuditAction(a) {
  const m = { created: 'Created', picked: 'Picked', dispatched: 'Dispatched', received: 'Received', completed: 'Completed' };
  return m[(a || '').toLowerCase()] || a;
}
function auditDotClass(a) {
  const m = { created: 'bg-gray-400', picked: 'bg-amber-500', dispatched: 'bg-blue-500', received: 'bg-green-500', completed: 'bg-green-600' };
  return m[(a || '').toLowerCase()] || 'bg-gray-400';
}
function isExpired(it) {
  const d = it.batch_expiry || it.expiry_date;
  if (!d) return false;
  return new Date(d) < new Date();
}

function getCurrentUserName() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (u) { const d = JSON.parse(u); return d.name || d.email?.split('@')[0] || 'user'; }
  } catch (_) {}
  return 'user';
}

async function load() {
  const id = transferId.value;
  if (!id) { error.value = 'No transfer ID'; loading.value = false; return; }
  loading.value = true;
  error.value = null;
  try {
    transfer.value = await getStockTransferById(id);
    if (!transfer.value) { error.value = 'Transfer not found'; loading.value = false; return; }
    items.value = await fetchStockTransferItems(id);
    audit.value = await fetchStockTransferAudit(id);
    const itemIds = items.value.map((it) => it.item_id).filter(Boolean);
    if (itemIds.length && transfer.value?.from_location_id) {
      stockMap.value = await fetchStockMapForItems(transfer.value.from_location_id, itemIds);
    } else {
      stockMap.value = {};
    }
  } catch (e) {
    console.warn(e);
    error.value = e?.message || 'Failed to load';
  } finally {
    loading.value = false;
  }
}

function goBack() {
  router.push('/homeportal/transfers');
}

function printTransfer() {
  if (!transfer.value?.transfer_number) {
    showNotification('Print available after transfer number is generated', 'warning');
    return;
  }
  const printItems = items.value.map((it) => ({
    item_name: it.item_name,
    sku: it.sku,
    requested_qty: it.picked_qty || it.transfer_qty,
    available_qty: it.received_qty,
    unit_cost: it.unit_cost,
    total_cost: (it.picked_qty || it.transfer_qty) * (it.unit_cost || 0)
  }));
  printStockTransfer(transfer.value, printItems);
}

function doStartPicking() {
  showPickingConfirm.value = true;
}

async function confirmPicking() {
  if (!transfer.value?.id) return;
  picking.value = true;
  try {
    const result = await confirmPickingStockTransfer(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Picking confirmed', 'success');
      showPickingConfirm.value = false;
      await load();
    } else {
      showNotification(result?.error || 'Failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    picking.value = false;
  }
}

function doDispatch() {
  showDispatchConfirm.value = true;
}

async function confirmDispatch() {
  if (!transfer.value?.id || hasInsufficientStock.value) return;
  dispatching.value = true;
  try {
    const result = await dispatchStockTransfer(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Dispatched to logistics', 'success');
      showDispatchConfirm.value = false;
      await load();
    } else {
      showNotification(result?.error || 'Dispatch failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

function openReceiveModal() {
  showReceiveModal.value = true;
}

async function confirmReceive() {
  if (!transfer.value?.id || !canConfirmReceive.value) return;
  receiving.value = true;
  try {
    let allOk = true;
    for (const row of receiveRows.value) {
      const recv = Number(row.receive_qty) || 0;
      const dam = Number(row.damage_qty) || 0;
      const rej = Number(row.reject_qty) || 0;
      if (recv + dam + rej <= 0) continue;
      const result = await receiveStockTransferItem(
        transfer.value.id,
        row.item_id,
        row.batch_id,
        recv,
        dam,
        rej,
        getCurrentUserName()
      );
      if (!result?.ok) {
        showNotification(result?.error || 'Receive failed', 'error');
        allOk = false;
        break;
      }
    }
    if (allOk) {
      showNotification('Items received', 'success');
      showReceiveModal.value = false;
      await load();
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    receiving.value = false;
  }
}

watch(() => route.params.id, () => load(), { immediate: false });
onMounted(() => load());
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
