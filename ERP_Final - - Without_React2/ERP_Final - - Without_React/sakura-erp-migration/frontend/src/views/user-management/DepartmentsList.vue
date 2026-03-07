<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="flex flex-wrap justify-between items-center gap-3 mb-6">
      <h2 class="text-2xl font-bold text-gray-800">User Management → Departments</h2>
      <div class="flex flex-wrap items-center gap-2">
        <button
          @click="openCreate"
          class="px-3 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38] text-sm font-medium flex items-center gap-1.5"
        >
          <i class="fas fa-plus"></i>
          <span>Create Department</span>
        </button>
      </div>
    </div>
    <div class="flex gap-2 mb-4">
      <button
        v-for="t in tabs"
        :key="t"
        @click="tab = t"
        :class="['px-4 py-2 rounded', tab === t ? 'bg-[#284b44] text-white' : 'bg-gray-200']"
      >
        {{ t }}
      </button>
    </div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Code</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-for="dept in filteredDepartments" :key="dept.id">
            <td class="px-6 py-4 text-sm font-mono text-gray-800">{{ dept.code }}</td>
            <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ dept.name }}</td>
            <td class="px-6 py-4 text-sm text-gray-600">{{ dept.description || '—' }}</td>
            <td class="px-6 py-4">
              <span :class="['px-2 py-1 rounded text-xs font-medium', dept.is_active !== false ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600']">
                {{ dept.is_active !== false ? 'Active' : 'Inactive' }}
              </span>
            </td>
            <td class="px-6 py-4 text-right">
              <button
                @click="openEdit(dept)"
                class="text-[#284b44] hover:underline text-sm font-medium mr-3"
              >
                Edit
              </button>
              <button
                v-if="dept.is_active !== false"
                @click="confirmDeactivate(dept)"
                class="text-red-600 hover:underline text-sm font-medium"
              >
                Deactivate
              </button>
              <button
                v-else
                @click="activate(dept)"
                class="text-green-600 hover:underline text-sm font-medium"
              >
                Activate
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="filteredDepartments.length === 0" class="p-6 text-center text-gray-500">No departments found. Create one to use as single source of truth for PR and other forms.</p>
    </div>

    <!-- Create / Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="showModal = false">
      <div class="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-xl font-bold text-gray-800 mb-4">{{ editingId ? 'Edit Department' : 'Create Department' }}</h3>
        <form @submit.prevent="submitForm" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Code <span class="text-red-500">*</span></label>
            <input
              v-model="form.code"
              type="text"
              required
              class="w-full px-3 py-2 border rounded-lg"
              placeholder="e.g. PROC"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name <span class="text-red-500">*</span></label>
            <input
              v-model="form.name"
              type="text"
              required
              class="w-full px-3 py-2 border rounded-lg"
              placeholder="e.g. Procurement"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              v-model="form.description"
              rows="2"
              class="w-full px-3 py-2 border rounded-lg"
              placeholder="Optional"
            ></textarea>
          </div>
          <div v-if="editingId" class="flex items-center gap-2">
            <input v-model="form.is_active" type="checkbox" id="dept-active" />
            <label for="dept-active" class="text-sm text-gray-700">Active</label>
          </div>
          <div class="flex gap-2 pt-2">
            <button type="submit" class="px-4 py-2 bg-[#284b44] text-white rounded-lg">{{ editingId ? 'Update' : 'Create' }}</button>
            <button type="button" @click="showModal = false" class="px-4 py-2 bg-gray-200 rounded-lg">Cancel</button>
          </div>
        </form>
        <p v-if="formError" class="text-red-600 text-sm mt-2">{{ formError }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  fetchDepartmentsForManagement,
  createDepartment,
  updateDepartment,
  deleteDepartment
} from '@/services/supabase.js';

const departments = ref([]);
const tab = ref('Active');
const tabs = ['Active', 'Inactive', 'All'];
const showModal = ref(false);
const editingId = ref(null);
const form = ref({ code: '', name: '', description: '', is_active: true });
const formError = ref('');

const filteredDepartments = computed(() => {
  const t = tab.value.toLowerCase();
  if (t === 'active') return departments.value.filter(d => d.is_active !== false);
  if (t === 'inactive') return departments.value.filter(d => d.is_active === false);
  return departments.value;
});

function openCreate() {
  editingId.value = null;
  form.value = { code: '', name: '', description: '', is_active: true };
  formError.value = '';
  showModal.value = true;
}

function openEdit(dept) {
  editingId.value = dept.id;
  form.value = {
    code: dept.code,
    name: dept.name,
    description: dept.description || '',
    is_active: dept.is_active !== false
  };
  formError.value = '';
  showModal.value = true;
}

async function submitForm() {
  formError.value = '';
  try {
    if (editingId.value) {
      await updateDepartment(editingId.value, {
        code: form.value.code.trim(),
        name: form.value.name.trim(),
        description: form.value.description?.trim() || null,
        is_active: form.value.is_active
      });
    } else {
      await createDepartment({
        code: form.value.code.trim(),
        name: form.value.name.trim(),
        description: form.value.description?.trim() || null
      });
    }
    showModal.value = false;
    await load();
  } catch (e) {
    formError.value = e?.message || 'Failed to save';
  }
}

function confirmDeactivate(dept) {
  if (!confirm(`Deactivate department "${dept.name}"? It will no longer appear in dropdowns.`)) return;
  doDeactivate(dept.id);
}

async function doDeactivate(id) {
  try {
    await deleteDepartment(id, true);
    await load();
  } catch (e) {
    alert(e?.message || 'Failed to deactivate');
  }
}

async function activate(dept) {
  try {
    await updateDepartment(dept.id, { ...dept, is_active: true });
    await load();
  } catch (e) {
    alert(e?.message || 'Failed to activate');
  }
}

async function load() {
  departments.value = await fetchDepartmentsForManagement();
}

onMounted(load);
</script>
