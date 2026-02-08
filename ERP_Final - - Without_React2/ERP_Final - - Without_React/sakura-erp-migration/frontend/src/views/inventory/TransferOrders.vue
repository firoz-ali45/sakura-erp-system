<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.transferOrders.title') }}</h1>
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
              <a href="#" @click.prevent="exportAllTransferOrders"><i class="fas fa-download mr-2 text-green-600"></i>{{ $t('inventory.transferOrders.exportAll') }}</a>
              <a v-if="selectedOrders.length > 0" href="#" @click.prevent="exportSelectedTransferOrders"><i class="fas fa-download mr-2 text-blue-600"></i>{{ $t('inventory.purchaseOrders.exportSelected') }}</a>
            </div>
          </div>
          <button 
            @click="openCreateTOModal"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
          >
            <i class="fas fa-plus"></i>
            <span>{{ $t('inventory.transferOrders.create') }}</span>
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
            @click="switchTab('accepted')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'accepted' }]"
          >
            {{ $t('status.accepted') }}
          </button>
          <button 
            @click="switchTab('declined')"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', { 'active': activeTab === 'declined' }]"
          >
            {{ $t('status.declined') }}
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
          <i class="fas fa-times"></i> Clear Selection
        </button>
      </div>
    </div>

    <!-- Transfer Orders Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left">
                <input 
                  type="checkbox" 
                  :checked="isAllSelected"
                  @change="toggleSelectAll"
                  class="rounded border-gray-300"
                />
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reference</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Warehouse</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Destination</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Business Date</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
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
                <div class="h-4 w-4 bg-gray-200 rounded sakura-skeleton"></div>
              </td>
            </tr>
            <!-- Empty State -->
            <tr v-else-if="!loading && paginatedOrders.length === 0" class="hover:bg-gray-50">
              <td colspan="8" class="px-6 py-8 text-center text-gray-500">
                No transfer orders found
              </td>
            </tr>
            <!-- Data Rows -->
            <tr 
              v-else 
              v-for="order in paginatedOrders" 
              :key="order.id" 
              class="hover:bg-gray-50 cursor-pointer transition-colors"
              @click.self="viewOrder(order)"
              @click="handleRowClick(order, $event)"
            >
              <td class="px-6 py-4" @click.stop>
                <input 
                  type="checkbox" 
                  :value="order.id"
                  v-model="selectedOrders"
                  class="rounded border-gray-300"
                  @click.stop
                >
              </td>
              <td class="px-6 py-4 text-sm text-gray-900 font-medium" @click="viewOrder(order)">
                <span v-if="order.toNumber || order.to_number">{{ order.toNumber || order.to_number }}</span>
                <span v-else class="text-gray-400 italic">Draft</span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700" @click="viewOrder(order)">{{ order.warehouse || 'N/A' }}</td>
              <td class="px-6 py-4 text-sm text-gray-700" @click="viewOrder(order)">{{ order.destination || 'N/A' }}</td>
              <td class="px-6 py-4 text-sm" @click="viewOrder(order)">
                <span 
                  :class="[
                    'px-2 py-1 rounded-full text-xs font-semibold',
                    getStatusClass(order.status || 'draft')
                  ]"
                >
                  {{ formatStatus(order.status || 'draft') }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700" @click="viewOrder(order)">{{ formatDate(order.businessDate || order.business_date) }}</td>
              <td class="px-6 py-4 text-sm text-gray-700" @click="viewOrder(order)">{{ formatDateTime(order.createdAt || order.created_at) }}</td>
              <td class="px-6 py-4 text-sm" @click.stop>
                <div class="relative">
                  <button @click.stop="toggleOrderMenu(order.id)" class="text-gray-600 hover:text-gray-800">
                    <i class="fas fa-ellipsis-v"></i>
                  </button>
                  <div v-if="activeOrderActions === order.id" class="dropdown-menu" @click.stop>
                    <a @click.stop="viewOrder(order)" class="cursor-pointer"><i class="fas fa-eye mr-2 text-blue-600"></i>View</a>
                    <a v-if="order.status === 'draft'" @click.stop="editOrder(order)" class="cursor-pointer"><i class="fas fa-edit mr-2 text-green-600"></i>Edit</a>
                    <a href="#" @click.prevent="deleteOrder(order)"><i class="fas fa-trash mr-2 text-red-600"></i>Delete</a>
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
        Showing {{ (currentPage - 1) * limit + 1 }} to {{ Math.min(currentPage * limit, filteredOrders.length) }} of {{ filteredOrders.length }} orders
      </div>
      <div class="flex gap-2">
        <button 
          @click="previousPage"
          :disabled="currentPage === 1"
          :class="['px-4 py-2 rounded-lg', currentPage === 1 ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          Previous
        </button>
        <button 
          @click="nextPage"
          :disabled="currentPage === totalPages"
          :class="['px-4 py-2 rounded-lg', currentPage === totalPages ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          Next
        </button>
      </div>
    </div>

    <!-- Create/Edit Transfer Order Modal -->
    <div v-if="showTOModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeTOModal" style="pointer-events: auto;">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl m-4" style="pointer-events: auto;" @click.stop>
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center" @click.stop>
          <h2 class="text-2xl font-bold text-gray-800">{{ editingOrder ? 'Edit Transfer Order' : 'New Transfer Order' }}</h2>
          <button @click.stop="closeTOModal" class="text-gray-500 hover:text-gray-700" style="pointer-events: auto;">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        
        <div class="p-6" @click.stop>
          <form @submit.prevent="saveTransferOrder" @click.stop>
            <div class="grid grid-cols-2 gap-4 mb-6" @click.stop>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Warehouse <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" title="Select the source warehouse"></i>
                </label>
                <select 
                  v-model="newOrder.warehouse" 
                  required
                  @click.stop
                  @change="handleWarehouseChange"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="warehouse in availableWarehouses" :key="warehouse" :value="warehouse">
                    {{ warehouse }}
                  </option>
                </select>
              </div>
              <div @click.stop>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Destination <span class="text-red-500">*</span>
                  <i class="fas fa-info-circle text-gray-400 ml-1" title="Select the destination warehouse"></i>
                </label>
                <select 
                  v-model="newOrder.destination" 
                  required
                  @click.stop
                  @change="handleDestinationChange"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44; pointer-events: auto;"
                >
                  <option value="">Choose...</option>
                  <option v-for="destination in availableDestinations" :key="destination" :value="destination">
                    {{ destination }}
                  </option>
                </select>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200" @click.stop>
              <button 
                type="button"
                @click.stop="closeTOModal" 
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

    <!-- Advanced Filter Modal -->
    <div v-if="showFilterModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeFilter">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center z-10">
          <h2 class="text-2xl font-bold text-gray-800">Filter</h2>
          <button @click="closeFilter" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <!-- Text Input Fields with Including/Excluding -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Reference</label>
                <div class="flex gap-2">
                  <input 
                    v-model="tempFilterCriteria.toNumber"
                    type="text"
                    placeholder="Search by TO number..."
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                  <select 
                    v-model="tempFilterCriteria.toNumberMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Business Date</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.status"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">Any</option>
                    <option value="draft">Draft</option>
                    <option value="pending">Pending</option>
                    <option value="accepted">Accepted</option>
                    <option value="declined">Declined</option>
                    <option value="closed">Closed</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.statusMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Warehouse</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.warehouse"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">Any</option>
                    <option v-for="warehouse in warehouseOptions" :key="warehouse" :value="warehouse">
                      {{ warehouse }}
                    </option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.warehouseMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Destination</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.destination"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">Any</option>
                    <option v-for="loc in locationOptionsForFilter" :key="loc" :value="loc">{{ loc }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.destinationMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Creator</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.creator"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">Any</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.creatorMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Submitter</label>
                <div class="flex gap-2">
                  <select 
                    v-model="tempFilterCriteria.submitter"
                    class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="">Any</option>
                    <option v-for="user in availableUsers" :key="user" :value="user">{{ user }}</option>
                  </select>
                  <select 
                    v-model="tempFilterCriteria.submitterMode"
                    class="w-32 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 text-sm"
                    style="--tw-ring-color: #284b44;"
                  >
                    <option value="including">Including</option>
                    <option value="excluding">Excluding</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Date Fields -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Updated After</label>
                <input 
                  v-model="tempFilterCriteria.updatedAfter"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
                  style="--tw-ring-color: #284b44;"
                >
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-6 mt-6 border-t border-gray-200">
            <button 
              @click="closeFilter" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              @click="applyFilter" 
              class="px-6 py-2 text-white rounded-lg sakura-primary-btn"
            >
              Apply
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
import { useAuthStore } from '@/stores/auth';
import { 
  loadTransferOrdersFromSupabase, 
  saveTransferOrderToSupabase, 
  updateTransferOrderInSupabase,
  deleteTransferOrderFromSupabase
} from '@/services/supabase';
import { showNotification } from '@/utils/notifications';
import * as XLSX from 'xlsx';
import { useI18n } from '@/composables/useI18n';
import { useInventoryLocations } from '@/composables/useInventoryLocations';

const router = useRouter();
const authStore = useAuthStore();
const { t, locale } = useI18n();
const { loadLocationsForTransferSource, loadLocationsForTransferDest } = useInventoryLocations();

// State
const transferOrders = ref([]);
const loading = ref(false);
const activeTab = ref('all');
const selectedOrders = ref([]);
const showBulkActionsMenu = ref(false);
const showExportMenu = ref(false);
const showTOModal = ref(false);
const showFilterModal = ref(false);
const editingOrder = ref(null);
const activeOrderActions = ref(null);
const saving = ref(false);
const currentPage = ref(1);
const limit = ref(50);

// Filter criteria
const filterCriteria = ref({});
const tempFilterCriteria = ref({});

// Source/dest: inventory_locations only. Source = allow_transfer_out, Dest = is_active
const transferSourceOptions = ref([]);
const transferDestOptions = ref([]);

// New order form
const newOrder = ref({
  warehouse: '',
  destination: '',
  status: 'draft',
  items: []
});

const availableWarehouses = computed(() => {
  const list = transferSourceOptions.value;
  if (!newOrder.value.destination) return list;
  return list.filter(w => w !== newOrder.value.destination);
});

const availableDestinations = computed(() => {
  const list = transferDestOptions.value;
  if (!newOrder.value.warehouse) return list;
  return list.filter(d => d !== newOrder.value.warehouse);
});

const locationOptionsForFilter = computed(() => transferDestOptions.value);

// Get available users from transfer orders
const availableUsers = computed(() => {
  const users = new Set();
  transferOrders.value.forEach(order => {
    if (order.creator) users.add(order.creator);
    if (order.submitter) users.add(order.submitter);
    if (order.accepter) users.add(order.accepter);
    if (order.decliner) users.add(order.decliner);
  });
  return Array.from(users).sort();
});

// Computed
const filteredOrders = computed(() => {
  let filtered = transferOrders.value;
  
  // Tab filter
  if (activeTab.value === 'draft') {
    filtered = filtered.filter(o => (o.status || '').toLowerCase() === 'draft');
  } else if (activeTab.value === 'pending') {
    filtered = filtered.filter(o => (o.status || '').toLowerCase() === 'pending');
  } else if (activeTab.value === 'accepted') {
    filtered = filtered.filter(o => (o.status || '').toLowerCase() === 'accepted');
  } else if (activeTab.value === 'declined') {
    filtered = filtered.filter(o => (o.status || '').toLowerCase() === 'declined');
  } else if (activeTab.value === 'closed') {
    filtered = filtered.filter(o => (o.status || '').toLowerCase() === 'closed');
  }
  
  // Apply advanced filters
  const criteria = filterCriteria.value;
  
  // Reference (TO Number)
  if (criteria.toNumber) {
    const toNumber = String(criteria.toNumber).toLowerCase();
    const mode = criteria.toNumberMode || 'including';
    filtered = filtered.filter(o => {
      const orderToNumber = (o.toNumber || o.to_number || '').toLowerCase();
      const matches = orderToNumber.includes(toNumber);
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Business Date
  if (criteria.businessDate) {
    filtered = filtered.filter(o => {
      const orderDate = o.businessDate || o.business_date;
      if (!orderDate) return false;
      return orderDate.startsWith(criteria.businessDate);
    });
  }
  
  // Status
  if (criteria.status) {
    const mode = criteria.statusMode || 'including';
    filtered = filtered.filter(o => {
      const orderStatus = (o.status || '').toLowerCase();
      const matches = orderStatus === criteria.status.toLowerCase();
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Warehouse
  if (criteria.warehouse) {
    const mode = criteria.warehouseMode || 'including';
    filtered = filtered.filter(o => {
      const orderWarehouse = (o.warehouse || '').trim();
      const matches = orderWarehouse === criteria.warehouse;
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Destination
  if (criteria.destination) {
    const mode = criteria.destinationMode || 'including';
    filtered = filtered.filter(o => {
      const orderDestination = (o.destination || '').trim();
      const matches = orderDestination === criteria.destination;
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Creator
  if (criteria.creator) {
    const mode = criteria.creatorMode || 'including';
    filtered = filtered.filter(o => {
      const orderCreator = (o.creator || '').trim();
      const matches = orderCreator === criteria.creator;
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Submitter
  if (criteria.submitter) {
    const mode = criteria.submitterMode || 'including';
    filtered = filtered.filter(o => {
      const orderSubmitter = (o.submitter || '').trim();
      const matches = orderSubmitter === criteria.submitter;
      return mode === 'including' ? matches : !matches;
    });
  }
  
  // Updated After
  if (criteria.updatedAfter) {
    filtered = filtered.filter(o => {
      const updatedAt = o.updatedAt || o.updated_at || o.createdAt || o.created_at;
      if (!updatedAt) return false;
      return updatedAt >= criteria.updatedAfter;
    });
  }
  
  return filtered;
});

const paginatedOrders = computed(() => {
  const start = (currentPage.value - 1) * limit.value;
  return filteredOrders.value.slice(start, start + limit.value);
});

const totalPages = computed(() => {
  return Math.ceil(filteredOrders.value.length / limit.value);
});

const isAllSelected = computed(() => {
  return paginatedOrders.value.length > 0 && 
         paginatedOrders.value.every(order => selectedOrders.value.includes(order.id));
});

const hasActiveFilters = computed(() => {
  const criteria = filterCriteria.value;
  return !!(
    criteria.toNumber ||
    criteria.businessDate ||
    criteria.status ||
    criteria.warehouse ||
    criteria.destination ||
    criteria.creator ||
    criteria.submitter ||
    criteria.updatedAfter
  );
});

const activeFiltersCount = computed(() => {
  const criteria = filterCriteria.value;
  let count = 0;
  if (criteria.toNumber) count++;
  if (criteria.businessDate) count++;
  if (criteria.status) count++;
  if (criteria.warehouse) count++;
  if (criteria.destination) count++;
  if (criteria.creator) count++;
  if (criteria.submitter) count++;
  if (criteria.updatedAfter) count++;
  return count;
});

// Methods
const loadTransferOrders = async () => {
  loading.value = true;
  try {
    const orders = await loadTransferOrdersFromSupabase();
    transferOrders.value = orders || [];
    console.log('✔ Transfer Orders loaded:', transferOrders.value.length);
  } catch (error) {
    console.error('❌ Error loading transfer orders:', error);
    showNotification('Error loading transfer orders', 'error');
  } finally {
    loading.value = false;
  }
};

const switchTab = (tab) => {
  activeTab.value = tab;
  currentPage.value = 1;
  selectedOrders.value = [];
};

const openCreateTOModal = () => {
  editingOrder.value = null;
  newOrder.value = {
    warehouse: '',
    destination: '',
    status: 'draft',
    items: []
  };
  showTOModal.value = true;
};

const closeTOModal = () => {
  showTOModal.value = false;
  editingOrder.value = null;
};

const saveTransferOrder = async () => {
  if (!newOrder.value.warehouse) {
    showNotification('Please select a warehouse', 'warning');
    return;
  }
  
  if (!newOrder.value.destination) {
    showNotification('Please select a destination', 'warning');
    return;
  }
  
  saving.value = true;
  try {
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
    
    const currentUserName = getCurrentUserName();
    
    const orderData = {
      warehouse: newOrder.value.warehouse,
      destination: newOrder.value.destination,
      status: newOrder.value.status,
      items: newOrder.value.items || [],
      creator: currentUserName,
      createdAt: new Date().toISOString()
    };
    
    let result;
    if (editingOrder.value) {
      result = await updateTransferOrderInSupabase(editingOrder.value.id, orderData);
    } else {
      result = await saveTransferOrderToSupabase(orderData);
    }
    
    if (result.success) {
      showNotification(editingOrder.value ? 'Transfer order updated successfully' : 'Transfer order created successfully', 'success');
      closeTOModal();
      await loadTransferOrders();
      // Navigate to detail page
      if (result.data && result.data.id) {
        router.push(`/transfer-order-detail/${result.data.id}`);
      }
    } else {
      throw new Error(result.error || 'Failed to save transfer order');
    }
  } catch (error) {
    console.error('Error saving transfer order:', error);
    showNotification('Error saving transfer order: ' + (error.message || 'Unknown error'), 'error');
  } finally {
    saving.value = false;
  }
};

const handleRowClick = (order, event) => {
  // Don't navigate if clicking on checkbox, actions button, or dropdown
  if (event.target.closest('input[type="checkbox"]') || 
      event.target.closest('button') || 
      event.target.closest('.dropdown-menu')) {
    return;
  }
  viewOrder(order);
};

const viewOrder = (order) => {
  if (!order || !order.id) {
    console.error('Invalid order:', order);
    showNotification('Invalid transfer order', 'error');
    return;
  }
  router.push(`/homeportal/transfer-order-detail/${order.id}`);
};

const handleWarehouseChange = () => {
  // If destination is same as selected warehouse, clear it
  if (newOrder.value.destination === newOrder.value.warehouse) {
    newOrder.value.destination = '';
  }
};

const handleDestinationChange = () => {
  // If warehouse is same as selected destination, clear it
  if (newOrder.value.warehouse === newOrder.value.destination) {
    newOrder.value.warehouse = '';
  }
};

const editOrder = (order) => {
  editingOrder.value = order;
  newOrder.value = {
    warehouse: order.warehouse || '',
    destination: order.destination || '',
    status: order.status || 'draft',
    items: order.items || []
  };
  showTOModal.value = true;
};

const deleteOrder = async (order) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Transfer Order',
    message: 'Are you sure you want to delete this transfer order?',
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });
  
  if (!confirmed) return;
  
  try {
    const result = await deleteTransferOrderFromSupabase(order.id);
    if (result.success) {
      showNotification('Transfer order deleted successfully', 'success');
      await loadTransferOrders();
    } else {
      throw new Error(result.error || 'Failed to delete transfer order');
    }
  } catch (error) {
    console.error('Error deleting transfer order:', error);
    showNotification('Error deleting transfer order: ' + (error.message || 'Unknown error'), 'error');
  }
};

const toggleOrderMenu = (orderId) => {
  activeOrderActions.value = activeOrderActions.value === orderId ? null : orderId;
};

const toggleSelectAll = () => {
  if (isAllSelected.value) {
    selectedOrders.value = selectedOrders.value.filter(id => !paginatedOrders.value.some(o => o.id === id));
  } else {
    const newSelections = paginatedOrders.value.map(o => o.id).filter(id => !selectedOrders.value.includes(id));
    selectedOrders.value = [...selectedOrders.value, ...newSelections];
  }
};

const clearSelection = () => {
  selectedOrders.value = [];
};

const toggleBulkActionsMenu = () => {
  showBulkActionsMenu.value = !showBulkActionsMenu.value;
};

const toggleExportMenu = () => {
  showExportMenu.value = !showExportMenu.value;
};

const bulkDeleteOrders = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Transfer Orders',
    message: `Are you sure you want to delete ${selectedOrders.value.length} transfer order(s)?`,
    type: 'danger',
    confirmText: 'Delete',
    cancelText: 'Cancel'
  });
  
  if (!confirmed) return;
  
  try {
    for (const orderId of selectedOrders.value) {
      await deleteTransferOrderFromSupabase(orderId);
    }
    showNotification(`${selectedOrders.value.length} transfer order(s) deleted successfully`, 'success');
    selectedOrders.value = [];
    await loadTransferOrders();
  } catch (error) {
    console.error('Error deleting transfer orders:', error);
    showNotification('Error deleting transfer orders', 'error');
  }
};

const bulkExportOrders = () => {
  const ordersToExport = transferOrders.value.filter(o => selectedOrders.value.includes(o.id));
  exportTransferOrders(ordersToExport);
};

const exportAllTransferOrders = () => {
  exportTransferOrders(filteredOrders.value);
};

const exportSelectedTransferOrders = () => {
  const ordersToExport = transferOrders.value.filter(o => selectedOrders.value.includes(o.id));
  exportTransferOrders(ordersToExport);
};

const exportTransferOrders = (orders) => {
  const data = orders.map(order => ({
    'Reference': order.toNumber || order.to_number || 'Draft',
    'Warehouse': order.warehouse || 'N/A',
    'Destination': order.destination || 'N/A',
    'Status': formatStatus(order.status || 'draft'),
    'Business Date': formatDate(order.businessDate || order.business_date),
    'Created': formatDateTime(order.createdAt || order.created_at),
    'Creator': order.creator || 'N/A',
    'Number of Items': (order.items || []).length
  }));
  
  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Transfer Orders');
  XLSX.writeFile(wb, `transfer_orders_${new Date().toISOString().split('T')[0]}.xlsx`);
  showNotification('Transfer orders exported successfully', 'success');
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
  if (!date) return '—';
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

const openFilter = () => {
  // Copy current filter criteria to temp
  tempFilterCriteria.value = JSON.parse(JSON.stringify(filterCriteria.value));
  showFilterModal.value = true;
};

const closeFilter = () => {
  showFilterModal.value = false;
};

const applyFilter = () => {
  // Copy temp filter criteria back to actual filter criteria
  filterCriteria.value = JSON.parse(JSON.stringify(tempFilterCriteria.value));
  currentPage.value = 1; // Reset to first page
  closeFilter();
};

const clearFilter = () => {
  filterCriteria.value = {};
  tempFilterCriteria.value = {};
  currentPage.value = 1; // Reset to first page
};

onMounted(async () => {
  transferSourceOptions.value = await loadLocationsForTransferSource();
  transferDestOptions.value = await loadLocationsForTransferDest();
  loadTransferOrders();
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
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  min-width: 180px;
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

.sakura-primary-btn {
  background-color: #284b44;
  color: white;
}

.sakura-primary-btn:hover {
  background-color: #1f3d37;
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

