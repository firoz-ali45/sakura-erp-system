<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.grn.title') }}</h1>
          <i class="fas fa-question-circle" style="color: #284b44;" cursor-pointer></i>
        </div>
        <div class="flex items-center gap-3">
          <div class="relative">
            <button 
              @click="toggleExportMenu"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-cloud"></i>
              <span>{{ $t('inventory.grn.export') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showExportMenu" class="dropdown-menu">
              <a href="#" @click.prevent="exportAllGRNs"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.grn.exportAll') }}</a>
              <a v-if="selectedGRNs.length > 0" href="#" @click.prevent="exportSelectedGRNs"><i class="fas fa-download mr-2 text-[#284b44]"></i>{{ $t('inventory.grn.exportSelected') }}</a>
            </div>
          </div>
          <div class="relative">
            <button 
              @click="toggleImportMenu"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-upload"></i>
              <span>{{ $t('inventory.grn.import') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showImportMenu" class="dropdown-menu">
              <a href="#" @click.prevent="openImportModal"><i class="fas fa-file-upload mr-2 text-[#284b44]"></i>{{ $t('inventory.grn.importFromExcel') }}</a>
              <a href="#" @click.prevent="downloadTemplate"><i class="fas fa-file-download mr-2 text-green-600"></i>{{ $t('inventory.grn.downloadExcelTemplate') }}</a>
            </div>
          </div>
          <button 
            @click="openReviewAndFinalizeModal"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            :title="$t('inventory.grn.reviewAndFinalize')"
          >
            <i class="fas fa-check-double"></i>
            <span>{{ $t('inventory.grn.reviewAndFinalize') }}</span>
          </button>
          <button 
            @click="openCreateGRNModal"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
            style="background-color: #284b44; color: white;"
          >
            <i class="fas fa-plus"></i>
            <span>{{ $t('inventory.grn.create') }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Tabs and Filter -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex gap-6 border-b border-gray-200">
          <button 
            @click="switchTab('all')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'all' }]"
          >
            {{ $t('common.all') }}
          </button>
          <button 
            @click="switchTab('draft')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'draft' }]"
          >
            {{ $t('status.draft') }}
          </button>
          <button 
            @click="switchTab('under_inspection')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'under_inspection' }]"
          >
            {{ $t('status.under_inspection') }}
          </button>
          <button 
            @click="switchTab('approved')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'approved' }]"
          >
            {{ $t('status.approved') }}
          </button>
          <button 
            @click="switchTab('rejected')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'rejected' }]"
          >
            {{ $t('status.rejected') }}
          </button>
        </div>
        <div class="flex items-center gap-3">
          <button 
            @click="hasActiveFilters ? clearFilter() : openFilter()" 
            :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', hasActiveFilters ? 'border-gray-300' : 'border-gray-300 hover:bg-gray-50']"
            :style="hasActiveFilters ? { backgroundColor: '#f0e1cd', borderColor: '#956c2a', color: '#284b44' } : {}"
          >
            <i :class="hasActiveFilters ? 'fas fa-times-circle' : 'fas fa-filter'"></i>
            <span>{{ hasActiveFilters ? $t('inventory.grn.clearFilter') : $t('common.filter') }}</span>
            <span v-if="hasActiveFilters" class="ml-1 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center" style="background-color: #284b44;">
              {{ activeFiltersCount }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <!-- GRNs Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.grnNumberHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.grnDateHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.purchaseOrderHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.supplierHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.receivingLocationHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.statusHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.receivedByHeader') }}</th>
              <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', textAlign]">{{ $t('inventory.grn.actionsHeader') }}</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <!-- Loading Skeleton -->
            <tr v-if="loading" v-for="n in 5" :key="'skeleton-' + n" class="animate-pulse">
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-6 w-20 bg-gray-200 rounded-full sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
              <td class="px-6 py-4">
                <div class="h-4 w-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
            </tr>
            <!-- Empty State -->
            <tr v-else-if="!loading && paginatedGRNs.length === 0" class="hover:bg-gray-50">
              <td colspan="8" class="px-6 py-8 text-center text-gray-500">
                No GRNs found
              </td>
            </tr>
            <!-- Data Rows -->
            <tr 
              v-else 
              v-for="grn in paginatedGRNs" 
              :key="grn.id" 
              class="hover:bg-gray-50 cursor-pointer transition-colors"
              @click="viewGRN(grn)"
            >
              <td :class="['px-6 py-4 text-sm text-gray-900 font-medium', textAlign]">
                <span v-if="grn.grnNumber || grn.grn_number">{{ grn.grnNumber || grn.grn_number }}</span>
                <span v-else class="text-gray-400 italic">Draft</span>
              </td>
              <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ formatDate(grn.grnDate || grn.grn_date) }}</td>
              <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ formatPurchaseOrderReference(grn) }}</td>
              <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ formatSupplierDisplay(grn.supplier) }}</td>
              <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ grn.receivingLocation || grn.receiving_location || 'N/A' }}</td>
              <td :class="['px-6 py-4 text-sm', textAlign]">
                <span 
                  :class="[
                    'px-2 py-1 rounded-full text-xs font-semibold',
                    getStatusClass(grn.status || 'draft')
                  ]"
                >
                  {{ formatStatus(grn.status || 'draft') }}
                </span>
              </td>
              <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ grn.receivedBy || grn.received_by || 'N/A' }}</td>
              <td :class="['px-6 py-4 text-sm', textAlign]" @click.stop>
                <div class="relative">
                  <button @click.stop="toggleGRNMenu(grn.id)" class="text-gray-600 hover:text-gray-800">
                    <i class="fas fa-ellipsis-v"></i>
                  </button>
                  <div v-if="activeGRNActions === grn.id" class="dropdown-menu" @click.stop>
                    <a @click.stop="viewGRN(grn)" class="cursor-pointer"><i class="fas fa-eye mr-2 text-[#284b44]"></i>{{ $t('common.view') }}</a>
                    <a v-if="grn.status === 'draft'" @click.stop="editGRN(grn)" class="cursor-pointer"><i class="fas fa-edit mr-2 text-green-600"></i>Edit</a>
                    <a href="#" @click.prevent="deleteGRN(grn)"><i class="fas fa-trash mr-2 text-red-600"></i>Delete</a>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="mt-4 flex justify-between items-center bg-white rounded-lg shadow-md p-4">
      <div class="text-sm text-gray-700">
        Showing {{ (currentPage - 1) * limit + 1 }} to {{ Math.min(currentPage * limit, filteredGRNs.length) }} of {{ filteredGRNs.length }} GRNs
      </div>
      <div class="flex gap-2">
        <button 
          @click="previousPage"
          :disabled="currentPage === 1"
          :class="['px-4 py-2 rounded-lg', currentPage === 1 ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          {{ $t('common.previous') }}
        </button>
        <button 
          @click="nextPage"
          :disabled="currentPage === totalPages"
          :class="['px-4 py-2 rounded-lg', currentPage === totalPages ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          {{ $t('common.next') }}
        </button>
      </div>
    </div>

    <!-- Create/Edit GRN Modal -->
    <div v-if="showGRNModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeGRNModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl m-4 max-h-[90vh] overflow-y-auto" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">{{ editingGRN ? 'Edit GRN' : 'New GRN' }}</h2>
          <button @click.stop="closeGRNModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="saveGRN" @click.stop>
            <!-- GRN Header Fields -->
            <div class="grid grid-cols-2 gap-4 mb-6" @click.stop>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Purchase Order Reference
                  <span class="text-xs text-gray-500 ml-1">(Optional - For Market Purchase, leave blank)</span>
                </label>
                <select 
                  v-model="newGRN.purchaseOrderId" 
                  @click.stop
                  @change="onPurchaseOrderChange"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">None (Market Purchase)</option>
                  <option v-for="po in approvedPurchaseOrders" :key="po.id" :value="po.id">
                    {{ po.poNumber || po.po_number }} - {{ getSupplierName(po) }}
                  </option>
                </select>
                <p v-if="newGRN.purchaseOrderId" class="text-xs text-blue-600 mt-1">
                  <i class="fas fa-info-circle"></i> Only items from this PO can be added. Quantities must match PO.
                </p>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  GRN Date <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model="newGRN.grnDate" 
                  type="date"
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Supplier
                </label>
                <input 
                  v-model="newGRN.supplier" 
                  type="text"
                  readonly
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed"
                  style="pointer-events: none;"
                >
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Receiving Location <span class="text-red-500">*</span>
                </label>
                <select 
                  v-model="newGRN.receivingLocation" 
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="location in receivingLocations" :key="location" :value="location">
                    {{ location }}
                  </option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Supplier Invoice Number
                </label>
                <input 
                  v-model="newGRN.supplierInvoiceNumber" 
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Delivery Note Number
                </label>
                <input 
                  v-model="newGRN.deliveryNoteNumber" 
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Received By <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model="newGRN.receivedBy" 
                  type="text"
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  External Reference ID
                </label>
                <input 
                  v-model="newGRN.externalReferenceId" 
                  type="text"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                  placeholder="Foodics PO ID"
                >
              </div>
            </div>

            <!-- GRN Items Section -->
            <div class="mb-6" @click.stop>
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-semibold text-gray-800">Items</h3>
                <button 
                  type="button"
                  @click.stop="addGRNItem"
                  class="px-4 py-2 text-white rounded-lg text-sm"
                  style="pointer-events: auto; background-color: #284b44; color: white;"
                >
                  <i class="fas fa-plus mr-2"></i>Add Item
                </button>
              </div>
              
              <div class="overflow-x-auto" @click.stop>
                <table class="w-full border-collapse" @click.stop>
                  <thead class="bg-gray-50">
                    <tr>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.item') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.unit') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.orderedQty') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.receivedQty') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.packagingType') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.supplierLot') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.grn.inspection') }}</th>
                      <th class="px-4 py-2 text-center text-sm font-semibold text-gray-700 border border-gray-200">{{ $t('common.actions') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-if="newGRN.items.length === 0">
                      <td colspan="8" class="px-4 py-4 text-center text-gray-500 border border-gray-200">
                        No items added. Click "Add Item" to add items.
                      </td>
                    </tr>
                    <tr v-for="(item, index) in newGRN.items" :key="index" @click.stop>
                      <td class="px-4 py-2 border border-gray-200" @click.stop>
                        <select 
                          v-model="item.itemId"
                          @change="onItemChange(index)"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          :class="{
                            'border-yellow-400 bg-yellow-50': selectedPO && poItems.length > 0 && !poItems.find(pi => (pi.itemId || pi.item_id) === item.itemId && item.itemId)
                          }"
                          style="pointer-events: auto;"
                        >
                          <option value="">Choose Item...</option>
                          <!-- If PO selected, only show PO items -->
                          <template v-if="selectedPO && poItems.length > 0">
                            <option 
                              v-for="poItem in poItems" 
                              :key="poItem.itemId || poItem.item_id" 
                              :value="poItem.itemId || poItem.item_id"
                            >
                              {{ getItemNameFromId(poItem.itemId || poItem.item_id) }} ({{ getItemSKUFromId(poItem.itemId || poItem.item_id) }})
                            </option>
                          </template>
                          <!-- If no PO, show all items -->
                          <template v-else>
                            <option v-for="invItem in inventoryItems" :key="invItem.id" :value="invItem.id">
                              {{ invItem.name }}{{ invItem.nameLocalized ? ` /${invItem.nameLocalized}` : '' }} ({{ invItem.sku }})
                            </option>
                          </template>
                        </select>
                        <p v-if="selectedPO && poItems.length > 0" class="text-xs text-blue-600 mt-1">
                          <i class="fas fa-info-circle"></i> Only PO items available
                        </p>
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <input 
                          :value="getItemUnit(item.itemId)"
                          readonly
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed text-sm"
                          style="pointer-events: none;"
                        />
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <input 
                          v-model.number="item.orderedQuantity"
                          type="number" 
                          min="0" 
                          step="0.01"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        />
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <input 
                          v-model.number="item.receivedQuantity"
                          type="number" 
                          min="0" 
                          step="0.01"
                          required
                          @input="validateReceivedQuantity(index)"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          :class="{
                            'border-yellow-400 bg-yellow-50': selectedPO && Math.abs((item.receivedQuantity || 0) - (item.orderedQuantity || 0)) > 0.01
                          }"
                          style="pointer-events: auto;"
                        />
                        <p 
                          v-if="selectedPO && Math.abs((item.receivedQuantity || 0) - (item.orderedQuantity || 0)) > 0.01" 
                          class="text-xs text-yellow-600 mt-1"
                        >
                          <i class="fas fa-exclamation-triangle"></i> 
                          Received ({{ item.receivedQuantity || 0 }}) differs from Ordered ({{ item.orderedQuantity || 0 }})
                        </p>
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <select 
                          v-model="item.packagingType"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        >
                          <option value="">Select...</option>
                          <option value="Good">Good</option>
                          <option value="Damaged">Damaged</option>
                        </select>
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <input 
                          v-model="item.supplierLotNumber"
                          type="text"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        />
                      </td>
                      <td class="px-4 py-2 border border-gray-200 align-top" @click.stop>
                        <select 
                          v-model="item.visualInspectionResult"
                          @click.stop
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        >
                          <option value="">Pending</option>
                          <option value="pass">Pass</option>
                          <option value="fail">Fail</option>
                        </select>
                      </td>
                      <td class="px-4 py-2 border border-gray-200 text-center" @click.stop>
                        <button 
                          type="button"
                          @click.stop="removeGRNItem(index)"
                          class="text-red-600 hover:text-red-800 cursor-pointer inline-flex items-center justify-center"
                          style="pointer-events: auto;"
                        >
                          <i class="fas fa-trash"></i>
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closeGRNModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                style="pointer-events: auto;"
              >
                {{ $t('common.cancel') }}
              </button>
              <button 
                type="submit" 
                :disabled="saving"
                @click.stop
                class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                style="pointer-events: auto; background-color: #284b44; color: white;"
              >
                {{ saving ? 'Saving...' : (editingGRN ? 'Update' : 'Create') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Advanced Filter Modal -->
    <div v-if="showFilterModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeFilter">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center z-10">
          <h2 class="text-2xl font-bold text-gray-800">{{ $t('inventory.grn.filter.title') }}</h2>
          <button @click="closeFilter" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <!-- Text Input Fields with Including/Excluding -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.grnNumber') }}</label>
                <div class="flex gap-2">
                  <input 
                    v-model="tempFilterCriteria.grnNumber"
                    type="text"
                    :placeholder="$t('inventory.grn.filter.searchByGRNNumber') + '...'"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <select 
                    v-model="tempFilterCriteria.grnNumberMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.purchaseOrder') }}</label>
                <div class="flex gap-2">
                  <input 
                    v-model="tempFilterCriteria.purchaseOrder"
                    type="text"
                    :placeholder="$t('inventory.grn.filter.searchByPONumber') + '...'"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <select 
                    v-model="tempFilterCriteria.purchaseOrderMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Dropdown Selects with Including/Excluding -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.status') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.status"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ $t('inventory.purchaseOrders.filter.any') }}</option>
                    <option value="draft">{{ $t('status.draft') }}</option>
                    <option value="under_inspection">{{ $t('status.under_inspection') }}</option>
                    <option value="approved">{{ $t('status.approved') }}</option>
                    <option value="rejected">{{ $t('status.rejected') }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.statusMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.receivingLocation') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.receivingLocation"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ $t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="location in receivingLocations" :key="location" :value="location">{{ location }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.receivingLocationMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.supplier') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.supplierId"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ $t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">
                      {{ supplier.name }}{{ supplier.nameLocalized ? ` (${supplier.nameLocalized})` : '' }}
                    </option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.supplierMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.receivedBy') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.receivedBy"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ $t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.receivedByMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Date Fields -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.grnDateFrom') }}</label>
                <input 
                  v-model="tempFilterCriteria.grnDateFrom"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.grnDateTo') }}</label>
                <input 
                  v-model="tempFilterCriteria.grnDateTo"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.grn.filter.createdAfter') }}</label>
                <input 
                  v-model="tempFilterCriteria.createdAfter"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="flex justify-between items-center pt-6 mt-6 border-t">
            <button 
              @click="clearFilter"
              class="px-6 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              {{ $t('common.clear') }}
            </button>
            <div class="flex gap-3">
              <button 
                @click="closeFilter"
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                {{ $t('common.close') }}
              </button>
              <button 
                @click="applyFilter"
                class="px-6 py-2 text-white rounded-lg sakura-primary-btn"
              >
                {{ $t('common.apply') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Modal -->
    <div v-if="showImportModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeImportModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center z-10">
          <h2 class="text-2xl font-bold text-gray-800">Import GRNs from Excel</h2>
          <button @click="closeImportModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p class="text-sm text-blue-800">
                <i class="fas fa-info-circle mr-2"></i>
                <strong>Instructions:</strong> Download the Excel template, fill in the GRN data, and upload it here.
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Select Excel File</label>
              <input 
                type="file"
                ref="importFileInput"
                accept=".xlsx,.xls"
                @change="handleFileSelect"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              >
            </div>
            <div v-if="importPreview.length > 0" class="mt-4">
              <h3 class="text-lg font-semibold text-gray-800 mb-2">Preview ({{ importPreview.length }} rows)</h3>
              <div class="overflow-x-auto max-h-60 overflow-y-auto border border-gray-200 rounded-lg">
                <table class="w-full text-sm">
                  <thead class="bg-gray-50 sticky top-0">
                    <tr>
                      <th :class="['px-3 py-2 border-b', textAlign]">{{ $t('inventory.grn.grnNumber') }}</th>
                      <th :class="['px-3 py-2 border-b', textAlign]">{{ $t('inventory.grn.grnDate') }}</th>
                      <th :class="['px-3 py-2 border-b', textAlign]">{{ $t('inventory.grn.supplier') }}</th>
                      <th :class="['px-3 py-2 border-b', textAlign]">{{ $t('inventory.grn.status') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(row, idx) in importPreview.slice(0, 10)" :key="idx" class="border-b">
                      <td class="px-3 py-2">{{ row.grnNumber || 'N/A' }}</td>
                      <td class="px-3 py-2">{{ row.grnDate || 'N/A' }}</td>
                      <td class="px-3 py-2">{{ row.supplier || 'N/A' }}</td>
                      <td class="px-3 py-2">{{ row.status || 'N/A' }}</td>
                    </tr>
                  </tbody>
                </table>
                <p v-if="importPreview.length > 10" class="text-xs text-gray-500 p-2 text-center">
                  Showing first 10 rows of {{ importPreview.length }} total rows
                </p>
              </div>
            </div>
          </div>
          <div class="flex justify-end gap-3 pt-6 mt-6 border-t">
            <button 
              @click="closeImportModal"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button 
              @click="processImport"
              :disabled="importPreview.length === 0 || importing"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed sakura-primary-btn"
            >
              {{ importing ? 'Importing...' : 'Import GRNs' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Review & Finalize Modal -->
    <div v-if="showReviewModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeReviewModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center z-10">
          <h2 class="text-2xl font-bold text-gray-800">Review & Finalize GRNs</h2>
          <button @click="closeReviewModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <p class="text-sm text-yellow-800">
                <i class="fas fa-exclamation-triangle mr-2"></i>
                <strong>Review Mode:</strong> Review all GRNs before finalizing. This will lock GRNs for editing.
              </p>
            </div>
            <div class="overflow-x-auto">
              <table class="w-full">
                <thead class="bg-gray-50">
                  <tr>
                    <th :class="['px-4 py-2 text-sm font-semibold', textAlign]">{{ $t('inventory.grn.grnNumber') }}</th>
                    <th :class="['px-4 py-2 text-sm font-semibold', textAlign]">{{ $t('inventory.grn.date') }}</th>
                    <th :class="['px-4 py-2 text-sm font-semibold', textAlign]">{{ $t('inventory.grn.supplier') }}</th>
                    <th :class="['px-4 py-2 text-sm font-semibold', textAlign]">{{ $t('inventory.grn.status') }}</th>
                    <th :class="['px-4 py-2 text-sm font-semibold', textAlign]">{{ $t('common.actions') }}</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                  <tr v-for="grn in grnsForReview" :key="grn.id" class="hover:bg-gray-50">
                    <td class="px-4 py-2 text-sm">{{ getGRNDisplayNumber(grn) }}</td>
                    <td class="px-4 py-2 text-sm">{{ formatDate(grn.grnDate || grn.grn_date) }}</td>
                    <td class="px-4 py-2 text-sm">{{ getSupplierName(grn) }}</td>
                    <td class="px-4 py-2 text-sm">
                      <span :class="getStatusClass(grn.status)" class="px-2 py-1 rounded-full text-xs font-semibold">
                        {{ formatStatus(grn.status) }}
                      </span>
                    </td>
                    <td class="px-4 py-2 text-sm">
                      <button 
                        @click="viewGRN(grn)"
                        class="text-blue-600 hover:text-blue-800"
                      >
                        <i class="fas fa-eye"></i> View
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div class="flex justify-end gap-3 pt-6 mt-6 border-t">
            <button 
              @click="closeReviewModal"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button 
              @click="finalizeGRNs"
              :disabled="finalizing"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed sakura-primary-btn"
            >
              {{ finalizing ? 'Finalizing...' : 'Finalize All' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { 
  loadGRNsFromSupabase, 
  saveGRNToSupabase, 
  updateGRNInSupabase,
  deleteGRNFromSupabase,
  generateGRNNumber
} from '@/services/supabase';
import { loadPurchaseOrdersFromSupabase, loadSuppliersFromSupabase } from '@/services/supabase';
import { loadItemsFromSupabase } from '@/services/supabase';
import { useInventoryLocations } from '@/composables/useInventoryLocations';
import { showNotification } from '@/utils/notifications';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';

const router = useRouter();

// i18n support - using new enterprise system
const { t, locale, textAlign } = useI18n();

// State
const grns = ref([]);
const loading = ref(false);
const activeTab = ref('all');
const selectedGRNs = ref([]);
const showExportMenu = ref(false);
const showGRNModal = ref(false);
const editingGRN = ref(null);
const activeGRNActions = ref(null);
const saving = ref(false);
const currentPage = ref(1);
const limit = ref(50);
const purchaseOrders = ref([]);
const inventoryItems = ref([]);

// Filter criteria
const filterCriteria = ref({
  grnNumber: '',
  grnNumberMode: 'including',
  purchaseOrder: '',
  purchaseOrderMode: 'including',
  status: '',
  statusMode: 'including',
  receivingLocation: '',
  receivingLocationMode: 'including',
  supplierId: '',
  supplierMode: 'including',
  receivedBy: '',
  receivedByMode: 'including',
  grnDateFrom: '',
  grnDateTo: '',
  createdAfter: ''
});
const tempFilterCriteria = ref({
  grnNumber: '',
  grnNumberMode: 'including',
  purchaseOrder: '',
  purchaseOrderMode: 'including',
  status: '',
  statusMode: 'including',
  receivingLocation: '',
  receivingLocationMode: 'including',
  supplierId: '',
  supplierMode: 'including',
  receivedBy: '',
  receivedByMode: 'including',
  grnDateFrom: '',
  grnDateTo: '',
  createdAfter: ''
});
const showFilterModal = ref(false);

// Import/Export state
const showImportMenu = ref(false);
const showImportModal = ref(false);
const importFileInput = ref(null);
const importPreview = ref([]);
const importing = ref(false);
const suppliers = ref([]);
const availableUsers = ref([]);

// Review & Finalize state
const showReviewModal = ref(false);
const finalizing = ref(false);

// Receiving locations: from inventory_locations WHERE allow_grn = true (GRN destination)
const receivingLocations = ref([]);
const { loadLocationsForGRN } = useInventoryLocations();

// New GRN form
const newGRN = ref({
  purchaseOrderId: '',
  grnDate: new Date().toISOString().split('T')[0],
  supplier: '',
  receivingLocation: '',
  supplierInvoiceNumber: '',
  deliveryNoteNumber: '',
  receivedBy: '',
  qcCheckedBy: '',
  status: 'draft',
  externalReferenceId: '',
  items: []
});

// Computed
const approvedPurchaseOrders = computed(() => {
  return purchaseOrders.value.filter(po => 
    (po.status || '').toLowerCase() === 'approved'
  );
});

const filteredGRNs = computed(() => {
  let filtered = grns.value;
  
  // Tab filter
  if (activeTab.value === 'draft') {
    filtered = filtered.filter(g => (g.status || '').toLowerCase() === 'draft');
  } else if (activeTab.value === 'under_inspection') {
    filtered = filtered.filter(g => (g.status || '').toLowerCase() === 'under_inspection');
  } else if (activeTab.value === 'approved') {
    filtered = filtered.filter(g => (g.status || '').toLowerCase() === 'approved');
  } else if (activeTab.value === 'rejected') {
    filtered = filtered.filter(g => (g.status || '').toLowerCase() === 'rejected');
  }
  
  // Apply advanced filters
  const criteria = filterCriteria.value;
  
  // GRN Number filter
  if (criteria.grnNumber) {
    const grnNum = (criteria.grnNumber || '').toLowerCase();
    filtered = filtered.filter(g => {
      const grnNumber = (g.grnNumber || g.grn_number || '').toLowerCase();
      const matches = grnNumber.includes(grnNum);
      return criteria.grnNumberMode === 'including' ? matches : !matches;
    });
  }
  
  // Purchase Order filter
  if (criteria.purchaseOrder) {
    const poNum = (criteria.purchaseOrder || '').toLowerCase();
    filtered = filtered.filter(g => {
      const poId = g.purchaseOrderId || g.purchase_order_id;
      if (!poId) return criteria.purchaseOrderMode === 'excluding';
      const po = purchaseOrders.value.find(p => p.id === poId);
      const poNumber = (po?.poNumber || po?.po_number || '').toLowerCase();
      const matches = poNumber.includes(poNum);
      return criteria.purchaseOrderMode === 'including' ? matches : !matches;
    });
  }
  
  // Status filter
  if (criteria.status) {
    filtered = filtered.filter(g => {
      const matches = (g.status || '').toLowerCase() === criteria.status.toLowerCase();
      return criteria.statusMode === 'including' ? matches : !matches;
    });
  }
  
  // Receiving Location filter
  if (criteria.receivingLocation) {
    filtered = filtered.filter(g => {
      const location = (g.receivingLocation || g.receiving_location || '').toLowerCase();
      const matches = location === criteria.receivingLocation.toLowerCase();
      return criteria.receivingLocationMode === 'including' ? matches : !matches;
    });
  }
  
  // Supplier filter
  if (criteria.supplierId) {
    filtered = filtered.filter(g => {
      const supplierId = g.supplierId || g.supplier_id;
      const matches = supplierId === criteria.supplierId;
      return criteria.supplierMode === 'including' ? matches : !matches;
    });
  }
  
  // Received By filter
  if (criteria.receivedBy) {
    filtered = filtered.filter(g => {
      const receivedBy = (g.receivedBy || g.received_by || '').toLowerCase();
      const matches = receivedBy === criteria.receivedBy.toLowerCase();
      return criteria.receivedByMode === 'including' ? matches : !matches;
    });
  }
  
  // Date filters
  if (criteria.grnDateFrom) {
    const fromDate = new Date(criteria.grnDateFrom);
    filtered = filtered.filter(g => {
      const grnDate = new Date(g.grnDate || g.grn_date);
      return grnDate >= fromDate;
    });
  }
  
  if (criteria.grnDateTo) {
    const toDate = new Date(criteria.grnDateTo);
    toDate.setHours(23, 59, 59, 999);
    filtered = filtered.filter(g => {
      const grnDate = new Date(g.grnDate || g.grn_date);
      return grnDate <= toDate;
    });
  }
  
  if (criteria.createdAfter) {
    const afterDate = new Date(criteria.createdAfter);
    filtered = filtered.filter(g => {
      const createdDate = new Date(g.createdAt || g.created_at);
      return createdDate >= afterDate;
    });
  }
  
  return filtered;
});

const paginatedGRNs = computed(() => {
  const start = (currentPage.value - 1) * limit.value;
  return filteredGRNs.value.slice(start, start + limit.value);
});

const totalPages = computed(() => {
  return Math.ceil(filteredGRNs.value.length / limit.value);
});

const hasActiveFilters = computed(() => {
  const criteria = filterCriteria.value;
  return !!(
    criteria.grnNumber ||
    criteria.purchaseOrder ||
    criteria.status ||
    criteria.receivingLocation ||
    criteria.supplierId ||
    criteria.receivedBy ||
    criteria.grnDateFrom ||
    criteria.grnDateTo ||
    criteria.createdAfter
  );
});

const activeFiltersCount = computed(() => {
  let count = 0;
  const criteria = filterCriteria.value;
  if (criteria.grnNumber) count++;
  if (criteria.purchaseOrder) count++;
  if (criteria.status) count++;
  if (criteria.receivingLocation) count++;
  if (criteria.supplierId) count++;
  if (criteria.receivedBy) count++;
  if (criteria.grnDateFrom || criteria.grnDateTo) count++;
  if (criteria.createdAfter) count++;
  return count;
});

const grnsForReview = computed(() => {
  return filteredGRNs.value.filter(grn => 
    grn.status === 'approved' || grn.status === 'under_inspection'
  );
});

// Methods
const loadGRNs = async () => {
  loading.value = true;
  try {
    const data = await loadGRNsFromSupabase();
    grns.value = data || [];
    console.log('✔ GRNs loaded:', grns.value.length);
    
    // CRITICAL: Log GRN data to verify supplier_name and purchase_order_number are present
    if (grns.value.length > 0) {
      const sampleGRN = grns.value[0];
      console.log('📋 Sample GRN data:', {
        id: sampleGRN.id,
        grn_number: sampleGRN.grn_number || sampleGRN.grnNumber,
        purchase_order_id: sampleGRN.purchase_order_id || sampleGRN.purchaseOrderId,
        purchase_order_number: sampleGRN.purchase_order_number || sampleGRN.purchaseOrderReference,
        supplier_id: sampleGRN.supplier_id || sampleGRN.supplierId,
        supplier_name: sampleGRN.supplier_name || sampleGRN.supplier,
        status: sampleGRN.status
      });
      
      // Count GRNs with missing data
      const missingPONumber = grns.value.filter(g => !g.purchase_order_number && !g.purchaseOrderReference).length;
      const missingSupplier = grns.value.filter(g => !g.supplier_name && !g.supplier).length;
      if (missingPONumber > 0 || missingSupplier > 0) {
        console.warn(`⚠️ ${missingPONumber} GRNs missing PO number, ${missingSupplier} GRNs missing supplier name`);
      }
    }
  } catch (error) {
    console.error('❌ Error loading GRNs:', error);
    showNotification('Error loading GRNs', 'error');
  } finally {
    loading.value = false;
  }
};

const loadPurchaseOrders = async () => {
  try {
    const orders = await loadPurchaseOrdersFromSupabase();
    purchaseOrders.value = orders || [];
  } catch (error) {
    console.error('Error loading purchase orders:', error);
  }
};

const loadInventoryItems = async () => {
  try {
    const items = await loadItemsFromSupabase();
    inventoryItems.value = items.filter(i => !i.deleted);
  } catch (error) {
    console.error('Error loading inventory items:', error);
  }
};

const loadSuppliers = async () => {
  try {
    const { loadSuppliersFromSupabase } = await import('@/services/supabase');
    const supplierList = await loadSuppliersFromSupabase();
    suppliers.value = supplierList || [];
    
    // Extract unique users from GRNs
    const usersSet = new Set();
    grns.value.forEach(grn => {
      if (grn.receivedBy || grn.received_by) {
        usersSet.add(grn.receivedBy || grn.received_by);
      }
      if (grn.qcCheckedBy || grn.qc_checked_by) {
        usersSet.add(grn.qcCheckedBy || grn.qc_checked_by);
      }
    });
    availableUsers.value = Array.from(usersSet).sort();
  } catch (error) {
    console.error('Error loading suppliers:', error);
  }
};

const switchTab = (tab) => {
  activeTab.value = tab;
  currentPage.value = 1;
};

const formatDate = (date) => {
  if (!date) return 'N/A';
  return new Date(date).toLocaleDateString('en-GB');
};

const formatStatus = (status) => {
  const statusMap = {
    'draft': 'Draft',
    'under_inspection': 'Under Inspection',
    'approved': 'Approved',
    'rejected': 'Rejected'
  };
  return statusMap[status] || status;
};

// Function to format GRN display number based on status
const formatGRNDisplayNumber = (grn) => {
  if (!grn) return 'Draft';
  
  const status = (grn.status || '').toLowerCase();
  const grnNum = grn.grnNumber || grn.grn_number;
  
  // Draft status: Show only "Draft", no number
  if (status === 'draft') {
    return 'Draft';
  }
  
  // If GRN number exists and doesn't start with "DRAFT-", show it
  if (grnNum && grnNum !== '' && !grnNum.startsWith('DRAFT-')) {
    return grnNum;
  }
  
  // Otherwise show status
  return formatStatus(status);
};

const getStatusClass = (status) => {
  const classMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'under_inspection': 'bg-yellow-100 text-yellow-800',
    'approved': 'bg-green-100 text-green-800',
    'rejected': 'bg-red-100 text-red-800'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800';
};

const openCreateGRNModal = () => {
  editingGRN.value = null;
  newGRN.value = {
    purchaseOrderId: '',
    grnDate: new Date().toISOString().split('T')[0],
    supplier: '',
    receivingLocation: '',
    supplierInvoiceNumber: '',
    deliveryNoteNumber: '',
    receivedBy: '',
    qcCheckedBy: '',
    status: 'draft',
    externalReferenceId: '',
    items: []
  };
  showGRNModal.value = true;
};

const closeGRNModal = () => {
  showGRNModal.value = false;
  editingGRN.value = null;
};

const getSupplierName = (po) => {
  if (!po) return 'N/A';
  // Handle supplier as object
  if (typeof po.supplier === 'object' && po.supplier !== null) {
    return po.supplier.name || po.supplier.nameLocalized || 'N/A';
  }
  // Handle supplier as string
  return po.supplier || po.supplierName || 'N/A';
};

const formatSupplierDisplay = (supplier) => {
  // Handle null/undefined
  if (!supplier || supplier === null || supplier === undefined) {
    return 'N/A';
  }
  
  // If already a string, return it (but check if it's a JSON string)
  if (typeof supplier === 'string') {
    if (supplier === '' || supplier === 'null' || supplier === 'undefined' || supplier === 'N/A') {
    return 'N/A';
  }
    // If it's a string representation of an object (JSON), try to parse it
    if (supplier.trim().startsWith('{')) {
      try {
        const parsed = JSON.parse(supplier);
        if (parsed && typeof parsed === 'object') {
          // Use priority: name_localized || name || code
          return parsed.name_localized || parsed.nameLocalized || parsed.name || parsed.supplier_name || parsed.code || 'N/A';
        }
      } catch (e) {
        // Not valid JSON, return as string
        return String(supplier);
      }
    }
  return supplier;
  }
  
  // CRITICAL: If supplier is an object, extract name properly
  // Priority: name_localized || name || code
  if (typeof supplier === 'object' && supplier !== null) {
    // Use priority: name_localized || name || code
    const displayName = supplier.name_localized || 
                 supplier.nameLocalized || 
                       supplier.name || 
                 supplier.supplier_name || 
                 supplier.supplierName ||
                       supplier.code ||
                       null;
    
    if (displayName && displayName !== 'N/A' && displayName !== '' && displayName !== null && displayName !== 'null' && displayName !== 'undefined') {
      return String(displayName).trim();
  }
    
    // If object has id but no name, it's likely a relationship object - return N/A
    // This prevents showing the entire JSON object
    return 'N/A';
  }
  
    return 'N/A';
};

const formatPurchaseOrderReference = (grn) => {
  if (!grn) return 'N/A';
  
  // CRITICAL: Check multiple possible fields (database column is purchase_order_number)
  let poRef = grn.purchase_order_number ||  // Database column (snake_case)
              grn.purchaseOrderReference ||  // Frontend field (camelCase)
                grn.purchase_order_reference || 
                grn.poReference ||
              grn.po_reference ||
              grn.poNumber ||
              grn.po_number;
  
  // If still null, try to get from purchase_order_id by querying PO
  if ((!poRef || poRef === 'N/A' || poRef === '') && (grn.purchase_order_id || grn.purchaseOrderId)) {
    // This will be populated when GRN is loaded, but if missing, return the ID as fallback
    const poId = grn.purchase_order_id || grn.purchaseOrderId;
    if (poId) {
      // Try to find in purchaseOrders list if available
      const po = purchaseOrders.value?.find(p => String(p.id).trim() === String(poId).trim());
      if (po && (po.poNumber || po.po_number)) {
        poRef = po.poNumber || po.po_number;
      }
    }
  }
  
  if (poRef && poRef !== 'N/A' && poRef !== '' && poRef !== null) {
    // If it's an object, extract the PO number
    if (typeof poRef === 'object') {
      return poRef.poNumber || poRef.po_number || 'N/A';
    }
    return String(poRef);
  }
  
  // Final fallback: Show PO ID if available
  if (grn.purchase_order_id || grn.purchaseOrderId) {
    const poId = grn.purchase_order_id || grn.purchaseOrderId;
    return `PO-ID: ${String(poId).substring(0, 8)}...`;
  }
  
  return 'N/A';
};

// Store selected PO data for validation
const selectedPO = ref(null);
const poItems = ref([]);

const onPurchaseOrderChange = async () => {
  if (!newGRN.value.purchaseOrderId) {
    // Market Purchase - Clear PO data
    selectedPO.value = null;
    poItems.value = [];
    newGRN.value.supplier = '';
    newGRN.value.purchaseOrderReference = '';
    newGRN.value.purchase_order_reference = '';
    // Clear items if they were from PO
    if (newGRN.value.items.length > 0) {
      const confirmed = await showConfirmDialog({
        title: 'Clear Items?',
        message: 'Removing Purchase Order will clear all items. Do you want to continue?',
        confirmText: 'Yes, Clear',
        cancelText: 'Cancel',
        type: 'warning',
        icon: 'fas fa-exclamation-triangle'
      });
      if (confirmed) {
        newGRN.value.items = [];
      } else {
        // Restore PO selection
        // This will be handled by the user
      }
    }
    return;
  }
  
  // Load PO data
  const { getPurchaseOrderById } = await import('@/services/supabase');
  const poResult = await getPurchaseOrderById(newGRN.value.purchaseOrderId);
  
  if (poResult.success && poResult.data) {
    selectedPO.value = poResult.data;
    const po = poResult.data;
    
    // Extract supplier name properly
    const supplierName = getSupplierName(po);
    newGRN.value.supplier = supplierName;
    // Also store purchase order reference
    newGRN.value.purchaseOrderReference = po.poNumber || po.po_number || '';
    newGRN.value.purchase_order_reference = po.poNumber || po.po_number || '';
    
    // Load PO items for validation
    poItems.value = (po.items || []).map(item => ({
      itemId: item.itemId || item.item_id,
      item: item.item || item,
      quantity: item.quantity || 0,
      unitPrice: item.unitPrice || item.unit_price || 0
    }));
    
    // Auto-populate GRN items from PO
    newGRN.value.items = poItems.value.map(item => ({
      itemId: item.itemId,
      unit: getItemUnit(item.itemId),
      orderedQuantity: item.quantity,
      receivedQuantity: item.quantity, // Default to ordered quantity
      packagingType: '',
      supplierLotNumber: '',
      visualInspectionResult: ''
    }));
    
    showNotification('Items loaded from Purchase Order. You can adjust received quantities.', 'info');
  } else {
    showNotification('Purchase Order not found', 'error');
    newGRN.value.purchaseOrderId = '';
  }
};

// Get item unit from database - ALWAYS use database value, never hardcode
const getItemUnit = (itemId) => {
  if (!itemId) return '';
  const item = inventoryItems.value.find(i => i.id === itemId);
  if (item) {
    // Get unit from database - check storageUnit first, then ingredientUnit
    return item.storageUnit || item.storage_unit || item.ingredientUnit || item.ingredient_unit || '';
  }
  // Don't default to 'Pcs' - return empty if not found
  return '';
};

const getItemNameFromId = (itemId) => {
  if (!itemId) return 'N/A';
  const item = inventoryItems.value.find(i => i.id === itemId);
  if (item) {
    return item.name + (item.nameLocalized ? ` /${item.nameLocalized}` : '');
  }
  return 'N/A';
};

const getItemSKUFromId = (itemId) => {
  if (!itemId) return 'N/A';
  const item = inventoryItems.value.find(i => i.id === itemId);
  return item?.sku || 'N/A';
};

const onItemChange = (index) => {
  const item = newGRN.value.items[index];
  if (!item.itemId) return;
  
  // If PO is selected, validate item is from PO
  if (selectedPO.value && poItems.value.length > 0) {
    const poItem = poItems.value.find(pi => (pi.itemId || pi.item_id) === item.itemId);
    if (!poItem) {
      showNotification('This item is not in the selected Purchase Order. Only PO items can be added.', 'warning');
      // Reset item selection
      item.itemId = '';
      return;
    }
    
    // Auto-fill ordered quantity from PO
    item.orderedQuantity = poItem.quantity || 0;
    item.unit = getItemUnit(item.itemId);
  } else {
    // Market Purchase - no restrictions
    item.unit = getItemUnit(item.itemId);
  }
};

// Validate received quantity against ordered quantity
const validateReceivedQuantity = (index) => {
  const item = newGRN.value.items[index];
  if (!item.itemId) return;
  
  // If PO is selected, show warning if received quantity differs from ordered
  if (selectedPO.value && poItems.value.length > 0) {
    const poItem = poItems.value.find(pi => (pi.itemId || pi.item_id) === item.itemId);
    if (poItem) {
      const orderedQty = item.orderedQuantity || 0;
      const receivedQty = item.receivedQuantity || 0;
      
      if (Math.abs(receivedQty - orderedQty) > 0.01) {
        // Show warning but allow (user might receive more or less)
        console.warn(`Received quantity (${receivedQty}) differs from ordered quantity (${orderedQty})`);
      }
    }
  }
};

const addGRNItem = () => {
  newGRN.value.items.push({
    itemId: '',
    unit: '',
    orderedQuantity: 0,
    receivedQuantity: 0,
    packagingType: '',
    supplierLotNumber: '',
    visualInspectionResult: ''
  });
};

const removeGRNItem = (index) => {
  newGRN.value.items.splice(index, 1);
};

const saveGRN = async () => {
  saving.value = true;
  try {
    // Don't generate GRN number for draft - it will be generated when submitted for inspection
    // Initialize as empty string for draft status
    if (!editingGRN.value) {
      newGRN.value.grnNumber = '';
      newGRN.value.grn_number = '';
    }
    
    // Auto-fill "Received By" with current user if not set
    const getCurrentUserName = () => {
      if (window.user && window.user.name) {
        return window.user.name;
      }
      if (window.parent && window.parent.user && window.parent.user.name) {
        return window.parent.user.name;
      }
      return 'Current User';
    };
    
    if (!newGRN.value.receivedBy && !newGRN.value.received_by) {
      const currentUser = getCurrentUserName();
      newGRN.value.receivedBy = currentUser;
      newGRN.value.received_by = currentUser;
    }
    
    const result = editingGRN.value
      ? await updateGRNInSupabase(editingGRN.value.id, newGRN.value)
      : await saveGRNToSupabase(newGRN.value);
    
    if (result.success) {
      showNotification(editingGRN.value ? 'GRN updated successfully' : 'GRN created successfully', 'success');
      await loadGRNs();
      closeGRNModal();
    } else {
      throw new Error(result.error || 'Failed to save GRN');
    }
  } catch (error) {
    console.error('Error saving GRN:', error);
    showNotification('Error saving GRN: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const viewGRN = (grn) => {
  router.push(`/homeportal/grn-detail/${grn.id}`);
};

const editGRN = (grn) => {
  editingGRN.value = grn;
  newGRN.value = {
    purchaseOrderId: grn.purchaseOrderId || grn.purchase_order_id || '',
    grnDate: grn.grnDate || grn.grn_date || new Date().toISOString().split('T')[0],
    supplier: grn.supplier || '',
    receivingLocation: grn.receivingLocation || grn.receiving_location || '',
    supplierInvoiceNumber: grn.supplierInvoiceNumber || grn.supplier_invoice_number || '',
    deliveryNoteNumber: grn.deliveryNoteNumber || grn.delivery_note_number || '',
    receivedBy: grn.receivedBy || grn.received_by || '',
    qcCheckedBy: grn.qcCheckedBy || grn.qc_checked_by || '',
    status: grn.status || 'draft',
    externalReferenceId: grn.externalReferenceId || grn.external_reference_id || '',
    items: grn.items || []
  };
  showGRNModal.value = true;
};

const deleteGRN = async (grn) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete GRN',
    message: 'Are you sure you want to delete this GRN?',
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deleteGRNFromSupabase(grn.id);
    if (result.success) {
      showNotification('GRN deleted successfully', 'success');
      await loadGRNs();
    } else {
      throw new Error(result.error || 'Failed to delete GRN');
    }
  } catch (error) {
    console.error('Error deleting GRN:', error);
    showNotification('Error deleting GRN: ' + (error.message || 'Unknown error'), 'error');
  }
};

const toggleGRNMenu = (grnId) => {
  activeGRNActions.value = activeGRNActions.value === grnId ? null : grnId;
};

const toggleExportMenu = () => {
  showExportMenu.value = !showExportMenu.value;
};

const exportAllGRNs = () => {
  exportGRNs(filteredGRNs.value);
};

const exportSelectedGRNs = () => {
  const selected = grns.value.filter(g => selectedGRNs.value.includes(g.id));
  exportGRNs(selected);
};

const exportGRNs = (grnsToExport) => {
  const data = grnsToExport.map(grn => ({
    'GRN Number': grn.grnNumber || grn.grn_number || 'Draft',
    'GRN Date': formatDate(grn.grnDate || grn.grn_date),
    'Purchase Order': formatPurchaseOrderReference(grn),
    'Supplier': getSupplierName(grn),
    'Receiving Location': grn.receivingLocation || grn.receiving_location || 'N/A',
    'Status': formatStatus(grn.status),
    'Received By': grn.receivedBy || grn.received_by || 'N/A',
    'QC Checked By': grn.qcCheckedBy || grn.qc_checked_by || 'N/A',
    'Supplier Invoice': grn.supplierInvoiceNumber || grn.supplier_invoice_number || 'N/A',
    'Delivery Note': grn.deliveryNoteNumber || grn.delivery_note_number || 'N/A',
    'Created At': formatDate(grn.createdAt || grn.created_at)
  }));
  
  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'GRNs');
  XLSX.writeFile(wb, `grns_${new Date().toISOString().split('T')[0]}.xlsx`);
  
  showNotification('GRNs exported successfully', 'success');
  showExportMenu.value = false;
};

const toggleImportMenu = () => {
  showImportMenu.value = !showImportMenu.value;
};

const openImportModal = () => {
  showImportModal.value = true;
  showImportMenu.value = false;
  importPreview.value = [];
};

const closeImportModal = () => {
  showImportModal.value = false;
  importPreview.value = [];
  if (importFileInput.value) {
    importFileInput.value.value = '';
  }
};

const handleFileSelect = (event) => {
  const file = event.target.files[0];
  if (!file) return;
  
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = new Uint8Array(e.target.result);
      const workbook = XLSX.read(data, { type: 'array' });
      const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
      const jsonData = XLSX.utils.sheet_to_json(firstSheet);
      
      importPreview.value = jsonData.map(row => ({
        grnNumber: row['GRN Number'] || row['grnNumber'] || '',
        grnDate: row['GRN Date'] || row['grnDate'] || '',
        supplier: row['Supplier'] || row['supplier'] || '',
        status: row['Status'] || row['status'] || 'draft',
        receivingLocation: row['Receiving Location'] || row['receivingLocation'] || '',
        receivedBy: row['Received By'] || row['receivedBy'] || '',
        purchaseOrder: row['Purchase Order'] || row['purchaseOrder'] || '',
        rawData: row
      }));
      
      showNotification(`File loaded: ${jsonData.length} rows found`, 'success');
    } catch (error) {
      console.error('Error reading file:', error);
      showNotification('Error reading file. Please check the format.', 'error');
    }
  };
  reader.readAsArrayBuffer(file);
};

const processImport = async () => {
  if (importPreview.value.length === 0) {
    showNotification('No data to import', 'error');
    return;
  }
  
  importing.value = true;
  let successCount = 0;
  let errorCount = 0;
  
  try {
    for (const row of importPreview.value) {
      try {
        const grnData = {
          grnNumber: row.grnNumber || '',
          grnDate: row.grnDate || new Date().toISOString().split('T')[0],
          supplier: row.supplier || '',
          receivingLocation: row.receivingLocation || '',
          status: row.status || 'draft',
          receivedBy: row.receivedBy || '',
          items: []
        };
        
        const result = await saveGRNToSupabase(grnData);
        if (result.success) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (error) {
        console.error('Error importing GRN:', error);
        errorCount++;
      }
    }
    
    showNotification(
      `Import completed: ${successCount} successful, ${errorCount} failed`,
      successCount > 0 ? 'success' : 'error'
    );
    
    await loadGRNs();
    closeImportModal();
  } catch (error) {
    console.error('Error processing import:', error);
    showNotification('Error processing import', 'error');
  } finally {
    importing.value = false;
  }
};

const downloadTemplate = () => {
  const templateData = [
    {
      'GRN Number': 'GRN-000001',
      'GRN Date': '2025-12-21',
      'Purchase Order': 'PO-000001',
      'Supplier': 'Supplier Name',
      'Receiving Location': '',
      'Status': 'draft',
      'Received By': 'User Name',
      'QC Checked By': '',
      'Supplier Invoice': '',
      'Delivery Note': ''
    }
  ];
  
  const ws = XLSX.utils.json_to_sheet(templateData);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'GRN Template');
  XLSX.writeFile(wb, 'grn_import_template.xlsx');
  
  showNotification('Template downloaded successfully', 'success');
  showImportMenu.value = false;
};

const openReviewAndFinalizeModal = () => {
  showReviewModal.value = true;
};

const closeReviewModal = () => {
  showReviewModal.value = false;
};

const finalizeGRNs = async () => {
  finalizing.value = true;
  try {
    const grnsToFinalize = grnsForReview.value;
    let successCount = 0;
    let errorCount = 0;
    
    for (const grn of grnsToFinalize) {
      try {
        const updateData = {
          ...grn,
          finalized: true,
          finalizedAt: new Date().toISOString()
        };
        
        const result = await updateGRNInSupabase(grn.id, updateData);
        if (result.success) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (error) {
        console.error('Error finalizing GRN:', error);
        errorCount++;
      }
    }
    
    showNotification(
      `Finalized: ${successCount} successful, ${errorCount} failed`,
      successCount > 0 ? 'success' : 'error'
    );
    
    await loadGRNs();
    closeReviewModal();
  } catch (error) {
    console.error('Error finalizing GRNs:', error);
    showNotification('Error finalizing GRNs', 'error');
  } finally {
    finalizing.value = false;
  }
};

const openFilter = () => {
  tempFilterCriteria.value = JSON.parse(JSON.stringify(filterCriteria.value));
  showFilterModal.value = true;
};

const closeFilter = () => {
  showFilterModal.value = false;
};

const applyFilter = () => {
  filterCriteria.value = JSON.parse(JSON.stringify(tempFilterCriteria.value));
  currentPage.value = 1;
  closeFilter();
};

const clearFilter = () => {
  const emptyFilter = {
    grnNumber: '',
    grnNumberMode: 'including',
    purchaseOrder: '',
    purchaseOrderMode: 'including',
    status: '',
    statusMode: 'including',
    receivingLocation: '',
    receivingLocationMode: 'including',
    supplierId: '',
    supplierMode: 'including',
    receivedBy: '',
    receivedByMode: 'including',
    grnDateFrom: '',
    grnDateTo: '',
    createdAfter: ''
  };
  filterCriteria.value = JSON.parse(JSON.stringify(emptyFilter));
  tempFilterCriteria.value = JSON.parse(JSON.stringify(emptyFilter));
  currentPage.value = 1;
  if (showFilterModal.value) {
    closeFilter();
  }
};

const previousPage = () => {
  if (currentPage.value > 1) {
    currentPage.value--;
  }
};

const nextPage = () => {
  if (currentPage.value < totalPages.value) {
    currentPage.value++;
  }
};

onMounted(async () => {
  await loadGRNs();
  await loadPurchaseOrders();
  await loadInventoryItems();
  await loadSuppliers();
  receivingLocations.value = await loadLocationsForGRN();
});
</script>

<style scoped>
.tab-button {
  border-bottom: 2px solid transparent;
  transition: all 0.2s;
}

.tab-button.active {
  border-bottom-color: #284b44;
  color: #284b44;
  font-weight: 600;
}

.dropdown-menu {
  position: absolute;
  right: 0;
  top: 100%;
  margin-top: 0.5rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  min-width: 150px;
  z-index: 50;
}

.dropdown-menu a {
  display: block;
  padding: 0.75rem 1rem;
  color: #374151;
  text-decoration: none;
  transition: background-color 0.2s;
}

.dropdown-menu a:hover {
  background-color: #f3f4f6;
}

/* Sakura Green Loading Skeleton Animation */
@keyframes sakura-shimmer {
  0% {
    background-position: -1000px 0;
  }
  100% {
    background-position: 1000px 0;
  }
}

.sakura-skeleton {
  background: linear-gradient(
    90deg,
    #f3f4f6 0%,
    #e5e7eb 20%,
    #284b44 40%,
    #e5e7eb 60%,
    #f3f4f6 80%,
    #f3f4f6 100%
  );
  background-size: 1000px 100%;
  animation: sakura-shimmer 2s infinite;
  opacity: 0.7;
}
</style>

