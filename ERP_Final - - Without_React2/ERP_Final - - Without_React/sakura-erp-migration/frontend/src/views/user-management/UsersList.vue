<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl md:text-3xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.users') }}</h2>
        <button 
          v-if="canCreateUser"
          @click="$router.push('/homeportal/user-management/user/new')" 
          class="px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-lg hover:from-green-700 hover:to-green-800 transition-all font-medium shadow-md flex items-center gap-2"
        >
          <i class="fas fa-user-plus"></i>
          <span>{{ $t('userManagement.createUser') }}</span>
        </button>
      </div>

      <!-- Tabs: Active | Inactive | Suspended | Deleted -->
      <div class="flex gap-2 mb-4 border-b border-gray-300 pb-2">
        <button 
          v-for="tab in tabs" 
          :key="tab.value"
          @click="activeTab = tab.value"
          :class="['px-4 py-2 rounded-lg font-medium transition-all', activeTab === tab.value ? 'bg-[#284b44] text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300']"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- Search & Filters -->
      <div class="bg-white p-4 rounded-lg shadow-md mb-4">
        <div class="flex flex-col md:flex-row gap-4">
          <div class="flex-1">
            <input 
              type="text" 
              v-model="searchTerm"
              :placeholder="$t('userManagement.searchPlaceholder')" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]"
            >
          </div>
          <select v-model="roleFilter" class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#284b44]">
            <option value="">{{ $t('userManagement.allRoles') }}</option>
            <option v-for="r in roles" :key="r.id" :value="r.role_code">{{ r.role_name }}</option>
          </select>
        </div>
      </div>

      <!-- Table -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">User name</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Email</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Role</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Department</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Assigned Locations</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Last login</th>
              <th class="px-6 py-3 text-xs font-medium text-gray-500 uppercase">Created date</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-if="loading">
              <td colspan="8" class="px-6 py-12 text-center">
                <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
                <p class="text-gray-600 mt-2">{{ $t('userManagement.loadingUsers') }}</p>
              </td>
            </tr>
            <tr v-else-if="filteredUsers.length === 0">
              <td colspan="8" class="px-6 py-12 text-center text-gray-500">{{ $t('userManagement.noUsersFound') }}</td>
            </tr>
            <tr 
              v-else 
              v-for="user in filteredUsers" 
              :key="user.id" 
              class="hover:bg-gray-50 cursor-pointer"
              @click="$router.push(`/homeportal/user-management/user/${user.id}`)"
            >
              <td class="px-6 py-4 whitespace-nowrap font-medium text-gray-900">{{ user.name }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ user.email }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 py-1 text-xs font-semibold rounded-full bg-[#284b44]/10 text-[#284b44]">{{ user.primaryRoleName || getRoleName(user.role) }}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ user.department || '-' }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">{{ user.assignedLocations || 'All' }}</td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="['px-2 py-1 text-xs font-semibold rounded-full', getStatusClass(user.status)]">{{ getStatusLabel(user.status) }}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(user.last_login || user.lastLogin) }}</td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ formatDate(user.created_at || user.createdAt) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getUsersEnriched, getRoles } from '@/services/userManagementService';
import { useI18n } from '@/composables/useI18n';
import { usePermissions } from '@/composables/usePermissions';
import { formatDate as formatDateUtil } from '@/utils/dateFormat';

const { t, locale } = useI18n();
const { permissions, loadPermissions } = usePermissions();
const canCreateUser = computed(() => {
  const p = permissions.value;
  return p.has('*') || p.has('user_management_view') || p.has('user_management_users');
});
const users = ref([]);
const roles = ref([]);
const loading = ref(false);
const searchTerm = ref('');
const roleFilter = ref('');
const activeTab = ref('active');

const tabs = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'suspended', label: 'Suspended' },
  { value: 'deleted', label: 'Deleted' }
];

const filteredUsers = computed(() => {
  let list = users.value.filter(u => (u.status || 'active').toLowerCase() === activeTab.value);
  if (searchTerm.value) {
    const term = searchTerm.value.toLowerCase();
    list = list.filter(u => 
      u.name?.toLowerCase().includes(term) || u.email?.toLowerCase().includes(term) || 
      (u.primaryRoleName || u.role)?.toLowerCase().includes(term) || (u.primaryRoleCode || u.role)?.toLowerCase().includes(term)
    );
  }
  if (roleFilter.value) {
    list = list.filter(u => (u.primaryRoleCode || u.role || '').toLowerCase() === roleFilter.value.toLowerCase());
  }
  return list;
});

function getRoleName(role) {
  const r = roles.value.find(x => (x.role_code || '').toLowerCase() === (role || '').toLowerCase());
  return r?.role_name || role;
}

function getStatusLabel(s) {
  const m = { active: 'Active', inactive: 'Inactive', suspended: 'Suspended', deleted: 'Deleted' };
  return m[(s || 'active').toLowerCase()] || s;
}

function getStatusClass(s) {
  const m = { active: 'bg-green-100 text-green-800', inactive: 'bg-yellow-100 text-yellow-800', suspended: 'bg-red-100 text-red-800', deleted: 'bg-gray-100 text-gray-800' };
  return m[(s || 'active').toLowerCase()] || 'bg-gray-100 text-gray-800';
}

function formatDate(d) {
  if (!d) return t('userManagement.never');
  try {
    return formatDateUtil(new Date(d), locale.value, { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: true });
  } catch {
    return '-';
  }
}

async function load() {
  loading.value = true;
  try {
    const [u, r] = await Promise.all([getUsersEnriched(), getRoles()]);
    users.value = u || [];
    roles.value = r || [];
  } catch (e) {
    console.error(e);
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await loadPermissions();
  load();
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
