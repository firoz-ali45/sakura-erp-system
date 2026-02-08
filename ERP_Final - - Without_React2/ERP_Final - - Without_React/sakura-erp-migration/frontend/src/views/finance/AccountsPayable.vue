<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold text-gray-800">{{ t('homePortal.accountsPayable') }}</h1>
        <p class="text-gray-600 mt-1">System of record — driven by Purchasing Invoices (PUR). SAP FBL1N style.</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-6 flex flex-wrap items-center gap-4">
      <div class="flex items-center gap-2">
        <label class="text-sm font-medium text-gray-700">Status</label>
        <select
          v-model="filterStatus"
          class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]"
        >
          <option value="">All</option>
          <option value="open">Open / Partial</option>
          <option value="paid">Paid</option>
        </select>
      </div>
      <div class="flex items-center gap-2">
        <label class="text-sm font-medium text-gray-700">Vendor</label>
        <select
          v-model="filterVendor"
          class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] min-w-[200px]"
        >
          <option value="">All vendors</option>
          <option v-for="v in vendors" :key="v.id" :value="v.id">{{ v.supplier_name || v.name }}</option>
        </select>
      </div>
      <button
        @click="loadInvoices"
        class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3a34] flex items-center gap-2"
      >
        <i class="fas fa-sync-alt"></i> Refresh
      </button>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-lg shadow p-4">
        <p class="text-sm text-gray-500">Total Outstanding</p>
        <p class="text-2xl font-bold text-[#284b44]">{{ formatCurrency(summary.totalOutstanding) }}</p>
      </div>
      <div class="bg-white rounded-lg shadow p-4">
        <p class="text-sm text-gray-500">Open Invoices</p>
        <p class="text-2xl font-bold text-orange-600">{{ summary.openCount }}</p>
      </div>
      <div class="bg-white rounded-lg shadow p-4">
        <p class="text-sm text-gray-500">Paid (this set)</p>
        <p class="text-2xl font-bold text-green-600">{{ formatCurrency(summary.totalPaid) }}</p>
      </div>
      <div class="bg-white rounded-lg shadow p-4">
        <p class="text-sm text-gray-500">Vendors</p>
        <p class="text-2xl font-bold text-gray-800">{{ summary.vendorCount }}</p>
      </div>
    </div>

    <!-- Invoices table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vendor</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Invoice No</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Invoice Date</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Due Date</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Paid</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Outstanding</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Aging</th>
              <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr
              v-for="inv in filteredInvoices"
              :key="inv.id"
              class="hover:bg-gray-50 cursor-pointer"
              @click="goToDetail(inv.id)"
            >
              <td class="px-4 py-3 text-sm font-medium text-gray-900">{{ inv.supplier_name || '—' }}</td>
              <td class="px-4 py-3 text-sm text-[#284b44] font-semibold">{{ inv.purchasing_number || inv.vendor_invoice_number || '—' }}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{{ formatDate(inv.invoice_date) }}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{{ formatDate(inv.due_date) }}</td>
              <td class="px-4 py-3 text-sm text-right font-semibold">{{ formatCurrency(inv.grand_total) }}</td>
              <td class="px-4 py-3 text-sm text-right text-green-600">{{ formatCurrency(inv.paid_amount) }}</td>
              <td class="px-4 py-3 text-sm text-right font-semibold" :class="outstanding(inv) > 0 ? 'text-red-600' : 'text-gray-600'">
                {{ formatCurrency(outstanding(inv)) }}
              </td>
              <td class="px-4 py-3 text-center">
                <span :class="getAgingClass(agingBucket(inv))" class="px-2 py-0.5 rounded text-xs font-semibold">{{ agingBucket(inv) || '—' }}</span>
              </td>
              <td class="px-4 py-3 text-center">
                <span :class="getStatusClass(inv.payment_status)" class="px-2 py-1 rounded text-xs font-semibold">
                  {{ formatPaymentStatus(inv.payment_status) }}
                </span>
              </td>
            </tr>
            <tr v-if="!loading && filteredInvoices.length === 0">
              <td colspan="9" class="px-6 py-12 text-center text-gray-500">
                No invoices match filters. Open invoices come from Finance → Purchasing (Invoices).
              </td>
            </tr>
          </tbody>
        </table>
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
const invoices = ref([]);
const vendors = ref([]);
const loading = ref(true);
const filterStatus = ref('');
const filterVendor = ref('');

