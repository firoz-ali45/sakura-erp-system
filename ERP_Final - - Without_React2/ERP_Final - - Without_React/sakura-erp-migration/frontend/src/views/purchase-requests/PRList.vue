<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <h1 class="text-2xl font-bold text-gray-800">Purchase Requests</h1>
          <span class="text-gray-500 text-sm">(SAP MM Compliant)</span>
        </div>
        <div class="flex items-center gap-3">
          <button 
            @click="refreshData"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
            :disabled="loading"
          >
            <i :class="['fas fa-sync-alt', loading ? 'fa-spin' : '']"></i>
            <span>Refresh</span>
          </button>
          <button 
            @click="navigateToCreate"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
          >
            <i class="fas fa-plus"></i>
            <span>Create PR</span>
          </button>
        </div>
      </div>
    </div>

    <!-- KPI Cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4 mb-4">
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-gray-400">
        <div class="text-2xl font-bold text-gray-800">{{ dashboardStats.draft_count || 0 }}</div>
        <div class="text-sm text-gray-500">Draft</div>
      </div>
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-yellow-400">
        <div class="text-2xl font-bold text-yellow-600">{{ dashboardStats.pending_approval || 0 }}</div>
        <div class="text-sm text-gray-500">Pending Approval</div>
      </div>
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-green-400">
        <div class="text-2xl font-bold text-green-600">{{ dashboardStats.approved_count || 0 }}</div>
        <div class="text-sm text-gray-500">Approved</div>
      </div>
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-blue-400">
        <div class="text-2xl font-bold text-blue-600">{{ dashboardStats.partially_ordered || 0 }}</div>
        <div class="text-sm text-gray-500">Partially Ordered</div>
      </div>
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-purple-400">
        <div class="text-2xl font-bold text-purple-600">{{ dashboardStats.closed_count || 0 }}</div>
        <div class="text-sm text-gray-500">Closed</div>
      </div>
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-red-400">
        <div class="text-2xl font-bold text-red-600">{{ dashboardStats.overdue_count || 0 }}</div>
        <div class="text-sm text-gray-500">Overdue</div>
      </div>
    </div>

    <!-- Tabs and Filter -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex gap-4 border-b border-gray-200 overflow-x-auto">
          <button 
            v-for="tab in tabs"
            :key="tab.value"
            @click="switchTab(tab.value)"
            :class="['tab-button', 'px-4', 'py-2', 'text-gray-700', 'whitespace-nowrap', { 'active': activeTab === tab.value }]"
          >
            {{ tab.label }}
            <span v-if="tab.count !== undefined" class="ml-1 text-xs bg-gray-200 px-2 py-0.5 rounded-full">
              {{ tab.count }}
            </span>
          </button>
        </div>
        <div class="flex items-center gap-3">
          <div class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Search PR number, department..."
              class="w-64 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            />
            <i class="fas fa-search absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
          </div>
          <button 
            @click="hasActiveFilters ? clearFilter() : openFilter()" 
            :class="['px-4', 'py-2', 'border', 'rounded-lg', 'flex', 'items-center', 'gap-2', hasActiveFilters ? 'border-[#284b44] bg-[#f0e1cd]' : 'border-gray-300 hover:bg-gray-50']"
          >
            <i :class="hasActiveFilters ? 'fas fa-times-circle' : 'fas fa-filter'"></i>
            <span>{{ hasActiveFilters ? 'Clear Filter' : 'Filter' }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Bulk Actions -->
    <div v-if="selectedPRs.length > 0" class="bg-yellow-50 border border-yellow-200 rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-4">
          <span class="font-semibold text-gray-700">{{ selectedPRs.length }} selected</span>
          <button 
            @click="bulkApprove"
            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center gap-2"
            :disabled="!canBulkApprove"
          >
            <i class="fas fa-check"></i>
            <span>Approve</span>
          </button>
          <button 
            @click="bulkDelete"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center gap-2"
          >
            <i class="fas fa-trash"></i>
            <span>Delete</span>
          </button>
        </div>
        <button @click="clearSelection" class="text-gray-600 hover:text-gray-800">
          <i class="fas fa-times"></i> Clear Selection
        </button>
      </div>
    </div>

    <!-- PR Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-4 text-left w-12">
              <input 
                type="checkbox" 
                :checked="allSelected" 
                @change="toggleSelectAll"
                class="rounded border-gray-300"
              />
            </th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">PR Number</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Requester</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Department</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Status</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Priority</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Items</th>
            <th class="px-4 py-4 text-right text-sm font-semibold text-gray-700">Est. Value</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Required Date</th>
            <th class="px-4 py-4 text-left text-sm font-semibold text-gray-700">Linked POs</th>
            <th class="px-4 py-4 text-center text-sm font-semibold text-gray-700">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <!-- Loading State -->
          <tr v-if="loading" v-for="n in 5" :key="'skeleton-' + n" class="animate-pulse">
            <td class="px-4 py-4"><div class="h-4 w-4 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-32 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-24 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-20 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-6 w-20 bg-gray-200 rounded-full sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-6 w-16 bg-gray-200 rounded-full sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-8 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-20 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-24 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-16 bg-gray-200 rounded sakura-skeleton"></div></td>
            <td class="px-4 py-4"><div class="h-4 w-8 bg-gray-200 rounded sakura-skeleton mx-auto"></div></td>
          </tr>
          
          <!-- Empty State -->
          <tr v-else-if="!loading && filteredPRs.length === 0">
            <td colspan="11" class="px-6 py-12 text-center">
              <div class="flex flex-col items-center">
                <i class="fas fa-file-invoice text-6xl text-gray-300 mb-4"></i>
                <h3 class="text-lg font-medium text-gray-600 mb-2">No Purchase Requests Found</h3>
                <p class="text-gray-500 mb-4">Get started by creating your first purchase request</p>
                <button 
                  @click="navigateToCreate"
                  class="px-6 py-2 text-white rounded-lg sakura-primary-btn"
                >
                  <i class="fas fa-plus mr-2"></i>
                  Create PR
                </button>
              </div>
            </td>
          </tr>
          
          <!-- Data Rows -->
          <tr 
            v-else
            v-for="pr in paginatedPRs" 
            :key="pr.id"
            @click="viewPRDetail(pr)"
            class="hover:bg-gray-50 cursor-pointer"
            :class="{ 'bg-red-50': pr.is_overdue }"
          >
            <td class="px-4 py-4" @click.stop>
              <input 
                type="checkbox" 
                :checked="selectedPRs.includes(pr.id)"
                @change="toggleSelectPR(pr.id)"
                class="rounded border-gray-300"
              />
            </td>
            <td class="px-4 py-4 text-sm font-medium text-gray-900">
              {{ pr.pr_number }}
              <span v-if="pr.is_overdue" class="ml-2 text-xs text-red-600">
                <i class="fas fa-exclamation-circle"></i> Overdue
              </span>
            </td>
            <td class="px-4 py-4 text-sm text-gray-700">
              {{ pr.requester_name }}
            </td>
            <td class="px-4 py-4 text-sm text-gray-700">
              {{ pr.department }}
            </td>
            <td class="px-4 py-4">
              <span :class="['px-2 py-1 rounded-full text-xs font-semibold', getStatusClass(pr.status)]">
                {{ formatStatus(pr.status) }}
              </span>
            </td>
            <td class="px-4 py-4">
              <span :class="['px-2 py-1 rounded-full text-xs font-semibold', getPriorityClass(pr.priority)]">
                {{ formatPriority(pr.priority) }}
              </span>
            </td>
            <td class="px-4 py-4 text-sm text-gray-700">
              {{ pr.total_items || 0 }}
            </td>
            <td class="px-4 py-4 text-sm text-gray-900 font-semibold text-right">
              {{ formatCurrency(pr.estimated_total_value || 0) }}
            </td>
            <td class="px-4 py-4 text-sm text-gray-700">
              {{ formatDate(pr.required_date) }}
            </td>
            <td class="px-4 py-4 text-sm text-gray-700">
              <span v-if="pr.linked_po_count > 0" class="text-blue-600">
                {{ pr.linked_po_count }} PO(s)
              </span>
              <span v-else class="text-gray-400">-</span>
            </td>
            <td class="px-4 py-4 text-center" @click.stop>
              <div class="relative inline-block">
                <button 
                  @click.stop="toggleActions(pr.id)"
                  class="text-gray-600 hover:text-gray-900 p-2"
                >
                  <i class="fas fa-ellipsis-v"></i>
                </button>
                <div 
                  v-if="activeActions === pr.id" 
                  class="dropdown-menu"
                >
                  <a @click.stop="viewPRDetail(pr)"><i class="fas fa-eye mr-2 text-[#284b44]"></i>View Details</a>
                  <a v-if="pr.status === 'draft'" @click.stop="editPR(pr)"><i class="fas fa-edit mr-2 text-green-600"></i>Edit</a>
                  <a v-if="pr.status === 'draft'" @click.stop="submitPR(pr)"><i class="fas fa-paper-plane mr-2 text-blue-600"></i>Submit</a>
                  <a v-if="canApprove(pr)" @click.stop="approvePR(pr)"><i class="fas fa-check mr-2 text-green-600"></i>Approve</a>
                  <a v-if="canReject(pr)" @click.stop="openRejectModal(pr)"><i class="fas fa-times mr-2 text-red-600"></i>Reject</a>
                  <a v-if="canConvertToPO(pr)" @click.stop="navigateToConvert(pr)"><i class="fas fa-exchange-alt mr-2 text-purple-600"></i>Convert to PO</a>
                  <a v-if="pr.status === 'draft'" @click.stop="deletePR(pr)" class="text-red-600"><i class="fas fa-trash mr-2"></i>Delete</a>
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="mt-4 flex justify-between items-center bg-white rounded-lg shadow-md p-4">
      <div class="text-sm text-gray-700">
        Showing {{ (currentPage - 1) * pageSize + 1 }} to {{ Math.min(currentPage * pageSize, filteredPRs.length) }} of {{ filteredPRs.length }} requests
      </div>
      <div class="flex gap-2">
        <button 
          @click="currentPage--"
          :disabled="currentPage === 1"
          :class="['px-4 py-2 rounded-lg', currentPage === 1 ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          Previous
        </button>
        <span class="px-4 py-2 text-gray-700">Page {{ currentPage }} of {{ totalPages }}</span>
        <button 
          @click="currentPage++"
          :disabled="currentPage === totalPages"
          :class="['px-4 py-2 rounded-lg', currentPage === totalPages ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-white border border-gray-300 hover:bg-gray-50']"
        >
          Next
        </button>
      </div>
    </div>

    <!-- Filter Modal -->
    <div v-if="showFilterModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeFilter">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[80vh] overflow-y-auto m-4">
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">Filter Purchase Requests</h2>
          <button @click="closeFilter" class="text-gray-500 hover:text-gray-700">
            <i class="fas fa-times text-xl"></i>
          </button>
        </div>
        <div class="p-6 space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Department</label>
              <select v-model="filterCriteria.department" class="w-full px-4 py-2 border border-gray-300 rounded-lg">
                <option value="">All Departments</option>
                <option v-for="dept in departments" :key="dept" :value="dept">{{ dept }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
              <select v-model="filterCriteria.priority" class="w-full px-4 py-2 border border-gray-300 rounded-lg">
                <option value="">All Priorities</option>
                <option value="critical">Critical</option>
                <option value="urgent">Urgent</option>
                <option value="high">High</option>
                <option value="normal">Normal</option>
                <option value="low">Low</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
              <input v-model="filterCriteria.fromDate" type="date" class="w-full px-4 py-2 border border-gray-300 rounded-lg" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
              <input v-model="filterCriteria.toDate" type="date" class="w-full px-4 py-2 border border-gray-300 rounded-lg" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Min Value</label>
              <input v-model.number="filterCriteria.minValue" type="number" class="w-full px-4 py-2 border border-gray-300 rounded-lg" placeholder="0.00" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Max Value</label>
              <input v-model.number="filterCriteria.maxValue" type="number" class="w-full px-4 py-2 border border-gray-300 rounded-lg" placeholder="999999.99" />
            </div>
          </div>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" v-model="filterCriteria.overdueOnly" class="rounded border-gray-300" />
              <span class="text-sm text-gray-700">Show overdue only</span>
            </label>
          </div>
        </div>
        <div class="sticky bottom-0 bg-white border-t border-gray-200 p-6 flex justify-end gap-3">
          <button @click="clearFilter" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            Clear
          </button>
          <button @click="applyFilter" class="px-6 py-2 text-white rounded-lg sakura-primary-btn">
            Apply Filter
          </button>
        </div>
      </div>
    </div>

    <!-- Reject Modal -->
    <div v-if="showRejectModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="closeRejectModal">
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md m-4">
        <div class="p-6 border-b border-gray-200">
          <h2 class="text-xl font-bold text-gray-800">Reject Purchase Request</h2>
        </div>
        <div class="p-6">
          <p class="text-gray-600 mb-4">Please provide a reason for rejecting PR <strong>{{ rejectingPR?.pr_number }}</strong></p>
          <textarea
            v-model="rejectReason"
            rows="4"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
            style="--tw-ring-color: #284b44;"
            placeholder="Enter rejection reason (required)..."
          ></textarea>
        </div>
        <div class="p-6 border-t border-gray-200 flex justify-end gap-3">
          <button @click="closeRejectModal" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            Cancel
          </button>
          <button 
            @click="confirmReject" 
            :disabled="!rejectReason.trim()"
            class="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
          >
            Reject PR
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onActivated, watch } from 'vue';
import { useRouter } from 'vue-router';
import { 
  getPurchaseRequests, 
  getPRDashboardStats,
  submitPRForApproval,
  approvePurchaseRequest,
  rejectPurchaseRequest,
  deletePurchaseRequest
} from '@/services/purchaseRequests';
import { loadDepartmentsFromSupabase } from '@/services/supabase';

const router = useRouter();

// State
const purchaseRequests = ref([]);
const dashboardStats = ref({});
const loading = ref(false);
const activeTab = ref('all');
const searchQuery = ref('');
const selectedPRs = ref([]);
const activeActions = ref(null);
const currentPage = ref(1);
const pageSize = ref(25);

// Filter state
const showFilterModal = ref(false);
const filterCriteria = ref({
  department: '',
  priority: '',
  fromDate: '',
  toDate: '',
  minValue: null,
  maxValue: null,
  overdueOnly: false
});

// Reject modal state
const showRejectModal = ref(false);
const rejectingPR = ref(null);
const rejectReason = ref('');

// Departments from DB (single source of truth) - loaded on mount
const departments = ref([]);

// Tabs configuration
const tabs = computed(() => [
  { label: 'All', value: 'all', count: purchaseRequests.value.length },
  { label: 'Draft', value: 'draft', count: dashboardStats.value.draft_count },
  { label: 'Pending', value: 'submitted', count: dashboardStats.value.pending_approval },
  { label: 'Approved', value: 'approved', count: dashboardStats.value.approved_count },
  { label: 'Ordered', value: 'ordered', count: (dashboardStats.value.partially_ordered || 0) + (dashboardStats.value.fully_ordered || 0) },
  { label: 'Closed', value: 'closed', count: dashboardStats.value.closed_count },
  { label: 'Rejected', value: 'rejected', count: dashboardStats.value.rejected_count }
]);

// Computed
const filteredPRs = computed(() => {
  let result = [...purchaseRequests.value];
  
  // Tab filter
  if (activeTab.value !== 'all') {
    if (activeTab.value === 'ordered') {
      result = result.filter(pr => ['partially_ordered', 'fully_ordered'].includes(pr.status));
    } else {
      result = result.filter(pr => pr.status === activeTab.value);
    }
  }
  
  // Search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter(pr => 
      (pr.pr_number || '').toLowerCase().includes(query) ||
      (pr.department || '').toLowerCase().includes(query) ||
      (pr.requester_name || '').toLowerCase().includes(query)
    );
  }
  
  // Advanced filters
  if (filterCriteria.value.department) {
    result = result.filter(pr => pr.department === filterCriteria.value.department);
  }
  if (filterCriteria.value.priority) {
    result = result.filter(pr => pr.priority === filterCriteria.value.priority);
  }
  if (filterCriteria.value.fromDate) {
    result = result.filter(pr => pr.business_date >= filterCriteria.value.fromDate);
  }
  if (filterCriteria.value.toDate) {
    result = result.filter(pr => pr.business_date <= filterCriteria.value.toDate);
  }
  if (filterCriteria.value.minValue !== null) {
    result = result.filter(pr => (pr.estimated_total_value || 0) >= filterCriteria.value.minValue);
  }
  if (filterCriteria.value.maxValue !== null) {
    result = result.filter(pr => (pr.estimated_total_value || 0) <= filterCriteria.value.maxValue);
  }
  if (filterCriteria.value.overdueOnly) {
    result = result.filter(pr => pr.is_overdue);
  }
  
  return result;
});

