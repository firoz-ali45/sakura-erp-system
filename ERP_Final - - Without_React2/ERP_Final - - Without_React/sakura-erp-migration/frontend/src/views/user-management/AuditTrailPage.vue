<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → Audit Trail</h2>
      <p class="text-gray-600 mt-1">Full audit trail — every create/edit/delete/approve logged (Super Admin only)</p>
    </div>

    <div v-if="!canAccess" class="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
      <p class="text-red-700 font-medium">Super Admin access required</p>
      <p class="text-sm text-red-600 mt-1">Only Super Admins can access the full audit trail.</p>
    </div>

    <div v-else class="bg-white p-4 rounded-lg shadow-md mb-4">
      <div class="flex flex-col md:flex-row gap-4">
        <div class="flex-1">
          <label class="block text-sm text-gray-600 mb-1">User</label>
          <select v-model="filterUserId" class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]">
            <option value="">All users</option>
            <option v-for="u in users" :key="u.id" :value="u.id">{{ u.name }} ({{ u.email }})</option>
          </select>
        </div>
        <div class="flex-1">
          <label class="block text-sm text-gray-600 mb-1">Action</label>
          <input v-model="filterAction" type="text" placeholder="Filter by action..." class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]" />
        </div>
        <div class="flex-1">
          <label class="block text-sm text-gray-600 mb-1">Module</label>
          <input v-model="filterModule" type="text" placeholder="Filter by module..." class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]" />
        </div>
        <div class="flex items-end">
          <button @click="loadLogs" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3d38]">
            <i class="fas fa-search mr-2"></i> Apply
          </button>
        </div>
      </div>
    </div>

    <div v-if="canAccess" class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">User</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Action</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Module</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Entity</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">IP</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Time</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading">
            <td colspan="6" class="px-6 py-12 text-center">
              <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
              <p class="text-gray-600 mt-2">Loading...</p>
            </td>
          </tr>
          <tr v-else-if="logs.length === 0">
            <td colspan="6" class="px-6 py-12 text-center text-gray-500">No audit records found</td>
          </tr>
          <tr v-else v-for="log in logs" :key="log.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="font-medium text-gray-900">{{ log.users?.name || '-' }}</span>
              <span class="block text-xs text-gray-500">{{ log.users?.email || '' }}</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="px-2 py-1 text-xs font-semibold rounded-full bg-[#284b44]/10 text-[#284b44]">{{ log.action }}</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ log.module || '-' }}</td>
            <td class="px-6 py-4 text-sm">
              <span v-if="log.entity_type">{{ log.entity_type }}</span>
              <span v-if="log.entity_id" class="text-gray-500"> #{{ String(log.entity_id).slice(0, 8) }}</span>
              <span v-if="!log.entity_type && !log.entity_id">-</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ log.ip_address || '-' }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(log.created_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { getErpAuditLogs, getUsersEnriched, isSuperAdmin } from '@/services/userManagementService';

const logs = ref([]);
const users = ref([]);
const loading = ref(true);
const canAccess = ref(false);
const filterUserId = ref('');
const filterAction = ref('');
const filterModule = ref('');

function formatDate(d) {
  if (!d) return '-';
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? '-' : dt.toLocaleString();
  } catch { return '-'; }
}

async function loadLogs() {
  loading.value = true;
  try {
    const filters = {};
    if (filterUserId.value) filters.user_id = filterUserId.value;
    if (filterAction.value?.trim()) filters.action = filterAction.value.trim();
    if (filterModule.value?.trim()) filters.module = filterModule.value.trim();
    logs.value = await getErpAuditLogs(filters);
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  const uid = JSON.parse(localStorage.getItem('sakura_current_user') || '{}')?.id;
  canAccess.value = uid ? await isSuperAdmin(uid) : false;
  if (!canAccess.value) return;
  users.value = await getUsersEnriched();
  await loadLogs();
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
