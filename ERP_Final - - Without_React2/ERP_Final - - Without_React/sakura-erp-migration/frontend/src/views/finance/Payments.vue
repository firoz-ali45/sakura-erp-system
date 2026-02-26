<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold text-gray-800">Manual Payments</h1>
        <p class="text-gray-600 mt-1">Finance → Payments — Bank Transfer / Manual Payment (SAP F-53)</p>
      </div>
      <button 
        @click="showCreateModal = true"
        class="px-6 py-2 text-white rounded-lg font-semibold flex items-center gap-2"
        style="background: linear-gradient(135deg, #1e3a34 0%, #284b44 100%);"
      >
        <i class="fas fa-plus"></i>
        New Payment
      </button>
    </div>

    <!-- Payment List -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <div class="flex gap-2 mb-4">
          <button
            @click="filterType = ''"
            :class="filterType === '' ? 'bg-[#284b44] text-white' : 'bg-gray-100 text-gray-700'"
            class="px-4 py-2 rounded-lg text-sm font-medium"
          >All</button>
          <button
            @click="filterType = 'AUTO'"
            :class="filterType === 'AUTO' ? 'bg-[#284b44] text-white' : 'bg-gray-100 text-gray-700'"
            class="px-4 py-2 rounded-lg text-sm font-medium"
          >Auto (system)</button>
          <button
            @click="filterType = 'MANUAL'"
            :class="filterType === 'MANUAL' ? 'bg-[#284b44] text-white' : 'bg-gray-100 text-gray-700'"
            class="px-4 py-2 rounded-lg text-sm font-medium"
          >Manual (Bank Transfer)</button>
        </div>
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Payment #</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Supplier</th>
              <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reference</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Invoice</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="p in filteredPayments" :key="p.id" class="hover:bg-gray-50 cursor-pointer" @click="viewPayment(p.id)">
              <td class="px-4 py-3">
                <span :class="p.payment_type === 'MANUAL' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-700'" class="px-2 py-0.5 rounded text-xs font-semibold">{{ p.payment_type }}</span>
              </td>
              <td class="px-4 py-3 text-sm font-semibold text-[#284b44]">{{ p.payment_number || '—' }}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{{ formatDate(p.payment_date || p.created_at) }}</td>
              <td class="px-4 py-3 text-sm text-gray-800">{{ p.supplier_name || '—' }}</td>
              <td class="px-4 py-3 text-sm text-right font-semibold">{{ formatCurrency(p.amount) }}</td>
              <td class="px-4 py-3 text-sm text-gray-600">{{ p.reference || '—' }}</td>
              <td class="px-4 py-3 text-sm text-blue-600">{{ p.purchasing_number || '—' }}</td>
            </tr>
            <tr v-if="!loading && filteredPayments.length === 0">
              <td colspan="7" class="px-6 py-12 text-center text-gray-500">
                <i class="fas fa-money-check-alt text-4xl text-gray-300 mb-3 block"></i>
                No payments yet. Create a manual payment (Bank Transfer) to pay open invoices.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Create Payment Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" @click.self="showCreateModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="p-6 border-b bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white">
          <h2 class="text-xl font-bold">New Manual Payment (Bank Transfer)</h2>
          <p class="text-sm opacity-90 mt-1">Select supplier and open invoices to pay</p>
        </div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Supplier *</label>
            <select 
              v-model="newPayment.supplier_id" 
              class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#284b44]"
              @change="loadOpenInvoices"
            >
              <option value="">— Select supplier —</option>
              <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.supplier_name || s.name }}</option>
            </select>
          </div>
          <div v-if="openInvoices.length > 0">
            <label class="block text-sm font-medium text-gray-700 mb-2">Select invoice to pay</label>
            <div class="border rounded-lg divide-y max-h-48 overflow-y-auto">
              <label v-for="inv in openInvoices" :key="inv.id" class="flex items-center justify-between p-4 hover:bg-gray-50 cursor-pointer">
                <div class="flex items-center gap-3">
                  <input type="radio" v-model="newPayment.invoice_id" :value="inv.id" class="rounded" />
                  <span class="font-medium">{{ inv.purchasing_number }}</span>
                  <span class="text-gray-500">{{ inv.supplier_name }}</span>
                </div>
                <span class="font-semibold">Outstanding: {{ formatCurrency(inv.outstanding_amount ?? inv.grand_total - (inv.paid_amount || 0)) }}</span>
              </label>
            </div>
          </div>
          <div v-else-if="newPayment.supplier_id" class="p-4 bg-gray-50 rounded-lg text-gray-600 text-sm">
            No open invoices for this supplier.
          </div>
          <div v-if="newPayment.invoice_id">
            <label class="block text-sm font-medium text-gray-700 mb-1">Payment amount *</label>
            <input 
              v-model.number="newPayment.amount" 
              type="number" 
              step="0.01" 
              class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#284b44]"
              placeholder="0.00"
            />
            <p v-if="selectedInvoiceOutstanding != null" class="text-xs text-gray-500 mt-1">Outstanding: {{ formatCurrency(selectedInvoiceOutstanding) }}. Payment must not exceed outstanding.</p>
            <p v-if="paymentAmountError" class="text-xs text-red-600 mt-1">{{ paymentAmountError }}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bank *</label>
            <select 
              v-model="newPayment.bank_id" 
              class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#284b44]"
            >
              <option value="">— Select Bank —</option>
              <option v-for="b in banks" :key="b.id" :value="b.id">{{ b.bank_name }} ({{ b.account_number || b.iban || '—' }})</option>
            </select>
            <p class="text-xs text-gray-500 mt-1">Configure banks in Finance → More → Payment Configuration.</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Payment date *</label>
            <input 
              v-model="newPayment.payment_date" 
              type="date" 
              class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#284b44]"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bank reference</label>
            <input 
              v-model="newPayment.reference_number" 
              type="text" 
              class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-[#284b44]"
              placeholder="Bank transfer ref / cheque no"
            />
          </div>
        </div>
        <div class="p-6 border-t flex justify-end gap-3">
          <button @click="showCreateModal = false" class="px-4 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
          <button 
            @click="submitPayment" 
            :disabled="submitting || !canSubmit"
            class="px-6 py-2 text-white rounded-lg font-semibold disabled:opacity-50"
            style="background: linear-gradient(135deg, #1e3a34 0%, #284b44 100%);"
          >
            {{ submitting ? 'Submitting...' : 'Submit Payment' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { asUuidOrNull } from '@/utils/uuidUtils';
import { useSubmitGuard } from '@/composables/useSubmitGuard';
import { useAuditLog } from '@/composables/useAuditLog';

const { t } = useI18n();
const router = useRouter();
const { submitting, guard } = useSubmitGuard();
const { logAction } = useAuditLog();
const payments = ref([]);
const suppliers = ref([]);
const openInvoices = ref([]);
const banks = ref([]);
const loading = ref(true);
const showCreateModal = ref(false);

const newPayment = ref({
  supplier_id: '',
  invoice_id: null,
  amount: 0,
  payment_date: new Date().toISOString().slice(0, 10),
  reference_number: '',
  bank_id: ''
});

const selectedInvoiceOutstanding = computed(() => {
  if (!newPayment.value.invoice_id) return null;
  const inv = openInvoices.value.find(i => i.id === newPayment.value.invoice_id);
  return inv ? (inv.outstanding_amount ?? Math.max(0, Number(inv.grand_total || 0) - Number(inv.paid_amount || 0))) : null;
});

const paymentAmountError = computed(() => {
  const amt = Number(newPayment.value.amount);
  const out = selectedInvoiceOutstanding.value;
  if (out == null || amt <= 0) return null;
  if (amt > out) return 'Payment amount cannot exceed outstanding.';
  return null;
});

const canSubmit = computed(() => 
  newPayment.value.invoice_id && 
  newPayment.value.amount > 0 && 
  newPayment.value.payment_date &&
  newPayment.value.bank_id &&
  !paymentAmountError.value
);

const filterType = ref('');
const filteredPayments = computed(() => {
  if (!filterType.value) return payments.value;
  return payments.value.filter(p => p.payment_type === filterType.value);
});

const formatDate = (d) => {
  if (!d) return '—';
  const x = new Date(d);
  return isNaN(x.getTime()) ? '—' : x.toLocaleDateString();
};

const formatCurrency = (n) => {
  const v = Number(n);
  return isNaN(v) ? '0.00' : v.toLocaleString('en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' SAR';
};

const loadPayments = async () => {
  loading.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient
      .from('finance_payments')
      .select(`
        id, payment_number, payment_type, payment_method, amount, reference, payment_date, created_at,
        purchasing_invoice_id, vendor_id,
        purchasing_invoices(purchasing_number, supplier_name)
      `)
      .order('created_at', { ascending: false })
      .limit(200);
    
    payments.value = (data || []).map(r => ({
      ...r,
      supplier_name: r.purchasing_invoices?.supplier_name,
      purchasing_number: r.purchasing_invoices?.purchasing_number
    }));
  } catch (e) {
    console.error('Load payments:', e);
    payments.value = [];
  } finally {
    loading.value = false;
  }
};

const loadSuppliers = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('suppliers').select('id, supplier_name, name').eq('deleted', false).order('supplier_name');
    suppliers.value = data || [];
  } catch (e) {
    suppliers.value = [];
  }
};

const loadBanks = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('finance_banks').select('id, bank_name, account_name, account_number, iban, swift_code').eq('is_active', true).order('bank_name');
    banks.value = data || [];
  } catch (e) {
    banks.value = [];
  }
};

