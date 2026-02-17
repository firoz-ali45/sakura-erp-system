<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.roles') }}</h2>
      <button @click="showCreateModal = true" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38]">
        <i class="fas fa-plus mr-2"></i>{{ $t('userManagement.createRole') }}
      </button>
    </div>
    <div class="flex gap-2 mb-4">
      <button v-for="t in tabs" :key="t" @click="tab = t" :class="['px-4 py-2 rounded', tab === t ? 'bg-[#284b44] text-white' : 'bg-gray-200']">{{ t }}</button>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="role in filteredRoles"
        :key="role.id"
        class="bg-white rounded-lg shadow p-6 cursor-pointer hover:shadow-lg transition-shadow"
        @click="$router.push(`/homeportal/user-management/role/${role.id}`)"
      >
        <h3 class="font-bold text-lg text-[#284b44]">{{ role.role_name }}</h3>
        <p class="text-sm text-gray-600 mt-1">{{ role.description || '-' }}</p>
        <span class="text-xs text-gray-500">{{ role.role_code }}</span>
      </div>
    </div>

    <!-- Create Role Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="showCreateModal = false">
      <div class="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-xl font-bold text-gray-800 mb-4">{{ $t('userManagement.createRole') }}</h3>
        <form @submit.prevent="submitCreateRole" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Role Name</label>
            <input v-model="createForm.role_name" type="text" required class="w-full px-3 py-2 border rounded-lg" placeholder="e.g. Warehouse Manager" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Role Code</label>
            <input v-model="createForm.role_code" type="text" class="w-full px-3 py-2 border rounded-lg" placeholder="e.g. WAREHOUSE_MANAGER" />
            <p class="text-xs text-gray-500 mt-1">Auto-generated if empty</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea v-model="createForm.description" rows="2" class="w-full px-3 py-2 border rounded-lg" placeholder="Optional"></textarea>
          </div>
          <div class="flex gap-2 pt-2">
            <button type="submit" class="px-4 py-2 bg-[#284b44] text-white rounded-lg">Create</button>
            <button type="button" @click="showCreateModal = false" class="px-4 py-2 bg-gray-200 rounded-lg">Cancel</button>
          </div>
        </form>
        <p v-if="createError" class="text-red-600 text-sm mt-2">{{ createError }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { getRoles, createRole } from '@/services/userManagementService';

const router = useRouter();
const roles = ref([]);
const tab = ref('Active');
const tabs = ['Active', 'Inactive', 'Deleted'];
const showCreateModal = ref(false);
const createForm = ref({ role_name: '', role_code: '', description: '' });
const createError = ref('');

const filteredRoles = computed(() => {
  const t = tab.value.toLowerCase();
  if (t === 'active') return roles.value.filter(r => r.is_active !== false);
  if (t === 'inactive') return roles.value.filter(r => r.is_active === false);
  return roles.value;
});

async function submitCreateRole() {
  createError.value = '';
  try {
    const code = createForm.value.role_code || createForm.value.role_name?.toUpperCase().replace(/\s+/g, '_');
    const role = await createRole({
      role_name: createForm.value.role_name,
      role_code: code,
      description: createForm.value.description || null
    });
    showCreateModal.value = false;
    createForm.value = { role_name: '', role_code: '', description: '' };
    roles.value = await getRoles();
    router.push(`/homeportal/user-management/role/${role.id}`);
  } catch (e) {
    createError.value = e.message || 'Failed to create role';
  }
}

onMounted(async () => {
  roles.value = await getRoles();
});
</script>
