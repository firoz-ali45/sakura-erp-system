<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → Blocked Users</h2>
      <p class="text-gray-600 mt-1">Suspended and blocked user accounts</p>
    </div>

    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">User</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Status</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading">
            <td colspan="3" class="px-6 py-12 text-center">
              <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
              <p class="text-gray-600 mt-2">Loading...</p>
            </td>
          </tr>
          <tr v-else-if="users.length === 0">
            <td colspan="3" class="px-6 py-12 text-center text-gray-500">No blocked users</td>
          </tr>
          <tr v-else v-for="u in users" :key="u.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="font-medium text-gray-900">{{ u.name || '-' }}</span>
              <span class="block text-xs text-gray-500">{{ u.email || '' }}</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span :class="['px-2 py-1 text-xs font-semibold rounded-full', statusClass(u.status)]">
                {{ u.status || 'blocked' }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <button
                @click="unblockUser(u)"
                class="text-[#284b44] hover:underline text-sm font-medium"
              >
                Unblock
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { getBlockedUsers, updateUserStatus } from '@/services/userManagementService';

const users = ref([]);
const loading = ref(true);

function statusClass(s) {
  const v = (s || '').toLowerCase();
  if (v === 'suspended') return 'bg-yellow-100 text-yellow-800';
  if (v === 'blocked') return 'bg-red-100 text-red-800';
  return 'bg-gray-100 text-gray-600';
}

async function unblockUser(u) {
  if (!confirm(`Unblock ${u.name || u.email}?`)) return;
  try {
    await updateUserStatus(u.id, 'active');
    users.value = users.value.filter(x => x.id !== u.id);
  } catch (e) {
    console.error(e);
    alert('Failed to unblock user');
  }
}

onMounted(async () => {
  loading.value = true;
  try {
    users.value = await getBlockedUsers();
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
