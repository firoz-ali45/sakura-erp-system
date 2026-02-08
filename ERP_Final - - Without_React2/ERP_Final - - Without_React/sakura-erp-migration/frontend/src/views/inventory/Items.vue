<template>
  <div class="min-h-screen bg-[#f0e1cd] p-6">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-800">{{ $t('inventory.items.title') }}</h1>
        <div class="flex items-center gap-3">
          <!-- Import/Export Dropdown -->
          <div class="relative">
            <button @click="toggleImportExportMenu" class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2">
              <i class="fas fa-cloud"></i>
              <span>{{ $t('inventory.suppliers.importExport') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showImportExportMenu" class="dropdown-menu">
              <a href="#" @click.prevent="openImportModal"><i class="fas fa-upload mr-2"></i>↑ {{ $t('inventory.items.import') }}</a>
              <a href="#" @click.prevent="exportItems"><i class="fas fa-download mr-2"></i>↓ {{ $t('inventory.items.export') }}</a>
              <a href="#" @click.prevent="downloadExcelTemplate"><i class="fas fa-file-excel mr-2"></i>{{ $t('inventory.suppliers.downloadExcelTemplate') }}</a>
            </div>
          </div>
          <!-- Create Item Button -->
          <button @click="openCreateItemModal" class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2 font-semibold">
            <i class="fas fa-plus"></i>
            <span>{{ $t('inventory.items.create') }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Tabs and Filter Section -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex gap-6 border-b border-gray-200">
          <button 
            v-for="tab in tabs" 
            :key="tab.id"
            @click="switchTab(tab.id)"
            :class="['tab-button px-4 py-2 text-gray-700', { active: activeTab === tab.id }]"
            :data-tab="tab.id"
          >
            {{ tab.label }}
          </button>
        </div>
        <div class="flex items-center gap-3">
          <button 
            @click="hasActiveFilters ? clearFilter() : openFilter()" 
            :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', hasActiveFilters ? 'bg-purple-100 border-purple-300 text-purple-700 hover:bg-purple-200' : 'border-gray-300 hover:bg-gray-50']"
          >
            <i :class="hasActiveFilters ? 'fas fa-times-circle' : 'fas fa-filter'"></i>
            <span>{{ hasActiveFilters ? $t('inventory.grn.filter.clear') : $t('common.filter') }}</span>
            <span v-if="hasActiveFilters" class="ml-1 bg-purple-600 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center">
              {{ activeFiltersCount }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <!-- Bulk Actions Bar -->
    <div v-if="selectedItems.length > 0" class="bg-yellow-50 border border-yellow-200 rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-4">
          <span class="font-semibold text-gray-700">{{ selectedItems.length }} {{ $t('common.selected') }}</span>
          <div class="relative">
            <button @click="toggleBulkActionsMenu" class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2">
              <i class="fas fa-tasks"></i>
              <span>{{ $t('common.actions') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showBulkActionsMenu" class="dropdown-menu">
              <a v-if="activeTab === 'deleted'" href="#" @click.prevent="bulkRestoreItems"><i class="fas fa-undo mr-2 text-green-600"></i>{{ $t('inventory.suppliers.bulkRestore') }}</a>
              <a v-else href="#" @click.prevent="bulkDeleteItems"><i class="fas fa-trash mr-2 text-red-600"></i>{{ $t('common.delete') }}</a>
              <a href="#" @click.prevent="bulkAddTags"><i class="fas fa-tags mr-2 text-blue-600"></i>{{ $t('inventory.suppliers.addTags') }}</a>
              <a href="#" @click.prevent="bulkRemoveTags"><i class="fas fa-tag mr-2 text-orange-600"></i>{{ $t('inventory.suppliers.removeTags') }}</a>
              <a href="#" @click.prevent="bulkExportItems"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.purchaseOrders.exportSelected') }}</a>
              <a href="#" @click.prevent="bulkChangeCategory"><i class="fas fa-folder mr-2 text-purple-600"></i>{{ $t('inventory.items.changeCategory') }}</a>
            </div>
          </div>
        </div>
        <button @click="clearSelection" class="text-gray-600 hover:text-gray-800">
          <i class="fas fa-times"></i> {{ $t('inventory.grn.filter.clearSelection') }}
        </button>
      </div>
    </div>

    <!-- Items Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="table-container">
        <table class="w-full">
          <thead>
            <tr class="bg-[#284b44] text-white">
              <th :class="['px-6 py-4', textAlign]">
                <input 
                  type="checkbox" 
                  :checked="allItemsSelected" 
                  @change="toggleSelectAll" 
                  class="rounded"
                >
              </th>
              <th :class="['px-6 py-4 font-semibold', textAlign]">{{ $t('inventory.items.name') }}</th>
              <th :class="['px-6 py-4 font-semibold', textAlign]">{{ $t('inventory.items.sku') }}</th>
              <th :class="['px-6 py-4 font-semibold', textAlign]">{{ $t('inventory.items.category') }}</th>
              <th :class="['px-6 py-4 font-semibold', textAlign]">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-if="loading">
              <td colspan="5" class="px-6 py-12 text-center">
                <div class="flex flex-col items-center justify-center space-y-4">
                  <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin"></div>
                  <p class="text-gray-600">{{ $t('inventory.items.loading') }}</p>
                </div>
              </td>
            </tr>
            <tr v-else-if="!filteredItems || filteredItems.length === 0">
              <td colspan="5" class="px-6 py-12 text-center">
                <div class="flex flex-col items-center justify-center space-y-4">
                  <div class="text-6xl mb-4">📦</div>
                  <h3 class="text-2xl font-bold text-gray-800 mb-2">{{ $t('common.noItemsFound') }}</h3>
                  <p class="text-gray-600 text-lg">
                    {{ activeTab === 'deleted' ? $t('inventory.items.noDeletedItems') : $t('inventory.items.noItemsMessage') }}
                  </p>
                </div>
              </td>
            </tr>
            <tr 
              v-else 
              v-for="item in paginatedItems" 
              :key="item.id" 
              class="hover:bg-gray-50 cursor-pointer"
              @click="handleRowClick(item, $event)"
            >
              <td class="px-6 py-4" @click.stop>
                <input 
                  type="checkbox" 
                  :value="item.id"
                  v-model="selectedItems"
                  class="item-checkbox rounded"
                  @click.stop
                >
              </td>
              <td class="px-6 py-4">
                <div class="font-medium text-gray-900">{{ item.name }}</div>
                <div v-if="item.nameLocalized" class="text-sm text-gray-500">{{ item.nameLocalized }}</div>
              </td>
              <td class="px-6 py-4 text-gray-700">{{ item.sku }}</td>
              <td class="px-6 py-4 text-gray-700">{{ item.category || $t('inventory.items.uncategorized') }}</td>
              <td class="px-6 py-4" @click.stop>
                <div class="relative">
                  <button @click.stop="toggleItemMenu(item.id)" class="text-gray-600 hover:text-gray-800">
                    <i class="fas fa-ellipsis-v"></i>
                  </button>
                  <div v-if="activeItemMenu === item.id" class="dropdown-menu" @click.stop>
                    <a @click.stop="viewItem(item.id)" class="cursor-pointer"><i class="fas fa-eye mr-2"></i>{{ $t('common.view') }}</a>
                    <a @click.stop="editItem(item)" class="cursor-pointer"><i class="fas fa-edit mr-2"></i>{{ $t('common.edit') }}</a>
                    <a v-if="activeTab === 'deleted'" href="#" @click.prevent.stop="restoreItem(item.id)"><i class="fas fa-undo mr-2"></i>{{ $t('inventory.suppliers.restore') }}</a>
                    <a v-else href="#" @click.prevent.stop="deleteItem(item.id)"><i class="fas fa-trash mr-2 text-red-600"></i>{{ $t('common.delete') }}</a>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Pagination -->
    <div class="mt-4 flex justify-between items-center">
      <div class="text-sm text-gray-600">
        Showing <span class="font-semibold">{{ showingFrom }}</span> to <span class="font-semibold">{{ showingTo }}</span> of <span class="font-semibold">{{ totalItems }}</span> items
      </div>
      <div class="flex gap-2">
        <button 
          @click="previousPage" 
          :disabled="currentPage === 1"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          <i class="fas fa-chevron-left"></i>
          <span>{{ $t('common.previous') }}</span>
        </button>
        <span class="px-4 py-2 text-gray-600">
          Page {{ currentPage }} of {{ totalPages }}
        </span>
        <button 
          @click="nextPage"
          :disabled="currentPage >= totalPages"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          <span>{{ $t('common.next') }}</span>
          <i class="fas fa-chevron-right"></i>
        </button>
      </div>
    </div>

    <!-- Create Item Modal (Complete form matching index.html) -->
    <div v-if="showCreateModal" class="modal show" @click.self="closeCreateItemModal">
      <div class="modal-content" style="max-width: 900px;">
        <div class="p-6">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-800">{{ $t('inventory.items.create') }}</h2>
            <button @click="closeCreateItemModal" class="text-gray-500 hover:text-gray-700 text-2xl">
              <i class="fas fa-times"></i>
            </button>
          </div>
          <form @submit.prevent="handleCreateItem">
            <div class="grid grid-cols-2 gap-4">
              <!-- Left Column -->
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.name') }} <span class="text-red-500">*</span>
                  </label>
                  <input v-model="newItem.name" type="text" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.sku') }} <span class="text-red-500">*</span> <span class="text-xs text-gray-500">({{ $t('inventory.items.autoGenerated') }})</span>
                  </label>
                  <input v-model="newItem.sku" type="text" required readonly placeholder="sk-19588" class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.storageUnit') }} <span class="text-red-500">*</span>
                  </label>
                  <input v-model="newItem.storageUnit" type="text" required placeholder="Pcs" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.storageToIngredient') }} <span class="text-red-500">*</span>
                  </label>
                  <input v-model.number="newItem.storageToIngredient" type="number" required placeholder="1" min="0" step="0.01" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.barcode') }}
                  </label>
                  <input v-model="newItem.barcode" type="text" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.minLevel') }}
                  </label>
                  <input v-model.number="newItem.minLevel" type="number" min="0" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.maximumLevel') }}
                  </label>
                  <input v-model="newItem.maxLevel" type="text" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
              </div>

              <!-- Right Column -->
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.nameLocalized') }}
                  </label>
                  <input v-model="newItem.nameLocalized" type="text" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.category') }}
                  </label>
                  <select v-model="newItem.category" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                    <option value="">{{ $t('inventory.purchaseOrders.choose') }}</option>
                    <option v-for="cat in categories" :key="cat.id" :value="cat.name">{{ cat.name }}</option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.ingredientUnit') }} <span class="text-red-500">*</span>
                  </label>
                  <input v-model="newItem.ingredientUnit" type="text" required placeholder="Pcs" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.costingMethod') }} <span class="text-red-500">*</span>
                  </label>
                  <select v-model="newItem.costingMethod" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                    <option value="">{{ $t('inventory.purchaseOrders.choose') }}</option>
                    <option value="From Transactions" selected>{{ $t('inventory.items.fromTransactions') }}</option>
                    <option value="Standard Cost">{{ $t('inventory.items.standardCost') }}</option>
                    <option value="Average Cost">{{ $t('inventory.items.averageCost') }}</option>
                    <option value="FIFO">FIFO</option>
                    <option value="LIFO">LIFO</option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.cost') }}
                  </label>
                  <input v-model.number="newItem.cost" type="number" min="0" step="0.01" placeholder="0.00" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.parLevel') }}
                  </label>
                  <input v-model="newItem.parLevel" type="text" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
              </div>
            </div>

            <!-- Advanced Options (Collapsible) -->
            <div v-if="showAdvancedOptions" class="mt-4 pt-4 border-t border-gray-200">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.factor') }}
                  </label>
                  <input v-model="newItem.factor" type="text" placeholder="1 Pcs = 1 Pcs" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    {{ $t('inventory.items.productionSection') }}
                  </label>
                  <select v-model="newItem.productionSection" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500">
                    <option value="">{{ $t('inventory.purchaseOrders.choose') }}</option>
                    <option value="Section A">{{ $t('inventory.items.sectionA') }}</option>
                    <option value="Section B">{{ $t('inventory.items.sectionB') }}</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Advanced Options Toggle -->
            <div class="mt-4">
              <a href="#" @click.prevent="showAdvancedOptions = !showAdvancedOptions" class="text-blue-600 hover:text-blue-800">
                {{ showAdvancedOptions ? $t('common.hide') : $t('inventory.items.advancedOptions') }}
              </a>
            </div>

            <!-- Modal Footer -->
            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
              <button type="button" @click="closeCreateItemModal" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
                {{ $t('common.close') }}
              </button>
              <button type="submit" class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
                {{ $t('common.save') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Advanced Filter Modal -->
    <div 
      v-if="showFilterModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeFilterModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <!-- Modal Header -->
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">{{ $t('common.filter') }}</h2>
          <button 
            @click="closeFilterModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <!-- Filter Form -->
        <div class="space-y-6">
          <!-- Text Inputs -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Name</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.name"
                  type="text"
                  placeholder="Search by name..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.nameMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">SKU</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.sku"
                  type="text"
                  placeholder="Search by SKU..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.skuMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Barcode</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.barcode"
                  type="text"
                  placeholder="Search by barcode..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.barcodeMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Updated After</label>
              <input 
                v-model="filterCriteria.updatedAfter"
                type="date"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>
          </div>

          <!-- Dropdown Selects -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Tag</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.tag"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option v-for="tag in availableTags" :key="tag" :value="tag">{{ tag }}</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.tagMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Category</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.category"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option v-for="cat in availableCategories" :key="cat" :value="cat">{{ cat }}</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.categoryMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Supplier</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.supplier"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option v-for="sup in availableSuppliers" :key="sup" :value="sup">{{ sup }}</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.supplierMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Costing Method</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.costingMethod"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option value="From Transactions">From Transactions</option>
                  <option value="Standard Cost">Standard Cost</option>
                  <option value="Average Cost">Average Cost</option>
                  <option value="FIFO">FIFO</option>
                  <option value="LIFO">LIFO</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.costingMethodMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Stock Product</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.stockProduct"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option value="yes">Yes</option>
                  <option value="no">No</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.stockProductMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Deleted</label>
              <div class="flex gap-2">
                <select 
                  v-model="tempFilterCriteria.deleted"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="">Any</option>
                  <option value="true">Deleted</option>
                  <option value="false">Not Deleted</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.deletedMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                    <option value="including">{{ $t('inventory.purchaseOrders.filter.including') }}</option>
                    <option value="excluding">{{ $t('inventory.purchaseOrders.filter.excluding') }}</option>
                </select>
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
            Clear
          </button>
          <div class="flex gap-3">
            <button 
              @click="closeFilterModal"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              @click="applyFilter"
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Import Modal -->
    <div 
      v-if="showImportModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeImportModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center pb-4 border-b mb-6">
          <h3 class="text-2xl font-bold text-gray-800">Upload a File</h3>
          <button 
            @click="closeImportModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="mb-6">
          <div class="bg-purple-50 border-l-4 border-purple-500 p-4 mb-4">
            <p class="text-sm text-purple-800 font-semibold">
              Make sure your file includes the following required columns:
            </p>
          </div>

          <!-- Required Columns List -->
          <div class="mb-6">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">REQUIRED COLUMNS</h3>
            <div class="grid grid-cols-2 gap-2 text-sm text-gray-600">
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Item Name</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>SKU</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Storage Unit</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Ingredient Unit</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Storage To Ingredient Conversion</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Cost</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Minimum Level</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>PAR Level</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-purple-500"></i>
                <span>Maximum Level</span>
              </div>
            </div>
          </div>

          <!-- Optional Columns List -->
          <div class="mb-6">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">OPTIONAL COLUMNS</h3>
            <div class="grid grid-cols-2 gap-2 text-sm text-gray-600">
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-gray-400"></i>
                <span>Inventory Item ID <span class="text-xs text-gray-500">(Auto-generated if not provided)</span></span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-gray-400"></i>
                <span>Name Localized</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-gray-400"></i>
                <span>Barcode</span>
              </div>
              <div class="flex items-center gap-2">
                <i class="fas fa-info-circle text-gray-400"></i>
                <span>Category Reference</span>
              </div>
            </div>
          </div>

          <!-- File Upload Area -->
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-4">
            <div class="flex flex-col items-center justify-center space-y-4">
              <div class="text-4xl mb-2">
                <i class="fas fa-file-excel text-green-600"></i>
                <i class="fas fa-file-csv text-blue-600 ml-2"></i>
              </div>
              <div>
                <p class="text-sm text-gray-600 mb-2">
                  What data do you want to upload? Upload a CSV or Excel file to begin the import process.
                </p>
                <input 
                  type="file"
                  @change="handleFileSelect"
                  accept=".xlsx,.xls,.csv"
                  class="hidden"
                  ref="fileInput"
                  id="import-file-input"
                >
                <label 
                  for="import-file-input"
                  class="inline-block px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 cursor-pointer"
                >
                  Choose File
                </label>
                <p v-if="importFile" class="text-sm text-gray-600 mt-2">
                  Selected: {{ importFile.name }}
                </p>
                <p v-else class="text-sm text-gray-500 mt-2">
                  No file chosen
                </p>
              </div>
            </div>
          </div>

          <div class="text-center">
            <button 
              @click="downloadExcelTemplate"
              class="text-purple-600 hover:text-purple-700 text-sm underline"
            >
              Download Excel template
            </button>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t">
          <button 
            @click="closeImportModal"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Cancel
          </button>
          <button 
            type="button"
            @click.prevent="handleImport"
            :disabled="!importFile"
            class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <i class="fas fa-upload"></i>
            Import
          </button>
        </div>
      </div>
    </div>

    <!-- Review & Finalize Modal -->
    <div 
      v-if="showReviewModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeReviewModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-[95vw] max-h-[95vh] flex flex-col">
        <!-- Modal Header -->
        <div class="flex justify-between items-center mb-4 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">Review & Finalize</h2>
          <button 
            @click="closeReviewModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>
        
        <!-- Summary -->
        <div class="mb-4 p-4 bg-gray-50 rounded-lg">
          <div class="flex items-center gap-6 text-sm font-semibold">
            <span>All rows: <strong class="text-gray-800">{{ reviewSummary.total }}</strong></span>
            <span class="text-green-600">Clean rows: <strong>{{ reviewSummary.clean }}</strong></span>
            <span class="text-red-600">Rows with issues: <strong>{{ reviewSummary.withIssues }}</strong></span>
          </div>
          <div v-if="reviewSummary.withIssues > 0" class="mt-2 text-xs text-red-600">
            ⚠️ Items with issues will be skipped during import. Only clean items will be imported.
          </div>
        </div>
        
        <!-- Table -->
        <div class="flex-1 overflow-y-auto border rounded-lg">
          <table class="w-full text-sm border-collapse">
            <thead class="bg-gray-100 sticky top-0 z-20">
              <tr>
                <th class="px-4 py-3 text-center border bg-gray-100 font-semibold text-gray-700 whitespace-nowrap" style="min-width: 80px;">Status</th>
                <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700 whitespace-nowrap" style="min-width: 200px;">Item Name</th>
                <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700 whitespace-nowrap" style="min-width: 200px;">Name Localized</th>
                <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700 whitespace-nowrap" style="min-width: 120px;">SKU</th>
                <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700 whitespace-nowrap" style="min-width: 120px;">Barcode</th>
                <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 250px;">Issues</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="(item, index) in paginatedReviewItems" 
                :key="index"
                :class="item.hasIssues ? 'bg-red-50 border-l-4 border-red-500' : ''"
              >
                <td class="px-4 py-2 text-center border align-middle">
                  <span v-if="item.hasIssues" class="text-red-600 font-bold text-lg">①</span>
                  <span v-else class="text-green-600">✓</span>
                </td>
                <td class="px-4 py-2 border align-middle" style="min-width: 200px;">{{ item.name || '' }}</td>
                <td class="px-4 py-2 border align-middle" style="min-width: 200px;">{{ item.name_localized || item.name || '' }}</td>
                <td class="px-4 py-2 font-mono text-sm border align-middle" :class="item.hasIssues ? 'text-red-600' : ''" style="min-width: 120px;">{{ item.sku || '' }}</td>
                <td class="px-4 py-2 border align-middle" style="min-width: 120px;">{{ item.barcode || '' }}</td>
                <td class="px-4 py-2 border align-middle" style="min-width: 250px;">
                  <div v-if="item.hasIssues" class="text-xs text-red-600">
                    {{ item.issues.slice(0, 3).join(', ') }}{{ item.issues.length > 3 ? '...' : '' }}
                  </div>
                  <span v-else class="text-green-600 text-xs">✓ Clean</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        
        <!-- Pagination Info -->
        <div class="text-sm text-gray-600 mt-2">
          Showing {{ ((currentReviewPage - 1) * reviewPageSize) + 1 }}-{{ Math.min(currentReviewPage * reviewPageSize, reviewItems.length) }} of {{ reviewItems.length }} items
        </div>
        
        <!-- Modal Footer -->
        <div class="flex justify-between items-center pt-4 border-t border-gray-200 mt-4">
          <button 
            @click="closeReviewModal"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Previous
          </button>
          <button 
            @click="finalizeImport"
            class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
          >
            Import
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { inventoryService } from '@/services/inventory';
import { loadItemsFromSupabase, supabaseClient, USE_SUPABASE } from '@/services/supabase';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';

const router = useRouter();
const { t, locale } = useI18n();

// State
const items = ref([]);
const loading = ref(false);
const activeTab = ref('all');
const selectedItems = ref([]);
const showImportExportMenu = ref(false);
const showBulkActionsMenu = ref(false);
const activeItemMenu = ref(null);
const showCreateModal = ref(false);
const currentPage = ref(1);
const limit = ref(50);

const newItem = ref({
  name: '',
  nameLocalized: '',
  sku: '',
  category: '',
  storageUnit: 'Pcs',
  ingredientUnit: 'Pcs',
  storageToIngredient: 1,
  costingMethod: 'From Transactions',
  cost: 0,
  barcode: '',
  minLevel: '',
  maxLevel: '',
  parLevel: '',
  productionSection: '',
  factor: '1 Pcs = 1 Pcs'
});

const showAdvancedOptions = ref(false);
const categories = ref([]);

// Tabs configuration
const tabs = computed(() => [
  { id: 'all', label: t('common.all') },
  { id: 'items', label: t('inventory.items.items') },
  { id: 'products', label: t('inventory.items.products') },
  { id: 'deleted', label: t('inventory.items.deleted') }
]);

// Computed
const filteredItems = computed(() => {
  // Ensure items is always an array
  if (!items.value || !Array.isArray(items.value)) {
    return [];
  }
  let filtered = items.value;
  
  // Apply tab filter first
  if (activeTab.value === 'deleted') {
    filtered = filtered.filter(item => item.deleted === true);
  } else if (activeTab.value === 'products') {
    // Products tab - show "Coming Soon" message (handled in template)
    return [];
  } else {
    filtered = filtered.filter(item => item.deleted !== true);
  }
  
  // Apply advanced filters with Including/Excluding logic
  if (filterCriteria.value.name) {
    const nameLower = filterCriteria.value.name.toLowerCase();
    const matches = (item) => 
      (item.name && item.name.toLowerCase().includes(nameLower)) ||
      (item.nameLocalized && item.nameLocalized.toLowerCase().includes(nameLower));
    
    if (filterCriteria.value.nameMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.sku) {
    const skuLower = filterCriteria.value.sku.toLowerCase();
    const matches = (item) => 
      item.sku && item.sku.toLowerCase().includes(skuLower);
    
    if (filterCriteria.value.skuMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.barcode) {
    const barcodeLower = filterCriteria.value.barcode.toLowerCase();
    const matches = (item) => 
      item.barcode && item.barcode.toLowerCase().includes(barcodeLower);
    
    if (filterCriteria.value.barcodeMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.category) {
    const matches = (item) => 
      item.category === filterCriteria.value.category;
    
    if (filterCriteria.value.categoryMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.tag) {
    const matches = (item) => 
      item.tags && Array.isArray(item.tags) && item.tags.includes(filterCriteria.value.tag);
    
    if (filterCriteria.value.tagMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.costingMethod) {
    const matches = (item) => 
      item.costing_method === filterCriteria.value.costingMethod ||
      item.costingMethod === filterCriteria.value.costingMethod;
    
    if (filterCriteria.value.costingMethodMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.deleted !== '') {
    const isDeleted = filterCriteria.value.deleted === 'true';
    const matches = (item) => item.deleted === isDeleted;
    
    if (filterCriteria.value.deletedMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(item => !matches(item));
    }
  }
  
  if (filterCriteria.value.updatedAfter) {
    const filterDate = new Date(filterCriteria.value.updatedAfter);
    filtered = filtered.filter(item => {
      const itemDate = new Date(item.updated_at || item.updatedAt || item.created_at || item.createdAt);
      return itemDate >= filterDate;
    });
  }
  
  return filtered;
});

// Paginated items (50 per page)
const paginatedItems = computed(() => {
  // Ensure filteredItems is always an array
  if (!filteredItems.value || !Array.isArray(filteredItems.value)) {
    return [];
  }
  const start = (currentPage.value - 1) * limit.value;
  const end = start + limit.value;
  return filteredItems.value.slice(start, end);
});

const allItemsSelected = computed(() => {
  return paginatedItems.value.length > 0 && 
         paginatedItems.value.every(item => selectedItems.value.includes(item.id));
});

const totalItems = computed(() => filteredItems.value.length);
const totalPages = computed(() => Math.ceil(totalItems.value / limit.value));
const showingFrom = computed(() => (currentPage.value - 1) * limit.value + 1);
const showingTo = computed(() => Math.min(currentPage.value * limit.value, totalItems.value));

// Methods
const loadItems = async () => {
  loading.value = true;
  try {
    // Load all items (pagination is client-side)
    const response = await inventoryService.getItems({
      deleted: activeTab.value === 'deleted'
    });
    // Handle both response formats: { data: [...] } or { data: { items: [...] } }
    if (response.data) {
      items.value = Array.isArray(response.data) ? response.data : (response.data.items || []);
    } else {
      items.value = [];
    }
  } catch (error) {
    console.error('Error loading items:', error);
    showNotification('Error loading items', 'error');
    // Ensure items is always an array even on error
    if (!items.value || !Array.isArray(items.value)) {
      items.value = [];
    }
  } finally {
    loading.value = false;
  }
};

const switchTab = (tabName) => {
  activeTab.value = tabName;
  selectedItems.value = [];
  currentPage.value = 1;
  loadItems();
};

const toggleSelectAll = () => {
  if (allItemsSelected.value) {
    selectedItems.value = [];
  } else {
    selectedItems.value = filteredItems.value.map(item => item.id);
  }
};

const toggleItemMenu = (itemId) => {
  activeItemMenu.value = activeItemMenu.value === itemId ? null : itemId;
};

const toggleImportExportMenu = () => {
  showImportExportMenu.value = !showImportExportMenu.value;
};

const toggleBulkActionsMenu = () => {
  showBulkActionsMenu.value = !showBulkActionsMenu.value;
};

const clearSelection = () => {
  selectedItems.value = [];
};

const openCreateItemModal = async () => {
  showCreateModal.value = true;
  showAdvancedOptions.value = false;
  await generateInventoryItemID();
  await generateSKU();
  await loadCategories();
};

const closeCreateItemModal = () => {
  showCreateModal.value = false;
  showAdvancedOptions.value = false;
  newItem.value = {
    name: '',
    nameLocalized: '',
    sku: '',
    category: '',
    storageUnit: 'Pcs',
    ingredientUnit: 'Pcs',
    storageToIngredient: 1,
    costingMethod: 'From Transactions',
    cost: 0,
    barcode: '',
    minLevel: '',
    maxLevel: '',
    parLevel: '',
    productionSection: '',
    factor: '1 Pcs = 1 Pcs',
    inventory_item_id: ''
  };
};

const generateSKU = async () => {
  try {
    const response = await inventoryService.getItems();
    const items = response.data?.items || response.data || [];
    let maxSKUNumber = 19587;
    
    items.forEach(item => {
      if (item.sku) {
        const match = item.sku.match(/sk-(\d+)/);
        if (match) {
          const num = parseInt(match[1]);
          if (num > maxSKUNumber) {
            maxSKUNumber = num;
          }
        }
      }
    });
    
    newItem.value.sku = `sk-${maxSKUNumber + 1}`;
  } catch (error) {
    console.error('Error generating SKU:', error);
    // Fallback: use timestamp-based SKU
    newItem.value.sku = `sk-${Date.now()}`;
  }
};

const generateInventoryItemID = async () => {
  try {
    let maxNumber = 0;
    
    if (USE_SUPABASE && supabaseClient) {
      try {
        const { data, error } = await supabaseClient
          .from('inventory_items')
          .select('inventory_item_id')
          .not('inventory_item_id', 'is', null);
        
        if (!error && data && data.length > 0) {
          data.forEach(item => {
            if (item.inventory_item_id) {
              const match = item.inventory_item_id.match(/SAK-FSID-(\d+)/);
              if (match) {
                const num = parseInt(match[1]);
                if (num > maxNumber) {
                  maxNumber = num;
                }
              }
            }
          });
        }
      } catch (e) {
        console.warn('Error fetching max ID from Supabase:', e);
      }
    } else {
      // Fallback: check from API
      try {
        const response = await inventoryService.getItems();
        const items = response.data?.items || response.data || [];
        items.forEach(item => {
          if (item.inventory_item_id || item.inventoryItemId) {
            const id = item.inventory_item_id || item.inventoryItemId;
            const match = id.match(/SAK-FSID-(\d+)/);
            if (match) {
              const num = parseInt(match[1]);
              if (num > maxNumber) {
                maxNumber = num;
              }
            }
          }
        });
      } catch (e) {
        console.warn('Error fetching max ID from API:', e);
      }
    }
    
    const nextNumber = maxNumber + 1;
    const nextID = `SAK-FSID-${String(nextNumber).padStart(5, '0')}`;
    newItem.value.inventory_item_id = nextID;
    console.log('Generated Inventory Item ID:', nextID);
  } catch (error) {
    console.error('Error generating Inventory Item ID:', error);
    // Fallback: use default
    newItem.value.inventory_item_id = 'SAK-FSID-00001';
  }
};

const loadCategories = async () => {
  try {
    const response = await inventoryService.getCategories(false);
    categories.value = response.data || [];
  } catch (error) {
    console.error('Error loading categories:', error);
    categories.value = [];
  }
};

const handleCreateItem = async () => {
  try {
    await inventoryService.createItem(newItem.value);
    showNotification('Item created successfully!', 'success');
    closeCreateItemModal();
    await loadItems();
  } catch (error) {
    showNotification(error.response?.data?.error || 'Error creating item', 'error');
  }
};

const deleteItem = async (itemId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Item',
    message: 'Are you sure you want to delete this item?',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    await inventoryService.deleteItem(itemId);
    showNotification('Item deleted successfully', 'success');
    await loadItems();
  } catch (error) {
    showNotification(error.response?.data?.error || 'Error deleting item', 'error');
  }
};

const restoreItem = async (itemId) => {
  try {
    await inventoryService.restoreItem(itemId);
    showNotification('Item restored successfully', 'success');
    await loadItems();
  } catch (error) {
    showNotification(error.response?.data?.error || 'Error restoring item', 'error');
  }
};

const handleRowClick = (item, event) => {
  // Don't navigate if clicking on checkbox, actions menu, or dropdown
  if (event.target.closest('.item-checkbox') || 
      event.target.closest('.dropdown-menu') || 
      event.target.closest('button') ||
      event.target.closest('input')) {
    return;
  }
  // Navigate to item detail page
  viewItem(item.id);
};

const viewItem = (itemId) => {
  router.push(`/homeportal/item-detail/${itemId}`);
};

const editItem = (item) => {
  router.push(`/homeportal/item-detail/${item.id}?edit=true`);
};

const bulkDeleteItems = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Items',
    message: `Are you sure you want to delete ${selectedItems.value.length} item(s)?`,
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    await Promise.all(selectedItems.value.map(id => inventoryService.deleteItem(id)));
    showNotification(`${selectedItems.value.length} items deleted successfully`, 'success');
    selectedItems.value = [];
    await loadItems();
  } catch (error) {
    showNotification('Error deleting items', 'error');
  }
};

const bulkRestoreItems = async () => {
  if (selectedItems.value.length === 0) {
    showNotification('Please select items to restore', 'warning');
    return;
  }
  
  try {
    const results = await Promise.allSettled(
      selectedItems.value.map(id => inventoryService.restoreItem(id))
    );
    
    const successful = results.filter(r => r.status === 'fulfilled' && r.value?.success).length;
    const failed = results.filter(r => r.status === 'rejected' || !r.value?.success).length;
    
    if (successful > 0) {
      showNotification(`${successful} item(s) restored successfully${failed > 0 ? `, ${failed} failed` : ''}`, 'success');
      selectedItems.value = [];
      await loadItems();
    } else {
      const errorMsg = results.find(r => r.status === 'rejected' || r.value?.error)?.value?.error || results.find(r => r.status === 'rejected')?.reason?.message || 'Error restoring items';
      showNotification(errorMsg, 'error');
    }
  } catch (error) {
    console.error('Bulk restore error:', error);
    showNotification(error.response?.data?.error || error.message || 'Error restoring items', 'error');
  }
};

const bulkAddTags = () => {
  console.log('Bulk add tags');
};

const bulkRemoveTags = () => {
  console.log('Bulk remove tags');
};

const bulkChangeCategory = () => {
  console.log('Bulk change category');
};

const showImportModal = ref(false);
const showReviewModal = ref(false);
const importFile = ref(null);
const fileInput = ref(null);
const itemsToImport = ref([]);
const reviewItems = ref([]);
const reviewSummary = ref({
  total: 0,
  clean: 0,
  withIssues: 0
});
const currentReviewPage = ref(1);
const reviewPageSize = ref(100);

const exportItems = async () => {
  try {
    // Get all items from API
    const response = await inventoryService.getItems();
    const items = response.data || [];
    
    if (items.length === 0) {
      showNotification('No items to export', 'warning');
      return;
    }
    
    // Create workbook
    const wb = XLSX.utils.book_new();
    const wsData = [
      ['Inventory Item ID', 'Item Name', 'Name Localized', 'SKU', 'Barcode', 'Storage Unit', 'Ingredient Unit', 'Storage To Ingredient Conversion', 'Cost', 'Minimum Level', 'PAR Level', 'Maximum Level', 'Category Reference']
    ];
    
    items.forEach(item => {
      wsData.push([
        item.inventory_item_id || item.inventoryItemId || '',
        item.name || '',
        item.nameLocalized || item.name || '',
        item.sku || '',
        item.barcode || '',
        item.storageUnit || item.storage_unit || '',
        item.ingredientUnit || item.ingredient_unit || '',
        item.storageToIngredient || item.storage_to_ingredient || 1,
        item.cost || 0,
        item.minLevel || item.min_level || '',
        item.parLevel || item.par_level || '',
        item.maxLevel || item.max_level || '',
        item.category || ''
      ]);
    });
    
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    XLSX.utils.book_append_sheet(wb, ws, 'Items');
    
    // Download
    const fileName = `Inventory_Items_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(wb, fileName);
    
    showNotification(`Successfully exported ${items.length} item(s)!`, 'success');
  } catch (error) {
    console.error('Error exporting items:', error);
    showNotification('Error exporting items. Please try again.', 'error');
  }
};

const openImportModal = () => {
  showImportModal.value = true;
};

const closeImportModal = () => {
  showImportModal.value = false;
  importFile.value = null;
};

const handleFileSelect = (event) => {
  const file = event.target.files[0];
  if (file) {
    importFile.value = file;
  }
};

const handleImport = async () => {
  console.log('handleImport called', importFile.value);
  
  if (!importFile.value) {
    showNotification('Please select a file', 'warning');
    return;
  }
  
  const fileName = importFile.value.name.toLowerCase();
  if (!fileName.endsWith('.xlsx') && !fileName.endsWith('.xls') && !fileName.endsWith('.csv')) {
    showNotification('Please upload an Excel file (.xlsx, .xls) or CSV file.', 'warning');
    return;
  }
  
  try {
    console.log('Starting file read...');
    const reader = new FileReader();
    
    reader.onerror = (error) => {
      console.error('FileReader error:', error);
      showNotification('Error reading file. Please try again.', 'error', 5000);
    };
    
    reader.onload = async (e) => {
      try {
        console.log('File read successfully, processing...');
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        
        // Get first sheet
        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        
        // Convert to JSON
        const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
        
        if (jsonData.length < 2) {
          showNotification('Excel file is empty or has no data rows.', 'warning');
          return;
        }
        
        // Get headers (first row)
        const headers = jsonData[0].map(h => String(h).trim());
        
        // Validate required columns (Inventory Item ID is optional - will be auto-generated)
        const requiredColumns = [
          'Item Name',
          'SKU',
          'Storage Unit',
          'Ingredient Unit',
          'Storage To Ingredient Conversion',
          'Cost',
          'Minimum Level',
          'PAR Level',
          'Maximum Level'
        ];
        
        const missingColumns = requiredColumns.filter(col => !headers.includes(col));
        if (missingColumns.length > 0) {
          showNotification(`Missing required columns: ${missingColumns.join(', ')}. Please download the template and use it for import.`, 'error', 6000);
          return;
        }
        
        // Process data rows (skip header row)
        const itemsToImportList = [];
        for (let i = 1; i < jsonData.length; i++) {
          const row = jsonData[i];
          if (!row || row.length === 0) continue;
          
          // Create item object from row
          const item = {};
          headers.forEach((header, index) => {
            const value = row[index];
            if (value !== undefined && value !== null && value !== '') {
              // Map Excel headers to database fields
              switch(header) {
                case 'Inventory Item ID':
                  item.inventory_item_id = String(value).trim();
                  break;
                case 'Item Name':
                  item.name = String(value).trim();
                  break;
                case 'Name Localized':
                  item.name_localized = String(value).trim();
                  break;
                case 'SKU':
                  item.sku = String(value).trim();
                  break;
                case 'Barcode':
                  item.barcode = String(value).trim();
                  break;
                case 'Storage Unit':
                  item.storage_unit = String(value).trim();
                  break;
                case 'Ingredient Unit':
                  item.ingredient_unit = String(value).trim();
                  break;
                case 'Storage To Ingredient Conversion':
                  const conversionValue = parseFloat(value);
                  item.storage_to_ingredient = (conversionValue && conversionValue > 0) ? conversionValue : 1;
                  break;
                case 'Cost':
                  const costValue = parseFloat(value);
                  item.cost = (costValue && costValue >= 0) ? costValue : 0;
                  break;
                case 'Minimum Level':
                  item.min_level = String(value).trim();
                  break;
                case 'PAR Level':
                  item.par_level = String(value).trim();
                  break;
                case 'Maximum Level':
                  item.max_level = String(value).trim();
                  break;
                case 'Category Reference':
                  item.category = String(value).trim();
                  break;
              }
            }
          });
          
          // Validate required fields
          if (item.name && item.sku && item.storage_unit && item.ingredient_unit) {
            // Set defaults
            if (item.inventory_item_id && item.inventory_item_id.trim() !== '') {
              // Validate format (SAK-FSID-00001)
              const idPattern = /^SAK-FSID-\d{5}$/;
              if (!idPattern.test(item.inventory_item_id.trim())) {
                console.warn(`Invalid Inventory Item ID format: ${item.inventory_item_id}, will generate new one`);
                item.inventory_item_id = null;
              } else {
                item.inventory_item_id = item.inventory_item_id.trim();
              }
            } else {
              item.inventory_item_id = null;
            }
            if (!item.name_localized) {
              item.name_localized = item.name;
            }
            if (!item.storage_to_ingredient || item.storage_to_ingredient <= 0) {
              item.storage_to_ingredient = 1;
            }
            if (item.cost === undefined || item.cost === null || item.cost < 0) {
              item.cost = 0;
            }
            if (!item.costing_method) {
              item.costing_method = 'From Transactions';
            }
            if (!item.category) {
              item.category = 'Uncategorized';
            }
            
            // Set defaults for JSONB fields
            item.tags = [];
            item.ingredients = [];
            item.suppliers = [];
            item.deleted = false;
            
            itemsToImportList.push(item);
          }
        }
        
        if (itemsToImportList.length === 0) {
          showNotification('No valid items found in the Excel file. Please check the data.', 'warning');
          return;
        }
        
        // Generate Inventory Item IDs for items that don't have one
        let currentMaxID = 0;
        if (USE_SUPABASE && supabaseClient) {
          try {
            const { data } = await supabaseClient
              .from('inventory_items')
              .select('inventory_item_id')
              .not('inventory_item_id', 'is', null);
            
            if (data && data.length > 0) {
              data.forEach(item => {
                if (item.inventory_item_id) {
                  const match = item.inventory_item_id.match(/SAK-FSID-(\d+)/);
                  if (match) {
                    const num = parseInt(match[1]);
                    if (num > currentMaxID) {
                      currentMaxID = num;
                    }
                  }
                }
              });
            }
          } catch (e) {
            console.warn('Error fetching max ID:', e);
          }
        }
        
        // Generate IDs sequentially for items that need them
        for (let i = 0; i < itemsToImportList.length; i++) {
          if (!itemsToImportList[i].inventory_item_id || itemsToImportList[i].inventory_item_id.trim() === '') {
            currentMaxID++;
            itemsToImportList[i].inventory_item_id = `SAK-FSID-${String(currentMaxID).padStart(5, '0')}`;
          }
        }
        
        // Show Review Data screen
        console.log('Items processed, showing review screen...', itemsToImportList.length);
        await showReviewDataScreen(itemsToImportList);
        
      } catch (error) {
        console.error('Error processing file:', error);
        showNotification('Error processing file: ' + (error.message || 'Unknown error'), 'error', 5000);
      }
    };
    
    console.log('Reading file as ArrayBuffer...');
    reader.readAsArrayBuffer(importFile.value);
  } catch (error) {
    console.error('Error importing items:', error);
    showNotification('Error importing items: ' + (error.message || 'Unknown error'), 'error', 5000);
  }
};

// Review & Finalize Functions
const showReviewDataScreen = async (items) => {
  // Close import modal
  closeImportModal();
  
  // Validate items and find issues
  const validatedItems = items.map((item, index) => {
    const issues = [];
    
    // Check for duplicate SKUs in import batch
    if (item.sku && item.sku.trim() !== '') {
      const duplicateSKU = items.filter((it, idx) => idx !== index && it.sku && it.sku.trim() === item.sku.trim());
      if (duplicateSKU.length > 0) {
        issues.push('Duplicate SKU in import file');
      }
    }
    
    // Check for duplicate Inventory Item IDs in import batch
    if (item.inventory_item_id && item.inventory_item_id.trim() !== '') {
      const duplicateID = items.filter((it, idx) => idx !== index && it.inventory_item_id && it.inventory_item_id.trim() === item.inventory_item_id.trim());
      if (duplicateID.length > 0) {
        issues.push('Duplicate Inventory Item ID in import file');
      }
    }
    
    // Validate required fields
    if (!item.name || item.name.trim() === '') {
      issues.push('Item Name is required');
    }
    if (!item.sku || item.sku.trim() === '') {
      issues.push('SKU is required');
    }
    if (!item.storage_unit || item.storage_unit.trim() === '') {
      issues.push('Storage Unit is required');
    }
    if (!item.ingredient_unit || item.ingredient_unit.trim() === '') {
      issues.push('Ingredient Unit is required');
    }
    if (!item.storage_to_ingredient || item.storage_to_ingredient <= 0) {
      issues.push('Storage To Ingredient Conversion must be greater than 0');
    }
    
    // Validate Inventory Item ID format
    if (item.inventory_item_id && item.inventory_item_id.trim() !== '') {
      const idPattern = /^SAK-FSID-\d{5}$/;
      if (!idPattern.test(item.inventory_item_id.trim())) {
        issues.push('Invalid Inventory Item ID format (should be SAK-FSID-00001)');
      }
    }
    
    return {
      ...item,
      rowNumber: index + 2, // Excel row number (header is row 1)
      issues: issues,
      hasIssues: issues.length > 0
    };
  });
  
  // Check for existing SKUs and IDs in database
  const validatedWithDB = await validateAgainstDatabase(validatedItems);
  
  // Store validated items for import
  itemsToImport.value = validatedWithDB;
  
  // Update review summary
  reviewSummary.value = {
    total: validatedWithDB.length,
    clean: validatedWithDB.filter(item => !item.hasIssues).length,
    withIssues: validatedWithDB.filter(item => item.hasIssues).length
  };
  
  // Set review items
  reviewItems.value = validatedWithDB;
  currentReviewPage.value = 1;
  
  // Show review modal
  showReviewModal.value = true;
};

// Validate against database (check for duplicates)
const validateAgainstDatabase = async (items) => {
  if (!USE_SUPABASE || !supabaseClient) {
    return items;
  }
  
  try {
    // Get existing SKUs and Inventory Item IDs
    const { data: existingItems, error: fetchError } = await supabaseClient
      .from('inventory_items')
      .select('sku, inventory_item_id');
    
    if (fetchError) {
      console.error('Error fetching existing items for validation:', fetchError);
      return items; // Return items without DB validation if fetch fails
    }
    
    const existingSKUs = new Set(existingItems?.map(item => item.sku).filter(sku => sku) || []);
    const existingIDs = new Set(existingItems?.map(item => item.inventory_item_id).filter(id => id) || []);
    
    // Add database validation issues
    return items.map(item => {
      const newIssues = [...(item.issues || [])];
      
      if (item.sku && item.sku.trim() !== '' && existingSKUs.has(item.sku.trim())) {
        newIssues.push('SKU already exists in database');
      }
      
      if (item.inventory_item_id && item.inventory_item_id.trim() !== '' && existingIDs.has(item.inventory_item_id.trim())) {
        newIssues.push('Item ID already exists in database');
      }
      
      return {
        ...item,
        issues: newIssues,
        hasIssues: newIssues.length > 0
      };
    });
  } catch (error) {
    console.error('Error validating against database:', error);
    return items;
  }
};

// Paginated review items
const paginatedReviewItems = computed(() => {
  const start = (currentReviewPage.value - 1) * reviewPageSize.value;
  const end = start + reviewPageSize.value;
  return reviewItems.value.slice(start, end);
});

// Close review modal
const closeReviewModal = () => {
  showReviewModal.value = false;
  reviewItems.value = [];
  itemsToImport.value = [];
  currentReviewPage.value = 1;
  // Reopen import modal
  showImportModal.value = true;
};

// Finalize Import (after review)
const finalizeImport = async () => {
  const items = itemsToImport.value;
  if (!items || items.length === 0) {
    showNotification('No items to import.', 'warning', 3000);
    return;
  }
  
  // Filter out items with issues
  const cleanItems = items.filter(item => !item.hasIssues);
  const itemsWithIssues = items.filter(item => item.hasIssues);
  
  if (cleanItems.length === 0) {
    showNotification('No clean items to import. Please fix the issues first.', 'warning', 4000);
    return;
  }
  
  if (itemsWithIssues.length > 0) {
    const confirmMsg = `You have ${itemsWithIssues.length} item(s) with issues that will be skipped.\n\nOnly ${cleanItems.length} clean item(s) will be imported.\n\nDo you want to continue?`;
    const { showConfirmDialog } = await import('@/utils/confirmDialog');
    const confirmed = await showConfirmDialog({
      title: 'Finalize Import',
      message: confirmMsg,
      confirmText: 'Yes, Import',
      cancelText: 'Cancel',
      type: 'info',
      icon: 'fas fa-check-circle'
    });
    if (!confirmed) {
      return;
    }
  }
  
  // Import clean items
  await importItemsToSupabase(cleanItems);
  
  // Close review modal
  closeReviewModal();
};

// Import items to Supabase (Final import after review)
const importItemsToSupabase = async (items) => {
  if (!USE_SUPABASE || !supabaseClient) {
    showNotification('Supabase not configured. Please refresh the page.', 'error', 5000);
    return;
  }
  
  try {
    // Import items in batches to avoid timeout
    const batchSize = 50;
    let successCount = 0;
    let errorCount = 0;
    const errors = [];
    
    for (let i = 0; i < items.length; i += batchSize) {
      const batch = items.slice(i, i + batchSize);
      
      // Remove validation metadata before inserting
      const batchToInsert = batch.map(item => {
        const { rowNumber, issues, hasIssues, ...itemData } = item;
        
        // Ensure all required fields are present and valid
        if (!itemData.name || itemData.name.trim() === '') {
          throw new Error(`Item at row ${item.rowNumber} missing name`);
        }
        if (!itemData.sku || itemData.sku.trim() === '') {
          throw new Error(`Item at row ${item.rowNumber} missing SKU`);
        }
        if (!itemData.storage_unit || itemData.storage_unit.trim() === '') {
          throw new Error(`Item at row ${item.rowNumber} missing Storage Unit`);
        }
        if (!itemData.ingredient_unit || itemData.ingredient_unit.trim() === '') {
          throw new Error(`Item at row ${item.rowNumber} missing Ingredient Unit`);
        }
        if (!itemData.inventory_item_id || itemData.inventory_item_id.trim() === '') {
          throw new Error(`Item at row ${item.rowNumber} missing Inventory Item ID`);
        }
        
        // Set defaults
        if (!itemData.name_localized) {
          itemData.name_localized = itemData.name;
        }
        if (!itemData.storage_to_ingredient || itemData.storage_to_ingredient <= 0) {
          itemData.storage_to_ingredient = 1;
        }
        if (itemData.cost === undefined || itemData.cost === null) {
          itemData.cost = 0;
        }
        if (!itemData.costing_method) {
          itemData.costing_method = 'From Transactions';
        }
        if (!itemData.category) {
          itemData.category = 'Uncategorized';
        }
        if (!itemData.tags) {
          itemData.tags = [];
        }
        if (!itemData.ingredients) {
          itemData.ingredients = [];
        }
        if (!itemData.suppliers) {
          itemData.suppliers = [];
        }
        itemData.deleted = false;
        
        return itemData;
      });
      
      const { data, error } = await supabaseClient
        .from('inventory_items')
        .insert(batchToInsert)
        .select();
      
      if (error) {
        console.error('Error importing batch:', error);
        console.error('Batch data:', batchToInsert);
        errorCount += batch.length;
        errors.push({
          batch: Math.floor(i / batchSize) + 1,
          error: error.message,
          details: error.details || '',
          hint: error.hint || '',
          items: batch.map(item => `${item.name || 'Unknown'} (${item.sku || 'No SKU'})`).join(', ')
        });
      } else {
        successCount += data ? data.length : 0;
      }
    }
    
    if (successCount > 0) {
      let message = `✅ Successfully imported ${successCount} item(s)!`;
      if (errorCount > 0) {
        message += `\n\n⚠️ ${errorCount} item(s) failed to import.`;
        if (errors.length > 0) {
          console.error('Import errors:', errors);
        }
      }
      showNotification(message, 'success', 5000);
      closeReviewModal();
      // Reload items table
      await loadItems();
    } else {
      let errorMsg = `❌ Failed to import items. ${errorCount > 0 ? errorCount + ' item(s) failed.' : ''}`;
      if (errors.length > 0) {
        const uniqueErrors = [...new Set(errors.map(e => e.error))];
        errorMsg += '\n\nCommon errors:\n' + uniqueErrors.slice(0, 5).map(e => `- ${e}`).join('\n');
        if (errors[0].hint) {
          errorMsg += '\n\nHint: ' + errors[0].hint;
        }
        errorMsg += '\n\nPlease check the browser console for detailed error information.';
      }
      showNotification(errorMsg.replace(/\n\n/g, '. '), 'error', 8000);
      console.error('Import errors (detailed):', errors);
    }
    
  } catch (error) {
    console.error('Error importing items:', error);
    showNotification('Error importing items: ' + error.message, 'error', 5000);
  }
};

const downloadExcelTemplate = () => {
  // Create template workbook
  const wb = XLSX.utils.book_new();
  const wsData = [
    ['Inventory Item ID', 'Item Name', 'Name Localized', 'SKU', 'Barcode', 'Storage Unit', 'Ingredient Unit', 'Storage To Ingredient Conversion', 'Cost', 'Minimum Level', 'PAR Level', 'Maximum Level', 'Category Reference'],
    ['ITEM001', 'Sample Item', 'Sample Item (AR)', 'SKU001', '123456789', 'kg', 'g', '1000', '10.50', '100', '200', '500', 'Category1']
  ];
  
  const ws = XLSX.utils.aoa_to_sheet(wsData);
  XLSX.utils.book_append_sheet(wb, ws, 'Template');
  
  // Download
  XLSX.writeFile(wb, 'Inventory_Items_Import_Template.xlsx');
  showNotification('Template downloaded successfully!', 'success');
};

const bulkExportItems = async () => {
  if (selectedItems.value.length === 0) {
    showNotification('Please select items to export.', 'warning');
    return;
  }
  
  try {
    // Get selected items
    const itemsToExport = items.value.filter(item => selectedItems.value.includes(item.id));
    
    if (itemsToExport.length === 0) {
      showNotification('No items found to export.', 'warning');
      return;
    }
    
    // Create workbook
    const wb = XLSX.utils.book_new();
    const wsData = [
      ['Inventory Item ID', 'Item Name', 'Name Localized', 'SKU', 'Barcode', 'Storage Unit', 'Ingredient Unit', 'Storage To Ingredient Conversion', 'Cost', 'Minimum Level', 'PAR Level', 'Maximum Level', 'Category Reference']
    ];
    
    itemsToExport.forEach(item => {
      wsData.push([
        item.inventoryItemId || '',
        item.name || '',
        item.nameLocalized || item.name || '',
        item.sku || '',
        item.barcode || '',
        item.storageUnit || '',
        item.ingredientUnit || '',
        item.storageToIngredient || 1,
        item.cost || 0,
        item.minLevel || '',
        item.parLevel || '',
        item.maxLevel || '',
        item.category || ''
      ]);
    });
    
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    XLSX.utils.book_append_sheet(wb, ws, 'Selected Items');
    
    // Download
    const fileName = `Selected_Items_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(wb, fileName);
    
    showNotification(`Successfully exported ${itemsToExport.length} item(s)!`, 'success');
    selectedItems.value = [];
  } catch (error) {
    console.error('Error exporting items:', error);
    showNotification('Error exporting items. Please try again.', 'error');
  }
};

const showFilterModal = ref(false);
// Active filter criteria (applied filters)
const filterCriteria = ref({
  name: '',
  nameMode: 'including', // 'including' or 'excluding'
  sku: '',
  skuMode: 'including',
  barcode: '',
  barcodeMode: 'including',
  tag: '',
  tagMode: 'including',
  category: '',
  categoryMode: 'including',
  supplier: '',
  supplierMode: 'including',
  costingMethod: '',
  costingMethodMode: 'including',
  stockProduct: '',
  stockProductMode: 'including',
  deleted: '',
  deletedMode: 'including',
  updatedAfter: ''
});

// Temporary filter criteria (for modal inputs - not applied until Apply is clicked)
const tempFilterCriteria = ref({
  name: '',
  nameMode: 'including',
  sku: '',
  skuMode: 'including',
  barcode: '',
  barcodeMode: 'including',
  tag: '',
  tagMode: 'including',
  category: '',
  categoryMode: 'including',
  supplier: '',
  supplierMode: 'including',
  costingMethod: '',
  costingMethodMode: 'including',
  stockProduct: '',
  stockProductMode: 'including',
  deleted: '',
  deletedMode: 'including',
  updatedAfter: ''
});

const openFilter = () => {
  // Copy current filter criteria to temp when opening modal
  tempFilterCriteria.value = JSON.parse(JSON.stringify(filterCriteria.value));
  showFilterModal.value = true;
};

const closeFilterModal = () => {
  showFilterModal.value = false;
};

const applyFilter = () => {
  // Copy temp filter criteria to actual filter criteria when Apply is clicked
  filterCriteria.value = JSON.parse(JSON.stringify(tempFilterCriteria.value));
  currentPage.value = 1; // Reset to first page
  closeFilterModal();
};

const clearFilter = () => {
  const emptyFilter = {
    name: '',
    nameMode: 'including',
    sku: '',
    skuMode: 'including',
    barcode: '',
    barcodeMode: 'including',
    tag: '',
    tagMode: 'including',
    category: '',
    categoryMode: 'including',
    supplier: '',
    supplierMode: 'including',
    costingMethod: '',
    costingMethodMode: 'including',
    stockProduct: '',
    stockProductMode: 'including',
    deleted: '',
    deletedMode: 'including',
    updatedAfter: ''
  };
  filterCriteria.value = JSON.parse(JSON.stringify(emptyFilter));
  tempFilterCriteria.value = JSON.parse(JSON.stringify(emptyFilter));
  currentPage.value = 1;
  if (showFilterModal.value) {
    closeFilterModal();
  }
};

// Check if any filters are active
const hasActiveFilters = computed(() => {
  return !!(
    filterCriteria.value.name ||
    filterCriteria.value.sku ||
    filterCriteria.value.barcode ||
    filterCriteria.value.tag ||
    filterCriteria.value.category ||
    filterCriteria.value.supplier ||
    filterCriteria.value.costingMethod ||
    filterCriteria.value.stockProduct ||
    filterCriteria.value.deleted !== '' ||
    filterCriteria.value.updatedAfter
  );
});

// Count active filters
const activeFiltersCount = computed(() => {
  let count = 0;
  if (filterCriteria.value.name) count++;
  if (filterCriteria.value.sku) count++;
  if (filterCriteria.value.barcode) count++;
  if (filterCriteria.value.tag) count++;
  if (filterCriteria.value.category) count++;
  if (filterCriteria.value.supplier) count++;
  if (filterCriteria.value.costingMethod) count++;
  if (filterCriteria.value.stockProduct) count++;
  if (filterCriteria.value.deleted !== '') count++;
  if (filterCriteria.value.updatedAfter) count++;
  return count;
});

const previousPage = () => {
  if (currentPage.value > 1) {
    currentPage.value--;
    // Scroll to top when changing page
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

const nextPage = () => {
  if (currentPage.value < totalPages.value) {
    currentPage.value++;
    // Scroll to top when changing page
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

const showNotification = (message, type = 'success') => {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 z-[10000] px-6 py-3 rounded-lg shadow-lg flex items-center gap-2 animate-slide-in`;
  
  // Set colors based on type
  const colors = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-yellow-500 text-white',
    info: 'bg-blue-500 text-white'
  };
  
  notification.className += ' ' + (colors[type] || colors.success);
  
  const icons = {
    success: 'fa-check-circle',
    error: 'fa-exclamation-circle',
    warning: 'fa-exclamation-triangle',
    info: 'fa-info-circle'
  };
  
  notification.innerHTML = `
    <i class="fas ${icons[type] || icons.success}"></i>
    <span>${message}</span>
  `;
  
  document.body.appendChild(notification);
  
  // Remove after 3 seconds
  setTimeout(() => {
    notification.style.opacity = '0';
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    }, 300);
  }, 3000);
};

// Lifecycle
onMounted(() => {
  const route = useRoute();
  console.log('🟢 [Items.vue] Component MOUNTED', {
    fullPath: route.fullPath,
    path: route.path,
    name: route.name,
    matched: route.matched.map(r => ({ path: r.path, name: r.name })),
    params: route.params
  });
  loadItems();
  loadCategories();
});
</script>

<style scoped>
.tab-button.active {
  border-bottom: 2px solid #284b44;
  color: #284b44;
  font-weight: 600;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 4px;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  z-index: 10;
  min-width: 200px;
}

.dropdown-menu a {
  display: block;
  padding: 12px 16px;
  color: #374151;
  text-decoration: none;
  transition: background-color 0.2s;
}

.dropdown-menu a:hover {
  background-color: #f3f4f6;
}
</style>