const paginatedPRs = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  return filteredPRs.value.slice(start, start + pageSize.value);
});

const totalPages = computed(() => Math.ceil(filteredPRs.value.length / pageSize.value));

const allSelected = computed(() => {
  return paginatedPRs.value.length > 0 && 
         paginatedPRs.value.every(pr => selectedPRs.value.includes(pr.id));
});

const hasActiveFilters = computed(() => {
  return !!(filterCriteria.value.department || 
            filterCriteria.value.priority ||
            filterCriteria.value.fromDate ||
            filterCriteria.value.toDate ||
            filterCriteria.value.minValue !== null ||
            filterCriteria.value.maxValue !== null ||
            filterCriteria.value.overdueOnly);
});

const canBulkApprove = computed(() => {
  const selected = purchaseRequests.value.filter(pr => selectedPRs.value.includes(pr.id));
  return selected.length > 0 && selected.every(pr => ['submitted', 'under_review'].includes(pr.status));
});

// Methods
const loadData = async () => {
  console.log('============ PRList loadData START ============');
  loading.value = true;
  try {
    const [prs, stats, deptList] = await Promise.all([
      getPurchaseRequests(),
      getPRDashboardStats(),
      loadDepartmentsFromSupabase()
    ]);

    console.log('Loaded PRs:', prs);
    console.log('Loaded Stats:', stats);

    purchaseRequests.value = prs || [];
    dashboardStats.value = stats || {};
    departments.value = (deptList || []).map(d => (typeof d === 'object' ? (d.name || d.code || '') : String(d))).filter(Boolean);
    
    console.log('PR List updated. Count:', purchaseRequests.value.length);
    console.log('============ PRList loadData END ============');
  } catch (error) {
    console.error('Error loading PR data:', error);
    showNotification('Error loading purchase requests', 'error');
  } finally {
    loading.value = false;
  }
};

