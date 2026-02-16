<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex justify-between items-center mb-6 sticky top-0 z-20 bg-[#f0e1cd] py-2 -mx-6 px-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-[#284b44] hover:text-[#1e3a36] flex items-center gap-2 font-medium">
          <i class="fas fa-arrow-left"></i>
          Back
        </button>
        <h1 class="text-2xl font-bold text-gray-800">{{ order?.transfer_number || 'Transfer Order' }}</h1>
      </div>
      <div class="flex gap-2 flex-wrap">
        <template v-if="normalizedStatus === 'draft'">
          <button @click="deletePermanently" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">Delete Permanently</button>
          <button disabled class="px-4 py-2 border border-gray-300 rounded-lg opacity-50 cursor-not-allowed">Print</button>
          <button @click="openEdit" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Edit</button>
          <button @click="submitForReview" :disabled="submitting || hasStockWarning" class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50" style="background-color: #284b44;">Submit for review</button>
        </template>
        <template v-else-if="normalizedStatus === 'pending'">
          <button @click="doDecline" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">Decline</button>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Print</button>
          <button @click="doAccept" class="px-6 py-2 rounded-lg text-white font-semibold" style="background-color: #284b44;">Accept</button>
        </template>
        <template v-else-if="normalizedStatus === 'approved'">
          <button @click="doDecline" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">Decline</button>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Print</button>
          <button @click="sendItems" class="px-6 py-2 rounded-lg text-white font-semibold" style="background-color: #284b44;">Send Items</button>
        </template>
        <template v-else>
          <button @click="printOrder" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Print</button>
        </template>
      </div>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-8 text-center">Loading...</div>
    <div v-else-if="!order" class="bg-white rounded-xl shadow-md p-8 text-center">Transfer order not found.</div>

    <template v-else>
      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-3">
            <div><span class="text-sm text-gray-500">Source</span><p class="font-medium">{{ order.from_name || order.from_code || '—' }}</p></div>
            <div><span class="text-sm text-gray-500">Destination</span><p class="font-medium">{{ order.to_name || order.to_code || '—' }}</p></div>
            <div><span class="text-sm text-gray-500">Business Date</span><p class="font-medium">{{ formatDate(order.business_date || today) }}</p></div>
            <div><span class="text-sm text-gray-500">Created at</span><p class="font-medium">{{ formatDateTime(order.created_at) }}</p></div>
            <div><span class="text-sm text-gray-500">Created by</span><p class="font-medium">{{ order.requested_by || '—' }}</p></div>
          </div>
          <div class="space-y-3 md:text-right">
            <div><span class="text-sm text-gray-500">Status</span><p><span :class="['px-2 py-1 rounded text-sm font-medium', statusClass(normalizedStatus)]">{{ formatStatus(normalizedStatus) }}</span></p></div>
            <div><span class="text-sm text-gray-500">Number of items</span><p class="font-medium">{{ items.length }}</p></div>
            <div><span class="text-sm text-gray-500">Total Qty</span><p class="font-medium">{{ formatNum(totalRequested) }}</p></div>
          </div>
        </div>
      </div>

      <div v-if="normalizedStatus === 'draft' && hasStockWarning" class="bg-red-50 border border-red-200 rounded-xl p-4 mb-6">
        <p class="text-red-800 font-medium">Transferred quantity exceeds available quantity</p>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-bold text-gray-800">Items</h2>
          <div v-if="normalizedStatus === 'draft'" class="flex gap-2 flex-wrap">
            <button class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Storage Unit</button>
            <button class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Edit Quantities</button>
            <button @click="showImportModal = true" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Import Items</button>
            <button @click="showAddModal = true" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">Add Items</button>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Item Name</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">SKU</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Quantity</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Available Quantity</th>
                <th v-if="normalizedStatus === 'draft'" class="px-4 py-3 w-10"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="it in enrichedItems" :key="it.id" class="hover:bg-gray-50 cursor-pointer" @click="normalizedStatus === 'draft' && openEditItem(it)">
                <td class="px-4 py-3 text-sm">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.requested_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.available_qty) }}</td>
                <td v-if="normalizedStatus === 'draft'" class="px-4 py-3 text-right">
                  <button @click.stop="removeItem(it)" class="text-red-600 hover:text-red-800"><i class="fas fa-trash"></i></button>
                </td>
              </tr>
              <tr v-if="!items.length">
                <td :colspan="normalizedStatus === 'draft' ? 5 : 4" class="px-4 py-8 text-center text-gray-500">No data to display!</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

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
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showEditModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button @click="saveEdit" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
        </div>
      </div>
    </div>

    <AddItemModal v-if="showAddModal" :from-location-id="order?.from_location_id" @close="showAddModal = false" @save="onAddItem" />
    <EditItemModal v-if="showEditItemModal" :item="editItem" @close="showEditItemModal = false" @save="onSaveEditItem" @delete="onDeleteEditItem" />
    <ImportItemsModal v-if="showImportModal" :from-location-id="order?.from_location_id" @close="showImportModal = false" @import="onImportItems" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getTransferOrderById,
  fetchTransferItemsFlow,
  fetchStockMapForItems,
  submitTransferOrder,
  approveTransferOrder,
  declineTransferOrder,
  sendTransferOrder,
  deleteTransferDraft,
  updateTransferDraft,
  addItemsToTransferOrder,
  updateTransferItemQty,
  removeTransferItem,
  importTransferItemsFromRows,
  normalizeTransferStatus
} from '@/services/transferEngine.js';
import { loadTransferSourceLocations, loadTransferDestLocations } from '@/composables/useInventoryLocations.js';
import { buildTransferOrderPrintHtml, printDocument } from '@/services/pdfPrintService.js';
import { showNotification } from '@/utils/notifications';
import AddItemModal from '@/components/transfer/AddItemModal.vue';
import EditItemModal from '@/components/transfer/EditItemModal.vue';
import ImportItemsModal from '@/components/transfer/ImportItemsModal.vue';

