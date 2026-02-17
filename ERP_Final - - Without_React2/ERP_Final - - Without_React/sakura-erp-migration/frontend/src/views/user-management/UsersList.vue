<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <div class="flex flex-wrap justify-between items-center gap-3 mb-4">
        <h2 class="text-2xl md:text-3xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.users') }}</h2>
        <div class="flex flex-wrap items-center gap-2">
          <button 
            v-if="canCreateUser"
            @click="$router.push('/homeportal/user-management/user/new')" 
            class="px-3 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3d38] text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-user-plus"></i>
            <span>Create New User</span>
          </button>
          <button 
            v-if="selectedUser && canCreateUser"
            @click="$router.push(`/homeportal/user-management/user/${selectedUser.id}`)"
            class="px-3 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-edit"></i>
            <span>Edit User</span>
          </button>
          <button 
            v-if="selectedUser && activeTab !== 'deleted'"
            @click="doDeleteUser"
            class="px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-trash"></i>
            <span>Delete (soft)</span>
          </button>
          <button 
            v-if="selectedUser && (selectedUser.status || 'active') === 'active'"
            @click="doSuspendUser"
            class="px-3 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-ban"></i>
            <span>Suspend</span>
          </button>
          <button 
            v-if="selectedUser && (selectedUser.status || '').toLowerCase() === 'suspended'"
            @click="doRestoreUser"
            class="px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-user-check"></i>
            <span>Restore</span>
          </button>
          <button 
            v-if="selectedUser"
            @click="showResetPassword = true"
            class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-key"></i>
            <span>Reset Password</span>
          </button>
          <button 
            v-if="selectedUser"
            @click="doForceLogout"
            class="px-3 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-sm font-medium flex items-center gap-1.5"
          >
            <i class="fas fa-sign-out-alt"></i>
            <span>Force Logout</span>
          </button>
        </div>
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
              :class="['hover:bg-gray-50 cursor-pointer', selectedUser?.id === user.id ? 'bg-[#284b44]/5 ring-1 ring-[#284b44]/30' : '']"
              @click="selectedUser = selectedUser?.id === user.id ? null : user"
              @dblclick="$router.push(`/homeportal/user-management/user/${user.id}`)"
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

    <!-- Reset Password Modal -->
    <div v-if="showResetPassword && selectedUser" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="showResetPassword = false">
      <div class="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-lg font-bold text-gray-800 mb-2">Reset Password</h3>
        <p class="text-sm text-gray-600 mb-4">New password for {{ selectedUser.name }} ({{ selectedUser.email }})</p>
        <input v-model="resetPasswordValue" type="password" placeholder="New password" class="w-full px-3 py-2 border rounded-lg mb-4" />
        <div class="flex gap-2">
          <button @click="doResetPassword" class="px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="!resetPasswordValue?.trim()">Reset</button>
          <button @click="showResetPassword = false; resetPasswordValue = ''" class="px-4 py-2 bg-gray-200 rounded-lg">Cancel</button>
        </div>
        <p v-if="resetError" class="text-red-600 text-sm mt-2">{{ resetError }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getUsersEnriched, getRoles, updateUserStatus, forceLogoutUser, resetUserPassword } from '@/services/userManagementService';
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
const selectedUser = ref(null);
const showResetPassword = ref(false);
const resetPasswordValue = ref('');
const resetError = ref('');

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

async function doDeleteUser() {
  if (!selectedUser.value || !confirm(`Soft delete ${selectedUser.value.name}? User will move to Deleted tab.`)) return;
  try {
    await updateUserStatus(selectedUser.value.id, 'deleted');
    selectedUser.value = null;
    await load();
  } catch (e) {
    console.error(e);
    alert('Failed to delete user');
  }
}

async function doSuspendUser() {
  if (!selectedUser.value || !confirm(`Suspend ${selectedUser.value.name}?`)) return;
  try {
    await updateUserStatus(selectedUser.value.id, 'suspended');
    selectedUser.value = null;
    await load();
  } catch (e) {
    console.error(e);
    alert('Failed to suspend user');
  }
}

async function doRestoreUser() {
  if (!selectedUser.value || !confirm(`Restore ${selectedUser.value.name}?`)) return;
  try {
    await updateUserStatus(selectedUser.value.id, 'active');
    selectedUser.value = null;
    await load();
  } catch (e) {
    console.error(e);
    alert('Failed to restore user');
  }
}

async function doResetPassword() {
  if (!selectedUser.value || !resetPasswordValue.value?.trim()) return;
  resetError.value = '';
  try {
    await resetUserPassword(selectedUser.value.id, resetPasswordValue.value.trim());
    showResetPassword.value = false;
    resetPasswordValue.value = '';
  } catch (e) {
    resetError.value = e.message || 'Failed to reset password';
  }
}

async function doForceLogout() {
  if (!selectedUser.value || !confirm(`Force logout all sessions for ${selectedUser.value.name}?`)) return;
  try {
    await forceLogoutUser(selectedUser.value.id);
    alert('User sessions closed.');
    selectedUser.value = null;
  } catch (e) {
    console.error(e);
    alert('Failed to force logout');
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
