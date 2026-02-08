<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="flex items-center gap-4 mb-6">
      <button @click="router.push('/homeportal/payments')" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
        <i class="fas fa-arrow-left"></i>
        <span>Back</span>
      </button>
      <h1 class="text-2xl font-bold text-gray-800">Payment {{ payment?.payment_number || '—' }}</h1>
    </div>

    <DocumentFlow v-if="payment?.id" docType="payment" :docId="payment.id" :currentNumber="payment.payment_number" :routeDocId="route.params.id" />

    <div v-if="payment" class="bg-white rounded-lg shadow-md p-6 mt-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="text-sm text-gray-500">Payment #</label>
          <p class="font-semibold">{{ payment.payment_number }}</p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Date</label>
          <p class="font-semibold">{{ formatDate(payment.payment_date || payment.created_at) }}</p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Type</label>
          <p class="font-semibold"><span :class="payment.payment_type === 'MANUAL' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-700'" class="px-2 py-0.5 rounded text-sm">{{ payment.payment_type }}</span></p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Amount</label>
          <p class="font-semibold text-lg">{{ formatCurrency(payment.amount ?? payment.payment_amount) }}</p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Reference</label>
          <p class="font-semibold">{{ payment.reference || payment.reference_number || '—' }}</p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Invoice</label>
          <p class="font-semibold text-blue-600 cursor-pointer hover:underline" @click="router.push(`/homeportal/purchasing-detail/${payment.purchasing_invoice_id}`)">
            {{ payment.purchasing_invoices?.purchasing_number || '—' }}
          </p>
        </div>
        <div>
          <label class="text-sm text-gray-500">Supplier</label>
          <p class="font-semibold">{{ payment.purchasing_invoices?.supplier_name || '—' }}</p>
        </div>
      </div>
    </div>
    <div v-else-if="!loading" class="bg-white rounded-lg shadow-md p-12 text-center text-gray-500">
      Payment not found.
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import DocumentFlow from '@/components/common/DocumentFlow.vue';

const route = useRoute();

const router = useRouter();
const payment = ref(null);
const loading = ref(true);

const formatDate = (d) => {
  if (!d) return '—';
  const x = new Date(d);
  return isNaN(x.getTime()) ? '—' : x.toLocaleDateString();
};

const formatCurrency = (n) => {
  const v = Number(n);
  return isNaN(v) ? '0.00' : v.toLocaleString('en-SA', { minimumFractionDigits: 2 }) + ' SAR';
};

onMounted(async () => {
  const id = route.params.id;
  if (!id) return;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    let data = (await supabaseClient.from('finance_payments').select('*, purchasing_invoices(purchasing_number, supplier_name)').eq('id', id).single()).data;
    if (!data) {
      data = (await supabaseClient.from('ap_payments').select('*, purchasing_invoices(purchasing_number, supplier_name)').eq('id', id).single()).data;
    }
    payment.value = data;
  } catch (e) {
    payment.value = null;
  } finally {
    loading.value = false;
  }
});
</script>