const route = useRoute();
const router = useRouter();
const order = ref(null);
const items = ref([]);
const stockMap = ref({});
const loading = ref(true);
const submitting = ref(false);
const showEditModal = ref(false);
const showAddModal = ref(false);
const showEditItemModal = ref(false);
const showImportModal = ref(false);
const sourceLocations = ref([]);
const destLocations = ref([]);
const editItem = ref(null);
const editForm = ref({ from_location_id: '', to_location_id: '' });
const today = new Date().toISOString().slice(0, 10);

const normalizedStatus = computed(() => normalizeTransferStatus(order.value?.status));
const totalRequested = computed(() => items.value.reduce((s, it) => s + (Number(it.requested_qty) || 0), 0));
const enrichedItems = computed(() => items.value.map((it) => ({ ...it, available_qty: stockMap.value[it.item_id]?.available_qty ?? 0 })));
const hasStockWarning = computed(() => enrichedItems.value.some((it) => (Number(it.requested_qty) || 0) > (Number(it.available_qty) || 0)));
const filteredDestLocations = computed(() => destLocations.value.filter((loc) => loc.id !== editForm.value.from_location_id));

function formatNum(n) { const v = Number(n); return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 }); }
function formatDate(d) { return d ? new Date(d).toLocaleDateString('en-GB') : '—'; }
function formatDateTime(d) { return d ? new Date(d).toLocaleString('en-GB') : '—'; }
function formatStatus(s) { return { draft: 'Draft', pending: 'Pending', approved: 'Approved', declined: 'Declined', sent: 'Sent', closed: 'Closed' }[s] || s; }
function statusClass(s) { return { draft: 'bg-gray-100 text-gray-800', pending: 'bg-amber-100 text-amber-800', approved: 'bg-blue-100 text-blue-800', declined: 'bg-red-100 text-red-800', sent: 'bg-green-100 text-green-800', closed: 'bg-gray-100 text-gray-800' }[s] || 'bg-gray-100 text-gray-800'; }
function userName() { try { const u = JSON.parse(localStorage.getItem('sakura_current_user') || '{}'); return u.name || u.email?.split('@')[0] || 'user'; } catch { return 'user'; } }

async function load() {
  loading.value = true;
  order.value = await getTransferOrderById(route.params.id);
  items.value = order.value ? await fetchTransferItemsFlow(order.value.id) : [];
  stockMap.value = order.value?.from_location_id ? await fetchStockMapForItems(order.value.from_location_id, items.value.map((it) => it.item_id)) : {};
  sourceLocations.value = await loadTransferSourceLocations();
  destLocations.value = await loadTransferDestLocations();
  editForm.value = { from_location_id: order.value?.from_location_id || '', to_location_id: order.value?.to_location_id || '' };
  loading.value = false;
}

function goBack() { router.push('/homeportal/transfer-orders'); }
function openEdit() { showEditModal.value = true; }
function onEditSourceChange() { if (editForm.value.from_location_id === editForm.value.to_location_id) editForm.value.to_location_id = ''; }

async function saveEdit() {
  if (!editForm.value.from_location_id || !editForm.value.to_location_id || editForm.value.from_location_id === editForm.value.to_location_id) return;
  const res = await updateTransferDraft(order.value.id, editForm.value);
  if (!res.success) return showNotification(res.error || 'Save failed', 'error');
  showEditModal.value = false;
  await load();
}

async function submitForReview() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Submit for review', message: 'Are you sure you want to submit this?', type: 'info' });
  if (!ok) return;
  submitting.value = true;
  const res = await submitTransferOrder(order.value.id);
  submitting.value = false;
  if (!res.ok) return showNotification(res.error || 'Submit failed', 'error');
  await load();
}

async function doAccept() { const res = await approveTransferOrder(order.value.id, userName()); if (res.ok) await load(); }
async function doDecline() { const res = await declineTransferOrder(order.value.id, userName()); if (res.ok) await load(); }
async function sendItems() { const res = await sendTransferOrder(order.value.id, userName()); if (res.ok) { await load(); router.push(`/homeportal/transfer-sending/${order.value.id}`); } }

async function deletePermanently() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Delete Permanently', message: 'Delete transfer order permanently?', type: 'danger' });
  if (!ok) return;
  const res = await deleteTransferDraft(order.value.id);
  if (res.success) goBack();
}

function printOrder() {
  if (!order.value?.transfer_number) return;
  const html = buildTransferOrderPrintHtml(order.value, enrichedItems.value);
  printDocument(html, `Transfer Order ${order.value.transfer_number}`);
}

function openEditItem(it) { editItem.value = it; showEditItemModal.value = true; }
async function onSaveEditItem(qty) { await updateTransferItemQty(order.value.id, editItem.value.item_id, qty); await load(); }
async function onDeleteEditItem() { await removeTransferItem(order.value.id, editItem.value.item_id); await load(); }
async function onAddItem(payload) { await addItemsToTransferOrder(order.value.id, [payload]); await load(); }
async function onImportItems(rows) { await importTransferItemsFromRows(order.value.id, order.value.from_location_id, rows); await load(); }
async function removeItem(it) { await removeTransferItem(order.value.id, it.item_id); await load(); }

onMounted(load);
</script>
