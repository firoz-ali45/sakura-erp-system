<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6">
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.locations.title') }}</h1>
        <button
          @click="openCreate"
          class="px-4 py-2 rounded-lg text-white flex items-center gap-2"
          style="background-color: #284b44;"
        >
          <i class="fas fa-plus"></i>
          <span>{{ $t('inventory.locations.createLocation') }}</span>
        </button>
      </div>
    </div>

    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.locationCode') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.locationName') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.type') }}</th>
            <th class="px-6 py-3 text-center text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.allowGrn') }}</th>
            <th class="px-6 py-3 text-center text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.allowTransferOut') }}</th>
            <th class="px-6 py-3 text-center text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.allowPosSale') }}</th>
            <th class="px-6 py-3 text-center text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.allowProduction') }}</th>
            <th class="px-6 py-3 text-left text-xs font-semibold text-gray-700 uppercase">{{ $t('inventory.locations.status') }}</th>
            <th class="px-6 py-3 text-right text-xs font-semibold text-gray-700 uppercase">{{ $t('common.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading" class="text-center">
            <td colspan="9" class="px-6 py-12"><i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i></td>
          </tr>
          <tr v-else-if="!locations.length" class="text-center">
            <td colspan="9" class="px-6 py-12 text-gray-500">{{ $t('inventory.locations.noLocations') }}</td>
          </tr>
          <tr v-else v-for="loc in locations" :key="loc.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ loc.location_code }}</td>
            <td class="px-6 py-4 text-sm text-gray-700">{{ loc.location_name }}</td>
            <td class="px-6 py-4 text-sm">
              <span :class="loc.location_type === 'WAREHOUSE' ? 'bg-blue-100 text-blue-800' : 'bg-amber-100 text-amber-800'" class="px-2 py-1 rounded text-xs font-semibold">{{ loc.location_type }}</span>
            </td>
            <td class="px-6 py-4 text-center"><i :class="loc.allow_grn ? 'fas fa-check text-green-600' : 'fas fa-minus text-gray-300'"></i></td>
            <td class="px-6 py-4 text-center"><i :class="loc.allow_transfer_out ? 'fas fa-check text-green-600' : 'fas fa-minus text-gray-300'"></i></td>
            <td class="px-6 py-4 text-center"><i :class="loc.allow_pos_sale ? 'fas fa-check text-green-600' : 'fas fa-minus text-gray-300'"></i></td>
            <td class="px-6 py-4 text-center"><i :class="loc.allow_production ? 'fas fa-check text-green-600' : 'fas fa-minus text-gray-300'"></i></td>
            <td class="px-6 py-4">
              <span :class="loc.is_active ? 'text-green-700 font-medium' : 'text-gray-500'">{{ loc.is_active ? $t('inventory.locations.active') : $t('inventory.locations.inactive') }}</span>
            </td>
            <td class="px-6 py-4 text-right">
              <button @click="openEdit(loc)" class="text-[#284b44] hover:underline mr-3">{{ $t('common.edit') }}</button>
              <button v-if="loc.is_active" @click="disableLocation(loc)" class="text-amber-600 hover:underline">{{ $t('inventory.locations.disable') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Form modal -->
    <div v-if="showForm" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="closeForm">
      <div class="bg-white rounded-xl shadow-xl max-w-lg w-full p-6" @click.stop>
        <h2 class="text-lg font-bold text-gray-800 mb-4">{{ isEdit ? $t('inventory.locations.editLocation') : $t('inventory.locations.createLocation') }}</h2>
        <form @submit.prevent="saveLocation">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.locations.locationCode') }} <span class="text-red-500">*</span></label>
              <input v-model="form.location_code" type="text" required :readonly="!!isEdit" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent" placeholder="e.g. W01" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.locations.locationName') }} <span class="text-red-500">*</span></label>
              <input v-model="form.location_name" type="text" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent" placeholder="e.g. Main Warehouse" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('inventory.locations.type') }} <span class="text-red-500">*</span></label>
              <select v-model="form.location_type" required class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44]" @change="applyTypeDefaults">
                <option value="WAREHOUSE">WAREHOUSE</option>
                <option value="BRANCH">BRANCH</option>
              </select>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <label class="flex items-center gap-2">
                <input v-model="form.allow_grn" type="checkbox" class="rounded" />
                <span class="text-sm">{{ $t('inventory.locations.allowGrn') }}</span>
              </label>
              <label class="flex items-center gap-2">
                <input v-model="form.allow_transfer_out" type="checkbox" class="rounded" />
                <span class="text-sm">{{ $t('inventory.locations.allowTransferOut') }}</span>
              </label>
              <label class="flex items-center gap-2">
                <input v-model="form.allow_pos_sale" type="checkbox" class="rounded" />
                <span class="text-sm">{{ $t('inventory.locations.allowPosSale') }}</span>
              </label>
              <label class="flex items-center gap-2">
                <input v-model="form.allow_production" type="checkbox" class="rounded" />
                <span class="text-sm">{{ $t('inventory.locations.allowProduction') }}</span>
              </label>
            </div>
            <div v-if="isEdit">
              <label class="flex items-center gap-2">
                <input v-model="form.is_active" type="checkbox" class="rounded" />
                <span class="text-sm">{{ $t('inventory.locations.active') }}</span>
              </label>
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-6 pt-4 border-t">
            <button type="button" @click="closeForm" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">{{ $t('common.cancel') }}</button>
            <button type="submit" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">{{ $t('common.save') }}</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { loadInventoryLocations } from '@/composables/useInventoryLocations';

const { t } = useI18n();
const loading = ref(false);
const locations = ref([]);
const showForm = ref(false);
const isEdit = ref(false);
const form = ref({
  location_code: '',
  location_name: '',
  location_type: 'WAREHOUSE',
  allow_grn: true,
  allow_transfer_out: true,
  allow_pos_sale: false,
  allow_production: true,
  is_active: true
});
let editingId = null;

function applyTypeDefaults() {
  if (form.value.location_type === 'WAREHOUSE') {
    form.value.allow_grn = true;
    form.value.allow_transfer_out = true;
    form.value.allow_production = true;
    form.value.allow_pos_sale = false;
  } else {
    form.value.allow_grn = true;
    form.value.allow_transfer_out = false;
    form.value.allow_production = false;
    form.value.allow_pos_sale = true;
  }
}

async function load() {
  loading.value = true;
  try {
    locations.value = await loadInventoryLocations(false);
  } finally {
    loading.value = false;
  }
}

function openCreate() {
  editingId = null;
  isEdit.value = false;
  form.value = {
    location_code: '',
    location_name: '',
    location_type: 'WAREHOUSE',
    allow_grn: true,
    allow_transfer_out: true,
    allow_pos_sale: false,
    allow_production: true,
    is_active: true
  };
  showForm.value = true;
}

function openEdit(loc) {
  editingId = loc.id;
  isEdit.value = true;
  form.value = {
    location_code: loc.location_code,
    location_name: loc.location_name,
    location_type: loc.location_type,
    allow_grn: !!loc.allow_grn,
    allow_transfer_out: !!loc.allow_transfer_out,
    allow_pos_sale: !!loc.allow_pos_sale,
    allow_production: !!loc.allow_production,
    is_active: !!loc.is_active
  };
  showForm.value = true;
}

function closeForm() {
  showForm.value = false;
}

async function saveLocation() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) {
      alert(t('common.error') || 'Database not available');
      return;
    }
    const payload = {
      location_code: form.value.location_code.trim(),
      location_name: form.value.location_name.trim(),
      location_type: form.value.location_type,
      allow_grn: form.value.allow_grn,
      allow_transfer_out: form.value.allow_transfer_out,
      allow_pos_sale: form.value.allow_pos_sale,
      allow_production: form.value.allow_production,
      is_active: form.value.is_active
    };
    if (isEdit.value && editingId) {
      const { error } = await supabaseClient.from('inventory_locations').update(payload).eq('id', editingId);
      if (error) throw error;
    } else {
      const { error } = await supabaseClient.from('inventory_locations').insert(payload);
      if (error) throw error;
    }
    closeForm();
    await load();
  } catch (e) {
    console.error(e);
    alert(e.message || 'Failed to save');
  }
}

async function disableLocation(loc) {
  if (!confirm(t('inventory.locations.confirmDisable') || 'Disable this location?')) return;
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return;
    const { error } = await supabaseClient.from('inventory_locations').update({ is_active: false }).eq('id', loc.id);
    if (error) throw error;
    await load();
  } catch (e) {
    console.error(e);
    alert(e.message || 'Failed to disable');
  }
}

onMounted(() => load());
</script>
