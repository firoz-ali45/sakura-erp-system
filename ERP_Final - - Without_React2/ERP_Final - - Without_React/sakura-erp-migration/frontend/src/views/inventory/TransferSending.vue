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
          <span v-else-if="transfer && !transfer.transfer_orders_id" class="text-sm text-gray-500">Direct transfer</span>
          <span v-if="transfer" :class="['px-3 py-1 rounded-full text-sm font-semibold', statusClass(transfer.status)]">
            {{ formatStatus(transfer.status) }}
          </span>
        </div>
      </div>
      <div class="flex gap-2 flex-wrap">
        <!-- Draft: Delete, Print, Start Picking, Add Items (direct transfer) -->
        <template v-if="transfer?.status === 'draft'">
          <button @click="doDelete" class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50">
            Delete
          </button>
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            v-if="!transfer?.transfer_orders_id"
            @click="showAddItemModal = true"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-plus"></i> Add Items
          </button>
          <button
            @click="doStartPicking"
            :disabled="picking || !items.length"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Start Picking
          </button>
        </template>
        <!-- Picking: Save picking (per row), Mark Picked -->
        <template v-else-if="transfer?.status === 'picking'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doMarkPicked"
            :disabled="picking || hasMissingBatch"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Mark Picked
          </button>
        </template>
        <!-- Picked: Print, Dispatch to Driver -->
        <template v-else-if="transfer?.status === 'picked'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="openDispatchModal"
            :disabled="dispatching || hasInsufficientStock || hasMissingBatchOnPicked"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Dispatch to Driver
          </button>
        </template>
        <!-- Handed to Driver: Mark In Transit -->
        <template v-else-if="transfer?.status === 'handed_to_driver'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doMarkInTransit"
            :disabled="dispatching"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Mark In Transit
          </button>
        </template>
        <!-- In Transit: Mark Arrived -->
        <template v-else-if="transfer?.status === 'in_transit'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            @click="doMarkArrived"
            :disabled="dispatching"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Mark Arrived
          </button>
        </template>
        <!-- Arrived: Quality Inspection, Receive Items -->
        <template v-else-if="transfer?.status === 'arrived'">
          <button @click="printTransfer" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <i class="fas fa-print"></i> Print
          </button>
          <button
            v-if="!hasQualityCheck"
            @click="showQualityModal = true"
            :disabled="dispatching"
            class="px-6 py-2 rounded-lg text-white font-semibold"
            style="background-color: #284b44;"
          >
            Quality Inspection
          </button>
          <button
            @click="openReceiveModal"
            :disabled="receiving || !hasQualityCheck"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Receive Items
          </button>
        </template>
        <!-- Partially Received: Receive Items -->
        <template v-else-if="transfer?.status === 'partially_received'">
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
            <label class="block text-sm text-gray-500 mb-1">Transfer No (TRS)</label>
            <p class="font-medium">{{ transfer.transfer_number || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Linked TO</label>
            <p class="font-medium">{{ transfer.to_number || (transfer?.transfer_orders_id ? '—' : 'Direct') }}</p>
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
          <div>
            <label class="block text-sm text-gray-500 mb-1">Total value</label>
            <p class="font-medium">{{ formatCurrency(transferTotalValue) }}</p>
          </div>
        </div>
      </div>

      <!-- Document Flow: TO → Transfer → Receiving -->
      <DocumentFlow
        v-if="transfer?.id"
        flow-type="transfer"
        doc-type="trs"
        :doc-id="transfer.id"
        :current-number="transfer.transfer_number"
      />

      <div v-if="hasMissingBatch && transfer?.status === 'picking'" class="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6 text-amber-800">
        <i class="fas fa-exclamation-triangle mr-2"></i>
        All items must have batch selected and picked qty before marking as Picked. Click each row to select batch.
      </div>
      <div v-if="(hasInsufficientStock || hasMissingBatchOnPicked) && transfer?.status === 'picked'" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 text-red-800">
        <i class="fas fa-exclamation-triangle mr-2"></i>
        <span v-if="hasMissingBatchOnPicked">All items must have batch selected. Cannot dispatch.</span>
        <span v-else>Insufficient stock in source warehouse. Cannot dispatch.</span>
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

      <!-- Logistics Handover Card -->
      <div v-if="logisticsHandover" class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4">Logistics</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <label class="block text-sm text-gray-500 mb-1">Driver</label>
            <p class="font-medium">{{ logisticsHandover.driver_name || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Vehicle</label>
            <p class="font-medium">{{ logisticsHandover.vehicle_no || '—' }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Handover Time</label>
            <p class="font-medium">{{ formatDateTime(logisticsHandover.handover_time) }}</p>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">Status</label>
            <p class="font-medium">{{ logisticsHandover.handover_status || '—' }}</p>
          </div>
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
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Unit Cost</th>
                <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Total Value</th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr
                v-for="it in items"
                :key="it.id"
                :class="[(it.variance_qty || 0) > 0 ? 'bg-red-50' : '', (transfer?.status === 'picking' || transfer?.status === 'draft') ? 'cursor-pointer hover:bg-gray-50' : '']"
                @click="(transfer?.status === 'picking') ? openPickingModal(it) : null"
              >
                <td class="px-4 py-3 text-sm text-gray-900">{{ it.item_name }}</td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">{{ it.sku }}</td>
                <td class="px-4 py-3 text-sm text-gray-600">{{ it.batch_no || it.lot_no || '—' }}</td>
                <td class="px-4 py-3 text-sm" :class="isExpired(it) ? 'text-red-600 font-semibold' : ''">{{ formatDate(it.batch_expiry || it.expiry_date) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.transfer_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.picked_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatNum(it.received_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right text-amber-600">{{ formatNum(it.damaged_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right" :class="(it.variance_qty || 0) > 0 ? 'text-red-600 font-semibold' : ''">{{ formatNum(it.variance_qty) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatCurrency(it.unit_cost) }}</td>
                <td class="px-4 py-3 text-sm text-right">{{ formatCurrency(itemTotalValue(it)) }}</td>
                <td class="px-4 py-3 text-sm">{{ itemStatus(it) }}</td>
              </tr>
              <tr v-if="!items.length">
                <td colspan="12" class="px-4 py-8 text-center text-gray-500">No items</td>
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
        <!-- OTP Verification (required before receive when status is arrived) -->
        <div v-if="transfer?.status === 'arrived' && !otpVerified" class="mb-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
          <p class="text-sm font-medium text-amber-800 mb-2">Delivery OTP verification required</p>
          <div class="flex items-center gap-2 flex-wrap">
            <button
              v-if="!generatedOtp"
              @click="doGenerateOtp"
              :disabled="dispatching"
              class="px-4 py-2 rounded-lg text-white text-sm font-medium"
              style="background-color: #284b44;"
            >
              Generate OTP
            </button>
            <template v-else>
              <span class="text-lg font-mono font-bold text-gray-800">{{ generatedOtp }}</span>
              <span class="text-sm text-gray-600">(share with branch manager)</span>
            </template>
            <div v-if="generatedOtp" class="flex items-center gap-2 flex-1">
              <input
                v-model="otpInput"
                type="text"
                maxlength="6"
                placeholder="Enter 6-digit OTP"
                class="w-32 px-3 py-2 border rounded-lg font-mono text-lg"
              />
              <button
                @click="doVerifyOtp"
                :disabled="dispatching || otpInput?.length !== 6"
                class="px-4 py-2 rounded-lg text-white text-sm font-medium disabled:opacity-50"
                style="background-color: #284b44;"
              >
                Verify OTP
              </button>
            </div>
          </div>
          <p v-if="otpVerified" class="text-green-600 text-sm mt-2"><i class="fas fa-check-circle"></i> OTP verified</p>
        </div>
        <div class="overflow-x-auto flex-1 overflow-y-auto">
          <table class="w-full">
            <thead class="bg-gray-50 sticky top-0">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Item</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Picked</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Receive</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Damaged</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Responsibility</th>
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
                  <select
                    v-if="(Number(it.damage_qty) || 0) > 0"
                    :value="damageResponsibilityByItem[it.item_id] || ''"
                    @change="setDamageResponsibility(it.item_id, $event.target.value)"
                    class="w-full min-w-[140px] px-2 py-1 border rounded text-sm"
                  >
                    <option value="">— Select —</option>
                    <option value="WAREHOUSE">Warehouse packing</option>
                    <option value="DRIVER">Driver transport</option>
                    <option value="BRANCH">Branch handling</option>
                  </select>
                  <span v-else class="text-gray-400">—</span>
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
            :disabled="receiving || !canConfirmReceive || (transfer?.status === 'arrived' && !otpVerified)"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Confirm Receive
          </button>
        </div>
      </div>
    </div>

    <!-- Mark Picked / Dispatch confirm modals -->
    <div v-if="showMarkPickedConfirm" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showMarkPickedConfirm = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Mark Picked</h3>
        <p class="text-gray-600 mb-6">Confirm that all items have been picked with batch selected? Status will change to Picked.</p>
        <div class="flex justify-end gap-2">
          <button @click="showMarkPickedConfirm = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button @click="confirmMarkPicked" :disabled="picking" class="px-6 py-2 rounded-lg text-white font-semibold" style="background-color: #284b44;">Confirm</button>
        </div>
      </div>
    </div>

    <PickingItemModal
      v-if="showPickingItemModal && editPickingItem"
      :item="editPickingItem"
      :transfer-id="transfer?.id"
      :from-location-id="transfer?.from_location_id"
      :allow-remove="!transfer?.transfer_orders_id"
      @close="showPickingItemModal = false; editPickingItem = null"
      @save="onPickingSave"
      @remove="onPickingRemove"
    />

    <div v-if="showAddItemModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showAddItemModal = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto m-4">
        <div class="p-6 border-b">
          <h3 class="text-lg font-bold">Add Items to Transfer</h3>
        </div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1">Search item</label>
            <input v-model="addItemSearch" type="text" placeholder="Type name or SKU..." class="w-full px-3 py-2 border rounded-lg" @input="debouncedAddItemSearch" />
          </div>
          <div v-if="addItemResults.length" class="border rounded-lg max-h-48 overflow-y-auto">
            <button
              v-for="it in addItemResults"
              :key="it.id"
              @click="selectAddItem(it)"
              class="w-full px-4 py-2 text-left hover:bg-gray-50 flex justify-between border-b last:border-b-0"
            >
              <span>{{ it.name }} ({{ it.sku }})</span>
              <span class="text-sm text-gray-500">Available: {{ formatNum(addItemStock[it.id]?.available_qty) }}</span>
            </button>
          </div>
          <div v-if="selectedAddItem" class="border rounded-lg p-4 bg-gray-50">
            <p class="font-medium">{{ selectedAddItem.name }} ({{ selectedAddItem.sku }})</p>
            <div class="mt-2 flex items-center gap-2">
              <label class="text-sm">Qty</label>
              <input v-model.number="addItemQty" type="number" min="0.01" step="0.01" class="w-24 px-2 py-1 border rounded" />
            </div>
          </div>
        </div>
        <div class="p-6 border-t flex justify-end gap-2">
          <button @click="showAddItemModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button @click="confirmAddItem" :disabled="!selectedAddItem || !addItemQty || addItemSaving" class="px-6 py-2 rounded-lg text-white" style="background-color: #284b44;">Add</button>
        </div>
      </div>
    </div>

    <!-- Dispatch to Driver Modal -->
    <div v-if="showDispatchModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showDispatchModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Dispatch to Driver</h3>
        <p class="text-gray-600 mb-4">Select driver and vehicle. Transfer will be handed to driver. Driver must be from system users.</p>
        <div class="space-y-3 mb-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Driver <span class="text-red-500">*</span></label>
            <select v-model="logisticsForm.driver_id" required class="w-full px-3 py-2 border rounded-lg">
              <option value="">— Select Driver —</option>
              <option v-for="d in drivers" :key="d.id" :value="d.id">{{ d.name }} ({{ d.phone || d.email || '—' }})</option>
            </select>
            <p v-if="!drivers.length" class="text-amber-600 text-sm mt-1">No active drivers available. Create driver user and assign Driver role.</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Vehicle No <span class="text-red-500">*</span></label>
            <input v-model="logisticsForm.vehicle_no" type="text" placeholder="e.g. ABC-123" required class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Seal Number</label>
            <input v-model="logisticsForm.seal_number" type="text" placeholder="Optional" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Expected Arrival Time</label>
            <input v-model="logisticsForm.expected_delivery_time" type="datetime-local" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
            <textarea v-model="logisticsForm.notes" rows="2" placeholder="Optional" class="w-full px-3 py-2 border rounded-lg"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2">
          <button @click="showDispatchModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button
            @click="confirmDispatchToDriver"
            :disabled="dispatching || !logisticsForm.driver_id || !logisticsForm.vehicle_no?.trim()"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Confirm Dispatch
          </button>
        </div>
      </div>
    </div>

    <!-- Quality Inspection Modal -->
    <div v-if="showQualityModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showQualityModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">Quality Inspection</h3>
        <p class="text-gray-600 mb-4">Inspect packaging, temperature, and condition before receiving.</p>
        <div class="space-y-3 mb-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Packaging Condition <span class="text-red-500">*</span></label>
            <select v-model="qualityForm.condition_status" required class="w-full px-3 py-2 border rounded-lg">
              <option value="">— Select —</option>
              <option value="GOOD">Good</option>
              <option value="DAMAGED">Damaged</option>
              <option value="WET">Wet</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Temperature (°C)</label>
            <input v-model.number="qualityForm.temperature" type="number" step="0.1" placeholder="e.g. 4" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div class="flex items-center gap-2">
            <input v-model="qualityForm.damage_flag" type="checkbox" id="qc-damage" class="rounded" />
            <label for="qc-damage" class="text-sm font-medium text-gray-700">Damage detected</label>
          </div>
          <div class="flex items-center gap-2">
            <input v-model="qualityForm.expired_items_flag" type="checkbox" id="qc-expired" class="rounded" />
            <label for="qc-expired" class="text-sm font-medium text-gray-700">Expired items found</label>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Remarks</label>
            <textarea v-model="qualityForm.notes" rows="2" placeholder="Optional" class="w-full px-3 py-2 border rounded-lg"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2">
          <button @click="showQualityModal = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button
            @click="confirmQualityCheck"
            :disabled="dispatching || !qualityForm.condition_status"
            class="px-6 py-2 rounded-lg text-white font-semibold disabled:opacity-50"
            style="background-color: #284b44;"
          >
            Submit Inspection
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import PickingItemModal from '@/components/transfer/PickingItemModal.vue';
import DocumentFlow from '@/components/common/DocumentFlow.vue';
import {
  getStockTransferById,
  fetchStockTransferItems,
  fetchStockMapForItems,
  startPickingStockTransfer,
  updateStockTransferItemPicking,
  confirmPickingStockTransfer,
  receiveStockTransferItem,
  fetchStockTransferAudit,
  deleteStockTransfer,
  addItemToStockTransfer,
  removeItemFromStockTransfer,
  searchInventoryItems,
  fetchDrivers,
  dispatchToDriver,
  warehouseMarkInTransit,
  warehouseMarkArrived,
  qualityCheckTransfer,
  generateDeliveryOtp,
  verifyDeliveryOtp,
  fetchLogisticsHandover,
  fetchQualityChecks,
  insertTransferDamageReport
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
const showMarkPickedConfirm = ref(false);
const showDispatchModal = ref(false);
const showQualityModal = ref(false);
const showPickingItemModal = ref(false);
const showAddItemModal = ref(false);
const editPickingItem = ref(null);
const drivers = ref([]);
const logisticsForm = ref({ driver_id: '', vehicle_no: '', seal_number: '', expected_delivery_time: '', notes: '' });
const qualityForm = ref({ condition_status: '', temperature: null, damage_flag: false, expired_items_flag: false, notes: '' });
const logisticsHandover = ref(null);
const qualityChecks = ref([]);
const otpVerified = ref(false);
const generatedOtp = ref('');
const otpInput = ref('');

const transferId = computed(() => route.params.id);

const hasInsufficientStock = computed(() => {
  if (transfer.value?.status !== 'picked') return false;
  const qty = (it) => Number(it.picked_qty || it.transfer_qty) || 0;
  return items.value.some((it) => {
    const avail = stockMap.value[it.item_id]?.available_qty ?? 0;
    return qty(it) > avail;
  });
});

const hasMissingBatch = computed(() => {
  if (transfer.value?.status !== 'picking') return false;
  return items.value.some((it) => {
    const q = Number(it.transfer_qty) || 0;
    return q > 0 && (!it.batch_id || Number(it.picked_qty || 0) <= 0);
  });
});

const hasMissingBatchOnPicked = computed(() => {
  if (transfer.value?.status !== 'picked') return false;
  return items.value.some((it) => {
    const q = Number(it.picked_qty || it.transfer_qty) || 0;
    return q > 0 && !it.batch_id;
  });
});

const transferTotalValue = computed(() =>
  items.value.reduce((s, it) => s + itemTotalValue(it), 0)
);

const damageResponsibilityByItem = ref({});
const receiveRows = computed(() =>
  items.value
    .filter((it) => (Number(it.picked_qty || it.transfer_qty) || 0) > 0)
    .map((it) => ({
      ...it,
      receive_qty: Number(it.received_qty) || Number(it.picked_qty || it.transfer_qty) || 0,
      damage_qty: Number(it.damaged_qty) || 0,
      reject_qty: Number(it.rejected_qty) || 0,
      damage_responsibility: damageResponsibilityByItem.value[it.item_id] || ''
    }))
);
function setDamageResponsibility(itemId, val) {
  damageResponsibilityByItem.value = { ...damageResponsibilityByItem.value, [itemId]: val };
}

const canConfirmReceive = computed(() => {
  const hasReceive = receiveRows.value.some((it) => (it.receive_qty || 0) > 0);
  const hasDamageWithoutResponsibility = receiveRows.value.some(
    (it) => (Number(it.damage_qty) || 0) > 0 && !(damageResponsibilityByItem.value[it.item_id])
  );
  return hasReceive && !hasDamageWithoutResponsibility;
});

const hasQualityCheck = computed(() => qualityChecks.value.length > 0);

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function formatCurrency(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR', minimumFractionDigits: 2 }).format(v);
}
function itemTotalValue(it) {
  const qty = Number(it.picked_qty || it.transfer_qty) || 0;
  const cost = Number(it.unit_cost) || 0;
  return qty * cost;
}
function itemStatus(it) {
  const recv = Number(it.received_qty) || 0;
  const pick = Number(it.picked_qty || it.transfer_qty) || 0;
  if (recv >= pick && pick > 0) return 'Received';
  if (recv > 0) return 'Partial';
  if (it.batch_id && (Number(it.picked_qty) || 0) > 0) return 'Picked';
  return 'Pending';
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
    picking: 'Picking',
    picked: 'Picked',
    handed_to_driver: 'Handed to Driver',
    in_transit: 'In Transit',
    arrived: 'Arrived',
    partially_received: 'Partially Received',
    completed: 'Completed',
    cancelled: 'Cancelled'
  };
  return m[(s || '').toLowerCase()] || s;
}
function statusClass(s) {
  const m = {
    draft: 'bg-gray-100 text-gray-800',
    picking: 'bg-amber-100 text-amber-800',
    picked: 'bg-amber-100 text-amber-800',
    handed_to_driver: 'bg-indigo-100 text-indigo-800',
    in_transit: 'bg-blue-100 text-blue-800',
    arrived: 'bg-cyan-100 text-cyan-800',
    partially_received: 'bg-blue-100 text-blue-800',
    completed: 'bg-green-100 text-green-800',
    cancelled: 'bg-red-100 text-red-800'
  };
  return m[(s || '').toLowerCase()] || 'bg-gray-100 text-gray-800';
}
function formatAuditAction(a) {
  const m = {
    created: 'Created',
    picking_started: 'Picking started',
    picked: 'Picked',
    dispatched: 'Dispatched',
    handed_to_driver: 'Handed to driver',
    driver_accepted: 'Driver accepted',
    marked_in_transit: 'Marked in transit',
    arrived: 'Arrived at branch',
    quality_checked: 'Quality checked',
    received: 'Received',
    completed: 'Completed'
  };
  return m[(a || '').toLowerCase()] || a;
}
function auditDotClass(a) {
  const m = {
    created: 'bg-gray-400',
    picking_started: 'bg-amber-400',
    picked: 'bg-amber-500',
    dispatched: 'bg-blue-500',
    handed_to_driver: 'bg-indigo-500',
    driver_accepted: 'bg-indigo-600',
    marked_in_transit: 'bg-blue-600',
    arrived: 'bg-cyan-500',
    quality_checked: 'bg-teal-500',
    received: 'bg-green-500',
    completed: 'bg-green-600'
  };
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
    logisticsHandover.value = await fetchLogisticsHandover(id);
    qualityChecks.value = await fetchQualityChecks(id);
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
    batch_no: it.batch_no || it.lot_no,
    batch_expiry: it.batch_expiry || it.expiry_date,
    picked_qty: it.picked_qty,
    transfer_qty: it.transfer_qty,
    unit_cost: it.unit_cost,
    total_cost: (it.picked_qty || it.transfer_qty) * (it.unit_cost || 0)
  }));
  printStockTransfer(transfer.value, printItems);
}

async function doStartPicking() {
  if (!transfer.value?.id) return;
  picking.value = true;
  try {
    const result = await startPickingStockTransfer(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Picking started. Click each row to select batch.', 'success');
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

function doMarkPicked() {
  if (hasMissingBatch.value) {
    showNotification('All items must have batch selected', 'warning');
    return;
  }
  showMarkPickedConfirm.value = true;
}

async function confirmMarkPicked() {
  if (!transfer.value?.id) return;
  picking.value = true;
  try {
    const result = await confirmPickingStockTransfer(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Marked as Picked', 'success');
      showMarkPickedConfirm.value = false;
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

function openPickingModal(it) {
  editPickingItem.value = it;
  showPickingItemModal.value = true;
}

async function onPickingSave(payload) {
  if (!transfer.value?.id || !editPickingItem.value?.item_id) return;
  const result = await updateStockTransferItemPicking(
    transfer.value.id,
    editPickingItem.value.item_id,
    payload.batchId,
    payload.pickedQty,
    payload.damagedQty,
    payload.unitCost
  );
  if (result?.ok) {
    showNotification('Batch saved', 'success');
    showPickingItemModal.value = false;
    editPickingItem.value = null;
    await load();
  } else {
    showNotification(result?.error || 'Failed', 'error');
  }
}

async function onPickingRemove() {
  if (!transfer.value?.id || !editPickingItem.value?.item_id) return;
  const result = await removeItemFromStockTransfer(transfer.value.id, editPickingItem.value.item_id);
  if (result?.ok) {
    showNotification('Item removed', 'success');
    showPickingItemModal.value = false;
    editPickingItem.value = null;
    await load();
  } else {
    showNotification(result?.error || 'Remove failed', 'error');
  }
}

async function doDelete() {
  const { showConfirmDialog } = await import('@/utils/confirmDialog.js');
  const ok = await showConfirmDialog({ title: 'Delete Transfer', message: 'Delete this transfer permanently?', confirmText: 'Yes', type: 'danger' });
  if (!ok) return;
  const result = await deleteStockTransfer(transfer.value.id);
  if (result?.ok) {
    showNotification('Transfer deleted', 'success');
    goBack();
  } else {
    showNotification(result?.error || 'Delete failed', 'error');
  }
}

const addItemSearch = ref('');
const addItemResults = ref([]);
const selectedAddItem = ref(null);
const addItemQty = ref(1);
const addItemStock = ref({});
const addItemSaving = ref(false);
let addItemSearchTimeout = null;

async function debouncedAddItemSearch() {
  clearTimeout(addItemSearchTimeout);
  addItemSearchTimeout = setTimeout(async () => {
    const q = addItemSearch.value?.trim();
    if (!q || q.length < 2) return;

    const results = await searchInventoryItems(q, 20);
    addItemResults.value = results;
    selectedAddItem.value = null;
    if (results.length && transfer.value?.from_location_id) {
      const ids = results.map((r) => r.id);
      const stockMap = await fetchStockMapForItems(transfer.value.from_location_id, ids);
      addItemStock.value = stockMap;
    } else {
      addItemStock.value = {};
    }
  }, 300);
}

function selectAddItem(it) {
  selectedAddItem.value = it;
  addItemQty.value = 1;
}

async function confirmAddItem() {
  if (!selectedAddItem.value || !addItemQty.value || addItemQty.value <= 0 || !transfer.value?.id) return;
  addItemSaving.value = true;
  try {
    const result = await addItemToStockTransfer(transfer.value.id, selectedAddItem.value.id, addItemQty.value);
    if (result?.ok) {
      showNotification('Item added', 'success');
      showAddItemModal.value = false;
      selectedAddItem.value = null;
      addItemSearch.value = '';
      await load();
    } else {
      showNotification(result?.error || 'Add failed', 'error');
    }
  } finally {
    addItemSaving.value = false;
  }
}

async function openDispatchModal() {
  drivers.value = await fetchDrivers();
  logisticsForm.value = { driver_id: '', vehicle_no: '', seal_number: '', expected_delivery_time: '', notes: '' };
  showDispatchModal.value = true;
}
function onRefreshDrivers() {
  if (showDispatchModal.value) fetchDrivers().then(d => { drivers.value = d; });
}

async function confirmDispatchToDriver() {
  if (!transfer.value?.id || !logisticsForm.value.driver_id || !logisticsForm.value.vehicle_no?.trim()) return;
  dispatching.value = true;
  try {
    const expTime = logisticsForm.value.expected_delivery_time
      ? new Date(logisticsForm.value.expected_delivery_time).toISOString()
      : null;
    const result = await dispatchToDriver(
      transfer.value.id,
      logisticsForm.value.driver_id,
      logisticsForm.value.vehicle_no?.trim(),
      logisticsForm.value.seal_number?.trim() || null,
      expTime,
      logisticsForm.value.notes?.trim() || null,
      getCurrentUserName()
    );
    if (result?.ok) {
      showNotification('Handed to driver', 'success');
      showDispatchModal.value = false;
      logisticsForm.value = { driver_id: '', vehicle_no: '', seal_number: '', expected_delivery_time: '', notes: '' };
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

async function doMarkInTransit() {
  if (!transfer.value?.id) return;
  dispatching.value = true;
  try {
    const result = await warehouseMarkInTransit(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Marked in transit', 'success');
      await load();
    } else {
      showNotification(result?.error || 'Failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

async function doMarkArrived() {
  if (!transfer.value?.id) return;
  dispatching.value = true;
  try {
    const result = await warehouseMarkArrived(transfer.value.id, getCurrentUserName());
    if (result?.ok) {
      showNotification('Marked as arrived', 'success');
      await load();
    } else {
      showNotification(result?.error || 'Failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

async function confirmQualityCheck() {
  if (!transfer.value?.id || !qualityForm.value.condition_status) return;
  dispatching.value = true;
  try {
    const result = await qualityCheckTransfer(
      transfer.value.id,
      qualityForm.value.condition_status,
      qualityForm.value.temperature,
      qualityForm.value.damage_flag,
      qualityForm.value.expired_items_flag,
      qualityForm.value.notes?.trim() || null,
      getCurrentUserName()
    );
    if (result?.ok) {
      showNotification('Quality inspection submitted', 'success');
      showQualityModal.value = false;
      qualityForm.value = { condition_status: '', temperature: null, damage_flag: false, expired_items_flag: false, notes: '' };
      await load();
    } else {
      showNotification(result?.error || 'Failed', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

async function doGenerateOtp() {
  if (!transfer.value?.id) return;
  dispatching.value = true;
  try {
    const result = await generateDeliveryOtp(transfer.value.id);
    if (result?.ok && result?.otp_code) {
      generatedOtp.value = result.otp_code;
      showNotification('OTP generated. Share with branch manager.', 'success');
    } else {
      showNotification(result?.error || 'Failed to generate OTP', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

async function doVerifyOtp() {
  if (!transfer.value?.id || !otpInput.value) return;
  dispatching.value = true;
  try {
    const result = await verifyDeliveryOtp(transfer.value.id, otpInput.value, getCurrentUserName());
    if (result?.ok) {
      otpVerified.value = true;
      showNotification('OTP verified', 'success');
    } else {
      showNotification(result?.error || 'Invalid OTP', 'error');
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    dispatching.value = false;
  }
}

function openReceiveModal() {
  otpVerified.value = false;
  generatedOtp.value = '';
  otpInput.value = '';
  damageResponsibilityByItem.value = {};
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
      if (dam > 0) {
        const resp = damageResponsibilityByItem.value[row.item_id];
        if (resp) {
          const drResult = await insertTransferDamageReport(
            transfer.value.id,
            row.item_id,
            dam,
            resp,
            null,
            getCurrentUserName()
          );
          if (!drResult?.ok) {
            showNotification(drResult?.error || 'Damage report failed', 'warning');
          }
        }
      }
    }
    if (allOk) {
      showNotification('Items received', 'success');
      showReceiveModal.value = false;
      otpVerified.value = false;
      generatedOtp.value = '';
      otpInput.value = '';
      damageResponsibilityByItem.value = {};
      await load();
    }
  } catch (e) {
    showNotification(e?.message || 'Error', 'error');
  } finally {
    receiving.value = false;
  }
}

watch(() => route.params.id, () => load(), { immediate: false });
onMounted(() => {
  load();
  if (typeof window !== 'undefined') window.addEventListener('erp:refresh-drivers', onRefreshDrivers);
});
onUnmounted(() => {
  if (typeof window !== 'undefined') window.removeEventListener('erp:refresh-drivers', onRefreshDrivers);
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
