<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <!-- Header Section -->
    <div class="flex justify-between items-center mb-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
          <i class="fas fa-arrow-left"></i>
          <span>Back</span>
        </button>
        <div class="flex items-center gap-3">
          <h1 class="text-3xl font-bold text-gray-800">
            Transfer Order {{ order?.toNumber || order?.to_number ? `(${order.toNumber || order.to_number})` : '(Draft)' }}
          </h1>
          <span 
            v-if="order"
            :class="[
              'px-3 py-1 rounded-full text-sm font-semibold',
              getStatusClass(order.status || 'draft')
            ]"
          >
            {{ formatStatus(order.status || 'draft') }}
          </span>
        </div>
      </div>
      <div class="flex flex-col md:flex-row items-stretch md:items-center gap-2 md:gap-3">
        <!-- Draft Status Actions -->
        <template v-if="orderStatus === 'draft'">
          <button 
            @click="deleteOrderPermanently" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-trash"></i>
            <span>Delete Permanently</span>
          </button>
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>Print</span>
          </button>
          <button 
            @click="editOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-edit"></i>
            <span>Edit</span>
          </button>
          <button 
            @click="submitForReview" 
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn"
          >
            <i class="fas fa-paper-plane"></i>
            <span>Submit For Review</span>
          </button>
        </template>
        
        <!-- Pending Status Actions -->
        <template v-else-if="orderStatus === 'pending'">
          <button 
            @click="declineOrder" 
            class="px-4 py-2 bg-white border border-red-300 rounded-lg hover:bg-red-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-times"></i>
            <span>Decline</span>
          </button>
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>Print</span>
          </button>
          <button 
            @click="acceptOrder" 
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn"
          >
            <i class="fas fa-check"></i>
            <span>Accept</span>
          </button>
        </template>
        
        <!-- Accepted Status Actions -->
        <template v-else-if="orderStatus === 'accepted'">
          <button 
            @click="declineOrder" 
            class="px-4 py-2 bg-white border border-red-300 rounded-lg hover:bg-red-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-times"></i>
            <span>Decline</span>
          </button>
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>Print</span>
          </button>
          <button 
            @click="sendItems" 
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn"
          >
            <i class="fas fa-paper-plane"></i>
            <span>Send Items</span>
          </button>
        </template>
        
        <!-- Declined/Closed Status - No Actions -->
        <template v-else-if="orderStatus === 'declined' || orderStatus === 'closed'">
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>Print</span>
          </button>
        </template>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="bg-white rounded-lg shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading transfer order details...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-white rounded-lg shadow-md p-6">
      <div class="text-center">
        <p class="text-red-600 mb-4">{{ error }}</p>
        <button @click="goBack" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
          ← Go Back
        </button>
      </div>
    </div>

    <!-- Order Details -->
    <div v-else-if="order">
      <!-- Order Information Card -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Warehouse</label>
              <p class="text-gray-900 font-medium">{{ order.warehouse || 'N/A' }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Business Date</label>
              <p class="text-gray-900 font-medium">{{ formatDate(order.businessDate || order.business_date) || '—' }}</p>
            </div>
            <div v-if="orderStatus === 'pending' || orderStatus === 'accepted'" class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Submitter</label>
              <p class="text-gray-900 font-medium">{{ order.submitter || order.creator || 'N/A' }}</p>
            </div>
            <div v-else class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Creator</label>
              <p class="text-gray-900 font-medium">{{ order.creator || 'N/A' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Created At</label>
              <p class="text-gray-900 font-medium">{{ formatDateTime(order.createdAt || order.created_at) }}</p>
            </div>
          </div>
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Destination</label>
              <p class="text-gray-900 font-medium">{{ order.destination || 'N/A' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Number of Items</label>
              <p class="text-gray-900 font-medium">{{ (order.items || []).length }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Items Section -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-800">Items</h2>
          <div class="flex items-center gap-3" v-if="orderStatus === 'draft' || orderStatus === 'pending'">
            <select 
              v-model="unitType"
              class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              <option value="storage">Storage Unit</option>
              <option value="ingredient">Ingredient Unit</option>
            </select>
            <button 
              @click="openEditQuantitiesModal"
              class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-edit"></i>
              <span>Edit Quantities</span>
            </button>
            <button 
              @click="openImportItemsModal"
              class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-upload"></i>
              <span>Import Items</span>
            </button>
            <button 
              @click="openAddItemsModal"
              class="px-4 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
            >
              <i class="fas fa-plus"></i>
              <span>Add Items</span>
            </button>
          </div>
        </div>
        
        <!-- Warning Message -->
        <div v-if="hasQuantityExceeded" class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          Transferred Quantity exceeds the Available Quantity
        </div>
        
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Name</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">SKU</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Quantity</th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Available Quantity</th>
                <th v-if="orderStatus === 'draft' || orderStatus === 'pending'" class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-if="!order.items || order.items.length === 0">
                <td :colspan="orderStatus === 'draft' || orderStatus === 'pending' ? 5 : 4" class="px-4 py-8 text-center text-gray-500">
                  No data to display!
                </td>
              </tr>
              <tr v-for="(item, index) in order.items || []" :key="index">
                <td class="px-4 py-3 text-sm text-gray-900">
                  {{ item.item?.name || 'N/A' }}
                  <span v-if="item.item?.nameLocalized" class="text-gray-500">
                    /{{ item.item.nameLocalized }}
                  </span>
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono">
                  {{ item.item?.sku || 'N/A' }}
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 font-semibold">
                  {{ formatQuantity(item.quantity || 0, item.item) }}
                </td>
                <td class="px-4 py-3 text-sm" :class="getAvailableQuantityClass(item)">
                  {{ formatAvailableQuantity(item) }}
                </td>
                <td v-if="orderStatus === 'draft' || orderStatus === 'pending'" class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    <button 
                      @click.stop="openUpdateItemModal(item, index)"
                      class="text-blue-600 hover:text-blue-800"
                      title="Edit Item"
                    >
                      <i class="fas fa-edit"></i>
                    </button>
                    <button 
                      @click.stop="deleteItemFromOrder(index)"
                      class="text-red-600 hover:text-red-800"
                      title="Delete Item"
                    >
                      <i class="fas fa-trash"></i>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Update Item Modal -->
    <div v-if="showUpdateItemModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeUpdateItemModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">
            Update Item: {{ updatingItem?.item?.name || 'N/A' }} {{ updatingItem?.item?.nameLocalized ? `/${updatingItem.item.nameLocalized}` : '' }} ({{ updatingItem?.item?.sku || 'N/A' }})
          </h2>
          <button @click="closeUpdateItemModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Quantity({{ getUnitLabel(updatingItem?.item) }}) <span class="text-red-500">*</span>
              </label>
              <input 
                v-model.number="updateItemForm.quantityKg"
                type="number" 
                min="0" 
                step="0.01"
                required
                @input="updateGramsFromKg"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              />
            </div>
            <div v-if="unitType === 'storage' && updatingItem?.item?.storageUnit?.toLowerCase().includes('kg')">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Quantity(Gram) <span class="text-red-500">*</span>
              </label>
              <input 
                v-model.number="updateItemForm.quantityGram"
                type="number" 
                min="0" 
                step="1"
                required
                @input="updateKgFromGrams"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              />
              <p class="text-xs text-gray-500 mt-1">1 {{ getUnitLabel(updatingItem?.item) }} = {{ getConversionFactor(updatingItem?.item) }} Gram</p>
            </div>
          </div>
          <div class="flex justify-between items-center mt-6 pt-4 border-t border-gray-200">
            <button 
              @click="deleteItemFromUpdateModal" 
              class="text-red-600 hover:text-red-800 font-medium"
            >
              Delete Item
            </button>
            <div class="flex gap-3">
              <button 
                @click="closeUpdateItemModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Close
              </button>
              <button 
                @click="saveUpdateItem" 
                class="px-6 py-2 text-white rounded-lg sakura-primary-btn"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Items Modal -->
    <div v-if="showAddItemsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeAddItemsModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden m-4 flex flex-col">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center z-10">
          <h2 class="text-xl font-bold text-gray-800">Add Items</h2>
          <button @click="closeAddItemsModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6 overflow-y-auto flex-1">
          <!-- Search Input -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Search Items
            </label>
            <div class="relative">
              <input 
                v-model="itemSearchQuery"
                type="text"
                placeholder="Search by name, SKU, or barcode..."
                class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                style="--tw-ring-color: #284b44;"
              />
              <i class="fas fa-search absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
            </div>
          </div>
          
          <!-- Items List -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              Items <i class="fas fa-info-circle text-gray-400 ml-1"></i>
            </label>
            <div class="border border-gray-300 rounded-lg max-h-96 overflow-y-auto">
              <div v-if="filteredAvailableItems.length === 0" class="p-8 text-center text-gray-500">
                <i class="fas fa-search text-4xl mb-2"></i>
                <p>No items found</p>
              </div>
              <div v-else class="divide-y divide-gray-200">
                <div
                  v-for="item in filteredAvailableItems"
                  :key="item.id"
                  @click="selectItemForAdd(item)"
                  :class="[
                    'p-4 cursor-pointer hover:bg-gray-50 transition-colors',
                    newItemForm.itemId === item.id ? 'bg-blue-50 border-l-4 border-blue-500' : ''
                  ]"
                >
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <div class="font-medium text-gray-900">
                        {{ item.name }}
                        <span v-if="item.nameLocalized" class="text-gray-500">
                          /{{ item.nameLocalized }}
                        </span>
                      </div>
                      <div class="text-sm text-gray-500 mt-1">
                        <span class="font-mono">{{ item.sku || 'N/A' }}</span>
                        <span v-if="item.barcode" class="ml-2">• Barcode: {{ item.barcode }}</span>
                      </div>
                      <div v-if="item.category" class="text-xs text-gray-400 mt-1">
                        Category: {{ item.category }}
                      </div>
                    </div>
                    <div class="ml-4">
                      <i v-if="newItemForm.itemId === item.id" class="fas fa-check-circle text-blue-600 text-xl"></i>
                      <i v-else class="fas fa-circle text-gray-300 text-xl"></i>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <p class="text-xs text-gray-500 mt-2">
              Showing {{ filteredAvailableItems.length }} of {{ availableItems.length }} items
            </p>
          </div>
          
          <div class="flex justify-end gap-3 mt-6 pt-4 border-t border-gray-200">
            <button 
              @click="closeAddItemsModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              @click="saveAddItem" 
              :disabled="!newItemForm.itemId"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed sakura-primary-btn"
            >
              Save
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Items Modal -->
    <div v-if="showImportItemsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeImportItemsModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">Import Items</h2>
          <button @click.stop="closeImportItemsModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <div class="space-y-4" @click.stop>
            <div @click.stop>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Choose File
              </label>
              <div class="flex items-center gap-3">
                <input 
                  ref="importFileInput"
                  type="file" 
                  accept=".xlsx,.xls,.csv"
                  @change="handleImportFileChange"
                  @click.stop
                  class="hidden"
                />
                <button 
                  type="button"
                  @click.stop="triggerFileInput"
                  class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                  style="pointer-events: auto;"
                >
                  Choose File
                </button>
                <span class="text-sm text-gray-600">{{ selectedFileName || 'No file chosen' }}</span>
              </div>
            </div>
            
            <div class="pt-2">
              <a 
                href="#" 
                @click.prevent="downloadImportTemplate"
                class="text-blue-600 hover:text-blue-800 underline text-sm"
                style="pointer-events: auto;"
              >
                Download Template
              </a>
            </div>
          </div>
          
          <div class="mt-6 pt-4 border-t border-gray-200 flex justify-end gap-3" @click.stop>
            <button 
              type="button"
              @click.stop="closeImportItemsModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
              style="pointer-events: auto;"
            >
              Close
            </button>
            <button 
              type="button"
              @click.stop="processImportFile" 
              :disabled="!importFileData || importingItems"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
              style="pointer-events: auto;"
            >
              {{ importingItems ? 'Importing...' : 'Save' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Edit Quantities Modal -->
    <div v-if="showEditQuantitiesModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeEditQuantitiesModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">Update Items Quantities</h2>
          <button @click.stop="closeEditQuantitiesModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <div class="space-y-4" @click.stop>
            <div 
              v-for="(item, index) in editQuantitiesForm.items" 
              :key="index"
              class="border border-gray-200 rounded-lg p-4"
              @click.stop
            >
              <div class="mb-3">
                <h3 class="font-semibold text-gray-800">
                  {{ item.item?.name || 'N/A' }}
                  <span v-if="item.item?.nameLocalized" class="text-gray-500">
                    /{{ item.item.nameLocalized }}
                  </span>
                  <span class="text-gray-500">({{ item.item?.sku || 'N/A' }})</span>
                </h3>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Quantity({{ getUnitLabel(item.item) }}) <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model.number="item.quantity"
                  @input="updateItemQuantity(index)"
                  @click.stop
                  type="number" 
                  min="0" 
                  step="0.01"
                  required
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                />
              </div>
            </div>
          </div>
          
          <div class="mt-6 pt-4 border-t border-gray-200 flex justify-end gap-3" @click.stop>
            <button 
              type="button"
              @click.stop="closeEditQuantitiesModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
              style="pointer-events: auto;"
            >
              Close
            </button>
            <button 
              type="button"
              @click.stop="saveEditQuantities" 
              :disabled="savingQuantities"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
              style="pointer-events: auto;"
            >
              {{ savingQuantities ? 'Saving...' : 'Save' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Edit Transfer Order Modal -->
    <div v-if="showEditModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeEditModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">Edit Transfer Order</h2>
          <button @click.stop="closeEditModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="saveEditOrder" @click.stop>
            <div class="grid grid-cols-2 gap-4 mb-6" @click.stop>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Warehouse <span class="text-red-500">*</span>
                </label>
                <select 
                  v-model="editForm.warehouse" 
                  required
                  @click.stop
                  @change="handleEditWarehouseChange"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="warehouse in availableWarehousesForEdit" :key="warehouse" :value="warehouse">
                    {{ warehouse }}
                  </option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Destination <span class="text-red-500">*</span>
                </label>
                <select 
                  v-model="editForm.destination" 
                  required
                  @click.stop
                  @change="handleEditDestinationChange"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="destination in availableDestinationsForEdit" :key="destination" :value="destination">
                    {{ destination }}
                  </option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">Business Date</label>
                <input 
                  :value="formatDate(order.businessDate || order.business_date) || '—'"
                  type="text"
                  readonly
                  disabled
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed"
                  style="pointer-events: none;"
                />
                <p class="text-xs text-gray-500 mt-1">Business Date is automatically set by the system when the transfer is completed</p>
              </div>
            </div>
            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closeEditModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                style="pointer-events: auto;"
              >
                Close
              </button>
              <button 
                type="submit" 
                :disabled="saving"
                @click.stop
                class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
                style="pointer-events: auto;"
              >
                {{ saving ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { getTransferOrderById, updateTransferOrderInSupabase, deleteTransferOrderFromSupabase, generateTONumber } from '@/services/supabase';
import { loadItemsFromSupabase } from '@/services/supabase';
import { showConfirmDialog } from '@/utils/confirmDialog';
import { showNotification } from '@/utils/notifications';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const order = ref(null);
const loading = ref(true);
const error = ref(null);
const showAddItemsModal = ref(false);
const showEditModal = ref(false);
const showEditQuantitiesModal = ref(false);
const showImportItemsModal = ref(false);
const showUpdateItemModal = ref(false);
const updatingItem = ref(null);
const updatingItemIndex = ref(-1);
const inventoryItems = ref([]);
const itemSearchQuery = ref('');
const saving = ref(false);
const savingQuantities = ref(false);
const importingItems = ref(false);
const importFileInput = ref(null);
const selectedFileName = ref('');
const importFileData = ref(null);
const unitType = ref('storage');

// Forms
const newItemForm = ref({
  itemId: '',
  quantity: 1
});

const transferSourceOptions = ref([]);
const transferDestOptions = ref([]);

const editForm = ref({
  warehouse: '',
  destination: '',
  businessDate: ''
});

const availableWarehousesForEdit = computed(() => {
  const list = transferSourceOptions.value;
  if (!editForm.value.destination) return list;
  return list.filter(w => w !== editForm.value.destination);
});

const availableDestinationsForEdit = computed(() => {
  const list = transferDestOptions.value;
  if (!editForm.value.warehouse) return list;
  return list.filter(d => d !== editForm.value.warehouse);
});

const editQuantitiesForm = ref({
  items: []
});

const updateItemForm = ref({
  quantityKg: 0,
  quantityGram: 0
});

// Computed
const orderStatus = computed(() => {
  return (order.value?.status || 'draft').toLowerCase();
});

const availableItems = computed(() => {
  if (!inventoryItems.value || inventoryItems.value.length === 0) return [];
  
  // Filter out items already in the order
  const existingItemIds = (order.value?.items || []).map(item => 
    item.itemId || item.item_id || item.item?.id
  ).filter(id => id);
  
  return inventoryItems.value.filter(item => !existingItemIds.includes(item.id));
});

const filteredAvailableItems = computed(() => {
  if (!itemSearchQuery.value || itemSearchQuery.value.trim() === '') {
    return availableItems.value;
  }
  
  const query = itemSearchQuery.value.toLowerCase().trim();
  
  return availableItems.value.filter(item => {
    const name = (item.name || '').toLowerCase();
    const nameLocalized = (item.nameLocalized || '').toLowerCase();
    const sku = (item.sku || '').toLowerCase();
    const barcode = (item.barcode || '').toLowerCase();
    const category = (item.category || '').toLowerCase();
    
    return name.includes(query) ||
           nameLocalized.includes(query) ||
           sku.includes(query) ||
           barcode.includes(query) ||
           category.includes(query);
  });
});

const hasQuantityExceeded = computed(() => {
  if (!order.value || !order.value.items) return false;
  
  return order.value.items.some(item => {
    const quantity = item.quantity || item.storage_quantity || item.ingredient_quantity || 0;
    const availableQty = item.available_quantity || item.availableQuantity || 0;
    return quantity > availableQty;
  });
});

// Methods
const loadOrder = async () => {
  loading.value = true;
  error.value = null;
  
  try {
    let orderId = route.params.id || route.query?.id;
    
    if (!orderId) {
      const currentView = window.currentView || '';
      const match = currentView.match(/id=([^&]+)/);
      if (match) {
        orderId = match[1];
      }
    }
    
    if (!orderId) {
      throw new Error('No transfer order ID provided');
    }
    
    const result = await getTransferOrderById(orderId);
    if (result.success && result.data) {
      order.value = result.data;
      
      // If items don't have nested item data, manually load item data
      if (order.value.items && order.value.items.length > 0) {
        const allItems = await loadItemsFromSupabase();
        order.value.items = order.value.items.map(toItem => {
          if (!toItem.item) {
            const itemId = toItem.item_id || toItem.itemId;
            const item = allItems.find(i => i.id === itemId);
            if (item) {
              toItem.item = item;
              // Ensure unit properties are available (check both camelCase and snake_case)
              if (!toItem.item.storageUnit && toItem.item.storage_unit) {
                toItem.item.storageUnit = toItem.item.storage_unit;
              }
              if (!toItem.item.ingredientUnit && toItem.item.ingredient_unit) {
                toItem.item.ingredientUnit = toItem.item.ingredient_unit;
              }
            }
          } else {
            // Ensure unit properties are available even if item exists
            if (!toItem.item.storageUnit && toItem.item.storage_unit) {
              toItem.item.storageUnit = toItem.item.storage_unit;
            }
            if (!toItem.item.ingredientUnit && toItem.item.ingredient_unit) {
              toItem.item.ingredientUnit = toItem.item.ingredient_unit;
            }
          }
          // Calculate available quantity (for now, using 0 as placeholder - should come from inventory system)
          toItem.available_quantity = toItem.available_quantity || 0;
          return toItem;
        });
      }
      
      console.log('✅ Transfer Order loaded:', order.value);
    } else {
      throw new Error('Transfer order not found');
    }
  } catch (err) {
    console.error('Error loading transfer order:', err);
    error.value = err.message || 'Failed to load transfer order';
  } finally {
    loading.value = false;
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

const goBack = () => {
  router.push('/homeportal/transfer-orders');
};

const formatStatus = (status) => {
  const statusMap = {
    'draft': 'Draft',
    'pending': 'Pending',
    'accepted': 'Accepted',
    'declined': 'Declined',
    'closed': 'Closed'
  };
  return statusMap[status] || status;
};

const getStatusClass = (status) => {
  const classMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'accepted': 'bg-green-100 text-green-800',
    'declined': 'bg-red-100 text-red-800',
    'closed': 'bg-gray-100 text-gray-800'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800';
};

const formatDate = (date) => {
  if (!date) return null;
  try {
    return new Date(date).toLocaleDateString('en-GB');
  } catch {
    return date;
  }
};

const formatDateTime = (date) => {
  if (!date) return '—';
  try {
    const d = new Date(date);
    return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric' }) + ', ' + 
           d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true }).toLowerCase();
  } catch {
    return date;
  }
};

// Get unit from database - ALWAYS use database value, never hardcode
const formatQuantity = (quantity, item) => {
  if (!item) return `${quantity}`;
  
  // Get unit from database based on unitType - check both camelCase and snake_case
  let unit = '';
  if (unitType.value === 'storage') {
    unit = item.storageUnit || item.storage_unit || '';
  } else {
    unit = item.ingredientUnit || item.ingredient_unit || '';
  }
  
  return unit ? `${quantity} ${unit}` : `${quantity}`;
};

// Get unit from database - ALWAYS use database value, never hardcode
const formatAvailableQuantity = (item) => {
  const availableQty = item.available_quantity || item.availableQuantity || 0;
  
  // Get unit from database based on unitType - check both camelCase and snake_case
  let unit = '';
  if (unitType.value === 'storage') {
    unit = item.item?.storageUnit || item.item?.storage_unit || '';
  } else {
    unit = item.item?.ingredientUnit || item.item?.ingredient_unit || '';
  }
  
  return unit ? `${availableQty} ${unit}` : `${availableQty}`;
};

const getAvailableQuantityClass = (item) => {
  const quantity = item.quantity || item.storage_quantity || item.ingredient_quantity || 0;
  const availableQty = item.available_quantity || item.availableQuantity || 0;
  if (quantity > availableQty) {
    return 'text-red-600 font-semibold';
  }
  return 'text-gray-700';
};

// Get unit from database - ALWAYS use database value, never hardcode
const getUnitLabel = (item) => {
  if (!item) return '';
  
  // Get unit from database based on unitType - check both camelCase and snake_case
  // IMPORTANT: Unit must come from database, not hardcoded
  if (unitType.value === 'storage') {
    return item.storageUnit || item.storage_unit || '';
  } else {
    return item.ingredientUnit || item.ingredient_unit || '';
  }
};

const getConversionFactor = (item) => {
  if (!item) return 1000;
  const unit = getUnitLabel(item).toLowerCase();
  if (unit.includes('kg')) return 1000;
  return 1;
};

const openUpdateItemModal = (item, index) => {
  updatingItem.value = item;
  updatingItemIndex.value = index;
  
  // Parse quantity based on unit type
  const quantity = item.quantity || item.storage_quantity || item.ingredient_quantity || 0;
  const unit = getUnitLabel(item.item).toLowerCase();
  
  if (unit.includes('kg')) {
    // If quantity is in kg, split into kg and grams
    const totalGrams = quantity * 1000;
    updateItemForm.value.quantityKg = Math.floor(totalGrams / 1000);
    updateItemForm.value.quantityGram = totalGrams % 1000;
  } else {
    // For other units, just use the quantity
    updateItemForm.value.quantityKg = quantity;
    updateItemForm.value.quantityGram = 0;
  }
  
  showUpdateItemModal.value = true;
};

const closeUpdateItemModal = () => {
  showUpdateItemModal.value = false;
  updatingItem.value = null;
  updatingItemIndex.value = -1;
  updateItemForm.value = { quantityKg: 0, quantityGram: 0 };
};

const updateGramsFromKg = () => {
  // When kg changes, keep grams the same but ensure they're within 0-999
  if (updateItemForm.value.quantityGram >= 1000) {
    const extraKg = Math.floor(updateItemForm.value.quantityGram / 1000);
    updateItemForm.value.quantityKg += extraKg;
    updateItemForm.value.quantityGram = updateItemForm.value.quantityGram % 1000;
  }
};

const updateKgFromGrams = () => {
  // When grams change, convert to kg if needed
  if (updateItemForm.value.quantityGram >= 1000) {
    const extraKg = Math.floor(updateItemForm.value.quantityGram / 1000);
    updateItemForm.value.quantityKg += extraKg;
    updateItemForm.value.quantityGram = updateItemForm.value.quantityGram % 1000;
  }
};

const saveUpdateItem = async () => {
  if (!updatingItem.value || updatingItemIndex.value === -1) return;
  
  try {
    const unit = getUnitLabel(updatingItem.value.item).toLowerCase();
    let finalQuantity = updateItemForm.value.quantityKg;
    
    if (unit.includes('kg')) {
      // Convert kg and grams to total quantity
      finalQuantity = updateItemForm.value.quantityKg + (updateItemForm.value.quantityGram / 1000);
    }
    
    const items = [...(order.value.items || [])];
    const itemToUpdate = items[updatingItemIndex.value];
    
    // Update the quantity based on unit type
    if (unitType.value === 'storage') {
      itemToUpdate.storage_quantity = finalQuantity;
      itemToUpdate.quantity = finalQuantity;
    } else {
      itemToUpdate.ingredient_quantity = finalQuantity;
      itemToUpdate.quantity = finalQuantity;
    }
    
    items[updatingItemIndex.value] = itemToUpdate;
    
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      items: items
    });
    
    if (result.success) {
      showNotification('Item updated successfully', 'success');
      closeUpdateItemModal();
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to update item');
    }
  } catch (err) {
    console.error('Error updating item:', err);
    showNotification('Error updating item: ' + (err.message || 'Unknown error'), 'error');
  }
};

const deleteItemFromUpdateModal = async () => {
  if (updatingItemIndex.value === -1) return;
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Item',
    message: 'Are you sure you want to delete this item from the transfer order?',
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });
  
  if (!confirmed) return;
  
  closeUpdateItemModal();
  await deleteItemFromOrder(updatingItemIndex.value);
};

const openAddItemsModal = () => {
  newItemForm.value = {
    itemId: '',
    quantity: 1
  };
  itemSearchQuery.value = '';
  showAddItemsModal.value = true;
};

const closeAddItemsModal = () => {
  showAddItemsModal.value = false;
  itemSearchQuery.value = '';
  newItemForm.value = {
    itemId: '',
    quantity: 1
  };
};

const selectItemForAdd = (item) => {
  newItemForm.value.itemId = item.id;
};

const saveAddItem = async () => {
  if (!newItemForm.value.itemId) {
    showNotification('Please select an item', 'warning');
    return;
  }
  
  if (!order.value) return;
  
  try {
    const selectedItem = inventoryItems.value.find(i => i.id === newItemForm.value.itemId);
    if (!selectedItem) {
      throw new Error('Item not found');
    }
    
    const items = [...(order.value.items || [])];
    items.push({
      itemId: selectedItem.id,
      item: selectedItem,
      quantity: newItemForm.value.quantity,
      storage_quantity: unitType.value === 'storage' ? newItemForm.value.quantity : 0,
      ingredient_quantity: unitType.value === 'ingredient' ? newItemForm.value.quantity : 0,
      available_quantity: 0 // Should be fetched from inventory system
    });
    
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      items: items
    });
    
    if (result.success) {
      showNotification('Item added successfully', 'success');
      closeAddItemsModal();
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to add item');
    }
  } catch (err) {
    console.error('Error adding item:', err);
    showNotification('Error adding item: ' + (err.message || 'Unknown error'), 'error');
  }
};

const deleteItemFromOrder = async (index) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Item',
    message: 'Are you sure you want to delete this item from the transfer order?',
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });

  if (!confirmed) return;

  try {
    const items = [...(order.value.items || [])];
    items.splice(index, 1);

    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      items: items
    });

    if (result.success) {
      showNotification('Item deleted successfully', 'success');
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to delete item');
    }
  } catch (err) {
    console.error('Error deleting item:', err);
    showNotification('Error deleting item: ' + (err.message || 'Unknown error'), 'error');
  }
};