const loadOpenInvoices = async () => {
  if (!newPayment.value.supplier_id) {
    openInvoices.value = [];
    return;
  }
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient
      .from('purchasing_invoices')
      .select('id, purchasing_number, supplier_id, supplier_name, grand_total, paid_amount, payment_status')
      .eq('supplier_id', newPayment.value.supplier_id)
      .in('payment_status', ['unpaid', 'partial'])
      .in('status', ['approved', 'posted'])
      .eq('deleted', false);
    
    openInvoices.value = (data || []).map(i => ({
      ...i,
      outstanding_amount: Math.max(0, Number(i.grand_total || 0) - Number(i.paid_amount || 0))
    }));
    newPayment.value.invoice_id = null;
  } catch (e) {
    openInvoices.value = [];
  }
};

const submitPayment = async () => {
  if (!canSubmit.value) return;
  await guard(async () => {
    try {
      const { supabaseClient } = await import('@/services/supabase.js');
      const authStore = (await import('@/stores/auth')).useAuthStore();
      
      const inv = openInvoices.value.find(i => i.id === newPayment.value.invoice_id);
      const payload = {
        payment_type: 'MANUAL',
        payment_method: 'BANK_TRANSFER',
        purchasing_invoice_id: newPayment.value.invoice_id,
        vendor_id: inv?.supplier_id ?? newPayment.value.supplier_id ?? null,
        bank_id: newPayment.value.bank_id || null,
        amount: newPayment.value.amount,
        currency: 'SAR',
        reference: newPayment.value.reference_number || null,
        payment_date: newPayment.value.payment_date,
        status: 'completed',
        created_by: asUuidOrNull(authStore.user?.id)
      };
      const { data } = await supabaseClient.from('finance_payments').insert(payload).select('id, payment_number').single();
      await logAction('INSERT', 'finance_payments', data?.id, null, payload);
      const uid = authStore.user?.id;
      if (uid) {
        const { logActivity } = await import('@/services/userManagementService.js');
        logActivity(uid, 'payment_create', 'finance_payments', data?.id, { amount: payload.amount });
      }
      showCreateModal.value = false;
      newPayment.value = { supplier_id: '', invoice_id: null, amount: 0, payment_date: new Date().toISOString().slice(0, 10), reference_number: '', bank_id: '' };
      await loadPayments();
    } catch (e) {
      console.error('Submit payment:', e);
      alert('Failed to submit payment: ' + (e.message || 'Unknown error'));
    }
  });
};

const viewPayment = (id) => router.push(`/homeportal/payment-detail/${id}`);

onMounted(async () => {
  await Promise.all([loadPayments(), loadSuppliers(), loadBanks()]);
});
</script>
