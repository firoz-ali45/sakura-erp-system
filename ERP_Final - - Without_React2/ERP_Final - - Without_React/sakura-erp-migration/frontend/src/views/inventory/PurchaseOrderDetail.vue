<template>
  <div class="bg-[#f0e1cd] p-4 md:p-6 min-h-screen">
    <!-- Header Section -->
    <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-4 md:mb-6 bg-white rounded-lg shadow-sm p-4 md:p-6 mx-auto max-w-7xl">
      <div class="flex items-center gap-4 flex-1 min-w-0">
        <button @click.stop.prevent="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2 flex-shrink-0">
          <i class="fas fa-arrow-left"></i>
            <span>{{ $t('common.back') }}</span>
        </button>
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <h1 class="text-2xl md:text-3xl font-bold text-gray-800 truncate">
            {{ $t('inventory.purchaseOrders.title') }} – {{ formatStatus(orderStatus) }}
          </h1>
          <span 
            v-if="order"
            :class="[
              'px-3 py-1 rounded-full text-sm font-semibold flex-shrink-0',
              getStatusClass(orderStatus)
            ]"
          >
            {{ formatStatus(orderStatus) }}
          </span>
        </div>
      </div>
      <div class="flex flex-col md:flex-row items-stretch md:items-center gap-2 md:gap-3 justify-end w-full md:w-auto">
        <!-- Draft Status Actions -->
        <template v-if="orderStatus === 'draft'">
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ $t('common.print') }}</span>
          </button>
          <button 
            @click="deleteOrderPermanently" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-trash"></i>
            <span>{{ $t('inventory.grn.deletePermanently') }}</span>
          </button>
          <button 
            @click="editOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-edit"></i>
            <span>{{ $t('common.edit') }}</span>
          </button>
          <button 
            @click.stop.prevent="submitForReview" 
            type="button"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn hover:opacity-90 transition-opacity cursor-pointer"
            style="pointer-events: auto; z-index: 10; position: relative;"
          >
            <i class="fas fa-paper-plane"></i>
            <span>{{ $t('inventory.purchaseOrders.submitForReview') }}</span>
          </button>
        </template>
        
        <!-- Pending Status Actions -->
        <template v-else-if="orderStatus === 'pending'">
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ $t('common.print') }}</span>
          </button>
          <button 
            @click="editOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-edit"></i>
            <span>{{ $t('common.edit') }}</span>
          </button>
          <button 
            @click="rejectOrder" 
            class="px-4 py-2 bg-white border border-red-300 rounded-lg hover:bg-red-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-times"></i>
            <span>{{ $t('common.reject') }}</span>
          </button>
          <button 
            @click.stop.prevent="approveOrder" 
            type="button"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn hover:opacity-90 transition-opacity cursor-pointer"
            style="pointer-events: auto; z-index: 10; position: relative;"
          >
            <i class="fas fa-check"></i>
            <span>{{ $t('inventory.purchaseOrders.approve') }}</span>
          </button>
        </template>
        
        <!-- Approved/Partially Received Status Actions -->
        <template v-else-if="poStatus === 'approved' || poStatus === 'partially_received' || poStatus === 'fully_received' || poStatus === 'closed' || orderStatus === 'approved' || orderStatus === 'partially_received' || orderStatus === 'fully_received' || orderStatus === 'closed'">
          <button 
            v-if="poStatus !== 'closed' && poStatus !== 'fully_received' && orderStatus !== 'closed' && orderStatus !== 'fully_received'"
            @click="closeOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-check"></i>
            <span>{{ $t('inventory.purchaseOrders.close') }}</span>
          </button>
          <button 
            @click="printOrder" 
            class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <i class="fas fa-print"></i>
            <span>{{ $t('common.print') }}</span>
          </button>
        </template>
        <!-- Create GRN Button - DB-driven: shown only when fn_can_create_next_document('PO', id) is true -->
          <button 
          v-if="order && !loading && canCreateGRN"
          :disabled="saving"
          @click.stop.prevent="onCreateGRN"
          @mousedown="console.log('🔥 BUTTON MOUSEDOWN', { canCreateGRN, saving })"
          @mouseup="console.log('🔥 BUTTON MOUSEUP')"
            type="button"
          class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold sakura-primary-btn hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          :class="{ 'opacity-50 cursor-not-allowed': saving }"
          style="pointer-events: auto !important; z-index: 9999; position: relative; cursor: pointer !important;"
          id="create-grn-button"
          >
            <i class="fas fa-clipboard-list"></i>
            <span>{{ $t('inventory.purchaseOrders.createGRN') }}</span>
          </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="bg-white rounded-lg shadow-md p-12 text-center mx-4 md:mx-6">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">{{ $t('inventory.purchaseOrders.loadingDetails') }}</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-white rounded-lg shadow-md p-6 mx-4 md:mx-6">
      <div class="text-center">
        <p class="text-red-600 mb-4">{{ error }}</p>
        <button @click="goBack" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
          ← Go Back
        </button>
      </div>
    </div>

    <!-- Order Details -->
    <div v-else-if="order" class="space-y-4 md:space-y-6 px-4 md:px-6 pb-4 md:pb-6 mx-auto max-w-7xl">
      <!-- Order Information Card -->
      <div class="bg-white rounded-lg shadow-md p-4 md:p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6 items-start">
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Supplier</label>
              <p class="text-gray-900 font-medium">
                <template v-if="order.supplier">
                  {{ order.supplier.name || 'N/A' }}
                  <span v-if="order.supplier.nameLocalized" class="text-gray-500">
                    ({{ order.supplier.nameLocalized }})
                  </span>
                </template>
                <template v-else-if="getSupplierName(order.supplierId || order.supplier_id)">
                  {{ getSupplierName(order.supplierId || order.supplier_id) }}
                  <span v-if="getSupplierLocalizedName(order.supplierId || order.supplier_id)" class="text-gray-500">
                    ({{ getSupplierLocalizedName(order.supplierId || order.supplier_id) }})
                  </span>
                </template>
                <template v-else>
                  N/A
                </template>
              </p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Business Date</label>
              <p class="text-gray-900">{{ order.businessDate ? formatDate(order.businessDate) : '—' }}</p>
            </div>
            <div v-if="orderStatus === 'pending' || orderStatus === 'approved'" class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Submitter</label>
              <p class="text-gray-900">{{ order.submitter || order.creator || 'N/A' }}</p>
            </div>
            <div v-else class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Creator</label>
              <p class="text-gray-900">{{ order.creator || 'N/A' }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Created At</label>
              <p class="text-gray-900">{{ formatDateTime(order.createdAt || order.created_at) }}</p>
            </div>
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Delivery Date</label>
              <p class="text-gray-900">{{ order.deliveryDate || order.expectedDate || order.expected_date ? formatDate(order.deliveryDate || order.expectedDate || order.expected_date) : '—' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Number of Items</label>
              <p class="text-gray-900 font-semibold">{{ (order.items || []).length }}</p>
            </div>
          </div>
          <div class="space-y-4">
            <div class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Destination</label>
              <p class="text-gray-900">{{ order.destination || '—' }}</p>
            </div>
            <div v-if="orderStatus === 'approved'" class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">Approver</label>
              <p class="text-gray-900">{{ order.approver || order.creator || 'N/A' }}</p>
            </div>
            <div v-if="order.notes" class="pb-4 border-b border-gray-200">
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ $t('inventory.purchaseOrders.notes') }}</label>
              <p class="text-gray-900">{{ order.notes }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">{{ $t('inventory.purchaseOrders.purchaseOrderTotalCost') }}</label>
              <p class="text-gray-900 font-semibold text-lg" style="color: #284b44;">
                {{ formatCurrency(order.totalAmount || order.total_amount || 0) }}
              </p>
            </div>
            <!-- Receiving Status Indicator (Real-time Tracking) -->
            <div v-if="orderStatus === 'approved' || orderStatus === 'fully_received' || orderStatus === 'partially_received'" class="mt-4 p-4 rounded-lg border-2" :class="getReceivingStatusClass()">
              <div class="flex items-center gap-3">
                <i :class="getReceivingStatusIcon()" class="text-2xl"></i>
                <div>
                  <label class="block text-sm font-semibold mb-1">{{ $t('inventory.purchaseOrders.receivingStatus') }}</label>
                  <p class="text-lg font-bold">{{ getReceivingStatusText() }}</p>
                  <p v-if="receivingStatusDetails" class="text-xs mt-1 opacity-90">{{ receivingStatusDetails }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Order Items Card -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-800">{{ $t('inventory.purchaseOrders.items') }}</h2>
          <div class="flex items-center gap-3" v-if="orderStatus === 'draft' || orderStatus === 'pending'">
            <button 
              @click="openEditQuantitiesModal"
              class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-edit"></i>
              <span>{{ $t('inventory.purchaseOrders.editQuantitiesCost') }}</span>
            </button>
            <button 
              @click="openImportItemsModal"
              class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-upload"></i>
              <span>{{ $t('inventory.purchaseOrders.importItems') }}</span>
            </button>
            <button 
              @click="openAddItemsModal"
              class="px-4 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
            >
              <i class="fas fa-plus"></i>
              <span>{{ $t('inventory.purchaseOrders.addItems') }}</span>
            </button>
          </div>
        </div>
        
        <div class="overflow-x-auto">
          <table class="w-full border-collapse">
            <thead class="bg-gray-50">
              <tr>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.name') }}</th>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.sku') }}</th>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.availableQuantity') }}</th>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.costPerUnit') }}</th>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.orderedQuantity') }}</th>
                <th v-if="shouldShowReceivingColumns" :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200 bg-green-50', textAlign]">
                  <i class="fas fa-check-circle text-green-600 mr-1"></i>{{ $t('inventory.purchaseOrders.receivedQuantity') }}
                </th>
                <th v-if="shouldShowReceivingColumns" :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200 bg-orange-50', textAlign]">
                  <i class="fas fa-clock text-orange-600 mr-1"></i>{{ $t('inventory.purchaseOrders.remainingQuantity') }}
                </th>
                <th :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('inventory.purchaseOrders.totalCost') }}</th>
                <th v-if="orderStatus === 'draft' || orderStatus === 'pending'" :class="['px-4 py-3 text-sm font-semibold text-gray-700 border border-gray-200', textAlign]">{{ $t('common.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!order.items || order.items.length === 0">
                <td :colspan="getItemsTableColspan()" class="px-4 py-8 text-center text-gray-500 border border-gray-200">
                  {{ $t('inventory.purchaseOrders.noDataToDisplay') }}
                </td>
              </tr>
              <tr v-for="(item, index) in order.items || []" :key="index" class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm text-gray-900 border border-gray-200 text-center">
                  {{ getItemName(item) }}
                  <span v-if="getItemNameLocalized(item)" class="text-gray-500 block text-xs mt-1">
                    /{{ getItemNameLocalized(item) }}
                  </span>
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 font-mono border border-gray-200 text-center">
                  {{ getItemSKU(item) }}
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 border border-gray-200 text-center">
                  {{ getAvailableQuantity(item.item) }} {{ getItemUnit(item.item) }}
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 border border-gray-200 text-center">
                  {{ formatCurrency(item.unitPrice || item.unit_price || 0) }}
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 font-semibold border border-gray-200 text-center">
                  {{ item.quantity || 0 }} {{ getItemUnit(item.item) }}
                </td>
                <td v-if="shouldShowReceivingColumns" class="px-4 py-3 text-sm font-semibold border border-gray-200 text-center" :class="getReceivedQuantityForPOItem(item) > 0 ? 'text-green-600' : 'text-gray-500'">
                  {{ getReceivedQuantityForPOItem(item).toFixed(2) }} {{ getItemUnit(item.item) }}
                </td>
                <td v-if="shouldShowReceivingColumns" class="px-4 py-3 text-sm font-semibold border border-gray-200 text-center" :class="getRemainingQuantityForPOItem(item) > 0 ? 'text-orange-600' : 'text-gray-400'">
                  {{ getRemainingQuantityForPOItem(item).toFixed(2) }} {{ getItemUnit(item.item) }}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 font-semibold border border-gray-200 text-center">
                  {{ formatCurrency(item.totalAmount || item.total_amount || 0) }}
                </td>
                <td v-if="orderStatus === 'draft' || orderStatus === 'pending'" class="px-4 py-3 border border-gray-200 text-center">
                  <div class="flex items-center justify-center gap-3">
                    <button 
                      @click.stop="openUpdateItemModal(item, index)"
                      class="text-blue-600 hover:text-blue-800"
                      :title="$t('inventory.purchaseOrders.editItem')"
                    >
                      <i class="fas fa-edit"></i>
                    </button>
                    <button 
                      @click.stop="deleteItemFromOrder(index)"
                      class="text-red-600 hover:text-red-800"
                      :title="$t('inventory.purchaseOrders.deleteItem')"
                    >
                      <i class="fas fa-trash"></i>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <!-- GRN References Section - Show received quantities by GRN -->
        <div v-if="shouldShowReceivingColumns" class="mt-8 pt-8 border-t-2 border-[#284b44]">
          <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] rounded-lg p-5 mb-6 shadow-lg">
            <h3 class="text-xl font-bold text-white mb-2 flex items-center gap-3">
              <i class="fas fa-receipt text-white text-2xl"></i>
              <span>{{ $t('inventory.purchaseOrders.grnsAgainstPO') }}</span>
              <span v-if="grns.length > 0" class="text-sm font-normal text-green-200 ml-auto bg-white/20 px-4 py-2 rounded-full">
                {{ grns.length }} {{ $t('inventory.grn.title') }}{{ grns.length !== 1 ? 's' : '' }}
              </span>
          </h3>
            <p class="text-green-100 text-sm flex items-center gap-2">
              <i class="fas fa-info-circle"></i>
              <span>{{ $t('inventory.purchaseOrders.trackGoodsReceived') }}</span>
            </p>
          </div>
          
          <div v-if="grns.length === 0" class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300 mb-6">
            <i class="fas fa-inbox text-4xl text-gray-400 mb-3"></i>
            <p class="text-gray-500 font-medium">{{ $t('inventory.purchaseOrders.noGRNsCreated') }}</p>
            <p class="text-gray-400 text-sm mt-1">{{ $t('inventory.purchaseOrders.createGRNFromPO') }}</p>
          </div>
          
          <div v-for="(poItem, itemIndex) in order.items || []" :key="itemIndex" class="mb-8 last:mb-0">
            <!-- Item Summary Card -->
            <div class="bg-gradient-to-r from-blue-50 via-green-50 to-orange-50 rounded-lg p-5 mb-4 border-2 border-gray-200 shadow-md hover:shadow-lg transition-shadow">
              <div class="flex items-center gap-3 mb-4">
                <div class="bg-[#284b44] text-white p-2 rounded-lg">
                  <i class="fas fa-box text-xl"></i>
                </div>
                <div class="flex-1">
                  <span class="font-bold text-gray-900 text-lg">
                  {{ poItem.item?.name || 'N/A' }}
                    <span v-if="poItem.item?.nameLocalized" class="text-gray-600 text-base font-normal">
                    /{{ poItem.item.nameLocalized }}
                  </span>
                </span>
                  <span class="ml-3 text-sm text-gray-500 font-mono bg-white px-2 py-1 rounded border border-gray-300">SKU: {{ poItem.item?.sku || 'N/A' }}</span>
              </div>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="bg-white rounded-lg p-3 border-2 border-blue-200 shadow-sm">
                  <div class="flex items-center gap-2 mb-1">
                  <i class="fas fa-shopping-cart text-blue-600"></i>
                    <span class="text-xs text-gray-600 font-semibold uppercase">{{ $t('inventory.purchaseOrders.ordered') }}</span>
                </div>
                  <span class="text-xl font-bold text-blue-700">{{ poItem.quantity || 0 }} {{ getItemUnit(poItem.item) }}</span>
                </div>
                <div class="bg-white rounded-lg p-3 border-2 border-green-200 shadow-sm">
                  <div class="flex items-center gap-2 mb-1">
                  <i class="fas fa-check-circle text-green-600"></i>
                    <span class="text-xs text-gray-600 font-semibold uppercase">{{ $t('inventory.purchaseOrders.received') }}</span>
                </div>
                  <span class="text-xl font-bold text-green-700">{{ getReceivedQuantityForPOItem(poItem).toFixed(2) }} {{ getItemUnit(poItem.item) }}</span>
                </div>
                <div class="bg-white rounded-lg p-3 border-2 border-orange-200 shadow-sm">
                  <div class="flex items-center gap-2 mb-1">
                  <i class="fas fa-clock text-orange-600"></i>
                    <span class="text-xs text-gray-600 font-semibold uppercase">{{ $t('inventory.purchaseOrders.remaining') }}</span>
                  </div>
                  <span class="text-xl font-bold text-orange-700">{{ getRemainingQuantityForPOItem(poItem).toFixed(2) }} {{ getItemUnit(poItem.item) }}</span>
                </div>
              </div>
            </div>
            
            <!-- GRN Details Table -->
            <div v-if="getGRNsForItem(poItem).length > 0" class="overflow-x-auto shadow-lg rounded-lg border-2 border-gray-200">
              <table class="w-full border-collapse bg-white">
                <thead class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white">
                  <tr>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.grnReference') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.status') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.receivedQty') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.unitCost') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.totalCost') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold border-r border-white/20', textAlign]">{{ $t('inventory.purchaseOrders.receivedDate') }}</th>
                    <th :class="['px-5 py-4 text-sm font-bold', textAlign]">{{ $t('common.actions') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(grn, grnIndex) in getGRNsForItem(poItem)" :key="grn.id" 
                      class="hover:bg-green-50 transition-all duration-200 border-b border-gray-200"
                      :class="grnIndex % 2 === 0 ? 'bg-white' : 'bg-gray-50'">
                    <td class="px-5 py-4 text-sm text-center border-r border-gray-200">
                      <div class="flex flex-col items-center gap-2">
                        <div class="bg-[#284b44] text-white px-3 py-1.5 rounded-lg font-bold text-sm shadow-md">
                          {{ grn.grnNumber || grn.grn_number || 'Draft' }}
                        </div>
                        <span v-if="grn.grnNumber || grn.grn_number" class="text-xs text-gray-500 font-mono bg-gray-100 px-2 py-0.5 rounded">
                          ID: {{ grn.id?.substring(0, 8) || 'N/A' }}
                        </span>
                      </div>
                    </td>
                    <td class="px-5 py-4 text-sm text-center border-r border-gray-200">
                      <span :class="[
                            getGRNStatusClass(grn.status),
                            'px-3 py-2 rounded-lg text-xs font-bold inline-block shadow-sm border-2',
                            {
                              'border-green-300': grn.status === 'approved' || grn.status === 'passed',
                              'border-yellow-300': grn.status === 'pending' || grn.status === 'draft',
                              'border-red-300': grn.status === 'rejected',
                              'border-gray-300': !grn.status || grn.status === 'cancelled'
                            }
                          ]">
                        <i class="fas fa-circle text-[6px] mr-1.5"></i>
                        {{ formatGRNStatus(grn.status) }}
                      </span>
                    </td>
                    <td class="px-5 py-4 text-sm font-bold text-center border-r border-gray-200">
                      <div class="inline-flex items-center gap-2 bg-green-100 text-green-800 px-3 py-2 rounded-lg border-2 border-green-300 shadow-sm">
                        <i class="fas fa-check-circle"></i>
                        <span class="text-lg">{{ getReceivedQtyFromGRN(grn, poItem).toFixed(2) }}</span>
                        <span class="text-xs">{{ getItemUnit(poItem.item) }}</span>
                      </div>
                    </td>
                    <td class="px-5 py-4 text-sm text-gray-700 text-center border-r border-gray-200 font-semibold">
                      {{ formatCurrency(poItem.unitPrice || poItem.unit_price || 0) }}
                    </td>
                    <td class="px-5 py-4 text-sm font-bold text-gray-900 text-center border-r border-gray-200">
                      <div class="bg-blue-50 text-blue-900 px-3 py-2 rounded-lg border border-blue-200 shadow-sm">
                      {{ formatCurrency((getReceivedQtyFromGRN(grn, poItem) * (poItem.unitPrice || poItem.unit_price || 0)).toFixed(2)) }}
                      </div>
                    </td>
                    <td class="px-5 py-4 text-sm text-gray-700 text-center border-r border-gray-200">
                      <div class="flex flex-col items-center gap-1">
                        <i class="fas fa-calendar text-gray-400"></i>
                        <span class="font-semibold">{{ formatDate(grn.grnDate || grn.grn_date || grn.createdAt || grn.created_at) }}</span>
                      </div>
                    </td>
                    <td class="px-5 py-4 text-sm text-center">
                      <button 
                        @click.stop.prevent="viewGRNDetail(grn.id)"
                        class="inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-bold text-white bg-gradient-to-r from-[#284b44] to-[#1e3a35] border-2 border-[#284b44] rounded-lg hover:from-[#1e3a35] hover:to-[#284b44] hover:shadow-lg transition-all cursor-pointer shadow-md hover:scale-105 transform duration-200"
                        :title="$t('inventory.purchaseOrders.viewGRNDetails')"
                      >
                        <i class="fas fa-eye"></i>
                        <span>{{ $t('inventory.purchaseOrders.viewGRN') }}</span>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else class="text-center py-6 text-gray-500 text-sm bg-gradient-to-r from-gray-50 to-gray-100 rounded-lg border-2 border-dashed border-gray-300">
              <i class="fas fa-inbox text-3xl text-gray-400 mb-3"></i>
              <p class="font-semibold text-gray-600">{{ $t('inventory.purchaseOrders.noGRNsReceivedItem') }}</p>
              <p class="text-gray-400 text-xs mt-1">{{ $t('inventory.purchaseOrders.createGRNToTrack') }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Document Flow Section -->
    <div class="px-4 md:px-6 mx-auto max-w-7xl">
      <DocumentFlow 
        v-if="order"
        docType="po" 
        :docId="order.id" 
        :currentNumber="order.poNumber || order.po_number"
        :routeDocId="route.params.id"
        :linkedPrId="linkedPrId"
      />
      
      <!-- Item Transaction Flow (by PR or PO) -->
      <ItemFlow v-if="order" :prId="linkedPrId" :poId="order.id" />
    </div>

    <!-- Update Item Modal -->
    <div v-if="showUpdateItemModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeUpdateItemModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">
            {{ $t('inventory.purchaseOrders.updateItem') }}: {{ updatingItem?.item?.name || 'N/A' }} {{ updatingItem?.item?.nameLocalized ? `(${updatingItem.item.nameLocalized})` : '' }} ({{ updatingItem?.item?.sku || 'N/A' }})
          </h2>
          <button @click="closeUpdateItemModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ $t('inventory.purchaseOrders.quantity') }}({{ getItemUnit(updatingItem?.item) }}) <span class="text-red-500">*</span>
              </label>
              <input 
                v-model.number="updateItemForm.quantity"
                type="number" 
                min="0" 
                step="0.01"
                required
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                {{ $t('inventory.purchaseOrders.totalCost') }}({{ currencySymbol }}) <span class="text-red-500">*</span>
              </label>
              <input 
                v-model.number="updateItemForm.totalCost"
                type="number" 
                min="0" 
                step="0.01"
                required
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
              />
              <p class="text-xs text-gray-500 mt-1">{{ $t('inventory.purchaseOrders.withoutTax') }}</p>
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-6 pt-4 border-t border-gray-200">
            <button 
              @click="closeUpdateItemModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              {{ $t('common.close') }}
            </button>
            <button 
              @click="saveUpdateItem" 
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              {{ $t('common.save') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Items Modal -->
    <div v-if="showAddItemsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeAddItemsModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">{{ $t('inventory.purchaseOrders.addItems') }}</h2>
          <button @click="closeAddItemsModal" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              <i class="fas fa-search mr-2 text-gray-500"></i>{{ $t('inventory.purchaseOrders.searchItems') }}
            </label>
            <input 
              v-model="itemSearchQuery"
              type="text" 
              :placeholder="$t('inventory.purchaseOrders.searchPlaceholder')"
              class="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:border-green-500"
              style="--tw-ring-color: #284b44;"
            />
            <p class="text-xs text-gray-500 mt-2">
              <i class="fas fa-info-circle mr-1"></i>{{ $t('inventory.purchaseOrders.searchHint') }}
            </p>
          </div>
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('inventory.purchaseOrders.orSelectFromDropdown') }}</label>
            <select 
              v-model="newItemForm.itemId"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            >
              <option value="">{{ $t('inventory.purchaseOrders.choose') }}</option>
              <option v-for="item in filteredItemsForAdd" :key="item.id" :value="item.id">
                {{ item.name }} {{ item.nameLocalized ? `/${item.nameLocalized}` : '' }} ({{ item.sku || 'N/A' }})
              </option>
            </select>
          </div>
          <div class="max-h-96 overflow-y-auto border border-gray-200 rounded-lg">
            <div 
              v-for="item in filteredItemsForAdd" 
              :key="item.id"
              @click="selectItemForAdd(item)"
              class="p-3 hover:bg-gray-50 cursor-pointer border-b border-gray-100"
            >
              <div class="font-medium">{{ item.name }}</div>
              <div v-if="item.nameLocalized" class="text-sm text-gray-600">{{ item.nameLocalized }}</div>
              <div class="text-xs text-gray-500">({{ item.sku || 'N/A' }})</div>
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-6 pt-4 border-t border-gray-200">
            <button 
              @click="closeAddItemsModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              {{ $t('common.close') }}
            </button>
            <button 
              @click="saveAddItem" 
              :disabled="!newItemForm.itemId"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed sakura-primary-btn"
            >
              {{ $t('common.save') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Edit Quantities & Cost Modal -->
    <div v-if="showEditQuantitiesModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeEditQuantitiesModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">{{ $t('inventory.purchaseOrders.updateItemsQuantities') }}</h2>
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
              <div class="grid grid-cols-2 gap-4">
                <div @click.stop>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.purchaseOrders.quantityPcs') }} <span class="text-red-500">*</span>
                  </label>
                  <input 
                    v-model.number="item.quantity"
                    @input="updateItemTotalInBulk(index)"
                    @click.stop
                    type="number" 
                    min="0" 
                    step="0.01"
                    required
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44; pointer-events: auto;"
                  />
                </div>
                <div @click.stop>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.purchaseOrders.cost') }} <span class="text-red-500">*</span>
                  </label>
                  <input 
                    v-model.number="item.unitPrice"
                    @input="updateItemTotalInBulk(index)"
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
              <div class="mt-2 text-sm text-gray-600">
                {{ $t('inventory.purchaseOrders.total') }}: <span class="font-semibold" style="color: #284b44;">{{ formatCurrency(item.totalAmount || 0) }}</span>
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
              {{ $t('common.close') }}
            </button>
            <button 
              type="button"
              @click.stop="saveEditQuantities" 
              :disabled="savingQuantities"
              class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
              style="pointer-events: auto;"
            >
              {{ savingQuantities ? $t('inventory.purchaseOrders.saving') : $t('common.save') }}
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

    <!-- Edit Purchase Order Modal -->
    <div v-if="showEditModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeEditModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">Edit purchase order</h2>
          <button @click.stop="closeEditModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="saveEditOrder" @click.stop>
            <div class="space-y-4 mb-6" @click.stop>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Supplier <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.selectSupplierForPO')"></i>
                </label>
                <select 
                  v-model="editForm.supplierId" 
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">
                    {{ supplier.name }}
                  </option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Destination <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.selectDestinationWarehouse')"></i>
                </label>
                <select 
                  v-model="editForm.destination" 
                  required
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="dest in destinationOptions" :key="dest" :value="dest">{{ dest }}</option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Additional Cost({{ currencySymbol }})
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.additionalCostForPO')"></i>
                </label>
                <input 
                  v-model.number="editForm.additionalCost"
                  type="number" 
                  min="0" 
                  step="0.01"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.purchaseOrders.deliveryDate') }}</label>
                <input 
                  v-model="editForm.deliveryDate" 
                  type="date"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                />
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.purchaseOrders.deliveryTime') }}</label>
                <select 
                  v-model="editForm.deliveryTime"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">{{ $t('inventory.purchaseOrders.choose') }}</option>
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
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  {{ $t('inventory.purchaseOrders.notes') }}
                  <i class="fas fa-info-circle text-gray-400 ml-1" :title="$t('inventory.purchaseOrders.additionalNotes')"></i>
                </label>
                <textarea 
                  v-model="editForm.notes" 
                  rows="3"
                  @click.stop
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                  :placeholder="$t('inventory.purchaseOrders.additionalNotes')"
                ></textarea>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closeEditModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer"
                style="pointer-events: auto;"
              >
                {{ $t('common.close') }}
              </button>
              <button 
                type="submit" 
                :disabled="saving"
                @click.stop
                class="px-6 py-2 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer sakura-primary-btn"
                style="pointer-events: auto;"
              >
                {{ saving ? $t('inventory.purchaseOrders.saving') : $t('common.save') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue';
import DocumentFlow from '@/components/common/DocumentFlow.vue';
import ItemFlow from '@/components/common/ItemFlow.vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { getPurchaseOrderById, updatePurchaseOrderInSupabase, deletePurchaseOrderFromSupabase } from '@/services/supabase';
import { loadItemsFromSupabase, loadSuppliersFromSupabase, loadGRNsFromSupabase } from '@/services/supabase';
import { supabaseClient } from '@/services/supabase';
import { showConfirmDialog } from '@/utils/confirmDialog';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';
import { useInventoryLocations } from '@/composables/useInventoryLocations';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

// i18n support - using new enterprise system
const { t, locale, textAlign, isRTL, direction } = useI18n();

const order = ref(null);
const linkedPrId = ref(null);
const loading = ref(true);
const error = ref(null);
// CRITICAL: Single source of truth for PO UUID (resolved from numeric route param)
const poUuid = ref(null);
const poStatus = ref(null);
const showUpdateItemModal = ref(false);
const showAddItemsModal = ref(false);
const showEditModal = ref(false);
const showEditQuantitiesModal = ref(false);
const showImportItemsModal = ref(false);
const updatingItem = ref(null);
const updatingItemIndex = ref(-1);
const inventoryItems = ref([]);
const suppliers = ref([]);
const itemSearchQuery = ref('');
const saving = ref(false);
const savingQuantities = ref(false);
const importingItems = ref(false);
const importFileInput = ref(null);
const selectedFileName = ref('');
const importFileData = ref(null);

// Forms
const updateItemForm = ref({
  quantity: 0,
  totalCost: 0
});

const newItemForm = ref({
  itemId: '',
  quantity: 1,
  unitPrice: 0
});

const editForm = ref({
  supplierId: '',
  destination: '',
  deliveryDate: '',
  deliveryTime: '',
  additionalCost: 0,
  notes: ''
});

// Destinations: ONLY from inventory_locations WHERE allow_grn = true
const { loadLocationsForPO } = useInventoryLocations();
const destinationOptions = ref([]);

const editQuantitiesForm = ref({
  items: []
});

// Computed - Determine status from database fields (closed_at, approval_state, status)
const orderStatus = computed(() => {
  if (!order.value) return 'draft';
  
  // Priority 1: Check closed_at field - if exists, status is "Closed"
  if (order.value.closed_at || order.value.closedAt) {
    return 'closed';
  }
  
  // Priority 2: Check approval_state field - if "approved", status is "Approved"
  const approvalState = order.value.approval_state || order.value.approvalState;
  if (approvalState === 'approved') {
    return 'approved';
  }
  
  // Priority 3: Use status field from database
  return (order.value.status || '').toLowerCase() || 'draft';
});

// Get PO display number (shows status based on database fields)
const getPODisplayNumber = computed(() => {
  if (!order.value) return `(${t('status.draft')})`;
  
  const status = orderStatus.value;
  const poNumber = order.value.poNumber || order.value.po_number;
  
  // Draft POs should show "Draft" without a number
  if (status === 'draft' || (!poNumber || poNumber === '')) {
    return `(${t('status.draft')})`;
  }
  
  // Other statuses show their number
  return `(${poNumber})`;
});

// DB-driven: fn_can_create_next_document('PO', po_id) — no local status logic
const canCreateGRN = ref(false);

const availableItems = computed(() => {
  const selectedItemIds = (order.value?.items || []).map(item => item.itemId || item.item_id);
  return inventoryItems.value.filter(item => !selectedItemIds.includes(item.id));
});

const filteredItemsForAdd = computed(() => {
  if (!itemSearchQuery.value) return availableItems.value;
  const query = itemSearchQuery.value.toLowerCase();
  return availableItems.value.filter(item => 
    item.name?.toLowerCase().includes(query) ||
    item.nameLocalized?.toLowerCase().includes(query) ||
    item.sku?.toLowerCase().includes(query)
  );
});

const currencySymbol = computed(() => 'SAR'); // System currency: SAR only

// Methods
const loadOrder = async () => {
  loading.value = true;
  error.value = null;
  
  try {
    // CRITICAL: Use poUuid.value (UUID), NEVER route.params.id (numeric)
    if (!poUuid.value) {
      throw new Error('PO UUID not resolved. Cannot load purchase order.');
    }
    
    const result = await getPurchaseOrderById(poUuid.value);
    if (result.success && result.data) {
      order.value = result.data;
      
      // CRITICAL: Ensure poUuid is set to order.value.id (database uses INTEGER IDs)
      if (order.value.id) {
        poUuid.value = String(order.value.id);
        console.log('[ID SYNCED] poUuid updated from order.id:', poUuid.value);
      }
      
      const rawStatus = order.value?.status || order.value?.approval_state || 'draft';
      poStatus.value = String(rawStatus).toLowerCase();

      const { canCreateNextDocument } = await import('@/services/erpViews.js');
      const rpcResult = await canCreateNextDocument('PO', order.value.id);
      canCreateGRN.value = rpcResult;
      console.log('RPC fn_can_create_next_document', { docType: 'PO', orderId: order.value.id, result: rpcResult });

      console.log('[PO STATUS UPDATE]', {
        rawStatus,
        poStatus: poStatus.value,
        canCreateGRN: canCreateGRN.value,
        orderId: order.value.id,
        poUuid: poUuid.value
      });
      
      // CRITICAL: Log PO data to verify quantities are loaded
      console.log('📦 PO loaded:', {
        id: order.value.id,
        po_number: order.value.poNumber || order.value.po_number,
        ordered_quantity: order.value.ordered_quantity,
        total_received_quantity: order.value.total_received_quantity,
        remaining_quantity: order.value.remaining_quantity,
        status: order.value.status,
        approval_state: order.value.approval_state,
        items_count: order.value.items?.length || 0
      });
      
      // If supplier relationship didn't load, manually load supplier data
      if (!order.value.supplier && (order.value.supplierId || order.value.supplier_id)) {
        const supplierId = order.value.supplierId || order.value.supplier_id;
        const supplierList = await loadSuppliersFromSupabase();
        const supplier = supplierList.find(s => s.id === supplierId);
        if (supplier) {
          order.value.supplier = supplier;
        }
      }
      
      // If items don't have nested item data, manually load item data
      if (order.value.items && order.value.items.length > 0) {
        const allItems = await loadItemsFromSupabase();
        order.value.items = order.value.items.map(poItem => {
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
      
      console.log('✅ Purchase Order loaded:', order.value);
      console.log('✅ Supplier data:', order.value.supplier);
      console.log('✅ Items data:', order.value.items);
      
      // CRITICAL: Load received quantities from database view (single source of truth)
      await loadReceivedQuantitiesFromDB();
      
      // Load GRNs for this PO to track receiving status
      await loadGRNsForPO();
      
      // Update PO status based on GRN receiving status
      if (order.value.status === 'approved' || order.value.status === 'fully_received' || order.value.status === 'partially_received') {
        await updatePOReceivingStatus();
      }

      // Fetch linked PR for ItemFlow
      try {
        const { data: linkData } = await supabaseClient
          .from('pr_po_linkage')
          .select('pr_id')
          .eq('po_id', order.value.id)
          .limit(1);
        
        if (linkData && linkData.length > 0) {
          linkedPrId.value = linkData[0].pr_id;
          console.log('🔗 Linked PR found:', linkedPrId.value);
        }
      } catch (e) {
        console.warn('Could not fetch linked PR:', e);
      }
    } else {
      throw new Error('Purchase order not found');
    }
  } catch (err) {
    console.error('Error loading purchase order:', err);
    error.value = err.message || 'Failed to load purchase order';
  } finally {
    loading.value = false;
  }
};

// CRITICAL: Load received quantities from database (single source of truth)
// Uses v_po_item_receipts view or direct calculation from grn_inspection_items
const loadReceivedQuantitiesFromDB = async () => {
  try {
    const poNumber = order.value?.po_number || order.value?.poNumber;
    if (!poNumber || !order.value?.items) {
      console.log('⚠️ No PO number or items, skipping received quantity load');
      return;
    }
    
    console.log('🔍 Loading received quantities from DB for PO:', poNumber);
    
    // STRATEGY 1: Try to use v_po_item_receipts view (most accurate)
    try {
      const { data: viewData, error: viewError } = await supabaseClient
        .from('v_po_item_receipts')
        .select('*')
        .eq('purchase_order_number', poNumber);
      
      if (!viewError && viewData && viewData.length > 0) {
        console.log('✅ Loaded from v_po_item_receipts view:', viewData.length, 'items');
        
        // Update order items with received quantities from view
        order.value.items = order.value.items.map(item => {
          const itemId = item.itemId || item.item_id;
          const viewItem = viewData.find(v => String(v.item_id) === String(itemId));
          
          if (viewItem) {
            console.log(`✅ Item ${itemId}: ordered=${viewItem.ordered_qty}, received=${viewItem.received_qty}, remaining=${viewItem.remaining_qty}`);
            return {
              ...item,
              quantity_received: parseFloat(viewItem.received_qty || 0),
              quantityReceived: parseFloat(viewItem.received_qty || 0),
              remaining_quantity: parseFloat(viewItem.remaining_qty || 0),
              remainingQuantity: parseFloat(viewItem.remaining_qty || 0)
            };
          }
          return item;
        });
        return;
      }
    } catch (e) {
      console.warn('⚠️ v_po_item_receipts view not available:', e.message);
    }
    
    // STRATEGY 2: Direct calculation from grn_inspection_items
    console.log('🔍 Calculating received quantities from grn_inspection_items...');
    
    const { data: grnItems, error: grnError } = await supabaseClient
      .from('grn_inspection_items')
      .select(`
        item_id,
        received_quantity,
        grn_inspection:grn_inspections!inner(
          purchase_order_number,
          status,
          deleted
        )
      `)
      .eq('grn_inspection.purchase_order_number', poNumber)
      .eq('grn_inspection.deleted', false)
      .not('grn_inspection.status', 'in', '("cancelled","rejected")');
    
    if (!grnError && grnItems) {
      console.log('✅ Loaded GRN items for quantity calculation:', grnItems.length);
      
      // Aggregate received quantities by item_id
      const receivedByItem = {};
      grnItems.forEach(gi => {
        const itemId = gi.item_id;
        if (itemId) {
          receivedByItem[itemId] = (receivedByItem[itemId] || 0) + parseFloat(gi.received_quantity || 0);
        }
      });
      
      console.log('✅ Aggregated received quantities:', receivedByItem);
      
      // Update order items
      order.value.items = order.value.items.map(item => {
        const itemId = item.itemId || item.item_id;
        const receivedQty = receivedByItem[itemId] || 0;
        const orderedQty = parseFloat(item.quantity || 0);
        const remainingQty = Math.max(0, orderedQty - receivedQty);
        
        console.log(`✅ Item ${itemId}: ordered=${orderedQty}, received=${receivedQty}, remaining=${remainingQty}`);
        
        return {
          ...item,
          quantity_received: receivedQty,
          quantityReceived: receivedQty,
          remaining_quantity: remainingQty,
          remainingQuantity: remainingQty
        };
      });
    } else if (grnError) {
      console.error('❌ Error loading GRN items:', grnError);
    }
  } catch (error) {
    console.error('❌ Error loading received quantities:', error);
  }
};

const loadGRNsForPO = async () => {
  try {
    // CRITICAL: Use purchase_order_number (TEXT) to match GRNs, NOT UUID
    // Database reality: purchase_orders.id = INTEGER, grn_inspections.purchase_order_number = TEXT
    const poNumber = order.value?.po_number || order.value?.poNumber;
    
    if (!poNumber) {
      console.warn('⚠️ PO Number not available, skipping GRN load');
      return;
    }
    
    console.log('🔍 Loading GRNs for PO Number:', poNumber);
    
    // STRATEGY 1: Direct Supabase query by purchase_order_number (MOST RELIABLE)
    try {
      const { data: directGRNs, error: directError } = await supabaseClient
        .from('grn_inspections')
        .select(`
          *,
          items:grn_inspection_items(*)
        `)
        .eq('purchase_order_number', poNumber)
        .eq('deleted', false)
        .order('created_at', { ascending: false });
      
      if (!directError && directGRNs && directGRNs.length > 0) {
        grns.value = directGRNs.map(grn => ({
          ...grn,
          // Map database fields to frontend fields
          grnNumber: grn.grn_number,
          purchaseOrderReference: grn.purchase_order_number,
          supplierName: grn.supplier_name,
          items: (grn.items || []).map(item => ({
            ...item,
            itemId: item.item_id,
            itemCode: item.item_code,
            itemName: item.item_name,
            receivedQuantity: parseFloat(item.received_quantity || 0),
            orderedQuantity: parseFloat(item.ordered_quantity || 0)
          }))
        }));
        
        console.log('✅ GRNs loaded for PO via direct query:', grns.value.length, 'GRNs found');
        console.log('✅ GRN Numbers:', grns.value.map(g => g.grnNumber || g.grn_number || 'Draft'));
        console.log('✅ GRN Statuses:', grns.value.map(g => g.status));
        return;
      }
    } catch (e) {
      console.warn('⚠️ Direct GRN query failed, falling back to loadGRNsFromSupabase:', e);
    }
    
    // STRATEGY 2: Fallback - Load all GRNs and filter by purchase_order_number
    const allGRNs = await loadGRNsFromSupabase();
    console.log('🔍 Total GRNs loaded:', allGRNs.length);
    
    grns.value = allGRNs.filter(grn => {
      // Match by purchase_order_number (TEXT field)
      const grnPONumber = grn.purchase_order_number || grn.purchaseOrderReference || grn.purchaseOrderNumber;
      const matches = grnPONumber === poNumber;
      
      if (grnPONumber) {
        console.log('🔍 Comparing GRN PO Number:', grnPONumber, 'with PO Number:', poNumber, '→ Match:', matches);
      }
      
      return matches;
    });
    
    console.log('✅ GRNs loaded for PO:', grns.value.length, 'GRNs found');
    if (grns.value.length > 0) {
      console.log('✅ GRN IDs:', grns.value.map(g => g.id));
      console.log('✅ GRN Statuses:', grns.value.map(g => g.status));
      console.log('✅ GRN PO Numbers:', grns.value.map(g => g.purchase_order_number || g.purchaseOrderReference));
    }
  } catch (error) {
    console.error('❌ Error loading GRNs:', error);
  }
};

const updatePOReceivingStatus = async () => {
  try {
    // CRITICAL: Use poUuid.value (UUID), NEVER order.value.id (might be numeric)
    if (!poUuid.value) {
      console.warn('⚠️ PO UUID not available, skipping status update');
      return;
    }
    
    console.log('🔄 Updating PO receiving status for PO UUID:', poUuid.value);
    
    // CRITICAL: First reload GRNs to get latest data
    await loadGRNsForPO();
    
    // Then update PO status based on GRNs (using UUID)
    const { updatePOStatusBasedOnGRNs } = await import('@/services/autoDraftFlow');
    const result = await updatePOStatusBasedOnGRNs(poUuid.value);
    
    if (result.success && result.data) {
      // Update local order status
      order.value.status = result.data.status || order.value.status;
      console.log('✅ PO status updated to:', order.value.status);
    }
  } catch (error) {
    console.error('❌ Error updating PO receiving status:', error);
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
    const supplierList = await loadSuppliersFromSupabase();
    suppliers.value = supplierList.filter(s => !s.deleted);
  } catch (error) {
    console.error('Error loading suppliers:', error);
  }
};

const goBack = () => {
  router.push('/homeportal/purchase-orders');
};

const editOrder = () => {
  if (!order.value) return;
  
  // Pre-fill edit form with current order data
  const supplierId = order.value.supplierId || order.value.supplier_id || 
                     (order.value.supplier ? order.value.supplier.id : '');
  
  editForm.value = {
    supplierId: supplierId,
    destination: order.value.destination || '',
    deliveryDate: order.value.deliveryDate || order.value.delivery_date ? (order.value.deliveryDate || order.value.delivery_date).split('T')[0] : '',
    deliveryTime: order.value.deliveryTime || order.value.delivery_time || '',
    additionalCost: order.value.additionalCost || order.value.additional_cost || 0,
    notes: order.value.notes || ''
  };
  
  console.log('📝 Edit form pre-filled:', editForm.value);
  console.log('📝 Current order supplier:', order.value.supplier);
  console.log('📝 Current order supplierId:', order.value.supplierId || order.value.supplier_id);
  
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
  editForm.value = {
    supplierId: '',
    destination: '',
    deliveryDate: '',
    deliveryTime: '',
    additionalCost: 0,
    notes: ''
  };
};

const saveEditOrder = async () => {
  if (!order.value) return;
  
  if (!editForm.value.supplierId) {
    showNotification('Please select a supplier', 'warning');
    return;
  }
  
  if (!editForm.value.destination) {
    showNotification('Please select a destination', 'warning');
    return;
  }
  
  saving.value = true;
  try {
    // Load supplier data before updating
    const supplier = suppliers.value.find(s => s.id === editForm.value.supplierId);
    
    const updatedData = {
      ...order.value,
      supplierId: editForm.value.supplierId,
      supplier_id: editForm.value.supplierId, // Also set supplier_id for compatibility
      destination: editForm.value.destination,
      deliveryDate: editForm.value.deliveryDate || null,
      delivery_date: editForm.value.deliveryDate || null,
      deliveryTime: editForm.value.deliveryTime || null,
      delivery_time: editForm.value.deliveryTime || null,
      additionalCost: editForm.value.additionalCost || 0,
      additional_cost: editForm.value.additionalCost || 0,
      notes: editForm.value.notes || null
    };
    
    // Add supplier object to updatedData for immediate display
    if (supplier) {
      updatedData.supplier = supplier;
    }
    
    const result = await updatePurchaseOrderInSupabase(order.value.id, updatedData);
    
    if (result.success) {
      // Update local order object with supplier data immediately
      if (supplier) {
        order.value.supplier = supplier;
        order.value.supplierId = editForm.value.supplierId;
        order.value.supplier_id = editForm.value.supplierId;
      }
      
      showNotification('Purchase order updated successfully', 'success');
      closeEditModal();
      await loadOrder(); // Reload order to show updated data
    } else {
      throw new Error(result.error || 'Failed to update purchase order');
    }
  } catch (error) {
    console.error('Error updating purchase order:', error);
    showNotification('Error updating purchase order: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const deleteOrderPermanently = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Purchase Order',
    message: 'Are you sure you want to delete this purchase order permanently? This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deletePurchaseOrderFromSupabase(order.value.id);
    if (result.success) {
      showNotification('Purchase order deleted successfully', 'success');
      goBack();
    } else {
      throw new Error(result.error || 'Failed to delete purchase order');
    }
  } catch (err) {
    console.error('Error deleting purchase order:', err);
    showNotification('Error deleting purchase order: ' + (err.message || 'Unknown error'), 'error');
  }
};

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

const submitForReview = async (e) => {
  if (e) {
    e.stopPropagation();
    e.preventDefault();
  }
  console.log('🚀 submitForReview called');
  
  try {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Confirm',
      message: 'Are you sure you want to submit this purchase order for review?',
    confirmText: 'Yes',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-paper-plane'
  });
  
    if (!confirmed) {
      console.log('❌ User cancelled submission');
      return;
    }
  
    console.log('✅ User confirmed, proceeding with submission...');
    
    const currentUserName = getCurrentUserName();
    
    // Generate PO number if it doesn't exist or if it's a DRAFT- number
    let poNumber = order.value.poNumber || order.value.po_number;
    if (!poNumber || poNumber === '' || (poNumber && poNumber.startsWith('DRAFT-'))) {
      console.log('📝 Generating new PO number (current:', poNumber, ')');
      const { generatePONumber, supabaseClient } = await import('@/services/supabase');
      
      // Retry logic to ensure unique PO number
      let attempts = 0;
      const maxAttempts = 5;
      while (attempts < maxAttempts) {
      poNumber = await generatePONumber();
        console.log('✅ Generated PO number (attempt', attempts + 1, '):', poNumber);
        
        // Verify PO number doesn't already exist (only if supabaseClient is available)
        if (supabaseClient) {
          const { data: existing } = await supabaseClient
            .from('purchase_orders')
            .select('id')
            .eq('po_number', poNumber)
            .neq('id', order.value.id) // Exclude current order
            .limit(1);
          
          if (!existing || existing.length === 0) {
            // PO number is unique
            console.log('✅ PO number is unique:', poNumber);
            break;
          } else {
            console.warn('⚠️ PO number already exists, retrying...', poNumber);
            attempts++;
            // Wait a bit before retrying
            await new Promise(resolve => setTimeout(resolve, 100));
          }
        } else {
          // No supabaseClient, use the generated number
          break;
        }
      }
      
      if (attempts >= maxAttempts) {
        throw new Error('Failed to generate unique PO number after ' + maxAttempts + ' attempts');
      }
    }
    
    // Prepare update data with proper field mapping
    const updateData = {
      poNumber: poNumber,
      po_number: poNumber,
      status: 'pending',
      submittedAt: new Date().toISOString(),
      submitted_at: new Date().toISOString(),
      submitter: currentUserName,
      // Preserve existing order data
      supplierId: order.value.supplierId || order.value.supplier_id,
      supplierName: order.value.supplierName || order.value.supplier_name,
      destination: order.value.destination,
      orderDate: order.value.orderDate || order.value.order_date,
      businessDate: order.value.businessDate || order.value.business_date || order.value.orderDate,
      expectedDate: order.value.expectedDate || order.value.expected_date,
      totalAmount: order.value.totalAmount || order.value.total_amount,
      vatAmount: order.value.vatAmount || order.value.vat_amount,
      notes: order.value.notes,
      items: order.value.items || []
    };
    
    console.log('📝 Updating purchase order with data:', updateData);
    
    const result = await updatePurchaseOrderInSupabase(order.value.id, updateData);
    
    if (result.success) {
      console.log('✅ Purchase order submitted successfully');
      showNotification('Purchase order submitted for review', 'success');
      // Reload order to get updated data with item relationships
      await loadOrder();
    } else {
      const errorMsg = result.error || 'Failed to submit purchase order';
      const errorDetails = result.details ? ` Details: ${JSON.stringify(result.details)}` : '';
      const errorHint = result.hint ? ` Hint: ${result.hint}` : '';
      throw new Error(errorMsg + errorDetails + errorHint);
    }
  } catch (err) {
    console.error('❌ Error submitting purchase order:', err);
    showNotification('Error submitting purchase order: ' + (err.message || 'Unknown error'), 'error', 5000);
  }
};

const approveOrder = async (e) => {
  if (e) {
    e.stopPropagation();
    e.preventDefault();
  }
  console.log('🚀 approveOrder called');
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Confirm Approval',
    message: 'Are you sure you want to approve this purchase order? This will automatically create a GRN Draft.',
    confirmText: 'Yes, Approve',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-check'
  });
  
  if (!confirmed) {
    console.log('❌ User cancelled approval');
    return;
  }
  
  try {
    console.log('✅ User confirmed, proceeding with approval...');
    const currentUserName = getCurrentUserName();
    
    // Prepare update data with proper field mapping
    const updateData = {
      status: 'approved',
      approvedAt: new Date().toISOString(),
      approved_at: new Date().toISOString(),
      approver: currentUserName,
      // Preserve existing order data
      poNumber: order.value.poNumber || order.value.po_number,
      po_number: order.value.poNumber || order.value.po_number,
      supplierId: order.value.supplierId || order.value.supplier_id,
      supplierName: order.value.supplierName || order.value.supplier_name,
      destination: order.value.destination,
      orderDate: order.value.orderDate || order.value.order_date,
      businessDate: order.value.businessDate || order.value.business_date || order.value.orderDate,
      expectedDate: order.value.expectedDate || order.value.expected_date,
      totalAmount: order.value.totalAmount || order.value.total_amount,
      vatAmount: order.value.vatAmount || order.value.vat_amount,
      notes: order.value.notes,
      items: order.value.items || []
    };
    
    console.log('📝 Updating purchase order to approved status...');
    const result = await updatePurchaseOrderInSupabase(order.value.id, updateData);
    
    if (result.success) {
      console.log('✅ Purchase order approved successfully');
      showNotification('Purchase order approved successfully', 'success');
      
      // CRITICAL: Force reload order and sync poStatus IMMEDIATELY
      await loadOrder();
      poStatus.value = order.value?.status || 'approved';
      await nextTick();
      console.log('[POST APPROVAL STATE]', { 
        status: order.value?.status, 
        poStatus: poStatus.value,
        canCreateGRN: canCreateGRN.value 
      });
      
      // AUTO-DRAFT FLOW: Create GRN Draft automatically when PO is approved
      // ISO 22000 Business Rule: One PO → Multiple GRNs (Allowed)
      // This separates commercial commitment (PO) from physical receipt (GRN)
      try {
        console.log('🔄 Starting auto-draft flow to create GRN...');
        const { onPOApproved } = await import('@/services/autoDraftFlow');
        const grnResult = await onPOApproved(result.data);
        
        if (grnResult.success && grnResult.grnDraft) {
          console.log('✅ GRN Draft auto-created successfully');
          const grnDraft = grnResult.grnDraft;
          const grnId = grnDraft.id;
          const grnNumber = grnDraft.grnNumber || grnDraft.grn_number || 'Draft';
          
          showNotification(
            `Purchase order approved. GRN Draft (${grnNumber}) auto-created successfully. Redirecting to GRN draft...`, 
            'success',
            3000
          );
          
          // Wait a bit for notification to show, then redirect to GRN detail page
          await new Promise(resolve => setTimeout(resolve, 1500));
          
          // Redirect to GRN detail page - use direct navigation approach
          console.log('📍 Redirecting to GRN detail page after PO approval...');
          console.log('📍 GRN ID:', grnId);
          
          if (!grnId) {
            console.error('❌ GRN ID is missing, cannot navigate');
            return;
          }
          
          // Force navigation using the most reliable method
          // Try parent.loadDashboard first (most common case in iframe setup)
          if (window.parent && window.parent !== window && typeof window.parent.loadDashboard === 'function') {
            console.log('✅ Navigating via parent.loadDashboard to grn-detail?id=' + grnId);
            window.parent.loadDashboard(`grn-detail?id=${grnId}`);
            // Also set window.currentView directly as backup
            window.currentView = `grn-detail?id=${grnId}`;
            return; // Exit early after navigation
          }
          
          // Try window.loadDashboard
          if (window.loadDashboard && typeof window.loadDashboard === 'function') {
            console.log('✅ Navigating via window.loadDashboard to grn-detail?id=' + grnId);
            window.loadDashboard(`grn-detail?id=${grnId}`);
            // Also set window.currentView directly as backup
            window.currentView = `grn-detail?id=${grnId}`;
            return; // Exit early after navigation
          }
          
          // Try router.push
          if (router) {
            try {
              console.log('✅ Navigating via router.push to /grn-detail?id=' + grnId);
              await router.push({ path: '/grn-detail', query: { id: grnId } });
              // Also set window.currentView directly as backup
              window.currentView = `grn-detail?id=${grnId}`;
              return; // Exit early after navigation
            } catch (e) {
              console.error('❌ router.push failed:', e);
            }
          }
          
          // Final fallback: Direct URL navigation
          console.log('✅ Navigating via direct URL to #grn-detail?id=' + grnId);
          window.currentView = `grn-detail?id=${grnId}`;
          window.location.hash = `grn-detail?id=${grnId}`;
          
          // Force reload if hash change doesn't work
          setTimeout(() => {
            if (window.currentView !== `grn-detail?id=${grnId}`) {
              console.log('⚠️ Hash change may not have worked, trying location.href');
              window.location.href = `#grn-detail?id=${grnId}`;
            }
          }, 100);
        } else {
          console.warn('⚠️ GRN Draft auto-creation failed:', grnResult.error);
          // Don't fail PO approval if GRN draft creation fails
          showNotification(
            `Purchase order approved, but GRN draft creation failed: ${grnResult.error || 'Unknown error'}. You can create GRN manually.`, 
            'warning',
            5000
          );
        }
      } catch (autoDraftError) {
        console.error('❌ Error in auto-draft flow:', autoDraftError);
        // Don't fail PO approval if auto-draft fails
        showNotification(
          `${t('inventory.purchaseOrders.poApproved')} ${t('inventory.grn.createManually')}. ${t('common.error')}: ${autoDraftError.message || t('common.unknownError')}`, 
          'info',
          5000
        );
      }
      
      await loadOrder();
      
      // CRITICAL: Force immediate status update
      const rawStatus = order.value?.status || order.value?.approval_state || 'draft';
      const normalizedStatus = String(rawStatus).toLowerCase();
      poStatus.value = normalizedStatus;
      
      console.log('[POST APPROVAL]', {
        rawStatus,
        normalizedStatus,
        poStatus: poStatus.value,
        canCreateGRN: canCreateGRN.value,
        orderStatus: orderStatus.value
      });
      
      // Force reactivity update
      await nextTick();
      
      // Double-check after nextTick
      if (poStatus.value !== normalizedStatus) {
        poStatus.value = normalizedStatus;
        await nextTick();
      }
      
      console.log('[POST APPROVAL FINAL]', {
        poStatus: poStatus.value,
        canCreateGRN: canCreateGRN.value
      });
    } else {
      const errorMsg = result.error || 'Failed to approve purchase order';
      const errorDetails = result.details ? ` Details: ${JSON.stringify(result.details)}` : '';
      const errorHint = result.hint ? ` Hint: ${result.hint}` : '';
      throw new Error(errorMsg + errorDetails + errorHint);
    }
  } catch (err) {
    console.error('❌ Error approving purchase order:', err);
    showNotification('Error approving purchase order: ' + (err.message || 'Unknown error'), 'error', 5000);
  }
};

const rejectOrder = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Confirm',
    message: 'Are you sure you want to decline this?',
    confirmText: 'Yes',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-times'
  });
  
  if (!confirmed) return;
  
  try {
    const currentUserName = getCurrentUserName();
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      status: 'rejected',
      rejectedAt: new Date().toISOString(),
      rejected_at: new Date().toISOString(),
      rejector: currentUserName
    });
    
    if (result.success) {
      showNotification('Purchase order rejected', 'success');
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to reject purchase order');
    }
  } catch (err) {
    console.error('Error rejecting purchase order:', err);
    showNotification('Error rejecting purchase order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const closeOrder = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Close Purchase Order',
    message: 'Are you sure you want to close this purchase order? This will mark it as closed without creating purchasing.',
    confirmText: 'Yes, Close',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-check'
  });
  
  if (!confirmed) return;
  
  try {
    const currentUserName = getCurrentUserName();
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      status: 'closed',
      closedAt: new Date().toISOString(),
      closed_at: new Date().toISOString(),
      closer: currentUserName
    });
    
    if (result.success) {
      showNotification('Purchase order closed successfully', 'success');
      await loadOrder();
    } else {
      throw new Error(result.error || 'Failed to close purchase order');
    }
  } catch (err) {
    console.error('Error closing purchase order:', err);
    showNotification('Error closing purchase order: ' + (err.message || 'Unknown error'), 'error');
  }
};

