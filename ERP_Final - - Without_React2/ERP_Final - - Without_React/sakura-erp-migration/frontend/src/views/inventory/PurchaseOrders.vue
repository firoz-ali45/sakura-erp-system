<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.purchaseOrders.title') }}</h1>
          <i class="fas fa-question-circle" style="color: #284b44;" cursor-pointer></i>
        </div>
        <div class="flex items-center gap-3">
          <div class="relative">
            <button 
              @click="toggleExportMenu"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-cloud"></i>
              <span>{{ $t('common.export') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showExportMenu" class="dropdown-menu">
              <a href="#" @click.prevent="exportAllPurchaseOrders"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.purchaseOrders.exportAll') }}</a>
              <a v-if="selectedOrders.length > 0" href="#" @click.prevent="exportSelectedPurchaseOrders"><i class="fas fa-download mr-2 text-[#284b44]"></i>{{ $t('inventory.purchaseOrders.exportSelected') }}</a>
            </div>
          </div>
          <button 
            @click="openCreatePOModal"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
          >
            <i class="fas fa-plus"></i>
            <span>{{ $t('inventory.purchaseOrders.create') }}</span>
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
            @click="switchTab('pending')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'pending' }]"
          >
            {{ $t('status.pending') }}
          </button>
          <button 
            @click="switchTab('closed')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'closed' }]"
          >
            {{ $t('status.closed') }}
          </button>
        </div>
        <div class="flex items-center gap-3">
          <button 
            @click="hasActiveFilters ? clearFilter() : openFilter()" 
            :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', hasActiveFilters ? 'border-gray-300' : 'border-gray-300 hover:bg-gray-50']"
            :style="hasActiveFilters ? { backgroundColor: '#f0e1cd', borderColor: '#956c2a', color: '#284b44' } : {}"
          >
            <i :class="hasActiveFilters ? 'fas fa-times-circle' : 'fas fa-filter'"></i>
            <span>{{ hasActiveFilters ? $t('inventory.grn.filter.clear') : $t('common.filter') }}</span>
            <span v-if="hasActiveFilters" class="ml-1 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center" style="background-color: #284b44;">
              {{ activeFiltersCount }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <!-- Bulk Actions Bar -->
    <div v-if="selectedOrders.length > 0" class="bg-yellow-50 border border-yellow-200 rounded-lg shadow-md p-4 mb-4" style="position: relative; z-index: 10;">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-4">
          <span class="font-semibold text-gray-700">{{ selectedOrders.length }} {{ $t('common.selected') }}</span>
          <div class="relative" @click.stop style="z-index: 1000;">
            <button @click.stop="toggleBulkActionsMenu" class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 cursor-pointer">
              <i class="fas fa-tasks"></i>
              <span>{{ $t('common.actions') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showBulkActionsMenu" class="dropdown-menu" style="pointer-events: auto; z-index: 1001;">
              <a href="#" @click.stop.prevent="bulkDeleteOrders" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-trash mr-2 text-red-600"></i>{{ $t('common.delete') }}</a>
              <a href="#" @click.stop.prevent="bulkExportOrders" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.purchaseOrders.exportSelected') }}</a>
            </div>
          </div>
        </div>
        <button @click="clearSelection" class="text-gray-600 hover:text-gray-800">
          <i class="fas fa-times"></i> {{ $t('inventory.grn.filter.clearSelection') }}
        </button>
      </div>
    </div>

    <!-- Purchase Orders Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-4 text-left">
              <input 
                type="checkbox" 
                :checked="allSelected" 
                @change="toggleSelectAll"
                class="rounded border-gray-300"
              />
            </th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.reference') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.supplier') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.destination') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.status') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.receiving') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.businessDate') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.totalAmount') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">CI</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('common.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <!-- Loading Skeleton -->
          <tr v-if="loading" v-for="n in 5" :key="'skeleton-' + n" class="animate-pulse">
            <td class="px-6 py-4">
              <div class="h-4 w-4 bg-gray-200 rounded sakura-skeleton"></div>
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
              <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
            </td>
            <td class="px-6 py-4">
              <div class="h-4 bg-gray-200 rounded sakura-skeleton"></div>
            </td>
            <td class="px-6 py-4">
              <div class="h-4 w-4 bg-gray-200 rounded sakura-skeleton"></div>
            </td>
          </tr>
          <!-- Empty State -->
          <tr v-else-if="!loading && (!paginatedOrders || paginatedOrders.length === 0)">
            <td colspan="10" class="px-6 py-8 text-center text-gray-500">
              No purchase orders found
            </td>
          </tr>
          <!-- Data Rows -->
          <tr 
            v-else
            v-for="order in paginatedOrders" 
            :key="order.id"
            @click="viewOrder(order)"
            class="hover:bg-gray-50 cursor-pointer"
          >
            <td class="px-6 py-4" @click.stop>
              <input 
                type="checkbox" 
                :checked="selectedOrders.includes(order.id)"
                @change="toggleSelectOrder(order.id)"
                @click.stop
                class="rounded border-gray-300"
              />
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-900 font-medium', textAlign]">
              <span v-if="order.poNumber || order.po_number">{{ order.poNumber || order.po_number }}</span>
              <span v-else class="text-gray-400 italic">Draft</span>
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">
              <div v-if="order.supplier">
                {{ order.supplier.name }}
                <span v-if="order.supplier.nameLocalized" class="text-gray-500">({{ order.supplier.nameLocalized }})</span>
              </div>
              <span v-else class="text-gray-400">N/A</span>
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">{{ order.destination || '—' }}</td>
            <td :class="['px-6 py-4', textAlign]">
              <span 
                :class="[
                  'px-2 py-1 rounded-full text-xs font-semibold',
                  getStatusClass(order.status || order.status)
                ]"
              >
                {{ formatStatus(order.status || order.status) }}
              </span>
            </td>
            <td :class="['px-6 py-4', textAlign]">
              <span 
                :class="[
                  'px-2 py-1 rounded-full text-xs font-semibold flex items-center gap-1',
                  getReceivingStatusClass(getPOReceivingStatus(order))
                ]"
                :title="getReceivingStatusTooltip(order)"
              >
                <i :class="getReceivingStatusIcon(getPOReceivingStatus(order))"></i>
                {{ getReceivingStatusText(getPOReceivingStatus(order)) }}
              </span>
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">
              {{ formatDate(order.orderDate || order.order_date) }}
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-900 font-semibold', textAlign]">
              {{ formatCurrency(order.totalAmount || order.total_amount || 0) }}
            </td>
            <td :class="['px-6 py-4 text-sm text-gray-700', textAlign]">
              {{ formatDate(order.createdAt || order.created_at) }}
            </td>
            <td class="px-6 py-4" @click.stop>
              <div class="relative">
                <button 
                  @click.stop="toggleOrderActions(order.id)"
                  class="text-gray-600 hover:text-gray-900"
                >
                  <i class="fas fa-ellipsis-v"></i>
                </button>
                <div 
                  v-if="activeOrderActions === order.id" 
                  class="dropdown-menu"
                  @click.stop
                >
                  <a @click.stop="viewOrder(order)" class="cursor-pointer"><i class="fas fa-eye mr-2 text-[#284b44]"></i>{{ $t('common.view') }}</a>
                  <a @click.stop="editOrder(order)" class="cursor-pointer"><i class="fas fa-edit mr-2 text-green-600"></i>{{ $t('common.edit') }}</a>
                  <a href="#" @click.prevent="deleteOrder(order.id)" class="text-red-600"><i class="fas fa-trash mr-2"></i>{{ $t('common.delete') }}</a>
                </div>
              </div>
            </td>
          </tr>
          <tr v-if="paginatedOrders.length === 0">
            <td colspan="10" class="px-6 py-8 text-center text-gray-500">
              No purchase orders found
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="mt-4 flex justify-between items-center bg-white rounded-lg shadow-md p-4">
      <div class="text-sm text-gray-700">
        Showing {{ (currentPage - 1) * limit + 1 }} to {{ Math.min(currentPage * limit, filteredOrders.length) }} of {{ filteredOrders.length }} orders
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

    <!-- Create/Edit Purchase Order Modal -->
    <div v-if="showPOModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closePOModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">{{ editingOrder ? 'Edit Purchase Order' : 'New Purchase Order' }}</h2>
          <button @click.stop="closePOModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="savePurchaseOrder" @click.stop>
            <div class="grid grid-cols-2 gap-4 mb-6" @click.stop>
              <div @click.stop class="relative">
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Supplier <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.selectSupplier')"></i>
                </label>
                <div class="relative">
                  <input
                    type="text"
                    :value="showSupplierDropdown ? supplierSearchQuery : getSelectedSupplierName()"
                    @input="supplierSearchQuery = $event.target.value; showSupplierDropdown = true"
                    @focus="showSupplierDropdown = true; if (!supplierSearchQuery) supplierSearchQuery = ''"
                    @blur="setTimeout(() => showSupplierDropdown = false, 200)"
                    :placeholder="!newOrder.supplierId ? $t('inventory.purchaseOrders.typeToSearchSuppliers') : ''"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                    @click.stop="showSupplierDropdown = true"
                  />
                  <i class="fas fa-search absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 pointer-events-none"></i>
                  <div
                    v-if="showSupplierDropdown && filteredSuppliers.length > 0"
                    class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto"
                    @click.stop
                  >
                    <div
                      v-for="supplier in filteredSuppliers"
                      :key="supplier.id"
                      @click="selectSupplier(supplier)"
                      class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0"
                    >
                      <div class="font-medium text-gray-900">{{ supplier.name }}</div>
                      <div v-if="supplier.nameLocalized" class="text-sm text-gray-500">{{ supplier.nameLocalized }}</div>
              </div>
                  </div>
                  <div
                    v-if="showSupplierDropdown && filteredSuppliers.length === 0"
                    class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-4 text-center text-gray-500"
                    @click.stop
                  >
                    No suppliers found
                  </div>
                </div>
              </div>
              <div @click.stop class="relative">
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Destination <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.selectDestination')"></i>
                </label>
                <div class="relative">
                  <input
                    type="text"
                    :value="showDestinationDropdown ? destinationSearchQuery : newOrder.destination"
                    @input="destinationSearchQuery = $event.target.value; showDestinationDropdown = true"
                    @focus="showDestinationDropdown = true; if (!destinationSearchQuery) destinationSearchQuery = ''"
                    @blur="setTimeout(() => showDestinationDropdown = false, 200)"
                    :placeholder="!newOrder.destination ? $t('inventory.purchaseOrders.typeToSearchDestinations') : ''"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                    @click.stop="showDestinationDropdown = true"
                  />
                  <i class="fas fa-search absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 pointer-events-none"></i>
                  <div
                    v-if="showDestinationDropdown && filteredDestinations.length > 0"
                    class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto"
                    @click.stop
                  >
                    <div
                      v-for="destination in filteredDestinations"
                      :key="destination"
                      @click="selectDestination(destination)"
                      class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0"
                    >
                      <div class="font-medium text-gray-900">{{ destination }}</div>
                    </div>
                  </div>
                  <div
                    v-if="showDestinationDropdown && filteredDestinations.length === 0"
                    class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-4 text-center text-gray-500 text-sm"
                    @click.stop
                  >
                    No locations. Add in Manage → Inventory Locations, set Status Active and Allow GRN.
                  </div>
                </div>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">Delivery Date</label>
                <input 
                  v-model="newOrder.deliveryDate" 
                  type="date"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">Delivery Time</label>
                <select 
                  v-model="newOrder.deliveryTime"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option value="08:00">08:00 AM</option>
                  <option value="09:00">09:00 AM</option>
                  <option value="10:00">10:00 AM</option>
                  <option value="11:00">11:00 AM</option>
                  <option value="12:00">12:00 PM</option>
                  <option value="13:00">01:00 PM</option>
                  <option value="14:00">02:00 PM</option>
                  <option value="15:00">03:00 PM</option>
                  <option value="16:00">04:00 PM</option>
                  <option value="17:00">05:00 PM</option>
                </select>
              </div>
            </div>

            <!-- Order Items -->
            <div class="mb-6" @click.stop>
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-lg font-semibold text-gray-800">Order Items</h3>
                <button 
                  type="button"
                  @click.stop="addOrderItem"
                  class="px-4 py-2 text-white rounded-lg flex items-center gap-2 cursor-pointer sakura-primary-btn"
                  style="pointer-events: auto; z-index: 10;"
                >
                  <i class="fas fa-plus"></i>
                  <span>Add Item</span>
                </button>
              </div>
              
              <div class="overflow-x-auto" @click.stop>
                <table class="w-full border border-gray-200 rounded-lg" @click.stop style="min-width: 900px;">
                  <colgroup>
                    <col style="width: 22%;">
                    <col style="width: 10%;">
                    <col style="width: 10%;">
                    <col style="width: 10%;">
                    <col style="width: 12%;">
                    <col style="width: 12%;">
                    <col style="width: 12%;">
                    <col style="width: 8%;">
                  </colgroup>
                  <thead class="bg-gray-50">
                    <tr>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.grn.item') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.sku') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.items.storageUnit') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.quantity') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.costPerUnit') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.purchaseOrders.vatPercent') }}</th>
                      <th :class="['px-4 py-2 text-sm font-semibold text-gray-700', textAlign]">{{ $t('common.total') }}</th>
                      <th class="px-4 py-2 text-center text-sm font-semibold text-gray-700">{{ $t('common.actions') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(item, index) in newOrder.items" :key="index" @click.stop>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <div class="relative">
                          <input
                            type="text"
                            :value="showItemDropdowns[index] ? (itemSearchQueries[index] || '') : getSelectedItemName(index)"
                            @input="itemSearchQueries[index] = $event.target.value; showItemDropdowns[index] = true"
                            @focus="showItemDropdowns[index] = true; if (!itemSearchQueries[index]) itemSearchQueries[index] = ''"
                            @blur="setTimeout(() => showItemDropdowns[index] = false, 200)"
                            :placeholder="!newOrder.items[index]?.itemId ? $t('inventory.purchaseOrders.typeToSearchItems') : ''"
                            class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2"
                            style="pointer-events: auto; --tw-ring-color: #284b44;"
                            @click.stop="showItemDropdowns[index] = true"
                          />
                          <i class="fas fa-search absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 pointer-events-none text-xs"></i>
                          <div
                            v-if="showItemDropdowns[index] && getFilteredItems(index).length > 0"
                            class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto"
                          @click.stop
                          >
                            <div
                              v-for="invItem in getFilteredItems(index)"
                              :key="invItem.id"
                              @click="selectItem(index, invItem)"
                              class="px-3 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0 text-sm"
                            >
                              <div class="font-medium text-gray-900">{{ invItem.name }}</div>
                              <div v-if="invItem.nameLocalized" class="text-xs text-gray-500">{{ invItem.nameLocalized }}</div>
                              <div v-if="invItem.sku" class="text-xs text-gray-400 font-mono">SKU: {{ invItem.sku }}</div>
                            </div>
                          </div>
                          <div
                            v-if="showItemDropdowns[index] && getFilteredItems(index).length === 0"
                            class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-3 text-center text-gray-500 text-sm"
                            @click.stop
                          >
                            {{ $t('common.noItemsFound') }}
                          </div>
                        </div>
                      </td>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <input 
                          :value="getItemSKU(item.itemId)"
                          readonly
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed font-mono text-sm"
                          style="pointer-events: none;"
                          :placeholder="$t('common.autoFilled')"
                        />
                      </td>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <input 
                          :value="getItemStorageUnit(item.itemId)"
                          readonly
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed text-sm"
                          style="pointer-events: none;"
                          :placeholder="$t('common.autoFilled')"
                        />
                      </td>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <input 
                          v-model.number="item.quantity"
                          @input.stop="updateItemTotal(index)"
                          @click.stop
                          type="number" 
                          min="0" 
                          step="0.01"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        />
                      </td>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <input 
                          v-model.number="item.unitPrice"
                          @input.stop="updateItemTotal(index)"
                          @click.stop
                          type="number" 
                          min="0" 
                          step="0.01"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                        />
                      </td>
                      <td class="px-4 py-2 align-top" @click.stop>
                        <input 
                          v-model.number="item.vatRate"
                          @input.stop="updateItemTotal(index)"
                          @click.stop
                          type="number" 
                          min="0" 
                          max="100"
                          step="0.01"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                          style="pointer-events: auto;"
                          :placeholder="'0'"
                        />
                      </td>
                      <td class="px-4 py-2 align-top font-semibold text-sm">
                        {{ formatCurrency(item.totalAmount || 0) }}
                      </td>
                      <td class="px-4 py-2 align-top text-center" @click.stop>
                        <button 
                          type="button"
                          @click.stop="removeOrderItem(index)"
                          class="text-red-600 hover:text-red-800 cursor-pointer inline-flex items-center justify-center"
                          style="pointer-events: auto;"
                        >
                          <i class="fas fa-trash"></i>
                        </button>
                      </td>
                    </tr>
                  </tbody>
                  <tfoot class="bg-gray-50">
                    <tr>
                      <td colspan="5" :class="['px-4 py-2 font-semibold', textAlign === 'text-right' ? 'text-right' : 'text-left']">{{ $t('common.subtotal') }}:</td>
                      <td class="px-4 py-2 font-semibold">{{ formatCurrency(subtotal) }}</td>
                      <td></td>
                    </tr>
                    <tr>
                      <td colspan="5" :class="['px-4 py-2 font-semibold', textAlign === 'text-right' ? 'text-right' : 'text-left']">{{ $t('common.vat') }}:</td>
                      <td class="px-4 py-2 font-semibold">{{ formatCurrency(totalVAT) }}</td>
                      <td></td>
                    </tr>
                    <tr>
                      <td colspan="5" :class="['px-4 py-2 font-semibold text-lg', textAlign === 'text-right' ? 'text-right' : 'text-left']">{{ $t('common.total') }}:</td>
                      <td class="px-4 py-2 font-semibold text-lg" style="color: #284b44;">{{ formatCurrency(totalAmount) }}</td>
                      <td></td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>

            <div class="mb-4" @click.stop>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ $t('inventory.purchaseOrders.notes') }}
                <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.additionalNotes')"></i>
              </label>
              <textarea 
                v-model="newOrder.notes" 
                rows="3"
                @click.stop
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                :placeholder="$t('inventory.purchaseOrders.additionalNotes')"
                style="pointer-events: auto;"
              ></textarea>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closePOModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                style="pointer-events: auto;"
              >
                {{ $t('common.cancel') }}
              </button>
              <button 
                type="submit" 
                :disabled="saving"
                @click.stop
                class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
                style="pointer-events: auto;"
              >
                {{ saving ? $t('inventory.purchaseOrders.saving') : (editingOrder ? $t('common.update') : $t('common.create')) }}
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
          <h2 class="text-2xl font-bold text-gray-800">{{ $t('common.filter') }}</h2>
          <button @click="closeFilter" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <!-- Text Input Fields with Including/Excluding -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.purchaseOrders.reference') }}</label>
                <div class="flex gap-2">
                  <input 
                    v-model="tempFilterCriteria.poNumber"
                    type="text"
                    :placeholder="$t('inventory.purchaseOrders.filter.searchByPONumber') + '...'"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <select 
                    v-model="tempFilterCriteria.poNumberMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.businessDate') }}</label>
                <input 
                  v-model="tempFilterCriteria.businessDate"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
            </div>

            <!-- Dropdown Selects with Including/Excluding -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.receivingStatus') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.receivingStatus"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option value="fully_received">Received All</option>
                    <option value="partially_received">Partially Received</option>
                    <option value="not_received_yet">Not Received Yet</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.receivingStatusMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('status.title') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.status"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option value="draft">{{ t('status.draft') }}</option>
                    <option value="pending">{{ t('status.pending') }}</option>
                    <option value="approved">{{ t('status.approved') }}</option>
                    <option value="rejected">{{ t('status.rejected') }}</option>
                    <option value="closed">{{ t('status.closed') }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.statusMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.destination') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.destination"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="dest in destinationOptions" :key="dest" :value="dest">{{ dest }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.destinationMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.suppliers.title') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.supplierId"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">
                      {{ supplier.name }}{{ supplier.nameLocalized ? ` (${supplier.nameLocalized})` : '' }}
                    </option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.supplierMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('common.createdBy') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.creator"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.creatorMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.submitter') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.submitter"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.submitterMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.approver') }}</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.approver"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">{{ t('inventory.purchaseOrders.filter.any') }}</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.approverMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">{{ t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ t('inventory.purchaseOrders.filter.excluding') }}</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Date Fields -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.updatedAfter') }}</label>
                <input 
                  v-model="tempFilterCriteria.updatedAfter"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">{{ t('inventory.purchaseOrders.deliveryDate') }}</label>
                <input 
                  v-model="tempFilterCriteria.deliveryDate"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
            </div>

            <!-- Advanced Range Filters -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4 border-t border-gray-200">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Total Amount Range</label>
                <div class="grid grid-cols-2 gap-2">
                  <input 
                    v-model.number="tempFilterCriteria.totalAmountMin"
                    type="number"
                    :placeholder="$t('common.min')"
                    min="0"
                    step="0.01"
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <input 
                    v-model.number="tempFilterCriteria.totalAmountMax"
                    type="number"
                    :placeholder="$t('common.max')"
                    min="0"
                    step="0.01"
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Number of Items Range</label>
                <div class="grid grid-cols-2 gap-2">
                  <input 
                    v-model.number="tempFilterCriteria.itemsCountMin"
                    type="number"
                    :placeholder="$t('common.min')"
                    min="0"
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <input 
                    v-model.number="tempFilterCriteria.itemsCountMax"
                    type="number"
                    :placeholder="$t('common.max')"
                    min="0"
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                </div>
              </div>
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="flex justify-between items-center pt-6 mt-6 border-t">
            <button 
              @click="clearFilter"
              class="px-6 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              {{ t('inventory.grn.filter.clear') }}
            </button>
            <div class="flex gap-3">
              <button 
                @click="closeFilter"
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                {{ t('common.close') }}
              </button>
              <button 
                @click="applyFilter"
                class="px-6 py-2 text-white rounded-lg sakura-primary-btn"
              >
                {{ t('common.apply') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { 
  loadPurchaseOrdersFromSupabase, 
  savePurchaseOrderToSupabase, 
  updatePurchaseOrderInSupabase,
  deletePurchaseOrderFromSupabase,
  generatePONumber
} from '@/services/supabase';
import { loadSuppliersFromSupabase, loadGRNsFromSupabase } from '@/services/supabase';
import { loadItemsFromSupabase } from '@/services/supabase';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';
import { useInventoryLocations } from '@/composables/useInventoryLocations';

const router = useRouter();
const { loadLocationsForPO } = useInventoryLocations();
const destinationOptions = ref([]);
const route = useRoute();
const authStore = useAuthStore();

// i18n support - using new enterprise system
const { t, locale, textAlign } = useI18n();

// State
const purchaseOrders = ref([]);
const suppliers = ref([]);
const inventoryItems = ref([]);
const grns = ref([]); // For receiving status calculation
const loading = ref(false);
const activeTab = ref('all');
const selectedOrders = ref([]);
const showBulkActionsMenu = ref(false);
const showExportMenu = ref(false);
const showPOModal = ref(false);
const showFilterModal = ref(false);
const editingOrder = ref(null);
const activeOrderActions = ref(null);
const saving = ref(false);
const currentPage = ref(1);
const limit = ref(50);

// Searchable dropdown state
const supplierSearchQuery = ref('');
const showSupplierDropdown = ref(false);
const destinationSearchQuery = ref('');
const showDestinationDropdown = ref(false);
const itemSearchQueries = ref({});
const showItemDropdowns = ref({});

// Active filter criteria (applied filters)
const filterCriteria = ref({
  poNumber: '',
  poNumberMode: 'including',
  businessDate: '',
  status: '',
  statusMode: 'including',
  receivingStatus: '',
  receivingStatusMode: 'including',
  destination: '',
  destinationMode: 'including',
  supplierId: '',
  supplierMode: 'including',
  creator: '',
  creatorMode: 'including',
  submitter: '',
  submitterMode: 'including',
  approver: '',
  approverMode: 'including',
  updatedAfter: '',
  deliveryDate: '',
  totalAmountMin: null,
  totalAmountMax: null,
  itemsCountMin: null,
  itemsCountMax: null
});

// Temporary filter criteria (for modal inputs - not applied until Apply is clicked)
const tempFilterCriteria = ref({
  poNumber: '',
  poNumberMode: 'including',
  businessDate: '',
  status: '',
  statusMode: 'including',
  receivingStatus: '',
  receivingStatusMode: 'including',
  destination: '',
  destinationMode: 'including',
  supplierId: '',
  supplierMode: 'including',
  creator: '',
  creatorMode: 'including',
  submitter: '',
  submitterMode: 'including',
  approver: '',
  approverMode: 'including',
  updatedAfter: '',
  deliveryDate: '',
  totalAmountMin: null,
  totalAmountMax: null,
  itemsCountMin: null,
  itemsCountMax: null
});

// New order form
const newOrder = ref({
  poNumber: '',
  supplierId: '',
  orderDate: new Date().toISOString().split('T')[0],
  expectedDate: '',
  status: 'draft',
  destination: '',
  notes: '',
  items: []
});

// Computed
const filteredOrders = computed(() => {
  // Ensure purchaseOrders is always an array
  if (!purchaseOrders.value || !Array.isArray(purchaseOrders.value)) {
    return [];
  }
  let filtered = purchaseOrders.value;
  
  console.log('🔍 Filtering orders. Total:', filtered.length, 'Active Tab:', activeTab.value);
  console.log('📋 All orders:', filtered.map(o => ({ id: o.id, poNumber: o.poNumber || o.po_number, status: o.status })));
  
  // Tab filter
  if (activeTab.value === 'draft') {
    filtered = filtered.filter(o => {
      const status = (o.status || '').toLowerCase();
      return status === 'draft';
    });
  } else if (activeTab.value === 'pending') {
    filtered = filtered.filter(o => {
      const status = (o.status || '').toLowerCase();
      return status === 'pending';
    });
  } else if (activeTab.value === 'closed') {
    filtered = filtered.filter(o => {
      const status = (o.status || '').toLowerCase();
      return status === 'closed';
    });
  }
  
  console.log('✅ After tab filter:', filtered.length, 'orders');
  
  // Advanced filters with Including/Excluding logic
  // PO Number filter
  if (filterCriteria.value.poNumber) {
    const poNum = filterCriteria.value.poNumber.toLowerCase();
    const matches = (o) => (o.poNumber || o.po_number || '').toLowerCase().includes(poNum);
    if (filterCriteria.value.poNumberMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Status filter
  if (filterCriteria.value.status) {
    const matches = (o) => (o.status || '').toLowerCase() === filterCriteria.value.status.toLowerCase();
    if (filterCriteria.value.statusMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Receiving Status filter
  if (filterCriteria.value.receivingStatus) {
    const matches = (o) => getPOReceivingStatus(o) === filterCriteria.value.receivingStatus;
    if (filterCriteria.value.receivingStatusMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Supplier filter
  if (filterCriteria.value.supplierId) {
    const matches = (o) => (o.supplierId || o.supplier_id) === filterCriteria.value.supplierId;
    if (filterCriteria.value.supplierMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Destination filter
  if (filterCriteria.value.destination) {
    const matches = (o) => (o.destination || '').toLowerCase() === filterCriteria.value.destination.toLowerCase();
    if (filterCriteria.value.destinationMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Creator filter
  if (filterCriteria.value.creator) {
    const matches = (o) => (o.creator || '').toLowerCase() === filterCriteria.value.creator.toLowerCase();
    if (filterCriteria.value.creatorMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Submitter filter
  if (filterCriteria.value.submitter) {
    const matches = (o) => (o.submitter || '').toLowerCase() === filterCriteria.value.submitter.toLowerCase();
    if (filterCriteria.value.submitterMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Approver filter
  if (filterCriteria.value.approver) {
    const matches = (o) => (o.approver || '').toLowerCase() === filterCriteria.value.approver.toLowerCase();
    if (filterCriteria.value.approverMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(o => !matches(o));
    }
  }
  
  // Business Date filter
  if (filterCriteria.value.businessDate) {
    filtered = filtered.filter(o => {
      const businessDate = o.businessDate || o.business_date || o.orderDate || o.order_date;
      return businessDate === filterCriteria.value.businessDate;
    });
  }
  
  // Updated After filter
  if (filterCriteria.value.updatedAfter) {
    filtered = filtered.filter(o => {
      const updatedAt = o.updatedAt || o.updated_at;
      return updatedAt && updatedAt >= filterCriteria.value.updatedAfter;
    });
  }
  
  // Delivery Date filter
  if (filterCriteria.value.deliveryDate) {
    filtered = filtered.filter(o => {
      const deliveryDate = o.deliveryDate || o.delivery_date;
      return deliveryDate === filterCriteria.value.deliveryDate;
    });
  }
  
  // Total Amount Range filter
  if (filterCriteria.value.totalAmountMin !== null && filterCriteria.value.totalAmountMin !== undefined) {
    filtered = filtered.filter(o => {
      const total = o.totalAmount || o.total_amount || 0;
      return total >= filterCriteria.value.totalAmountMin;
    });
  }
  if (filterCriteria.value.totalAmountMax !== null && filterCriteria.value.totalAmountMax !== undefined) {
    filtered = filtered.filter(o => {
      const total = o.totalAmount || o.total_amount || 0;
      return total <= filterCriteria.value.totalAmountMax;
    });
  }
  
  // Number of Items Range filter
  if (filterCriteria.value.itemsCountMin !== null && filterCriteria.value.itemsCountMin !== undefined) {
    filtered = filtered.filter(o => {
      const itemsCount = (o.items || []).length;
      return itemsCount >= filterCriteria.value.itemsCountMin;
    });
  }
  if (filterCriteria.value.itemsCountMax !== null && filterCriteria.value.itemsCountMax !== undefined) {
    filtered = filtered.filter(o => {
      const itemsCount = (o.items || []).length;
      return itemsCount <= filterCriteria.value.itemsCountMax;
    });
  }
  
  return filtered;
});

const paginatedOrders = computed(() => {
  // Ensure filteredOrders is always an array
  if (!filteredOrders.value || !Array.isArray(filteredOrders.value)) {
    return [];
  }
  const start = (currentPage.value - 1) * limit.value;
  const end = start + limit.value;
  return filteredOrders.value.slice(start, end);
});

const totalPages = computed(() => {
  return Math.ceil(filteredOrders.value.length / limit.value);
});

const allSelected = computed(() => {
  return paginatedOrders.value.length > 0 && 
         paginatedOrders.value.every(order => selectedOrders.value.includes(order.id));
});

// Get available users from purchase orders
const availableUsers = computed(() => {
  const users = new Set();
  purchaseOrders.value.forEach(order => {
    if (order.creator) users.add(order.creator);
    if (order.submitter) users.add(order.submitter);
    if (order.approver) users.add(order.approver);
  });
  return Array.from(users).sort();
});

const hasActiveFilters = computed(() => {
  return !!(filterCriteria.value.poNumber || 
           filterCriteria.value.businessDate ||
           filterCriteria.value.status || 
           filterCriteria.value.destination ||
           filterCriteria.value.supplierId || 
           filterCriteria.value.creator ||
           filterCriteria.value.submitter ||
           filterCriteria.value.approver ||
           filterCriteria.value.updatedAfter ||
           filterCriteria.value.deliveryDate ||
           (filterCriteria.value.totalAmountMin !== null && filterCriteria.value.totalAmountMin !== undefined) ||
           (filterCriteria.value.totalAmountMax !== null && filterCriteria.value.totalAmountMax !== undefined) ||
           (filterCriteria.value.itemsCountMin !== null && filterCriteria.value.itemsCountMin !== undefined) ||
           (filterCriteria.value.itemsCountMax !== null && filterCriteria.value.itemsCountMax !== undefined));
});

const activeFiltersCount = computed(() => {
  let count = 0;
  if (filterCriteria.value.poNumber) count++;
  if (filterCriteria.value.businessDate) count++;
  if (filterCriteria.value.status) count++;
  if (filterCriteria.value.destination) count++;
  if (filterCriteria.value.supplierId) count++;
  if (filterCriteria.value.creator) count++;
  if (filterCriteria.value.submitter) count++;
  if (filterCriteria.value.approver) count++;
  if (filterCriteria.value.updatedAfter) count++;
  if (filterCriteria.value.deliveryDate) count++;
  if (filterCriteria.value.totalAmountMin !== null && filterCriteria.value.totalAmountMin !== undefined) count++;
  if (filterCriteria.value.totalAmountMax !== null && filterCriteria.value.totalAmountMax !== undefined) count++;
  if (filterCriteria.value.itemsCountMin !== null && filterCriteria.value.itemsCountMin !== undefined) count++;
  if (filterCriteria.value.itemsCountMax !== null && filterCriteria.value.itemsCountMax !== undefined) count++;
  return count;
});

const subtotal = computed(() => {
  return newOrder.value.items.reduce((sum, item) => {
    return sum + ((item.quantity || 0) * (item.unitPrice || 0));
  }, 0);
});

const totalVAT = computed(() => {
  return newOrder.value.items.reduce((sum, item) => {
    const itemSubtotal = (item.quantity || 0) * (item.unitPrice || 0);
    const vat = itemSubtotal * ((item.vatRate || 0) / 100);
    return sum + vat;
  }, 0);
});

const totalAmount = computed(() => {
  return subtotal.value + totalVAT.value;
});

// Methods
const loadPurchaseOrders = async () => {
  loading.value = true;
  try {
    const orders = await loadPurchaseOrdersFromSupabase();
    
    // Ensure orders is always an array
    if (!orders || !Array.isArray(orders)) {
      purchaseOrders.value = [];
      return;
    }
    
    // If suppliers didn't load via relationship, manually load them
    const supplierList = await loadSuppliersFromSupabase();
    
    // Load items if not already loaded
    let allItems = inventoryItems.value;
    if (!allItems || !Array.isArray(allItems) || allItems.length === 0) {
      allItems = await loadItemsFromSupabase() || [];
    }
    
    purchaseOrders.value = orders.map(order => {
      // If supplier relationship didn't load, manually load supplier data
      if (!order.supplier && (order.supplierId || order.supplier_id)) {
        const supplierId = order.supplierId || order.supplier_id;
        const supplier = supplierList.find(s => s.id === supplierId);
        if (supplier) {
          order.supplier = supplier;
        }
      }
      
      // If items don't have nested item data, manually load item data
      if (order.items && order.items.length > 0) {
        order.items = order.items.map(poItem => {
          // If item relationship didn't load, manually load it
          if (!poItem.item) {
            const itemId = poItem.itemId || poItem.item_id;
            const item = allItems.find(i => i.id === itemId);
            if (item) {
              poItem.item = item;
            }
          }
          return poItem;
        });
      }
      
      return order;
    });
    
    console.log('✅ Purchase Orders loaded:', purchaseOrders.value.length);
    console.log('📋 Purchase Orders data:', purchaseOrders.value.map(o => ({
      id: o.id,
      poNumber: o.poNumber || o.po_number,
      status: o.status,
      supplier: o.supplier?.name || 'N/A'
    })));
  } catch (error) {
    console.error('❌ Error loading purchase orders:', error);
    showNotification('Error loading purchase orders: ' + (error.message || 'Unknown error'), 'error');
    // Ensure purchaseOrders is always an array even on error
    if (!purchaseOrders.value || !Array.isArray(purchaseOrders.value)) {
      purchaseOrders.value = [];
    }
  } finally {
    loading.value = false;
  }
};

const loadSuppliers = async () => {
  try {
    const supplierList = await loadSuppliersFromSupabase();
    suppliers.value = supplierList.filter(s => !s.deleted);
  } catch (error) {
    console.error('Error loading suppliers:', error);
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

const switchTab = (tab) => {
  activeTab.value = tab;
  currentPage.value = 1;
  clearSelection();
};

const openCreatePOModal = async () => {
  editingOrder.value = null;
  newOrder.value = {
    poNumber: '', // PO number will be generated only when submitted for review
    supplierId: '',
    orderDate: new Date().toISOString().split('T')[0],
    expectedDate: '',
    deliveryDate: new Date().toISOString().split('T')[0],
    deliveryTime: '',
    status: 'draft',
    destination: '',
    notes: '',
    items: []
  };
  // Reset search queries
  supplierSearchQuery.value = '';
  destinationSearchQuery.value = '';
  itemSearchQueries.value = {};
  showSupplierDropdown.value = false;
  showDestinationDropdown.value = false;
  showItemDropdowns.value = {};
  // Load destinations first so dropdown has options when modal opens
  try {
    const list = await loadLocationsForPO();
    destinationOptions.value = Array.isArray(list) ? list : [];
  } catch (e) {
    console.warn('Load destinations for PO:', e);
    destinationOptions.value = [];
  }
  showPOModal.value = true;
};

const closePOModal = () => {
  showPOModal.value = false;
  editingOrder.value = null;
  newOrder.value = {
    poNumber: '',
    supplierId: '',
    orderDate: new Date().toISOString().split('T')[0],
    expectedDate: '',
    deliveryDate: new Date().toISOString().split('T')[0],
    deliveryTime: '',
    status: 'draft',
    destination: '',
    notes: '',
    items: []
  };
  // Reset search queries
  supplierSearchQuery.value = '';
  destinationSearchQuery.value = '';
  itemSearchQueries.value = {};
  showSupplierDropdown.value = false;
  showDestinationDropdown.value = false;
  showItemDropdowns.value = {};
};

const editOrder = (order) => {
  editingOrder.value = order;
  newOrder.value = {
    poNumber: order.poNumber || order.po_number,
    supplierId: order.supplierId || order.supplier_id,
    orderDate: order.orderDate || order.order_date ? (order.orderDate || order.order_date).split('T')[0] : new Date().toISOString().split('T')[0],
    expectedDate: order.expectedDate || order.expected_date ? (order.expectedDate || order.expected_date).split('T')[0] : '',
    deliveryDate: order.deliveryDate || order.delivery_date ? (order.deliveryDate || order.delivery_date).split('T')[0] : new Date().toISOString().split('T')[0],
    deliveryTime: order.deliveryTime || order.delivery_time || '',
    status: order.status || order.status,
    destination: order.destination || '',
    notes: order.notes || '',
    items: (order.items || []).map(item => ({
      itemId: item.itemId || item.item_id,
      quantity: item.quantity || 0,
      unitPrice: item.unitPrice || item.unit_price || 0,
      vatRate: item.vatRate || item.vat_rate || 0,
      vatAmount: item.vatAmount || item.vat_amount || 0,
      totalAmount: item.totalAmount || item.total_amount || 0
    }))
  };
  // Reset search queries
  supplierSearchQuery.value = '';
  destinationSearchQuery.value = '';
  itemSearchQueries.value = {};
  showSupplierDropdown.value = false;
  showDestinationDropdown.value = false;
  showItemDropdowns.value = {};
  showPOModal.value = true;
};

const getAvailableItems = (currentIndex) => {
  // Get all selected item IDs except the current one
  const selectedItemIds = newOrder.value.items
    .map((item, idx) => idx !== currentIndex ? item.itemId : null)
    .filter(id => id);
  
  // Filter out already selected items
  return inventoryItems.value.filter(item => 
    !selectedItemIds.includes(item.id)
  );
};

// Searchable dropdown computed properties and functions
const filteredSuppliers = computed(() => {
  if (!supplierSearchQuery.value) {
    return suppliers.value;
  }
  const query = supplierSearchQuery.value.toLowerCase();
  return suppliers.value.filter(supplier => {
    const name = (supplier.name || '').toLowerCase();
    const nameLocalized = (supplier.nameLocalized || '').toLowerCase();
    return name.includes(query) || nameLocalized.includes(query);
  });
});

// ONLY from Supabase inventory_locations (allow_grn) — no hardcoded list
const filteredDestinations = computed(() => {
  const destinations = destinationOptions.value || [];
  if (!destinationSearchQuery.value) return destinations;
  const query = destinationSearchQuery.value.toLowerCase();
  return destinations.filter(dest => (dest || '').toLowerCase().includes(query));
});

const getFilteredItems = (index) => {
  const availableItems = getAvailableItems(index);
  const searchQuery = itemSearchQueries.value[index] || '';
  
  if (!searchQuery) {
    return availableItems;
  }
  
  const query = searchQuery.toLowerCase();
  return availableItems.filter(item => {
    const name = (item.name || '').toLowerCase();
    const nameLocalized = (item.nameLocalized || '').toLowerCase();
    const sku = (item.sku || '').toLowerCase();
    return name.includes(query) || nameLocalized.includes(query) || sku.includes(query);
  });
};

const getSelectedSupplierName = () => {
  if (!newOrder.value.supplierId) return '';
  const supplier = suppliers.value.find(s => s.id === newOrder.value.supplierId);
  if (!supplier) return '';
  return supplier.nameLocalized ? `${supplier.name} (${supplier.nameLocalized})` : supplier.name;
};

const getSelectedItemName = (index) => {
  const item = newOrder.value.items[index];
  if (!item || !item.itemId) return '';
  const invItem = inventoryItems.value.find(i => i.id === item.itemId);
  if (!invItem) return '';
  return invItem.nameLocalized ? `${invItem.name} (${invItem.nameLocalized})` : invItem.name;
};

const selectSupplier = (supplier) => {
  newOrder.value.supplierId = supplier.id;
  supplierSearchQuery.value = '';
  showSupplierDropdown.value = false;
};

const selectDestination = (destination) => {
  newOrder.value.destination = destination;
  destinationSearchQuery.value = '';
  showDestinationDropdown.value = false;
};

const selectItem = (index, invItem) => {
  newOrder.value.items[index].itemId = invItem.id;
  itemSearchQueries.value[index] = '';
  showItemDropdowns.value[index] = false;
  updateItemTotal(index);
};

const addOrderItem = () => {
  const newIndex = newOrder.value.items.length;
  newOrder.value.items.push({
    itemId: '',
    quantity: 0,
    unitPrice: 0,
    vatRate: 0,
    vatAmount: 0,
    totalAmount: 0
  });
  // Initialize search query for new item
  itemSearchQueries.value[newIndex] = '';
  showItemDropdowns.value[newIndex] = false;
};

const removeOrderItem = (index) => {
  newOrder.value.items.splice(index, 1);
  // Clean up search queries
  delete itemSearchQueries.value[index];
  delete showItemDropdowns.value[index];
  // Reindex remaining items
  const newQueries = {};
  const newDropdowns = {};
  newOrder.value.items.forEach((item, idx) => {
    if (itemSearchQueries.value[idx] !== undefined) {
      newQueries[idx] = itemSearchQueries.value[idx];
    }
    if (showItemDropdowns.value[idx] !== undefined) {
      newDropdowns[idx] = showItemDropdowns.value[idx];
    }
  });
  itemSearchQueries.value = newQueries;
  showItemDropdowns.value = newDropdowns;
  calculateTotals();
};

const getItemSKU = (itemId) => {
  if (!itemId) return '';
  const invItem = inventoryItems.value.find(item => item.id === itemId);
  return invItem?.sku || 'N/A';
};

const getItemStorageUnit = (itemId) => {
  if (!itemId) return '';
  const invItem = inventoryItems.value.find(item => item.id === itemId);
  // Check both camelCase and snake_case
  return invItem?.storageUnit || invItem?.storage_unit || 'Pcs';
};

const updateItemTotal = (index) => {
  const item = newOrder.value.items[index];
  const quantity = item.quantity || 0;
  const unitPrice = item.unitPrice || 0;
  const vatRate = item.vatRate || 0;
  
  // Auto-populate unit price from item cost if not set
  if (item.itemId && !item.unitPrice) {
    const invItem = inventoryItems.value.find(i => i.id === item.itemId);
    if (invItem && invItem.cost) {
      item.unitPrice = invItem.cost;
    }
  }
  
  const subtotal = quantity * unitPrice;
  const vatAmount = subtotal * (vatRate / 100);
  const totalAmount = subtotal + vatAmount;
  
  item.vatAmount = vatAmount;
  item.totalAmount = totalAmount;
};

const calculateTotals = () => {
  newOrder.value.items.forEach((item, index) => {
    updateItemTotal(index);
  });
};

const savePurchaseOrder = async () => {
  if (!newOrder.value.supplierId) {
    showNotification('Please select a supplier', 'warning');
    return;
  }
  
  if (!newOrder.value.destination) {
    showNotification('Please select a destination', 'warning');
    return;
  }
  
  if (newOrder.value.items.length === 0) {
    showNotification('Please add at least one item', 'warning');
    return;
  }
  
  saving.value = true;
  try {
    // Get current user name
    const getCurrentUserName = () => {
      const user = authStore.user;
      if (user) {
        return user.name || user.fullName || user.email?.split('@')[0] || 'Unknown User';
      }
      // Fallback to localStorage
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
    
    const currentUserName = getCurrentUserName();
    
    // Get supplier name from suppliers list
    const selectedSupplier = suppliers.value.find(s => s.id === newOrder.value.supplierId);
    const supplierName = selectedSupplier ? selectedSupplier.name : null;
    
    // For new orders (drafts), ensure status is 'draft' and PO number can be empty
    const orderStatus = editingOrder.value ? newOrder.value.status : 'draft';
    
    const orderData = {
      poNumber: newOrder.value.poNumber || null, // Can be null for drafts
      supplierId: newOrder.value.supplierId,
      supplierName: supplierName, // Add supplier name
      orderDate: newOrder.value.orderDate,
      businessDate: newOrder.value.orderDate, // Use orderDate as business_date
      expectedDate: newOrder.value.expectedDate || null,
      deliveryDate: newOrder.value.deliveryDate || null,
      deliveryTime: newOrder.value.deliveryTime || null,
      status: orderStatus, // Ensure 'draft' for new orders
      destination: newOrder.value.destination,
      notes: newOrder.value.notes || null,
      totalAmount: totalAmount.value,
      vatAmount: totalVAT.value,
      creator: currentUserName, // Save creator name
      createdBy: currentUserName, // Also save as createdBy for database
      items: newOrder.value.items.map(item => ({
        itemId: item.itemId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        vatRate: item.vatRate,
        vatAmount: item.vatAmount,
        totalAmount: item.totalAmount
      }))
    };
    
    let result;
    if (editingOrder.value) {
      result = await updatePurchaseOrderInSupabase(editingOrder.value.id, orderData);
    } else {
      result = await savePurchaseOrderToSupabase(orderData);
    }
    
    if (result.success) {
      showNotification(
        editingOrder.value ? 'Purchase order updated successfully' : 'Purchase order created successfully as draft',
        'success'
      );
      closePOModal();
      
      // Switch to draft tab if creating new order
      if (!editingOrder.value) {
        switchTab('draft');
      }
      
      // Reload purchase orders to show the new draft
      await loadPurchaseOrders();
      // Force refresh status/stock/flow (no cached state)
      const { forceRefreshAfterAction } = await import('@/services/erpViews.js');
      await forceRefreshAfterAction();
    } else {
      // Show detailed error message
      const errorMsg = result.error || 'Failed to save purchase order';
      const errorDetails = result.details ? ` Details: ${JSON.stringify(result.details)}` : '';
      const errorHint = result.hint ? ` Hint: ${result.hint}` : '';
      throw new Error(errorMsg + errorDetails + errorHint);
    }
  } catch (error) {
    console.error('Error saving purchase order:', error);
    showNotification('Error saving purchase order: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const viewOrder = (order) => {
  router.push(`/homeportal/purchase-order-detail/${order.id}`);
};

const deleteOrder = async (orderId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Purchase Order',
    message: 'Are you sure you want to delete this purchase order? This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deletePurchaseOrderFromSupabase(orderId);
    if (result.success) {
      showNotification('Purchase order deleted successfully', 'success');
      await loadPurchaseOrders();
    } else {
      throw new Error(result.error || 'Failed to delete purchase order');
    }
  } catch (error) {
    console.error('Error deleting purchase order:', error);
    showNotification('Error deleting purchase order: ' + (error.message || 'Unknown error'), 'error');
  }
};

const toggleSelectAll = () => {
  if (allSelected.value) {
    paginatedOrders.value.forEach(order => {
      const index = selectedOrders.value.indexOf(order.id);
      if (index > -1) selectedOrders.value.splice(index, 1);
    });
  } else {
    paginatedOrders.value.forEach(order => {
      if (!selectedOrders.value.includes(order.id)) {
        selectedOrders.value.push(order.id);
      }
    });
  }
};

const toggleSelectOrder = (orderId) => {
  const index = selectedOrders.value.indexOf(orderId);
  if (index > -1) {
    selectedOrders.value.splice(index, 1);
  } else {
    selectedOrders.value.push(orderId);
  }
};

const clearSelection = () => {
  selectedOrders.value = [];
  showBulkActionsMenu.value = false;
};

const toggleBulkActionsMenu = () => {
  showBulkActionsMenu.value = !showBulkActionsMenu.value;
};

const toggleExportMenu = () => {
  showExportMenu.value = !showExportMenu.value;
};

const toggleOrderActions = (orderId) => {
  activeOrderActions.value = activeOrderActions.value === orderId ? null : orderId;
};

const bulkDeleteOrders = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Purchase Orders',
    message: `Are you sure you want to delete ${selectedOrders.value.length} purchase order(s)? This action cannot be undone.`,
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const results = await Promise.allSettled(
      selectedOrders.value.map(id => deletePurchaseOrderFromSupabase(id))
    );
    
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
    showNotification(
      `Deleted ${successCount} of ${selectedOrders.value.length} purchase order(s)`,
      successCount === selectedOrders.value.length ? 'success' : 'warning'
    );
    
    clearSelection();
    await loadPurchaseOrders();
  } catch (error) {
    console.error('Error deleting purchase orders:', error);
    showNotification('Error deleting purchase orders', 'error');
  }
};

const exportAllPurchaseOrders = () => {
  exportPurchaseOrders(filteredOrders.value);
};

const exportSelectedPurchaseOrders = () => {
  const selected = purchaseOrders.value.filter(o => selectedOrders.value.includes(o.id));
  exportPurchaseOrders(selected);
};

const bulkExportOrders = () => {
  exportSelectedPurchaseOrders();
};

const exportPurchaseOrders = (orders) => {
  const data = orders.map(order => ({
    'PO Number': order.poNumber || order.po_number || 'Draft',
    'Supplier': order.supplier?.name || 'N/A',
    'Destination': order.destination || '—',
    'Status': formatStatus(order.status || order.status),
    'Order Date': formatDate(order.orderDate || order.order_date),
    'Expected Date': order.expectedDate || order.expected_date ? formatDate(order.expectedDate || order.expected_date) : '',
    'Total Amount': order.totalAmount || order.total_amount || 0,
    'VAT Amount': order.vatAmount || order.vat_amount || 0,
    'Created At': formatDate(order.createdAt || order.created_at)
  }));
  
  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Purchase Orders');
  XLSX.writeFile(wb, `purchase_orders_${new Date().toISOString().split('T')[0]}.xlsx`);
  
  showNotification('Purchase orders exported successfully', 'success');
  showExportMenu.value = false;
};

const openFilter = () => {
  // Copy current filter criteria to temp when opening modal
  tempFilterCriteria.value = JSON.parse(JSON.stringify(filterCriteria.value));
  showFilterModal.value = true;
};

const closeFilter = () => {
  showFilterModal.value = false;
};

const applyFilter = () => {
  // Copy temp filter criteria to actual filter criteria when Apply is clicked
  filterCriteria.value = JSON.parse(JSON.stringify(tempFilterCriteria.value));
  currentPage.value = 1;
  closeFilter();
};

const clearFilter = () => {
  const emptyFilter = {
    poNumber: '',
    poNumberMode: 'including',
    businessDate: '',
    status: '',
    statusMode: 'including',
    destination: '',
    destinationMode: 'including',
    supplierId: '',
    supplierMode: 'including',
    creator: '',
    creatorMode: 'including',
    submitter: '',
    submitterMode: 'including',
    approver: '',
    approverMode: 'including',
    updatedAfter: '',
    deliveryDate: '',
    totalAmountMin: null,
    totalAmountMax: null,
    itemsCountMin: null,
    itemsCountMax: null
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

const formatStatus = (status) => {
  const statusMap = {
    'draft': 'Draft',
    'pending': 'Pending',
    'closed': 'Closed',
    'received': 'Received',
    'partial': 'Partial',
    'completed': 'Completed',
    'cancelled': 'Cancelled'
  };
  return statusMap[status] || status;
};

const getStatusClass = (status) => {
  const classMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'closed': 'bg-green-100 text-green-800',
    'received': 'bg-blue-100 text-blue-800',
    'partial': 'bg-orange-100 text-orange-800',
    'completed': 'bg-green-100 text-green-800',
    'cancelled': 'bg-red-100 text-red-800'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800';
};

const formatDate = (date) => {
  if (!date) return 'N/A';
  const d = new Date(date);
  return d.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
};

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'SAR'
  }).format(amount || 0);
};

const showNotification = (message, type = 'info') => {
  if (window.showNotification) {
    window.showNotification(message, type);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

// Receiving Status Calculation Functions
// PRIORITY: Use database-calculated receiving_status first (SAP style)
// PRIORITY: Use database-calculated receiving_status (SAP style)
const getPOReceivingStatus = (order) => {
  if (!order) {
    return 'not_received_yet';
  }
  
  // STRICT: Use ONLY the database-calculated receiving_status field
  // This is maintained by PostgreSQL triggers (v_po_receipt_summary)
  const dbStatus = order.receiving_status || order.receivingStatus;
  
  if (dbStatus) {
    const normalizedStatus = dbStatus.toLowerCase();
    
    // Map standard DB statuses to frontend keys
    if (normalizedStatus === 'fully_received') return 'fully_received';
    if (normalizedStatus === 'partial_received' || normalizedStatus === 'partially_received') return 'partially_received';
    if (normalizedStatus === 'not_received') return 'not_received_yet';
    
    return normalizedStatus;
  }
  
  return 'not_received_yet'; 
};

const getReceivingStatusText = (status) => {
  const statusMap = {
    'fully_received': 'Received All',
    'partially_received': 'Partially Received',
    'not_received_yet': 'Not Received Yet'
  };
  return statusMap[status] || 'Not Received Yet';
};

const getReceivingStatusClass = (status) => {
  const classMap = {
    'fully_received': 'bg-emerald-100 text-emerald-800 border border-emerald-300',
    'partially_received': 'bg-amber-100 text-amber-800 border border-amber-300',
    'not_received_yet': 'bg-blue-100 text-blue-800 border border-blue-300'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800 border border-gray-300';
};

const getReceivingStatusIcon = (status) => {
  const iconMap = {
    'fully_received': 'fas fa-check-circle',
    'partially_received': 'fas fa-exclamation-triangle',
    'not_received_yet': 'fas fa-box'
  };
  return iconMap[status] || 'fas fa-box';
};

const getReceivingStatusTooltip = (order) => {
  const status = getPOReceivingStatus(order);
  if (status === 'fully_received') {
    return t('inventory.purchaseOrders.receivingStatusFullyReceived');
  } else if (status === 'partially_received') {
    return t('inventory.purchaseOrders.receivingStatusPartiallyReceived');
  } else {
    return t('inventory.purchaseOrders.noItemsReceivedYet');
  }
};

// Close dropdowns when clicking outside
onMounted(async () => {
  const route = useRoute();
  console.log('🟢 [PurchaseOrders.vue] Component MOUNTED', {
    fullPath: route.fullPath,
    path: route.path,
    name: route.name,
    matched: route.matched.map(r => ({ path: r.path, name: r.name })),
    params: route.params
  });
  // Load suppliers and items first so they're available when loading purchase orders
  await loadInventoryItems();
  await loadSuppliers();
  destinationOptions.value = await loadLocationsForPO();
  await loadPurchaseOrders();
  
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.relative') && !e.target.closest('.dropdown-menu')) {
      showBulkActionsMenu.value = false;
      showExportMenu.value = false;
      activeOrderActions.value = null;
    }
  });
});
</script>

<style scoped>
.tab-button.active {
  border-bottom: 2px solid #284b44;
  color: #284b44;
}

.sakura-primary-btn {
  background-color: #284b44;
  transition: background-color 0.2s ease;
}

.sakura-primary-btn:hover:not(:disabled) {
  background-color: #1f3a35;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 0.5rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  min-width: 200px;
  z-index: 1000;
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

