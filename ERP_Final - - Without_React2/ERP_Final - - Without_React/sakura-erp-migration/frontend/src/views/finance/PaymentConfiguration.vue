<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="mb-6 flex items-center gap-4">
      <button
        @click="$router.push('/homeportal/finance-more')"
        class="text-[#284b44] hover:text-[#1e3a34] flex items-center gap-2 font-medium"
      >
        <i class="fas fa-arrow-left"></i>
        {{ t('common.back') }}
      </button>
      <div>
        <h1 class="text-3xl font-bold text-gray-800">{{ t('homePortal.paymentConfiguration') }}</h1>
        <p class="text-gray-600 mt-1">Finance → More → Payment Configuration. ATM Master & Bank Master.</p>
      </div>
    </div>

    <!-- C) PAYMENT RULES ENGINE (read-only from config) -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden mb-8">
      <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4">
        <h2 class="text-xl font-semibold flex items-center gap-2">
          <i class="fas fa-list-alt"></i> Payment Rules Engine
        </h2>
        <p class="text-sm opacity-90 mt-1">Rules drive Purchasing (allowed methods) and Payments (Bank Transfer only for manual). Credit is forbidden.</p>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div
            v-for="r in paymentRules"
            :key="r.payment_method"
            class="border rounded-lg p-4"
            :class="r.allow_in_purchasing ? 'border-green-200 bg-green-50/50' : 'border-gray-200 bg-gray-50/50'"
          >
            <div class="font-semibold text-gray-900">{{ r.display_name }}</div>
            <div class="text-xs text-gray-600 mt-2 space-y-1">
              <span class="block">Auto: {{ r.is_auto_payment ? 'Yes' : 'No' }}</span>
              <span class="block">In Purchasing: {{ r.allow_in_purchasing ? 'Yes' : 'No' }}</span>
              <span v-if="r.requires_atm" class="block text-amber-700">Requires ATM</span>
              <span v-if="r.requires_bank" class="block text-blue-700">Requires Bank (manual only)</span>
              <span v-if="r.requires_reference" class="block text-purple-700">Requires reference</span>
            </div>
          </div>
        </div>
        <p v-if="!loadingRules && paymentRules.length === 0" class="text-gray-500 text-sm mt-4">No payment rules. Run migration 03_HARD_RESET_FINANCE_RBAC.sql.</p>
      </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-8">
      <!-- A) ATM MASTER (card-based) -->
      <div class="bg-white rounded-xl shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-semibold"><span class="mr-2">🏧</span>{{ t('homePortal.atmMaster') }}</h2>
          <button
            @click="openAtmModal()"
            class="px-4 py-2 bg-white/20 rounded-lg hover:bg-white/30 text-sm font-medium"
          >
            <i class="fas fa-plus mr-2"></i>{{ t('common.add') }}
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div
              v-for="a in atms"
              :key="a.id"
              class="border border-gray-200 rounded-lg p-4 hover:border-[#284b44]/30 flex justify-between items-start"
            >
              <div>
                <div class="font-semibold text-gray-900">{{ a.atm_name }}</div>
                <div class="text-sm text-[#284b44] font-mono mt-1">ATM # {{ a.atm_number || '—' }}</div>
                <div class="text-sm text-gray-600 mt-1">{{ a.linked_bank_name || a.bank_name || '—' }}</div>
                <div v-if="a.location" class="text-xs text-gray-500 mt-1"><i class="fas fa-map-marker-alt mr-1"></i>{{ a.location }}</div>
                <span :class="a.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'" class="inline-block mt-2 px-2 py-0.5 rounded text-xs font-semibold">
                  {{ a.is_active ? 'Active' : 'Disabled' }}
                </span>
              </div>
              <button @click="openAtmModal(a)" class="text-[#284b44] hover:underline text-sm font-medium">{{ t('common.edit') }}</button>
            </div>
          </div>
          <p v-if="!loadingAtms && atms.length === 0" class="text-gray-500 text-center py-8">No ATMs. Add one to use in Purchasing (ATM / Market Purchase).</p>
        </div>
      </div>

      <!-- B) BANK MASTER (card-based) -->
      <div class="bg-white rounded-xl shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-semibold"><span class="mr-2">🏦</span>{{ t('homePortal.bankMaster') }}</h2>
          <button
            @click="openBankModal()"
            class="px-4 py-2 bg-white/20 rounded-lg hover:bg-white/30 text-sm font-medium"
          >
            <i class="fas fa-plus mr-2"></i>{{ t('common.add') }}
          </button>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div
              v-for="b in banks"
              :key="b.id"
              class="border border-gray-200 rounded-lg p-4 hover:border-[#284b44]/30 flex justify-between items-start"
            >
              <div>
                <div class="font-semibold text-gray-900">{{ b.bank_name }}</div>
                <div v-if="b.account_name" class="text-sm text-gray-700 mt-1">{{ b.account_name }}</div>
                <div class="text-sm text-gray-600 mt-1">Account: {{ b.account_number || '—' }}</div>
                <div class="text-sm text-gray-600">IBAN: {{ b.iban || '—' }}</div>
                <div v-if="b.swift_code" class="text-xs text-gray-500 mt-1">SWIFT: {{ b.swift_code }}</div>
                <span :class="b.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'" class="inline-block mt-2 px-2 py-0.5 rounded text-xs font-semibold">
                  {{ b.is_active ? 'Active' : 'Disabled' }}
                </span>
              </div>
              <button @click="openBankModal(b)" class="text-[#284b44] hover:underline text-sm font-medium">{{ t('common.edit') }}</button>
            </div>
          </div>
          <p v-if="!loadingBanks && banks.length === 0" class="text-gray-500 text-center py-8">No banks. Add one to use in Finance → Payments (Bank Transfer only).</p>
        </div>
      </div>
    </div>

    <!-- ATM Modal -->
    <div v-if="showAtmModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" @click.self="showAtmModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-md">
        <div class="p-4 border-b font-semibold text-gray-800">{{ editingAtm ? t('common.edit') : t('common.add') }} ATM</div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">ATM Name *</label>
            <input v-model="atmForm.atm_name" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="e.g. Branch Main" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">ATM Number <span class="text-red-500">*</span></label>
            <input v-model="atmForm.atm_number" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Required, unique" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bank Name (linked)</label>
            <input v-model="atmForm.linked_bank_name" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Optional" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
            <input v-model="atmForm.location" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="e.g. Branch Main" />
          </div>
          <div class="flex items-center gap-2">
            <input v-model="atmForm.is_active" type="checkbox" id="atm-active" class="rounded" />
            <label for="atm-active" class="text-sm text-gray-700">Active</label>
          </div>
        </div>
        <div class="p-4 border-t flex justify-end gap-3">
          <button @click="showAtmModal = false" class="px-4 py-2 border rounded-lg hover:bg-gray-50">{{ t('common.cancel') }}</button>
          <button @click="saveAtm" :disabled="savingAtm || !atmForm.atm_name || !atmForm.atm_number" class="px-6 py-2 bg-[#284b44] text-white rounded-lg font-semibold disabled:opacity-50">{{ savingAtm ? 'Saving...' : t('common.save') }}</button>
        </div>
      </div>
    </div>

    <!-- Bank Modal -->
    <div v-if="showBankModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" @click.self="showBankModal = false">
      <div class="bg-white rounded-xl shadow-2xl w-full max-w-md">
        <div class="p-4 border-b font-semibold text-gray-800">{{ editingBank ? t('common.edit') : t('common.add') }} Bank</div>
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bank Name *</label>
            <input v-model="bankForm.bank_name" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="e.g. Al Rajhi Bank" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Account Name</label>
            <input v-model="bankForm.account_name" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Optional" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Account Number</label>
            <input v-model="bankForm.account_number" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Optional" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">IBAN</label>
            <input v-model="bankForm.iban" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Optional" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">SWIFT Code</label>
            <input v-model="bankForm.swift_code" type="text" class="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-[#284b44]" placeholder="Optional" />
          </div>
          <div class="flex items-center gap-2">
            <input v-model="bankForm.is_active" type="checkbox" id="bank-active" class="rounded" />
            <label for="bank-active" class="text-sm text-gray-700">Active</label>
          </div>
        </div>
        <div class="p-4 border-t flex justify-end gap-3">
          <button @click="showBankModal = false" class="px-4 py-2 border rounded-lg hover:bg-gray-50">{{ t('common.cancel') }}</button>
          <button @click="saveBank" :disabled="savingBank || !bankForm.bank_name" class="px-6 py-2 bg-[#284b44] text-white rounded-lg font-semibold disabled:opacity-50">{{ savingBank ? 'Saving...' : t('common.save') }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const atms = ref([]);
const banks = ref([]);
const paymentRules = ref([]);
const loadingAtms = ref(true);
const loadingBanks = ref(true);
const loadingRules = ref(false);
const showAtmModal = ref(false);
const showBankModal = ref(false);
const editingAtm = ref(null);
const editingBank = ref(null);
const savingAtm = ref(false);
const savingBank = ref(false);

const atmForm = ref({ atm_name: '', atm_number: '', linked_bank_name: '', location: '', is_active: true });
const bankForm = ref({ bank_name: '', account_name: '', account_number: '', iban: '', swift_code: '', is_active: true });

const loadAtms = async () => {
  loadingAtms.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('finance_atms').select('*').order('atm_name');
    atms.value = data || [];
  } catch (e) {
    console.error('Load ATMs:', e);
    atms.value = [];
  } finally {
    loadingAtms.value = false;
  }
};