const formatDate = (d) => {
  if (!d) return '—';
  const x = new Date(d);
  return isNaN(x.getTime()) ? '—' : x.toLocaleDateString();
};

const formatCurrency = (n) => {
  const v = Number(n);
  return (isNaN(v) ? '0.00' : v.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })) + ' SAR';
};

const outstanding = (inv) => Math.max(0, Number(inv.grand_total || 0) - Number(inv.paid_amount || 0));

const agingBucket = (inv) => {
  if (!inv.due_date || inv.payment_status === 'paid') return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const due = new Date(inv.due_date);
  const days = Math.floor((today - due) / (1000 * 60 * 60 * 24));
  if (days <= 30) return '0-30';
  if (days <= 60) return '31-60';
  if (days <= 90) return '61-90';
  return '90+';
};

const getAgingClass = (b) => {
  const c = { '0-30': 'bg-green-100 text-green-800', '31-60': 'bg-yellow-100 text-yellow-800', '61-90': 'bg-orange-100 text-orange-800', '90+': 'bg-red-100 text-red-800' };
  return c[b] || 'bg-gray-100 text-gray-600';
};

const formatPaymentStatus = (s) => {
  const m = { unpaid: 'Open', partial: 'Partial', paid: 'Paid' };
  return m[s] || s || '—';
};

const getStatusClass = (s) => {
  const c = { unpaid: 'bg-red-100 text-red-800', partial: 'bg-yellow-100 text-yellow-800', paid: 'bg-green-100 text-green-800' };
  return c[s] || 'bg-gray-100 text-gray-800';
};

const filteredInvoices = computed(() => {
  let list = invoices.value;
  if (filterStatus.value === 'open') {
    list = list.filter(i => i.payment_status === 'unpaid' || i.payment_status === 'partial');
  } else if (filterStatus.value === 'paid') {
    list = list.filter(i => i.payment_status === 'paid');
  }
  if (filterVendor.value) {
    list = list.filter(i => String(i.supplier_id) === String(filterVendor.value));
  }
  return list;
});

const summary = computed(() => {
  const list = filteredInvoices.value;
  const totalOutstanding = list.reduce((s, i) => s + outstanding(i), 0);
  const totalPaid = list.reduce((s, i) => s + Number(i.paid_amount || 0), 0);
  const openCount = list.filter(i => i.payment_status !== 'paid').length;
  const vendorIds = new Set(list.map(i => i.supplier_id).filter(Boolean));
  return {
    totalOutstanding,
    totalPaid,
    openCount,
    vendorCount: vendorIds.size
  };
});

const loadInvoices = async () => {
  loading.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient
      .from('purchasing_invoices')
      .select('id, purchasing_number, vendor_invoice_number, supplier_id, supplier_name, invoice_date, due_date, grand_total, paid_amount, payment_status, status')
      .eq('deleted', false)
      .in('status', ['approved', 'posted', 'draft', 'pending_approval'])
      .order('invoice_date', { ascending: false })
      .limit(500);
    invoices.value = data || [];
  } catch (e) {
    console.error('Load AP invoices:', e);
    invoices.value = [];
  } finally {
    loading.value = false;
  }
};

const loadVendors = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('suppliers').select('id, supplier_name, name').eq('deleted', false).order('supplier_name');
    vendors.value = data || [];
  } catch (e) {
    vendors.value = [];
  }
};

const goToDetail = (id) => router.push(`/homeportal/purchasing-detail/${id}`);

onMounted(async () => {
  await Promise.all([loadInvoices(), loadVendors()]);
});
</script>
