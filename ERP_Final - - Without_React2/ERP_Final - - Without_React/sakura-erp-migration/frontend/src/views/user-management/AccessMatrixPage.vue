<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.accessMatrix') }}</h2>
      <p class="text-gray-600 mt-1">Role × Permission matrix</p>
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
              <span v-if="hasPermission(role.id, perm)" class="inline-block w-5 h-5 rounded bg-green-500" title="Yes">
                <i class="fas fa-check text-white text-xs leading-5"></i>
              </span>
              <span v-else class="inline-block w-5 h-5 rounded bg-gray-200" title="No">–</span>
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
import { getRoles, getRolePermissions, getPermissionsMaster } from '@/services/userManagementService';

const roles = ref([]);
const rolePerms = ref({});
const allPermissions = ref([]);
const loading = ref(true);

const allPermissionCodes = computed(() => {
  const codes = new Set();
  for (const p of allPermissions.value) codes.add(p.permission_code);
  return [...codes].sort();
});

function hasPermission(roleId, permissionCode) {
  const perms = rolePerms.value[roleId] || [];
  return perms.some(p => p.permission_code === permissionCode) || perms.some(p => p.permission_code === '*');
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