const refreshData = () => {
  console.log('Refreshing PR data...');
  loadData();
};

const switchTab = (tab) => {
  activeTab.value = tab;
  currentPage.value = 1;
  clearSelection();
};

const toggleSelectAll = () => {
  if (allSelected.value) {
    paginatedPRs.value.forEach(pr => {
      const index = selectedPRs.value.indexOf(pr.id);
      if (index > -1) selectedPRs.value.splice(index, 1);
    });
  } else {
    paginatedPRs.value.forEach(pr => {
      if (!selectedPRs.value.includes(pr.id)) {
        selectedPRs.value.push(pr.id);
      }
    });
  }
};

const toggleSelectPR = (prId) => {
  const index = selectedPRs.value.indexOf(prId);
  if (index > -1) {
    selectedPRs.value.splice(index, 1);
  } else {
    selectedPRs.value.push(prId);
  }
};

const clearSelection = () => {
  selectedPRs.value = [];
};

const toggleActions = (prId) => {
  activeActions.value = activeActions.value === prId ? null : prId;
};

// Navigation
const navigateToCreate = () => {
  router.push('/homeportal/pr-create');
};

const viewPRDetail = (pr) => {
  router.push(`/homeportal/pr-detail/${pr.id}`);
};

const editPR = (pr) => {
  router.push(`/homeportal/pr-create?edit=${pr.id}`);
};

