<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-800">Finance Dashboard</h1>
      <p class="text-gray-600 mt-1">Derived only from Finance tables. Cash position, payables aging, upcoming dues. Currency: SAR.</p>
    </div>

    <!-- KPI cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
      <div class="bg-white rounded-xl shadow-md p-6 border-l-4 border-[#284b44]">
        <p class="text-sm text-gray-500 uppercase tracking-wide">Total Open Payables</p>
        <p class="text-2xl font-bold text-[#284b44] mt-1">{{ formatCurrency(summary.totalOutstanding) }}</p>
        <p class="text-xs text-gray-500 mt-1">{{ summary.openCount }} open invoices</p>
      </div>
      <div class="bg-white rounded-xl shadow-md p-6 border-l-4 border-amber-500">
        <p class="text-sm text-gray-500 uppercase tracking-wide">Payables Aging (90+ days)</p>
        <p class="text-2xl font-bold text-amber-700 mt-1">{{ formatCurrency(summary.aging90Plus) }}</p>
        <p class="text-xs text-gray-500 mt-1">{{ summary.count90Plus }} invoices</p>
      </div>
      <div class="bg-white rounded-xl shadow-md p-6 border-l-4 border-blue-500">
        <p class="text-sm text-gray-500 uppercase tracking-wide">Upcoming Dues (30 days)</p>
        <p class="text-2xl font-bold text-blue-700 mt-1">{{ formatCurrency(summary.upcomingDues) }}</p>
        <p class="text-xs text-gray-500 mt-1">Due in next 30 days</p>
      </div>
      <div class="bg-white rounded-xl shadow-md p-6 border-l-4 border-green-500">
        <p class="text-sm text-gray-500 uppercase tracking-wide">Paid (last 30 days)</p>
        <p class="text-2xl font-bold text-green-700 mt-1">{{ formatCurrency(summary.paidLast30) }}</p>
        <p class="text-xs text-gray-500 mt-1">From finance_payments</p>
      </div>
    </div>

    <!-- Payables aging breakdown -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden mb-8">
      <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
        <h2 class="text-xl font-semibold">Payables Aging</h2>
        <router-link to="/homeportal/accounts-payable" class="text-sm opacity-90 hover:underline">View AP →</router-link>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="border rounded-lg p-4 text-center">
            <p class="text-xs text-gray-500 uppercase">0–30 days</p>
            <p class="text-lg font-bold text-gray-800">{{ formatCurrency(agingBuckets['0-30']) }}</p>
          </div>
          <div class="border rounded-lg p-4 text-center">
            <p class="text-xs text-gray-500 uppercase">31–60 days</p>
            <p class="text-lg font-bold text-amber-700">{{ formatCurrency(agingBuckets['31-60']) }}</p>
          </div>
          <div class="border rounded-lg p-4 text-center">
            <p class="text-xs text-gray-500 uppercase">61–90 days</p>
            <p class="text-lg font-bold text-orange-600">{{ formatCurrency(agingBuckets['61-90']) }}</p>
          </div>
          <div class="border rounded-lg p-4 text-center">
            <p class="text-xs text-gray-500 uppercase">90+ days</p>
            <p class="text-lg font-bold text-red-600">{{ formatCurrency(agingBuckets['90+']) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Upcoming dues list -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
        <h2 class="text-xl font-semibold">Upcoming Dues (next 30 days)</h2>
        <router-link to="/homeportal/accounts-payable" class="text-sm opacity-90 hover:underline">View all →</router-link>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vendor</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Invoice</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Due Date</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Outstanding</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="inv in upcomingList" :key="inv.id" class="hover:bg-gray-50 cursor-pointer" @click="$router.push(`/homeportal/purchasing-detail/${inv.id}`)">
              <td class="px-4 py-3 text-sm font-medium text-gray-900">{{ inv.supplier_name || '—' }}</td>
              <td class="px-4 py-3 text-sm text-[#284b44] font-semibold">{{ inv.purchasing_number || '—' }}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{{ formatDate(inv.due_date) }}</td>
              <td class="px-4 py-3 text-sm text-right font-semibold">{{ formatCurrency(outstanding(inv)) }}</td>
            </tr>
            <tr v-if="!loading && upcomingList.length === 0">
              <td colspan="4" class="px-6 py-8 text-center text-gray-500">No upcoming dues in the next 30 days.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const loading = ref(true);
const invoices = ref([]);
const paymentsLast30 = ref(0);

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

const agingBuckets = computed(() => {
  const b = { '0-30': 0, '31-60': 0, '61-90': 0, '90+': 0 };
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  invoices.value.filter(i => (i.payment_status !== 'paid' && outstanding(i) > 0)).forEach(inv => {
    const due = inv.due_date ? new Date(inv.due_date) : null;
    if (!due) return;
    const days = Math.floor((today - due) / (1000 * 60 * 60 * 24));
    const amt = outstanding(inv);
    if (days <= 30) b['0-30'] += amt;
    else if (days <= 60) b['31-60'] += amt;
    else if (days <= 90) b['61-90'] += amt;
    else b['90+'] += amt;
  });
  return b;
});

const summary = computed(() => {
  const open = invoices.value.filter(i => i.payment_status !== 'paid');
  const totalOutstanding = open.reduce((s, i) => s + outstanding(i), 0);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const in90Plus = open.filter(i => {
    const due = i.due_date ? new Date(i.due_date) : null;
    if (!due) return false;
    const days = Math.floor((today - due) / (1000 * 60 * 60 * 24));
    return days > 90;
  });
  const in30Days = open.filter(i => {
    const due = i.due_date ? new Date(i.due_date) : null;
    if (!due) return false;
    const days = Math.floor((due - today) / (1000 * 60 * 60 * 24));
    return days >= 0 && days <= 30;
  });
  return {
    totalOutstanding,
    openCount: open.length,
    aging90Plus: in90Plus.reduce((s, i) => s + outstanding(i), 0),
    count90Plus: in90Plus.length,
    upcomingDues: in30Days.reduce((s, i) => s + outstanding(i), 0),
    paidLast30: paymentsLast30.value
  };
});

const upcomingList = computed(() => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const in30 = invoices.value.filter(i => {
    if (i.payment_status === 'paid' || outstanding(i) <= 0) return false;
    const due = i.due_date ? new Date(i.due_date) : null;
    if (!due) return false;
    const days = Math.floor((due - today) / (1000 * 60 * 60 * 24));
    return days >= 0 && days <= 30;
  });
  in30.sort((a, b) => (new Date(a.due_date) - new Date(b.due_date)));
  return in30.slice(0, 15);
});

const load = async () => {
  loading.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const [invRes, payRes] = await Promise.all([
      supabaseClient.from('purchasing_invoices').select('id, purchasing_number, supplier_name, due_date, grand_total, paid_amount, payment_status').eq('deleted', false).in('status', ['approved', 'posted', 'draft', 'pending_approval']),
      supabaseClient.from('finance_payments').select('amount').eq('status', 'completed').gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
    ]);
    invoices.value = invRes.data || [];
    paymentsLast30.value = (payRes.data || []).reduce((s, r) => s + Number(r.amount || 0), 0);
  } catch (e) {
    invoices.value = [];
    paymentsLast30.value = 0;
  } finally {
    loading.value = false;
  }
};

onMounted(load);
</script>
