<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <!-- Header Section -->
    <div class="flex justify-between items-center mb-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
          <i class="fas fa-arrow-left"></i>
          <span>{{ t('inventory.grn.back') }}</span>
        </button>
        <div class="flex flex-col md:flex-row items-stretch md:items-center gap-2 md:gap-3">
          <h1 class="text-3xl font-bold text-gray-800">
            {{ t('inventory.grn.title') }} {{ getGRNDisplayNumber() }}
          </h1>
          <span 
            v-if="grn"
            :class="[
              'px-3 py-1 rounded-full text-sm font-semibold',
              getStatusClass(grn.status || grnStatus || 'draft')
            ]"
          >
            {{ formatStatus(grn.status || grnStatus || 'draft') }}
          </span>
        </div>
      </div>
      <div class="flex flex-col md:flex-row items-stretch md:items-center gap-2 md:gap-3">
        <!-- Draft Status Actions -->
        <template v-if="grnStatus === 'draft'">
          <button 
            @click="printGRN" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ t('inventory.grn.print') }}</span>
          </button>
          <button 
            @click="deleteGRNPermanently" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-trash"></i>
            <span>{{ t('inventory.grn.deletePermanently') }}</span>
          </button>
          <button 
            @click="editGRN" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-edit"></i>
            <span>{{ t('inventory.grn.edit') }}</span>
          </button>
          <button 
            @click="submitForInspection" 
            :disabled="!canSubmitForInspection"
            :class="[
              'px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold transition-all duration-300 relative overflow-hidden',
              canSubmitForInspection 
                ? 'shadow-lg hover:shadow-xl transform hover:scale-105' 
                : 'opacity-60 cursor-not-allowed'
            ]"
            :style="canSubmitForInspection 
              ? 'background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%); color: white;' 
              : 'background: linear-gradient(135deg, #9ca3af 0%, #d1d5db 50%, #9ca3af 100%); color: white;'"
            :title="canSubmitForInspection 
              ? t('inventory.grn.allItemsComplete') 
              : t('inventory.grn.completeAllEntries')"
          >
            <i :class="canSubmitForInspection ? 'fas fa-clipboard-check' : 'fas fa-lock'"></i>
            <span>{{ t('inventory.grn.submitForInspection') }}</span>
            <span v-if="!canSubmitForInspection" class="ml-2 text-xs bg-white bg-opacity-30 px-2 py-0.5 rounded font-bold">
              ({{ t('inventory.grn.incomplete') }})
            </span>
          </button>
        </template>
        
        <!-- Under Inspection Status Actions -->
        <template v-else-if="grnStatus === 'under_inspection'">
          <button 
            @click="printGRN" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ t('inventory.grn.print') }}</span>
          </button>
          <button 
            @click="rejectGRN" 
            class="px-4 py-2 bg-white border border-red-300 rounded-lg hover:bg-red-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-times"></i>
            <span>{{ t('inventory.grn.reject') }}</span>
          </button>
          <!-- Submit for GRN Approval Button (Receiver) - Show when not yet submitted -->
          <button 
            v-if="!isSubmittedForApproval"
            @click="submitForGRNApproval" 
            :disabled="!allBatchesHaveQCInspection"
            :class="[
              'px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold transition-all duration-300 relative overflow-hidden',
              allBatchesHaveQCInspection
                ? 'shadow-lg hover:shadow-xl transform hover:scale-105'
                : 'opacity-60 cursor-not-allowed'
            ]"
            :style="allBatchesHaveQCInspection
              ? 'background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%); color: white;'
              : 'background: linear-gradient(135deg, #9ca3af 0%, #d1d5db 50%, #9ca3af 100%); color: white;'"
            :title="allBatchesHaveQCInspection
              ? t('inventory.grn.allBatchesApproved')
              : t('inventory.grn.completeQCInspection')"
          >
            <i :class="allBatchesHaveQCInspection ? 'fas fa-paper-plane' : 'fas fa-lock'"></i>
            <span>{{ t('inventory.grn.submitForGRNApproval') }}</span>
            <span v-if="!allBatchesHaveQCInspection" class="ml-2 text-xs bg-white bg-opacity-30 px-2 py-0.5 rounded font-bold">
              ({{ qcInspectionProgress.pending }} {{ t('inventory.grn.pending') }})
            </span>
          </button>
          
          <!-- Approve GRN Button (QA Manager) - Show when GRN is submitted for approval -->
          <button 
            v-else-if="isSubmittedForApproval"
            @click="approveGRN" 
            :class="[
              'px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold transition-all duration-300 relative overflow-hidden shadow-lg hover:shadow-xl transform hover:scale-105'
            ]"
            :style="'background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%); color: white;'"
            :title="t('inventory.grn.grnSubmittedForApproval')"
          >
            <i class="fas fa-check-circle"></i>
            <span>{{ t('inventory.grn.approveGRN') }}</span>
          </button>
          
          <!-- Show message if batches not all approved yet -->
          <div 
            v-else
            class="px-6 py-2 bg-gray-100 border border-gray-300 rounded-lg text-gray-600 flex items-center gap-2"
          >
            <i class="fas fa-info-circle"></i>
            <span>{{ t('inventory.grn.waitingForQAInspector') }} ({{ qcInspectionProgress.pending }} {{ t('inventory.grn.pending') }})</span>
          </div>
        </template>
        
        <!-- Approved Status Actions -->
        <template v-else-if="grnStatus === 'approved'">
          <button 
            @click="printGRN" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ t('inventory.grn.print') }}</span>
          </button>
          <!-- DB-driven: show only when fn_can_create_next_document('GRN', grn_id) is true -->
          <button 
            v-if="canCreatePurchase"
            @click="createPurchasing" 
            :class="[
              'px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold transition-all duration-300 relative overflow-hidden shadow-lg hover:shadow-xl transform hover:scale-105'
            ]"
            :style="'background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%); color: white;'"
            :title="t('inventory.grn.createPurchasing')"
          >
            <i class="fas fa-shopping-cart"></i>
            <span>{{ t('inventory.grn.createPurchasing') }}</span>
          </button>
        </template>
        
        <!-- Rejected/Cancelled Status - Read Only -->
        <template v-else>
          <button 
            @click="printGRN" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ t('inventory.grn.print') }}</span>
          </button>
        </template>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="bg-white rounded-lg shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">{{ t('inventory.grn.loadingGRNDetails') }}</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-white rounded-lg shadow-md p-6">
      <div class="text-center">
        <p class="text-red-600 mb-4">{{ error }}</p>
        <button @click="goBack" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
          ← {{ t('inventory.grn.back') }}
        </button>
      </div>
    </div>

    <!-- GRN Details -->
    <div v-else-if="grn">
      <!-- GRN Information Card -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.date') }}</label>
              <p class="text-gray-900 font-medium">{{ formatDate(grn.grnDate || grn.grn_date) }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.purchaseOrders.reference') }}</label>
              <p class="text-gray-900 font-medium">{{ purchaseOrderNumber || t('common.notAvailable') }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.suppliers.title') }}</label>
              <p class="text-gray-900 font-medium">{{ formatSupplierDisplay(grn.supplier) }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.receivingLocation') }}</label>
              <p class="text-gray-900 font-medium">{{ receivingLocationDisplay }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.receivedBy') }}</label>
              <p class="text-gray-900 font-medium">
                {{ grn.received_by_name || getUuidDisplayName(grn.received_by) || getUuidDisplayName(grn.receivedBy) }}
              </p>
            </div>
          </div>
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.supplierInvoiceNumber') }}</label>
              <p class="text-gray-900 font-medium">{{ grn.supplierInvoiceNumber || grn.supplier_invoice_number || t('common.notAvailable') }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.deliveryNoteNumber') }}</label>
              <p class="text-gray-900 font-medium">{{ grn.deliveryNoteNumber || grn.delivery_note_number || t('common.notAvailable') }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.qcCheckedBy') }}</label>
              <p class="text-gray-900 font-medium">
                {{ getQCCheckedByDisplay() }}
              </p>
            </div>
            <div v-if="grnStatus === 'approved' && (grn.approvedBy || grn.approved_by)" class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.grnApprovedBy') }}</label>
              <p class="text-gray-900 font-medium" style="color: #059669; font-weight: 600;">
                {{ grn.approved_by_name || getUuidDisplayName(grn.approved_by) || getUuidDisplayName(grn.approvedBy) }}
                <span v-if="grn.approvedAt || grn.approved_at" class="text-gray-500 text-sm font-normal ml-2">
                  ({{ formatDateTime(grn.approvedAt || grn.approved_at) }})
                </span>
              </p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('inventory.grn.externalReferenceId') }}</label>
              <p class="text-gray-900 font-medium">{{ grn.externalReferenceId || grn.external_reference_id || t('common.notAvailable') }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ t('common.createdAt') }}</label>
              <p class="text-gray-900 font-medium">{{ formatDateTime(grn.createdAt || grn.created_at) }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs: Items, Batches, QC -->
      <div class="bg-white rounded-lg shadow-md">
        <div class="border-b border-gray-200">
          <nav class="flex -mb-px">
            <button
              @click.prevent.stop="switchTab('items')"
              :class="[
                'px-6 py-4 text-sm font-medium border-b-2 transition-colors cursor-pointer',
                activeTab === 'items'
                  ? 'border-[#284b44] text-[#284b44]'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              {{ t('inventory.items.items') }}
            </button>
            <button
              v-if="batchesTabUnlocked || grnStatus === 'approved'"
              @click.prevent.stop="switchTab('batches')"
              data-tab-button="batches"
              :class="[
                'px-6 py-4 text-sm font-medium border-b-2 transition-colors cursor-pointer',
                activeTab === 'batches'
                  ? 'border-[#284b44] text-[#284b44]'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              {{ t('inventory.grn.batches') }}
            </button>
            <span
              v-else-if="grnStatus !== 'approved'"
              class="px-6 py-4 text-sm font-medium text-gray-400 cursor-not-allowed"
              :title="t('inventory.grn.completeAllEntries')"
            >
              {{ t('inventory.grn.batches') }} <i class="fas fa-lock ml-1 text-xs"></i>
            </span>
            <button
              v-if="allItemsHaveBatches || grnStatus === 'approved'"
              @click.prevent.stop="switchTab('qc')"
              :class="[
                'px-6 py-4 text-sm font-medium border-b-2 transition-colors cursor-pointer',
                activeTab === 'qc'
                  ? 'border-[#284b44] text-[#284b44]'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              {{ t('inventory.grn.qcInspection') }}
            </button>
            <span
              v-else-if="grnStatus !== 'approved'"
              class="px-6 py-4 text-sm font-medium text-gray-400 cursor-not-allowed"
              :title="t('inventory.grn.completeAllEntries')"
            >
              {{ t('inventory.grn.qcInspection') }} <i class="fas fa-lock ml-1 text-xs"></i>
            </span>
          </nav>
        </div>

        <div class="p-6">
          <!-- Items Tab -->
          <div v-if="activeTab === 'items'" class="space-y-4">
            <div class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.item') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.sku') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.unit') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.orderedQty') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.receivedQty') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.packagingType') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.supplierLot') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.inspection') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-if="(grn.items || []).length === 0">
                    <td colspan="8" class="px-4 py-8 text-center text-gray-500 border border-gray-200">
                      {{ t('inventory.grn.noItemsFound') }}
                    </td>
                  </tr>
                  <tr v-for="(item, index) in grn.items" :key="index" class="hover:bg-gray-50">
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      {{ getItemName(item) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center font-mono">
                      {{ getItemSKU(item) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      {{ getItemUnit(item) || item.unit || t('common.notAvailable') }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      {{ item.orderedQuantity || item.ordered_quantity || 0 }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      <div v-if="!editingItems[index]" class="flex items-center justify-center gap-2">
                        <span>{{ item.receivedQuantity || item.received_quantity || 0 }}</span>
                      </div>
                      <div v-else class="flex flex-col items-center gap-1">
                      <input
                        v-model.number="itemEditForm[index].receivedQuantity"
                        type="number"
                          :min="0"
                          :max="itemEditForm[index]?.maxAvailable || item.orderedQuantity || item.ordered_quantity || 0"
                        step="0.01"
                          :class="[
                            'w-24 px-2 py-1 border rounded text-sm focus:outline-none focus:ring-2',
                            (itemEditForm[index]?.receivedQuantity || 0) > (itemEditForm[index]?.maxAvailable || 0) 
                              ? 'border-red-500 bg-red-50' 
                              : 'border-gray-300'
                          ]"
                        style="--tw-ring-color: #284b44;"
                        @keyup.enter="saveItemEdit(index)"
                        @keyup.esc="cancelItemEdit(index)"
                      />
                        <div v-if="itemEditForm[index]?.maxAvailable !== null && itemEditForm[index]?.maxAvailable !== undefined" class="text-xs text-gray-500">
                          {{ t('inventory.grn.max') }}: {{ itemEditForm[index].maxAvailable.toFixed(2) }}
                          <span v-if="itemEditForm[index].orderedQty" class="text-gray-400">
                            ({{ t('inventory.grn.ordered') }}: {{ itemEditForm[index].orderedQty.toFixed(2) }})
                          </span>
                        </div>
                        <div v-if="(itemEditForm[index]?.receivedQuantity || 0) > (itemEditForm[index]?.maxAvailable || 0)" class="text-xs text-red-600 font-semibold">
                          {{ t('inventory.grn.exceedsAvailable') }}
                        </div>
                      </div>
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      <div v-if="!editingItems[index]">
                        <span>{{ item.packagingType || item.packaging_type || item.packagingCondition || item.packaging_condition || t('common.notAvailable') }}</span>
                      </div>
                      <div v-else class="flex justify-center">
                        <select
                        v-model="itemEditForm[index].packagingType"
                        class="w-32 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2"
                        style="--tw-ring-color: #284b44;"
                        @keyup.enter="saveItemEdit(index)"
                        @keyup.esc="cancelItemEdit(index)"
                        >
                          <option value="">{{ t('inventory.grn.select') }}</option>
                          <option value="Good">{{ t('inventory.grn.good') }}</option>
                          <option value="Damaged">{{ t('inventory.grn.damaged') }}</option>
                        </select>
                      </div>
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      <div v-if="!editingItems[index]" class="flex items-center justify-center gap-2">
                        <span>{{ item.supplierLotNumber || item.supplier_lot_number || t('common.notAvailable') }}</span>
                        <button
                          v-if="grnStatus === 'draft' || grnStatus === 'under_inspection'"
                          @click="startEditItem(index)"
                          class="text-blue-600 hover:text-blue-800 text-xs"
                          :title="t('inventory.grn.editItemDetails')"
                        >
                          <i class="fas fa-edit"></i>
                        </button>
                      </div>
                      <div v-else class="flex items-center justify-center gap-2">
                        <input
                          v-model="itemEditForm[index].supplierLotNumber"
                          type="text"
                          :placeholder="t('inventory.grn.supplierLotNumber')"
                          class="w-32 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2"
                          style="--tw-ring-color: #284b44;"
                          @keyup.enter="saveItemEdit(index)"
                          @keyup.esc="cancelItemEdit(index)"
                        />
                        <button
                          @click="saveItemEdit(index)"
                          class="text-green-600 hover:text-green-800 text-xs"
                          :title="t('inventory.grn.save')"
                        >
                          <i class="fas fa-check"></i>
                        </button>
                        <button
                          @click="cancelItemEdit(index)"
                          class="text-red-600 hover:text-red-800 text-xs"
                          :title="t('inventory.grn.cancel')"
                        >
                          <i class="fas fa-times"></i>
                        </button>
                      </div>
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      <span :class="getInspectionClass(getItemInspectionStatus(item))">
                        {{ formatInspectionResult(getItemInspectionStatus(item)) }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <!-- Proceed Next Button - Show after physical check (when received quantities are set) -->
            <div v-if="grnStatus === 'draft' || grnStatus === 'under_inspection'" class="mt-6 flex justify-end">
              <button
                @click="proceedToBatches"
                :disabled="!canProceedToBatches"
                :class="[
                  'px-8 py-3 text-white rounded-lg font-semibold flex items-center gap-3 transition-all duration-300 shadow-lg',
                  canProceedToBatches
                    ? 'bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 transform hover:scale-105'
                    : 'bg-gray-400 cursor-not-allowed opacity-60'
                ]"
                :title="canProceedToBatches 
                  ? t('inventory.grn.allItemsComplete') 
                  : t('inventory.grn.completeAllEntries')"
              >
                <i :class="canProceedToBatches ? 'fas fa-arrow-right' : 'fas fa-lock'"></i>
                <span>{{ t('inventory.grn.proceedNext') }}</span>
              </button>
            </div>
          </div>

          <!-- Batches Tab -->
          <div v-if="activeTab === 'batches'" class="space-y-4">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-800">{{ t('inventory.grn.batchesISO22000') }}</h3>
              <button 
                v-if="grnStatus === 'draft' || grnStatus === 'under_inspection'"
                @click="openCreateBatchModal"
                class="px-4 py-2 text-white rounded-lg text-sm font-semibold flex items-center gap-2 hover:opacity-90 transition-opacity"
                style="background-color: #284b44; color: white;"
              >
                <i class="fas fa-plus"></i>
                <span>{{ t('inventory.grn.createBatch') }}</span>
              </button>
              <!-- Debug: Show status if button not visible -->
              <div v-else class="text-xs text-gray-500">
                ({{ t('inventory.grn.batchesCanOnlyBeCreated', { status: grnStatus }) }})
              </div>
            </div>
            
            <!-- Batch Creation Progress Indicator -->
            <div v-if="grnStatus === 'draft' || grnStatus === 'under_inspection'" class="bg-gradient-to-r from-blue-50 to-green-50 border-2 rounded-lg p-4 mb-4" :class="allItemsHaveBatches ? 'border-green-300' : 'border-orange-300'">
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center gap-2">
                  <i :class="allItemsHaveBatches ? 'fas fa-check-circle text-green-600' : 'fas fa-tasks text-orange-600'" class="text-xl"></i>
                  <h4 class="font-semibold text-gray-800">{{ t('inventory.grn.batchCreationProgress') }}</h4>
                </div>
                <div v-if="allItemsHaveBatches" class="text-xs bg-green-100 text-green-800 px-3 py-1 rounded-full font-semibold flex items-center gap-1">
                  <i class="fas fa-check"></i>
                  {{ t('inventory.grn.allBatchesComplete') }}
                </div>
                <div v-else class="text-xs bg-orange-100 text-orange-800 px-3 py-1 rounded-full font-semibold flex items-center gap-1">
                  <i class="fas fa-exclamation-triangle"></i>
                  {{ batchProgress.filter(p => p && !p.isComplete && p.receivedQty > 0).length }} {{ t('inventory.grn.itemsPending') }}
                </div>
              </div>
              <div class="space-y-3">
                <div v-for="progress in batchProgress" :key="progress?.itemId || 'unknown'" v-if="progress && progress.receivedQty > 0" class="bg-white rounded-lg p-3 border-2 transition-all" :class="progress.isComplete ? 'border-green-300 bg-green-50' : 'border-orange-300 bg-orange-50'">
                  <div class="flex justify-between items-center mb-2">
                    <div class="flex-1">
                      <div class="flex items-center gap-2 flex-wrap">
                        <span class="font-semibold text-gray-800">{{ progress.itemName }}</span>
                        <span class="text-xs text-gray-500 font-mono">({{ progress.itemSKU }})</span>
                        <span v-if="progress.isComplete" class="text-xs bg-green-500 text-white px-2 py-0.5 rounded-full flex items-center gap-1 font-semibold shadow-sm">
                          <i class="fas fa-check-circle"></i>
                          {{ t('inventory.grn.complete') }}
                        </span>
                        <span v-else class="text-xs bg-orange-500 text-white px-2 py-0.5 rounded-full flex items-center gap-1 font-semibold shadow-sm animate-pulse">
                          <i class="fas fa-clock"></i>
                          {{ t('inventory.grn.pending') }}
                        </span>
                      </div>
                    </div>
                    <div class="text-sm font-semibold" :class="progress.isComplete ? 'text-green-700' : 'text-orange-700'">
                      <span :class="progress.isComplete ? 'text-green-600' : 'text-orange-600'">{{ progress.totalBatchQty.toFixed(2) }}</span>
                      <span class="text-gray-400"> / </span>
                      <span>{{ progress.receivedQty.toFixed(2) }}</span>
                      <span class="text-gray-500 ml-1 text-xs">{{ getItemUnit(grn.value?.items?.find(i => (i.itemId || i.item_id) === progress.itemId)) || '' }}</span>
                    </div>
                  </div>
                  <div class="w-full bg-gray-200 rounded-full h-3 shadow-inner">
                    <div 
                      class="h-3 rounded-full transition-all duration-500 shadow-sm"
                      :class="progress.isComplete ? 'bg-gradient-to-r from-green-500 to-green-600' : 'bg-gradient-to-r from-orange-400 to-orange-500'"
                      :style="{ width: Math.min(progress.progress, 100) + '%' }"
                    ></div>
                  </div>
                  <div v-if="!progress.isComplete && progress.receivedQty > 0" class="mt-2 p-2 bg-white rounded border border-orange-200">
                    <div class="flex items-center gap-2 text-xs">
                      <i class="fas fa-exclamation-circle text-orange-600"></i>
                      <span class="text-gray-700">{{ t('common.remaining') }}:</span>
                      <span class="font-bold text-orange-600">{{ progress.remainingQty.toFixed(2) }} {{ getItemUnit(grn.value?.items?.find(i => (i.itemId || i.item_id) === progress.itemId)) || '' }}</span>
                      <span class="text-gray-500">{{ t('inventory.grn.needsBatchCreation') }}</span>
                    </div>
                  </div>
                </div>
                <div v-if="batchProgress.filter(p => p && p.receivedQty > 0).length === 0" class="text-center py-4 text-gray-500 text-sm">
                  <i class="fas fa-info-circle mr-2"></i>
                  {{ t('inventory.grn.noItemsFound') }}
                </div>
              </div>
              
              <!-- QC Inspection Progress Indicator (shown when batches are complete) -->
              <div v-if="allItemsHaveBatches && grnStatus === 'under_inspection'" class="mt-4 pt-4 border-t-2 border-gray-200">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <i :class="allBatchesHaveQCInspection ? 'fas fa-check-circle text-green-600' : 'fas fa-clipboard-check text-blue-600'" class="text-xl"></i>
                    <h4 class="font-semibold text-gray-800">QC & Inspection Progress</h4>
                  </div>
                  <div v-if="allBatchesHaveQCInspection" class="text-xs bg-green-100 text-green-800 px-3 py-1 rounded-full font-semibold flex items-center gap-1">
                    <i class="fas fa-check"></i>
                    All QC Complete - Ready to Approve
                  </div>
                  <div v-else class="text-xs bg-blue-100 text-blue-800 px-3 py-1 rounded-full font-semibold flex items-center gap-1">
                    <i class="fas fa-clock"></i>
                    {{ qcInspectionProgress.pending }} Batch(es) Pending QC
                  </div>
                </div>
                <div class="bg-white rounded-lg p-3 border border-gray-200">
                  <div class="flex items-center justify-between text-sm mb-2">
                    <span class="text-gray-700">Total Batches:</span>
                    <span class="font-semibold text-gray-900">{{ qcInspectionProgress.total }}</span>
                  </div>
                  <div class="flex items-center justify-between text-sm mb-2">
                    <span class="text-green-700">✓ Approved:</span>
                    <span class="font-semibold text-green-700">{{ qcInspectionProgress.approved }}</span>
                  </div>
                  <div class="flex items-center justify-between text-sm mb-2">
                    <span class="text-red-700">✗ Rejected:</span>
                    <span class="font-semibold text-red-700">{{ qcInspectionProgress.rejected }}</span>
                  </div>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-orange-700">⏳ Pending:</span>
                    <span class="font-semibold text-orange-700">{{ qcInspectionProgress.pending }}</span>
                  </div>
                  <div class="w-full bg-gray-200 rounded-full h-3 mt-3 shadow-inner">
                    <div 
                      class="h-3 rounded-full transition-all duration-500 shadow-sm"
                      :class="allBatchesHaveQCInspection ? 'bg-gradient-to-r from-green-500 to-green-600' : 'bg-gradient-to-r from-blue-400 to-blue-500'"
                      :style="{ width: qcInspectionProgress.total > 0 ? (qcInspectionProgress.complete / qcInspectionProgress.total) * 100 + '%' : '0%' }"
                    ></div>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
              <p class="text-sm text-blue-800 mb-2">
                <i class="fas fa-info-circle mr-2"></i>
                <strong>ISO 22000 Rule:</strong> Batch = Item + Expiry Date + GRN. Same Item + Same Expiry + Same GRN = Same Batch.
                Sum of batch quantities must equal received quantity.
              </p>
              <!-- Batch Quantity Validation Warning -->
              <div v-if="hasBatchQuantityMismatch" class="mt-2 p-2 bg-yellow-100 border border-yellow-300 rounded">
                <p class="text-xs text-yellow-800">
                  <i class="fas fa-exclamation-triangle mr-1"></i>
                  <strong>Warning:</strong> Some items have batch quantities that don't match received quantities.
                </p>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.batchId') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.item') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.expiryDate') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.batchQuantity') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('common.remaining') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.storageLocation') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.vendorBatch') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.qcStatus') }}</th>
                    <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.createdBy') }}</th>
                    <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ t('inventory.grn.actions') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-if="(grn.batches || []).length === 0">
                    <td colspan="10" class="px-4 py-8 text-center text-gray-500 border border-gray-200">
                      {{ t('inventory.grn.noBatchesCreated') }}
                    </td>
                  </tr>
                  <tr v-for="batch in grn.batches" :key="batch.id" class="hover:bg-gray-50">
                    <td class="px-4 py-3 border border-gray-200 font-mono text-sm">
                      {{ getBatchIdDisplay(batch) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ getBatchItemName(batch) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ formatDate(batch.expiryDate || batch.expiry_date) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ getBatchQuantity(batch) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ (batch.remaining_qty != null ? Number(batch.remaining_qty) : 0) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ (batch.storageLocation || batch.storage_location) || notAvailableLabel }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ (batch.vendorBatchNumber || batch.vendor_batch_number) || notAvailableLabel }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      <span :class="getQCStatusClass(batch.qcStatus || batch.qc_status)">
                        {{ formatQCStatus(batch.qcStatus || batch.qc_status) }}
                      </span>
                    </td>
                    <td class="px-4 py-3 border border-gray-200">
                      {{ getBatchCreatedByDisplay(batch) }}
                    </td>
                    <td class="px-4 py-3 border border-gray-200 text-center">
                      <button 
                        @click="viewBatchQC(batch)"
                        class="text-blue-600 hover:text-blue-800 mr-2"
                        title="View QC Details"
                      >
                        <i class="fas fa-eye"></i>
                      </button>
                      <button 
                        v-if="canShowBatchEditDelete(batch)"
                        @click="editBatch(batch)"
                        class="text-green-600 hover:text-green-800 mr-2"
                        :title="t('inventory.grn.editBatch')"
                      >
                        <i class="fas fa-edit"></i>
                      </button>
                      <button 
                        v-if="canShowBatchEditDelete(batch)"
                        @click="deleteBatch(batch)"
                        class="text-red-600 hover:text-red-800"
                        title="Delete Batch"
                      >
                        <i class="fas fa-trash"></i>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- QC & Inspection Tab - Only visible when all batches are created -->
          <div v-if="activeTab === 'qc' && allItemsHaveBatches" class="space-y-4">
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
              <p class="text-sm text-yellow-800">
                <i class="fas fa-exclamation-triangle mr-2"></i>
                <strong>QC Workflow:</strong> QA Inspector performs inspection per batch. QA Manager approves or rejects batches.
                Rejected batches are blocked from future use.
              </p>
            </div>

            <div v-if="(grn.batches || []).length === 0" class="text-center py-8 text-gray-500">
              {{ t('inventory.grn.noBatchesAvailable') }}
            </div>

            <div v-else class="space-y-4">
              <div 
                v-for="batch in grn.batches" 
                :key="batch.id"
                :data-batch-id="batch.id"
                class="bg-white border border-gray-200 rounded-lg p-4"
                :class="{
                  'border-red-300 bg-red-50': (batch.qcStatus || batch.qc_status) === 'rejected',
                  'border-green-300 bg-green-50': (batch.qcStatus || batch.qc_status) === 'approved'
                }"
              >
                <div class="flex justify-between items-start mb-4">
                  <div>
                    <h4 class="font-semibold text-gray-800">
                      Batch: {{ getBatchIdDisplay(batch) }}
                    </h4>
                    <p class="text-sm text-gray-600">
                      Item: {{ getBatchItemName(batch) }} ({{ getBatchItemSKU(batch) }}) | 
                      Expiry: {{ formatDate(batch.expiryDate || batch.expiry_date) }} | 
                      Quantity: {{ getBatchQuantity(batch) }}
                    </p>
                    <p v-if="batch.storageLocation || batch.storage_location" class="text-xs text-gray-500 mt-1">
                      Storage: {{ batch.storageLocation || batch.storage_location }}
                    </p>
                  </div>
                  <span :class="getQCStatusClass(batch.qcStatus || batch.qc_status)">
                    {{ formatQCStatus(batch.qcStatus || batch.qc_status) }}
                  </span>
                </div>

                <!-- QC Data Fields -->
                <div class="grid grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Visual Condition <span class="text-red-500">*</span>
                    </label>
                    <input 
                      v-model="batch.qcData.visualCondition"
                      :disabled="(batch.qcStatus || batch.qc_status) !== 'pending'"
                      type="text"
                      @blur="saveQCData(batch)"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg disabled:bg-gray-100 disabled:cursor-not-allowed"
                      :class="{
                        'border-red-300': (batch.qcStatus || batch.qc_status) === 'rejected',
                        'border-green-300': (batch.qcStatus || batch.qc_status) === 'approved'
                      }"
                      placeholder="Good / Damaged / etc."
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Packaging Condition <span class="text-red-500">*</span>
                    </label>
                    <input 
                      v-model="batch.qcData.packagingCondition"
                      :disabled="(batch.qcStatus || batch.qc_status) !== 'pending'"
                      type="text"
                      @blur="saveQCData(batch)"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg disabled:bg-gray-100 disabled:cursor-not-allowed"
                      :class="{
                        'border-red-300': (batch.qcStatus || batch.qc_status) === 'rejected',
                        'border-green-300': (batch.qcStatus || batch.qc_status) === 'approved'
                      }"
                      placeholder="Intact / Damaged / etc."
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Temperature (if applicable)
                    </label>
                    <input 
                      v-model="batch.qcData.temperature"
                      :disabled="(batch.qcStatus || batch.qc_status) !== 'pending'"
                      type="number"
                      step="0.1"
                      @blur="saveQCData(batch)"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg disabled:bg-gray-100 disabled:cursor-not-allowed"
                      :class="{
                        'border-red-300': (batch.qcStatus || batch.qc_status) === 'rejected',
                        'border-green-300': (batch.qcStatus || batch.qc_status) === 'approved'
                      }"
                      placeholder="°C"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Remarks</label>
                    <textarea 
                      v-model="batch.qcData.remarks"
                      :disabled="(batch.qcStatus || batch.qc_status) !== 'pending'"
                      @blur="saveQCData(batch)"
                      rows="2"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg disabled:bg-gray-100 disabled:cursor-not-allowed"
                      :class="{
                        'border-red-300': (batch.qcStatus || batch.qc_status) === 'rejected',
                        'border-green-300': (batch.qcStatus || batch.qc_status) === 'approved'
                      }"
                      placeholder="Additional notes..."
                    ></textarea>
                  </div>
                </div>

                <!-- QC Status Info -->
                <div v-if="(batch.qcStatus || batch.qc_status) !== 'pending'" class="mb-4 p-3 rounded-lg" :class="{
                  'bg-red-50 border border-red-200': (batch.qcStatus || batch.qc_status) === 'rejected',
                  'bg-green-50 border border-green-200': (batch.qcStatus || batch.qc_status) === 'approved'
                }">
                  <p class="text-sm" :class="{
                    'text-red-800': (batch.qcStatus || batch.qc_status) === 'rejected',
                    'text-green-800': (batch.qcStatus || batch.qc_status) === 'approved'
                  }">
                    <i :class="(batch.qcStatus || batch.qc_status) === 'rejected' ? 'fas fa-times-circle' : 'fas fa-check-circle'" class="mr-2"></i>
                    <strong>Status:</strong> {{ formatQCStatus(batch.qcStatus || batch.qc_status) }}
                    <span v-if="batch.qcCheckedBy || batch.qc_checked_by"> by {{ batch.qcCheckedBy || batch.qc_checked_by }}</span>
                    <span v-if="(batch.qcStatus || batch.qc_status) === 'rejected'" class="block mt-1">
                      ⚠️ This batch is blocked from future use.
                    </span>
                  </p>
                </div>

                <!-- Action Buttons -->
                <div v-if="(batch.qcStatus || batch.qc_status) === 'pending'" class="flex justify-end gap-2">
                  <button 
                    @click="rejectBatchQC(batch)"
                    class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center gap-2"
                  >
                    <i class="fas fa-times"></i>
                    <span>Reject Batch</span>
                  </button>
                  <button 
                    @click="approveBatchQC(batch)"
                    class="px-4 py-2 text-white rounded-lg flex items-center gap-2"
                    style="background-color: #284b44;"
                  >
                    <i class="fas fa-check"></i>
                    <span>Approve Batch</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- =========================================================== -->
    <!-- DOCUMENT FLOW (SAP VBFA STYLE) - Full Chain Visualization -->
    <!-- =========================================================== -->
    <DocumentFlow 
      v-if="grn?.id"
      docType="grn" 
      :docId="grn.id" 
      :currentNumber="grn.grn_number"
      :routeDocId="route.params.id"
      :linkedPrId="linkedPrId"
    />

    <!-- =========================================================== -->
    <!-- ITEM-WISE DOCUMENT FLOW (SAP EKBE STYLE) -->
    <!-- =========================================================== -->
    <ItemFlow v-if="grn?.id" :prId="linkedPrId" :poId="tracedPoId" :grnId="grn.id" />

    <!-- Edit GRN Modal -->
    <div v-if="showEditModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeEditModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">Edit GRN</h2>
          <button @click.stop="closeEditModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="saveEditGRN" @click.stop>
            <div class="space-y-4 mb-6" @click.stop>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.date') }} <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model="editForm.grnDate" 
                  type="date"
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.receivingLocation') }} <span class="text-red-500">*</span>
                </label>
                <select 
                  v-model="editForm.receivingLocation" 
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">{{ t('inventory.grn.select') }}</option>
                  <option v-for="loc in receivingLocationOptions" :key="loc" :value="loc">{{ loc }}</option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.receivedBy') }}
                  <span class="text-xs text-gray-500 ml-1">(Auto-filled with current user)</span>
                </label>
                <input 
                  :value="editForm.receivedBy || grn?.received_by_name || getUuidDisplayName(grn?.received_by)"
                  type="text"
                  readonly
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed"
                  style="pointer-events: none;"
                  placeholder="Auto-filled with current user"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.supplierInvoiceNumber') }}
                </label>
                <input 
                  v-model="editForm.supplierInvoiceNumber"
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                  placeholder="Enter supplier invoice number"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.deliveryNoteNumber') }}
                </label>
                <input 
                  v-model="editForm.deliveryNoteNumber"
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                  placeholder="Enter delivery note number"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ t('inventory.grn.externalReferenceId') }}
                </label>
                <input 
                  v-model="editForm.externalReferenceId"
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                  placeholder="Enter external reference ID"
                />
              </div>
            </div>
            
            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closeEditModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                style="pointer-events: auto;"
              >
                Cancel
              </button>
              <button 
                type="submit"
                @click.stop
                :disabled="saving"
                class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                style="background-color: #284b44; pointer-events: auto;"
              >
                {{ saving ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Create/Edit Batch Modal -->
    <div v-if="showBatchModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeBatchModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">
            {{ editingBatch ? t('inventory.grn.editBatch') : t('inventory.grn.createBatch') }}
          </h2>
          <button @click="closeBatchModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Item <span class="text-red-500">*</span>
              </label>
              <select 
                v-model="batchForm.itemId"
                required
                @change="onBatchItemChange"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              >
                <option value="">{{ t('inventory.grn.chooseItem') }}</option>
                <option 
                  v-for="item in grn.items" 
                  :key="item.itemId || item.item_id"
                  :value="item.itemId || item.item_id"
                >
                  {{ getItemName(item) }} ({{ getItemSKU(item) }})
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ t('inventory.grn.expiryDate') }} <span class="text-red-500">*</span>
              </label>
              <input 
                v-model="batchForm.expiryDate"
                type="date"
                required
                @change="checkExistingBatch"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              />
              <p v-if="existingBatchWarning" class="text-xs text-yellow-600 mt-1">
                <i class="fas fa-exclamation-triangle"></i> 
                Batch with same Item + Expiry + GRN already exists. Will use existing batch.
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ t('inventory.grn.batchQuantity') }} <span class="text-red-500">*</span>
              </label>
              <input 
                v-model.number="batchForm.batchQuantity"
                type="number"
                min="0"
                step="0.01"
                required
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              />
              <p class="text-xs mt-1" :class="{
                'text-red-600 font-semibold': getRemainingQuantity(batchForm.itemId) === 0 && batchForm.itemId,
                'text-gray-500': getRemainingQuantity(batchForm.itemId) > 0 || !batchForm.itemId
              }">
                <i v-if="getRemainingQuantity(batchForm.itemId) === 0 && batchForm.itemId" class="fas fa-exclamation-triangle mr-1"></i>
                {{ t('common.remaining') }}: {{ getRemainingQuantity(batchForm.itemId) }}
                <span v-if="batchForm.itemId" class="text-gray-400">
                  (Received: {{ getReceivedQuantityForItem(batchForm.itemId) }})
                </span>
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ t('inventory.grn.storageLocation') }} <span class="text-red-500">*</span>
              </label>
              <select 
                v-model="batchForm.storageLocation"
                required
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              >
                <option value="">{{ t('inventory.grn.select') }}</option>
                <option v-for="location in storageLocations" :key="location" :value="location">
                  {{ location }}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ t('inventory.grn.vendorBatchNumber') }}
              </label>
              <input 
                v-model="batchForm.vendorBatchNumber"
                type="text"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
                placeholder="Reference only"
              />
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-6 pt-4 border-t border-gray-200">
            <button 
              @click="closeBatchModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button 
              @click="saveBatch" 
              class="px-6 py-2 text-white rounded-lg font-semibold hover:opacity-90 transition-opacity"
              style="background-color: #284b44; color: white;"
            >
              {{ editingBatch ? 'Update' : 'Create' }} Batch
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, defineAsyncComponent } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { 
  getGRNById, 
  updateGRNInSupabase, 
  deleteGRNFromSupabase,
  saveBatchToSupabase,
  updateBatchInSupabase,
  deleteBatchFromSupabase,
  getRemainingAllocatableForItem,
  generateGRNNumber,
  loadBatchesForGRN,
  loadGRNsFromSupabase,
  getUsers
} from '@/services/supabase';
// Lazy-load to avoid "Cannot access before initialization" (circular/order dependency)
const DocumentFlow = defineAsyncComponent(() => import('@/components/common/DocumentFlow.vue'));
const ItemFlow = defineAsyncComponent(() => import('@/components/common/ItemFlow.vue'));
import { loadItemsFromSupabase } from '@/services/supabase';
import { loadPurchaseOrdersFromSupabase } from '@/services/supabase';
import { showConfirmDialog } from '@/utils/confirmDialog';
import { showNotification } from '@/utils/notifications';
import { getCurrentUserUUID, safeUUID } from '@/utils/uuidUtils';
import { useAuthStore } from '@/stores/auth';
import { useI18n } from '@/composables/useI18n';
import { useInventoryLocations } from '@/composables/useInventoryLocations';