const openEditQuantitiesModal = () => {
  if (!order.value || !order.value.items || order.value.items.length === 0) {
    showNotification('No items to edit', 'warning');
    return;
  }
  
  editQuantitiesForm.value.items = (order.value.items || []).map(item => ({
    ...item,
    item: item.item || {},
    itemId: item.itemId || item.item_id || item.item?.id,
    quantity: item.quantity || item.storage_quantity || item.ingredient_quantity || 0
  }));
  
  showEditQuantitiesModal.value = true;
};

const closeEditQuantitiesModal = () => {
  showEditQuantitiesModal.value = false;
  editQuantitiesForm.value.items = [];
};

const updateItemQuantity = (index) => {
  // Can add validation here if needed
};

const saveEditQuantities = async () => {
  if (!order.value) return;
  
  savingQuantities.value = true;
  try {
    const updatedItems = editQuantitiesForm.value.items.map(item => ({
      itemId: item.itemId || item.item_id || item.item?.id,
      item: item.item,
      quantity: item.quantity,
      storage_quantity: unitType.value === 'storage' ? item.quantity : (item.storage_quantity || 0),
      ingredient_quantity: unitType.value === 'ingredient' ? item.quantity : (item.ingredient_quantity || 0),
      available_quantity: item.available_quantity || item.availableQuantity || 0
    }));
    
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      items: updatedItems
    });
    
    if (result.success) {
      showNotification('Item quantities updated successfully', 'success');
      closeEditQuantitiesModal();
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to update quantities');
    }
  } catch (error) {
    console.error('Error updating quantities:', error);
    showNotification('Error updating quantities: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    savingQuantities.value = false;
  }
};

