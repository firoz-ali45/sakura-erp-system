<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6 flex flex-wrap justify-between items-center gap-3">
      <div>
        <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.activityLogs') }}</h2>
        <p class="text-gray-600 mt-1">User activity audit trail — filterable & exportable</p>
      </div>
      <button @click="exportLogs" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3d38] flex items-center gap-2">
        <i class="fas fa-download"></i>
        <span>Export CSV</span>
      </button>
    </div>

    <!-- Filters -->
    <div class="bg-white p-4 rounded-lg shadow-md mb-4">
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
        <div class="flex items-end">
          <button @click="loadLogs" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3d38]">
            <i class="fas fa-search mr-2"></i> Apply
          </button>
        </div>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">User</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Action</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Entity</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">IP</th>
            <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase text-left">Time</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading">
            <td colspan="5" class="px-6 py-12 text-center">
              <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
              <p class="text-gray-600 mt-2">Loading...</p>
            </td>
          </tr>
          <tr v-else-if="logs.length === 0">
            <td colspan="5" class="px-6 py-12 text-center text-gray-500">No activity logs found</td>
          </tr>
          <tr v-else v-for="log in logs" :key="log.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="font-medium text-gray-900">{{ log.users?.name || '-' }}</span>
              <span class="block text-xs text-gray-500">{{ log.users?.email || '' }}</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="px-2 py-1 text-xs font-semibold rounded-full bg-[#284b44]/10 text-[#284b44]">{{ log.action }}</span>
            </td>
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
import { getActivityLogs, getUsersEnriched } from '@/services/userManagementService';

const logs = ref([]);
const users = ref([]);
const loading = ref(true);
const filterUserId = ref('');
const filterAction = ref('');

function formatDate(d) {
  if (!d) return '-';
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? '-' : dt.toLocaleString();
  } catch { return '-'; }
}

function exportLogs() {
  if (logs.value.length === 0) {
    alert('No data to export');
    return;
  }
  const headers = ['Date', 'User', 'Email', 'Action', 'Module', 'Reference', 'IP'];
  const rows = logs.value.map(l => [
    formatDate(l.created_at),
    l.users?.name || '-',
    l.users?.email || '-',
    l.action || '-',
    l.entity_type || '-',
    l.entity_id || '-',
    l.ip_address || '-'
  ]);
  const csv = [headers.join(','), ...rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `activity-logs-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

async function loadLogs() {
  loading.value = true;
  try {
    const filters = {};
    if (filterUserId.value) filters.user_id = filterUserId.value;
    if (filterAction.value?.trim()) filters.action = filterAction.value.trim();
    logs.value = await getActivityLogs(filters);
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  users.value = await getUsersEnriched();
  await loadLogs();
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