const onCreateGRN = async (event) => {
  console.log('🔥🔥🔥 BUTTON CLICKED - onCreateGRN FIRED 🔥🔥🔥');
  
  if (event) {
    event.preventDefault();
    event.stopPropagation();
  }
  
  console.log('[CREATE GRN CLICKED]', {
    canCreateGRN: canCreateGRN.value,
    poStatus: poStatus.value,
    orderStatus: orderStatus.value,
    orderValueStatus: order.value?.status,
    poUuid: poUuid.value,
    orderId: order.value?.id,
    itemsCount: order.value?.items?.length || 0,
    hasItems: !!(order.value?.items && order.value.items.length > 0)
  });
  
  // CRITICAL: Ensure items are loaded
  if (!order.value?.items || order.value.items.length === 0) {
    console.warn('[NO ITEMS] Reloading order to get items...');
    await loadOrder();
    await nextTick();
    
    if (!order.value?.items || order.value.items.length === 0) {
      console.error('[BLOCKED] No items found in PO');
      showNotification('Cannot create GRN: Purchase order has no items', 'error');
    return;
  }
  }

  // CRITICAL: Use order.value.id directly (can be integer OR UUID)
  if (order.value?.id) {
    const orderIdStr = String(order.value.id);
    if (poUuid.value !== orderIdStr) {
      console.log('[ID RE-SYNC] Updating poUuid from order.id:', order.value.id);
      poUuid.value = orderIdStr;
      await nextTick();
    }
  }

  // FORCE RE-LOAD ORDER TO GET LATEST STATUS
  try {
    await loadOrder();
    poStatus.value = order.value?.status || poStatus.value;
    await nextTick();
  } catch (e) {
    console.warn('Could not reload order, using cached status');
  }
  
  // Check status from multiple sources
  const currentStatus = poStatus.value || orderStatus.value || order.value?.status || '';
  const normalizedStatus = String(currentStatus).toLowerCase().trim();
  
  console.log('[STATUS CHECK]', {
    poStatus: poStatus.value,
    orderStatus: orderStatus.value,
    orderValueStatus: order.value?.status,
    normalizedStatus,
    canCreateGRN: canCreateGRN.value
  });
  
  if (normalizedStatus !== 'approved' && normalizedStatus !== 'partially_received') {
    console.warn('[STATUS WARNING] PO status =', normalizedStatus, '- but proceeding anyway');
    // DON'T BLOCK - Allow user to create GRN even if status seems wrong
    // Backend will validate anyway
  }
  
  console.log('[PROCEEDING] Starting GRN creation...');
  await createGRN();
  }
  
