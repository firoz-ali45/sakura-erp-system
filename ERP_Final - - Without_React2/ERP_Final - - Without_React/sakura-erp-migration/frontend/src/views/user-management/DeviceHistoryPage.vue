<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → Device History</h2>
      <p class="text-gray-600 mt-1">Login sessions by device</p>
    </div>

    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">User</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Device / Browser</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">IP</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Login</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading">
            <td colspan="5" class="px-6 py-12 text-center">
              <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
              <p class="text-gray-600 mt-2">Loading...</p>
            </td>
          </tr>
          <tr v-else-if="sessions.length === 0">
            <td colspan="5" class="px-6 py-12 text-center text-gray-500">No device history found</td>
          </tr>
          <tr v-else v-for="s in sessions" :key="s.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="font-medium text-gray-900">{{ s.users?.name || '-' }}</span>
              <span class="block text-xs text-gray-500">{{ s.users?.email || '' }}</span>
            </td>
            <td class="px-6 py-4 text-sm text-gray-600 max-w-xs truncate" :title="s.device">{{ s.device || '-' }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ s.ip_address || '-' }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(s.login_time) }}</td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span :class="['px-2 py-1 text-xs font-semibold rounded-full', s.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600']">
                {{ s.is_active ? 'Active' : 'Ended' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { getLoginSessions } from '@/services/userManagementService';

const sessions = ref([]);
const loading = ref(true);

function formatDate(d) {
  if (!d) return '-';
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? '-' : dt.toLocaleString();
  } catch { return '-'; }
}

onMounted(async () => {
  loading.value = true;
  try {
    sessions.value = await getLoginSessions(false, null);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
