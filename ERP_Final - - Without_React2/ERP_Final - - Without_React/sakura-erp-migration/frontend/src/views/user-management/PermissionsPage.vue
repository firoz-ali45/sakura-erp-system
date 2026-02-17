<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.permissions') }}</h2>
      <p class="text-gray-600 mt-1">Permissions master – all available permissions by module</p>
    </div>

    <div v-if="loading" class="text-center py-12">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
      <p class="text-gray-600 mt-2">Loading...</p>
    </div>

    <div v-else class="space-y-6">
      <div v-for="(perms, module) in permissionsByModule" :key="module" class="bg-white rounded-lg shadow overflow-hidden">
        <div class="px-6 py-4 bg-gray-50 border-b font-semibold text-gray-800">{{ module }}</div>
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Permission Code</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Action</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Description</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="p in perms" :key="p.id" class="hover:bg-gray-50">
              <td class="px-6 py-4">
                <span class="font-mono text-sm text-[#284b44]">{{ p.permission_code }}</span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-600">{{ p.action || '-' }}</td>
              <td class="px-6 py-4 text-sm text-gray-600">{{ p.description || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="!Object.keys(permissionsByModule).length" class="text-gray-500 text-center py-8">No permissions found</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getPermissionsMaster } from '@/services/userManagementService';

const permissions = ref([]);
const loading = ref(true);

const permissionsByModule = computed(() => {
  const byModule = {};
  for (const p of permissions.value) {
    const m = p.module || 'Other';
    if (!byModule[m]) byModule[m] = [];
    byModule[m].push(p);
  }
  return byModule;
});

onMounted(async () => {
  loading.value = true;
  try {
    permissions.value = await getPermissionsMaster();
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