const createGRN = async () => {
  if (saving.value) {
    console.log('⏳ Already processing, please wait...');
    return;
  }
  
  // CRITICAL: Use order.value.id directly (database uses INTEGER IDs, not UUIDs)
  if (!poUuid.value && !order.value?.id) {
    console.error('[ID VALIDATION FAILED]', {
      poUuid: poUuid.value,
      orderId: order.value?.id,
      routeParam: route.params?.id
    });
    showNotification('Cannot create GRN: Purchase Order ID not found. Please refresh the page.', 'error');
      return;
    }
    
  // Use order.value.id if poUuid is missing
  if (!poUuid.value && order.value?.id) {
    poUuid.value = String(order.value.id);
    console.log('[ID SET] Using order.id as poUuid:', poUuid.value);
  }
    
  saving.value = true;
  
  try {
    console.log('[CREATE GRN START]', {
      poUuid: poUuid.value,
      orderId: order.value?.id,
      poNumber: order.value?.poNumber || order.value?.po_number,
      status: order.value?.status
    });
    
    // Use order.value.id directly (database uses INTEGER, not UUID)
    const orderId = order.value?.id || poUuid.value;
    const orderWithUuid = {
      ...order.value,
      id: orderId,
      purchaseOrderId: orderId,
      purchase_order_id: orderId
    };
    
    console.log('[GRN CREATION] Using order ID:', orderId, 'Type:', typeof orderId);
    
    const { createGRNDraftFromPO } = await import('@/services/autoDraftFlow');
    
    showNotification('Creating GRN Draft...', 'info');
    console.log('Creating GRN Draft...');
    
    const result = await createGRNDraftFromPO(orderWithUuid);
    
    if (result.success && result.data) {
      const grnDraft = result.data;
      const grnId = grnDraft.id;
      
      if (!grnId) {
        throw new Error('GRN ID is missing');
      }
      
      showNotification('GRN Draft created successfully. Redirecting...', 'success', 2000);
      
      console.log('[REDIRECT START]', { grnId, router: !!router });
      
      // Method 1: Try router.push with route name
      try {
        await router.push({
          name: 'GRNDetail',
          params: { id: grnId }
        });
        console.log('✅ Redirected via router.push (route name)');
            return;
        } catch (e) {
        console.warn('⚠️ router.push (route name) failed, trying path:', e);
      }
      
      // Method 2: Try router.push with path
      try {
        await router.push({
          path: `/homeportal/grn-detail/${grnId}`
        });
        console.log('✅ Redirected via router.push (path)');
            return;
        } catch (e) {
        console.warn('⚠️ router.push (path) failed, trying query:', e);
      }
      
      // Method 3: Try router.push with query
      try {
        await router.push({
          path: '/homeportal/grn-detail',
          query: { id: grnId }
        });
        console.log('✅ Redirected via router.push (query)');
          return;
        } catch (e) {
        console.warn('⚠️ router.push (query) failed, trying hash:', e);
      }
      
      // Method 4: Direct hash navigation
      window.location.hash = `#/homeportal/grn-detail?id=${grnId}`;
      console.log('✅ Redirected via hash navigation');
    } else {
      const errorMsg = result.error || 'Failed to create GRN Draft';
      throw new Error(errorMsg);
    }
  } catch (error) {
    console.error('❌ Error creating GRN:', error);
    showNotification('Error creating GRN: ' + (error.message || 'Unknown error'), 'error', 5000);
  } finally {
    saving.value = false;
  }
};

