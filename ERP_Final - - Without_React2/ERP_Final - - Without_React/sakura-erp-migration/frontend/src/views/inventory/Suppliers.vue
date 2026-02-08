<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.suppliers.title') }}</h1>
          <i class="fas fa-question-circle text-purple-500 cursor-pointer"></i>
        </div>
        <div class="flex items-center gap-3">
          <div class="relative" @click.stop>
            <button 
              @click.stop="toggleImportExportMenu"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            >
              <i class="fas fa-cloud"></i>
              <span>{{ $t('inventory.suppliers.importExport') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showImportExportMenu" class="dropdown-menu" @click.stop>
              <a href="#" @click.prevent.stop="handleExportClick"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('common.export') }}</a>
              <a href="#" @click.prevent.stop="handleImportClick"><i class="fas fa-upload mr-2 text-[#284b44]"></i>{{ $t('common.import') }}</a>
              <a href="#" @click.prevent.stop="handleDownloadTemplateClick"><i class="fas fa-file-excel mr-2 text-green-600"></i>{{ $t('inventory.suppliers.downloadExcelTemplate') }}</a>
            </div>
          </div>
          <button 
            @click="openCreateSupplierModal"
            class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2"
          >
            <i class="fas fa-plus"></i>
            <span>{{ $t('inventory.suppliers.add') }}</span>
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
            @click="switchTab('deleted')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'deleted' }]"
          >
            {{ $t('inventory.suppliers.deleted') }}
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
    <div v-if="selectedSuppliers.length > 0" class="bg-yellow-50 border border-yellow-200 rounded-lg shadow-md p-4 mb-4" style="position: relative; z-index: 10;">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-4">
          <span class="font-semibold text-gray-700">{{ selectedSuppliers.length }} {{ $t('common.selected') }}</span>
          <div class="relative" @click.stop style="z-index: 1000;">
            <button @click.stop="toggleBulkActionsMenu" class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2 cursor-pointer">
              <i class="fas fa-tasks"></i>
              <span>{{ $t('common.actions') }}</span>
              <i class="fas fa-chevron-down text-xs"></i>
            </button>
            <div v-if="showBulkActionsMenu" class="dropdown-menu" style="pointer-events: auto; z-index: 1001;">
              <a v-if="activeTab === 'deleted'" href="#" @click.stop.prevent="bulkRestoreSuppliers" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-undo mr-2 text-green-600"></i>{{ $t('inventory.suppliers.bulkRestore') }}</a>
              <a v-else href="#" @click.stop.prevent="bulkDeleteSuppliers" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-trash mr-2 text-red-600"></i>{{ $t('common.delete') }}</a>
              <a href="#" @click.stop.prevent="bulkAddTags" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-tags mr-2 text-[#284b44]"></i>{{ $t('inventory.suppliers.addTags') }}</a>
              <a href="#" @click.stop.prevent="bulkRemoveTags" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-tag mr-2 text-orange-600"></i>{{ $t('inventory.suppliers.removeTags') }}</a>
              <a href="#" @click.stop.prevent="bulkExportSuppliers" class="cursor-pointer" style="pointer-events: auto;"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.purchaseOrders.exportSelected') }}</a>
            </div>
          </div>
        </div>
        <button @click="clearSelection" class="text-gray-600 hover:text-gray-800">
          <i class="fas fa-times"></i> {{ $t('inventory.grn.filter.clearSelection') }}
        </button>
      </div>
    </div>

    <!-- Suppliers Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-4 text-left">
              <input 
                type="checkbox" 
                :checked="allSuppliersSelected"
                @change="toggleSelectAll"
                class="rounded"
              >
            </th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.suppliers.name') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.suppliers.code') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('inventory.suppliers.contact') }}</th>
            <th :class="['px-6 py-4 text-sm font-semibold text-gray-700', textAlign]">{{ $t('common.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="5" class="px-6 py-12">
              <div class="flex flex-col items-center justify-center">
                <i class="fas fa-spinner fa-spin text-4xl text-purple-500 mb-4"></i>
                <p class="text-gray-600">{{ $t('inventory.suppliers.loadingSuppliers') }}</p>
              </div>
            </td>
          </tr>
          <tr v-else-if="!paginatedSuppliers || paginatedSuppliers.length === 0" class="text-center">
            <td colspan="5" class="px-6 py-12">
              <div class="flex flex-col items-center justify-center">
                <div class="text-6xl mb-4">📦</div>
                <h3 class="text-2xl font-bold text-gray-800 mb-2">{{ $t('inventory.suppliers.noSuppliers') }}</h3>
                <p class="text-gray-600 text-lg">
                  {{ activeTab === 'deleted' ? $t('inventory.suppliers.noDeletedSuppliers') : $t('inventory.suppliers.noSuppliersMessage') }}
                </p>
              </div>
            </td>
          </tr>
          <tr 
            v-else 
            v-for="supplier in paginatedSuppliers" 
            :key="supplier.id"
            class="hover:bg-gray-50 cursor-pointer"
            @click="viewSupplier(supplier.id)"
          >
            <td class="px-6 py-4" @click.stop>
              <input 
                type="checkbox" 
                :value="supplier.id"
                v-model="selectedSuppliers"
                class="rounded"
                @click.stop
              >
            </td>
            <td :class="['px-6 py-4', textAlign]">
              <div class="flex items-center gap-2">
                <div>
                  <div class="font-medium text-gray-900">{{ supplier.name }}</div>
                  <div v-if="supplier.nameLocalized" class="text-sm text-gray-500">{{ supplier.nameLocalized }}</div>
                </div>
                <span v-if="supplier.deleted || supplier.deletedAt" class="px-2 py-1 bg-red-100 text-red-800 rounded-full text-xs font-semibold">{{ $t('inventory.suppliers.deleted') }}</span>
              </div>
            </td>
            <td :class="['px-6 py-4 text-gray-700', textAlign]">{{ supplier.code || '-' }}</td>
            <td :class="['px-6 py-4 text-gray-700', textAlign]">
              <div v-if="supplier.contactName">{{ supplier.contactName }}</div>
              <div v-if="supplier.phone" class="text-sm text-gray-500">{{ supplier.phone }}</div>
              <div v-if="supplier.primaryEmail" class="text-sm text-gray-500">{{ supplier.primaryEmail }}</div>
              <span v-if="!supplier.contactName && !supplier.phone && !supplier.primaryEmail">-</span>
            </td>
            <td :class="['px-6 py-4', textAlign]" @click.stop>
              <div class="relative">
                <button 
                  @click="toggleSupplierMenu(supplier.id)"
                  class="text-gray-600 hover:text-gray-800"
                >
                  <i class="fas fa-ellipsis-v"></i>
                </button>
                <div v-if="activeSupplierMenu === supplier.id" class="dropdown-menu">
                  <a @click.stop="viewSupplier(supplier.id)" class="cursor-pointer"><i class="fas fa-eye mr-2"></i>{{ $t('common.view') }}</a>
                  <a @click.stop="editSupplier(supplier)" class="cursor-pointer"><i class="fas fa-edit mr-2"></i>{{ $t('common.edit') }}</a>
                  <a v-if="activeTab === 'deleted'" href="#" @click.prevent.stop="restoreSupplier(supplier.id)"><i class="fas fa-undo mr-2"></i>{{ $t('inventory.suppliers.restore') }}</a>
                  <a v-else href="#" @click.prevent.stop="deleteSupplier(supplier.id)"><i class="fas fa-trash mr-2 text-red-600"></i>{{ $t('common.delete') }}</a>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="mt-4 flex justify-between items-center bg-white rounded-lg shadow-md p-4">
      <div class="text-sm text-gray-600">
        Showing {{ showingFrom }} to {{ showingTo }} of {{ totalSuppliers }} suppliers
      </div>
      <div class="flex gap-2">
        <button 
          @click="previousPage"
          :disabled="currentPage === 1"
          :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', currentPage === 1 ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50']"
        >
          <i class="fas fa-chevron-left"></i>
          <span>Previous</span>
        </button>
        <button 
          @click="nextPage"
          :disabled="currentPage === totalPages"
          :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', currentPage === totalPages ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50']"
        >
          <span>Next</span>
          <i class="fas fa-chevron-right"></i>
        </button>
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
          <h2 class="text-2xl font-bold text-gray-800">Filter</h2>
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
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Code</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.code"
                  type="text"
                  placeholder="Search by code..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.codeMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Contact Name</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.contactName"
                  type="text"
                  placeholder="Search by contact name..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.contactNameMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Phone</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.phone"
                  type="text"
                  placeholder="Search by phone..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.phoneMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
              <div class="flex gap-2">
                <input 
                  v-model="tempFilterCriteria.email"
                  type="text"
                  placeholder="Search by email..."
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                <select 
                  v-model="tempFilterCriteria.emailMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
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
                  <option v-for="tag in availableSupplierTags" :key="tag.id" :value="tag.name">{{ tag.name }}</option>
                </select>
                <select 
                  v-model="tempFilterCriteria.tagMode"
                  class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                >
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
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
                  <option value="including">Including</option>
                  <option value="excluding">Excluding</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <!-- Modal Footer -->
        <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
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

    <!-- Create/Edit Supplier Modal -->
    <div 
      v-if="showCreateModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeCreateSupplierModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">{{ editingSupplier ? 'Edit Supplier' : 'Create Supplier' }}</h2>
          <button 
            @click="closeCreateSupplierModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <form @submit.prevent="saveSupplier">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <!-- Basic Information -->
            <div class="md:col-span-2">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">Basic Information</h3>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Name <span class="text-red-500">*</span>
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Supplier name"></i>
              </label>
              <input 
                v-model="newSupplier.name"
                type="text"
                required
                placeholder="Enter supplier name"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Name Localized
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Supplier name in local language"></i>
              </label>
              <input 
                v-model="newSupplier.nameLocalized"
                type="text"
                placeholder="Enter localized name"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Supplier Code
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Unique supplier code"></i>
              </label>
              <input 
                v-model="newSupplier.code"
                type="text"
                placeholder="Auto-generated or enter manually"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <!-- Contact Information -->
            <div class="md:col-span-2 mt-4">
              <h3 class="text-lg font-semibold text-gray-800 mb-4">Contact Information</h3>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Contact Name
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Primary contact person name"></i>
              </label>
              <input 
                v-model="newSupplier.contactName"
                type="text"
                placeholder="Enter contact name"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Phone
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Contact phone number"></i>
              </label>
              <input 
                v-model="newSupplier.phone"
                type="tel"
                placeholder="Enter phone number"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Primary Email
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Primary email address"></i>
              </label>
              <input 
                v-model="newSupplier.primaryEmail"
                type="email"
                placeholder="Enter primary email"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Additional Emails
                <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Additional email addresses (comma-separated)"></i>
              </label>
              <input 
                v-model="newSupplier.additionalEmails"
                type="text"
                placeholder="email1@example.com, email2@example.com"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
              >
            </div>

            <!-- Advanced Options (World Class ERP) -->
            <div class="md:col-span-2 mt-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-800">Advanced Options</h3>
                <button 
                  type="button"
                  @click="showAdvancedOptions = !showAdvancedOptions"
                  class="text-purple-600 hover:text-purple-800 text-sm"
                >
                  {{ showAdvancedOptions ? 'Hide' : 'Show' }} Advanced Options
                </button>
              </div>
            </div>

            <div v-if="showAdvancedOptions" class="md:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-4 border-t pt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Address
                </label>
                <textarea 
                  v-model="newSupplier.address"
                  rows="3"
                  placeholder="Enter supplier address"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                ></textarea>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  City
                </label>
                <input 
                  v-model="newSupplier.city"
                  type="text"
                  placeholder="Enter city"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  State/Province
                </label>
                <input 
                  v-model="newSupplier.state"
                  type="text"
                  placeholder="Enter state/province"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Country
                </label>
                <input 
                  v-model="newSupplier.country"
                  type="text"
                  placeholder="Enter country"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Postal Code
                </label>
                <input 
                  v-model="newSupplier.postalCode"
                  type="text"
                  placeholder="Enter postal code"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Tax ID / VAT Number
                </label>
                <input 
                  v-model="newSupplier.taxId"
                  type="text"
                  placeholder="Enter tax ID/VAT number"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Payment Terms (Days)
                </label>
                <input 
                  v-model.number="newSupplier.paymentTerms"
                  type="number"
                  min="0"
                  placeholder="e.g., 30"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Credit Limit
                </label>
                <input 
                  v-model.number="newSupplier.creditLimit"
                  type="number"
                  min="0"
                  step="0.01"
                  placeholder="0.00"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Currency
                </label>
                <select 
                  v-model="newSupplier.currency"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="SAR">SAR (Saudi Riyal)</option>
                  <option value="USD">USD (US Dollar)</option>
                  <option value="EUR">EUR (Euro)</option>
                  <option value="GBP">GBP (British Pound)</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Website
                </label>
                <input 
                  v-model="newSupplier.website"
                  type="url"
                  placeholder="https://example.com"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Notes
                </label>
                <textarea 
                  v-model="newSupplier.notes"
                  rows="3"
                  placeholder="Additional notes about the supplier"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                ></textarea>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-6 mt-6 border-t">
            <button 
              type="button"
              @click="closeCreateSupplierModal"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              type="submit"
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Save
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Import Suppliers Modal -->
    <div 
      v-if="showImportModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeImportModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">Upload a File</h2>
          <button 
            @click="closeImportModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="grid grid-cols-2 gap-6">
          <!-- Left Column: Column Requirements and Download Template -->
          <div class="space-y-4">
            <div class="bg-purple-50 border-l-4 border-purple-500 p-4">
              <div class="flex items-start gap-2">
                <i class="fas fa-info-circle text-purple-500 mt-0.5"></i>
                <p class="text-sm text-purple-800 font-semibold">
                  Make sure your file includes the following required columns:
                </p>
              </div>
            </div>

            <!-- Required Columns List -->
            <div>
              <h3 class="text-sm font-semibold text-gray-700 mb-3">REQUIRED COLUMNS</h3>
              <div class="space-y-2">
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-purple-500"></i>
                  <span>Supplier ID</span>
                  <i class="fas fa-info-circle text-gray-400 text-xs cursor-help" title="Auto-generated if not provided"></i>
                </div>
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-purple-500"></i>
                  <span>Name</span>
                </div>
              </div>
            </div>

            <!-- Optional Columns List -->
            <div>
              <h3 class="text-sm font-semibold text-gray-700 mb-3">OPTIONAL COLUMNS</h3>
              <div class="space-y-2">
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-gray-400"></i>
                  <span>Code</span>
                </div>
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-gray-400"></i>
                  <span>Contact Name</span>
                </div>
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-gray-400"></i>
                  <span>Primary Email</span>
                </div>
                <div class="flex items-center gap-2 text-sm text-gray-600">
                  <i class="fas fa-info-circle text-gray-400"></i>
                  <span>Phone</span>
                </div>
              </div>
            </div>

            <!-- Download Template Button -->
            <button 
              @click="downloadExcelTemplate"
              class="w-full px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center justify-center gap-2 font-semibold mt-6"
            >
              <i class="fas fa-download"></i>
              <span>Download Excel template</span>
            </button>
          </div>

          <!-- Right Column: File Upload Area -->
          <div class="flex flex-col">
            <div class="border-2 border-dashed border-purple-300 rounded-lg p-12 text-center flex-1 flex flex-col items-center justify-center bg-gray-50">
              <div class="flex items-center justify-center gap-4 mb-4">
                <div class="text-4xl text-gray-400">.csv</div>
                <div class="text-5xl text-gray-400">+</div>
                <div class="text-4xl text-gray-400">.xls</div>
              </div>
              <div class="mb-4">
                <p class="text-sm font-medium text-gray-700 mb-1">What data do you want to upload?</p>
                <p class="text-xs text-gray-500">Upload a CSV or Excel file to begin the import process</p>
              </div>
              <input 
                type="file"
                @change="handleFileSelect"
                accept=".xlsx,.xls,.csv"
                class="hidden"
                ref="fileInput"
                id="supplier-import-file-input"
              >
              <label 
                for="supplier-import-file-input"
                class="inline-block px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 cursor-pointer font-semibold"
              >
                Choose File
              </label>
              <p v-if="importFile" class="text-sm text-gray-600 mt-3">
                Selected: <span class="font-medium">{{ importFile.name }}</span>
              </p>
            </div>

            <!-- Action Buttons -->
            <div class="flex justify-end gap-3 mt-6 pt-4 border-t">
              <button 
                type="button"
                @click="closeImportModal"
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button 
                type="button"
                @click="handleImport"
                :disabled="!importFile"
                :class="['px-6', 'py-2', 'bg-purple-600', 'text-white', 'rounded-lg', 'hover:bg-purple-700', 'font-semibold', !importFile ? 'opacity-50 cursor-not-allowed' : '']"
              >
                Import
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Select Header Row Modal -->
    <div 
      v-if="showHeaderSelectModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeHeaderSelectModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-5xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">Select header row</h2>
          <button 
            @click="closeHeaderSelectModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="overflow-x-auto border rounded-lg">
          <table class="w-full text-sm border-collapse">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left border font-semibold text-gray-700" style="min-width: 60px;"></th>
                <th 
                  v-for="(cell, colIndex) in rawImportData[0] || []" 
                  :key="colIndex"
                  class="px-4 py-3 text-left border font-semibold text-gray-700"
                  style="min-width: 150px;"
                >
                  {{ cell || `Column ${colIndex + 1}` }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="(row, rowIndex) in rawImportData.slice(0, 15)" 
                :key="rowIndex"
                @click="selectHeaderRow(rowIndex)"
                :class="['cursor-pointer hover:bg-gray-50', selectedHeaderRow === rowIndex ? 'bg-purple-100 border-l-4 border-purple-500' : '']"
              >
                <td class="px-4 py-3 border text-center">
                  <input 
                    type="radio" 
                    :checked="selectedHeaderRow === rowIndex"
                    @change="selectHeaderRow(rowIndex)"
                    class="text-purple-600"
                  >
                </td>
                <td 
                  v-for="(cell, colIndex) in row" 
                  :key="colIndex"
                  class="px-4 py-3 border"
                >
                  {{ cell || '' }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="flex justify-end gap-3 mt-6 pt-4 border-t">
          <button 
            @click="closeHeaderSelectModal"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Previous
          </button>
          <button 
            @click="processImportData"
            :disabled="selectedHeaderRow === null"
            :class="['px-6', 'py-2', 'bg-purple-600', 'text-white', 'rounded-lg', 'hover:bg-purple-700', 'font-semibold', selectedHeaderRow === null ? 'opacity-50 cursor-not-allowed' : '']"
          >
            Next
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
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-[95vw] max-h-[95vh] flex flex-col relative z-50" @click.stop style="pointer-events: auto; position: relative;">
        <!-- Modal Header -->
        <div class="flex justify-between items-center mb-4 pb-4 border-b">
          <div class="flex items-center gap-2">
            <i class="fas fa-check-circle text-green-600"></i>
            <h2 class="text-2xl font-bold text-gray-800">Review & finalize</h2>
          </div>
          <button 
            @click="closeReviewModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>
        
        <div class="flex gap-6 flex-1 overflow-hidden">
          <!-- Left: Main Content -->
          <div class="flex-1 flex flex-col overflow-hidden">
            <!-- Summary -->
            <div class="mb-4 p-4 bg-gray-50 rounded-lg">
              <div class="flex items-center gap-6 text-sm font-semibold">
                <span>All rows <strong class="text-purple-600">{{ reviewSummary.total }}</strong></span>
                <span class="text-green-600">Clean rows <strong>{{ reviewSummary.clean }}</strong></span>
                <span class="text-red-600">Rows with issues <strong>{{ reviewSummary.withIssues }}</strong></span>
              </div>
            </div>
            
            <!-- Table -->
            <div class="flex-1 overflow-y-auto border rounded-lg">
              <table class="w-full text-sm border-collapse">
                <thead class="bg-gray-100 sticky top-0 z-20">
                  <tr>
                    <th class="px-4 py-3 text-center border bg-gray-100 font-semibold text-gray-700" style="min-width: 50px;">
                      <i class="fas fa-info-circle text-gray-400"></i>
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 120px;">
                      Supplier ID
                      <i class="fas fa-info-circle text-gray-400 ml-1"></i>
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 200px;">
                      Name
                      <i class="fas fa-info-circle text-gray-400 ml-1"></i>
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 120px;">
                      Code
                      <i class="fas fa-exclamation-triangle text-red-500 ml-1" v-if="allIssues.code && allIssues.code.length > 0"></i>
                      <span v-if="allIssues.code && allIssues.code.length > 0" class="text-red-600 font-bold ml-1">
                        {{ reviewItems.filter(s => s.issues.some(i => i.field === 'code')).length }}
                      </span>
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 150px;">
                      Contact Name
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 150px;">
                      Email
                    </th>
                    <th class="px-4 py-3 text-left border bg-gray-100 font-semibold text-gray-700" style="min-width: 120px;">
                      Phone
                      <i class="fas fa-exclamation-triangle text-red-500 ml-1" v-if="allIssues.phone && allIssues.phone.length > 0"></i>
                      <span v-if="allIssues.phone && allIssues.phone.length > 0" class="text-red-600 font-bold ml-1">
                        {{ reviewItems.filter(s => s.issues.some(i => i.field === 'phone')).length }}
                      </span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr 
                    v-for="(supplier, index) in paginatedReviewItems" 
                    :key="index"
                    :class="['hover:bg-gray-50', supplier.hasIssues ? 'bg-red-50' : '', selectedSupplierRow === index ? 'bg-blue-50' : '']"
                    @click="selectedSupplierRow = index"
                  >
                    <td class="px-4 py-2 text-center border align-middle">
                      <input 
                        type="checkbox" 
                        :checked="!supplier.hasIssues"
                        disabled
                        class="rounded"
                      >
                    </td>
                    <td class="px-4 py-2 border align-middle">{{ supplier.supplier_id || '-' }}</td>
                    <td class="px-4 py-2 border align-middle">{{ supplier.name || '' }}</td>
                    <td 
                      class="px-4 py-2 border align-middle"
                      :class="supplier.issues.some(i => i.field === 'code') ? 'bg-red-100' : ''"
                    >
                      {{ supplier.code || '-' }}
                    </td>
                    <td class="px-4 py-2 border align-middle">{{ supplier.contactName || '-' }}</td>
                    <td class="px-4 py-2 border align-middle">{{ supplier.primaryEmail || '-' }}</td>
                    <td 
                      class="px-4 py-2 border align-middle"
                      :class="supplier.issues.some(i => i.field === 'phone') ? 'bg-red-100' : ''"
                    >
                      {{ supplier.phone || '-' }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <!-- Pagination Info and Controls -->
            <div class="flex justify-between items-center mt-2">
              <div class="text-sm text-gray-600">
                Showing {{ ((currentReviewPage - 1) * reviewPageSize) + 1 }}-{{ Math.min(currentReviewPage * reviewPageSize, reviewItems.length) }} of {{ reviewItems.length }} suppliers
              </div>
              <div class="flex gap-2">
                <button 
                  @click="currentReviewPage--"
                  :disabled="currentReviewPage === 1"
                  :class="['px-3', 'py-1', 'border', 'rounded', 'text-sm', currentReviewPage === 1 ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50']"
                >
                  Previous
                </button>
                <button 
                  @click="currentReviewPage++"
                  :disabled="currentReviewPage >= Math.ceil(reviewItems.length / reviewPageSize)"
                  :class="['px-3', 'py-1', 'border', 'rounded', 'text-sm', currentReviewPage >= Math.ceil(reviewItems.length / reviewPageSize) ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50']"
                >
                  Next
                </button>
              </div>
            </div>
          </div>

          <!-- Right: All Issues Panel -->
          <div class="w-80 border-l pl-6 flex flex-col">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-800">All issues</h3>
              <i class="fas fa-chevron-right text-gray-400"></i>
            </div>
            
            <div class="flex gap-2 mb-4">
              <button class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50">Map columns</button>
              <button class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50">Find and replace</button>
              <button class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50">Export</button>
            </div>

            <div class="flex-1 overflow-y-auto space-y-4">
              <!-- Code Issues -->
              <div v-if="allIssues.code && allIssues.code.length > 0" class="border rounded-lg p-3 bg-red-50">
                <div class="flex items-center gap-2 mb-2">
                  <i class="fas fa-exclamation-triangle text-red-600"></i>
                  <span class="font-semibold text-gray-800">Code</span>
                  <span class="text-red-600 font-bold">{{ reviewItems.filter(s => s.issues.some(i => i.field === 'code')).length }}</span>
                </div>
                <p class="text-xs text-gray-600 mb-2">
                  {{ reviewItems.filter(s => s.issues.some(i => i.field === 'code')).length }} cells require attention
                </p>
                <div class="flex flex-wrap gap-1">
                  <span 
                    v-for="(issue, idx) in allIssues.code.slice(0, 5)" 
                    :key="idx"
                    class="px-2 py-1 bg-white border border-red-200 rounded text-xs text-gray-700"
                  >
                    {{ issue.message }}
                  </span>
                </div>
              </div>

              <!-- Phone Issues -->
              <div v-if="allIssues.phone && allIssues.phone.length > 0" class="border rounded-lg p-3 bg-red-50">
                <div class="flex items-center gap-2 mb-2">
                  <i class="fas fa-exclamation-triangle text-red-600"></i>
                  <span class="font-semibold text-gray-800">Phone</span>
                  <span class="text-red-600 font-bold">{{ reviewItems.filter(s => s.issues.some(i => i.field === 'phone')).length }}</span>
                </div>
                <p class="text-xs text-gray-600 mb-2">
                  {{ reviewItems.filter(s => s.issues.some(i => i.field === 'phone')).length }} cells require attention
                </p>
                <div class="flex flex-wrap gap-1">
                  <span 
                    v-for="(issue, idx) in allIssues.phone.slice(0, 5)" 
                    :key="idx"
                    class="px-2 py-1 bg-white border border-red-200 rounded text-xs text-gray-700"
                  >
                    {{ issue.message }}
                  </span>
                </div>
              </div>

              <!-- Email Issues -->
              <div v-if="allIssues.email && allIssues.email.length > 0" class="border rounded-lg p-3 bg-red-50">
                <div class="flex items-center gap-2 mb-2">
                  <i class="fas fa-exclamation-triangle text-red-600"></i>
                  <span class="font-semibold text-gray-800">Email</span>
                  <span class="text-red-600 font-bold">{{ reviewItems.filter(s => s.issues.some(i => i.field === 'email')).length }}</span>
                </div>
                <p class="text-xs text-gray-600 mb-2">
                  {{ reviewItems.filter(s => s.issues.some(i => i.field === 'email')).length }} cells require attention
                </p>
              </div>

              <!-- Name Issues -->
              <div v-if="allIssues.name && allIssues.name.length > 0" class="border rounded-lg p-3 bg-red-50">
                <div class="flex items-center gap-2 mb-2">
                  <i class="fas fa-exclamation-triangle text-red-600"></i>
                  <span class="font-semibold text-gray-800">Name</span>
                  <span class="text-red-600 font-bold">{{ reviewItems.filter(s => s.issues.some(i => i.field === 'name')).length }}</span>
                </div>
                <p class="text-xs text-gray-600 mb-2">
                  {{ reviewItems.filter(s => s.issues.some(i => i.field === 'name')).length }} cells require attention
                </p>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Modal Footer - Always visible, not scrollable -->
        <div 
          class="flex justify-between items-center pt-4 border-t border-gray-200 mt-4 flex-shrink-0" 
          @click.stop.prevent
          style="pointer-events: auto; position: relative; z-index: 1000; background: white;"
        >
          <button 
            @click.stop.prevent="closeReviewModal"
            type="button"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
            style="pointer-events: auto; position: relative; z-index: 1001;"
          >
            Previous
          </button>
          <button 
            @click.stop.prevent="handleImportButtonClick"
            @mousedown.stop.prevent
            @mouseup.stop.prevent
            type="button"
            id="import-button-final"
            :disabled="isImporting"
            class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-semibold cursor-pointer transition-colors active:bg-purple-800 disabled:opacity-70 disabled:cursor-not-allowed"
            style="pointer-events: auto; position: relative; z-index: 1001; min-width: 120px;"
          >
            <span v-if="!isImporting">Import</span>
            <span v-else class="flex items-center gap-2">
              <i class="fas fa-spinner fa-spin"></i>
              Importing...
            </span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from '@/composables/useI18n';
import { supabaseClient, USE_SUPABASE, importSuppliersToSupabase, saveSupplierToSupabase, updateSupplierInSupabase } from '@/services/supabase';

const router = useRouter();
const route = useRoute();
const { t, locale } = useI18n();

// State
const suppliers = ref([]);
const loading = ref(false);
const activeTab = ref('all');
const selectedSuppliers = ref([]);
const activeSupplierMenu = ref(null);
const showImportExportMenu = ref(false);
const showBulkActionsMenu = ref(false);
const showCreateModal = ref(false);
const editingSupplier = ref(null);
const showAdvancedOptions = ref(false);
const currentPage = ref(1);
const limit = ref(50);

// Filter state
const showFilterModal = ref(false);
// Active filter criteria (applied filters)
const filterCriteria = ref({
  name: '',
  nameMode: 'including',
  code: '',
  codeMode: 'including',
  contactName: '',
  contactNameMode: 'including',
  phone: '',
  phoneMode: 'including',
  email: '',
  emailMode: 'including',
  tag: '',
  tagMode: 'including',
  deleted: '',
  deletedMode: 'including',
  updatedAfter: ''
});

// Temporary filter criteria (for modal inputs - not applied until Apply is clicked)
const tempFilterCriteria = ref({
  name: '',
  nameMode: 'including',
  code: '',
  codeMode: 'including',
  contactName: '',
  contactNameMode: 'including',
  phone: '',
  phoneMode: 'including',
  email: '',
  emailMode: 'including',
  tag: '',
  tagMode: 'including',
  deleted: '',
  deletedMode: 'including',
  updatedAfter: ''
});

// New supplier form
const newSupplier = ref({
  name: '',
  nameLocalized: '',
  code: '',
  contactName: '',
  phone: '',
  primaryEmail: '',
  additionalEmails: '',
  address: '',
  city: '',
  state: '',
  country: '',
  postalCode: '',
  taxId: '',
  paymentTerms: 30,
  creditLimit: 0,
  currency: 'SAR',
  website: '',
  notes: ''
});

// Computed
const filteredSuppliers = computed(() => {
  // Ensure suppliers is always an array
  if (!suppliers.value || !Array.isArray(suppliers.value)) {
    return [];
  }
  let filtered = suppliers.value;
  
  // Apply tab filter first
  if (activeTab.value === 'deleted') {
    filtered = filtered.filter(s => s.deleted === true || s.deletedAt);
  } else {
    filtered = filtered.filter(s => !s.deleted && !s.deletedAt);
  }
  
  // Apply advanced filters with Including/Excluding logic
  if (filterCriteria.value.name) {
    const nameLower = filterCriteria.value.name.toLowerCase();
    const matches = (s) => 
      (s.name && s.name.toLowerCase().includes(nameLower)) ||
      (s.nameLocalized && s.nameLocalized.toLowerCase().includes(nameLower));
    
    if (filterCriteria.value.nameMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.code) {
    const codeLower = filterCriteria.value.code.toLowerCase();
    const matches = (s) => 
      s.code && s.code.toLowerCase().includes(codeLower);
    
    if (filterCriteria.value.codeMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.contactName) {
    const contactLower = filterCriteria.value.contactName.toLowerCase();
    const matches = (s) => 
      s.contactName && s.contactName.toLowerCase().includes(contactLower);
    
    if (filterCriteria.value.contactNameMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.phone) {
    const phoneLower = filterCriteria.value.phone.toLowerCase();
    const matches = (s) => 
      s.phone && s.phone.toLowerCase().includes(phoneLower);
    
    if (filterCriteria.value.phoneMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.email) {
    const emailLower = filterCriteria.value.email.toLowerCase();
    const matches = (s) => 
      (s.primaryEmail && s.primaryEmail.toLowerCase().includes(emailLower)) ||
      (s.additionalEmails && s.additionalEmails.toLowerCase().includes(emailLower));
    
    if (filterCriteria.value.emailMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.tag) {
    const matches = (s) => {
      const supplierId = s.id;
      const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
      if (!linkedTags) return false;
      const tagIds = JSON.parse(linkedTags);
      const stored = localStorage.getItem('supplier_tags');
      const allTags = stored ? JSON.parse(stored) : [];
      const linkedTagNames = allTags.filter(tag => tagIds.includes(tag.id)).map(tag => tag.name);
      return linkedTagNames.includes(filterCriteria.value.tag);
    };
    
    if (filterCriteria.value.tagMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.deleted !== '') {
    const isDeleted = filterCriteria.value.deleted === 'true';
    const matches = (s) => s.deleted === isDeleted || (isDeleted && s.deletedAt);
    
    if (filterCriteria.value.deletedMode === 'including') {
      filtered = filtered.filter(matches);
    } else {
      filtered = filtered.filter(s => !matches(s));
    }
  }
  
  if (filterCriteria.value.updatedAfter) {
    const filterDate = new Date(filterCriteria.value.updatedAfter);
    filtered = filtered.filter(s => {
      const supplierDate = new Date(s.updated_at || s.updatedAt || s.created_at || s.createdAt);
      return supplierDate >= filterDate;
    });
  }
  
  return filtered;
});

const paginatedSuppliers = computed(() => {
  // Ensure filteredSuppliers is always an array
  if (!filteredSuppliers.value || !Array.isArray(filteredSuppliers.value)) {
    return [];
  }
  const start = (currentPage.value - 1) * limit.value;
  const end = start + limit.value;
  return filteredSuppliers.value.slice(start, end);
});

const allSuppliersSelected = computed(() => {
  return paginatedSuppliers.value.length > 0 && 
         paginatedSuppliers.value.every(s => selectedSuppliers.value.includes(s.id));
});

const totalSuppliers = computed(() => filteredSuppliers.value.length);
const totalPages = computed(() => Math.ceil(totalSuppliers.value / limit.value));
const showingFrom = computed(() => (currentPage.value - 1) * limit.value + 1);
const showingTo = computed(() => Math.min(currentPage.value * limit.value, totalSuppliers.value));

const hasActiveFilters = computed(() => {
  return !!(
    filterCriteria.value.name ||
    filterCriteria.value.code ||
    filterCriteria.value.contactName ||
    filterCriteria.value.phone ||
    filterCriteria.value.email ||
    filterCriteria.value.tag ||
    filterCriteria.value.deleted !== '' ||
    filterCriteria.value.updatedAfter
  );
});

const activeFiltersCount = computed(() => {
  let count = 0;
  if (filterCriteria.value.name) count++;
  if (filterCriteria.value.code) count++;
  if (filterCriteria.value.contactName) count++;
  if (filterCriteria.value.phone) count++;
  if (filterCriteria.value.email) count++;
  if (filterCriteria.value.tag) count++;
  if (filterCriteria.value.deleted !== '') count++;
  if (filterCriteria.value.updatedAfter) count++;
  return count;
});

const availableSupplierTags = computed(() => {
  try {
    const stored = localStorage.getItem('supplier_tags');
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    return [];
  }
});

// Methods
const loadSuppliers = async () => {
  loading.value = true;
  try {
    // Try Supabase first (priority to Supabase)
    const supabaseModule = await import('@/services/supabase');
    const { loadSuppliersFromSupabase, ensureSupabaseReady } = supabaseModule;
    
    // Ensure Supabase is ready
    const isSupabaseReady = await ensureSupabaseReady();
    
    // If Supabase is available, use it exclusively (don't fallback to localStorage)
    if (isSupabaseReady) {
    const supabaseSuppliers = await loadSuppliersFromSupabase();
    
      // Map Supabase data to component format
      suppliers.value = (supabaseSuppliers || []).map(s => ({
        id: s.id,
        name: s.name,
        nameLocalized: s.name_localized || s.name,
        code: s.code || '',
        contactName: s.contact_name || '',
        phone: s.phone || '',
        primaryEmail: s.primary_email || '',
        additionalEmails: s.additional_emails || '',
        address: s.address || '',
        city: s.city || '',
        state: s.state || '',
        country: s.country || '',
        postalCode: s.postal_code || '',
        taxId: s.tax_id || '',
        paymentTerms: s.payment_terms || 30,
        creditLimit: s.credit_limit || 0,
        currency: s.currency || 'SAR',
        website: s.website || '',
        notes: s.notes || '',
        deleted: s.deleted || false,
        deletedAt: s.deleted_at || null,
        createdAt: s.created_at || new Date().toISOString(),
        updatedAt: s.updated_at || new Date().toISOString()
      }));
    } else {
      // Only use localStorage if Supabase is not available
      const stored = localStorage.getItem('suppliers');
      if (stored) {
        try {
          const parsed = JSON.parse(stored);
          suppliers.value = Array.isArray(parsed) ? parsed : [];
        } catch (parseError) {
          suppliers.value = [];
        }
      } else {
        suppliers.value = [];
      }
    }
  } catch (error) {
    console.error('Error loading suppliers:', error);
    // Only fallback to localStorage if Supabase is not configured
    try {
      const supabaseModule = await import('@/services/supabase');
      const { ensureSupabaseReady } = supabaseModule;
      const isSupabaseReady = await ensureSupabaseReady();
      
      if (!isSupabaseReady) {
    const stored = localStorage.getItem('suppliers');
    if (stored) {
      suppliers.value = JSON.parse(stored);
    } else {
          suppliers.value = [];
        }
      } else {
        suppliers.value = [];
      }
    } catch (fallbackError) {
      console.error('Error in fallback:', fallbackError);
      suppliers.value = [];
    }
    // Ensure suppliers is always an array even on error
    if (!suppliers.value || !Array.isArray(suppliers.value)) {
      suppliers.value = [];
    }
  } finally {
    loading.value = false;
  }
};

const switchTab = (tabName) => {
  activeTab.value = tabName;
  selectedSuppliers.value = [];
  currentPage.value = 1;
  loadSuppliers();
};

const toggleSelectAll = () => {
  if (allSuppliersSelected.value) {
    selectedSuppliers.value = [];
  } else {
    selectedSuppliers.value = paginatedSuppliers.value.map(s => s.id);
  }
};

const toggleBulkActionsMenu = (e) => {
  if (e) {
    e.stopPropagation();
  }
  showBulkActionsMenu.value = !showBulkActionsMenu.value;
};

const clearSelection = () => {
  selectedSuppliers.value = [];
  showBulkActionsMenu.value = false;
};

const toggleSupplierMenu = (supplierId) => {
  activeSupplierMenu.value = activeSupplierMenu.value === supplierId ? null : supplierId;
  showBulkActionsMenu.value = false; // Close bulk actions menu when opening item menu
};

const toggleImportExportMenu = (e) => {
  if (e) {
    e.stopPropagation();
  }
  showImportExportMenu.value = !showImportExportMenu.value;
};

// Wrapper functions for dropdown menu items
const handleExportClick = async () => {
  showImportExportMenu.value = false;
  await exportSuppliers();
};

const handleImportClick = () => {
  showImportExportMenu.value = false;
  openImportModal();
};

const handleDownloadTemplateClick = async () => {
  showImportExportMenu.value = false;
  await downloadExcelTemplate();
};

const openCreateSupplierModal = () => {
  editingSupplier.value = null;
  newSupplier.value = {
    name: '',
    nameLocalized: '',
    code: '',
    contactName: '',
    phone: '',
    primaryEmail: '',
    additionalEmails: '',
    address: '',
    city: '',
    state: '',
    country: '',
    postalCode: '',
    taxId: '',
    paymentTerms: 30,
    creditLimit: 0,
    currency: 'SAR',
    website: '',
    notes: ''
  };
  showAdvancedOptions.value = false;
  showCreateModal.value = true;
};

const closeCreateSupplierModal = () => {
  showCreateModal.value = false;
  editingSupplier.value = null;
};

const saveSupplier = async () => {
  try {
    const supplierData = {
      ...newSupplier.value,
      id: editingSupplier.value?.id || null,
      createdAt: editingSupplier.value?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      deleted: false
    };
    
    // Ensure Supabase is ready
    const supabaseModule = await import('@/services/supabase');
    const { ensureSupabaseReady, saveSupplierToSupabase, updateSupplierInSupabase } = supabaseModule;
    const isSupabaseReady = await ensureSupabaseReady();
    
    // Save to Supabase if available
    if (isSupabaseReady) {
      if (editingSupplier.value && editingSupplier.value.id) {
        // Update existing supplier
        const result = await updateSupplierInSupabase(editingSupplier.value.id, supplierData);
        if (result.success) {
          showNotification('Supplier updated successfully', 'success');
          closeCreateSupplierModal();
          await loadSuppliers();
        } else {
          throw new Error(result.error || 'Failed to update supplier');
        }
      } else {
        // Create new supplier
        const result = await saveSupplierToSupabase(supplierData);
        if (result.success) {
          showNotification('Supplier created successfully', 'success');
          closeCreateSupplierModal();
          await loadSuppliers();
        } else {
          throw new Error(result.error || 'Failed to create supplier');
        }
      }
    } else {
      // Fallback to localStorage
    const stored = localStorage.getItem('suppliers');
    const suppliersList = stored ? JSON.parse(stored) : [];
    
      if (editingSupplier.value && editingSupplier.value.id) {
        const index = suppliersList.findIndex(s => s.id === editingSupplier.value.id);
      if (index !== -1) {
          suppliersList[index] = {
            ...supplierData,
            id: editingSupplier.value.id
          };
      }
    } else {
        supplierData.id = `supplier-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      suppliersList.push(supplierData);
    }
    
    localStorage.setItem('suppliers', JSON.stringify(suppliersList));
    showNotification(editingSupplier.value ? 'Supplier updated successfully' : 'Supplier created successfully', 'success');
    closeCreateSupplierModal();
    await loadSuppliers();
    }
  } catch (error) {
    console.error('Error saving supplier:', error);
    showNotification('Error saving supplier: ' + (error.message || 'Unknown error'), 'error');
  }
};

const viewSupplier = (supplierId) => {
  router.push(`/homeportal/suppliers/${supplierId}`);
};

const editSupplier = (supplier) => {
  editingSupplier.value = supplier;
  newSupplier.value = { ...supplier };
  showCreateModal.value = true;
};

const deleteSupplier = async (supplierId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Supplier',
    message: 'Are you sure you want to delete this supplier?',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    // Try Supabase first
    const { deleteSupplierFromSupabase } = await import('@/services/supabase');
    const result = await deleteSupplierFromSupabase(supplierId);
    
    if (result.success) {
      showNotification('Supplier deleted successfully', 'success');
      selectedSuppliers.value = selectedSuppliers.value.filter(id => id !== supplierId);
      await loadSuppliers();
    } else {
      throw new Error(result.error || 'Failed to delete supplier');
    }
  } catch (error) {
    console.error('Error deleting supplier:', error);
    showNotification('Error deleting supplier: ' + (error.message || 'Unknown error'), 'error');
  }
};

const restoreSupplier = async (supplierId) => {
  try {
    // Try Supabase first
    const { restoreSupplierFromSupabase } = await import('@/services/supabase');
    const result = await restoreSupplierFromSupabase(supplierId);
    
    if (result.success) {
      showNotification('Supplier restored successfully', 'success');
      // Update local state immediately before reload
      const supplierIndex = suppliers.value.findIndex(s => s.id === supplierId);
      if (supplierIndex !== -1) {
        suppliers.value[supplierIndex].deleted = false;
        suppliers.value[supplierIndex].deletedAt = null;
      }
      // Reload suppliers to get fresh data from Supabase/localStorage
      await loadSuppliers();
      // If on deleted tab and no more deleted suppliers, switch to all tab
      if (activeTab.value === 'deleted' && filteredSuppliers.value.length === 0) {
        activeTab.value = 'all';
      }
    } else {
      throw new Error(result.error || 'Failed to restore supplier');
    }
  } catch (error) {
    console.error('Error restoring supplier:', error);
    showNotification('Error restoring supplier: ' + (error.message || 'Unknown error'), 'error');
  }
};

const bulkDeleteSuppliers = async () => {
  if (selectedSuppliers.value.length === 0) {
    showNotification('Please select suppliers to delete', 'warning');
    return;
  }
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Suppliers',
    message: `Are you sure you want to delete ${selectedSuppliers.value.length} supplier(s)?`,
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const { deleteSupplierFromSupabase } = await import('@/services/supabase');
    const results = await Promise.allSettled(
      selectedSuppliers.value.map(id => deleteSupplierFromSupabase(id))
    );
    
    const successful = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
    const failed = results.length - successful;
    
    if (successful > 0) {
      showNotification(`Successfully deleted ${successful} supplier(s)${failed > 0 ? `. ${failed} failed.` : ''}`, 'success');
      selectedSuppliers.value = [];
      await loadSuppliers();
    } else {
      showNotification('Failed to delete suppliers', 'error');
    }
  } catch (error) {
    console.error('Error bulk deleting suppliers:', error);
    showNotification('Error deleting suppliers: ' + (error.message || 'Unknown error'), 'error');
  }
};

const bulkRestoreSuppliers = async () => {
  if (selectedSuppliers.value.length === 0) {
    showNotification('Please select suppliers to restore', 'warning');
    return;
  }
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Restore Suppliers',
    message: `Are you sure you want to restore ${selectedSuppliers.value.length} supplier(s)?`,
    confirmText: 'Restore',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-undo'
  });
  
  if (!confirmed) return;
  
  try {
    const { restoreSupplierFromSupabase } = await import('@/services/supabase');
    const results = await Promise.allSettled(
      selectedSuppliers.value.map(id => restoreSupplierFromSupabase(id))
    );
    
    const successful = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
    const failed = results.length - successful;
    
    if (successful > 0) {
      showNotification(`Successfully restored ${successful} supplier(s)${failed > 0 ? `. ${failed} failed.` : ''}`, 'success');
      // Store IDs before clearing
      const restoredIds = [...selectedSuppliers.value];
      selectedSuppliers.value = [];
      // Update local state immediately for all restored suppliers
      restoredIds.forEach(supplierId => {
        const supplierIndex = suppliers.value.findIndex(s => s.id === supplierId);
        if (supplierIndex !== -1) {
          suppliers.value[supplierIndex].deleted = false;
          suppliers.value[supplierIndex].deletedAt = null;
        }
      });
      // Reload suppliers to get fresh data
      await loadSuppliers();
      // If on deleted tab and no more deleted suppliers, switch to all tab
      if (activeTab.value === 'deleted' && filteredSuppliers.value.length === 0) {
        activeTab.value = 'all';
      }
    } else {
      showNotification('Failed to restore suppliers', 'error');
    }
  } catch (error) {
    console.error('Error bulk restoring suppliers:', error);
    showNotification('Error restoring suppliers: ' + (error.message || 'Unknown error'), 'error');
  }
};

const bulkAddTags = async () => {
  if (selectedSuppliers.value.length === 0) {
    showNotification('Please select suppliers to add tags', 'warning');
    return;
  }
  
  // Load available supplier tags
  const stored = localStorage.getItem('supplier_tags');
  const availableTags = stored ? JSON.parse(stored) : [];
  
  if (availableTags.length === 0) {
    showNotification('No supplier tags available. Please create tags first.', 'warning');
    return;
  }
  
  // Show modal to select tags
  const selectedTagIds = await new Promise((resolve) => {
    // Create a simple modal for tag selection
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center';
    modal.style.zIndex = '9999';
    modal.innerHTML = `
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md" style="z-index: 10000;">
        <h2 class="text-2xl font-bold text-gray-800 mb-4">Add Tags to ${selectedSuppliers.value.length} Supplier(s)</h2>
        <div class="max-h-64 overflow-y-auto mb-4">
          ${availableTags.map(tag => `
            <label class="flex items-center gap-2 p-2 hover:bg-gray-50 cursor-pointer">
              <input type="checkbox" value="${tag.id}" class="tag-checkbox rounded">
              <span>${tag.name}</span>
            </label>
          `).join('')}
        </div>
        <div class="flex justify-end gap-3">
          <button class="cancel-tags-btn px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button class="apply-tags-btn px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">Apply</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    const cancelBtn = modal.querySelector('.cancel-tags-btn');
    const applyBtn = modal.querySelector('.apply-tags-btn');
    
    cancelBtn.onclick = () => {
      document.body.removeChild(modal);
      resolve([]);
    };
    
    applyBtn.onclick = () => {
      const checkboxes = modal.querySelectorAll('.tag-checkbox:checked');
      const tagIds = Array.from(checkboxes).map(cb => cb.value);
      document.body.removeChild(modal);
      resolve(tagIds);
    };
  });
  
  if (selectedTagIds.length === 0) return;
  
  try {
    // Add tags to all selected suppliers
    for (const supplierId of selectedSuppliers.value) {
      const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
      const existingTagIds = linkedTags ? JSON.parse(linkedTags) : [];
      
      // Add new tags (avoid duplicates)
      const newTagIds = [...new Set([...existingTagIds, ...selectedTagIds])];
      localStorage.setItem(`supplier_${supplierId}_tags`, JSON.stringify(newTagIds));
    }
    
    showNotification(`Tags added to ${selectedSuppliers.value.length} supplier(s)`, 'success');
    selectedSuppliers.value = [];
    showBulkActionsMenu.value = false;
  } catch (error) {
    console.error('Error adding tags:', error);
    showNotification('Error adding tags', 'error');
  }
};

const bulkRemoveTags = async () => {
  if (selectedSuppliers.value.length === 0) {
    showNotification('Please select suppliers to remove tags', 'warning');
    return;
  }
  
  // Get all tags that are linked to at least one selected supplier
  const allTagIds = new Set();
  for (const supplierId of selectedSuppliers.value) {
    const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
    if (linkedTags) {
      const tagIds = JSON.parse(linkedTags);
      tagIds.forEach(id => allTagIds.add(id));
    }
  }
  
  if (allTagIds.size === 0) {
    showNotification('No tags found on selected suppliers', 'warning');
    return;
  }
  
  // Load supplier tags
  const stored = localStorage.getItem('supplier_tags');
  const availableTags = stored ? JSON.parse(stored) : [];
  const tagsToShow = availableTags.filter(tag => allTagIds.has(tag.id));
  
  // Show modal to select tags to remove
  const selectedTagIds = await new Promise((resolve) => {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center';
    modal.style.zIndex = '9999';
    modal.innerHTML = `
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md" style="z-index: 10000;">
        <h2 class="text-2xl font-bold text-gray-800 mb-4">Remove Tags from ${selectedSuppliers.value.length} Supplier(s)</h2>
        <div class="max-h-64 overflow-y-auto mb-4">
          ${tagsToShow.map(tag => `
            <label class="flex items-center gap-2 p-2 hover:bg-gray-50 cursor-pointer">
              <input type="checkbox" value="${tag.id}" class="tag-checkbox rounded">
              <span>${tag.name}</span>
            </label>
          `).join('')}
        </div>
        <div class="flex justify-end gap-3">
          <button class="cancel-tags-btn px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button class="apply-tags-btn px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">Remove</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    const cancelBtn = modal.querySelector('.cancel-tags-btn');
    const applyBtn = modal.querySelector('.apply-tags-btn');
    
    cancelBtn.onclick = () => {
      document.body.removeChild(modal);
      resolve([]);
    };
    
    applyBtn.onclick = () => {
      const checkboxes = modal.querySelectorAll('.tag-checkbox:checked');
      const tagIds = Array.from(checkboxes).map(cb => cb.value);
      document.body.removeChild(modal);
      resolve(tagIds);
    };
  });
  
  if (selectedTagIds.length === 0) return;
  
  try {
    // Remove tags from all selected suppliers
    for (const supplierId of selectedSuppliers.value) {
      const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
      const existingTagIds = linkedTags ? JSON.parse(linkedTags) : [];
      
      // Remove selected tags
      const newTagIds = existingTagIds.filter(id => !selectedTagIds.includes(id));
      localStorage.setItem(`supplier_${supplierId}_tags`, JSON.stringify(newTagIds));
    }
    
    showNotification(`Tags removed from ${selectedSuppliers.value.length} supplier(s)`, 'success');
    selectedSuppliers.value = [];
    showBulkActionsMenu.value = false;
  } catch (error) {
    console.error('Error removing tags:', error);
    showNotification('Error removing tags', 'error');
  }
};

const bulkExportSuppliers = async () => {
  if (selectedSuppliers.value.length === 0) {
    showNotification('Please select suppliers to export.', 'warning');
    return;
  }
  
  try {
    // Get selected suppliers
    const suppliersToExport = suppliers.value.filter(s => selectedSuppliers.value.includes(s.id));
    
    if (suppliersToExport.length === 0) {
      showNotification('No suppliers found to export.', 'warning');
      return;
    }
    
    // Import XLSX
    const XLSX = await import('xlsx');
    
    // Create workbook
    const wb = XLSX.utils.book_new();
    const wsData = [
      ['Supplier ID', 'Name', 'Name Localized', 'Code', 'Contact Name', 'Phone', 'Primary Email', 'Additional Emails']
    ];
    
    suppliersToExport.forEach(supplier => {
      wsData.push([
        supplier.id || '',
        supplier.name || '',
        supplier.nameLocalized || supplier.name || '',
        supplier.code || '',
        supplier.contactName || '',
        supplier.phone || '',
        supplier.primaryEmail || '',
        supplier.additionalEmails || ''
      ]);
    });
    
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    XLSX.utils.book_append_sheet(wb, ws, 'Selected Suppliers');
    
    // Download
    const fileName = `Selected_Suppliers_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(wb, fileName);
    
    showNotification(`Successfully exported ${suppliersToExport.length} supplier(s)!`, 'success');
    selectedSuppliers.value = [];
    showBulkActionsMenu.value = false;
  } catch (error) {
    console.error('Error exporting suppliers:', error);
    showNotification('Error exporting suppliers. Please try again.', 'error');
  }
};

const previousPage = () => {
  if (currentPage.value > 1) {
    currentPage.value--;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

const nextPage = () => {
  if (currentPage.value < totalPages.value) {
    currentPage.value++;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
};

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
  currentPage.value = 1;
  closeFilterModal();
};

const clearFilter = () => {
  const emptyFilter = {
    name: '',
    nameMode: 'including',
    code: '',
    codeMode: 'including',
    contactName: '',
    contactNameMode: 'including',
    phone: '',
    phoneMode: 'including',
    email: '',
    emailMode: 'including',
    tag: '',
    tagMode: 'including',
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

const showImportModal = ref(false);
const showReviewModal = ref(false);
const showHeaderSelectModal = ref(false);
const importFile = ref(null);
const fileInput = ref(null);
const rawImportData = ref([]);
const selectedHeaderRow = ref(null);
const suppliersToImport = ref([]);
const reviewItems = ref([]);
const reviewSummary = ref({
  total: 0,
  clean: 0,
  withIssues: 0
});
const currentReviewPage = ref(1);
const reviewPageSize = ref(50);
const allIssues = ref({});
const selectedSupplierRow = ref(null);

const exportSuppliers = async () => {
  try {
    const suppliersToExport = filteredSuppliers.value.filter(s => !s.deleted);
    
    if (suppliersToExport.length === 0) {
      showNotification('No suppliers to export', 'warning');
      return;
    }
    
    // Import XLSX library
    const XLSX = await import('xlsx');
    
    // Create workbook
    const wb = XLSX.utils.book_new();
    const wsData = [
      ['name', 'code', 'contact_name', 'email', 'phone', 'additional_emails']
    ];
    
    suppliersToExport.forEach(supplier => {
      wsData.push([
        supplier.name || '',
        supplier.code || '',
        supplier.contactName || '',
        supplier.primaryEmail || '',
        supplier.phone || '',
        supplier.additionalEmails || ''
      ]);
    });
    
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    XLSX.utils.book_append_sheet(wb, ws, 'Suppliers');
    
    // Download
    const fileName = `Suppliers_${new Date().toISOString().split('T')[0]}.xlsx`;
    XLSX.writeFile(wb, fileName);
    
    showNotification(`Successfully exported ${suppliersToExport.length} supplier(s)!`, 'success');
  } catch (error) {
    console.error('Error exporting suppliers:', error);
    showNotification('Error exporting suppliers. Please try again.', 'error');
  }
};

const openImportModal = () => {
  showImportModal.value = true;
  importFile.value = null;
};

const closeImportModal = () => {
  showImportModal.value = false;
  importFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = '';
  }
};

const handleFileSelect = (event) => {
  const file = event.target.files[0];
  if (file) {
    importFile.value = file;
  }
};

const handleImport = async () => {
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
    const XLSX = await import('xlsx');
    const reader = new FileReader();
    
    reader.onerror = (error) => {
      console.error('FileReader error:', error);
      showNotification('Error reading file. Please try again.', 'error');
    };
    
    reader.onload = async (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        
        // Get first sheet
        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        
        // Convert to JSON array (raw data)
        const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: '' });
        
        if (jsonData.length < 2) {
          showNotification('Excel file is empty or has no data rows.', 'warning');
          return;
        }
        
        // Store raw data for header selection
        rawImportData.value = jsonData;
        
        // Default to first row as header (most common case)
        selectedHeaderRow.value = 0;
        
        // Show header selection modal
        closeImportModal();
        showHeaderSelectModal.value = true;
      } catch (error) {
        console.error('Error processing file:', error);
        showNotification('Error processing file. Please check the file format.', 'error');
      }
    };
    
    reader.readAsArrayBuffer(importFile.value);
  } catch (error) {
    console.error('Error importing suppliers:', error);
    showNotification('Error importing suppliers. Please try again.', 'error');
  }
};

const selectHeaderRow = (rowIndex) => {
  selectedHeaderRow.value = rowIndex;
};

const processImportData = () => {
  if (!rawImportData.value || rawImportData.value.length === 0) return;
  
  const headers = rawImportData.value[selectedHeaderRow.value].map(h => String(h).trim());
  
  // Process data rows (skip header row)
  const processedSuppliers = [];
  for (let i = selectedHeaderRow.value + 1; i < rawImportData.value.length; i++) {
    const row = rawImportData.value[i];
    if (!row || row.length === 0 || row.every(cell => !cell || String(cell).trim() === '')) continue;
    
    // Create supplier object from row
    const supplier = {};
    headers.forEach((header, index) => {
      const value = row[index];
      if (value !== undefined && value !== null && value !== '') {
        const headerLower = String(header).toLowerCase().trim();
        if (headerLower === 'supplier_id' || headerLower === 'supplier id') {
          supplier.supplier_id = String(value).trim();
        } else if (headerLower === 'name') {
          supplier.name = String(value).trim();
        } else if (headerLower === 'code') {
          supplier.code = String(value).trim();
        } else if (headerLower === 'contact_name' || headerLower === 'contact name') {
          supplier.contactName = String(value).trim();
        } else if (headerLower === 'email' || headerLower === 'primary email' || headerLower === 'primary_email') {
          supplier.primaryEmail = String(value).trim();
        } else if (headerLower === 'phone') {
          supplier.phone = String(value).trim();
        } else if (headerLower === 'additional_emails' || headerLower === 'additional emails') {
          supplier.additionalEmails = String(value).trim();
        }
      }
    });
    
    if (supplier.name && supplier.name.trim()) {
      processedSuppliers.push(supplier);
    }
  }
  
  if (processedSuppliers.length === 0) {
    showNotification('No valid suppliers found in the file.', 'warning');
    closeHeaderSelectModal();
    return;
  }
  
  // Show review screen
  showReviewDataScreen(processedSuppliers);
};

const showReviewDataScreen = (suppliers) => {
  closeHeaderSelectModal();
  
  // Validate suppliers and find issues
  const validatedSuppliers = suppliers.map((supplier, index) => {
    const issues = [];
    
    // Check for duplicate names in import batch
    if (supplier.name && supplier.name.trim() !== '') {
      const duplicateName = suppliers.filter((s, idx) => idx !== index && s.name && s.name.trim() === supplier.name.trim());
      if (duplicateName.length > 0) {
        issues.push({ field: 'name', message: 'Duplicate name in import file' });
      }
    }
    
    // Validate required fields
    if (!supplier.name || supplier.name.trim() === '') {
      issues.push({ field: 'name', message: 'Name is required' });
    }
    
    // Validate email format if provided
    if (supplier.primaryEmail && supplier.primaryEmail.trim() !== '') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(supplier.primaryEmail.trim())) {
        issues.push({ field: 'email', message: 'Invalid email format' });
      }
    }
    
    // Validate phone format if provided
    if (supplier.phone && supplier.phone.trim() !== '') {
      const phoneRegex = /^[\d\s\-\+\(\)]+$/;
      if (!phoneRegex.test(supplier.phone.trim())) {
        issues.push({ field: 'phone', message: 'Invalid phone format' });
      }
    }
    
    // Check for duplicate codes in import batch
    if (supplier.code && supplier.code.trim() !== '') {
      const duplicateCode = suppliers.filter((s, idx) => idx !== index && s.code && s.code.trim() === supplier.code.trim());
      if (duplicateCode.length > 0) {
        issues.push({ field: 'code', message: 'Duplicate code in import file' });
      }
    }
    
    return {
      ...supplier,
      rowNumber: index + 1,
      issues: issues,
      hasIssues: issues.length > 0
    };
  });
  
  // Calculate summary
  reviewSummary.value = {
    total: validatedSuppliers.length,
    clean: validatedSuppliers.filter(s => !s.hasIssues).length,
    withIssues: validatedSuppliers.filter(s => s.hasIssues).length
  };
  
  // Group issues by field
  allIssues.value = {};
  validatedSuppliers.forEach(supplier => {
    supplier.issues.forEach(issue => {
      if (!allIssues.value[issue.field]) {
        allIssues.value[issue.field] = [];
      }
      const issueKey = issue.message;
      if (!allIssues.value[issue.field].find(i => i.message === issueKey)) {
        allIssues.value[issue.field].push({
          message: issue.message,
          count: validatedSuppliers.filter(s => s.issues.some(i => i.field === issue.field && i.message === issueKey)).length
        });
      }
    });
  });
  
  reviewItems.value = validatedSuppliers;
  currentReviewPage.value = 1;
  showReviewModal.value = true;
};

const paginatedReviewItems = computed(() => {
  const start = (currentReviewPage.value - 1) * reviewPageSize.value;
  const end = start + reviewPageSize.value;
  return reviewItems.value.slice(start, end);
});

const closeHeaderSelectModal = () => {
  showHeaderSelectModal.value = false;
  rawImportData.value = [];
  selectedHeaderRow.value = 0;
};

const closeReviewModal = () => {
  showReviewModal.value = false;
  reviewItems.value = [];
  reviewSummary.value = { total: 0, clean: 0, withIssues: 0 };
  allIssues.value = {};
  currentReviewPage.value = 1;
};

// Import suppliers to Supabase (Final import after review)
const importSuppliersToSupabaseHandler = async (suppliers) => {
  // Ensure Supabase is ready
  const supabaseModule = await import('@/services/supabase');
  const { ensureSupabaseReady, importSuppliersToSupabase } = supabaseModule;
  const isSupabaseReady = await ensureSupabaseReady();
  
  if (!isSupabaseReady) {
    showNotification('Supabase not configured. Please refresh the page.', 'error', 5000);
    return;
  }
  
  try {
    const result = await importSuppliersToSupabase(suppliers);
    
    if (result.success && result.imported > 0) {
      let message = `✅ Successfully imported ${result.imported} supplier(s)!`;
      if (result.failed > 0) {
        message += `\n\n⚠️ ${result.failed} supplier(s) failed to import.`;
        if (result.errors && result.errors.length > 0) {
          console.error('Import errors:', result.errors);
        }
      }
      showNotification(message, 'success', 5000);
      closeReviewModal();
      // Reload suppliers table
      await loadSuppliers();
    } else {
      let errorMsg = `❌ Failed to import suppliers. ${result.failed > 0 ? result.failed + ' supplier(s) failed.' : ''}`;
      if (result.errors && result.errors.length > 0) {
        const uniqueErrors = [...new Set(result.errors.map(e => e.error))];
        errorMsg += '\n\nCommon errors:\n' + uniqueErrors.slice(0, 5).map(e => `- ${e}`).join('\n');
        if (result.errors[0].hint) {
          errorMsg += '\n\nHint: ' + result.errors[0].hint;
        }
        errorMsg += '\n\nPlease check the browser console for detailed error information.';
      }
      showNotification(errorMsg.replace(/\n\n/g, '. '), 'error', 8000);
      console.error('Import errors (detailed):', result.errors);
    }
    
  } catch (error) {
    console.error('Error importing suppliers:', error);
    showNotification('Error importing suppliers: ' + error.message, 'error', 5000);
  }
};

// Import button loading state
const isImporting = ref(false);

// Wrapper function for Import button click
const handleImportButtonClick = async (event) => {
  console.log('🔘 Import button clicked!', event);
  console.log('🔘 Button element:', event?.target);
  console.log('🔘 Current review items:', reviewItems.value.length);
  
  // Prevent multiple clicks
  if (isImporting.value) {
    console.log('⚠️ Import already in progress, ignoring click');
    return;
  }
  
  if (event) {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  }
  
  // Set loading state
  isImporting.value = true;
  
  // Update button text and disable it
  const button = document.getElementById('import-button-final');
  if (button) {
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Importing...';
    button.disabled = true;
    button.style.opacity = '0.7';
    button.style.cursor = 'not-allowed';
    
    console.log('✅ Event handled, calling finalizeImport...');
    try {
      await finalizeImport();
    } catch (error) {
      console.error('❌ Error in handleImportButtonClick:', error);
      showNotification('Error: ' + error.message, 'error');
      // Restore button
      button.innerHTML = originalText;
      button.disabled = false;
      button.style.opacity = '1';
      button.style.cursor = 'pointer';
    } finally {
      isImporting.value = false;
      // Restore button after a delay
      setTimeout(() => {
        if (button) {
          button.innerHTML = originalText;
          button.disabled = false;
          button.style.opacity = '1';
          button.style.cursor = 'pointer';
        }
      }, 1000);
    }
  } else {
    console.log('✅ Event handled, calling finalizeImport...');
    try {
      await finalizeImport();
    } catch (error) {
      console.error('❌ Error in handleImportButtonClick:', error);
      showNotification('Error: ' + error.message, 'error');
    } finally {
      isImporting.value = false;
    }
  }
};

const finalizeImport = async () => {
  console.log('🚀 finalizeImport function called');
  console.log('Review items count:', reviewItems.value.length);
  
  try {
    // Only import clean suppliers
    const cleanSuppliers = reviewItems.value.filter(s => !s.hasIssues);
    console.log('Clean suppliers count:', cleanSuppliers.length);
    
    if (cleanSuppliers.length === 0) {
      showNotification('No clean suppliers to import. Please fix the issues first.', 'warning');
      return;
    }
    
    // Ensure Supabase is ready
    const supabaseModule = await import('@/services/supabase');
    const { ensureSupabaseReady, supabaseClient } = supabaseModule;
    const isSupabaseReady = await ensureSupabaseReady();
    
    // Check for existing suppliers in Supabase to avoid duplicates
    if (isSupabaseReady && supabaseClient) {
      const { data: existingSuppliers } = await supabaseClient
        .from('suppliers')
        .select('name')
        .eq('deleted', false);
      
      // Filter out suppliers that already exist
      const suppliersToImport = cleanSuppliers.filter(newSupplier => {
        if (!newSupplier.name || !newSupplier.name.trim()) return false;
        const exists = existingSuppliers?.some(s => 
          s.name && newSupplier.name && 
          s.name.toLowerCase() === newSupplier.name.toLowerCase()
        );
        return !exists;
      });
      
      if (suppliersToImport.length === 0) {
        showNotification('All suppliers already exist in the database.', 'warning');
        return;
      }
      
      if (suppliersToImport.length < cleanSuppliers.length) {
        const skipped = cleanSuppliers.length - suppliersToImport.length;
        showNotification(`${skipped} supplier(s) already exist and will be skipped.`, 'info', 3000);
      }
      
      // Import to Supabase
      await importSuppliersToSupabaseHandler(suppliersToImport);
    } else {
      // Fallback to localStorage
    const stored = localStorage.getItem('suppliers');
    const existingSuppliers = stored ? JSON.parse(stored) : [];
    
    // Add new suppliers
    cleanSuppliers.forEach(newSupplier => {
      // Generate ID if not provided
      if (!newSupplier.supplier_id || !newSupplier.supplier_id.trim()) {
        newSupplier.id = `supplier-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      } else {
        newSupplier.id = newSupplier.supplier_id;
      }
      
      // Check if supplier with same name already exists
      const exists = existingSuppliers.find(s => 
        s.name && newSupplier.name && 
        s.name.toLowerCase() === newSupplier.name.toLowerCase() &&
        !s.deleted
      );
      
      if (!exists) {
        const supplierToAdd = {
          id: newSupplier.id,
          name: newSupplier.name,
          nameLocalized: newSupplier.nameLocalized || '',
          code: newSupplier.code || '',
          contactName: newSupplier.contactName || '',
          phone: newSupplier.phone || '',
          primaryEmail: newSupplier.primaryEmail || '',
          additionalEmails: newSupplier.additionalEmails || '',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          deleted: false
        };
        existingSuppliers.push(supplierToAdd);
      }
    });
    
    localStorage.setItem('suppliers', JSON.stringify(existingSuppliers));
    showNotification(`Successfully imported ${cleanSuppliers.length} supplier(s)! ${reviewSummary.value.withIssues > 0 ? `${reviewSummary.value.withIssues} supplier(s) with issues were skipped.` : ''}`, 'success');
    closeReviewModal();
    await loadSuppliers();
    }
  } catch (error) {
    console.error('Error finalizing import:', error);
    showNotification('Error importing suppliers. Please try again.', 'error');
  }
};

const downloadExcelTemplate = async () => {
  try {
    // Import XLSX library
    const XLSX = await import('xlsx');
    
    // Create workbook with template structure
    const wb = XLSX.utils.book_new();
    const wsData = [
      ['supplier_id', 'name', 'code', 'contact_name', 'email', 'phone', 'additional_emails']
    ];
    
    // Add sample row
    wsData.push([
      'SUP001',
      'Sample Supplier Name',
      'SUP001',
      'John Doe',
      'supplier@example.com',
      '1234567890',
      'additional@example.com'
    ]);
    
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    XLSX.utils.book_append_sheet(wb, ws, 'Suppliers');
    
    // Download
    const fileName = 'Suppliers_Template.xlsx';
    XLSX.writeFile(wb, fileName);
    
    showNotification('Template downloaded successfully!', 'success');
  } catch (error) {
    console.error('Error downloading template:', error);
    showNotification('Error downloading template. Please try again.', 'error');
  }
};

// Notification helper
const showNotification = (message, type = 'info', duration = 3000) => {
  // Use existing notification system from HomePortal
  if (window.showNotification) {
    window.showNotification(message, type, duration);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

// Watch for review modal opening to attach direct event listener as fallback
let importButtonListener = null;
watch(showReviewModal, (isOpen) => {
  if (isOpen) {
    // Wait for DOM to update
    setTimeout(() => {
      const button = document.getElementById('import-button-final');
      if (button) {
        console.log('✅ Import button found, attaching direct event listener');
        
        // Remove existing listener if any
        if (importButtonListener) {
          button.removeEventListener('click', importButtonListener);
        }
        
        // Add direct event listener as fallback
        importButtonListener = async (e) => {
          console.log('🔘 Direct event listener triggered!', e);
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          await handleImportButtonClick(e);
        };
        
        button.addEventListener('click', importButtonListener, { capture: true });
        console.log('✅ Direct event listener attached');
      } else {
        console.warn('⚠️ Import button not found in DOM');
      }
    }, 100);
  } else {
    // Clean up listener when modal closes
    if (importButtonListener) {
      const button = document.getElementById('import-button-final');
      if (button) {
        button.removeEventListener('click', importButtonListener);
      }
      importButtonListener = null;
    }
  }
});

onMounted(() => {
  const route = useRoute();
  console.log('🟢 [Suppliers.vue] Component MOUNTED', {
    fullPath: route.fullPath,
    path: route.path,
    name: route.name,
    matched: route.matched.map(r => ({ path: r.path, name: r.name })),
    params: route.params
  });
  loadSuppliers();
  
  // Check for tag filter in URL query or currentView
  const currentView = window.currentView || '';
  const tagMatch = currentView.match(/tag=([^&]+)/);
  if (tagMatch) {
    const tagName = decodeURIComponent(tagMatch[1]);
    filterCriteria.value.tag = tagName;
    filterCriteria.value.tagMode = 'including';
    // Open filter modal to show the applied filter
    setTimeout(() => {
      showFilterModal.value = true;
    }, 500);
  }
  
  // Also check route query if available
  if (route.query && route.query.tag) {
    const tagName = decodeURIComponent(route.query.tag);
    filterCriteria.value.tag = tagName;
    filterCriteria.value.tagMode = 'including';
    setTimeout(() => {
      showFilterModal.value = true;
    }, 500);
  }
  
  // Close bulk actions menu when clicking outside
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.relative') && !e.target.closest('.dropdown-menu')) {
      showBulkActionsMenu.value = false;
    }
    // Close import/export menu when clicking outside
    if (!e.target.closest('.relative') && !e.target.closest('.dropdown-menu')) {
      showImportExportMenu.value = false;
    }
  });
});

// Watch for route changes to apply tag filter
watch(() => route.query?.tag, (newTag) => {
  if (newTag) {
    const tagName = decodeURIComponent(newTag);
    filterCriteria.value.tag = tagName;
    filterCriteria.value.tagMode = 'including';
    setTimeout(() => {
      showFilterModal.value = true;
    }, 500);
  }
}, { immediate: true });
</script>

<style scoped>
.tab-button.active {
  border-bottom: 2px solid #9333ea;
  color: #9333ea;
  font-weight: 600;
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
  min-width: 150px;
  z-index: 1001 !important;
  pointer-events: auto !important;
}

.dropdown-menu a {
  display: block;
  padding: 0.75rem 1rem;
  color: #374151;
  text-decoration: none;
  transition: background-color 0.2s;
  cursor: pointer !important;
  pointer-events: auto !important;
  user-select: none;
}

.dropdown-menu a:hover {
  background-color: #f3f4f6;
}

.dropdown-menu a:active {
  background-color: #e5e7eb;
}
</style>

