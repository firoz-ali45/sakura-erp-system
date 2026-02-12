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
      <div class="flex gap-2 flex-wrap">
        <button
          v-if="order?.status === 'draft'"
          @click="deleteDraft"
          class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50"
        >
          Delete
        </button>
        <button
          v-if="order?.status === 'draft'"
          @click="showEditModal = true"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          Edit
        </button>
        <button
          v-if="order?.status === 'draft'"
          @click="doSubmit"
          :disabled="submitting"
          class="px-6 py-2 rounded-lg text-white font-semibold"
          style="background-color: #284b44;"
        >
          Submit for Approval
        </button>
        <template v-if="order?.status === 'submitted' && permApprove && approvalStep">
          <button
            v-if="approvalStep.next_level === 1"
            @click="doApprove(1)"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Approve L1
          </button>
          <button
            v-if="approvalStep.next_level === 2"
            @click="doApprove(2)"
            :disabled="approving"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Approve L2
          </button>
          <button
            @click="doReject"
            :disabled="approving"
            class="px-6 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50"
          >
            Reject
          </button>
        </template>
        <button
          v-if="canDispatch && permDispatch"
          @click="doDispatch"
          :disabled="dispatching || hasStockWarning"
          :title="hasStockWarning ? 'Insufficient stock at source' : ''"
          class="px-6 py-2 rounded-lg text-white font-semibold"
          style="background-color: #1e3a36;"
        >
          <i class="fas fa-truck mr-2"></i> DISPATCH
        </button>
        <button
          v-if="canReceive && permReceive"
          @click="doReceiveFull"
          :disabled="receiving"
          class="px-6 py-2 rounded-lg text-white font-semibold"
          style="background-color: #284b44;"
        >
          Receive Full
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
        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <div>
            <label class="block text-sm text-gray-500 mb-1">From</label>
            <p class="font-medium">{{ order.from_name || order.from_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">To</label>
            <p class="font-medium">{{ order.to_name || order.to_code || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created By</label>
            <p class="font-medium">{{ order.requested_by || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Business Date</label>
            <p class="font-medium">{{ order.business_date ? formatDate(order.business_date) : '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Created At</label>
            <p class="font-medium">{{ formatDateTime(order.created_at) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total Items</label>
            <p class="font-medium">{{ items.length }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total Qty</label>
            <p class="font-medium">{{ formatNum(order.requested_total ?? totalRequested) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total Value</label>
            <p class="font-medium">{{ formatCurrency(totalValue) }}</p>
          </div>
        </div>
      </div>

      <!-- Approval timeline -->
      <div v-if="timeline.length > 0" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Approval Timeline</h2>
        <div class="flex flex-wrap gap-4">
          <div
            v-for="(t, i) in timeline"
            :key="i"
            class="flex items-center gap-3 px-4 py-2 rounded-lg bg-gray-50"
          >
            <i :class="['fas', t.icon, 'text-[#284b44]']"></i>
            <div>
              <p class="text-sm font-medium text-gray-800">{{ t.label }}</p>
              <p class="text-xs text-gray-600">{{ t.by }} {{ t.at ? '— ' + formatDateTime(t.at) : '' }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Stock validation warning -->
      <div
        v-if="order.status === 'draft' && hasStockWarning"
        class="bg-red-50 border border-red-200 rounded-xl p-4 mb-6 flex items-center gap-3"
      >
        <i class="fas fa-exclamation-triangle text-red-600"></i>
        <p class="text-red-800 font-medium">Transferred Quantity exceeds the Available Quantity. Adjust quantities or add stock before dispatch.</p>
      </div>

      <!-- Approval Panel (fallback) -->
      <div v-if="order.status === 'submitted' && permApprove && !approvalStep?.next_level" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Approval</h2>
        <p class="text-sm text-gray-600">Awaiting approval.</p>
      </div>

      <!-- Dispatch Panel -->
      <div v-if="canDispatch && permDispatch" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Dispatch</h2>
        <button
          @click="doDispatch"
          :disabled="dispatching || hasStockWarning"
          :title="hasStockWarning ? 'Insufficient stock at source' : ''"
          class="px-6 py-2 rounded-lg text-white font-semibold"
          style="background-color: #1e3a36;"
        >
          <i class="fas fa-truck mr-2"></i> DISPATCH
        </button>
      </div>

      <!-- Receive Panel -->
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

      <!-- Items section -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-bold text-gray-800">Items</h2>
          <div v-if="order.status === 'draft'" class="flex gap-2">
            <button
              @click="showImportModal = true"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-file-excel"></i>
              Import Items
            </button>
            <button
              @click="openAddItems"
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
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Item</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">SKU</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Batch</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Available</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Transfer Qty</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Dispatched</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Received</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Variance</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Unit Cost</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500">Total Cost</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500">Status</th>
                <th v-if="order.status === 'draft'" class="px-4 py-3 text-right text-xs font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="it in enrichedItems" :key="it.id">
                <td class="px-4 py-3 text-sm text-gray-900">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm">{{ it.batchLabel || '—' }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.available_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">
                  <template v-if="order.status === 'draft'">
                    <button
                      @click="openEditQty(it)"
                      class="text-[#284b44] hover:underline font-medium"
                    >
                      {{ formatNum(it.requested_qty) }}
                    </button>
                  </template>
                  <template v-else>{{ formatNum(it.requested_qty) }}</template>
                </td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.dispatched_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.received_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right" :class="it.variance_qty > 0 ? 'text-amber-600' : ''">
                  {{ formatNum(it.variance_qty) }}
                </td>
                <td class="px-4 py-3 text-sm text-right">{{ formatCurrency(it.unit_cost) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatCurrency(it.total_cost) }}</td>
                <td class="px-4 py-3">
                  <span :class="['px-2 py-1 rounded text-xs font-medium', itemStatusClass(it.item_status)]">
                    {{ it.item_status }}
                  </span>
                </td>
                <td v-if="order.status === 'draft'" class="px-4 py-3 text-right">
                  <button
                    @click="removeItem(it)"
                    class="text-red-600 hover:text-red-800"
                    title="Remove"
                  >
                    <i class="fas fa-trash"></i>
                  </button>
                </td>
              </tr>
              <tr v-if="!items.length">
                <td :colspan="order.status === 'draft' ? 12 : 11" class="px-4 py-8 text-center text-gray-500">No items</td>
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
            <select v-model="editForm.from_location_id" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Choose...</option>
              <option v-for="loc in sourceLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }}{{ loc.location_code ? ` (${loc.location_code})` : '' }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Destination *</label>
            <select v-model="editForm.to_location_id" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Choose...</option>
              <option v-for="loc in filteredDestLocations" :key="loc.id" :value="loc.id">{{ loc.location_name }}{{ loc.location_code ? ` (${loc.location_code})` : '' }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Business Date</label>
            <input v-model="editForm.business_date" type="date" class="w-full px-3 py-2 border rounded-lg" />
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

    <!-- Add Items modal -->
    <div v-if="showAddModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showAddModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-bold mb-4">Add Items</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search Items</label>
            <input
              v-model="addSearchQuery"
              type="text"
              placeholder="Type to search by name, SKU, barcode..."
              class="w-full px-3 py-2 border rounded-lg"
              @input="debouncedSearch"
            />
            <div v-if="addSearchResults.length > 0" class="mt-2 border rounded-lg max-h-48 overflow-y-auto">
              <button
                v-for="it in addSearchResults"
                :key="it.id"
                @click="selectAddItem(it)"
                class="w-full px-4 py-2 text-left hover:bg-gray-50 flex justify-between items-center"
              >
                <span>{{ it.name }}</span>
                <span class="text-xs text-gray-500">{{ it.sku }}</span>
              </button>
            </div>
          </div>
          <div v-if="selectedAddItem" class="border rounded-lg p-4 bg-gray-50">
            <p class="font-medium">{{ selectedAddItem.name }} ({{ selectedAddItem.sku }})</p>
            <p class="text-sm text-gray-600 mt-1">Available: {{ formatNum(addItemStock?.available_qty) }} | Avg cost: {{ formatCurrency(addItemStock?.avg_cost) }}</p>
            <p v-if="addItemStock?.batches?.length" class="text-xs text-gray-500">Batches: {{ addItemStock.batches.join(', ') }}</p>
            <div class="mt-3 flex items-center gap-2">
              <label class="text-sm">Transfer Qty:</label>
              <input v-model.number="addItemQty" type="number" min="0.01" step="0.01" class="w-24 px-2 py-1 border rounded" />
              <button
                @click="confirmAddItem"
                :disabled="!addItemQty || addItemQty <= 0"
                class="px-4 py-1 rounded text-white text-sm"
                style="background-color: #284b44;"
              >
                Add
              </button>
            </div>
          </div>
        </div>
        <div class="flex justify-end mt-6">
          <button @click="showAddModal = false" class="px-4 py-2 border rounded-lg">Close</button>
        </div>
      </div>
    </div>

    <!-- Edit Quantity popup -->
    <div v-if="showEditQtyModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showEditQtyModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-sm">
        <h3 class="text-lg font-bold mb-4">Update Quantity</h3>
        <p class="text-sm text-gray-600 mb-2">{{ editQtyItem?.item_name }} ({{ editQtyItem?.sku }})</p>
        <p class="text-sm text-gray-500 mb-3">Available: {{ formatNum(editQtyItem?.available_qty) }}</p>
        <div class="flex items-center gap-2">
          <label class="text-sm">Quantity:</label>
          <input v-model.number="editQtyValue" type="number" min="0" step="0.01" class="w-24 px-2 py-1 border rounded" />
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showEditQtyModal = false" class="px-4 py-2 border rounded-lg">Close</button>
          <button @click="saveEditQty" :disabled="editQtySaving" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
        </div>
      </div>
    </div>

    <!-- Import Items modal -->
    <div v-if="showImportModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showImportModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-bold mb-4">Import Items</h3>
        <p class="text-sm text-gray-600 mb-2">Upload Excel with columns: <strong>SKU</strong>, <strong>Quantity</strong></p>
        <a href="#" @click.prevent="downloadImportTemplate" class="text-[#284b44] hover:underline text-sm mb-4 block">Download Template</a>
        <input
          ref="importFileInput"
          type="file"
          accept=".xlsx,.xls,.csv"
          class="hidden"
          @change="onImportFile"
        />
        <button
          @click="$refs.importFileInput?.click()"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 mb-4"
        >
          <i class="fas fa-upload"></i>
          Choose File
        </button>
        <div v-if="importPreview.length > 0" class="border rounded-lg overflow-hidden">
          <p class="p-2 bg-gray-50 text-sm font-medium">Preview</p>
          <table class="w-full text-sm">
            <thead class="bg-gray-100">
              <tr>
                <th class="px-3 py-2 text-left">SKU</th>
                <th class="px-3 py-2 text-right">Quantity</th>
                <th class="px-3 py-2 text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in importPreview" :key="i" class="border-t">
                <td class="px-3 py-2">{{ r.sku }}</td>
                <td class="px-3 py-2 text-right">{{ r.quantity }}</td>
                <td class="px-3 py-2" :class="r.error ? 'text-red-600' : 'text-green-600'">{{ r.error || 'OK' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="importErrors.length > 0" class="mt-2 text-red-600 text-sm">
          <p v-for="(e, i) in importErrors" :key="i">{{ e }}</p>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showImportModal = false" class="px-4 py-2 border rounded-lg">Close</button>
          <button
            @click="confirmImport"
            :disabled="importPreview.length === 0 || !importPreview.some(r => !r.error)"
            class="px-6 py-2 rounded-lg text-white"
            style="background-color: #284b44;"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getTransferOrderById,
  fetchTransferItemsFlow,
  fetchStockMapForItems,
  fetchTransferApprovals,
  fetchTransferDispatches,
  fetchTransferReceipts,
  canDispatchTransfer,
  canReceiveTransfer,
  getNextTransferApprovalStep,
  approveTransferLevel,
  rejectTransfer,
  dispatchTransfer,
  receiveTransfer,
  receiveTransferItem,
  submitTransfer,
  deleteTransferDraft,
  updateTransferDraft,
  addItemsToTransferOrder,
  updateTransferItemQty,
  removeTransferItem,
  searchInventoryItems,
  fetchItemStockAtLocation,
  importTransferItemsFromRows
} from '@/services/transferEngine.js';
import { showNotification } from '@/utils/notifications';
import { forceInventoryViewsRefresh } from '@/services/erpViews.js';
import { useTransferPermissions } from '@/composables/useTransferPermissions.js';
import { loadTransferSourceLocations, loadTransferDestLocations } from '@/composables/useInventoryLocations.js';
import * as XLSX from 'xlsx';

const route = useRoute();
const router = useRouter();
const { canDispatch: permDispatch, canReceive: permReceive, canApprove: permApprove } = useTransferPermissions();
const order = ref(null);
const items = ref([]);
const stockMap = ref({});
const loading = ref(true);
const error = ref(null);
const canDispatch = ref(false);
const canReceive = ref(false);
const approvalStep = ref(null);
const approvals = ref([]);
const dispatches = ref([]);
const receipts = ref([]);
const approving = ref(false);
const dispatching = ref(false);
const receiving = ref(false);
const submitting = ref(false);
const receiveQty = ref({});
const showEditModal = ref(false);
const showAddModal = ref(false);
const showEditQtyModal = ref(false);
const showImportModal = ref(false);
const editForm = ref({ from_location_id: '', to_location_id: '', business_date: '', remarks: '' });
const editSaving = ref(false);
const sourceLocations = ref([]);
const destLocations = ref([]);
const addSearchQuery = ref('');
const addSearchResults = ref([]);
const selectedAddItem = ref(null);
const addItemStock = ref(null);
const addItemQty = ref(1);
const editQtyItem = ref(null);
const editQtyValue = ref(0);
const editQtySaving = ref(false);
const importPreview = ref([]);
const importErrors = ref([]);
const importFileInput = ref(null);
const pendingImportRows = ref([]);
let searchTimeout = null;

const totalRequested = computed(() => items.value.reduce((s, it) => s + (Number(it.requested_qty) || 0), 0));
const totalValue = computed(() =>
  enrichedItems.value.reduce((s, it) => s + (Number(it.total_cost) || 0), 0)
);
const enrichedItems = computed(() => {
  return items.value.map((it) => {
    const stock = stockMap.value[it.item_id] || {};
    const avail = stock.available_qty ?? 0;
    const avgCost = stock.avg_cost ?? 0;
    const req = Number(it.requested_qty) || 0;
    const totalCost = req * avgCost;
    const batchLabel = stock.batches?.length ? (stock.batches.length > 1 ? `${stock.batches.length} batches` : stock.batches[0]) : null;
    return {
      ...it,
      available_qty: avail,
      unit_cost: avgCost,
      total_cost: totalCost,
      batchLabel,
      exceedsStock: req > avail && avail >= 0
    };
  });
});
const hasStockWarning = computed(() => enrichedItems.value.some((it) => it.exceedsStock));
const itemsWithPending = computed(() => {
  return items.value.filter(it => (it.dispatched_qty || 0) > (it.received_qty || 0))
    .map(it => ({
      ...it,
      pending: Math.max(0, (it.dispatched_qty || 0) - (it.received_qty || 0))
    }));
});
const timeline = computed(() => {
  const out = [];
  const req = order.value?.requested_by;
  if (req) out.push({ label: 'Submitted by', by: req, at: order.value?.created_at, icon: 'fa-paper-plane' });
  approvals.value.forEach((a) => {
    out.push({ label: `Approved L${a.approval_level}`, by: a.approved_by, at: a.approved_at, icon: 'fa-check-circle' });
  });
  const d = dispatches.value[0];
  if (d) out.push({ label: 'Dispatched', by: d.dispatched_by || '—', at: d.dispatched_at, icon: 'fa-truck' });
  const r = receipts.value[0];
  if (r) out.push({ label: 'Received', by: r.received_by || '—', at: r.received_at, icon: 'fa-box-open' });
  if (order.value?.status === 'closed') out.push({ label: 'Closed', by: '—', at: null, icon: 'fa-archive' });
  return out;
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function formatCurrency(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
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
  const m = { draft: 'Draft', submitted: 'Submitted', level1_approved: 'L1 Approved', level2_approved: 'L2 Approved', dispatched: 'Dispatched', partially_received: 'Partially Received', closed: 'Closed', rejected: 'Rejected' };
  return m[(s || '').toLowerCase()] || s;
}
function statusClass(s) {
  const m = { draft: 'bg-gray-100 text-gray-800', submitted: 'bg-amber-100 text-amber-800', level1_approved: 'bg-blue-100 text-blue-800', level2_approved: 'bg-blue-100 text-blue-800', dispatched: 'bg-green-100 text-green-800', partially_received: 'bg-purple-100 text-purple-800', closed: 'bg-gray-100 text-gray-800', rejected: 'bg-red-100 text-red-800' };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}
function itemStatusClass(s) {
  const m = { pending: 'bg-gray-100 text-gray-800', dispatched: 'bg-blue-100 text-blue-800', partially_received: 'bg-amber-100 text-amber-800', completed: 'bg-green-100 text-green-800' };
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
    canDispatch.value = await canDispatchTransfer(id);
    canReceive.value = await canReceiveTransfer(id);
    approvalStep.value = await getNextTransferApprovalStep(id);
    approvals.value = await fetchTransferApprovals(id);
    dispatches.value = await fetchTransferDispatches(id);
    receipts.value = await fetchTransferReceipts(id);
    const itemIds = items.value.map((it) => it.item_id).filter(Boolean);
    if (itemIds.length && order.value?.from_location_id) {
      stockMap.value = await fetchStockMapForItems(order.value.from_location_id, itemIds);
    } else {
      stockMap.value = {};
    }
    receiveQty.value = {};
    items.value.forEach(it => {
      const pending = Math.max(0, (it.dispatched_qty || 0) - (it.received_qty || 0));
      if (pending > 0) receiveQty.value[it.item_id] = pending;
    });
    if (order.value?.status === 'draft') {
      sourceLocations.value = await loadTransferSourceLocations();
      destLocations.value = await loadTransferDestLocations();
      editForm.value = { from_location_id: order.value.from_location_id, to_location_id: order.value.to_location_id, business_date: order.value.business_date ? String(order.value.business_date).slice(0, 10) : '', remarks: order.value.remarks || '' };
    }
  } catch (e) {
    console.warn(e);
    error.value = e?.message || 'Failed to load';
  } finally {
    loading.value = false;
  }
}

/** Destinations exclude selected source. */
const filteredDestLocations = computed(() => {
  const src = editForm.value.from_location_id;
  if (!src) return destLocations.value;
  return destLocations.value.filter((loc) => loc.id !== src);
});

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
      business_date: editForm.value.business_date,
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

function openAddItems() {
  showAddModal.value = true;
  addSearchQuery.value = '';
  addSearchResults.value = [];
  selectedAddItem.value = null;
  addItemStock.value = null;
  addItemQty.value = 1;
  searchInventoryItems('').then((r) => { addSearchResults.value = r; });
}
async function debouncedSearch() {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(async () => {
    const q = addSearchQuery.value?.trim();
    addSearchResults.value = await searchInventoryItems(q || '', 50);
  }, 200);
}
async function selectAddItem(it) {
  selectedAddItem.value = it;
  if (order.value?.from_location_id) {
    const stock = await fetchItemStockAtLocation(order.value.from_location_id);
    addItemStock.value = stock.find((s) => s.item_id === it.id) || { available_qty: 0, avg_cost: 0, batches: [] };
  } else {
    addItemStock.value = { available_qty: 0, avg_cost: 0, batches: [] };
  }
  addItemQty.value = 1;
}
async function confirmAddItem() {
  if (!selectedAddItem.value || !addItemQty.value || addItemQty.value <= 0) return;
  const r = await addItemsToTransferOrder(order.value.id, [{ item_id: selectedAddItem.value.id, requested_qty: addItemQty.value }]);
  if (r.success) {
    showNotification('Item added', 'success');
    selectedAddItem.value = null;
    addItemStock.value = null;
    await load();
  } else {
    showNotification(r.error || 'Add failed', 'error');
  }
}

function openEditQty(it) {
  editQtyItem.value = it;
  editQtyValue.value = Number(it.requested_qty) || 0;
  showEditQtyModal.value = true;
}
async function saveEditQty() {
  if (!editQtyItem.value || editQtyValue.value < 0) return;
  editQtySaving.value = true;
  try {
    const r = await updateTransferItemQty(order.value.id, editQtyItem.value.item_id, editQtyValue.value);
    if (r.success) {
      showNotification('Quantity updated', 'success');
      showEditQtyModal.value = false;
      await load();
    } else {
      showNotification(r.error || 'Update failed', 'error');
    }
  } finally {
    editQtySaving.value = false;
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

function downloadImportTemplate() {
  const ws = XLSX.utils.aoa_to_sheet([['SKU', 'Quantity'], ['sk-12345', '10']]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Items');
  XLSX.writeFile(wb, 'transfer_order_items_template.xlsx');
}
function onImportFile(ev) {
  const f = ev.target?.files?.[0];
  if (!f) return;
  const reader = new FileReader();
  reader.onload = async (e) => {
    const data = e.target?.result;
    const wb = XLSX.read(data, { type: 'binary' });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1 });
    const headers = (rows[0] || []).map((h) => String(h || '').toLowerCase());
    const skuCol = headers.findIndex((h) => h === 'sku');
    const qtyCol = headers.findIndex((h) => ['quantity', 'qty', 'qty.'].includes(h));
    if (skuCol < 0 || qtyCol < 0) {
      showNotification('Excel must have SKU and Quantity columns', 'warning');
      return;
    }
    const parsed = rows.slice(1).map((row, i) => {
      const sku = String(row[skuCol] || '').trim();
      const qty = parseFloat(row[qtyCol] || 0);
      return { sku, quantity: qty, rowIndex: i + 2 };
    }).filter((r) => r.sku || r.quantity);
    pendingImportRows.value = parsed;
    importErrors.value = [];
    importPreview.value = parsed.map((r) => ({ sku: r.sku, quantity: r.quantity, error: null }));
    await validateImportPreview();
  };
  reader.readAsBinaryString(f);
  ev.target.value = '';
}
async function validateImportPreview() {
  const { supabaseClient } = await import('@/services/supabase.js');
  const { data: allItems } = await supabaseClient.from('inventory_items').select('id, sku').or('deleted.eq.false,deleted.is.null');
  const skuMap = (allItems || []).reduce((acc, it) => { acc[(it.sku || '').toLowerCase()] = it; return acc; }, {});
  importPreview.value = pendingImportRows.value.map((r) => {
    const item = skuMap[r.sku?.toLowerCase()];
    const err = !r.sku ? 'SKU required' : !item ? `SKU "${r.sku}" not found` : r.quantity <= 0 ? 'Invalid quantity' : null;
    return { sku: r.sku, quantity: r.quantity, error: err };
  });
}
async function confirmImport() {
  const valid = pendingImportRows.value.filter((_, i) => !importPreview.value[i]?.error);
  if (valid.length === 0) {
    showNotification('No valid rows to import', 'warning');
    return;
  }
  const rows = valid.map((r) => ({ SKU: r.sku, Quantity: r.quantity }));
  const result = await importTransferItemsFromRows(order.value.id, order.value.from_location_id, rows);
  if (result.success) {
    showNotification(`Imported ${result.added.length} items`, 'success');
    showImportModal.value = false;
    importPreview.value = [];
    pendingImportRows.value = [];
    await load();
  } else {
    showNotification(result.errors?.[0] || 'Import failed', 'error');
  }
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
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Reject Transfer', message: 'Are you sure?', type: 'danger' });
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
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Delete Transfer', message: 'Are you sure? This cannot be undone.', type: 'danger' });
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

watch(() => route.params.id, () => load(), { immediate: false });

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
