<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <!-- Header Section -->
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold text-gray-800">{{ t('inventory.purchasing.title') }}</h1>
        <p class="text-gray-600 mt-1">{{ t('inventory.purchasing.subtitle') }}</p>
      </div>
      <div class="flex gap-3">
        <button 
          @click="refreshData"
          class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
        >
          <i class="fas fa-sync-alt"></i>
          <span>{{ t('common.refresh') || 'Refresh' }}</span>
        </button>
      </div>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-blue-500">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-gray-500 text-sm">{{ t('inventory.purchasing.totalInvoices') }}</p>
            <p class="text-2xl font-bold text-gray-800">{{ stats.total }}</p>
          </div>
          <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
            <i class="fas fa-file-invoice-dollar text-blue-600 text-xl"></i>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-yellow-500">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-gray-500 text-sm">{{ t('inventory.purchasing.draftInvoices') }}</p>
            <p class="text-2xl font-bold text-yellow-600">{{ stats.draft }}</p>
          </div>
          <div class="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center">
            <i class="fas fa-edit text-yellow-600 text-xl"></i>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-green-500">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-gray-500 text-sm">{{ t('inventory.purchasing.approvedInvoices') }}</p>
            <p class="text-2xl font-bold text-green-600">{{ stats.approved }}</p>
          </div>
          <div class="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
            <i class="fas fa-check-circle text-green-600 text-xl"></i>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow-md p-4 border-l-4 border-red-500">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-gray-500 text-sm">{{ t('inventory.purchasing.overdueInvoices') }}</p>
            <p class="text-2xl font-bold text-red-600">{{ stats.overdue }}</p>
          </div>
          <div class="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
            <i class="fas fa-exclamation-triangle text-red-600 text-xl"></i>
          </div>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-6">
      <div class="flex flex-wrap gap-4 items-center">
        <div class="flex-1 min-w-[200px]">
          <div class="relative">
            <i class="fas fa-search absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
            <input 
              v-model="searchQuery"
              type="text"
              :placeholder="t('inventory.purchasing.searchPlaceholder')"
              class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
            />
          </div>
        </div>
        
        <select 
          v-model="statusFilter"
          class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
        >
          <option value="all">{{ t('common.all') }}</option>
          <option value="draft">{{ t('status.draft') }}</option>
          <option value="pending_approval">{{ t('status.pending') }}</option>
          <option value="approved">{{ t('status.approved') }}</option>
          <option value="posted">{{ t('inventory.purchasing.posted') }}</option>
        </select>
        
        <select 
          v-model="paymentFilter"
          class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
        >
          <option value="all">{{ t('inventory.purchasing.allPayments') }}</option>
          <option value="unpaid">{{ t('inventory.purchasing.unpaid') }}</option>
          <option value="partial">{{ t('inventory.purchasing.partialPaid') }}</option>
          <option value="paid">{{ t('inventory.purchasing.paid') }}</option>
          <option value="overdue">{{ t('inventory.purchasing.overdue') }}</option>
        </select>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="bg-white rounded-lg shadow-md p-8 text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-[#284b44] mx-auto mb-4"></div>
      <p class="text-gray-600">{{ t('common.loading') }}</p>
    </div>

    <!-- Empty State -->
    <div v-else-if="filteredInvoices.length === 0" class="bg-white rounded-lg shadow-md p-8 text-center">
      <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <i class="fas fa-file-invoice-dollar text-gray-400 text-3xl"></i>
      </div>
      <h3 class="text-lg font-semibold text-gray-800 mb-2">{{ t('inventory.purchasing.noInvoices') }}</h3>
      <p class="text-gray-500 mb-4">{{ t('inventory.purchasing.noInvoicesDesc') }}</p>
    </div>

    <!-- Invoices Table -->
    <div v-else class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white">
          <tr>
            <th class="px-4 py-4 text-left text-sm font-semibold">Doc Number</th>
            <th class="px-4 py-4 text-left text-sm font-semibold">Vendor Invoice</th>
            <th class="px-4 py-4 text-left text-sm font-semibold">{{ t('inventory.purchasing.supplier') }}</th>
            <th class="px-4 py-4 text-left text-sm font-semibold">References</th>
            <th class="px-4 py-4 text-left text-sm font-semibold">Payment Method</th>
            <th class="px-4 py-4 text-right text-sm font-semibold">{{ t('inventory.purchasing.grandTotal') }}</th>
            <th class="px-4 py-4 text-center text-sm font-semibold">{{ t('inventory.purchasing.status') }}</th>
            <th class="px-4 py-4 text-center text-sm font-semibold">Payment</th>
            <th class="px-4 py-4 text-center text-sm font-semibold">{{ t('common.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr 
            v-for="invoice in filteredInvoices" 
            :key="invoice.id"
            class="hover:bg-gray-50 transition-colors cursor-pointer"
            @click="viewInvoice(invoice.id)"
          >
            <!-- Purchasing Doc Number (PUR-XXXXXX) -->
            <td class="px-4 py-4">
              <span class="px-3 py-1 bg-[#284b44] text-white rounded-lg text-sm font-bold">
                {{ invoice.purchasing_number || invoice.invoice_number || 'Draft' }}
              </span>
            </td>
            <!-- Vendor Invoice Number -->
            <td class="px-4 py-4 text-sm">
              <span v-if="invoice.vendor_invoice_number" class="font-medium text-gray-800">
                {{ invoice.vendor_invoice_number }}
              </span>
              <span v-else class="text-gray-400 italic">Not entered</span>
            </td>
            <!-- Supplier -->
            <td class="px-4 py-4 text-sm text-gray-800 font-medium">
              {{ invoice.supplier_name || 'N/A' }}
            </td>
            <!-- References (GRN & PO) -->
            <td class="px-4 py-4 text-sm text-gray-600">
              <div class="flex flex-col">
                <span v-if="invoice.grn_number" class="font-medium text-green-700">
                  <i class="fas fa-clipboard-check text-xs mr-1"></i>{{ invoice.grn_number }}
                </span>
                <span v-if="invoice.purchase_order_number" class="text-xs text-blue-600">
                  <i class="fas fa-file-invoice text-xs mr-1"></i>{{ invoice.purchase_order_number }}
                </span>
              </div>
            </td>
            <!-- Payment Method -->
            <td class="px-4 py-4 text-sm">
              <span :class="getPaymentMethodClass(invoice.payment_method)" class="px-2 py-1 rounded text-xs font-semibold">
                {{ formatPaymentMethod(invoice.payment_method) }}
              </span>
            </td>
            <!-- Grand Total -->
            <td class="px-4 py-4 text-sm font-bold text-gray-900 text-right">
              {{ formatCurrency(invoice.grand_total || invoice.total_amount || 0) }}
            </td>
            <!-- Status -->
            <td class="px-4 py-4 text-center">
              <span :class="getStatusClass(invoice.status)" class="px-3 py-1 rounded-full text-xs font-semibold">
                {{ formatStatus(invoice.status) }}
              </span>
            </td>
            <!-- Payment Status -->
            <td class="px-4 py-4 text-center">
              <span :class="getPaymentStatusClass(invoice.payment_status, invoice.due_date)" class="px-3 py-1 rounded-full text-xs font-semibold">
                {{ formatPaymentStatus(invoice.payment_status, invoice.due_date) }}
              </span>
            </td>
            <!-- Actions -->
            <td class="px-4 py-4 text-center">
              <div class="flex items-center justify-center gap-2">
                <button 
                  @click.stop="viewInvoice(invoice.id)"
                  class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                  :title="t('common.view')"
                >
                  <i class="fas fa-eye"></i>
                </button>
                <button 
                  v-if="invoice.status === 'draft'"
                  @click.stop="editInvoice(invoice.id)"
                  class="p-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors"
                  :title="t('common.edit')"
                >
                  <i class="fas fa-edit"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      
      <!-- Pagination -->
      <div class="px-6 py-4 border-t border-gray-200 flex items-center justify-between">
        <div class="text-sm text-gray-600">
          {{ t('inventory.purchasing.showing') }} {{ filteredInvoices.length }} {{ t('inventory.purchasing.of') }} {{ invoices.length }} {{ t('inventory.purchasing.invoices') }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const router = useRouter();

// State
const invoices = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const statusFilter = ref('all');
const paymentFilter = ref('all');

// Stats
const stats = computed(() => {
  const today = new Date().toISOString().split('T')[0];
  return {
    total: invoices.value.length,
    draft: invoices.value.filter(i => i.status === 'draft').length,
    approved: invoices.value.filter(i => i.status === 'approved' || i.status === 'posted').length,
    overdue: invoices.value.filter(i => 
      i.payment_status === 'unpaid' && 
      i.due_date && 
      i.due_date < today
    ).length
  };
});

// Filtered invoices
const filteredInvoices = computed(() => {
  let result = [...invoices.value];
  
  // Search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter(inv => 
      (inv.invoice_number || '').toLowerCase().includes(query) ||
      (inv.grn_number || '').toLowerCase().includes(query) ||
      (inv.supplier_name || '').toLowerCase().includes(query) ||
      (inv.purchase_order_number || '').toLowerCase().includes(query)
    );
  }
  
  // Status filter
  if (statusFilter.value !== 'all') {
    result = result.filter(inv => inv.status === statusFilter.value);
  }
  
  // Payment filter
  if (paymentFilter.value !== 'all') {
    const today = new Date().toISOString().split('T')[0];
    if (paymentFilter.value === 'overdue') {
      result = result.filter(inv => 
        inv.payment_status === 'unpaid' && 
        inv.due_date && 
        inv.due_date < today
      );
    } else {
      result = result.filter(inv => inv.payment_status === paymentFilter.value);
    }
  }
  
  // Sort by date descending
  result.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  
  return result;
});

// Load data - SAP RBKP List equivalent
const loadInvoices = async () => {
  isLoading.value = true;
  console.log('🔄 PURCHASING LIST: Starting data load...');
  
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    
    if (!ready) {
      console.error('❌ PURCHASING LIST: Supabase not ready');
      invoices.value = [];
      return;
    }
    
    console.log('📋 PURCHASING LIST: Querying purchasing_invoices table...');
    
    // Simple query first - no complex conditions that might fail
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .select('*')
      .order('created_at', { ascending: false });
    
    console.log('📋 PURCHASING LIST: Query result - data:', data, 'error:', error);
    
    if (error) {
      console.error('❌ PURCHASING LIST: Error loading purchasing invoices:', error);
      console.error('❌ Error code:', error.code);
      console.error('❌ Error message:', error.message);
      console.error('❌ Error details:', error.details);
      
      if (error.code === '42P01') {
        console.warn('⚠️ PURCHASING LIST: purchasing_invoices table does not exist.');
        console.warn('⚠️ Please run ENTERPRISE_ERP_SCHEMA.sql in Supabase SQL Editor.');
      }
      invoices.value = [];
    } else {
      console.log('✅ PURCHASING LIST: Loaded', data?.length || 0, 'invoices');
      
      if (data && data.length > 0) {
        console.log('📋 FIRST INVOICE:', data[0]);
      }
      
      // Filter out deleted records in JavaScript (more reliable than DB filter)
      let filteredData = (data || []).filter(inv => inv.deleted !== true);
      
      // Process data to ensure supplier_name is a string (fix JSON issue)
      const processedData = filteredData.map(inv => {
        // Fix supplier_name if it's an object or JSON string
        if (typeof inv.supplier_name === 'object' && inv.supplier_name !== null) {
          inv.supplier_name = inv.supplier_name.name || inv.supplier_name.supplier_name || 'N/A';
          console.log('🔧 Fixed supplier_name from object:', inv.supplier_name);
        } else if (typeof inv.supplier_name === 'string' && inv.supplier_name.startsWith('{')) {
          try {
            const parsed = JSON.parse(inv.supplier_name);
            inv.supplier_name = parsed.name || parsed.supplier_name || 'N/A';
            console.log('🔧 Fixed supplier_name from JSON string:', inv.supplier_name);
          } catch (e) {
            console.warn('⚠️ Could not parse supplier_name JSON');
          }
        }
        return inv;
      });
      
      invoices.value = processedData;
      console.log('✅ PURCHASING LIST: Final processed invoices:', invoices.value.length);
    }
  } catch (error) {
    console.error('❌ PURCHASING LIST: Exception:', error);
    console.error('❌ Stack trace:', error.stack);
    invoices.value = [];
  } finally {
    isLoading.value = false;
    console.log('🏁 PURCHASING LIST: Load complete. isLoading:', isLoading.value);
  }
};

const refreshData = () => {
  loadInvoices();
};

// Navigation
const viewInvoice = (id) => {
  router.push(`/homeportal/purchasing-detail/${id}`);
};

const editInvoice = (id) => {
  router.push(`/homeportal/purchasing-detail/${id}?edit=true`);
};

// Formatters
const formatDate = (date) => {
  if (!date) return '—';
  return new Date(date).toLocaleDateString('en-GB', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
};

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'SAR'
  }).format(amount || 0);
};