const navigateToConvert = (pr) => {
  router.push(`/homeportal/pr-convert-to-po/${pr.id}`);
};

// Workflow actions
const submitPR = async (pr) => {
  try {
    const result = await submitPRForApproval(pr.id);
    if (result.success) {
      showNotification(`PR ${pr.pr_number} submitted for approval`, 'success');
      await loadData();
    } else {
      showNotification(result.error || 'Failed to submit PR', 'error');
    }
  } catch (error) {
    console.error('Error submitting PR:', error);
    showNotification('Error submitting PR', 'error');
  }
  activeActions.value = null;
};

const approvePR = async (pr) => {
  try {
    const result = await approvePurchaseRequest(pr.id);
    if (result.success) {
      showNotification(`PR ${pr.pr_number} approved`, 'success');
      await loadData();
    } else {
      showNotification(result.error || 'Failed to approve PR', 'error');
    }
  } catch (error) {
    console.error('Error approving PR:', error);
    showNotification('Error approving PR', 'error');
  }
  activeActions.value = null;
};

const openRejectModal = (pr) => {
  rejectingPR.value = pr;
  rejectReason.value = '';
  showRejectModal.value = true;
  activeActions.value = null;
};

const closeRejectModal = () => {
  showRejectModal.value = false;
  rejectingPR.value = null;
  rejectReason.value = '';
};