const loadBanks = async () => {
  loadingBanks.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('finance_banks').select('*').order('bank_name');
    banks.value = data || [];
  } catch (e) {
    console.error('Load banks:', e);
    banks.value = [];
  } finally {
    loadingBanks.value = false;
  }
};

const loadPaymentRules = async () => {
  loadingRules.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('finance_payment_rules').select('*').order('sort_order');
    paymentRules.value = data || [];
  } catch (e) {
    paymentRules.value = [];
  } finally {
    loadingRules.value = false;
  }
};

const openAtmModal = (row = null) => {
  editingAtm.value = row;
  atmForm.value = row
    ? { atm_name: row.atm_name, atm_number: row.atm_number || '', linked_bank_name: row.linked_bank_name || row.bank_name || '', location: row.location || '', is_active: !!row.is_active }
    : { atm_name: '', atm_number: '', linked_bank_name: '', location: '', is_active: true };
  showAtmModal.value = true;
};

const openBankModal = (row = null) => {
  editingBank.value = row;
  bankForm.value = row
    ? { bank_name: row.bank_name, account_name: row.account_name || '', account_number: row.account_number || '', iban: row.iban || '', swift_code: row.swift_code || '', is_active: !!row.is_active }
    : { bank_name: '', account_name: '', account_number: '', iban: '', swift_code: '', is_active: true };
  showBankModal.value = true;
};