const route = useRoute();
const { loadLocationsForGRN } = useInventoryLocations();
const router = useRouter();
const authStore = useAuthStore();
const { t, locale, isRTL, direction } = useI18n();
const currentLang = computed(() => locale.value || 'en');
// Never show translation key: use real fallback so "common.notAvailable" never appears in UI
const notAvailableLabel = computed(() => {
  const v = t('common.notAvailable');
  return (v && v !== 'common.notAvailable' && !String(v).startsWith('common.')) ? v : 'Not available';
});
const grn = ref(null);
const linkedPrId = ref(null);
const tracedPoId = ref(null);
const loading = ref(true);
const error = ref(null);
const activeTab = ref('items');
const batchesTabUnlocked = ref(false); // Track if batches tab is unlocked (only after clicking "Proceed Next" button)
const showBatchModal = ref(false);
const editingBatch = ref(null);
const inventoryItems = ref([]);
const existingBatchWarning = ref(false);
const showEditModal = ref(false);
const saving = ref(false);
const editingItems = ref({}); // Track which item is being edited
const itemEditForm = ref({}); // Store edited item values
const canCreatePurchase = ref(false); // DB-driven: fn_can_create_next_document('GRN', grn_id)

// Edit form
const editForm = ref({
  grnDate: '',
  receivingLocation: '',
  receivedBy: '',
  supplierInvoiceNumber: '',
  deliveryNoteNumber: '',
  externalReferenceId: ''
});