const confirmReject = async () => {
  if (!rejectReason.value.trim()) return;
  
  try {
    const result = await rejectPurchaseRequest(rejectingPR.value.id, rejectReason.value);
    if (result.success) {
      showNotification(`PR ${rejectingPR.value.pr_number} rejected`, 'success');
      closeRejectModal();
      await loadData();
    } else {
      showNotification(result.error || 'Failed to reject PR', 'error');
    }
  } catch (error) {
    console.error('Error rejecting PR:', error);
    showNotification('Error rejecting PR', 'error');
  }
};

const deletePR = async (pr) => {
  if (!confirm(`Are you sure you want to delete PR ${pr.pr_number}?`)) return;
  
  try {
    const result = await deletePurchaseRequest(pr.id);
    if (result.success) {
      showNotification(`PR ${pr.pr_number} deleted`, 'success');
      await loadData();
    } else {
      showNotification(result.error || 'Failed to delete PR', 'error');
    }
  } catch (error) {
    console.error('Error deleting PR:', error);
    showNotification('Error deleting PR', 'error');
  }
  activeActions.value = null;
};

const bulkApprove = async () => {
  if (!confirm(`Approve ${selectedPRs.value.length} purchase request(s)?`)) return;
  
  try {
    const results = await Promise.allSettled(
      selectedPRs.value.map(id => approvePurchaseRequest(id))
    );
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
    showNotification(`Approved ${successCount} of ${selectedPRs.value.length} PR(s)`, 'success');
    clearSelection();
    await loadData();
  } catch (error) {
    console.error('Error bulk approving:', error);
    showNotification('Error approving PRs', 'error');
  }
};

