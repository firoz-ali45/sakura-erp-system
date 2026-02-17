<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6 flex justify-between items-center">
      <div>
        <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.accessMatrix') }}</h2>
        <p class="text-gray-600 mt-1">Role × Permission matrix (click to toggle, SAP-style)</p>
      </div>
      <button v-if="hasChanges" @click="saveAll" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3d38]" :disabled="saving">
        {{ saving ? 'Saving...' : 'Save Changes' }}
      </button>
    </div>

    <div v-if="loading" class="text-center py-12">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
      <p class="text-gray-600 mt-2">Loading...</p>
    </div>

    <div v-else class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full min-w-[600px]">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-xs font-medium text-gray-500 uppercase text-left sticky left-0 bg-gray-50 z-10">Role</th>
            <th v-for="perm in allPermissionCodes" :key="perm" class="px-2 py-3 text-xs font-medium text-gray-500 uppercase text-center whitespace-nowrap">
              {{ perm }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-for="role in roles" :key="role.id" class="hover:bg-gray-50">
            <td class="px-4 py-3 font-medium text-gray-900 sticky left-0 bg-white z-10">
              <span class="text-sm">{{ role.role_name }}</span>
              <span class="block text-xs text-gray-500">{{ role.role_code }}</span>
            </td>
            <td v-for="perm in allPermissionCodes" :key="perm" class="px-2 py-2 text-center">
              <button
                type="button"
                @click="togglePermission(role.id, perm)"
                :class="['inline-block w-6 h-6 rounded cursor-pointer transition-all', hasPermission(role.id, perm) ? 'bg-green-500 hover:bg-green-600' : 'bg-gray-200 hover:bg-gray-300']"
                :title="hasPermission(role.id, perm) ? 'Click to remove' : 'Click to add'"
              >
                <i v-if="hasPermission(role.id, perm)" class="fas fa-check text-white text-xs leading-6"></i>
                <span v-else class="text-gray-500 text-xs">–</span>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!roles.length" class="text-gray-500 text-center py-8">No roles found</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getRoles, getRolePermissions, getPermissionsMaster, setRolePermissions } from '@/services/userManagementService';

const roles = ref([]);
const rolePerms = ref({});
const allPermissions = ref([]);
const loading = ref(true);
const saving = ref(false);
const pendingChanges = ref({});

const allPermissionCodes = computed(() => {
  const codes = new Set();
  for (const p of allPermissions.value) codes.add(p.permission_code);
  return [...codes].sort();
});

const hasChanges = computed(() => Object.keys(pendingChanges.value).length > 0);

function hasPermission(roleId, permissionCode) {
  const perms = rolePerms.value[roleId] || [];
  const pending = pendingChanges.value[roleId];
  if (pending && pending.has(permissionCode)) return true;
  if (pending && pending.has('!' + permissionCode)) return false;
  return perms.some(p => p.permission_code === permissionCode) || perms.some(p => p.permission_code === '*');
}

function getEffectivePerms(roleId) {
  const perms = rolePerms.value[roleId] || [];
  const base = new Set(perms.map(p => p.permission_code).filter(c => c !== '*'));
  const pending = pendingChanges.value[roleId];
  if (pending) {
    for (const c of pending) {
      if (c.startsWith('!')) base.delete(c.slice(1));
      else base.add(c);
    }
  }
  return [...base];
}

async function saveAll() {
  saving.value = true;
  try {
    for (const roleId of Object.keys(pendingChanges.value)) {
      const codes = getEffectivePerms(roleId);
      await setRolePermissions(roleId, codes);
    }
    pendingChanges.value = {};
    const permMap = {};
    for (const role of roles.value) {
      permMap[role.id] = await getRolePermissions(role.id);
    }
    rolePerms.value = permMap;
  } catch (e) {
    console.error(e);
    alert('Failed to save');
  } finally {
    saving.value = false;
  }
}

function togglePermission(roleId, permissionCode) {
  const perms = rolePerms.value[roleId] || [];
  const current = perms.some(p => p.permission_code === permissionCode) || perms.some(p => p.permission_code === '*');
  const p = pendingChanges.value[roleId] || new Set();
  const next = new Set(p);
  if (current) {
    next.add('!' + permissionCode);
    next.delete(permissionCode);
  } else {
    next.add(permissionCode);
    next.delete('!' + permissionCode);
  }
  if (next.size === 0) {
    const { [roleId]: _, ...rest } = pendingChanges.value;
    pendingChanges.value = rest;
  } else {
    pendingChanges.value = { ...pendingChanges.value, [roleId]: next };
  }
}

onMounted(async () => {
  loading.value = true;
  try {
    const [r, p] = await Promise.all([getRoles(), getPermissionsMaster()]);
    roles.value = r || [];
    allPermissions.value = p || [];
    const permMap = {};
    for (const role of roles.value) {
      permMap[role.id] = await getRolePermissions(role.id);
    }
    rolePerms.value = permMap;
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