const openImportItemsModal = () => {
  showImportItemsModal.value = true;
  selectedFileName.value = '';
  importFileData.value = null;
};

const closeImportItemsModal = () => {
  showImportItemsModal.value = false;
  selectedFileName.value = '';
  importFileData.value = null;
  if (importFileInput.value) {
    importFileInput.value.value = '';
  }
};

const triggerFileInput = () => {
  if (importFileInput.value) {
    importFileInput.value.click();
  }
};

const handleImportFileChange = async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  
  selectedFileName.value = file.name;
  
  try {
    const fileData = await readFile(file);
    importFileData.value = fileData;
    console.log('✅ File loaded:', fileData);
  } catch (error) {
    console.error('Error reading file:', error);
    showNotification('Error reading file: ' + (error.message || 'Unknown error'), 'error');
    selectedFileName.value = '';
    importFileData.value = null;
  }
};

const readFile = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = (e) => {
      try {
        let jsonData;
        
        if (file.name.endsWith('.csv')) {
          const text = e.target.result;
          const workbook = XLSX.read(text, { type: 'string' });
          const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
          jsonData = XLSX.utils.sheet_to_json(firstSheet);
        } else {
          const data = new Uint8Array(e.target.result);
          const workbook = XLSX.read(data, { type: 'array' });
          const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
          jsonData = XLSX.utils.sheet_to_json(firstSheet);
        }
        
        resolve(jsonData);
      } catch (error) {
        reject(error);
      }
    };
    
    reader.onerror = () => reject(new Error('Failed to read file'));
    
    if (file.name.endsWith('.csv')) {
      reader.readAsText(file);
    } else {
      reader.readAsArrayBuffer(file);
    }
  });
};