const formatStatus = (status) => {
  const statusMap = {
    'draft': t('status.draft'),
    'pending_approval': t('status.pending'),
    'approved': t('status.approved'),
    'posted': t('inventory.purchasing.posted'),
    'cancelled': t('status.cancelled') || 'Cancelled',
    'void': t('inventory.purchasing.void') || 'Void'
  };
  return statusMap[status] || status;
};

const formatPaymentStatus = (status, dueDate) => {
  const today = new Date().toISOString().split('T')[0];
  if (status === 'unpaid' && dueDate && dueDate < today) {
    return t('inventory.purchasing.overdue');
  }
  const paymentMap = {
    'unpaid': t('inventory.purchasing.unpaid'),
    'partial': t('inventory.purchasing.partialPaid'),
    'paid': t('inventory.purchasing.paid')
  };
  return paymentMap[status] || status;
};

const getStatusClass = (status) => {
  const classes = {
    'draft': 'bg-yellow-100 text-yellow-800',
    'pending_approval': 'bg-blue-100 text-blue-800',
    'approved': 'bg-green-100 text-green-800',
    'posted': 'bg-purple-100 text-purple-800',
    'cancelled': 'bg-gray-100 text-gray-800',
    'void': 'bg-red-100 text-red-800'
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
};

const getPaymentStatusClass = (status, dueDate) => {
  const today = new Date().toISOString().split('T')[0];
  if (status === 'unpaid' && dueDate && dueDate < today) {
    return 'bg-red-100 text-red-800';
  }
  const classes = {
    'unpaid': 'bg-orange-100 text-orange-800',
    'partial': 'bg-yellow-100 text-yellow-800',
    'paid': 'bg-green-100 text-green-800'
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
};

// Payment Method formatters
const formatPaymentMethod = (method) => {
  const methodMap = {
    'CASH_ON_HAND': 'Cash on Hand',
    'ATM_MARKET_PURCHASE': 'ATM/Market',
    'FREE_SAMPLE': 'Free Sample',
    'ONLINE_GATEWAY': 'Online'
  };
  return methodMap[method] || method || 'N/A';
};

const getPaymentMethodClass = (method) => {
  const classes = {
    'CASH_ON_HAND': 'bg-green-100 text-green-800',
    'ATM_MARKET_PURCHASE': 'bg-teal-100 text-teal-800',
    'FREE_SAMPLE': 'bg-purple-100 text-purple-800',
    'ONLINE_GATEWAY': 'bg-indigo-100 text-indigo-800'
  };
  return classes[method] || 'bg-gray-100 text-gray-800';
};

onMounted(() => {
  loadInvoices();
});
</script>