const saveAtm = async () => {
  if (!atmForm.value.atm_name || !(atmForm.value.atm_number || '').trim()) return;
  savingAtm.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const linkedBank = (atmForm.value.linked_bank_name || '').trim() || null;
    const { dbInsert, dbUpdate } = await import('@/services/db.js');
    if (editingAtm.value) {
      await dbUpdate(supabaseClient, 'finance_atms', {
        atm_name: atmForm.value.atm_name,
        atm_number: (atmForm.value.atm_number || '').trim() || null,
        linked_bank_name: linkedBank,
        bank_name: linkedBank,
        location: (atmForm.value.location || '').trim() || null,
        is_active: atmForm.value.is_active,
        updated_at: new Date().toISOString()
      }, { id: editingAtm.value.id });
    } else {
      await dbInsert(supabaseClient, 'finance_atms', {
        atm_name: atmForm.value.atm_name,
        atm_number: (atmForm.value.atm_number || '').trim() || null,
        linked_bank_name: linkedBank,
        bank_name: linkedBank,
        location: (atmForm.value.location || '').trim() || null,
        is_active: atmForm.value.is_active
      });
    }
    showAtmModal.value = false;
    await loadAtms();
  } catch (e) {
    console.error('Save ATM:', e);
    alert('Failed to save ATM: ' + (e.message || 'Unknown error'));
  } finally {
    savingAtm.value = false;
  }
};

const saveBank = async () => {
  if (!bankForm.value.bank_name) return;
  savingBank.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { dbInsert, dbUpdate } = await import('@/services/db.js');
    if (editingBank.value) {
      await dbUpdate(supabaseClient, 'finance_banks', {
        bank_name: bankForm.value.bank_name,
        account_name: (bankForm.value.account_name || '').trim() || null,
        account_number: (bankForm.value.account_number || '').trim() || null,
        iban: (bankForm.value.iban || '').trim() || null,
        swift_code: (bankForm.value.swift_code || '').trim() || null,
        is_active: bankForm.value.is_active,
        updated_at: new Date().toISOString()
      }, { id: editingBank.value.id });
    } else {
      await dbInsert(supabaseClient, 'finance_banks', {
        bank_name: bankForm.value.bank_name,
        account_name: (bankForm.value.account_name || '').trim() || null,
        account_number: (bankForm.value.account_number || '').trim() || null,
        iban: (bankForm.value.iban || '').trim() || null,
        swift_code: (bankForm.value.swift_code || '').trim() || null,
        is_active: bankForm.value.is_active
      });
    }
    showBankModal.value = false;
    await loadBanks();
  } catch (e) {
    console.error('Save bank:', e);
    alert('Failed to save bank: ' + (e.message || 'Unknown error'));
  } finally {
    savingBank.value = false;
  }
};

onMounted(async () => {
  await Promise.all([loadPaymentRules(), loadAtms(), loadBanks()]);
});
</script>