const downloadImportTemplate = () => {
  // Create template with columns: name, sku, storage_qi, ingredients_quantity
  const templateData = [
    {
      name: '',
      sku: '',
      storage_qi: '',
      ingredients_quantity: ''
    }
  ];
  
  const worksheet = XLSX.utils.json_to_sheet(templateData);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Transfer Order Items');
  
  const fileName = `transfer_orders_${new Date().getTime()}.xlsx`;
  XLSX.writeFile(workbook, fileName);
  
  showNotification('Template downloaded successfully', 'success');
};

const processImportFile = async () => {
  if (!importFileData.value || !order.value) return;
  
  importingItems.value = true;
  try {
    const allItems = inventoryItems.value.length > 0 
      ? inventoryItems.value 
      : await loadItemsFromSupabase();
    
    const importedItems = [];
    const errors = [];
    
    for (let i = 0; i < importFileData.value.length; i++) {
      const row = importFileData.value[i];
      const rowNum = i + 2;
      
      if (!row.name && !row.sku) {
        errors.push(`Row ${rowNum}: Name or SKU is required`);
        continue;
      }
      
      let item = null;
      if (row.sku) {
        item = allItems.find(i => i.sku === row.sku || i.sku === String(row.sku));
      }
      if (!item && row.name) {
        item = allItems.find(i => 
          i.name?.toLowerCase() === String(row.name).toLowerCase() ||
          i.nameLocalized?.toLowerCase() === String(row.name).toLowerCase()
        );
      }
      
      if (!item) {
        errors.push(`Row ${rowNum}: Item not found (${row.name || row.sku})`);
        continue;
      }
      
      const storageQty = parseFloat(row.storage_qi || 0);
      const ingredientQty = parseFloat(row.ingredients_quantity || 0);
      const quantity = storageQty > 0 ? storageQty : ingredientQty;
      
      if (quantity <= 0) {
        errors.push(`Row ${rowNum}: Quantity must be greater than 0`);
        continue;
      }
      
      const existingItemIndex = order.value.items?.findIndex(
        toItem => (toItem.itemId || toItem.item_id) === item.id
      );
      
      if (existingItemIndex >= 0) {
        order.value.items[existingItemIndex].quantity = quantity;
        order.value.items[existingItemIndex].storage_quantity = storageQty;
        order.value.items[existingItemIndex].ingredient_quantity = ingredientQty;
      } else {
        importedItems.push({
          itemId: item.id,
          item: item,
          quantity: quantity,
          storage_quantity: storageQty,
          ingredient_quantity: ingredientQty,
          available_quantity: 0
        });
      }
    }
    
    if (errors.length > 0) {
      showNotification(`Import completed with ${errors.length} error(s)`, 'warning');
      console.error('Import errors:', errors);
    }
    
    if (importedItems.length > 0) {
      const items = [...(order.value.items || []), ...importedItems];
      
      const result = await updateTransferOrderInSupabase(order.value.id, {
        ...order.value,
        items: items
      });
      
      if (result.success) {
        showNotification(`${importedItems.length} item(s) imported successfully`, 'success');
        closeImportItemsModal();
        await loadOrder();
      } else {
        throw new Error(result.error || 'Failed to import items');
      }
    } else if (errors.length === 0) {
      showNotification('No new items to import', 'info');
    }
  } catch (error) {
    console.error('Error importing items:', error);
    showNotification('Error importing items: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    importingItems.value = false;
  }
};

const editOrder = () => {
  if (!order.value) return;
  
  editForm.value = {
    warehouse: order.value.warehouse || '',
    destination: order.value.destination || '',
    businessDate: order.value.businessDate || order.value.business_date ? 
      (order.value.businessDate || order.value.business_date).split('T')[0] : ''
  };
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
  editForm.value = {
    warehouse: '',
    destination: '',
    businessDate: ''
  };
};

const handleEditWarehouseChange = () => {
  // If destination is same as selected warehouse, clear it
  if (editForm.value.destination === editForm.value.warehouse) {
    editForm.value.destination = '';
  }
};

const handleEditDestinationChange = () => {
  // If warehouse is same as selected destination, clear it
  if (editForm.value.warehouse === editForm.value.destination) {
    editForm.value.warehouse = '';
  }
};

const saveEditOrder = async () => {
  if (!order.value) return;
  
  saving.value = true;
  try {
    const updatedData = {
      ...order.value,
      warehouse: editForm.value.warehouse,
      destination: editForm.value.destination,
      businessDate: editForm.value.businessDate || null
    };
    
    const result = await updateTransferOrderInSupabase(order.value.id, updatedData);
    
    if (result.success) {
      showNotification('Transfer order updated successfully', 'success');
      closeEditModal();
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to update transfer order');
    }
  } catch (err) {
    console.error('Error updating transfer order:', err);
    showNotification('Error updating transfer order: ' + (err.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const submitForReview = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Submit For Review',
    message: 'Are you sure you want to submit this transfer order for review?',
    confirmText: 'Yes',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-paper-plane'
  });
  
  if (!confirmed) return;
  
  try {
    const currentUserName = getCurrentUserName();
    
    // Generate TO number if it doesn't exist (for draft orders)
    let toNumber = order.value.toNumber || order.value.to_number;
    if (!toNumber || toNumber === '') {
      toNumber = await generateTONumber();
    }
    
    // Auto-set business date when submitting
    const businessDate = new Date().toISOString().split('T')[0];
    
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      toNumber: toNumber,
      to_number: toNumber,
      status: 'pending',
      businessDate: businessDate,
      business_date: businessDate,
      submittedAt: new Date().toISOString(),
      submitted_at: new Date().toISOString(),
      submitter: currentUserName
    });
    
    if (result.success) {
      showNotification('Transfer order submitted for review', 'success');
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to submit transfer order');
    }
  } catch (err) {
    console.error('Error submitting transfer order:', err);
    showNotification('Error submitting transfer order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const acceptOrder = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Accept Transfer Order',
    message: 'Are you sure you want to accept this transfer order?',
    confirmText: 'Yes, Accept',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-check'
  });
  
  if (!confirmed) return;
  
  try {
    const currentUserName = getCurrentUserName();
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      status: 'accepted',
      acceptedAt: new Date().toISOString(),
      accepted_at: new Date().toISOString(),
      accepter: currentUserName
    });
    
    if (result.success) {
      showNotification('Transfer order accepted successfully', 'success');
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to accept transfer order');
    }
  } catch (err) {
    console.error('Error accepting transfer order:', err);
    showNotification('Error accepting transfer order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const declineOrder = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Decline Transfer Order',
    message: 'Are you sure you want to decline this transfer order? This will mark it as declined and closed.',
    confirmText: 'Yes, Decline',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-times'
  });
  
  if (!confirmed) return;
  
  try {
    const currentUserName = getCurrentUserName();
    // Set status to 'declined' so it shows in Declined tab, but mark as closed (no more actions)
    const result = await updateTransferOrderInSupabase(order.value.id, {
      ...order.value,
      status: 'declined',
      declinedAt: new Date().toISOString(),
      declined_at: new Date().toISOString(),
      closedAt: new Date().toISOString(),
      closed_at: new Date().toISOString(),
      decliner: currentUserName,
      closer: currentUserName
    });
    
    if (result.success) {
      showNotification('Transfer order declined and closed', 'success');
      await loadOrder();
      // Navigate back to list after declining
      setTimeout(() => {
        goBack();
      }, 1000);
    } else {
      throw new Error(result.error || 'Failed to decline transfer order');
    }
  } catch (err) {
    console.error('Error declining transfer order:', err);
    showNotification('Error declining transfer order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const sendItems = async () => {
  // Placeholder for Send Items functionality
  // User will tell us what to do with this later
  showNotification('Send Items functionality - To be implemented', 'info');
};

const deleteOrderPermanently = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Permanently',
    message: 'Are you sure you want to permanently delete this transfer order? This action cannot be undone.',
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deleteTransferOrderFromSupabase(order.value.id);
    if (result.success) {
      showNotification('Transfer order deleted successfully', 'success');
      goBack();
    } else {
      throw new Error(result.error || 'Failed to delete transfer order');
    }
  } catch (err) {
    console.error('Error deleting transfer order:', err);
    showNotification('Error deleting transfer order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const printOrder = async () => {
  if (!order.value) {
    showNotification('No transfer order data available', 'warning');
    return;
  }

  // Use hidden iframe instead of new tab for printing
  let printFrame = document.getElementById('print-frame-to');
  if (!printFrame) {
    printFrame = document.createElement('iframe');
    printFrame.id = 'print-frame-to';
    printFrame.name = 'print-frame-to';
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

  // Get current order data
  const orderData = order.value;
  
  // Helper functions
  const escapeHtml = (text) => {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  };

  // Use i18n composable (already imported at top level)
  const { t: translate, locale } = useI18n();
  const currentLang = locale.value || 'en';
  
  // Helper functions for formatting
  const dir = currentLang === 'ar' ? 'rtl' : 'ltr';
  const textAlign = currentLang === 'ar' ? 'right' : 'left';
  
  const formatDate = (date) => {
    if (!date) return 'N/A';
  try {
      const d = new Date(date);
      return d.toLocaleDateString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
    } catch {
      return String(date);
    }
  };
  
  const formatDateTime = (date) => {
    if (!date) return 'N/A';
    try {
      const d = new Date(date);
      return d.toLocaleString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
    } catch {
      return String(date);
    }
  };
  
  const formatPrintDateTime = () => {
    const now = new Date();
    return {
      printDate: now.toLocaleDateString(currentLang === 'ar' ? 'ar-SA' : 'en-US'),
      printTime: now.toLocaleTimeString(currentLang === 'ar' ? 'ar-SA' : 'en-US')
    };
  };

  const translateStatus = (status) => {
    return translate(`status.${status}`) || status;
  };

  // Get formatted values
  const toNumber = escapeHtml(orderData?.toNumber || orderData?.to_number || 'Draft');
  const warehouse = escapeHtml(orderData?.warehouse || 'N/A');
  const destination = escapeHtml(orderData?.destination || 'N/A');
  const businessDate = orderData?.businessDate ? formatDate(orderData.businessDate) : '—';
  const creator = escapeHtml(orderData?.creator || 'N/A');
  const createdAt = (orderData?.createdAt || orderData?.created_at) ? formatDateTime(orderData.createdAt || orderData.created_at) : 'N/A';
  const status = orderData?.status || 'draft';
  const statusText = translateStatus(status, currentLang);
  const numberOfItems = (orderData?.items || []).length;
  
  // Current date and time
  const { printDate, printTime } = formatPrintDateTime();

  // Build print document
  printDoc.open();
  printDoc.write('<!DOCTYPE html>');
  
  const htmlEl = printDoc.createElement('html');
  htmlEl.setAttribute('lang', currentLang);
  htmlEl.setAttribute('dir', dir);
  
  const headEl = printDoc.createElement('head');
  const meta1 = printDoc.createElement('meta');
  meta1.setAttribute('charset', 'UTF-8');
  const meta2 = printDoc.createElement('meta');
  meta2.setAttribute('name', 'viewport');
  meta2.setAttribute('content', 'width=device-width, initial-scale=1.0');
  const titleEl = printDoc.createElement('title');
  titleEl.textContent = 'Transfer Order - ' + toNumber;
  const scriptEl = printDoc.createElement('script');
  scriptEl.setAttribute('src', 'https://cdn.tailwindcss.com');
  
  // Print-optimized CSS
  const styleEl = printDoc.createElement('style');
  styleEl.textContent = '@page { size: A4; margin: 20mm 15mm; } @media print { * { -webkit-print-color-adjust: exact; print-color-adjust: exact; } body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; font-size: 12px; line-height: 1.5; color: #111827; background: white; } .print-container { width: 100%; max-width: 100%; margin: 0; padding: 0; } } body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; font-size: 12px; line-height: 1.5; color: #111827; background: white; margin: 0; padding: 0; } .print-container { width: 100%; max-width: 100%; margin: 0 auto; padding: 0; }';
  
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
  parts.push('<div style="font-size: 11px; color: #6b7280; font-weight: 600;">' + translate('inventory.transferOrders.title') + ' – Sakura ERP</div>');
  parts.push('</div>');
  
  // HEADER: Centered logo
  const logoUrl = window.location.origin + '/sakura-logo.png';
  parts.push('<div style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #d1d5db; background: white;">');
  parts.push('<img src="' + logoUrl + '" alt="Sakura Logo" style="height: 80px; max-width: 200px; margin: 0 auto; display: block; object-fit: contain; background: white;" />');
  parts.push('</div>');
  
  // TITLE ROW: TO Number left, Status right
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">');
  parts.push('<div><h2 style="font-size: 18px; font-weight: 700; color: #111827; margin: 0;">' + translate('inventory.transferOrders.title') + ' (' + toNumber + ')</h2></div>');
  parts.push('<div><span style="padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: #f3f4f6; color: #374151;">' + statusText + '</span></div>');
  parts.push('</div>');
  
  // DETAILS SECTION: Two-column layout with borders
  const alignStyle = 'text-align: ' + textAlign + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('inventory.transferOrders.fromLocation') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + warehouse + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('inventory.transferOrders.toLocation') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + destination + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('inventory.transferOrders.businessDate') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + businessDate + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('common.createdBy') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + creator + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('common.createdAt') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + createdAt + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + translate('inventory.grn.numberOfItems') + '</div><div style="font-size: 13px; color: #111827; font-weight: 600; ' + alignStyle + '">' + numberOfItems + '</div></div>');
  parts.push('</div>');
  
  // ITEMS SECTION: Table with light gray header
  const thAlign = 'text-align: ' + textAlign + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">' + translate('inventory.items.items') + '</h3>');
  
  // Warning message if quantity exceeded
  const hasExceeded = (orderData?.items || []).some(item => {
    const qty = item.quantity || item.storage_quantity || item.ingredient_quantity || 0;
    const available = item.available_quantity || item.availableQuantity || 0;
    return qty > available;
  });
  if (hasExceeded) {
    parts.push('<div style="background-color: #fee2e2; border: 1px solid #fecaca; color: #991b1b; padding: 8px 12px; border-radius: 4px; margin-bottom: 12px; font-size: 12px;">' + (currentLang === 'ar' ? 'الكمية المنقولة تتجاوز الكمية المتاحة' : 'Transferred Quantity exceeds the Available Quantity') + '</div>');
  }
  
  parts.push('<table style="width: 100%; border-collapse: collapse;">');
  parts.push('<thead>');
  parts.push('<tr style="background-color: #f9fafb;">');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + translate('inventory.items.name') + '</th>');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + translate('inventory.items.sku') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + translate('inventory.transferOrders.quantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + translate('inventory.transferOrders.availableQuantity') + '</th>');
  parts.push('</tr>');
  parts.push('</thead>');
  parts.push('<tbody>');
  
  // Build items rows
  const items = orderData?.items || [];
  items.forEach(item => {
    const itemName = escapeHtml(item.item?.name || 'N/A');
    const itemNameLocalized = item.item?.nameLocalized ? '<br><span style="color: #6b7280; font-size: 0.875rem;">' + escapeHtml(item.item.nameLocalized) + '</span>' : '';
    const sku = escapeHtml(item.item?.sku || 'N/A');
    const quantity = item.quantity || item.storage_quantity || item.ingredient_quantity || 0;
    const availableQty = item.available_quantity || item.availableQuantity || 0;
    // Get unit from database - never hardcode
    const unit = item.item?.storageUnit || item.item?.storage_unit || item.item?.ingredientUnit || item.item?.ingredient_unit || '';
    const qtyColor = quantity > availableQty ? '#dc2626' : '#374151';
    
    parts.push('<tr>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + itemName + itemNameLocalized + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + sku + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: ' + qtyColor + '; text-align: right; border-bottom: 1px solid #e5e7eb;">' + quantity + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: ' + qtyColor + '; text-align: right; border-bottom: 1px solid #e5e7eb;">' + availableQty + ' ' + unit + '</td>');
    parts.push('</tr>');
  });
  
  if (items.length === 0) {
    parts.push('<tr><td colspan="4" style="padding: 32px 16px; text-align: center; color: #6b7280;">' + translate('common.noItemsFound') + '</td></tr>');
  }
  
  parts.push('</tbody>');
  parts.push('</table>');
  parts.push('</div>');
  
  // FOOTER: System name left, Page number right
  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #6b7280;">');
  parts.push('<div>Sakura ERP Management System</div>');
  parts.push('<div>' + translate('common.page') + ' 1 / 1</div>');
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

  if (printFrame.contentDocument.readyState === 'complete') {
    setTimeout(printContent, 300);
  } else {
    printFrame.onload = () => {
      setTimeout(printContent, 300);
    };
  }
};

const getCurrentUserName = () => {
  const user = authStore.user;
  if (user) {
    return user.name || user.fullName || user.email?.split('@')[0] || 'Unknown User';
  }
  try {
    const savedUser = localStorage.getItem('sakura_current_user');
    if (savedUser) {
      const userData = JSON.parse(savedUser);
      return userData.name || userData.fullName || userData.email?.split('@')[0] || 'Unknown User';
    }
  } catch (e) {
    console.error('Error getting user from localStorage:', e);
  }
  return 'Unknown User';
};

onMounted(async () => {
  await loadInventoryItems();
  await loadOrder();
});
</script>

<style scoped>
.sakura-primary-btn {
  background-color: #284b44;
  color: white;
}

.sakura-primary-btn:hover {
  background-color: #1f3d37;
}

.loading-spinner {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>