// Receiving location dropdown: ONLY from inventory_locations WHERE allow_grn = true (no hardcoded)
const receivingLocationOptions = ref([]);

// Batch form
const batchForm = ref({
  itemId: '',
  expiryDate: '',
  batchQuantity: 0,
  storageLocation: '',
  vendorBatchNumber: '',
  qcStatus: 'pending'
});

// Storage locations (batch): ONLY from inventory_locations (same as receiving, no hardcoded)
const storageLocations = ref([]);

// Map batch created_by UUID → user name (from users table) for display
const createdByNameMap = ref({});

// Computed
const grnStatus = computed(() => {
  if (!grn.value) return 'draft';
  
  // Get status from multiple possible fields
  let status = grn.value.status || grn.value.Status || grn.value.grnStatus || 'draft';
  
  // Normalize status to lowercase
  status = status.toLowerCase();
  
  // Normalize database status values to UI status values
  // Database stores 'pending' (valid constraint value), but UI logic uses 'under_inspection'
  if (status === 'pending') {
    status = 'under_inspection';
  }
  // Database stores 'passed' (valid constraint value), but UI logic uses 'approved'
  if (status === 'passed') {
    status = 'approved';
  }
  
  // Debug if status is still draft but GRN exists
  if (status === 'draft' && grn.value.id && grn.value.grnNumber) {
    console.warn('⚠️ GRN has number but status is draft. GRN:', grn.value.grnNumber, 'ID:', grn.value.id);
  }
  
  // Debug logging for status transitions (only log when status changes significantly)
  if (status === 'approved' || status === 'under_inspection') {
    console.log('📊 GRN Status:', {
      rawStatus: grn.value.status || grn.value.Status || grn.value.grnStatus,
      normalizedStatus: status,
      submittedForApproval: grn.value.submittedForApproval || grn.value.submitted_for_approval,
      grnId: grn.value.id
    });
  }
  
  return status;
});

// Receiving location: GRN header first, else derive from batches (first batch storage_location or unique list)
const receivingLocationDisplay = computed(() => {
  const g = grn.value;
  if (!g) return t('common.notAvailable');
  const fromGrn = g.receivingLocation || g.receiving_location;
  if (fromGrn && String(fromGrn).trim() !== '') return fromGrn.trim();
  const batches = g.batches || [];
  if (batches.length === 0) return t('common.notAvailable');
  const locs = [...new Set((batches.map(b => b.storage_location || b.storageLocation).filter(Boolean)))];
  return locs.length > 0 ? locs.join(', ') : t('common.notAvailable');
});

// Check if batch quantities match received quantities
const hasBatchQuantityMismatch = computed(() => {
  if (!grn.value || !grn.value.items || !grn.value.batches) return false;
  
  return grn.value.items.some(item => {
    const itemId = item.itemId || item.item_id;
    const receivedQty = item.receivedQuantity || item.received_quantity || 0;
    
    const batchesForItem = grn.value.batches.filter(b => 
      (b.itemId || b.item_id) === itemId
    );
    
    const totalBatchQty = batchesForItem.reduce((sum, b) => 
      sum + getBatchQuantity(b), 0
    );
    
    return Math.abs(totalBatchQty - receivedQty) > 0.01; // Allow small floating point differences
  });
});

// Check if GRN is submitted for approval
const isSubmittedForApproval = computed(() => {
  if (!grn.value) return false;
  const isSubmitted = !!(grn.value.submittedForApproval || grn.value.submitted_for_approval);
  
  // Debug logging
  if (isSubmitted) {
    console.log('✅ GRN is submitted for approval:', {
      submittedForApproval: grn.value.submittedForApproval,
      submitted_for_approval: grn.value.submitted_for_approval,
      status: grn.value.status,
      grnId: grn.value.id
    });
  }
  
  return isSubmitted;
});

// Check if all items have batches created (for Submit For Inspection button)
const allItemsHaveBatches = computed(() => {
  if (!grn.value || !grn.value.items || grn.value.items.length === 0) return false;
  if (!grn.value.batches || grn.value.batches.length === 0) return false;
  
  // Check each item has at least one batch and batch quantities match received quantities
  return grn.value.items.every(item => {
    const itemId = item.itemId || item.item_id;
    const receivedQty = item.receivedQuantity || item.received_quantity || 0;
    
    if (receivedQty <= 0) return true; // Skip items with 0 received quantity
    
    const batchesForItem = grn.value.batches.filter(b => 
      (b.itemId || b.item_id) === itemId
    );
    
    if (batchesForItem.length === 0) return false; // No batches for this item
    
    const totalBatchQty = batchesForItem.reduce((sum, b) => 
      sum + getBatchQuantity(b), 0
    );
    
    // Batch quantity should match received quantity (allow small floating point differences)
    return Math.abs(totalBatchQty - receivedQty) <= 0.01;
  });
});

// Check if all batches have QC inspection completed (for Approve GRN button)
const allBatchesHaveQCInspection = computed(() => {
  if (!grn.value || !grn.value.batches || grn.value.batches.length === 0) return false;
  
  // All batches must have QC status of 'approved' or 'rejected' (not 'pending')
  // Rejected batches are allowed - they're blocked from use but inspection is complete
  return grn.value.batches.every(batch => {
    const qcStatus = (batch.qcStatus || batch.qc_status || 'pending').toLowerCase();
    return qcStatus === 'approved' || qcStatus === 'rejected';
  });
});

// Get QC inspection progress for display
const qcInspectionProgress = computed(() => {
  if (!grn.value || !grn.value.batches || grn.value.batches.length === 0) {
    return { total: 0, pending: 0, approved: 0, rejected: 0, complete: 0 };
  }
  
  let pending = 0;
  let approved = 0;
  let rejected = 0;
  
  grn.value.batches.forEach(batch => {
    const qcStatus = (batch.qcStatus || batch.qc_status || 'pending').toLowerCase();
    if (qcStatus === 'pending') {
      pending++;
    } else if (qcStatus === 'approved') {
      approved++;
    } else if (qcStatus === 'rejected') {
      rejected++;
    }
  });
  
  const total = grn.value.batches.length;
  const complete = approved + rejected; // Both approved and rejected are considered "complete" inspections
  
  return { total, pending, approved, rejected, complete };
});

// Get batch creation progress for each item (for display)
const batchProgress = computed(() => {
  if (!grn.value || !grn.value.items || !Array.isArray(grn.value.items)) return [];
  
  return grn.value.items.map(item => {
    if (!item) return null;
    
    const itemId = item.itemId || item.item_id;
    const receivedQty = parseFloat(item.receivedQuantity || item.received_quantity || 0);
    
    const batchesForItem = (grn.value.batches || []).filter(b => {
      if (!b) return false;
      return (b.itemId || b.item_id) === itemId;
    });
    
    const totalBatchQty = batchesForItem.reduce((sum, b) => {
      if (!b) return sum;
      return sum + getBatchQuantity(b);
    }, 0);
    
    const remainingQty = Math.max(0, receivedQty - totalBatchQty);
    const progress = receivedQty > 0 ? (totalBatchQty / receivedQty) * 100 : 0;
    
    return {
      itemId,
      itemName: getItemName(item) || t('inventory.grn.unknownItem'),
      itemSKU: getItemSKU(item) || t('common.notAvailable'),
      receivedQty,
      totalBatchQty,
      remainingQty,
      progress,
      hasBatches: batchesForItem.length > 0,
      isComplete: Math.abs(totalBatchQty - receivedQty) <= 0.01
    };
  }).filter(p => p !== null);
});

// Methods
const loadGRN = async () => {
  loading.value = true;
  error.value = null;
  linkedPrId.value = null;
  tracedPoId.value = null;
  try {
    // Priority 1: Check if we're on a GRN detail route and get ID from params
    let grnId = null;
    const currentPath = route.path || '';
    
    // If we're on /grn-detail/:id route, get ID from params
    if (currentPath.includes('/grn-detail/')) {
      grnId = route.params.id;
    }
    
    // Priority 2: Get ID from query string (for grn-detail?id=xxx format)
    if (!grnId) {
      grnId = route.query.id;
    }
    
    // Priority 3: Try to get from window.currentView
    if (!grnId) {
      const currentView = window.currentView || '';
      console.log('🔍 Current view:', currentView);
      const match = currentView.match(/grn-detail[?&]id=([^&]+)/);
      if (match && match[1]) {
        grnId = match[1];
      }
    }
    
    // Debug: Log the ID we're trying to use
    console.log('🔍 Loading GRN - Route path:', currentPath, 'Route query.id:', route.query.id, 'Route params.id:', route.params.id, 'Final GRN ID:', grnId);
    
    // Validate that the ID looks like a GRN ID (starts with 'grn_' or similar)
    if (grnId && (grnId.startsWith('to-') || grnId.startsWith('po-'))) {
      console.warn('⚠️ ID looks like a Transfer Order or Purchase Order ID, not a GRN ID:', grnId);
      // Don't use it, try to find GRN ID from currentView instead
      const currentView = window.currentView || '';
      const match = currentView.match(/grn-detail[?&]id=([^&]+)/);
      if (match && match[1] && !match[1].startsWith('to-') && !match[1].startsWith('po-')) {
        grnId = match[1];
        console.log('✅ Found valid GRN ID from currentView:', grnId);
      } else {
        grnId = null;
      }
    }
    
    if (!grnId) {
      console.error('❌ GRN ID not found in route or currentView');
        error.value = 'GRN ID not found';
        loading.value = false;
        return;
      }
      
    console.log('🔍 Attempting to load GRN with ID:', grnId);
    
    const result = await getGRNById(grnId);
      if (result && result.success && result.data) {
        grn.value = result.data;
      // Load user display names (received_by, approved_by, batch created_by) so UUIDs are not shown
      await loadCreatedByNameMap(grn.value.batches || [], grn.value);
      
      // Fetch PO number when GRN is loaded
      await fetchPurchaseOrderNumber();
      
      // Trace back to PR for DocumentFlow (GRN→PO→PR)
      try {
        let poId = grn.value.purchaseOrderId || grn.value.purchase_order_id;
        if (!poId && grn.value.purchase_order_number) {
          const { supabaseClient } = await import('@/services/supabase.js');
          const { data: poRow } = await supabaseClient.from('purchase_orders')
            .select('id').eq('po_number', (grn.value.purchase_order_number || '').trim()).maybeSingle();
          if (poRow?.id) poId = poRow.id;
        }
        if (poId) {
          tracedPoId.value = poId;
          const { supabaseClient } = await import('@/services/supabase.js');
          const poIdNum = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
          const { data: linkRow } = await supabaseClient.from('pr_po_linkage')
            .select('pr_id').eq('po_id', poIdNum).limit(1).maybeSingle();
          if (linkRow?.pr_id) linkedPrId.value = linkRow.pr_id;
        }
      } catch (e) { console.warn('Trace PR from GRN:', e); }
      
      // Ensure status is properly set (don't default to draft if status exists)
      if (!grn.value.status && grn.value.id) {
        console.warn('⚠️ GRN loaded but status is missing. ID:', grn.value.id);
      }
      
      // CRITICAL: Ensure items array exists and is populated
      if (!grn.value.items || grn.value.items.length === 0) {
        console.warn('⚠️ GRN has no items! GRN ID:', grnId);
        grn.value.items = [];
      } else {
        console.log('✅ GRN has', grn.value.items.length, 'items');
      }
        
        // Ensure items have full item objects with storageUnit from database
        // Load inventory items first if not already loaded
        if (inventoryItems.value.length === 0) {
          await loadInventoryItems();
        }
        
        if (grn.value.items && grn.value.items.length > 0) {
          grn.value.items = grn.value.items.map(grnItem => {
            const itemId = grnItem.itemId || grnItem.item_id;
            console.log('🔍 Processing GRN item:', {
              itemId: itemId,
              itemName: grnItem.item_name || grnItem.itemName,
              itemSku: grnItem.item_code || grnItem.itemCode,
              hasItemObject: !!grnItem.item
            });
            
            // If item relationship didn't load, try to load it manually
            if (itemId && !grnItem.item) {
              const fullItem = inventoryItems.value.find(i => i.id === itemId);
              if (fullItem) {
                grnItem.item = fullItem;
                console.log('✅ Loaded item relationship for:', fullItem.name);
              } else {
                console.warn('⚠️ Item not found in inventoryItems for ID:', itemId);
              }
            }
            
            // Ensure item object has all necessary fields
            if (itemId && (!grnItem.item || !grnItem.item.storageUnit)) {
              const fullItem = inventoryItems.value.find(i => i.id === itemId);
              if (fullItem) {
                grnItem.item = {
                  ...grnItem.item,
                  ...fullItem,
                  storageUnit: fullItem.storageUnit || fullItem.storage_unit,
                  storage_unit: fullItem.storageUnit || fullItem.storage_unit
                };
              }
            }
            
            // If item relationship still not loaded, create a minimal item object from saved data
            if (!grnItem.item && (grnItem.item_name || grnItem.item_code)) {
              grnItem.item = {
                id: itemId,
                name: grnItem.item_name || grnItem.itemName || 'N/A',
                sku: grnItem.item_code || grnItem.itemCode || 'N/A',
                storageUnit: grnItem.unit_of_measure || grnItem.unit || 'Pcs',
                storage_unit: grnItem.unit_of_measure || grnItem.unit || 'Pcs'
              };
              console.log('✅ Created minimal item object from saved data:', grnItem.item);
            }
            
            return grnItem;
          });
        }
        
        // Load batches separately if not included
        if (!grn.value.batches || grn.value.batches.length === 0) {
        await loadBatchesForGRNLocal(grnId);
        }
        // Ensure batches array exists
        if (!grn.value.batches) {
          grn.value.batches = [];
        }
        // ERP Document Closure: Check if Purchasing exists for this GRN (hide Create Purchasing if yes)
        try {
          const { canCreateNextDocument } = await import('@/services/erpViews.js');
          canCreatePurchase.value = await canCreateNextDocument('GRN', grnId);
          console.log('RPC fn_can_create_next_document', { docType: 'GRN', grnId, result: canCreatePurchase.value });
        } catch (e) {
          console.warn('canCreateNextDocument:', e);
          canCreatePurchase.value = false;
        }

        // Initialize QC data for batches
        grn.value.batches.forEach(batch => {
          if (!batch.qcData) {
            batch.qcData = {
              visualCondition: batch.qcData?.visualCondition || '',
              packagingCondition: batch.qcData?.packagingCondition || '',
              temperature: batch.qcData?.temperature || '',
              remarks: batch.qcData?.remarks || ''
            };
          } else {
            // Ensure all QC data fields exist
            batch.qcData = {
              visualCondition: batch.qcData.visualCondition || '',
              packagingCondition: batch.qcData.packagingCondition || '',
              temperature: batch.qcData.temperature || '',
              remarks: batch.qcData.remarks || ''
            };
          }
        });
      } else {
      console.error('❌ GRN not found or load failed. Result:', result);
        error.value = result?.success === false ? 'GRN not found' : 'Failed to load GRN data. Please refresh the page.';
    }
  } catch (err) {
    console.error('❌ Error loading GRN:', err);
    error.value = 'Error loading GRN: ' + (err.message || 'Unknown error');
  } finally {
    loading.value = false;
  }
};

// Tab switching function
const switchTab = (tab) => {
  // Allow Batches tab when unlocked OR when GRN is approved (view-only mode)
  if (tab === 'batches' && !batchesTabUnlocked.value && grnStatus.value !== 'approved') {
    showNotification('Please complete all item entries and click "Proceed Next → Create Batches" to unlock the Batches tab.', 'warning');
    return;
  }
  
  // Allow QC tab when batches complete OR when GRN approved (view-only mode)
  if (tab === 'qc' && !allItemsHaveBatches.value && grnStatus.value !== 'approved') {
    showNotification('Please complete batch creation for all items before accessing QC & Inspection.', 'warning');
    return;
  }
  
  // Directly set the active tab
  activeTab.value = tab;
  console.log('Tab switched to:', tab, 'Active tab value:', activeTab.value);
  
  // Force Vue to update by triggering a reactive update
  nextTick(() => {
    console.log('After nextTick - Active tab:', activeTab.value);
  });
};

// Check if user can proceed to batches (all items must have complete entries)
const canProceedToBatches = computed(() => {
  if (!grn.value || !grn.value.items || grn.value.items.length === 0) return false;
  
  // All items must have complete entries:
  // 1. Received quantity > 0
  // 2. Packaging Type filled (not empty/N/A/Select...) - check both packagingType and packaging_condition
  // 3. Supplier Lot Number filled (not empty/N/A)
  return grn.value.items.every(item => {
    const receivedQty = parseFloat(item.receivedQuantity || item.received_quantity || 0);
    
    // Check packaging type from multiple possible sources
    const packagingType = (
      item.packagingType || 
      item.packaging_type || 
      item.packagingCondition || 
      item.packaging_condition || 
      ''
    ).trim();
    
    // Check supplier lot number
    const supplierLot = (item.supplierLotNumber || item.supplier_lot_number || '').trim();
    
    // All fields must be filled
    const hasReceivedQty = receivedQty > 0;
    const hasPackagingType = packagingType !== '' && 
           packagingType.toLowerCase() !== 'n/a' &&
                             packagingType.toLowerCase() !== 'select...';
    const hasSupplierLot = supplierLot !== '' && 
           supplierLot.toLowerCase() !== 'n/a';
    
    return hasReceivedQty && hasPackagingType && hasSupplierLot;
  });
});

// Check if user can submit for inspection (both Items and Batches must be complete)
const canSubmitForInspection = computed(() => {
  // Must have complete item entries AND all batches created
  return canProceedToBatches.value && allItemsHaveBatches.value;
});

