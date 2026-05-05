<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">Nexora Control Center</h2>
      <p class="text-sm text-gray-600 mt-1">
        Manage client companies and their subscription state.
      </p>
    </div>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4 md:p-6">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-lg font-semibold text-gray-800">Tenants / Companies</h3>
        <button
          class="px-3 py-2 rounded-lg bg-[#284b44] text-white text-sm disabled:opacity-50"
          :disabled="loading"
          @click="loadCompanies"
        >
          {{ loading ? 'Refreshing...' : 'Refresh' }}
        </button>
      </div>

      <p v-if="warning" class="text-amber-700 bg-amber-50 border border-amber-200 rounded p-3 text-sm mb-3">
        {{ warning }}
      </p>
      <p v-if="error" class="text-red-700 bg-red-50 border border-red-200 rounded p-3 text-sm mb-3">
        {{ error }}
      </p>

      <div class="overflow-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="text-left border-b">
              <th class="py-2 pr-3">Company</th>
              <th class="py-2 pr-3">Code</th>
              <th class="py-2 pr-3">Plan</th>
              <th class="py-2 pr-3">Status</th>
              <th class="py-2 pr-3">Trial End</th>
              <th class="py-2 pr-3">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in companies" :key="c.id" class="border-b last:border-0">
              <td class="py-2 pr-3 font-medium text-gray-800">{{ c.name || c.company_name || '—' }}</td>
              <td class="py-2 pr-3 text-gray-600">{{ c.company_code || '—' }}</td>
              <td class="py-2 pr-3">
                <select :value="getEdit(c.id).subscription_plan" @change="onFieldChange(c.id, 'subscription_plan', $event.target.value)" class="px-2 py-1 border rounded">
                  <option value="free">free</option>
                  <option value="starter">starter</option>
                  <option value="pro">pro</option>
                  <option value="enterprise">enterprise</option>
                </select>
              </td>
              <td class="py-2 pr-3">
                <select :value="getEdit(c.id).subscription_status" @change="onFieldChange(c.id, 'subscription_status', $event.target.value)" class="px-2 py-1 border rounded">
                  <option value="trial">trial</option>
                  <option value="active">active</option>
                  <option value="past_due">past_due</option>
                  <option value="expired">expired</option>
                  <option value="canceled">canceled</option>
                </select>
              </td>
              <td class="py-2 pr-3 text-gray-600">{{ formatDate(c.trial_ends_at) }}</td>
              <td class="py-2 pr-3">
                <button
                  class="px-2 py-1 rounded bg-gray-800 text-white text-xs disabled:opacity-50"
                  :disabled="savingId === c.id"
                  @click="saveCompany(c.id)"
                >
                  {{ savingId === c.id ? 'Saving...' : 'Save' }}
                </button>
              </td>
            </tr>
            <tr v-if="!loading && companies.length === 0">
              <td colspan="6" class="py-4 text-gray-500">No companies visible for current auth context.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase';

const companies = ref([]);
const loading = ref(false);
const savingId = ref(null);
const error = ref('');
const warning = ref('');
const edits = ref({});

function formatDate(v) {
  if (!v) return '—';
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
}

function initEdits(rows) {
  const next = {};
  rows.forEach((c) => {
    next[c.id] = {
      subscription_plan: c.subscription_plan || 'free',
      subscription_status: c.subscription_status || 'trial'
    };
  });
  edits.value = next;
}

function getEdit(companyId) {
  if (!companyId) return { subscription_plan: 'free', subscription_status: 'trial' };
  if (!edits.value[companyId]) {
    edits.value[companyId] = { subscription_plan: 'free', subscription_status: 'trial' };
  }
  return edits.value[companyId];
}

function onFieldChange(companyId, field, value) {
  const row = getEdit(companyId);
  row[field] = value;
}

async function loadCompanies() {
  loading.value = true;
  error.value = '';
  warning.value = '';
  try {
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) throw new Error('Supabase not ready');
    const { data, error: e } = await supabaseClient
      .from('companies')
      .select('id, name, company_name, company_code, subscription_plan, subscription_status, trial_ends_at')
      .order('created_at', { ascending: false });
    if (e) {
      warning.value = 'Provider-level listing may be blocked by RLS for this auth mode. Use backend service-role APIs for full SaaS control.';
      throw e;
    }
    companies.value = data || [];
    initEdits(companies.value);
  } catch (err) {
    error.value = err?.message || 'Failed to load companies';
  } finally {
    loading.value = false;
  }
}

async function saveCompany(companyId) {
  const draft = edits.value[companyId];
  if (!draft) return;
  savingId.value = companyId;
  error.value = '';
  try {
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) throw new Error('Supabase not ready');
    const { error: e } = await supabaseClient
      .from('companies')
      .update({
        subscription_plan: draft.subscription_plan,
        subscription_status: draft.subscription_status
      })
      .eq('id', companyId);
    if (e) throw e;
    await loadCompanies();
  } catch (err) {
    error.value = err?.message || 'Failed to update subscription';
  } finally {
    savingId.value = null;
  }
}

onMounted(loadCompanies);
</script>
