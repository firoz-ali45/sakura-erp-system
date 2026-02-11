<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
      <div class="flex justify-between items-center mb-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
          <i class="fas fa-arrow-left"></i>
          Back
        </button>
        <div>
          <h1 class="text-2xl font-bold text-gray-800">{{ order?.transfer_number || 'Transfer Order' }}</h1>
          <span v-if="order" :class="['px-3 py-1 rounded-full text-sm font-semibold', statusClass(order.status)]">
            {{ formatStatus(order.status) }}
          </span>
        </div>
      </div>
      <div v-if="order?.status === 'draft'" class="flex gap-2">
        <button @click="deleteDraft" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
          Delete
        </button>
        <button @click="doSubmit" :disabled="submitting" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">
          Submit
        </button>
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
      <!-- Header card -->
      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <label class="block text-sm text-gray-500 mb-1">From</label>
            <p class="font-medium">{{ order.from_name || order.from_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">To</label>
            <p class="font-medium">{{ order.to_name || order.to_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Requested By</label>
            <p class="font-medium">{{ order.requested_by || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created</label>
            <p class="font-medium">{{ formatDate(order.created_at) }}</p>
          </div>
        </div>
      </div>

      <!-- Approval Panel (status = submitted, manager only) -->
      <div v-if="order.status === 'submitted' && permApprove" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Approval</h2>
        <p class="text-sm text-gray-600 mb-4">Next level: {{ approvalStep?.next_level || '—' }}</p>
        <div class="flex gap-3">
          <button
            v-if="approvalStep?.next_level === 1"
            @click="doApprove(1)"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white"
            style="background-color: #284b44;"
          >
            Approve Level 1
          </button>
          <button
            v-if="approvalStep?.next_level === 2"
            @click="doApprove(2)"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white"
            style="background-color: #284b44;"
          >
            Approve Level 2
          </button>
          <button
            @click="doReject"
            :disabled="approving"
            class="px-6 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50"
          >
            Reject
          </button>
        </div>
      </div>

      <!-- Dispatch Panel (warehouse only, fn_can_dispatch_transfer = true) -->
      <div v-if="canDispatch && permDispatch" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Dispatch</h2>
        <button
          @click="doDispatch"
          :disabled="dispatching"
          class="px-6 py-2 rounded-lg text-white font-semibold"
          style="background-color: #1e3a36;"
        >
          <i class="fas fa-truck mr-2"></i> DISPATCH
        </button>
      </div>

      <!-- Receive Panel (branch only, fn_can_receive_transfer = true) -->
      <div v-if="canReceive && permReceive" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Receive</h2>
        <div class="flex flex-wrap gap-3 mb-4">
          <button
            @click="doReceiveFull"
            :disabled="receiving"
            class="px-6 py-2 rounded-lg text-white"
            style="background-color: #284b44;"
          >
            Receive Full
          </button>
        </div>
        <div v-if="itemsWithPending.length > 0" class="border rounded-lg overflow-hidden">
          <p class="p-3 bg-gray-50 text-sm font-medium">Partial / Item-wise receive</p>
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500">Item</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Dispatched</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Received</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Pending</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500">Receive Qty</th>
                <th class="px-4 py-2"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="it in itemsWithPending" :key="it.id" class="border-t">
                <td class="px-4 py-2 text-sm">{{ it.item_name }} ({{ it.sku }})</td>
                <td class="px-4 py-2 text-sm text-right">{{ formatNum(it.dispatched_qty) }}</td>
                <td class="px-4 py-2 text-sm text-right">{{ formatNum(it.received_qty) }}</td>
                <td class="px-4 py-2 text-sm text-right font-medium">{{ formatNum(it.pending) }}</td>
                <td class="px-4 py-2">
                  <input
                    v-model.number="receiveQty[it.item_id]"
                    type="number"
                    :min="0"
                    :max="it.pending"
                    step="0.01"
                    class="w-24 px-2 py-1 border rounded text-right"
                  />
                </td>
                <td class="px-4 py-2">
                  <button
                    @click="doReceiveItem(it)"
                    :disabled="receiving || !(receiveQty[it.item_id] > 0)"
                    class="px-3 py-1 rounded text-white text-sm"
                    style="background-color: #284b44;"
                  >
                    Receive
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Items table -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Items</h2>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Item</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">SKU</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Requested</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Dispatched</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Received</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Variance</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="it in items" :key="it.id">
                <td class="px-4 py-3 text-sm text-gray-900">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.requested_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.dispatched_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.received_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right" :class="it.variance_qty > 0 ? 'text-amber-600' : ''">
                  {{ formatNum(it.variance_qty) }}
                </td>
                <td class="px-4 py-3">
                  <span :class="['px-2 py-1 rounded text-xs font-medium', itemStatusClass(it.item_status)]">
                    {{ it.item_status }}
                  </span>
                </td>
              </tr>
              <tr v-if="!items.length">
                <td colspan="7" class="px-4 py-8 text-center text-gray-500">No items</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getTransferOrderById,
  fetchTransferItemsFlow,
  canDispatchTransfer,
  canReceiveTransfer,
  getNextTransferApprovalStep,
  approveTransferLevel,
  rejectTransfer,
  dispatchTransfer,
  receiveTransfer,
  receiveTransferItem,
  submitTransfer,
  deleteTransferDraft
} from '@/services/transferEngine.js';
import { showNotification } from '@/utils/notifications';
import { forceInventoryViewsRefresh } from '@/services/erpViews.js';
import { useTransferPermissions } from '@/composables/useTransferPermissions.js';

const route = useRoute();
const router = useRouter();
const { canDispatch: permDispatch, canReceive: permReceive, canApprove: permApprove } = useTransferPermissions();
const order = ref(null);
const items = ref([]);
const loading = ref(true);
const error = ref(null);
const canDispatch = ref(false);
const canReceive = ref(false);
const approvalStep = ref(null);
const approving = ref(false);
const dispatching = ref(false);
const receiving = ref(false);
const submitting = ref(false);
const receiveQty = ref({});

const itemsWithPending = computed(() => {
  return items.value.filter(it => (it.dispatched_qty || 0) > (it.received_qty || 0))
    .map(it => ({
      ...it,
      pending: Math.max(0, (it.dispatched_qty || 0) - (it.received_qty || 0))
    }));
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
    partially_received: 'Partially Received',
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

function itemStatusClass(s) {
  const m = {
    pending: 'bg-gray-100 text-gray-800',
    dispatched: 'bg-blue-100 text-blue-800',
    partially_received: 'bg-amber-100 text-amber-800',
    completed: 'bg-green-100 text-green-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
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

async function load() {
  const id = route.params.id;
  if (!id) {
    error.value = 'No transfer ID';
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    order.value = await getTransferOrderById(id);
    items.value = await fetchTransferItemsFlow(id);
    canDispatch.value = await canDispatchTransfer(id);
    canReceive.value = await canReceiveTransfer(id);
    approvalStep.value = await getNextTransferApprovalStep(id);
    receiveQty.value = {};
    items.value.forEach(it => {
      const pending = Math.max(0, (it.dispatched_qty || 0) - (it.received_qty || 0));
      if (pending > 0) receiveQty.value[it.item_id] = pending;
    });
  } catch (e) {
    console.warn(e);
    error.value = e?.message || 'Failed to load';
  } finally {
    loading.value = false;
  }
}

function goBack() {
  router.push('/homeportal/transfer-orders');
}

async function doApprove(level) {
  approving.value = true;
  try {
    const result = await approveTransferLevel(order.value.id, level, getCurrentUserName());
    if (result.ok) {
      showNotification(`Approved at level ${level}`, 'success');
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

async function doReject() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const ok = await showConfirmDialog({
    title: 'Reject Transfer',
    message: 'Are you sure you want to reject this transfer?',
    type: 'danger'
  });
  if (!ok) return;
  approving.value = true;
  try {
    const result = await rejectTransfer(order.value.id, getCurrentUserName());
    if (result.ok) {
      showNotification('Transfer rejected', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Reject failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    approving.value = false;
  }
}

async function doDispatch() {
  dispatching.value = true;
  try {
    const result = await dispatchTransfer(order.value.id, getCurrentUserName());
    if (result.ok) {
      showNotification('Transfer dispatched', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Dispatch failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

async function doReceiveFull() {
  receiving.value = true;
  try {
    const result = await receiveTransfer(order.value.id, getCurrentUserName());
    if (result.ok) {
      showNotification('Transfer received', 'success');
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Receive failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    receiving.value = false;
  }
}

async function doReceiveItem(it) {
  const qty = receiveQty.value[it.item_id];
  if (!qty || qty <= 0) {
    showNotification('Enter receive quantity', 'warning');
    return;
  }
  const pending = Math.max(0, (it.dispatched_qty || 0) - (it.received_qty || 0));
  if (qty > pending) {
    showNotification('Receive qty cannot exceed pending', 'warning');
    return;
  }
  receiving.value = true;
  try {
    const result = await receiveTransferItem(order.value.id, it.item_id, qty, getCurrentUserName());
    if (result.ok) {
      showNotification(`Received ${qty} of ${it.item_name}`, 'success');
      receiveQty.value[it.item_id] = pending - qty;
      await load();
      await forceInventoryViewsRefresh();
    } else {
      showNotification(result.error || 'Receive failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    receiving.value = false;
  }
}

watch(() => route.params.id, () => load(), { immediate: false });

async function doSubmit() {
  submitting.value = true;
  try {
    const result = await submitTransfer(order.value.id);
    if (result.ok) {
      showNotification('Transfer submitted', 'success');
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

async function deleteDraft() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const ok = await showConfirmDialog({
    title: 'Delete Transfer',
    message: 'Are you sure? This cannot be undone.',
    type: 'danger'
  });
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

onMounted(() => load());
</script>

<style scoped>
.loading-spinner {
  animation: spin 1s linear infinite;
}
@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