// Proceed to batches tab after physical check
const proceedToBatches = async () => {
  try {
  if (!canProceedToBatches.value) {
      // Check which fields are missing
      const incompleteItems = [];
      grn.value.items.forEach((item, index) => {
        const receivedQty = parseFloat(item.receivedQuantity || item.received_quantity || 0);
        
        // Check packaging type from multiple sources
        const packagingType = (
          item.packagingType || 
          item.packaging_type || 
          item.packagingCondition || 
          item.packaging_condition || 
          ''
        ).trim();
        
        const supplierLot = (item.supplierLotNumber || item.supplier_lot_number || '').trim();
        const itemName = getItemName(item);
        
        const missingFields = [];
        if (receivedQty <= 0) missingFields.push('Received Qty');
        if (!packagingType || packagingType.toLowerCase() === 'n/a' || packagingType.toLowerCase() === 'select...') {
          missingFields.push('Packaging Type');
        }
        if (!supplierLot || supplierLot.toLowerCase() === 'n/a') {
          missingFields.push('Supplier Lot');
        }
        
        if (missingFields.length > 0) {
          incompleteItems.push(`${itemName}: ${missingFields.join(', ')}`);
        }
      });
      
      const message = incompleteItems.length > 0 
        ? `Please complete all entries for:\n${incompleteItems.join('\n')}`
        : 'Please complete all entries (Received Qty, Packaging Type, Supplier Lot) for all items before proceeding to batch creation.';
      
      showNotification(message, 'warning', 6000);
    return;
  }
  
    // CRITICAL: Ensure all data is saved to Supabase before proceeding
    console.log('💾 Saving all GRN items to Supabase before proceeding to batches...');
  
    // Ensure grn and items are loaded
    if (!grn.value || !grn.value.items || grn.value.items.length === 0) {
      showNotification('GRN data is not loaded. Please refresh the page.', 'error');
      return;
    }
    
    // Save all items to Supabase to ensure data persistence
    const result = await updateGRNInSupabase(grn.value.id, {
      items: grn.value.items,
      receivedBy: grn.value.receivedBy || grn.value.received_by,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID()
    });
    
    if (!result.success) {
      console.error('❌ Error saving GRN items to Supabase:', result.error);
      showNotification('Error saving data to database. Please try again.', 'error');
      return;
    }
    
    console.log('✅ All GRN items saved to Supabase successfully');
    
    // Reload GRN to get latest data from database
    await loadGRN();
    
    // Unlock the batches tab first
    batchesTabUnlocked.value = true;
    
    // Wait for Vue to update the DOM
    await nextTick();
    
    // Switch to batches tab using the switchTab function
  switchTab('batches');
    
    // Wait for Vue to update the DOM again
    await nextTick();
    
    // Find the batches tab button and ensure it's visually active
    const batchesTabButton = document.querySelector('[data-tab-button="batches"]');
    
    if (batchesTabButton) {
      // Scroll to the tab button to ensure it's visible
      window.setTimeout(() => {
        batchesTabButton.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }, 100);
    }
    
    // Scroll to the batches content area after a short delay
    window.setTimeout(() => {
      const batchesContent = document.querySelector('.bg-white.rounded-lg.shadow-md');
      if (batchesContent) {
        batchesContent.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 300);
  
  // Show helpful message
    showNotification('Batches tab unlocked! Now create batches for all received items. All items must have complete batches before submitting for inspection.', 'info', 5000);
  } catch (error) {
    console.error('Error in proceedToBatches:', error);
    // Unlock the batches tab even if there's an error
    batchesTabUnlocked.value = true;
    // Try to switch tab anyway
    await nextTick();
    switchTab('batches');
    showNotification('Batches tab unlocked. Please create batches for all received items.', 'info', 5000);
  }
};

const loadInventoryItems = async () => {
  try {
    const items = await loadItemsFromSupabase();
    inventoryItems.value = items.filter(i => !i.deleted);
    
    // After loading items, enrich GRN items with unit data if GRN is already loaded
    if (grn.value && grn.value.items) {
      grn.value.items = grn.value.items.map(grnItem => {
        const itemId = grnItem.itemId || grnItem.item_id;
        if (itemId) {
          const fullItem = inventoryItems.value.find(i => i.id === itemId);
          if (fullItem) {
            grnItem.item = {
              ...grnItem.item,
              ...fullItem,
              storageUnit: fullItem.storageUnit || fullItem.storage_unit,
              storage_unit: fullItem.storageUnit || fullItem.storage_unit
            };
          }
        }
        return grnItem;
      });
    }
  } catch (error) {
    console.error('Error loading inventory items:', error);
  }
};

// Load batches for GRN (separate function to ensure batches are loaded)
const loadBatchesForGRNLocal = async (grnId) => {
  try {
    const batches = await loadBatchesForGRN(grnId);
    if (grn.value && batches) {
      grn.value.batches = batches;
      await loadCreatedByNameMap(batches, grn.value);
    }
  } catch (error) {
    console.error('Error loading batches:', error);
    if (grn.value) {
      grn.value.batches = [];
    }
  }
};

// Map UUID → users.full_name/name for display (batches.created_by, grn.received_by, grn.approved_by)
const loadCreatedByNameMap = async (batches, grnData) => {
  const batchIds = (batches || []).map(b => b.created_by ?? b.createdBy).filter(Boolean);
  const grnIds = grnData ? [
    grnData.received_by,
    grnData.approved_by,
    grnData.submitted_for_approval_by
  ].filter(Boolean) : [];
  const ids = [...new Set([...batchIds, ...grnIds])];
  if (ids.length === 0) {
    createdByNameMap.value = {};
    return;
  }
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    if (!supabaseClient) return;
    const { data } = await supabaseClient.from('users').select('id, name, full_name, email').in('id', ids);
    const map = {};
    (data || []).forEach((r) => {
      map[r.id] = (r.full_name && String(r.full_name).trim()) || (r.name && String(r.name).trim()) || (r.email && String(r.email).split('@')[0]) || null;
    });
    createdByNameMap.value = map;
  } catch (e) {
    console.warn('loadCreatedByNameMap:', e);
    createdByNameMap.value = {};
  }
};

const goBack = () => {
  router.push('/homeportal/grns');
};

const formatDate = (date) => {
  if (!date) return 'N/A';
  return new Date(date).toLocaleDateString('en-GB');
};

const formatDateTime = (date) => {
  if (!date) return 'N/A';
  return new Date(date).toLocaleString('en-GB');
};

const formatSupplierDisplay = (supplier) => {
  if (!supplier) return 'N/A';
  // If supplier is an object, extract name
  if (typeof supplier === 'object') {
    return supplier.name || supplier.nameLocalized || 'N/A';
  }
  // If supplier is a string, return as is
  return supplier;
};

// Purchase Order Number - computed property that fetches PO number from database
const purchaseOrderNumber = ref('N/A');

// Function to fetch PO number from database
const fetchPurchaseOrderNumber = async () => {
  if (!grn.value) {
    purchaseOrderNumber.value = 'N/A';
    return;
  }
  
  // Priority 1: Check if purchase_order_number is directly stored
  if (grn.value.purchase_order_number) {
    purchaseOrderNumber.value = grn.value.purchase_order_number;
    return;
  }
  
  // Priority 2: Check purchase_order_reference field
  if (grn.value.purchaseOrderReference || grn.value.purchase_order_reference) {
    const poRef = grn.value.purchaseOrderReference || grn.value.purchase_order_reference;
    if (typeof poRef === 'object') {
      purchaseOrderNumber.value = poRef.poNumber || poRef.po_number || 'N/A';
    } else {
      purchaseOrderNumber.value = poRef;
    }
    return;
  }
  
  // Priority 3: If purchase_order_id exists, fetch PO number from database
  const poId = grn.value.purchaseOrderId || grn.value.purchase_order_id;
  if (poId) {
    try {
      const { getPurchaseOrderById } = await import('@/services/supabase');
      const result = await getPurchaseOrderById(poId);
      if (result.success && result.data) {
        const poNumber = result.data.poNumber || result.data.po_number;
        if (poNumber && !poNumber.startsWith('DRAFT-')) {
          purchaseOrderNumber.value = poNumber;
          return;
        }
      }
    } catch (error) {
      console.warn('⚠️ Error fetching PO number:', error);
  }
  }
  
  purchaseOrderNumber.value = 'N/A';
};

// Legacy function for backward compatibility (now just returns the ref value)
const formatPurchaseOrderReference = (grn) => {
  return purchaseOrderNumber.value;
};

// Function to get GRN display number based on status
const getGRNDisplayNumber = () => {
  if (!grn.value) return `(${t('status.draft')})`;
  
  const status = (grn.value.status || '').toLowerCase();
  const grnNum = grn.value.grnNumber || grn.value.grn_number;
  
  // Draft status: Show only "Draft", no number
  if (status === 'draft') {
    return `(${t('status.draft')})`;
  }
  
  // If GRN number exists and doesn't start with "DRAFT-", show it
  if (grnNum && grnNum !== '' && !grnNum.startsWith('DRAFT-')) {
    return `(${grnNum})`;
  }
  
  // Otherwise show status
  return `(${formatStatus(grn.value.status)})`;
};

const formatStatus = (status) => {
  if (!status) return '';
  
  // Normalize status values
  const normalizedStatus = status.toLowerCase();
  
  // Map statuses to translation keys
  const statusKeyMap = {
    'draft': 'status.draft',
    'pending': 'status.under_inspection', // Map 'pending' to 'Under Inspection' for display
    'under_inspection': 'status.under_inspection',
    'approved': 'status.approved',
    'passed': 'status.approved', // Database status - map to 'Approved' for display
    'rejected': 'status.rejected',
    'hold': 'status.hold',
    'conditional': 'status.conditional'
  };
  
  const translationKey = statusKeyMap[normalizedStatus];
  if (translationKey) {
    const translated = t(translationKey);
    // If translation returns the key (missing translation), use fallback
    if (translated === translationKey) {
      return status;
    }
    return translated;
  }
  
  return status;
};

const getStatusClass = (status) => {
  const classMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'pending': 'bg-yellow-100 text-yellow-800', // Map 'pending' to yellow for 'Under Inspection'
    'under_inspection': 'bg-yellow-100 text-yellow-800', // Keep for backward compatibility
    'approved': 'bg-green-100 text-green-800',
    'rejected': 'bg-red-100 text-red-800',
    'passed': 'bg-green-100 text-green-800',
    'hold': 'bg-orange-100 text-orange-800',
    'conditional': 'bg-blue-100 text-blue-800'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800';
};

const getItemName = (item) => {
  if (!item || typeof item !== 'object') return t('common.notAvailable');
  
  // Priority 1: Item relationship from database
  if (item.item && item.item.name) {
    return item.item.name;
  }
  
  // Priority 2: Saved item_name from GRN item record
  if (item.item_name) {
    return item.item_name;
  }
  
  // Priority 3: itemName (camelCase)
  if (item.itemName) {
    return item.itemName;
  }
  
  // Priority 4: Try to find in inventoryItems by itemId
  const itemId = item.itemId || item.item_id;
  if (itemId) {
    const invItem = inventoryItems.value.find(i => i.id === itemId);
    if (invItem && invItem.name) {
      return invItem.name;
  }
  }
  
  return 'N/A';
};

const getItemSKU = (item) => {
  if (!item || typeof item !== 'object') return t('common.notAvailable');
  
  // Priority 1: Item relationship from database
  if (item.item && item.item.sku) {
    return item.item.sku;
  }
  
  // Priority 2: Saved item_code from GRN item record
  if (item.item_code) {
    return item.item_code;
  }
  
  // Priority 3: itemCode (camelCase)
  if (item.itemCode) {
    return item.itemCode;
  }
  
  // Priority 4: Try to find in inventoryItems by itemId
  const itemId = item.itemId || item.item_id;
  if (itemId) {
    const invItem = inventoryItems.value.find(i => i.id === itemId);
    if (invItem && invItem.sku) {
      return invItem.sku;
  }
  }
  
  return 'N/A';
};

// Get item unit from database - ALWAYS use database value, never hardcode
const getItemUnit = (item) => {
  // If item has nested item object (from GRN items)
  if (typeof item === 'object' && item.item) {
    const unit = item.item.storageUnit || item.item.storage_unit || item.item.ingredientUnit || item.item.ingredient_unit;
    if (unit) return unit;
    // If still not found, try to find in inventoryItems
    const itemId = item.itemId || item.item_id || item.item.id;
    if (itemId) {
      const invItem = inventoryItems.value.find(i => i.id === itemId);
      if (invItem) {
        return invItem.storageUnit || invItem.storage_unit || invItem.ingredientUnit || invItem.ingredient_unit || '';
      }
    }
  }
  
  // If item has itemId directly
  if (typeof item === 'object' && item.itemId) {
    const invItem = inventoryItems.value.find(i => i.id === item.itemId);
    if (invItem) {
      return invItem.storageUnit || invItem.storage_unit || invItem.ingredientUnit || invItem.ingredient_unit || '';
    }
  }
  
  // If item is the inventory item itself
  if (typeof item === 'object' && (item.storageUnit || item.storage_unit || item.ingredientUnit || item.ingredient_unit)) {
    return item.storageUnit || item.storage_unit || item.ingredientUnit || item.ingredient_unit || '';
  }
  
  // Last resort: return empty string (don't default to 'Pcs' - let database value show)
  return '';
};

const getBatchItemName = (batch) => {
  const na = safeNotAvailable();
  if (batch?.item) return batch.item.name || na;
  if (batch?.itemId || batch?.item_id) {
    const invItem = inventoryItems.value.find(i => i.id === (batch.itemId || batch.item_id));
    return invItem?.name || na;
  }
  return na;
};

const getBatchItemSKU = (batch) => {
  const na = safeNotAvailable();
  if (batch?.item) return batch.item.sku || na;
  if (batch?.itemId || batch?.item_id) {
    const invItem = inventoryItems.value.find(i => i.id === (batch.itemId || batch.item_id));
    return invItem?.sku || na;
  }
  return na;
};

/** Batch quantity: use batches.qty_received (view exposes as quantity). Single source for display/sum. */
const getBatchQuantity = (batch) => {
  if (!batch) return 0;
  const q = batch.qty_received ?? batch.batchQuantity ?? batch.batch_quantity ?? batch.quantity;
  return Number(q) || 0;
};

/** Never show i18n key in UI: return real fallback. */
const safeNotAvailable = () => {
  const v = t('common.notAvailable');
  return (v && v !== 'common.notAvailable' && !String(v).startsWith('common.')) ? v : 'Not available';
};

/** Resolve UUID to name for display (uses createdByNameMap). */
const getUuidDisplayName = (uuidOrName) => {
  if (!uuidOrName) return t('common.notAvailable');
  const map = createdByNameMap.value;
  const name = map[uuidOrName];
  if (name) return name;
  return safeUUID(uuidOrName) ? t('common.notAvailable') : uuidOrName;
};

/** created_by is UUID from batches; prefer DB created_by_name (view), then map, then fallback. */
const getBatchCreatedByDisplay = (batch) => {
  const fallback = safeNotAvailable();
  if (!batch) return fallback;
  const fromDb = batch.created_by_name ?? batch.createdByName;
  if (fromDb && String(fromDb).trim()) return fromDb.trim();
  const uid = batch.created_by ?? batch.createdBy;
  if (!uid) return fallback;
  const name = createdByNameMap.value[uid];
  return name || fallback;
};

/** Edit/Delete visible when GRN is draft or under_inspection AND batch QC is pending (case-insensitive). */
const canShowBatchEditDelete = (batch) => {
  const status = String(grnStatus.value || '').toLowerCase();
  const qc = String(batch?.qcStatus ?? batch?.qc_status ?? 'pending').toLowerCase();
  return (status === 'draft' || status === 'under_inspection') && qc === 'pending';
};

const saveQCData = async (batch) => {
  // Auto-save QC data as user types (only for pending batches)
  if ((batch.qcStatus || batch.qc_status) !== 'pending') {
    return;
  }
  
  try {
    const result = await updateBatchInSupabase(batch.id, {
      qcData: batch.qcData,
      updated_at: new Date().toISOString()
    });
    
    if (!result.success) {
      console.error('Error auto-saving QC data:', result.error);
    }
  } catch (error) {
    console.error('Error saving QC data:', error);
  }
};

// Get inspection status based on batch QC status (ISO 22000 logic)
const getItemInspectionStatus = (item) => {
  if (!grn.value || !grn.value.batches || !item) return '';
  
  const itemId = item.itemId || item.item_id;
  if (!itemId) return '';
  
  // Find all batches for this item
  const batchesForItem = grn.value.batches.filter(b => {
    const batchItemId = b.itemId || b.item_id;
    return batchItemId === itemId;
  });
  
  // If no batches exist, return pending
  if (batchesForItem.length === 0) {
    return '';
  }
  
  // Check QC status of all batches
  const hasRejected = batchesForItem.some(b => {
    const qcStatus = b.qcStatus || b.qc_status;
    return qcStatus === 'rejected';
  });
  
  const hasPending = batchesForItem.some(b => {
    const qcStatus = b.qcStatus || b.qc_status;
    return qcStatus === 'pending' || !qcStatus;
  });
  
  const allApproved = batchesForItem.every(b => {
    const qcStatus = b.qcStatus || b.qc_status;
    return qcStatus === 'approved';
  });
  
  // Priority: Rejected > Pending > Approved
  if (hasRejected) {
    return 'fail';
  } else if (hasPending) {
    return '';
  } else if (allApproved) {
    return 'pass';
  }
  
  return '';
};

const formatInspectionResult = (result) => {
  if (!result || result === '') {
    return t('status.pending');
  }
  
  const resultKeyMap = {
    'pass': 'status.pass',
    'fail': 'status.fail'
  };
  
  const translationKey = resultKeyMap[result];
  if (translationKey) {
    const translated = t(translationKey);
    // If translation returns the key (missing translation), use fallback
    if (translated === translationKey) {
      return result;
    }
    return translated;
  }
  
  return t('status.pending');
};

const getInspectionClass = (result) => {
  const classMap = {
    'pass': 'px-2 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800',
    'fail': 'px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800',
    '': 'px-2 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800'
  };
  return classMap[result] || classMap[''];
};

const formatQCStatus = (status) => {
  if (!status) {
    return t('status.pending');
  }
  
  const statusKeyMap = {
    'pending': 'status.pending',
    'approved': 'status.approved',
    'rejected': 'status.rejected'
  };
  
  const normalizedStatus = status.toLowerCase();
  const translationKey = statusKeyMap[normalizedStatus];
  
  if (translationKey) {
    const translated = t(translationKey);
    // If translation returns the key (missing translation), use fallback
    if (translated === translationKey) {
      return status;
    }
    return translated;
  }
  
  return t('status.pending');
};

const getQCStatusClass = (status) => {
  const classMap = {
    'pending': 'px-2 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800',
    'approved': 'px-2 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800',
    'rejected': 'px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800'
  };
  return classMap[status] || classMap['pending'];
};

/** Batch ID display: ONLY batch_number (BATCH-GRN-{GRN}-{YYYYMMDD}-{SEQ}). NEVER vendor_batch or row.id */
const getBatchIdDisplay = (batch) => {
  const bn = batch?.batch_number || batch?.batchNumber;
  if (bn && String(bn).trim()) return String(bn).trim();
  return '—'; // Pending DB sync — same format as Stock Overview
};

const getReceivedQuantityForItem = (itemId) => {
  if (!itemId || !grn.value) return 0;
  const item = grn.value.items.find(i => {
    const itemIdToCheck = i.itemId || i.item_id;
    return itemIdToCheck === itemId;
  });
  return item ? (item.receivedQuantity || item.received_quantity || 0) : 0;
};

const getRemainingQuantity = (itemId) => {
  if (!itemId || !grn.value) return 0;
  
  // Find item in GRN items
  const item = grn.value.items.find(i => {
    const itemIdToCheck = i.itemId || i.item_id;
    return itemIdToCheck === itemId;
  });
  
  if (!item) {
    console.warn('Item not found in GRN items:', itemId, 'Available items:', grn.value.items.map(i => ({ id: i.itemId || i.item_id, name: i.item?.name || 'N/A' })));
    return 0;
  }
  
  const receivedQty = item.receivedQuantity || item.received_quantity || 0;
  
  // Get all batches for this item (excluding the batch being edited)
  const batchesForItem = (grn.value.batches || []).filter(b => {
    const batchItemId = b.itemId || b.item_id;
    return batchItemId === itemId && b.id !== editingBatch.value?.id;
  });
  
  const totalBatchQty = batchesForItem.reduce((sum, b) => sum + getBatchQuantity(b), 0);
  
  const remaining = receivedQty - totalBatchQty;
  
  if (import.meta.env.DEV && receivedQty > 0 && batchesForItem.length === 0) {
    console.warn('[GRN] No batches for item:', itemId, 'receivedQty:', receivedQty, '- create a batch to allocate quantity');
  }
  
  return Math.max(0, remaining); // Ensure non-negative
};

const checkExistingBatch = () => {
  if (!batchForm.value.itemId || !batchForm.value.expiryDate || !grn.value) {
    existingBatchWarning.value = false;
    return;
  }
  
  const existing = (grn.value.batches || []).find(b => 
    (b.itemId || b.item_id) === batchForm.value.itemId &&
    (b.expiryDate || b.expiry_date) === batchForm.value.expiryDate &&
    b.id !== editingBatch.value?.id
  );
  
  existingBatchWarning.value = !!existing;
};

const onBatchItemChange = () => {
  checkExistingBatch();
};

const openCreateBatchModal = () => {
  editingBatch.value = null;
  batchForm.value = {
    itemId: '',
    expiryDate: '',
    batchQuantity: 0,
    storageLocation: '',
    vendorBatchNumber: '',
    qcStatus: 'pending'
  };
  existingBatchWarning.value = false;
  showBatchModal.value = true;
};

const closeBatchModal = () => {
  showBatchModal.value = false;
  editingBatch.value = null;
  existingBatchWarning.value = false;
};

const editBatch = (batch) => {
  editingBatch.value = batch;
  batchForm.value = {
    itemId: batch.itemId || batch.item_id || '',
    expiryDate: batch.expiryDate || batch.expiry_date || '',
    batchQuantity: getBatchQuantity(batch),
    storageLocation: batch.storageLocation || batch.storage_location || '',
    vendorBatchNumber: batch.vendorBatchNumber || batch.vendor_batch_number || '',
    qcStatus: batch.qcStatus || batch.qc_status || 'pending'
  };
  checkExistingBatch();
  showBatchModal.value = true;
};

const deleteBatch = async (batch) => {
  const batchLabel = batch.batch_number || batch.batchNumber || 'this batch';
  const confirmed = await showConfirmDialog({
    title: 'Delete Batch',
    message: `Are you sure you want to delete batch ${batchLabel}? This action cannot be undone.`,
    confirmText: 'Yes, Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const batchId = batch.id || batch.batch_id;
    if (!batchId || !safeUUID(batchId)) {
      showNotification('Invalid batch: cannot delete. Batch ID must be a valid UUID.', 'error');
      return;
    }
    const result = await deleteBatchFromSupabase(batchId);
    if (result.success) {
      showNotification('Batch deleted successfully', 'success');
      // Remove from local state
      if (grn.value && grn.value.batches) {
        grn.value.batches = grn.value.batches.filter(b => (b.id || b.batch_id) !== batchId);
      }
      // Reload from DB
      await loadBatchesForGRNLocal(grn.value.id);
      await loadGRN();
    } else {
      showNotification('Error deleting batch: ' + (result.error || 'Unknown error'), 'error');
    }
  } catch (error) {
    console.error('Error deleting batch:', error);
    showNotification('Error deleting batch: ' + (error.message || 'Unknown error'), 'error');
  }
};

const saveBatch = async () => {
  try {
    // Validation: Check required fields
    if (!batchForm.value.itemId) {
      showNotification('Please select an item', 'warning');
      return;
    }
    
    if (!batchForm.value.expiryDate) {
      showNotification('Please select an expiry date', 'warning');
      return;
    }
    
    if (batchForm.value.batchQuantity === null || batchForm.value.batchQuantity === undefined || batchForm.value.batchQuantity < 0) {
      showNotification('Please enter a valid batch quantity (must be 0 or greater)', 'warning');
      return;
    }
    
    // Allow 0 but show warning
    if (batchForm.value.batchQuantity === 0) {
      const confirmed = await showConfirmDialog({
        title: 'Zero Batch Quantity',
        message: 'Batch quantity is 0. Are you sure you want to create a batch with 0 quantity?',
        confirmText: 'Yes, Create',
        cancelText: 'Cancel',
        type: 'warning',
        icon: 'fas fa-exclamation-triangle'
      });
      if (!confirmed) return;
    }
    
    if (!batchForm.value.storageLocation) {
      showNotification('Please select a storage location', 'warning');
      return;
    }
    
    // ISO 22000 Validation Rule: Same Item + Same Expiry + Same GRN = Same Batch
    const existing = (grn.value.batches || []).find(b => 
      (b.itemId || b.item_id) === batchForm.value.itemId &&
      (b.expiryDate || b.expiry_date) === batchForm.value.expiryDate &&
      b.id !== editingBatch.value?.id
    );
    
    if (existing && !editingBatch.value) {
      // ISO Rule: Use existing batch and add quantity
      const currentQty = getBatchQuantity(existing);
      const newQty = batchForm.value.batchQuantity;
      const updatedQty = currentQty + newQty;
      
      // Validate total quantity doesn't exceed received quantity
      const item = grn.value.items.find(i => (i.itemId || i.item_id) === batchForm.value.itemId);
      if (!item) {
        showNotification('Item not found in GRN', 'error');
        return;
      }
      
      const receivedQty = item.receivedQuantity || item.received_quantity || 0;
      if (updatedQty > receivedQty) {
        showNotification(`Total batch quantity (${updatedQty}) cannot exceed received quantity (${receivedQty})`, 'error');
        return;
      }
      
      const result = await updateBatchInSupabase(existing.id, {
        batchQuantity: updatedQty,
        batch_quantity: updatedQty,
        updated_at: new Date().toISOString()
      });
      
      if (result.success) {
        showNotification(`Batch quantity updated (ISO 22000: Same Item + Expiry + GRN = Same Batch). Total: ${updatedQty}`, 'success');
        await loadGRN();
        closeBatchModal();
      } else {
        throw new Error(result.error || 'Failed to update batch');
      }
      return;
    }
    
    // Over-batching / duplicate prevention: block if already fully allocated
    const item = grn.value.items.find(i => (i.itemId || i.item_id) === batchForm.value.itemId);
    const receivedQty = parseFloat(item?.receivedQuantity ?? item?.received_quantity ?? 0);
    const remaining = await getRemainingAllocatableForItem(grn.value.id, batchForm.value.itemId, receivedQty);
    if (remaining <= 0 && !editingBatch.value) {
      showNotification('All received quantity is already allocated to batches. Cannot create duplicate.', 'error');
      return;
    }
    if (batchForm.value.batchQuantity > remaining) {
      showNotification(`Batch quantity (${batchForm.value.batchQuantity}) cannot exceed remaining quantity (${remaining}). Received quantity: ${receivedQty}`, 'error');
      return;
    }
    
    // Do NOT generate batch_number or batchId in frontend.
    // DB generates batch_number via fn_generate_batch_number_from_grn: BATCH-{GRN_NUMBER}-{YYYYMMDD}-{SEQ}

    const batchData = {
      itemId: batchForm.value.itemId,
      item_id: batchForm.value.itemId,
      expiryDate: batchForm.value.expiryDate,
      expiry_date: batchForm.value.expiryDate,
      batchQuantity: batchForm.value.batchQuantity,
      batch_quantity: batchForm.value.batchQuantity,
      remainingQty: getRemainingQuantity(batchForm.value.itemId),
      storageLocation: batchForm.value.storageLocation,
      storage_location: batchForm.value.storageLocation,
      vendorBatchNumber: batchForm.value.vendorBatchNumber || null,
      vendor_batch_number: batchForm.value.vendorBatchNumber || null,
      grnId: grn.value.id,
      grn_id: grn.value.id,
      grnNumber: grn.value.grnNumber || grn.value.grn_number,
      grn_number: grn.value.grnNumber || grn.value.grn_number,
      qcStatus: 'pending',
      qc_status: 'pending',
      qcData: {
        visualCondition: '',
        packagingCondition: '',
        temperature: '',
        remarks: ''
      },
      created_by: getCurrentUserUUID(),
      createdAt: new Date().toISOString(),
      created_at: new Date().toISOString()
    };
    
    const result = editingBatch.value
      ? await updateBatchInSupabase(editingBatch.value.id, {
          ...batchData,
          updated_at: new Date().toISOString()
        })
      : await saveBatchToSupabase(batchData);
    
    if (result.success) {
      showNotification(editingBatch.value ? 'Batch updated successfully' : 'Batch created successfully (ISO 22000 compliant)', 'success');
      // Optimistic update: add batch to list immediately so table updates (handles timing/race)
      if (result.data && grn.value) {
        if (!grn.value.batches) grn.value.batches = [];
        const exists = grn.value.batches.some(b => (b.id || b.batch_id) === (result.data.id || result.data.batch_id));
        if (!exists) {
          const qty = result.data.qty_received ?? result.data.quantity ?? result.data.batch_quantity;
          const batchRow = { ...result.data, qty_received: qty, batch_quantity: qty, batchQuantity: qty };
          grn.value.batches = [batchRow, ...grn.value.batches];
        }
      }
      // Reload batches from DB/localStorage to ensure full data (batch_number, etc.)
      await loadBatchesForGRNLocal(grn.value.id);
      // Also reload full GRN to ensure data consistency
      await loadGRN();
      closeBatchModal();
    } else {
      throw new Error(result.error || 'Failed to save batch');
    }
  } catch (error) {
    console.error('Error saving batch:', error);
    showNotification('Error saving batch: ' + (error.message || 'Unknown error'), 'error');
  }
};

const approveBatchQC = async (batch) => {
  // Validate QC data before approval
  if (!batch.qcData.visualCondition || !batch.qcData.packagingCondition) {
    showNotification('Please fill in Visual Condition and Packaging Condition before approving', 'warning');
    return;
  }
  
  const confirmed = await showConfirmDialog({
    title: 'Approve Batch',
    message: `Are you sure you want to approve batch ${batch.batch_number || batch.batchNumber || '—'}? This batch will be available for use.`,
    confirmText: 'Yes, Approve',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-check'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await updateBatchInSupabase(batch.id, {
      qcStatus: 'approved',
      qc_status: 'approved',
      qc_checked_by: getCurrentUserUUID(),
      qcCheckedAt: new Date().toISOString(),
      qc_checked_at: new Date().toISOString(),
      qcData: batch.qcData,
      updated_at: new Date().toISOString()
    });
    
    if (result.success) {
      showNotification('Batch approved successfully. Batch is now available for use.', 'success');
      await loadGRN();
    } else {
      throw new Error(result.error || 'Failed to approve batch');
    }
  } catch (error) {
    console.error('Error approving batch:', error);
    showNotification('Error approving batch: ' + (error.message || 'Unknown error'), 'error');
  }
};

const rejectBatchQC = async (batch) => {
  const confirmed = await showConfirmDialog({
    title: 'Reject Batch',
    message: `Are you sure you want to reject batch ${batch.batch_number || batch.batchNumber || '—'}? Rejected batches are permanently blocked from future use and cannot be undone.`,
    confirmText: 'Yes, Reject',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-times'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await updateBatchInSupabase(batch.id, {
      qcStatus: 'rejected',
      qc_status: 'rejected',
      qc_checked_by: getCurrentUserUUID(),
      qcCheckedAt: new Date().toISOString(),
      qc_checked_at: new Date().toISOString(),
      qcData: batch.qcData,
      blocked: true, // Mark as blocked for future use
      updated_at: new Date().toISOString()
    });
    
    if (result.success) {
      showNotification('Batch rejected. It is now permanently blocked from future use.', 'success');
      await loadGRN();
    } else {
      throw new Error(result.error || 'Failed to reject batch');
    }
  } catch (error) {
    console.error('Error rejecting batch:', error);
    showNotification('Error rejecting batch: ' + (error.message || 'Unknown error'), 'error');
  }
};