const printOrder = async () => {
  if (!order.value) {
    showNotification('No purchase order data available', 'warning');
    return;
  }

  // Use hidden iframe instead of new tab for printing
  // This prevents opening a new tab and shows print dialog directly
  let printFrame = document.getElementById('print-frame');
  if (!printFrame) {
    printFrame = document.createElement('iframe');
    printFrame.id = 'print-frame';
    printFrame.name = 'print-frame';
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

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'SAR'
    }).format(amount || 0);
  };

  const formatDate = (date) => {
    if (!date) return '—';
    const d = new Date(date);
    return d.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
  };

  const formatDateTime = (date) => {
    if (!date) return 'N/A';
    const d = new Date(date);
    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });
  };

  // Use i18n values from top-level setup (hooks already called at top level)
  const currentLang = locale.value || 'en';
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
  
  // Helper function to translate status
  const translateStatus = (status) => {
    try {
      return t(`status.${status}`) || status;
    } catch (e) {
      return status;
    }
  };
  
  // Date formatting helpers (simplified for print)
  const formatDateByLang = (dateStr) => {
    if (!dateStr) return '—';
    const date = new Date(dateStr);
    return date.toLocaleDateString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
  };
  
  const formatDateTimeByLang = (dateStr) => {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
  };
  
  const formatPrintDateTime = () => {
    const now = new Date();
    const printDate = now.toLocaleDateString(currentLang === 'ar' ? 'ar-SA' : 'en-US');
    const printTime = now.toLocaleTimeString(currentLang === 'ar' ? 'ar-SA' : 'en-US', { 
      hour: '2-digit', 
      minute: '2-digit',
      hour12: true
    });
    return { printDate, printTime };
  };

  // Get formatted values
  const supplierName = orderData?.supplier?.name || 'N/A';
  const supplierLocalized = orderData?.supplier?.nameLocalized ? ' (' + escapeHtml(orderData.supplier.nameLocalized) + ')' : '';
  const poNumber = escapeHtml(orderData?.poNumber || orderData?.po_number || 'N/A');
  const destination = escapeHtml(orderData?.destination || '—');
  const businessDate = orderData?.businessDate ? formatDateByLang(orderData.businessDate) : '—';
  const deliveryDate = (orderData?.deliveryDate || orderData?.delivery_date) ? formatDateByLang(orderData.deliveryDate || orderData.delivery_date) : '—';
  const creator = escapeHtml(orderData?.creator || 'N/A');
  const submitter = orderData?.submitter ? escapeHtml(orderData.submitter) : '';
  const approver = orderData?.approver ? escapeHtml(orderData.approver) : '';
  const createdAt = (orderData?.createdAt || orderData?.created_at) ? formatDateTimeByLang(orderData.createdAt || orderData.created_at) : 'N/A';
  const notes = orderData?.notes ? escapeHtml(orderData.notes) : '';
  const status = orderData?.status || 'draft';
  const statusText = translateStatus(status);
  const totalAmount = formatCurrency(orderData?.totalAmount || orderData?.total_amount || 0);
  const numberOfItems = (orderData?.items || []).length;
  
  // Current date and time
  const { printDate, printTime } = formatPrintDateTime();

  // Build print document using DOM manipulation to avoid Vue parser issues
  // This matches the Foodics reference exactly
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
  titleEl.textContent = 'Purchase Order - ' + poNumber;
  const scriptEl = printDoc.createElement('script');
  scriptEl.setAttribute('src', 'https://cdn.tailwindcss.com');
  
  // Print-optimized CSS matching Foodics reference exactly
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
  
  // Build HTML content as array to avoid Vue parser issues
  // Structure matches Foodics reference EXACTLY
  const parts = [];
  
  // TOP BAR: Date/Time left, System Name right (matching Foodics exactly)
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid #d1d5db;">');
  parts.push('<div style="font-size: 11px; color: #6b7280;">' + printDate + ', ' + printTime + '</div>');
  parts.push('<div style="font-size: 11px; color: #6b7280; font-weight: 600;">' + safeT('inventory.purchaseOrders.purchaseOrderSakuraERP') + '</div>');
  parts.push('</div>');
  
  // HEADER: Centered logo (matching Foodics exactly)
  // SAKURA LOGO: Using actual logo image
  // Note: Place your logo file in public folder as /sakura-logo.png
  const logoUrl = window.location.origin + '/Sakura_Pink_Logo.png';
  parts.push('<div style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #d1d5db; background: white;">');
  // Logo image - The logo already contains both the flower symbol and "SAKURA" text
  // Using full URL for print window compatibility
  // White background to avoid transparent checkerboard pattern
  parts.push('<img src="' + logoUrl + '" alt="Sakura Logo" style="height: 80px; max-width: 200px; margin: 0 auto; display: block; object-fit: contain; background: white;" />');
  parts.push('</div>');
  
  // TITLE ROW: PO Number left, Status right (matching Foodics exactly)
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">');
  parts.push('<div><h2 style="font-size: 18px; font-weight: 700; color: #111827; margin: 0;">' + safeT('inventory.purchaseOrders.title') + ' (' + poNumber + ')</h2></div>');
  parts.push('<div><span style="padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: #f3f4f6; color: #374151;">' + statusText + '</span></div>');
  parts.push('</div>');
  
  // DETAILS SECTION: Two-column layout with borders (matching Foodics EXACTLY)
  // Field order: Supplier, Destination, Business Date, Creator, Submitter, Approver, Created At, Notes, Delivery Date, Purchase Order Total Cost, Number of Items
  const alignStyle = 'text-align: ' + textAlignValue + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.supplier') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + supplierName + supplierLocalized + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.destination') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + destination + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.businessDate') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + businessDate + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.creator') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + creator + '</div></div>');
  if (submitter) {
    parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.submitter') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + submitter + '</div></div>');
  }
  if (approver) {
    parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.approver') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + approver + '</div></div>');
  }
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.createdAt') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + createdAt + '</div></div>');
  if (notes) {
    parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.notes') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + notes + '</div></div>');
  }
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.deliveryDate') + '</div><div style="font-size: 13px; color: #111827; ' + alignStyle + '">' + deliveryDate + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.purchaseOrderTotalCost') + '</div><div style="font-size: 13px; color: #111827; font-weight: 600; ' + alignStyle + '">' + totalAmount + '</div></div>');
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + safeT('inventory.purchaseOrders.numberOfItems') + '</div><div style="font-size: 13px; color: #111827; font-weight: 600; ' + alignStyle + '">' + numberOfItems + '</div></div>');
  parts.push('</div>');
  
  // ITEMS SECTION: Table with light gray header (matching Foodics exactly)
  const thAlign = 'text-align: ' + textAlignValue + ';';
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">' + safeT('inventory.purchaseOrders.items') + '</h3>');
  parts.push('<table style="width: 100%; border-collapse: collapse;">');
  parts.push('<thead>');
  parts.push('<tr style="background-color: #f9fafb;">');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.name') + '</th>');
  parts.push('<th style="padding: 10px 16px; ' + thAlign + ' font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.sku') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.availableQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.costPerUnit') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.orderedQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.receivedQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.remainingQuantity') + '</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #d1d5db;">' + safeT('inventory.purchaseOrders.totalCost') + '</th>');
  parts.push('</tr>');
  parts.push('</thead>');
  parts.push('<tbody>');
  
  // Build items rows
  const items = orderData?.items || [];
  items.forEach(item => {
    const itemName = escapeHtml(item.item?.name || 'N/A');
    const itemNameLocalized = item.item?.nameLocalized ? '<br><span style="color: #6b7280; font-size: 0.875rem;">' + escapeHtml(item.item.nameLocalized) + '</span>' : '';
    const sku = escapeHtml(item.item?.sku || 'N/A');
    const availableQty = item.item?.availableQuantity || item.item?.quantity || 0;
    const costPerUnit = formatCurrency(item.unitPrice || item.unit_price || 0);
    const quantity = item.quantity || 0;
    const totalCost = formatCurrency(item.totalAmount || item.total_amount || 0);
    // Calculate received and remaining quantities from GRNs
    const receivedQty = getReceivedQuantityForPOItem(item);
    const remainingQty = getRemainingQuantityForPOItem(item);
    // Get unit from database - never hardcode
    const unit = item.item?.storageUnit || item.item?.storage_unit || item.item?.ingredientUnit || item.item?.ingredient_unit || '';
    
    parts.push('<tr>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + itemName + itemNameLocalized + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + sku + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; text-align: right; border-bottom: 1px solid #e5e7eb;">' + availableQty + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; text-align: right; border-bottom: 1px solid #e5e7eb;">' + costPerUnit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + quantity.toFixed(2) + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #10b981; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + receivedQty.toFixed(2) + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: ' + (remainingQty > 0 ? '#f59e0b' : '#6b7280') + '; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + remainingQty.toFixed(2) + ' ' + unit + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + totalCost + '</td>');
    parts.push('</tr>');
  });
  
  if (items.length === 0) {
    parts.push('<tr><td colspan="8" style="padding: 32px 16px; text-align: center; color: #6b7280;">' + safeT('inventory.purchaseOrders.noItems') + '</td></tr>');
  }
  
  parts.push('</tbody>');
  parts.push('</table>');
  parts.push('</div>');
  
  // FOOTER: System name left, Page number right (matching Foodics exactly)
  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #6b7280;">');
  parts.push('<div>' + safeT('inventory.purchaseOrders.sakuraERPSystem') + '</div>');
  parts.push('<div>' + safeT('inventory.purchaseOrders.page') + ' 1 / 1</div>');
  parts.push('</div>');
  
  container.innerHTML = parts.join('');
  bodyEl.appendChild(container);
  htmlEl.appendChild(bodyEl);
  printDoc.appendChild(htmlEl);
  printDoc.close();

  // Wait for iframe content to load, then print directly
  // This shows print dialog in current window without opening new tab
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

const openUpdateItemModal = (item, index) => {
  updatingItem.value = item;
  updatingItemIndex.value = index;
  updateItemForm.value = {
    quantity: item.quantity || 0,
    totalCost: item.totalAmount || item.total_amount || 0
  };
  showUpdateItemModal.value = true;
};

const closeUpdateItemModal = () => {
  showUpdateItemModal.value = false;
  updatingItem.value = null;
  updatingItemIndex.value = -1;
  updateItemForm.value = { quantity: 0, totalCost: 0 };
};

const saveUpdateItem = async () => {
  if (!updatingItem.value || updatingItemIndex.value === -1) return;
  
  try {
    const unitPrice = updateItemForm.value.totalCost / updateItemForm.value.quantity;
    const items = [...(order.value.items || [])];
    items[updatingItemIndex.value] = {
      ...items[updatingItemIndex.value],
      quantity: updateItemForm.value.quantity,
      unitPrice: unitPrice,
      totalAmount: updateItemForm.value.totalCost
    };
    
    // Recalculate totals
    const subtotal = items.reduce((sum, item) => sum + (item.totalAmount || 0), 0);
    
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      items: items,
      totalAmount: subtotal
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

const openAddItemsModal = () => {
  showAddItemsModal.value = true;
  itemSearchQuery.value = '';
  newItemForm.value = { itemId: '', quantity: 1, unitPrice: 0 };
};

const closeAddItemsModal = () => {
  showAddItemsModal.value = false;
  itemSearchQuery.value = '';
  newItemForm.value = { itemId: '', quantity: 1, unitPrice: 0 };
};

const deleteItemFromOrder = async (index) => {
  if (!order.value || !order.value.items || index < 0 || index >= order.value.items.length) {
    showNotification('Invalid item index', 'error');
    return;
  }
  
  const item = order.value.items[index];
  const itemName = item.item?.name || item.item?.nameLocalized || 'this item';
  const itemSKU = item.item?.sku || '';
  
  // Show confirmation using custom dialog
  const confirmed = await showConfirmDialog({
    title: 'Delete Item',
    message: `Are you sure you want to delete "${itemName}${itemSKU ? ' (' + itemSKU + ')' : ''}" from this purchase order?`,
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) {
    return;
  }
  
  try {
    // Remove item from array
    const items = [...(order.value.items || [])];
    items.splice(index, 1);
    
    // Recalculate totals
    const subtotal = items.reduce((sum, item) => sum + (item.totalAmount || item.total_amount || 0), 0);
    
    // Update purchase order
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      items: items,
      totalAmount: subtotal
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

const selectItemForAdd = (item) => {
  newItemForm.value.itemId = item.id;
  newItemForm.value.unitPrice = item.cost || 0;
};

const saveAddItem = async () => {
  if (!newItemForm.value.itemId) {
    showNotification('Please select an item', 'warning');
    return;
  }
  
  try {
    const selectedItem = inventoryItems.value.find(i => i.id === newItemForm.value.itemId);
    if (!selectedItem) {
      throw new Error('Selected item not found');
    }
    
    const newItem = {
      itemId: newItemForm.value.itemId,
      quantity: newItemForm.value.quantity || 1,
      unitPrice: newItemForm.value.unitPrice || 0,
      vatRate: 0,
      vatAmount: 0,
      totalAmount: (newItemForm.value.quantity || 1) * (newItemForm.value.unitPrice || 0)
    };
    
    const items = [...(order.value.items || []), newItem];
    const subtotal = items.reduce((sum, item) => sum + (item.totalAmount || 0), 0);
    
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      items: items,
      totalAmount: subtotal
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

const openEditQuantitiesModal = () => {
  if (!order.value || !order.value.items || order.value.items.length === 0) {
    showNotification('No items to edit', 'warning');
    return;
  }
  
  // Pre-fill form with current items data
  editQuantitiesForm.value.items = (order.value.items || []).map(item => {
    // Handle nested item structure (from Supabase relationship)
    const itemData = item.item || item;
    
    return {
      ...item,
      item: itemData, // Keep item reference for display
      itemId: item.itemId || item.item_id || itemData?.id,
      quantity: item.quantity || 0,
      unitPrice: item.unitPrice || item.unit_price || 0,
      vatRate: item.vatRate || item.vat_rate || 0,
      totalAmount: item.totalAmount || item.total_amount || (item.quantity || 0) * (item.unitPrice || item.unit_price || 0)
    };
  });
  
  console.log('📝 Edit Quantities Form:', editQuantitiesForm.value.items);
  showEditQuantitiesModal.value = true;
};

const closeEditQuantitiesModal = () => {
  showEditQuantitiesModal.value = false;
  editQuantitiesForm.value.items = [];
};

const updateItemTotalInBulk = (index) => {
  const item = editQuantitiesForm.value.items[index];
  if (item) {
    const quantity = item.quantity || 0;
    const unitPrice = item.unitPrice || 0;
    item.totalAmount = quantity * unitPrice;
  }
};

const saveEditQuantities = async () => {
  if (!order.value) return;
  
  if (!editQuantitiesForm.value.items || editQuantitiesForm.value.items.length === 0) {
    showNotification(t('inventory.purchaseOrders.noItemsToSave'), 'warning');
    return;
  }
  
  savingQuantities.value = true;
  try {
    // Validate all items have quantity and cost
    for (const item of editQuantitiesForm.value.items) {
      if (!item.quantity || item.quantity <= 0) {
        showNotification('Please enter a valid quantity for all items', 'warning');
        savingQuantities.value = false;
        return;
      }
      if (!item.unitPrice || item.unitPrice < 0) {
        showNotification('Please enter a valid cost for all items', 'warning');
        savingQuantities.value = false;
        return;
      }
    }
    
    // Update items with new quantities and costs
    const updatedItems = editQuantitiesForm.value.items.map(item => ({
      itemId: item.itemId || item.item_id,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      vatRate: item.vatRate || item.vat_rate || 0,
      vatAmount: (item.quantity * item.unitPrice) * ((item.vatRate || item.vat_rate || 0) / 100),
      totalAmount: item.totalAmount || (item.quantity * item.unitPrice)
    }));
    
    // Calculate new totals
    const subtotal = updatedItems.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0);
    const totalVAT = updatedItems.reduce((sum, item) => sum + item.vatAmount, 0);
    const totalAmount = subtotal + totalVAT;
    
    const result = await updatePurchaseOrderInSupabase(order.value.id, {
      ...order.value,
      items: updatedItems,
      totalAmount: totalAmount,
      vatAmount: totalVAT
    });
    
    if (result.success) {
      showNotification('Items quantities and costs updated successfully', 'success');
      closeEditQuantitiesModal();
      await loadOrder(); // Reload order to show updated data
    } else {
      throw new Error(result.error || 'Failed to update items');
    }
  } catch (error) {
    console.error('Error updating quantities and costs:', error);
    showNotification('Error updating items: ' + (error.message || 'Unknown error'), 'error');
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
          // Parse CSV
          const text = e.target.result;
          const workbook = XLSX.read(text, { type: 'string' });
          const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
          jsonData = XLSX.utils.sheet_to_json(firstSheet);
        } else {
          // Parse Excel
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
  // Create template data with headers
  const templateData = [
    {
      name: '',
      sku: '',
      order_qua: '',
      storage_qi: '',
      total_cost: ''
    }
  ];
  
  // Create workbook
  const worksheet = XLSX.utils.json_to_sheet(templateData);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Purchase Order Items');
  
  // Download file
  const fileName = `purchase_order_items_template_${new Date().getTime()}.xlsx`;
  XLSX.writeFile(workbook, fileName);
  
  showNotification('Template downloaded successfully', 'success');
};

const processImportFile = async () => {
  if (!importFileData.value || !order.value) return;
  
  importingItems.value = true;
  try {
    // Load all inventory items to match by name or SKU
    const allItems = inventoryItems.value.length > 0 
      ? inventoryItems.value 
      : await loadItemsFromSupabase();
    
    const importedItems = [];
    const errors = [];
    
    for (let i = 0; i < importFileData.value.length; i++) {
      const row = importFileData.value[i];
      const rowNum = i + 2; // +2 because Excel rows start at 1 and we have a header
      
      // Validate required fields
      if (!row.name && !row.sku) {
        errors.push(`Row ${rowNum}: Name or SKU is required`);
        continue;
      }
      
      // Find item by name or SKU
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
      
      // Get quantity and cost
      const quantity = parseFloat(row.order_qua || row.order_quantity || row.quantity || 0);
      const totalCost = parseFloat(row.total_cost || row.totalCost || 0);
      const unitPrice = quantity > 0 ? totalCost / quantity : 0;
      
      if (quantity <= 0) {
        errors.push(`Row ${rowNum}: Quantity must be greater than 0`);
        continue;
      }
      
      if (totalCost < 0) {
        errors.push(`Row ${rowNum}: Total cost cannot be negative`);
        continue;
      }
      
      // Check if item already exists in order
      const existingItemIndex = order.value.items?.findIndex(
        poItem => (poItem.itemId || poItem.item_id) === item.id
      );
      
      if (existingItemIndex >= 0) {
        // Update existing item
        const existingItem = order.value.items[existingItemIndex];
        existingItem.quantity = (existingItem.quantity || 0) + quantity;
        existingItem.unitPrice = unitPrice;
        existingItem.totalAmount = (existingItem.totalAmount || 0) + totalCost;
      } else {
        // Add new item
        importedItems.push({
          itemId: item.id,
          item: item,
          quantity: quantity,
          unitPrice: unitPrice,
          vatRate: 0,
          vatAmount: 0,
          totalAmount: totalCost
        });
      }
    }
    
    if (errors.length > 0) {
      showNotification(`Import completed with ${errors.length} error(s). Check console for details.`, 'warning');
      console.error('Import errors:', errors);
    }
    
    // Add new items to order
    if (importedItems.length > 0) {
      const currentItems = order.value.items || [];
      const updatedItems = [...currentItems, ...importedItems];
      
      // Recalculate totals
      const subtotal = updatedItems.reduce((sum, item) => sum + (item.totalAmount || 0), 0);
      const totalVAT = updatedItems.reduce((sum, item) => sum + (item.vatAmount || 0), 0);
      const totalAmount = subtotal + totalVAT;
      
      const result = await updatePurchaseOrderInSupabase(order.value.id, {
        ...order.value,
        items: updatedItems,
        totalAmount: totalAmount,
        vatAmount: totalVAT
      });
      
      if (result.success) {
        showNotification(`${importedItems.length} item(s) imported successfully`, 'success');
        closeImportItemsModal();
        await loadOrder(); // Reload order to show updated data
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

const getAvailableQuantity = (item) => {
  // Get available quantity from inventory
  return item?.availableQuantity || item?.quantity || 0;
};

// Get item unit from database - ALWAYS use database value, never hardcode
const getItemUnit = (item) => {
  if (!item) return '';
  // Get unit from database - check storageUnit first, then ingredientUnit
  // IMPORTANT: Unit must come from database, not hardcoded
  return item.storageUnit || item.storage_unit || item.ingredientUnit || item.ingredient_unit || '';
};

// Get item name - try multiple sources (item relationship, direct fields, inventory lookup)
const getItemName = (poItem) => {
  if (!poItem) return 'N/A';
  // Try item relationship first (from database)
  if (poItem.item?.name) return poItem.item.name;
  // Try direct fields
  if (poItem.itemName || poItem.item_name) return poItem.itemName || poItem.item_name;
  // Try inventory lookup
  const itemId = poItem.itemId || poItem.item_id;
  if (itemId) {
    const inventoryItem = inventoryItems.value.find(i => i.id === itemId);
    if (inventoryItem?.name) return inventoryItem.name;
  }
  return 'N/A';
};

// Get item name localized
const getItemNameLocalized = (poItem) => {
  if (!poItem) return null;
  if (poItem.item?.nameLocalized || poItem.item?.name_localized) {
    return poItem.item.nameLocalized || poItem.item.name_localized;
  }
  const itemId = poItem.itemId || poItem.item_id;
  if (itemId) {
    const inventoryItem = inventoryItems.value.find(i => i.id === itemId);
    if (inventoryItem?.nameLocalized || inventoryItem?.name_localized) {
      return inventoryItem.nameLocalized || inventoryItem.name_localized;
    }
  }
  return null;
};

// Get item SKU - try multiple sources
const getItemSKU = (poItem) => {
  if (!poItem) return 'N/A';
  // Try item relationship first (from database)
  if (poItem.item?.sku || poItem.item?.code) return poItem.item.sku || poItem.item.code;
  // Try direct fields
  if (poItem.itemCode || poItem.item_code) return poItem.itemCode || poItem.item_code;
  // Try inventory lookup
  const itemId = poItem.itemId || poItem.item_id;
  if (itemId) {
    const inventoryItem = inventoryItems.value.find(i => i.id === itemId);
    if (inventoryItem?.sku || inventoryItem?.code) {
      return inventoryItem.sku || inventoryItem.code;
    }
  }
  return 'N/A';
};

const getSupplierName = (supplierId) => {
  if (!supplierId) return null;
  const supplier = suppliers.value.find(s => s.id === supplierId);
  return supplier ? supplier.name : null;
};

const getSupplierLocalizedName = (supplierId) => {
  if (!supplierId) return null;
  const supplier = suppliers.value.find(s => s.id === supplierId);
  return supplier ? supplier.nameLocalized : null;
};

const formatStatus = (status) => {
  const statusMap = {
    'draft': 'Draft',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'closed': 'Closed',
    'fully_received': 'Fully Received',
    'partially_received': 'Partially Received'
  };
  return statusMap[status] || status;
};

const getStatusClass = (status) => {
  const classMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'approved': 'bg-green-100 text-green-800',
    'rejected': 'bg-red-100 text-red-800',
    'closed': 'bg-gray-100 text-gray-800',
    'fully_received': 'bg-emerald-100 text-emerald-800',
    'partially_received': 'bg-amber-100 text-amber-800'
  };
  return classMap[status] || 'bg-gray-100 text-gray-800';
};

// Receiving Status Tracking (Real-time)
const grns = ref([]);
const receivingStatusDetails = computed(() => {
  if (!order.value || grns.value.length === 0) return null;
  
  const poItems = order.value.items || [];
  const itemReceivedQty = {};
  const itemOrderedQty = {};
  
  // Calculate ordered quantities
  poItems.forEach(poItem => {
    const itemId = poItem.itemId || poItem.item_id;
    itemOrderedQty[itemId] = parseFloat(poItem.quantity || 0);
  });
  
  // Calculate received quantities from approved/under_inspection GRNs
  grns.value.forEach(grn => {
    if (grn.status === 'approved' || grn.status === 'under_inspection') {
      const grnItems = grn.items || [];
      grnItems.forEach(grnItem => {
        const itemId = grnItem.itemId || grnItem.item_id;
        if (!itemReceivedQty[itemId]) {
          itemReceivedQty[itemId] = 0;
        }
        itemReceivedQty[itemId] += parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
      });
    }
  });
  
  // Calculate totals
  let totalOrdered = 0;
  let totalReceived = 0;
  let fullyReceivedItems = 0;
  let partiallyReceivedItems = 0;
  let notReceivedItems = 0;
  
  poItems.forEach(poItem => {
    const itemId = poItem.itemId || poItem.item_id;
    const ordered = itemOrderedQty[itemId] || 0;
    const received = itemReceivedQty[itemId] || 0;
    
    totalOrdered += ordered;
    totalReceived += received;
    
    if (received >= ordered) {
      fullyReceivedItems++;
    } else if (received > 0) {
      partiallyReceivedItems++;
    } else {
      notReceivedItems++;
    }
  });
  
  const percentage = totalOrdered > 0 ? Math.round((totalReceived / totalOrdered) * 100) : 0;
  
  return `${totalReceived} / ${totalOrdered} units received (${percentage}%) • ${fullyReceivedItems} fully, ${partiallyReceivedItems} partial, ${notReceivedItems} pending`;
});

const getReceivingStatusText = () => {
  const status = order.value?.status || '';
  if (status === 'fully_received') {
    return '✅ Received All';
  } else if (status === 'partially_received') {
    return '⚠️ Partially Received';
  } else if (status === 'approved') {
    return '📦 Not Received Yet';
  }
  return '';
};

const getReceivingStatusClass = () => {
  const status = order.value?.status || '';
  if (status === 'fully_received') {
    return 'bg-emerald-50 border-emerald-300 text-emerald-900';
  } else if (status === 'partially_received') {
    return 'bg-amber-50 border-amber-300 text-amber-900';
  } else if (status === 'approved') {
    return 'bg-blue-50 border-blue-300 text-blue-900';
  }
  return 'bg-gray-50 border-gray-300 text-gray-900';
};

const getReceivingStatusIcon = () => {
  const status = order.value?.status || '';
  if (status === 'fully_received') {
    return 'fas fa-check-circle text-emerald-600';
  } else if (status === 'partially_received') {
    return 'fas fa-exclamation-triangle text-amber-600';
  } else if (status === 'approved') {
    return 'fas fa-box text-blue-600';
  }
  return 'fas fa-info-circle text-gray-600';
};

// Get received quantity for a specific PO item (from all associated GRNs)
// CRITICAL: Uses grns.value which is filtered by purchase_order_number
const getReceivedQuantityForPOItem = (poItem) => {
  if (!poItem || !order.value) return 0;
  
  const itemId = poItem.itemId || poItem.item_id;
  if (!itemId) return 0;
  
  // PRIORITY 1: Use quantity_received from database if available (updated by trigger)
  const storedReceived = parseFloat(poItem.quantity_received || poItem.quantityReceived || 0);
  if (storedReceived > 0) {
    console.log(`✅ Using stored quantity_received for item ${itemId}: ${storedReceived}`);
    return storedReceived;
  }
  
  // PRIORITY 2: Calculate from loaded GRNs
  if (!grns.value || grns.value.length === 0) {
    return 0;
  }
  
  let totalReceived = 0;
  
  // Sum up received quantities from all GRNs (excluding rejected/cancelled)
  grns.value.forEach(grn => {
    const grnStatus = (grn.status || '').toLowerCase();
    // Count: draft, pending, passed, hold, conditional, approved, submitted
    // Exclude: rejected, cancelled
    if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
      const grnItems = grn.items || [];
      grnItems.forEach(grnItem => {
        const grnItemId = grnItem.itemId || grnItem.item_id;
        // CRITICAL: Compare item IDs as strings (both should be UUIDs)
        if (String(grnItemId) === String(itemId)) {
          const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
          totalReceived += receivedQty;
          console.log(`📦 GRN ${grn.grnNumber || grn.grn_number || 'Draft'}: Item ${itemId} received ${receivedQty}, Total now: ${totalReceived}`);
        }
      });
    }
  });
  
  console.log(`✅ Total received for item ${itemId}: ${totalReceived}`);
  return totalReceived;
};

// Get remaining quantity for a specific PO item
const getRemainingQuantityForPOItem = (poItem) => {
  if (!poItem || !order.value) return 0;
  
  const orderedQty = parseFloat(poItem.quantity || 0);
  const receivedQty = getReceivedQuantityForPOItem(poItem);
  const remaining = orderedQty - receivedQty;
  
  return Math.max(0, remaining); // Ensure non-negative
};

// Get all GRNs that received a specific PO item
const getGRNsForItem = (poItem) => {
  if (!poItem || !grns.value || grns.value.length === 0) return [];
  
  const itemId = poItem.itemId || poItem.item_id;
  if (!itemId) return [];
  
  return grns.value.filter(grn => {
    const grnItems = grn.items || [];
    return grnItems.some(grnItem => {
      const grnItemId = grnItem.itemId || grnItem.item_id;
      return grnItemId === itemId && (grnItem.receivedQuantity || grnItem.received_quantity || 0) > 0;
    });
  });
};

// Get received quantity for an item from a specific GRN
const getReceivedQtyFromGRN = (grn, poItem) => {
  if (!grn || !poItem) return 0;
  
  const itemId = poItem.itemId || poItem.item_id;
  if (!itemId) return 0;
  
  const grnItems = grn.items || [];
  const grnItem = grnItems.find(gi => {
    const giItemId = gi.itemId || gi.item_id;
    return giItemId === itemId;
  });
  
  if (!grnItem) return 0;
  
  return parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
};

// Get CSS class for GRN status
const getGRNStatusClass = (status) => {
  const statusMap = {
    'draft': 'bg-gray-100 text-gray-800',
    'pending': 'bg-yellow-100 text-yellow-800',
    'under_inspection': 'bg-yellow-100 text-yellow-800',
    'passed': 'bg-green-100 text-green-800',
    'approved': 'bg-green-100 text-green-800',
    'hold': 'bg-orange-100 text-orange-800',
    'conditional': 'bg-blue-100 text-blue-800',
    'rejected': 'bg-red-100 text-red-800',
    'cancelled': 'bg-gray-100 text-gray-600'
  };
  return statusMap[status?.toLowerCase()] || 'bg-gray-100 text-gray-800';
};

// Format GRN status text
const formatGRNStatus = (status) => {
  const statusMap = {
    'draft': 'Draft',
    'pending': 'Under Inspection',
    'under_inspection': 'Under Inspection',
    'passed': 'Approved',
    'approved': 'Approved',
    'hold': 'Hold',
    'conditional': 'Conditional',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled'
  };
  return statusMap[status?.toLowerCase()] || status || 'Unknown';
};

// Navigate to GRN detail page - SAP-style direct navigation
const viewGRNDetail = (grnId) => {
  if (!grnId) {
    console.warn('⚠️ No GRN ID provided for navigation');
    return;
  }
  
  console.log('🔍 VIEW GRN CLICKED - Navigating to GRN with ID:', grnId);
  
  // FIXED: Use Vue Router with correct path format (matching router/index.js)
  // Route: /homeportal/grn-detail/:id
  const targetPath = `/homeportal/grn-detail/${grnId}`;
  
  try {
    // Primary method: Vue Router push with path parameter
    console.log('✅ Navigating via router.push to:', targetPath);
    router.push(targetPath);
  } catch (routerError) {
    console.warn('⚠️ Router.push failed, trying fallback:', routerError);
    
    // Fallback 1: Use hash navigation (for hash-based router)
    try {
      window.location.hash = `#${targetPath}`;
      console.log('✅ Navigated via hash to:', `#${targetPath}`);
    } catch (hashError) {
      console.error('❌ Hash navigation failed:', hashError);
      
      // Fallback 2: Full page navigation
      window.location.href = `/#${targetPath}`;
      console.log('✅ Navigated via full URL to:', `/#${targetPath}`);
    }
  }
};

// Show Received/Remaining columns after PO is approved (always show, even if no GRNs yet)
const shouldShowReceivingColumns = computed(() => {
  const status = order.value?.status || '';
  // Show columns if PO is approved/partially_received/fully_received/closed (always, even if no GRNs yet)
  return status === 'approved' || status === 'partially_received' || status === 'fully_received' || status === 'closed';
});

// Calculate table colspan based on status and receiving columns visibility
const getItemsTableColspan = () => {
  const baseCols = 6; // Name, SKU, Available Qty, Cost Per Unit, Ordered Qty, Total Cost
  const actionCol = (orderStatus.value === 'draft' || orderStatus.value === 'pending') ? 1 : 0;
  const receivingCols = shouldShowReceivingColumns.value ? 2 : 0; // Received Qty, Remaining Qty
  return baseCols + receivingCols + actionCol;
};

const formatDate = (date) => {
  if (!date) return '—';
  const d = new Date(date);
  return d.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
};

const formatDateTime = (date) => {
  if (!date) return 'N/A';
  const d = new Date(date);
  return d.toLocaleDateString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
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

watch(
  () => poStatus.value,
  () => {
    console.log('[PO STATUS WATCHER]', poStatus.value);
    nextTick();
  }
);

watch(
  () => orderStatus.value,
  (newStatus) => {
    if (newStatus && (!poStatus.value || poStatus.value !== newStatus)) {
      console.log('[ORDER STATUS WATCHER] Syncing poStatus from orderStatus:', newStatus);
      poStatus.value = newStatus;
      nextTick();
    }
  },
  { immediate: true }
);

onMounted(async () => {
  destinationOptions.value = await loadLocationsForPO();
  // STEP 1: Resolve PO UUID from numeric route param (SINGLE SOURCE OF TRUTH)
  const routeParamId = route.params?.id;
  if (!routeParamId) {
    error.value = 'No purchase order ID provided';
    loading.value = false;
    return;
  }
  
  // Database uses INTEGER IDs, not UUIDs - use route param directly
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const isNumericId = typeof routeParamId === 'number' || (typeof routeParamId === 'string' && /^\d+$/.test(routeParamId));
  
  if (isNumericId) {
    // Numeric ID: Use directly (database uses integer IDs)
    console.log('✅ Using numeric route param as PO ID:', routeParamId);
    poUuid.value = String(routeParamId);
    console.log('✅ PO ID set:', poUuid.value);
  } else if (uuidRegex.test(routeParamId)) {
    // UUID format: Use directly
    poUuid.value = routeParamId;
    console.log('✅ Route param is UUID:', poUuid.value);
  } else {
    // Try lookup by po_number if route param is not numeric or UUID
    console.log('🔍 Resolving PO ID from route param:', routeParamId);
    try {
      // Strategy 1: Try by po_number (exact match)
      let poRecord = null;
      let poError = null;
      
      const { data: dataByNumber, error: errorByNumber } = await supabaseClient
        .from('purchase_orders')
        .select('id, po_number')
        .eq('po_number', String(routeParamId))
        .maybeSingle();
      
      if (!errorByNumber && dataByNumber?.id) {
        poRecord = dataByNumber;
      } else {
        // Strategy 2: Try by id (if numeric ID is actually UUID or stored differently)
        const { data: dataById, error: errorById } = await supabaseClient
          .from('purchase_orders')
          .select('id, po_number')
          .eq('id', routeParamId)
          .maybeSingle();
        
        if (!errorById && dataById?.id) {
          poRecord = dataById;
        } else {
          // Strategy 3: Try numeric po_number patterns (PO-XXX, etc.)
          const paddedNumber = String(routeParamId).padStart(6, '0');
          const { data: dataByPattern, error: errorByPattern } = await supabaseClient
            .from('purchase_orders')
            .select('id, po_number')
            .or(`po_number.eq.PO-${paddedNumber},po_number.ilike.%${routeParamId}%`)
            .limit(1)
            .maybeSingle();
          
          if (!errorByPattern && dataByPattern?.id) {
            poRecord = dataByPattern;
          } else {
            poError = errorByPattern || errorById || errorByNumber;
          }
        }
      }
      
      if (poError || !poRecord?.id) {
        console.error('❌ PO UUID lookup failed after all strategies:', poError?.message);
        error.value = `Purchase order with number "${routeParamId}" not found`;
        loading.value = false;
        return;
      }
      
      // Database uses INTEGER IDs - use directly
      poUuid.value = String(poRecord.id);
      console.log('✅ PO ID resolved:', poUuid.value, 'from route param:', routeParamId, 'po_number:', poRecord.po_number);
    } catch (lookupError) {
      console.error('❌ Error looking up PO ID:', lookupError);
      error.value = `Failed to lookup purchase order: ${lookupError.message}`;
      loading.value = false;
      return;
    }
  }
  
  // STEP 2: Load order using UUID (never use numeric ID)
  if (!poUuid.value) {
    error.value = 'PO UUID resolution failed';
    loading.value = false;
    return;
  }
  
  loadOrder();
  loadInventoryItems();
  loadSuppliers();
  
  // CRITICAL: Listen for GRN approval events to refresh PO data
  const handleGRNApproved = async (event) => {
    const { poId, grnId } = event.detail || {};
    const currentPOId = order.value ? String(order.value.id).trim() : null;
    const eventPOId = poId ? String(poId).trim() : null;
    
    console.log('🔄 GRN approved event received:', { 
      eventPOId, 
      currentPOId, 
      grnId,
      matches: eventPOId === currentPOId 
    });
    
    if (eventPOId && currentPOId && eventPOId === currentPOId) {
      console.log('✅ PO IDs match, refreshing PO data...');
      // Small delay to ensure database trigger has completed
      setTimeout(async () => {
        try {
          // CRITICAL: First reload GRNs to get latest data
          await loadGRNsForPO();
          
          // Then reload PO to get updated quantities from database
          await loadOrder();
          
          // Force Vue reactivity update
          await nextTick();
          
          console.log('✅ PO data refreshed after GRN approval');
          console.log('📊 Updated PO quantities:', {
            ordered: order.value?.ordered_quantity,
            received: order.value?.total_received_quantity,
            remaining: order.value?.remaining_quantity,
            status: order.value?.status
          });
          
          showNotification('PO quantities updated after GRN approval', 'success');
        } catch (error) {
          console.error('❌ Error refreshing PO after GRN approval:', error);
          showNotification('Error updating PO quantities', 'error');
        }
      }, 800); // Increased delay to ensure database trigger completes
    } else {
      console.log('⚠️ PO IDs do not match, skipping refresh');
      console.log('   Event PO ID:', eventPOId);
      console.log('   Current PO ID:', currentPOId);
    }
  };
  
  window.addEventListener('grn-approved', handleGRNApproved);
  
  // Cleanup on unmount
  onUnmounted(() => {
    window.removeEventListener('grn-approved', handleGRNApproved);
  });
  
  // CRITICAL: Force bind click handler to Create GRN button
  const bindCreateGRNButton = () => {
    const button = document.getElementById('create-grn-button') ||
                   document.querySelector('button[id="create-grn-button"]') ||
                            Array.from(document.querySelectorAll('button')).find(btn => 
                     btn.textContent && (btn.textContent.includes('Create GRN') || btn.textContent.includes('إنشاء'))
                            );
    
    if (button) {
      console.log('✅ Create GRN button found, binding click handler');
      
      // Remove any existing listeners by cloning
      const newButton = button.cloneNode(true);
      button.parentNode.replaceChild(newButton, button);
      
      // Add click handler
      newButton.addEventListener('click', (e) => {
        console.log('🔥🔥🔥 DIRECT CLICK HANDLER FIRED 🔥🔥🔥');
        e.stopPropagation();
        e.preventDefault();
        onCreateGRN(e);
      }, { capture: true, once: false });
      
      // Also add mousedown/mouseup for debugging
      newButton.addEventListener('mousedown', () => {
        console.log('🔥 DIRECT MOUSEDOWN');
      });
      
      newButton.addEventListener('mouseup', () => {
        console.log('🔥 DIRECT MOUSEUP');
      });
      
      return newButton;
    } else {
      console.warn('⚠️ Create GRN button not found');
      return null;
    }
  };
  
  // Bind immediately after mount and keep retrying until found
  const bindButtonWithRetry = async (maxRetries = 10) => {
    for (let i = 0; i < maxRetries; i++) {
      await nextTick();
      const button = bindCreateGRNButton();
      if (button) {
        console.log('✅ Button bound successfully on attempt', i + 1);
        return;
      }
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    console.error('❌ Failed to bind button after', maxRetries, 'attempts');
  };
  
  await bindButtonWithRetry();
  
  // Re-bind after status changes to approved
  watch(
    () => poStatus.value,
    (newStatus) => {
      if (newStatus === 'approved' || newStatus === 'partially_received') {
        console.log('[STATUS CHANGE] Re-binding button for status:', newStatus);
        setTimeout(() => {
          bindButtonWithRetry(5);
        }, 200);
      }
    }
  );
  
  // Also re-bind after order loads
  watch(
    () => order.value?.status,
    () => {
      setTimeout(() => {
        bindButtonWithRetry(3);
      }, 200);
    }
  );
});
</script>

<style scoped>
.loading-spinner {
  border-top-color: #284b44;
}

.sakura-primary-btn {
  background-color: #284b44;
  transition: background-color 0.2s ease;
}

.sakura-primary-btn:hover:not(:disabled) {
  background-color: #1f3a35;
}

.loading-overlay,
.skeleton,
.overlay {
  pointer-events: none !important;
}
</style>