const bulkDelete = async () => {
  if (!confirm(`Delete ${selectedPRs.value.length} purchase request(s)?`)) return;
  
  try {
    const results = await Promise.allSettled(
      selectedPRs.value.map(id => deletePurchaseRequest(id))
    );
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
    showNotification(`Deleted ${successCount} of ${selectedPRs.value.length} PR(s)`, 'success');
    clearSelection();
    await loadData();
  } catch (error) {
    console.error('Error bulk deleting:', error);
    showNotification('Error deleting PRs', 'error');
  }
};

// Permission checks
const canApprove = (pr) => ['submitted', 'under_review'].includes(pr.status);
const canReject = (pr) => ['submitted', 'under_review'].includes(pr.status);
const canConvertToPO = (pr) => ['approved', 'partially_ordered'].includes(pr.status);

// Filter methods
const openFilter = () => showFilterModal.value = true;
const closeFilter = () => showFilterModal.value = false;
const applyFilter = () => {
  currentPage.value = 1;
  closeFilter();
};
const clearFilter = () => {
  filterCriteria.value = {
    department: '',
    priority: '',
    fromDate: '',
    toDate: '',
    minValue: null,
    maxValue: null,
    overdueOnly: false
  };
  currentPage.value = 1;
  closeFilter();
};