const viewBatchQC = (batch) => {
  activeTab.value = 'qc';
  // Scroll to batch QC section
  setTimeout(() => {
    const element = document.querySelector(`[data-batch-id="${batch.id}"]`);
    if (element) element.scrollIntoView({ behavior: 'smooth' });
  }, 100);
};

const submitForInspection = async () => {
  // STRICT VALIDATION: Check if all items have complete entries AND all batches are created
  if (!canSubmitForInspection.value) {
    const missingFields = [];
    
    // Check item entries
    if (!canProceedToBatches.value) {
      const incompleteItems = [];
      grn.value.items.forEach((item) => {
        const receivedQty = parseFloat(item.receivedQuantity || item.received_quantity || 0);
        const packagingType = (
          item.packagingType || 
          item.packaging_type || 
          item.packagingCondition || 
          item.packaging_condition || 
          ''
        ).trim();
        const supplierLot = (item.supplierLotNumber || item.supplier_lot_number || '').trim();
        const itemName = getItemName(item);
        
        const itemMissingFields = [];
        if (receivedQty <= 0) itemMissingFields.push('Received Qty');
        if (!packagingType || packagingType.toLowerCase() === 'n/a' || packagingType.toLowerCase() === 'select...') {
          itemMissingFields.push('Packaging Type');
        }
        if (!supplierLot || supplierLot.toLowerCase() === 'n/a') {
          itemMissingFields.push('Supplier Lot');
        }
        
        if (itemMissingFields.length > 0) {
          incompleteItems.push(`${itemName}: ${itemMissingFields.join(', ')}`);
        }
      });
      
      if (incompleteItems.length > 0) {
        missingFields.push(`Items incomplete:\n${incompleteItems.join('\n')}`);
      }
    }
    
    // Check batches
  if (!allItemsHaveBatches.value) {
    const incompleteItems = batchProgress.value.filter(p => p && !p.isComplete && p.receivedQty > 0);
    const itemList = incompleteItems.map(p => `• ${p.itemName} (${p.itemSKU}): ${p.remainingQty.toFixed(2)} ${getItemUnit(grn.value?.items?.find(i => (i.itemId || i.item_id) === p.itemId)) || ''} remaining`).join('\n');
      
      if (itemList) {
        missingFields.push(`Batches incomplete:\n${itemList}`);
      }
    }
    
    showNotification(
      `Cannot submit for inspection. Please complete all entries:\n\n${missingFields.join('\n\n')}`,
      'warning',
      10000
    );
    return;
  }
  
  const confirmed = await showConfirmDialog({
    title: 'Submit For Inspection',
    message: 'Are you sure you want to submit this GRN for inspection? All items and batches are complete.',
    confirmText: 'Yes, Submit',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-clipboard-check'
  });
  
  if (!confirmed) return;
  
  try {
    console.log('💾 Saving all GRN data to Supabase before submitting for inspection...');
    
    // CRITICAL: Ensure all data is saved to Supabase before submitting
    const saveResult = await updateGRNInSupabase(grn.value.id, {
      items: grn.value.items,
      batches: grn.value.batches,
      receivedBy: grn.value.receivedBy || grn.value.received_by,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID()
    });
    
    if (!saveResult.success) {
      console.error('❌ Error saving GRN data to Supabase:', saveResult.error);
      showNotification('Error saving data to database. Please try again.', 'error');
      return;
    }
    
    console.log('✅ All GRN data saved to Supabase successfully');
    
    // Generate GRN number only when submitting for inspection (not in draft)
    // Remove any DRAFT- prefix if exists
    let grnNumber = grn.value.grnNumber || grn.value.grn_number;
    if (!grnNumber || grnNumber === '' || grnNumber.startsWith('DRAFT-')) {
      grnNumber = await generateGRNNumber();
    }
    
    // Ensure GRN number doesn't start with DRAFT-
    if (grnNumber && grnNumber.startsWith('DRAFT-')) {
      grnNumber = await generateGRNNumber();
    }
    
    const result = await updateGRNInSupabase(grn.value.id, {
      ...grn.value,
      status: 'pending', // Use 'pending' to match database constraint (allowed: 'draft', 'pending', 'passed', 'hold', 'rejected', 'conditional')
      grnNumber: grnNumber,
      grn_number: grnNumber,
      submittedForInspectionAt: new Date().toISOString(),
      submitted_for_inspection_at: new Date().toISOString()
    });
    
    if (result.success) {
      showNotification('GRN submitted for inspection. QC & Inspection tab is now available.', 'success');
      await loadGRN();
      
      // Automatically switch to QC & Inspection tab
      await nextTick();
      switchTab('qc');
      
      // Wait for Vue to update the DOM
      await nextTick();
    } else {
      throw new Error(result.error || 'Failed to submit GRN');
    }
  } catch (error) {
    console.error('Error submitting GRN:', error);
    showNotification('Error submitting GRN: ' + (error.message || 'Unknown error'), 'error');
  }
};

const approveGRN = async () => {
  // Check if GRN is submitted for approval
  if (!isSubmittedForApproval.value) {
    showNotification('GRN must be submitted for approval before it can be approved by QA Manager.', 'warning');
    return;
  }
  
  // STRICT VALIDATION: Check if all batches have QC inspection completed before allowing approval
  if (!allBatchesHaveQCInspection.value) {
    const pendingBatches = grn.value.batches.filter(b => {
      const qcStatus = (b.qcStatus || b.qc_status || 'pending').toLowerCase();
      return qcStatus === 'pending';
    });
    
    const batchList = pendingBatches.map(b => {
      const itemName = getItemName(grn.value.items.find(i => (i.itemId || i.item_id) === (b.itemId || b.item_id)));
      const batchId = b.batch_number || b.batchNumber || '—';
      return `• ${itemName} - Batch ${batchId}`;
    }).join('\n');
    
    showNotification(
      `Cannot approve GRN. Please complete QC inspection for all batches first.\n\nPending batches:\n${batchList}`,
      'warning',
      8000
    );
    return;
  }
  
  // Additional check: Ensure all items have batches (double validation)
  if (!allItemsHaveBatches.value) {
    showNotification('Cannot approve GRN. All items must have complete batches created.', 'warning');
    return;
  }
  
  const confirmed = await showConfirmDialog({
    title: 'Approve GRN',
    message: `All batches have QC inspection completed. Are you sure you want to approve this GRN? This will post stock at batch level.\n\nQC Summary: ${qcInspectionProgress.value.approved} approved, ${qcInspectionProgress.value.rejected} rejected.`,
    confirmText: 'Yes, Approve',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-check'
  });
  
  if (!confirmed) return;
  
  try {
    console.log('💾 Saving all GRN data to Supabase before approving...');
    
    // CRITICAL: Ensure all data is saved to Supabase before approving
    const saveResult = await updateGRNInSupabase(grn.value.id, {
      items: grn.value.items,
      batches: grn.value.batches,
      receivedBy: grn.value.receivedBy || grn.value.received_by,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID()
    });
    
    if (!saveResult.success) {
      console.error('❌ Error saving GRN data to Supabase:', saveResult.error);
      showNotification('Error saving data to database. Please try again.', 'error');
      return;
    }
    
    console.log('✅ All GRN data saved to Supabase successfully');
    
    const result = await updateGRNInSupabase(grn.value.id, {
      status: 'passed', // Use 'passed' to match database constraint (allowed: 'draft', 'pending', 'passed', 'hold', 'rejected', 'conditional')
      approved_by: getCurrentUserUUID(),
      approvedAt: new Date().toISOString(),
      approved_at: new Date().toISOString()
    });
    
    if (result.success) {
      console.log('✅ GRN approved successfully. Status updated to "approved" in Supabase.');
      showNotification('GRN approved. Stock posted at batch level. "Create Purchasing" button is now available.', 'success');
      
      // Update PO receiving status when GRN is approved
      const poId = grn.value.purchaseOrderId || grn.value.purchase_order_id;
      if (poId) {
        console.log('🔄 Updating PO status based on GRN approval, PO ID:', poId);
        
        // Wait a moment for database trigger to complete
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const { updatePOStatusBasedOnGRNs } = await import('@/services/autoDraftFlow');
        const poUpdateResult = await updatePOStatusBasedOnGRNs(poId);
        
        if (poUpdateResult.success) {
          console.log('✅ PO status updated:', poUpdateResult.data?.status);
        } else {
          console.warn('⚠️ PO status update failed:', poUpdateResult.error);
        }
        
        // CRITICAL: Fire window event to notify PO detail page to refresh
        // Ensure PO ID is string for proper comparison
        const poIdStr = String(poId).trim();
          window.dispatchEvent(new CustomEvent('grn-approved', { 
            detail: { 
            poId: poIdStr,
              grnId: grn.value.id 
            } 
          }));
        console.log('✅ Fired grn-approved event for PO:', poIdStr);
        
        // Also manually trigger database function to ensure quantities are updated
        try {
          const { supabaseClient } = await import('@/services/supabase');
          if (supabaseClient) {
            const { error: triggerError } = await supabaseClient.rpc('update_po_received_quantities', {
              po_id_param: poIdStr
            });
            
            if (triggerError) {
              console.warn('⚠️ Manual trigger call failed (might not exist):', triggerError);
            } else {
              console.log('✅ Manually triggered PO quantity update');
            }
          }
        } catch (e) {
          console.warn('⚠️ Could not manually trigger PO update:', e);
        }
      }
      
      // AUTO-DRAFT FLOW: Prepare Purchasing Draft Payload when GRN is approved
      // ISO 22000 Business Rule: Approved GRN → Purchasing Draft Payload
      // This separates physical receipt (GRN) from accounting (Purchasing)
      // Multiple GRNs can be merged into ONE Purchasing later
      try {
        const { onGRNApproved } = await import('@/services/autoDraftFlow');
        const purchasingResult = await onGRNApproved(result.data);
        
        if (purchasingResult.success) {
          console.log('✅ Purchasing Draft Payload prepared:', purchasingResult.purchasingDraftPayload);
          // Don't show notification to user yet - Purchasing module not built
          // The payload is stored and ready for Purchasing module creation
        } else {
          console.warn('⚠️ Purchasing Draft Payload preparation failed:', purchasingResult.error);
          // Don't fail GRN approval if Purchasing draft preparation fails
        }
      } catch (autoDraftError) {
        console.error('❌ Error in auto-draft flow:', autoDraftError);
        // Don't fail GRN approval if auto-draft fails
      }
      
      // CRITICAL: Reload GRN to get latest status from database
      await loadGRN();
      const { forceSystemSync } = await import('@/services/erpViews.js');
      await forceSystemSync();
      
      // Wait for Vue to update the DOM
      await nextTick();
    } else {
      throw new Error(result.error || 'Failed to approve GRN');
    }
  } catch (error) {
    console.error('Error approving GRN:', error);
    showNotification('Error approving GRN: ' + (error.message || 'Unknown error'), 'error');
  }
};

