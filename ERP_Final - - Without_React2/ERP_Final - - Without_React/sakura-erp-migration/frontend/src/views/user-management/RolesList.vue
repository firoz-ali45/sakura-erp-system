<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="flex flex-wrap justify-between items-center gap-3 mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.roles') }}</h2>
      <div class="flex flex-wrap items-center gap-2">
        <button v-if="canCreateRole" @click="showCreateModal = true" class="px-3 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38] text-sm font-medium flex items-center gap-1.5">
          <i class="fas fa-plus"></i>
          <span>Create Role</span>
        </button>
        <button v-if="selectedRole && canCreateRole" @click="$router.push(`/homeportal/user-management/role/${selectedRole.id}`)" class="px-3 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 text-sm font-medium flex items-center gap-1.5">
          <i class="fas fa-edit"></i>
          <span>Edit Role</span>
        </button>
        <button v-if="selectedRole && tab !== 'Deleted' && canDeleteRole" @click="doDeleteRole" class="px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm font-medium flex items-center gap-1.5">
          <i class="fas fa-trash"></i>
          <span>Delete (soft)</span>
        </button>
        <button v-if="selectedRole && canCreateRole" @click="doCloneRole" class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium flex items-center gap-1.5">
          <i class="fas fa-copy"></i>
          <span>Clone Role</span>
        </button>
      </div>
    </div>
    <div class="flex gap-2 mb-4">
      <button v-for="t in tabs" :key="t" @click="tab = t" :class="['px-4 py-2 rounded', tab === t ? 'bg-[#284b44] text-white' : 'bg-gray-200']">{{ t }}</button>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="role in filteredRoles"
        :key="role.id"
        :class="['bg-white rounded-lg shadow p-6 cursor-pointer hover:shadow-lg transition-shadow', selectedRole?.id === role.id ? 'ring-2 ring-[#284b44]' : '']"
        @click="selectedRole = selectedRole?.id === role.id ? null : role"
        @dblclick="$router.push(`/homeportal/user-management/role/${role.id}`)"
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
import { getRoles, createRole, updateRole, cloneRole, isSuperAdmin } from '@/services/userManagementService';
import { usePermissions } from '@/composables/usePermissions';

const router = useRouter();
const { permissions, loadPermissions } = usePermissions();
const canCreateRole = computed(() => {
  if (_isAdmin()) return true;
  const p = permissions.value;
  return p.has('*') || p.has('user_management_view') || p.has('user_management_roles') || p.has('role_create');
});

function _isAdmin() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (!u) return false;
    const parsed = JSON.parse(u);
    const role = (parsed.role || parsed.primaryRoleCode || '').toLowerCase();
    return role === 'admin' || role === 'administrator';
  } catch { return false; }
}
const roles = ref([]);
const canDeleteRole = ref(false);
const tab = ref('Active');
const tabs = ['Active', 'Inactive', 'Deleted'];
const selectedRole = ref(null);
const showCreateModal = ref(false);
const createForm = ref({ role_name: '', role_code: '', description: '' });
const createError = ref('');

const filteredRoles = computed(() => {
  const t = tab.value.toLowerCase();
  if (t === 'active') return roles.value.filter(r => (r.is_active !== false) && !r.deleted);
  if (t === 'inactive') return roles.value.filter(r => (r.is_active === false) && !r.deleted);
  if (t === 'deleted') return roles.value.filter(r => !!r.deleted);
  return roles.value;
});

async function doDeleteRole() {
  if (!selectedRole.value || !confirm(`Soft delete role "${selectedRole.value.role_name}"?`)) return;
  try {
    await updateRole(selectedRole.value.id, { deleted: true, is_active: false });
    selectedRole.value = null;
    roles.value = await getRoles();
  } catch (e) {
    console.error(e);
    alert('Failed to delete role');
  }
}

async function doCloneRole() {
  if (!selectedRole.value) return;
  try {
    const created = await cloneRole(selectedRole.value.id);
    selectedRole.value = null;
    roles.value = await getRoles();
    router.push(`/homeportal/user-management/role/${created.id}`);
  } catch (e) {
    console.error(e);
    alert('Failed to clone role');
  }
}

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
  await loadPermissions();
  roles.value = await getRoles();
  const uid = JSON.parse(localStorage.getItem('sakura_current_user') || '{}')?.id;
  canDeleteRole.value = uid ? await isSuperAdmin(uid) : false;
});
</script>