// Formatters
const formatStatus = (status) => {
  const map = {
    'draft': 'Draft',
    'submitted': 'Submitted',
    'under_review': 'Under Review',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'partially_ordered': 'Partially Ordered',
    'fully_ordered': 'Fully Ordered',
    'closed': 'Closed',
    'cancelled': 'Cancelled'
  };
  return map[status] || status;
};

const getStatusClass = (status) => {
  const map = {
    'draft': 'bg-gray-100 text-gray-800',
    'submitted': 'bg-yellow-100 text-yellow-800',
    'under_review': 'bg-orange-100 text-orange-800',
    'approved': 'bg-green-100 text-green-800',
    'rejected': 'bg-red-100 text-red-800',
    'partially_ordered': 'bg-blue-100 text-blue-800',
    'fully_ordered': 'bg-indigo-100 text-indigo-800',
    'closed': 'bg-purple-100 text-purple-800',
    'cancelled': 'bg-gray-100 text-gray-800'
  };
  return map[status] || 'bg-gray-100 text-gray-800';
};

const formatPriority = (priority) => {
  const map = {
    'low': 'Low',
    'normal': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
    'critical': 'Critical'
  };
  return map[priority] || priority;
};

const getPriorityClass = (priority) => {
  const map = {
    'low': 'bg-gray-100 text-gray-600',
    'normal': 'bg-blue-100 text-blue-600',
    'high': 'bg-yellow-100 text-yellow-600',
    'urgent': 'bg-orange-100 text-orange-600',
    'critical': 'bg-red-100 text-red-600'
  };
  return map[priority] || 'bg-gray-100 text-gray-600';
};

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'SAR'
  }).format(amount || 0);
};

const formatDate = (date) => {
  if (!date) return '-';
  return new Date(date).toLocaleDateString('en-GB', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
};

const showNotification = (message, type = 'info') => {
  if (window.showNotification) {
    window.showNotification(message, type);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

// Close dropdowns when clicking outside
onMounted(async () => {
  console.log('============ PRList MOUNTED ============');
  await loadData();
  
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.relative')) {
      activeActions.value = null;
    }
  });
});

// Watch for tab changes
watch(activeTab, () => {
  currentPage.value = 1;
});

// Reload data when route becomes active (e.g., returning from create page)
onActivated(async () => {
  console.log('============ PRList ACTIVATED (Route Re-entered) ============');
  await loadData();
});
</script>

<style scoped>
.tab-button.active {
  border-bottom: 2px solid #284b44;
  color: #284b44;
  font-weight: 600;
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
  min-width: 180px;
  z-index: 1000;
}

.dropdown-menu a {
  display: block;
  padding: 0.75rem 1rem;
  color: #374151;
  text-decoration: none;
  cursor: pointer;
  transition: background-color 0.2s;
}

.dropdown-menu a:hover {
  background-color: #f3f4f6;
}

@keyframes sakura-shimmer {
  0% { background-position: -1000px 0; }
  100% { background-position: 1000px 0; }
}

.sakura-skeleton {
  background: linear-gradient(90deg, #f3f4f6 0%, #e5e7eb 20%, #284b44 40%, #e5e7eb 60%, #f3f4f6 80%, #f3f4f6 100%);
  background-size: 1000px 100%;
  animation: sakura-shimmer 2s infinite;
  opacity: 0.7;
}
</style>