const submitForGRNApproval = async () => {
  // Validate that all batches have QC inspection completed
  if (!allBatchesHaveQCInspection.value) {
    const pendingBatches = grn.value.batches.filter(b => {
      const qcStatus = (b.qcStatus || b.qc_status || 'pending').toLowerCase();
      return qcStatus === 'pending';
    });
    
    const batchList = pendingBatches.map(b => {
      const itemName = getItemName(grn.value.items.find(i => (i.itemId || i.item_id) === (b.itemId || b.item_id)));
      const batchId = b.batch_number || b.batchNumber || '—';
      return `• ${itemName} - Batch ${batchId}`;
    }).join('\n');
    
    showNotification(
      `Cannot submit for GRN approval. Please ensure all batches have QC inspection completed first.\n\nPending batches:\n${batchList}`,
      'warning',
      8000
    );
    return;
  }
  
  const confirmed = await showConfirmDialog({
    title: 'Submit for GRN Approval',
    message: 'All batches have been approved by QA Inspector. Submit this GRN for approval by QA Manager?',
    confirmText: 'Yes, Submit',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-paper-plane'
  });
  
  if (!confirmed) return;
  
  try {
    console.log('💾 Saving all GRN data to Supabase before submitting for approval...');
    
    // CRITICAL: Ensure all data is saved to Supabase before submitting
    const saveResult = await updateGRNInSupabase(grn.value.id, {
      items: grn.value.items,
      batches: grn.value.batches,
      receivedBy: grn.value.receivedBy || grn.value.received_by,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID()
    });
    
    if (!saveResult.success) {
      console.error('❌ Error saving GRN data to Supabase:', saveResult.error);
      showNotification('Error saving data to database. Please try again.', 'error');
      return;
    }
    
    console.log('✅ All GRN data saved to Supabase successfully');
    
    const result = await updateGRNInSupabase(grn.value.id, {
      submittedForApproval: true,
      submitted_for_approval: true,
      submittedForApprovalAt: new Date().toISOString(),
      submitted_for_approval_at: new Date().toISOString(),
      submittedForApprovalBy: null,
      submitted_for_approval_by: getCurrentUserUUID()
    });
    
    if (result.success) {
      console.log('✅ GRN submitted for approval successfully. submittedForApproval set to true in Supabase.');
      showNotification('GRN submitted for approval. "Approve GRN" button is now available for QA Manager.', 'success');
      
      // CRITICAL: Reload GRN to get latest submittedForApproval status from database
      await loadGRN();
      
      // Wait for Vue to update the DOM
      await nextTick();
    } else {
      throw new Error(result.error || 'Failed to submit GRN for approval');
    }
  } catch (error) {
    console.error('Error submitting GRN for approval:', error);
    showNotification('Error submitting GRN for approval: ' + (error.message || 'Unknown error'), 'error');
  }
};

const rejectGRN = async () => {
  const confirmed = await showConfirmDialog({
    title: 'Reject GRN',
    message: 'Are you sure you want to reject this GRN?',
    confirmText: 'Yes, Reject',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-times'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await updateGRNInSupabase(grn.value.id, {
      status: 'rejected'
    });
    
    if (result.success) {
      showNotification('GRN rejected', 'success');
      await loadGRN();
    } else {
      throw new Error(result.error || 'Failed to reject GRN');
    }
  } catch (error) {
    console.error('Error rejecting GRN:', error);
    showNotification('Error rejecting GRN: ' + (error.message || 'Unknown error'), 'error');
  }
};

const createPurchasing = async () => {
  // ============================================================
  // SAP MIRO: Create Purchasing Invoice from Approved GRN
  // Business Rule: GRN Approved → Purchasing Draft Created → Finance Workflow
  // CRITICAL: Cost MUST flow from PO → GRN → Purchasing (SAP RBKP/RSEG logic)
  // ============================================================
  
  try {
    console.log('='.repeat(60));
    console.log('🛒 CREATE PURCHASING: Starting...');
    console.log('🛒 GRN ID:', grn.value.id);
    console.log('🛒 GRN Number:', grn.value.grnNumber || grn.value.grn_number);
    console.log('='.repeat(60));
    
    // Validate GRN is approved
    const grnStatus = (grn.value.status || '').toLowerCase();
    console.log('📋 GRN Status:', grnStatus);
    
    if (grnStatus !== 'approved' && grnStatus !== 'passed') {
      showNotification('GRN must be approved before creating Purchasing Invoice.', 'error');
      return;
    }
    
    // Check if purchasing invoice already exists for this GRN
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    
    if (!ready) {
      showNotification('Database connection not available. Please try again.', 'error');
      return;
    }
    
    // Check for existing purchasing invoice
    const { data: existingInvoice } = await supabaseClient
      .from('purchasing_invoices')
      .select('id, invoice_number')
      .eq('grn_id', grn.value.id)
      .single();
    
    if (existingInvoice) {
      showNotification(`Purchasing Invoice already exists for this GRN. Redirecting...`, 'info');
      router.push(`/homeportal/purchasing-detail/${existingInvoice.id}`);
      return;
    }

    // BUSINESS RULE: Block if GRN is CLOSED or Purchasing already exists (document state control)
    const { canCreateNextDocument } = await import('@/services/erpViews.js');
    const canCreate = await canCreateNextDocument('GRN', grn.value.id);
    if (!canCreate) {
      showNotification('Purchasing already exists for this GRN or the GRN is closed. Duplicate creation is not allowed.', 'error');
      canCreatePurchase.value = false;
      return;
    }
    
    // ============================================================
    // SAP COST FLOW: Fetch unit_price from purchase_order_items
    // PRIMARY KEY: purchase_order_id (bigint) - more reliable than po_number
    // ============================================================
    const poId = grn.value.purchaseOrderId || grn.value.purchase_order_id;
    const poNumber = grn.value.purchaseOrderNumber || grn.value.purchase_order_number || 
                     grn.value.purchaseOrderReference || grn.value.purchase_order_reference;
    
    console.log('📦 PO Lookup - purchase_order_id:', poId, 'po_number:', poNumber);
    
    // Fetch PO items with unit_price using BOTH purchase_order_id and po_number
    let poItemCosts = {};
    let poItemsFound = false;
    
    // Method 1: Query by purchase_order_id (PRIMARY - more reliable)
    if (poId) {
      console.log('📦 Querying PO items by purchase_order_id:', poId);
      const { data: poItems, error: poError } = await supabaseClient
        .from('purchase_order_items')
        .select('item_id, item_sku, item_name, unit_price, quantity')
        .eq('purchase_order_id', poId);
      
      console.log('📦 PO Items Query Result:', { data: poItems, error: poError });
      
      if (!poError && poItems && poItems.length > 0) {
        poItemsFound = true;
        poItems.forEach(poi => {
          console.log(`💰 PO ITEM: ${poi.item_name}, item_id=${poi.item_id}, unit_price=${poi.unit_price}`);
          if (poi.item_id) {
            poItemCosts[poi.item_id] = parseFloat(poi.unit_price || 0);
          }
          if (poi.item_sku) {
            poItemCosts[`sku_${poi.item_sku}`] = parseFloat(poi.unit_price || 0);
          }
        });
        console.log('✅ PO Item Costs loaded by purchase_order_id:', poItemCosts);
      } else {
        console.warn('⚠️ No PO items found by purchase_order_id:', poError?.message || 'No data');
      }
    }
    
    // Method 2: Fallback query by po_number
    if (!poItemsFound && poNumber) {
      console.log('📦 Fallback: Querying PO items by po_number:', poNumber);
      const { data: poItems, error: poError } = await supabaseClient
        .from('purchase_order_items')
        .select('item_id, item_sku, item_name, unit_price, quantity')
        .eq('po_number', poNumber);
      
      console.log('📦 PO Items Query Result (by po_number):', { data: poItems, error: poError });
      
      if (!poError && poItems && poItems.length > 0) {
        poItemsFound = true;
        poItems.forEach(poi => {
          console.log(`💰 PO ITEM (by po_number): ${poi.item_name}, item_id=${poi.item_id}, unit_price=${poi.unit_price}`);
          if (poi.item_id) {
            poItemCosts[poi.item_id] = parseFloat(poi.unit_price || 0);
          }
          if (poi.item_sku) {
            poItemCosts[`sku_${poi.item_sku}`] = parseFloat(poi.unit_price || 0);
          }
        });
        console.log('✅ PO Item Costs loaded by po_number:', poItemCosts);
      }
    }
    
    // Method 3: Final fallback - load inventory item costs
    console.log('📦 Loading inventory item costs as fallback...');
    const { data: inventoryItems } = await supabaseClient
      .from('inventory_items')
      .select('id, sku, cost');
    
    const inventoryCosts = {};
    if (inventoryItems) {
      inventoryItems.forEach(item => {
        inventoryCosts[item.id] = parseFloat(item.cost || 0);
        if (item.sku) {
          inventoryCosts[`sku_${item.sku}`] = parseFloat(item.cost || 0);
        }
      });
      console.log('📦 Inventory Costs loaded:', Object.keys(inventoryCosts).length, 'items');
    }
    
    // ============================================================
    // Build purchasing invoice items with CORRECT COST
    // ============================================================
    const grnItems = grn.value.items || [];
    console.log('📋 GRN Items to process:', grnItems.length);
    
    let totalAmount = 0;
    
    const purchasingItems = grnItems.map((item, index) => {
      const itemId = item.itemId || item.item_id;
      const itemCode = item.itemCode || item.item_code || item.item_sku;
      const qty = parseFloat(item.receivedQuantity || item.received_quantity || 0);
      
      console.log(`\n📝 Processing GRN Item ${index + 1}:`);
      console.log(`   - item_id: ${itemId}`);
      console.log(`   - item_code: ${itemCode}`);
      console.log(`   - quantity: ${qty}`);
      
      // COST PRIORITY: 1) PO Item Cost by ID, 2) PO Cost by SKU, 3) Inventory Cost, 4) Zero
      let unitCost = 0;
      let costSource = 'NONE';
      
      // Try PO cost by item_id first
      if (itemId && poItemCosts[itemId] && poItemCosts[itemId] > 0) {
        unitCost = poItemCosts[itemId];
        costSource = 'PO_BY_ID';
        console.log(`   ✅ Cost from PO (by item_id): ${unitCost}`);
      }
      // Try PO cost by SKU
      else if (itemCode && poItemCosts[`sku_${itemCode}`] && poItemCosts[`sku_${itemCode}`] > 0) {
        unitCost = poItemCosts[`sku_${itemCode}`];
        costSource = 'PO_BY_SKU';
        console.log(`   ✅ Cost from PO (by SKU): ${unitCost}`);
      }
      // Fallback to inventory cost by ID
      else if (itemId && inventoryCosts[itemId] && inventoryCosts[itemId] > 0) {
        unitCost = inventoryCosts[itemId];
        costSource = 'INVENTORY_BY_ID';
        console.log(`   ⚠️ Cost from Inventory (by item_id): ${unitCost}`);
      }
      // Fallback to inventory cost by SKU
      else if (itemCode && inventoryCosts[`sku_${itemCode}`] && inventoryCosts[`sku_${itemCode}`] > 0) {
        unitCost = inventoryCosts[`sku_${itemCode}`];
        costSource = 'INVENTORY_BY_SKU';
        console.log(`   ⚠️ Cost from Inventory (by SKU): ${unitCost}`);
      }
      else {
        console.warn(`   ❌ NO COST FOUND for item ${itemId || itemCode}`);
        console.warn(`   PO costs available:`, Object.keys(poItemCosts));
        console.warn(`   Looking for key: ${itemId} or sku_${itemCode}`);
      }
      
      const itemTotal = qty * unitCost;
      totalAmount += itemTotal;
      
      console.log(`   💰 FINAL: UnitCost=${unitCost}, Total=${itemTotal}, Source=${costSource}`);
      
      return {
        item_id: itemId,
        item_name: item.itemName || item.item_name,
        item_code: itemCode,
        quantity: qty,
        unit_cost: unitCost,
        total_cost: itemTotal
      };
    });
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 COST SUMMARY:');
    console.log(`   Total Items: ${purchasingItems.length}`);
    console.log(`   Total Amount (Subtotal): ${totalAmount}`);
    console.log(`   Tax (15%): ${totalAmount * 0.15}`);
    console.log(`   Grand Total: ${totalAmount * 1.15}`);
    console.log('='.repeat(60));
    
    // ============================================================
    // Extract SUPPLIER NAME (not object)
    // ============================================================
    let supplierName = 'N/A';
    const supplierRaw = grn.value.supplier || grn.value.supplierName || grn.value.supplier_name;
    
    console.log('📋 Supplier Raw Value:', supplierRaw, 'Type:', typeof supplierRaw);
    
    if (typeof supplierRaw === 'string' && !supplierRaw.startsWith('{')) {
      supplierName = supplierRaw;
    } else if (typeof supplierRaw === 'object' && supplierRaw !== null) {
      // If supplier is an object, extract the name
      supplierName = supplierRaw.name || supplierRaw.supplier_name || supplierRaw.supplierName || 'N/A';
      console.log('📋 Extracted supplier name from object:', supplierName);
    } else if (typeof supplierRaw === 'string' && supplierRaw.startsWith('{')) {
      // JSON string
      try {
        const parsed = JSON.parse(supplierRaw);
        supplierName = parsed.name || parsed.supplier_name || 'N/A';
        console.log('📋 Extracted supplier name from JSON string:', supplierName);
      } catch (e) {
        supplierName = supplierRaw.substring(0, 50);
      }
    }
    
    // If still no name, try to fetch from suppliers table
    const supplierId = grn.value.supplierId || grn.value.supplier_id;
    if ((supplierName === 'N/A' || supplierName.startsWith('{')) && supplierId) {
      console.log('📋 Fetching supplier from DB, supplier_id:', supplierId);
      const { data: supplierData } = await supabaseClient
        .from('suppliers')
        .select('name, name_localized')
        .eq('id', supplierId)
        .single();
      
      if (supplierData) {
        supplierName = supplierData.name || supplierData.name_localized || 'N/A';
        console.log('✅ Fetched supplier name from DB:', supplierName);
      }
    }
    
    // ============================================================
    // Create purchasing invoice header (SAP RBKP)
    // payment_method: DB allows only CASH_ON_HAND, ATM_MARKET_PURCHASE, FREE_SAMPLE, ONLINE_GATEWAY.
    // BANK_TRANSFER is forbidden here (manual payments only in Finance → Payments).
    // Default draft from GRN to CASH_ON_HAND; user can change on Purchasing detail.
    // CRITICAL: created_by MUST be UUID only - never user name (fixes "invalid input syntax for type uuid")
    // ============================================================
    let createdByUuid = safeUUID(getCurrentUserUUID());
    // Fallback: if auth has old session (id: "Ali"), fetch UUID from users table by email
    if (!createdByUuid) {
      const u = authStore.user;
      const userObj = (u && typeof u === 'object' && 'value' in u) ? u.value : u;
      const email = userObj?.email;
      if (email) {
        const { data: userRow } = await supabaseClient
          .from('users')
          .select('id')
          .eq('email', String(email).toLowerCase().trim())
          .maybeSingle();
        createdByUuid = safeUUID(userRow?.id);
      }
    }
    if (!createdByUuid) {
      showNotification('Session expired or invalid. Please log out and log back in, then try again.', 'warning', 8000);
      return;
    }
    const purchasingInvoice = {
      grn_id: grn.value.id,
      grn_number: grn.value.grnNumber || grn.value.grn_number,
      purchase_order_id: poId || null,
      purchase_order_number: poNumber || null,
      supplier_id: supplierId || null,
      supplier_name: supplierName,
      invoice_date: new Date().toISOString().split('T')[0],
      receiving_location: grn.value.receivingLocation || grn.value.receiving_location || (receivingLocationOptions.value[0] || ''),
      subtotal: totalAmount,
      total_amount: totalAmount,
      tax_rate: 15, // SAR VAT 15%
      tax_amount: totalAmount * 0.15,
      grand_total: totalAmount * 1.15,
      payment_method: 'CASH_ON_HAND', // Required: must be one of CASH_ON_HAND, ATM_MARKET_PURCHASE, FREE_SAMPLE, ONLINE_GATEWAY
      status: 'draft',
      created_by: createdByUuid,
      created_at: new Date().toISOString()
    };
    
    // Insert purchasing invoice via service (enforces: no duplicate PUR for GRN, GRN not closed)
    const { savePurchasingInvoiceToSupabase } = await import('@/services/supabase.js');
    const result = await savePurchasingInvoiceToSupabase(purchasingInvoice);
    
    if (!result.success) {
      showNotification(result.error || 'Failed to create purchasing invoice', 'error', 8000);
      return;
    }
    const newInvoice = result.data;
    if (!newInvoice || !newInvoice.id) {
      showNotification('Purchasing invoice was not created. Please try again.', 'error');
      return;
    }
    
    console.log('✅ Purchasing Invoice created:', newInvoice.id, 'Invoice#:', newInvoice.invoice_number);
    
    // Insert purchasing invoice items (SAP RSEG)
    const itemsToInsert = purchasingItems.map(item => ({
      ...item,
      purchasing_invoice_id: newInvoice.id
    }));
    
    const { error: itemsError } = await supabaseClient
      .from('purchasing_invoice_items')
      .insert(itemsToInsert);
    
    if (itemsError) {
      console.warn('⚠️ Error creating purchasing invoice items:', itemsError);
      // Don't fail the whole operation, items can be added manually
    } else {
      console.log('✅ Purchasing Invoice Items created:', itemsToInsert.length);
    }
    
    // Create document flow record (SAP VBFA - Document Flow)
    try {
      // Link PO → GRN (if not exists)
      if (poNumber) {
        await supabaseClient
          .from('document_flow')
          .upsert({
            source_type: 'PO',
            source_number: poNumber,
            target_type: 'GRN',
            target_id: grn.value.id,
            target_number: grn.value.grnNumber || grn.value.grn_number
          }, { onConflict: 'source_type,source_number,target_type,target_id' });
      }
      
      // Link GRN → PURCHASING
      await supabaseClient
        .from('document_flow')
        .insert({
          source_type: 'GRN',
          source_id: grn.value.id,
          source_number: grn.value.grnNumber || grn.value.grn_number,
          target_type: 'PURCHASING',
          target_id: newInvoice.id,
          target_number: newInvoice.invoice_number
        });
      
      console.log('✅ Document Flow created');
    } catch (docFlowError) {
      console.warn('⚠️ Document flow creation skipped:', docFlowError);
    }
    
    showNotification('Purchasing Invoice created successfully! Redirecting...', 'success');
    canCreatePurchase.value = false; // DB: next doc created; fn_can_create_next_document will be false on refresh
    const { forceSystemSync } = await import('@/services/erpViews.js');
    await forceSystemSync();
    // Navigate to purchasing detail page
    setTimeout(() => {
      router.push(`/homeportal/purchasing-detail/${newInvoice.id}`);
    }, 500);
    
  } catch (error) {
    console.error('❌ Error creating Purchasing Invoice:', error);
    showNotification('Error creating Purchasing Invoice: ' + (error.message || 'Unknown error'), 'error');
  }
};

// Get QC Checked By display - shows user who checked batches
const getQCCheckedByDisplay = () => {
  // First check if GRN has qcCheckedBy
  if (grn.value?.qcCheckedBy || grn.value?.qc_checked_by) {
    return grn.value.qcCheckedBy || grn.value.qc_checked_by;
  }
  
  // If not, check batches for QC checked by
  if (grn.value?.batches && Array.isArray(grn.value.batches) && grn.value.batches.length > 0) {
    const checkedBatches = grn.value.batches.filter(b => 
      b && (b.qcCheckedBy || b.qc_checked_by)
    );
    
    if (checkedBatches.length > 0) {
      // Get unique user names
      const uniqueUsers = new Set();
      checkedBatches.forEach(b => {
        const user = b.qcCheckedBy || b.qc_checked_by;
        if (user) uniqueUsers.add(user);
      });
      
      if (uniqueUsers.size > 0) {
        return Array.from(uniqueUsers).join(', ');
      }
    }
  }
  
  return 'N/A';
};

// Get max available quantity for an item (ordered - already received from other GRNs + current item's old qty)
const getMaxAvailableQuantity = async (itemId, currentGRNId) => {
  try {
    const poId = grn.value?.purchaseOrderId || grn.value?.purchase_order_id;
    if (!poId) return null;
    
    const purchaseOrders = await loadPurchaseOrdersFromSupabase();
    const purchaseOrder = purchaseOrders.find(po => po.id === poId);
    if (!purchaseOrder || !purchaseOrder.items) return null;
    
    const poItem = purchaseOrder.items.find(poi => (poi.itemId || poi.item_id) === itemId);
    if (!poItem) return null;
    
    const orderedQty = parseFloat(poItem.quantity || 0);
    
    // Get already received from all GRNs (including current GRN)
    const allGRNs = await loadGRNsFromSupabase();
    const grnsForPO = allGRNs.filter(g => {
      const grnPOId = g.purchaseOrderId || g.purchase_order_id;
      return grnPOId === poId;
    });
    
    let totalReceivedQty = 0;
    let currentItemOldQty = 0;
    
    grnsForPO.forEach(grn => {
      if (grn.items && Array.isArray(grn.items)) {
        grn.items.forEach(grnItem => {
          const grnItemId = grnItem.itemId || grnItem.item_id;
          if (grnItemId === itemId) {
            const grnStatus = (grn.status || '').toLowerCase();
            if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
              const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
              totalReceivedQty += receivedQty;
              
              // Track current item's old quantity
              if (grn.id === currentGRNId) {
                currentItemOldQty += receivedQty;
              }
            }
          }
        });
      }
    });
    
    // Max available = ordered - (total received - current item's old qty)
    // This gives us the remaining + current item's old qty (which can be changed)
    const alreadyReceivedFromOthers = totalReceivedQty - currentItemOldQty;
    return orderedQty - alreadyReceivedFromOthers;
  } catch (error) {
    console.error('Error getting max available quantity:', error);
    return null;
  }
};

// Item editing functions for Received Qty, Packaging Type, Supplier Lot
const startEditItem = async (index) => {
  const item = grn.value.items[index];
  const itemId = item.itemId || item.item_id;
  
  // Get max available quantity
  const maxAvailable = await getMaxAvailableQuantity(itemId, grn.value.id);
  const orderedQty = parseFloat(item.orderedQuantity || item.ordered_quantity || 0);
  
  itemEditForm.value[index] = {
    receivedQuantity: item.receivedQuantity || item.received_quantity || 0,
    packagingType: item.packagingType || item.packaging_type || item.packagingCondition || item.packaging_condition || '',
    supplierLotNumber: item.supplierLotNumber || item.supplier_lot_number || '',
    maxAvailable: maxAvailable !== null ? maxAvailable : orderedQty,
    orderedQty: orderedQty
  };
  editingItems.value[index] = true;
};

// Validate received quantity against PO ordered quantity
const validateReceivedQuantity = async (itemId, newReceivedQty, currentGRNId) => {
  try {
    // Get PO ID from current GRN
    const poId = grn.value?.purchaseOrderId || grn.value?.purchase_order_id;
    if (!poId) {
      // If no PO linked, allow the quantity (might be direct GRN)
      return { valid: true, remaining: null, alreadyReceived: 0 };
    }
    
    // Load Purchase Order to get ordered quantity
    const purchaseOrders = await loadPurchaseOrdersFromSupabase();
    const purchaseOrder = purchaseOrders.find(po => po.id === poId);
    
    if (!purchaseOrder || !purchaseOrder.items) {
      return { valid: true, remaining: null, alreadyReceived: 0 };
    }
    
    // Find the PO item
    const poItem = purchaseOrder.items.find(poi => 
      (poi.itemId || poi.item_id) === itemId
    );
    
    if (!poItem) {
      return { valid: true, remaining: null, alreadyReceived: 0 };
    }
    
    const orderedQty = parseFloat(poItem.quantity || 0);
    
    // Load all GRNs for this PO (including current GRN to get all items)
    const allGRNs = await loadGRNsFromSupabase();
    const grnsForPO = allGRNs.filter(g => {
      const grnPOId = g.purchaseOrderId || g.purchase_order_id;
      return grnPOId === poId;
    });
    
    // Calculate total already received quantity from all GRNs for this item
    let totalReceivedQty = 0;
    let currentItemOldQty = 0;
    
    grnsForPO.forEach(grn => {
      if (grn.items && Array.isArray(grn.items)) {
        grn.items.forEach(grnItem => {
          const grnItemId = grnItem.itemId || grnItem.item_id;
          if (grnItemId === itemId) {
            const grnStatus = (grn.status || '').toLowerCase();
            // Count all GRNs except rejected/cancelled
            if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
              const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
              totalReceivedQty += receivedQty;
              
              // Track current item's old quantity (before edit)
              if (grn.id === currentGRNId) {
                currentItemOldQty += receivedQty;
              }
            }
          }
        });
      }
    });
    
    // Subtract current item's old quantity and add new quantity
    // This gives us: (total from all GRNs - old qty of current item) + new qty
    const totalAfterUpdate = totalReceivedQty - currentItemOldQty + newReceivedQty;
    const alreadyReceivedFromOthers = totalReceivedQty - currentItemOldQty;
    
    // Calculate remaining quantity
    const remainingQty = Math.max(0, orderedQty - alreadyReceivedFromOthers);
    
    // ERP-GRADE VALIDATION: Strict validation with clear error messages
    if (totalAfterUpdate > orderedQty) {
      const maxAllowed = remainingQty;
      return {
        valid: false,
        orderedQty,
        alreadyReceived: alreadyReceivedFromOthers,
        remaining: remainingQty,
        attempted: newReceivedQty,
        total: totalAfterUpdate,
        maxAllowed: maxAllowed,
        currentItemOldQty: currentItemOldQty,
        errorMessage: `Cannot receive ${newReceivedQty} units. Maximum allowed: ${maxAllowed} units (Ordered: ${orderedQty}, Already Received: ${alreadyReceivedFromOthers})`
      };
    }
    
    // Additional validation: Ensure received quantity is positive
    if (newReceivedQty < 0) {
      return {
        valid: false,
        orderedQty,
        alreadyReceived: alreadyReceivedFromOthers,
        remaining: remainingQty,
        attempted: newReceivedQty,
        errorMessage: 'Received quantity cannot be negative'
      };
    }
    
    return {
      valid: true,
      orderedQty,
      alreadyReceived: alreadyReceivedFromOthers,
      remaining: remainingQty
    };
  } catch (error) {
    console.error('Error validating received quantity:', error);
    // On error, allow the quantity (fail open)
    return { valid: true, remaining: null, alreadyReceived: 0 };
  }
};

const saveItemEdit = async (index) => {
  if (!grn.value || !grn.value.items || !grn.value.items[index]) return;
  
  try {
    const item = grn.value.items[index];
    const editedData = itemEditForm.value[index];
    const newReceivedQty = parseFloat(editedData.receivedQuantity || 0);
    const itemId = item.itemId || item.item_id;
    
    // Validate received quantity against PO ordered quantity
    const validation = await validateReceivedQuantity(itemId, newReceivedQty, grn.value.id);
    
    if (!validation.valid) {
      const itemName = getItemName(item);
      const unit = getItemUnit(item) || 'units';
      const errorMsg = validation.errorMessage || 
        `Cannot receive ${newReceivedQty} ${unit} for "${itemName}". ` +
        `Maximum allowed: ${validation.maxAllowed !== undefined ? validation.maxAllowed.toFixed(2) : validation.remaining.toFixed(2)} ${unit} ` +
        `(Ordered: ${validation.orderedQty} ${unit}, Already Received: ${validation.alreadyReceived.toFixed(2)} ${unit})`;
      
      showNotification(errorMsg, 'error', 10000);
      return;
    }
    
    // Update item in GRN - CRITICAL: Preserve all existing item fields
    const updatedItems = [...grn.value.items];
    
    // CRITICAL: Get packaging type from editedData, fallback to existing values
    const packagingTypeValue = editedData.packagingType || item.packagingType || item.packaging_type || item.packagingCondition || item.packaging_condition || '';
    
    updatedItems[index] = {
      ...item, // Preserve all existing fields (item_id, item object, etc.)
      receivedQuantity: newReceivedQty,
      received_quantity: newReceivedQty,
      packagingType: packagingTypeValue,
      packaging_type: packagingTypeValue,
      packagingCondition: packagingTypeValue,
      packaging_condition: packagingTypeValue,
      supplierLotNumber: editedData.supplierLotNumber || item.supplierLotNumber || item.supplier_lot_number || '',
      supplier_lot_number: editedData.supplierLotNumber || item.supplierLotNumber || item.supplier_lot_number || ''
    };
    
    // CRITICAL: Ensure item_id is preserved (it might be in item.item.id)
    if (!updatedItems[index].itemId && !updatedItems[index].item_id) {
      if (item.item && item.item.id) {
        updatedItems[index].itemId = item.item.id;
        updatedItems[index].item_id = item.item.id;
      } else if (item.itemId || item.item_id) {
        updatedItems[index].itemId = item.itemId || item.item_id;
        updatedItems[index].item_id = item.itemId || item.item_id;
      }
    }
    
    // CRITICAL: Ensure item object is preserved for display
    if (item.item && !updatedItems[index].item) {
      updatedItems[index].item = item.item;
    }
    
    console.log('📝 Updating item at index', index, ':', {
      itemId: updatedItems[index].itemId || updatedItems[index].item_id,
      itemName: updatedItems[index].itemName || updatedItems[index].item_name || updatedItems[index].item?.name,
      receivedQuantity: updatedItems[index].receivedQuantity,
      packagingType: updatedItems[index].packagingType || updatedItems[index].packaging_type,
      supplierLotNumber: updatedItems[index].supplierLotNumber || updatedItems[index].supplier_lot_number,
      hasItemObject: !!updatedItems[index].item
    });
    
    const receivedByDisplay = grn.value.receivedBy || grn.value.received_by;
    const result = await updateGRNInSupabase(grn.value.id, {
      items: updatedItems,
      receivedBy: receivedByDisplay,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID()
    });
    
    if (result.success) {
      showNotification('Item details updated successfully', 'success');
      editingItems.value[index] = false;
      await loadGRN();
      
      // Update PO status if GRN is linked to PO
      if (grn.value.purchaseOrderId || grn.value.purchase_order_id) {
        const { updatePOStatusBasedOnGRNs } = await import('@/services/autoDraftFlow');
        await updatePOStatusBasedOnGRNs(grn.value.purchaseOrderId || grn.value.purchase_order_id);
      }
    } else {
      throw new Error(result.error || 'Failed to update item details');
    }
  } catch (error) {
    console.error('Error updating item details:', error);
    showNotification('Error updating item details: ' + (error.message || 'Unknown error'), 'error');
  }
};

const cancelItemEdit = (index) => {
  editingItems.value[index] = false;
  delete itemEditForm.value[index];
};

const editGRN = () => {
  if (!grn.value) return;
  
  // Pre-fill edit form with current GRN data (receivedBy for display only)
  editForm.value = {
    grnDate: grn.value.grnDate || grn.value.grn_date ? (grn.value.grnDate || grn.value.grn_date).split('T')[0] : '',
    receivingLocation: grn.value.receivingLocation || grn.value.receiving_location || '',
    receivedBy: grn.value.receivedBy || grn.value.received_by,
    supplierInvoiceNumber: grn.value.supplierInvoiceNumber || grn.value.supplier_invoice_number || '',
    deliveryNoteNumber: grn.value.deliveryNoteNumber || grn.value.delivery_note_number || '',
    externalReferenceId: grn.value.externalReferenceId || grn.value.external_reference_id || ''
  };
  
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
  editForm.value = {
    grnDate: '',
    receivingLocation: '',
    receivedBy: '',
    supplierInvoiceNumber: '',
    deliveryNoteNumber: '',
    externalReferenceId: ''
  };
};

const saveEditGRN = async () => {
  if (!grn.value) return;
  
  if (!editForm.value.grnDate) {
    showNotification('Please select a GRN date', 'warning');
    return;
  }
  
  if (!editForm.value.receivingLocation) {
    showNotification('Please select a receiving location', 'warning');
    return;
  }
  
  saving.value = true;
  try {
    const receivedByDisplay = editForm.value.receivedBy || grn.value.receivedBy || grn.value.received_by;
    const updatedData = {
      ...grn.value,
      grnDate: editForm.value.grnDate,
      grn_date: editForm.value.grnDate,
      receivingLocation: editForm.value.receivingLocation,
      receiving_location: editForm.value.receivingLocation,
      receivedBy: receivedByDisplay,
      received_by: safeUUID(grn.value.received_by) || getCurrentUserUUID(),
      supplierInvoiceNumber: editForm.value.supplierInvoiceNumber || null,
      supplier_invoice_number: editForm.value.supplierInvoiceNumber || null,
      deliveryNoteNumber: editForm.value.deliveryNoteNumber || null,
      delivery_note_number: editForm.value.deliveryNoteNumber || null,
      externalReferenceId: editForm.value.externalReferenceId || null,
      external_reference_id: editForm.value.externalReferenceId || null
    };
    
    const result = await updateGRNInSupabase(grn.value.id, updatedData);
    
    if (result.success) {
      showNotification('GRN updated successfully', 'success');
      closeEditModal();
      await loadGRN();
      
      // Update PO receiving status if GRN is linked to PO
      if (grn.value.purchaseOrderId || grn.value.purchase_order_id) {
        const { updatePOStatusBasedOnGRNs } = await import('@/services/autoDraftFlow');
        await updatePOStatusBasedOnGRNs(grn.value.purchaseOrderId || grn.value.purchase_order_id);
      }
    } else {
      throw new Error(result.error || 'Failed to update GRN');
    }
  } catch (error) {
    console.error('Error updating GRN:', error);
    showNotification('Error updating GRN: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const deleteGRNPermanently = async () => {
  const confirmed = await showConfirmDialog({
    title: 'Delete GRN',
    message: 'Are you sure you want to permanently delete this GRN? This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deleteGRNFromSupabase(grn.value.id);
    if (result.success) {
      showNotification('GRN deleted successfully', 'success');
      goBack();
    } else {
      throw new Error(result.error || 'Failed to delete GRN');
    }
  } catch (error) {
    console.error('Error deleting GRN:', error);
    showNotification('Error deleting GRN: ' + (error.message || 'Unknown error'), 'error');
  }
};

const printGRN = async () => {
  if (!grn.value) {
    showNotification('No GRN data available', 'warning');
    return;
  }

  // Use hidden iframe instead of new tab for printing
  let printFrame = document.getElementById('print-frame-grn');
  if (!printFrame) {
    printFrame = document.createElement('iframe');
    printFrame.id = 'print-frame-grn';
    printFrame.name = 'print-frame-grn';
    printFrame.style.position = 'fixed';
    printFrame.style.width = '0';
    printFrame.style.height = '0';
    printFrame.style.border = 'none';
    printFrame.style.top = '-9999px';
    printFrame.style.left = '-9999px';
    document.body.appendChild(printFrame);
  }
  
  const printWindow = printFrame.contentWindow;
  const printDoc = printWindow.document;

  // Get current GRN data
  const grnData = grn.value;
  
  // Helper functions
  const escapeHtml = (text) => {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  };

  // Use i18n values from top-level setup (hooks already called at top level)
  const currentLangValue = locale.value || 'en';
  const dir = direction.value || 'ltr';
  const textAlignValue = isRTL.value ? 'right' : 'left';
  
  // Safe translation helper - prevents keys from leaking into PDF if translation is missing
  const safeT = (key) => {
    try {
      const value = t(key);
      // If vue-i18n returns the key itself (translation missing), return empty string
      return value === key ? '' : value;
    } catch (e) {
      return '';
    }
  };
  
  const formatDate = (date) => {
    if (!date) return 'N/A';
  try {
      const d = new Date(date);
      return d.toLocaleDateString(currentLangValue === 'ar' ? 'ar-SA' : 'en-US');
    } catch {
      return String(date);
    }
  };
  
  const formatDateTime = (date) => {
    if (!date) return 'N/A';
    try {
      const d = new Date(date);
      return d.toLocaleString(currentLangValue === 'ar' ? 'ar-SA' : 'en-US');
    } catch {
      return String(date);
    }
  };
  
  const formatPrintDateTime = () => {
    const now = new Date();
    return {
      printDate: now.toLocaleDateString(currentLangValue === 'ar' ? 'ar-SA' : 'en-US'),
      printTime: now.toLocaleTimeString(currentLangValue === 'ar' ? 'ar-SA' : 'en-US')
    };
  };

  // Normalize status before translation (database stores 'passed'/'pending', UI uses 'approved'/'under_inspection')
  const normalizeStatus = (status) => {
    if (!status) return 'draft';
    let normalized = status.toLowerCase();
    if (normalized === 'pending') normalized = 'under_inspection';
    if (normalized === 'passed') normalized = 'approved';
    return normalized;
  };

  const translateStatus = (status) => {
    const normalizedStatus = normalizeStatus(status);
    try {
      const translated = t(`status.${normalizedStatus}`);
      // If translation returns the key (missing translation), use formatStatus fallback
      if (translated === `status.${normalizedStatus}`) {
        return formatStatus(normalizedStatus);
      }
      return translated;
    } catch (e) {
      return formatStatus(normalizedStatus);
    }
  };

  // Get formatted values
  const grnNumber = escapeHtml(grnData?.grnNumber || grnData?.grn_number || 'Draft');
  const grnDate = formatDate(grnData?.grnDate || grnData?.grn_date);
  const poRef = formatPurchaseOrderReference(grnData);
  const supplierName = formatSupplierDisplay(grnData?.supplier);
  const receivingLocation = escapeHtml(grnData?.receivingLocation || grnData?.receiving_location || 'N/A');
  const receivedBy = escapeHtml(grnData?.receivedBy || grnData?.received_by || 'N/A');
  const supplierInvoiceNumber = escapeHtml(grnData?.supplierInvoiceNumber || grnData?.supplier_invoice_number || 'N/A');
  const deliveryNoteNumber = escapeHtml(grnData?.deliveryNoteNumber || grnData?.delivery_note_number || 'N/A');
  // Get QC Checked By - check batches if not in GRN
  let qcCheckedBy = escapeHtml(grnData?.qcCheckedBy || grnData?.qc_checked_by || '');
  if (!qcCheckedBy && grnData?.batches && Array.isArray(grnData.batches)) {
    const checkedBatches = grnData.batches.filter(b => b && (b.qcCheckedBy || b.qc_checked_by));
    if (checkedBatches.length > 0) {
      const uniqueUsers = new Set();
      checkedBatches.forEach(b => {
        const user = b.qcCheckedBy || b.qc_checked_by;
        if (user) uniqueUsers.add(user);
      });
      if (uniqueUsers.size > 0) {
        qcCheckedBy = Array.from(uniqueUsers).join(', ');
      }
    }
  }
  qcCheckedBy = qcCheckedBy || 'N/A';
  
  const approvedBy = escapeHtml(grnData?.approvedBy || grnData?.approved_by || 'N/A');
  const approvedAt = (grnData?.approvedAt || grnData?.approved_at) ? formatDateTime(grnData.approvedAt || grnData.approved_at) : null;
  const externalReferenceId = escapeHtml(grnData?.externalReferenceId || grnData?.external_reference_id || 'N/A');
  const createdAt = (grnData?.createdAt || grnData?.created_at) ? formatDateTime(grnData.createdAt || grnData.created_at) : 'N/A';
  const status = grnData?.status || 'draft';
  const statusText = translateStatus(status);
  const numberOfItems = (grnData?.items || []).length;
  const numberOfBatches = (grnData?.batches || []).length;
  
  // Current date and time
  const { printDate, printTime } = formatPrintDateTime();

  // Build print document
  printDoc.open();
  printDoc.write('<!DOCTYPE html>');
  
  const htmlEl = printDoc.createElement('html');
  htmlEl.setAttribute('lang', currentLangValue);
  htmlEl.setAttribute('dir', dir);
  
  const headEl = printDoc.createElement('head');
  const meta1 = printDoc.createElement('meta');
  meta1.setAttribute('charset', 'UTF-8');
  const meta2 = printDoc.createElement('meta');
  meta2.setAttribute('name', 'viewport');
  meta2.setAttribute('content', 'width=device-width, initial-scale=1.0');
  const titleEl = printDoc.createElement('title');
  titleEl.textContent = 'GRN - ' + grnNumber;
  const scriptEl = printDoc.createElement('script');
  scriptEl.setAttribute('src', 'https://cdn.tailwindcss.com');
  
  // Print-optimized CSS
  const styleEl = printDoc.createElement('style');
  styleEl.textContent = '@page { size: A4; margin: 20mm 15mm; } @media print { * { -webkit-print-color-adjust: exact; print-color-adjust: exact; } link[rel="icon"], link[rel="shortcut icon"], svg:not([src]), .icon, .material-icons { display: none !important; } body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; font-size: 12px; line-height: 1.5; color: #111827; background: white; } .print-container { width: 100%; max-width: 100%; margin: 0; padding: 0; } } body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; font-size: 12px; line-height: 1.5; color: #111827; background: white; margin: 0; padding: 0; } .print-container { width: 100%; max-width: 100%; margin: 0 auto; padding: 0; }';
  
  headEl.appendChild(meta1);
  headEl.appendChild(meta2);
  headEl.appendChild(titleEl);
  headEl.appendChild(scriptEl);
  headEl.appendChild(styleEl);
  htmlEl.appendChild(headEl);
  
  const bodyEl = printDoc.createElement('body');
  const container = printDoc.createElement('div');
  container.className = 'print-container';
  
  // Build HTML content
  const parts = [];
  
  // TOP BAR: Date/Time left, System Name right
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid #d1d5db;">');
  parts.push('<div style="font-size: 11px; color: #6b7280;">' + printDate + ', ' + printTime + '</div>');
  parts.push('<div style="font-size: 11px; color: #6b7280; font-weight: 600;">' + safeT('inventory.grn.title') + ' – Sakura ERP</div>');
  parts.push('</div>');
  
  // HEADER: Centered logo
  const logoUrl = window.location.origin + '/Sakura_Pink_Logo.png';
  parts.push('<div style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #d1d5db; background: white;">');
  parts.push('<img src="' + logoUrl + '" alt="Sakura Logo" style="height: 80px; max-width: 200px; margin: 0 auto; display: block; object-fit: contain; background: white;" />');
  parts.push('</div>');
  
  // TITLE ROW: GRN Number left, Status right
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">');
  parts.push('<div><h2 style="font-size: 18px; font-weight: 700; color: #111827; margin: 0;">' + safeT('inventory.grn.title') + ' (' + grnNumber + ')</h2></div>');
  parts.push('<div><span style="padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: #f3f4f6; color: #374151;">' + statusText + '</span></div>');
  parts.push('</div>');
  
  // DETAILS SECTION: Two-column layout with borders
  const alignStyle = 'text-align: ' + textAlignValue + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.date') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + grnDate + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.poReference') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + poRef + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.suppliers.title') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + supplierName + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.receivingLocation') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + receivingLocation + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.receivedBy') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + receivedBy + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.supplierInvoiceNumber') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + supplierInvoiceNumber + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.deliveryNoteNumber') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + deliveryNoteNumber + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.qcCheckedBy') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + qcCheckedBy + '</div></div>');
  if (status === 'approved' && approvedBy !== 'N/A') {
    parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.approvedBy') + '</div><div style="font-size: 13px; color: #059669; font-weight: 600; ' + alignStyle + '">' + approvedBy + (approvedAt ? ' (' + approvedAt + ')' : '') + '</div></div>');
  }
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.externalReferenceId') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + externalReferenceId + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('common.createdAt') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + createdAt + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.numberOfItems') + '</div><div style="font-size: 13px; color: #111827; font-weight: 600; ' + alignStyle + '">' + numberOfItems + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.grn.numberOfBatches') + '</div><div style="font-size: 13px; color: #111827; font-weight: 600; ' + alignStyle + '">' + numberOfBatches + '</div></div>');
  parts.push('</div>');
  
  // ITEMS SECTION: Table
  const thAlign = 'text-align: ' + textAlignValue + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">' + safeT('inventory.items.items') + '</h3>');
  parts.push('<table style="width: 100%; border-collapse: collapse;">');
  parts.push('<thead>');
  parts.push('<tr style="background-color: #f9fafb;">');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.items.name') + '</th>');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.items.sku') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.items.storageUnit') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.orderedQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.grn.receivedQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.grn.packagingType') + '</th>');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.grn.inspection') + '</th>');
  parts.push('</tr>');
  parts.push('</thead>');
  parts.push('<tbody>');
  
  // Helper function to get item name (same logic as component)
  const getItemNameForPrint = (item) => {
    if (typeof item === 'object' && item.item) {
      return item.item.name || 'N/A';
    }
    if (typeof item === 'object' && item.itemId) {
      const invItem = inventoryItems.value.find(i => i.id === item.itemId);
      return invItem?.name || 'N/A';
    }
    return item?.name || 'N/A';
  };

  // Helper function to get item SKU (same logic as component)
  const getItemSKUForPrint = (item) => {
    if (typeof item === 'object' && item.item) {
      return item.item.sku || 'N/A';
    }
    if (typeof item === 'object' && item.itemId) {
      const invItem = inventoryItems.value.find(i => i.id === item.itemId);
      return invItem?.sku || 'N/A';
    }
    return item?.sku || 'N/A';
  };

  // Helper function to get item localized name
  const getItemNameLocalizedForPrint = (item) => {
    if (typeof item === 'object' && item.item) {
      return item.item.nameLocalized || '';
    }
    if (typeof item === 'object' && item.itemId) {
      const invItem = inventoryItems.value.find(i => i.id === item.itemId);
      return invItem?.nameLocalized || '';
    }
    return item?.nameLocalized || '';
  };

  // Build items rows
  const items = grnData?.items || [];
  items.forEach(item => {
    const itemName = escapeHtml(getItemNameForPrint(item));
    const itemNameLocalized = getItemNameLocalizedForPrint(item);
    const itemNameLocalizedHtml = itemNameLocalized ? '<br><span style="color: #6b7280; font-size: 0.875rem;">' + escapeHtml(itemNameLocalized) + '</span>' : '';
    const sku = escapeHtml(getItemSKUForPrint(item));
    // Get unit from database - never hardcode
    const unit = getItemUnit(item) || item.unit || '';
    const orderedQty = item.orderedQuantity || item.ordered_quantity || 0;
    const receivedQty = item.receivedQuantity || item.received_quantity || 0;
    const packagingType = escapeHtml(item.packagingType || item.packaging_type || 'N/A');
    const inspectionResult = formatInspectionResult(item.visualInspectionResult || item.visual_inspection_result);
    
    parts.push('<tr>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + itemName + itemNameLocalizedHtml + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + sku + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; text-align: right; border-bottom: 1px solid #e5e7eb;">' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; text-align: right; border-bottom: 1px solid #e5e7eb;">' + orderedQty + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + receivedQty + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + packagingType + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + inspectionResult + '</td>');
    parts.push('</tr>');
  });
  
  if (items.length === 0) {
    parts.push('<tr><td colspan="7" style="padding: 32px 16px; text-align: center; color: #6b7280;">' + safeT('common.noItemsFound') + '</td></tr>');
  }
  
  parts.push('</tbody>');
  parts.push('</table>');
  parts.push('</div>');
  
  // BATCHES SECTION: ISO 22000 Batch Details
  const batches = grnData?.batches || [];
  if (batches.length > 0) {
    parts.push('<div style="margin-bottom: 24px; page-break-inside: avoid;">');
    parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">' + safeT('inventory.grn.batches') + ' (ISO 22000 Compliant)</h3>');
    parts.push('<table style="width: 100%; border-collapse: collapse;">');
    parts.push('<thead>');
    parts.push('<tr style="background-color: #f9fafb;">');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.batchId') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.items.items') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.expiryDate') + '</th>');
    parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.batchQuantity') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.storageLocation') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.vendorBatchNumber') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('inventory.grn.qcStatus') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('common.createdBy') + '</th>');
    parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + t('common.createdAt') + '</th>');
    parts.push('</tr>');
    parts.push('</thead>');
    parts.push('<tbody>');
    
    batches.forEach(batch => {
      const batchId = escapeHtml(batch.batch_number || batch.batchNumber || '—');
      const batchItemId = batch.itemId || batch.item_id;
      const batchItem = batch.item || inventoryItems.value.find(i => i.id === batchItemId);
      const batchItemName = escapeHtml(batchItem?.name || 'N/A');
      const batchItemSKU = escapeHtml(batchItem?.sku || 'N/A');
      const batchItemDisplay = batchItemName + ' (' + batchItemSKU + ')';
      const expiryDate = formatDate(batch.expiryDate || batch.expiry_date);
      const batchQty = getBatchQuantity(batch);
      const storageLocation = escapeHtml((batch.storageLocation || batch.storage_location) || safeNotAvailable());
      const vendorBatchNumber = escapeHtml((batch.vendorBatchNumber || batch.vendor_batch_number) || safeNotAvailable());
      const qcStatus = batch.qcStatus || batch.qc_status || 'pending';
      const qcStatusText = qcStatus.charAt(0).toUpperCase() + qcStatus.slice(1);
      const qcStatusColor = qcStatus === 'approved' ? '#10b981' : qcStatus === 'rejected' ? '#ef4444' : '#f59e0b';
      const createdBy = escapeHtml(getBatchCreatedByDisplay(batch));
      const createdDate = formatDate(batch.createdAt || batch.created_at);
      
      parts.push('<tr>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + batchId + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + batchItemDisplay + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + expiryDate + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + batchQty + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + storageLocation + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + vendorBatchNumber + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; border-bottom: 1px solid #e5e7eb;"><span style="padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: ' + qcStatusColor + '20; color: ' + qcStatusColor + ';">' + qcStatusText + '</span></td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + createdBy + '</td>');
      parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; border-bottom: 1px solid #e5e7eb;">' + createdDate + '</td>');
      parts.push('</tr>');
    });
    
    parts.push('</tbody>');
    parts.push('</table>');
    parts.push('</div>');
  }
  
  // QC & INSPECTION SECTION: ISO 22000 QC Details
  if (batches.length > 0) {
    parts.push('<div style="margin-bottom: 24px; page-break-inside: avoid;">');
    parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">' + t('inventory.grn.qcInspectionDetails') + ' (ISO 22000)</h3>');
    
    batches.forEach((batch, index) => {
      const batchId = escapeHtml(batch.batch_number || batch.batchNumber || '—');
      const batchItemId = batch.itemId || batch.item_id;
      const batchItem = batch.item || inventoryItems.value.find(i => i.id === batchItemId);
      const batchItemName = escapeHtml(batchItem?.name || 'N/A');
      const batchItemSKU = escapeHtml(batchItem?.sku || 'N/A');
      const expiryDate = formatDate(batch.expiryDate || batch.expiry_date);
      const batchQty = getBatchQuantity(batch);
      const qcStatus = batch.qcStatus || batch.qc_status || 'pending';
      const qcStatusText = qcStatus.charAt(0).toUpperCase() + qcStatus.slice(1);
      const qcStatusColor = qcStatus === 'approved' ? '#10b981' : qcStatus === 'rejected' ? '#ef4444' : '#f59e0b';
      const qcData = batch.qcData || {};
      const visualCondition = escapeHtml(qcData.visualCondition || qcData.visual_condition || 'N/A');
      const packagingCondition = escapeHtml(qcData.packagingCondition || qcData.packaging_condition || 'N/A');
      const temperature = escapeHtml(qcData.temperature || 'N/A');
      const remarks = escapeHtml(qcData.remarks || 'N/A');
      const qcCheckedBy = escapeHtml(batch.qcCheckedBy || batch.qc_checked_by || 'N/A');
      const qcCheckedAt = batch.qcCheckedAt || batch.qc_checked_at ? formatDateTime(batch.qcCheckedAt || batch.qc_checked_at) : 'N/A';
      
      parts.push('<div style="margin-bottom: 16px; padding: 16px; border: 1px solid #e5e7eb; border-radius: 8px; background-color: #f9fafb;">');
      parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid #d1d5db;">');
      parts.push('<div style="font-size: 14px; font-weight: 600; color: #111827;">Batch: ' + batchId + '</div>');
      parts.push('<div><span style="padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: ' + qcStatusColor + '20; color: ' + qcStatusColor + ';">' + qcStatusText + '</span></div>');
      parts.push('</div>');
      
      parts.push('<div style="margin-bottom: 12px;">');
      parts.push('<div style="font-size: 12px; color: #6b7280; margin-bottom: 4px;">Item: ' + batchItemName + ' (' + batchItemSKU + ') | Expiry: ' + expiryDate + ' | Quantity: ' + batchQty + '</div>');
      parts.push('</div>');
      
      parts.push('<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px;">');
      parts.push('<div style="padding: 8px; background-color: white; border-radius: 4px;">');
      parts.push('<div style="font-size: 11px; font-weight: 600; color: #4b5563; margin-bottom: 4px;">Visual Condition</div>');
      parts.push('<div style="font-size: 12px; color: #111827;">' + visualCondition + '</div>');
      parts.push('</div>');
      parts.push('<div style="padding: 8px; background-color: white; border-radius: 4px;">');
      parts.push('<div style="font-size: 11px; font-weight: 600; color: #4b5563; margin-bottom: 4px;">Packaging Condition</div>');
      parts.push('<div style="font-size: 12px; color: #111827;">' + packagingCondition + '</div>');
      parts.push('</div>');
      parts.push('</div>');
      
      parts.push('<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px;">');
      parts.push('<div style="padding: 8px; background-color: white; border-radius: 4px;">');
      parts.push('<div style="font-size: 11px; font-weight: 600; color: #4b5563; margin-bottom: 4px;">Temperature (if applicable)</div>');
      parts.push('<div style="font-size: 12px; color: #111827;">' + temperature + '</div>');
      parts.push('</div>');
      parts.push('<div style="padding: 8px; background-color: white; border-radius: 4px;">');
      parts.push('<div style="font-size: 11px; font-weight: 600; color: #4b5563; margin-bottom: 4px;">Storage Location</div>');
      parts.push('<div style="font-size: 12px; color: #111827;">' + escapeHtml(batch.storageLocation || batch.storage_location || 'N/A') + '</div>');
      parts.push('</div>');
      parts.push('</div>');
      
      parts.push('<div style="padding: 8px; background-color: white; border-radius: 4px; margin-bottom: 12px;">');
      parts.push('<div style="font-size: 11px; font-weight: 600; color: #4b5563; margin-bottom: 4px;">Remarks</div>');
      parts.push('<div style="font-size: 12px; color: #111827;">' + remarks + '</div>');
      parts.push('</div>');
      
      if (qcCheckedBy !== 'N/A' || qcCheckedAt !== 'N/A') {
        parts.push('<div style="padding-top: 8px; border-top: 1px solid #e5e7eb; font-size: 11px; color: #6b7280;">');
        parts.push('QC Checked By: ' + qcCheckedBy + (qcCheckedAt !== 'N/A' ? ' | Checked At: ' + qcCheckedAt : ''));
        parts.push('</div>');
      }
      
      parts.push('</div>');
    });
    
    parts.push('</div>');
  }
  
  // FOOTER: System name left, Page number right
  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #6b7280;">');
  parts.push('<div>Sakura ERP Management System</div>');
  parts.push('<div>' + safeT('common.page') + ' 1 / 1</div>');
  parts.push('</div>');
  
  container.innerHTML = parts.join('');
  bodyEl.appendChild(container);
  htmlEl.appendChild(bodyEl);
  printDoc.appendChild(htmlEl);
  printDoc.close();

  // Wait for iframe content to load, then print directly
  const printContent = () => {
    try {
      printWindow.focus();
      printWindow.print();
    } catch (err) {
      console.error('Print error:', err);
      showNotification('Error printing document', 'error');
    }
  };

  // Wait for content to load
  if (printFrame.contentDocument.readyState === 'complete') {
    setTimeout(printContent, 300);
  } else {
    printFrame.onload = () => {
      setTimeout(printContent, 300);
    };
  }
};

onMounted(async () => {
  loadGRN();
  loadInventoryItems();
  const locs = await loadLocationsForGRN();
  if (locs && locs.length) {
    receivingLocationOptions.value = locs;
    storageLocations.value = locs;
  }
});
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

