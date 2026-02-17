<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl md:text-3xl font-bold text-gray-800">{{ $t('homePortal.userManagementTitle') }}</h2>
        <button 
          @click="openAddUserModal" 
          class="px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-lg hover:from-green-700 hover:to-green-800 transition-all font-medium shadow-md flex items-center gap-2"
        >
          <i class="fas fa-user-plus"></i>
          <span>{{ $t('homePortal.addUser') }}</span>
        </button>
      </div>

      <!-- User Statistics -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="kpi-card">
          <div class="icon bg-[#284b44]"><i class="fas fa-users"></i></div>
          <div>
            <p class="title">{{ $t('homePortal.totalUsers') }}</p>
            <div class="value">{{ userStats.total }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-green-500"><i class="fas fa-user-check"></i></div>
          <div>
            <p class="title">{{ $t('homePortal.activeUsers') }}</p>
            <div class="value">{{ userStats.active }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-yellow-500"><i class="fas fa-user-shield"></i></div>
          <div>
            <p class="title">{{ $t('homePortal.adminUsers') }}</p>
            <div class="value">{{ userStats.admins }}</div>
          </div>
        </div>
        <div class="kpi-card">
          <div class="icon bg-orange-500"><i class="fas fa-user-clock"></i></div>
          <div>
            <p class="title">{{ $t('userManagement.pendingApproval') }}</p>
            <div class="value">{{ userStats.pending }}</div>
          </div>
        </div>
      </div>

      <!-- User Search and Filters -->
      <div class="bg-white p-4 rounded-lg shadow-md mb-4">
        <div class="flex flex-col md:flex-row gap-4">
          <div class="flex-1">
            <input 
              type="text" 
              v-model="searchTerm"
              @input="filterUsers"
              :placeholder="$t('userManagement.searchPlaceholder')" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
            >
          </div>
          <select 
            v-model="roleFilter"
            @change="filterUsers"
            class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
          >
            <option value="">{{ $t('userManagement.allRoles') }}</option>
            <option value="admin">{{ $t('userManagement.roleAdmin') }}</option>
            <option value="manager">{{ $t('userManagement.roleManager') }}</option>
            <option value="supervisor">{{ $t('userManagement.roleSupervisor') }}</option>
            <option value="logistics_manager">{{ $t('userManagement.roleLogisticsManager') }}</option>
            <option value="warehouse_manager">{{ $t('userManagement.roleWarehouseManager') }}</option>
            <option value="branch_manager">{{ $t('userManagement.roleBranchManager') }}</option>
            <option value="driver">{{ $t('userManagement.roleDriver') }}</option>
            <option value="finance">{{ $t('userManagement.roleFinance') }}</option>
            <option value="auditor">{{ $t('userManagement.roleAuditor') }}</option>
            <option value="procurement">{{ $t('userManagement.roleProcurement') }}</option>
            <option value="inventory_manager">{{ $t('userManagement.roleInventoryManager') }}</option>
            <option value="user">{{ $t('userManagement.roleUser') }}</option>
            <option value="viewer">{{ $t('userManagement.roleViewer') }}</option>
          </select>
          <select 
            v-model="statusFilter"
            @change="filterUsers"
            class="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
          >
            <option value="">{{ $t('userManagement.allStatus') }}</option>
            <option value="active">{{ $t('userManagement.statusActive') }}</option>
            <option value="inactive">{{ $t('userManagement.statusInactive') }}</option>
            <option value="suspended">{{ $t('userManagement.statusSuspended') }}</option>
          </select>
        </div>
      </div>

      <!-- Users Table -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('homePortal.userName') }}</th>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('homePortal.userEmail') }}</th>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('homePortal.userRole') }}</th>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('homePortal.userStatus') }}</th>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('homePortal.lastActivity') }}</th>
                <th :class="['px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider', isRTL ? 'text-right' : 'text-left']">{{ $t('common.actions') }}</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-if="loading">
                <td colspan="6" class="px-6 py-12 text-center">
                  <div class="flex flex-col items-center justify-center space-y-4">
                    <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin"></div>
                    <p class="text-gray-600">{{ $t('userManagement.loadingUsers') }}</p>
                  </div>
                </td>
              </tr>
              <tr v-else-if="filteredUsers.length === 0">
                <td colspan="6" class="px-6 py-12 text-center text-gray-500">{{ $t('userManagement.noUsersFound') }}</td>
              </tr>
              <tr v-else v-for="user in filteredUsers" :key="user.id" class="hover:bg-gray-50">
                <td :class="['px-6 py-4 whitespace-nowrap', isRTL ? 'text-right' : 'text-left']">
                  <div class="flex items-center">
                    <div class="flex-shrink-0 h-10 w-10 relative">
                      <img 
                        v-if="user.profile_photo_url" 
                        :src="user.profile_photo_url" 
                        :alt="user.name" 
                        class="h-10 w-10 rounded-full object-cover border-2 border-gray-300"
                        @error="handleImageError"
                      >
                      <div 
                        v-else
                        class="h-10 w-10 rounded-full bg-gradient-to-r from-gray-400 to-gray-600 flex items-center justify-center text-white font-bold"
                      >
                        {{ user.name.charAt(0).toUpperCase() }}
                      </div>
                    </div>
                    <div :class="isRTL ? 'mr-4' : 'ml-4'">
                      <div class="text-sm font-medium text-gray-900">{{ user.name }}</div>
                      <div class="text-xs text-gray-500 mt-1">
                        <span 
                          v-if="user.email_verified === true || user.email_verified === 'true'"
                          class="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
                          :title="$t('userManagement.emailVerified')"
                        >
                          <i :class="['fas', 'fa-check-circle', isRTL ? 'ml-1' : 'mr-1']"></i>{{ $t('userManagement.verified') }}
                        </span>
                        <span 
                          v-else
                          class="px-2 py-1 text-xs font-semibold rounded-full bg-orange-100 text-orange-800"
                          :title="$t('userManagement.emailNotVerified')"
                        >
                          <i :class="['fas', 'fa-exclamation-circle', isRTL ? 'ml-1' : 'mr-1']"></i>{{ $t('userManagement.unverified') }}
                        </span>
                      </div>
                    </div>
                  </div>
                </td>
                <td :class="['px-6 py-4 whitespace-nowrap', isRTL ? 'text-right' : 'text-left']">
                  <div class="text-sm text-gray-900">{{ user.email }}</div>
                </td>
                <td :class="['px-6 py-4 whitespace-nowrap', isRTL ? 'text-right' : 'text-left']">
                  <span 
                    :class="getRoleBadgeClass(user.role)"
                    class="px-2 py-1 text-xs font-semibold rounded-full"
                  >
                    {{ getRoleLabel(user.role) }}
                  </span>
                </td>
                <td :class="['px-6 py-4 whitespace-nowrap', isRTL ? 'text-right' : 'text-left']">
                  <span 
                    :class="getStatusBadgeClass(user.status)"
                    class="px-2 py-1 text-xs font-semibold rounded-full"
                  >
                    {{ getStatusLabel(user.status) }}
                  </span>
                </td>
                <td :class="['px-6 py-4 whitespace-nowrap text-sm text-gray-500', isRTL ? 'text-right' : 'text-left']">
                  {{ formatDate(user.lastActivity || user.last_activity) }}
                </td>
                <td :class="['px-6 py-4 whitespace-nowrap text-sm font-medium', isRTL ? 'text-right' : 'text-left']">
                  <div :class="['flex items-center gap-2', isRTL ? 'justify-end' : 'justify-start']">
                    <!-- Approve/Reject buttons for inactive users -->
                    <template v-if="user.status === 'inactive' && canManageUsers">
                      <button 
                        @click="approveUser(user.id)" 
                        class="text-green-600 hover:text-green-900" 
                        :title="$t('userManagement.approveUser')"
                      >
                        <i class="fas fa-check-circle"></i>
                      </button>
                      <button 
                        @click="rejectUser(user.id)" 
                        class="text-red-600 hover:text-red-900" 
                        :title="$t('userManagement.rejectUser')"
                      >
                        <i class="fas fa-times-circle"></i>
                      </button>
                    </template>
                    
                    <!-- Resend verification for unverified users -->
                    <button 
                      v-if="!isEmailVerified(user) && canManageUsers"
                      @click="resendVerificationEmail(user.id)" 
                      class="text-[#284b44] hover:text-[#1f3d38]" 
                      :title="$t('userManagement.resendVerificationEmail')"
                    >
                      <i class="fas fa-envelope"></i>
                    </button>
                    
                    <!-- Edit/Delete buttons for admins -->
                    <template v-if="canManageUsers">
                      <button 
                        @click="editUser(user.id)" 
                        class="text-[#284b44] hover:text-[#1f3d38]" 
                        :title="$t('userManagement.editUser')"
                      >
                        <i class="fas fa-edit"></i>
                      </button>
                      <button 
                        @click="deleteUser(user.id)" 
                        class="text-red-600 hover:text-red-900" 
                        :title="$t('userManagement.deleteUser')"
                      >
                        <i class="fas fa-trash"></i>
                      </button>
                    </template>
                    
                    <button 
                      @click="viewUserDetails(user.id)" 
                      class="text-[#284b44] hover:text-[#1f3d38]" 
                      :title="$t('userManagement.viewDetails')"
                    >
                      <i class="fas fa-eye"></i>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- User Modal -->
    <div 
      v-if="showUserModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeUserModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center pb-3 border-b mb-4">
          <h3 class="text-xl font-bold text-gray-800 flex items-center gap-2">
            <i class="fas fa-user-edit text-gray-500"></i>
            <span>{{ editingUser ? $t('userManagement.editUser') : $t('homePortal.addUser') }}</span>
          </h3>
          <button @click="closeUserModal" class="text-gray-400 hover:text-gray-800 text-2xl">&times;</button>
        </div>

        <form @submit.prevent="saveUser" class="space-y-4">
          <input type="hidden" v-model="userForm.id">
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.fullName') }} *</label>
              <input 
                type="text" 
                v-model="userForm.name" 
                required 
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.emailAddress') }} *</label>
              <input 
                type="email" 
                v-model="userForm.email" 
                required 
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.password') }} *</label>
              <input 
                type="password" 
                v-model="userForm.password" 
                :required="!editingUser"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
              <p class="text-xs text-gray-500 mt-1">{{ $t('homePortal.passwordLeaveBlank') }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.phoneNumber') }}</label>
              <input 
                type="tel" 
                v-model="userForm.phone" 
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.userRole') }} *</label>
              <select 
                v-model="userForm.role" 
                required 
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
                <option value="admin">{{ $t('userManagement.roleAdmin') }}</option>
                <option value="manager">{{ $t('userManagement.roleManager') }}</option>
                <option value="supervisor">{{ $t('userManagement.roleSupervisor') }}</option>
                <option value="logistics_manager">{{ $t('userManagement.roleLogisticsManager') }}</option>
                <option value="warehouse_manager">{{ $t('userManagement.roleWarehouseManager') }}</option>
                <option value="branch_manager">{{ $t('userManagement.roleBranchManager') }}</option>
                <option value="driver">{{ $t('userManagement.roleDriver') }}</option>
                <option value="finance">{{ $t('userManagement.roleFinance') }}</option>
                <option value="auditor">{{ $t('userManagement.roleAuditor') }}</option>
                <option value="procurement">{{ $t('userManagement.roleProcurement') }}</option>
                <option value="inventory_manager">{{ $t('userManagement.roleInventoryManager') }}</option>
                <option value="user">{{ $t('userManagement.roleUser') }}</option>
                <option value="viewer">{{ $t('userManagement.roleViewer') }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.userStatus') }} *</label>
              <select 
                v-model="userForm.status" 
                required 
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
              >
                <option value="active">{{ $t('userManagement.statusActive') }}</option>
                <option value="inactive">{{ $t('userManagement.statusInactive') }}</option>
              </select>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.permissions') }}</label>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.accountsPayable" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permAccountsPayable') }}</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.forecasting" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permForecasting') }}</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.warehouse" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permWarehouse') }}</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.userManagement" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permUserManagement') }}</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.reports" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permReports') }}</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" v-model="userForm.permissions.settings" :class="isRTL ? 'ml-2' : 'mr-2'">
                <span class="text-sm">{{ $t('homePortal.permSettings') }}</span>
              </label>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">{{ $t('homePortal.notes') }}</label>
            <textarea 
              v-model="userForm.notes" 
              rows="3" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-400"
            ></textarea>
          </div>

          <div class="flex justify-end gap-3 pt-4 border-t">
            <button 
              type="button" 
              @click="closeUserModal" 
              class="px-6 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400 transition-all font-medium"
            >
              {{ $t('common.cancel') }}
            </button>
            <button 
              type="submit" 
              class="px-6 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-lg hover:from-green-700 hover:to-green-800 transition-all font-medium shadow-md flex items-center gap-2"
            >
              <i class="fas fa-save"></i>
              <span>{{ $t('homePortal.saveUser') }}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useI18n } from '@/composables/useI18n';
import api from '@/services/api';
import { getUsers, createUserInSupabase, updateUserInSupabase, deleteUserFromSupabase } from '@/services/supabase';
import { translatePage } from '@/utils/i18n';
import { formatDate as formatDateUtil } from '@/utils/dateFormat';

const authStore = useAuthStore();
const { t, locale, isRTL } = useI18n();

// State
const users = ref([]);
const loading = ref(false);
const showUserModal = ref(false);
const editingUser = ref(null);
const searchTerm = ref('');
const roleFilter = ref('');
const statusFilter = ref('');

const userForm = ref({
  id: '',
  name: '',
  email: '',
  password: '',
  phone: '',
  role: 'user',
  status: 'active',
  permissions: {
    accountsPayable: false,
    forecasting: false,
    warehouse: false,
    userManagement: false,
    reports: false,
    settings: false
  },
  notes: ''
});

const userStats = ref({
  total: 0,
  active: 0,
  admins: 0,
  pending: 0
});

// Computed
const canManageUsers = computed(() => {
  const currentUser = authStore.user;
  return currentUser && (
    currentUser.role?.toLowerCase() === 'admin' || 
    currentUser.permissions?.userManagement === true
  );
});

const filteredUsers = computed(() => {
  let filtered = users.value;
  
  // Search filter
  if (searchTerm.value) {
    const term = searchTerm.value.toLowerCase();
    filtered = filtered.filter(user => 
      user.name?.toLowerCase().includes(term) ||
      user.email?.toLowerCase().includes(term) ||
      user.role?.toLowerCase().includes(term)
    );
  }
  
  // Role filter
  if (roleFilter.value) {
    filtered = filtered.filter(user => 
      user.role?.toLowerCase() === roleFilter.value.toLowerCase()
    );
  }
  
  // Status filter
  if (statusFilter.value) {
    filtered = filtered.filter(user => 
      user.status?.toLowerCase() === statusFilter.value.toLowerCase()
    );
  }
  
  return filtered;
});

// Methods
const loadUsers = async () => {
  loading.value = true;
  try {
    // Try Supabase first
    try {
      const supabaseUsers = await getUsers();
      if (supabaseUsers && supabaseUsers.length > 0) {
        users.value = supabaseUsers;
        updateUserStatistics();
        loading.value = false;
        return;
      }
    } catch (error) {
      console.warn('Supabase load failed, trying API:', error);
    }
    
    // Fallback to API
    const response = await api.get('/api/users');
    users.value = response.data.data?.users || response.data.users || [];
    updateUserStatistics();
  } catch (error) {
    console.error('Error loading users:', error);
    showNotification(t('userManagement.errorLoadingUsers'), 'error');
  } finally {
    loading.value = false;
  }
};

const updateUserStatistics = () => {
  const allUsers = users.value;
  userStats.value = {
    total: allUsers.length,
    active: allUsers.filter(u => (u.status || '').toLowerCase() === 'active').length,
    admins: allUsers.filter(u => (u.role || '').toLowerCase() === 'admin').length,
    pending: allUsers.filter(u => (u.status || '').toLowerCase() === 'inactive').length
  };
};

const filterUsers = () => {
  // Filtering is handled by computed property
  updateUserStatistics();
};

const openAddUserModal = () => {
  editingUser.value = null;
  userForm.value = {
    id: '',
    name: '',
    email: '',
    password: '',
    phone: '',
    role: 'user',
    status: 'active',
    permissions: {
      accountsPayable: false,
      forecasting: false,
      warehouse: false,
      userManagement: false,
      reports: false,
      settings: false
    },
    notes: ''
  };
  showUserModal.value = true;
};

const closeUserModal = () => {
  showUserModal.value = false;
  editingUser.value = null;
  userForm.value = {
    id: '',
    name: '',
    email: '',
    password: '',
    phone: '',
    role: 'user',
    status: 'active',
    permissions: {
      accountsPayable: false,
      forecasting: false,
      warehouse: false,
      userManagement: false,
      reports: false,
      settings: false
    },
    notes: ''
  };
};

const editUser = async (userId) => {
  const user = users.value.find(u => u.id === userId);
  if (!user) return;
  
  editingUser.value = user;
  userForm.value = {
    id: user.id,
    name: user.name,
    email: user.email,
    password: '',
    phone: user.phone || '',
    role: user.role?.toLowerCase() || 'user',
    status: user.status?.toLowerCase() || 'active',
    permissions: user.permissions || {
      accountsPayable: false,
      forecasting: false,
      warehouse: false,
      userManagement: false,
      reports: false,
      settings: false
    },
    notes: user.notes || ''
  };
  showUserModal.value = true;
};

const saveUser = async () => {
  try {
    if (editingUser.value) {
      // Update existing user
      const updateData = {
        name: userForm.value.name.trim(),
        email: userForm.value.email.trim().toLowerCase(),
        phone: userForm.value.phone || '',
        role: userForm.value.role.toLowerCase(),
        status: userForm.value.status.toLowerCase(),
        permissions: userForm.value.permissions,
        notes: userForm.value.notes || ''
      };
      
      if (userForm.value.password) {
        updateData.password_hash = userForm.value.password.trim();
      }
      
      // Try Supabase first
      try {
        const result = await updateUserInSupabase(userForm.value.id, updateData);
        if (result.success) {
          showNotification(t('userManagement.userUpdatedSuccessfully'), 'success');
          closeUserModal();
          await loadUsers();
          return;
        }
      } catch (error) {
        console.warn('Supabase update failed, trying API:', error);
      }
      
      // Fallback to API
      await api.put(`/api/users/${userForm.value.id}`, updateData);
      showNotification(t('userManagement.userUpdatedSuccessfully'), 'success');
    } else {
      // Create new user
      if (!userForm.value.password) {
        showNotification(t('userManagement.passwordRequired'), 'error');
        return;
      }
      
      const newUser = {
        name: userForm.value.name.trim(),
        email: userForm.value.email.trim().toLowerCase(),
        password: userForm.value.password.trim(),
        phone: userForm.value.phone || '',
        role: userForm.value.role.toLowerCase(),
        status: userForm.value.status.toLowerCase(),
        permissions: userForm.value.permissions,
        notes: userForm.value.notes || ''
      };
      
      // Try Supabase first
      try {
        const result = await createUserInSupabase(newUser);
        if (result.success) {
          showNotification(t('userManagement.userAddedSuccessfully'), 'success');
          closeUserModal();
          await loadUsers();
          return;
        }
      } catch (error) {
        console.warn('Supabase create failed, trying API:', error);
      }
      
      // Fallback to API
      await api.post('/api/users', newUser);
      showNotification(t('userManagement.userAddedSuccessfully'), 'success');
    }
    
    closeUserModal();
    await loadUsers();
  } catch (error) {
    console.error('Error saving user:', error);
    showNotification(error.response?.data?.error || t('userManagement.errorSavingUser'), 'error');
  }
};

const approveUser = async (userId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: t('userManagement.approveUserTitle'),
    message: t('userManagement.approveUserMessage'),
    confirmText: t('userManagement.approveUser'),
    cancelText: t('common.cancel'),
    type: 'success',
    icon: 'fas fa-check-circle'
  });
  if (!confirmed) return;
  
  try {
    await api.put(`/api/users/${userId}/approve`);
    showNotification(t('userManagement.userApprovedSuccessfully'), 'success');
    await loadUsers();
  } catch (error) {
    console.error('Error approving user:', error);
    showNotification(error.response?.data?.error || t('userManagement.errorApprovingUser'), 'error');
  }
};

const rejectUser = async (userId) => {
  const user = users.value.find(u => u.id === userId);
  if (!user) return;
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: t('userManagement.rejectUserTitle'),
    message: t('userManagement.rejectUserMessage').replace('{name}', user.name).replace('{email}', user.email),
    confirmText: t('userManagement.rejectUser'),
    cancelText: t('common.cancel'),
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    await api.delete(`/api/users/${userId}`);
    showNotification(t('userManagement.userRejectedSuccessfully'), 'success');
    await loadUsers();
  } catch (error) {
    console.error('Error rejecting user:', error);
    showNotification(error.response?.data?.error || t('userManagement.errorRejectingUser'), 'error');
  }
};

const deleteUser = async (userId) => {
  const user = users.value.find(u => u.id === userId);
  if (!user) return;
  
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: t('userManagement.deleteUserTitle'),
    message: t('userManagement.deleteUserMessage').replace('{name}', user.name),
    confirmText: t('userManagement.deleteUser'),
    cancelText: t('common.cancel'),
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    // Try Supabase first
    try {
      const result = await deleteUserFromSupabase(userId);
      if (result.success) {
        showNotification(t('userManagement.userDeletedSuccessfully'), 'success');
        await loadUsers();
        return;
      }
    } catch (error) {
      console.warn('Supabase delete failed, trying API:', error);
    }
    
    // Fallback to API
    await api.delete(`/api/users/${userId}`);
    showNotification(t('userManagement.userDeletedSuccessfully'), 'success');
    await loadUsers();
  } catch (error) {
    console.error('Error deleting user:', error);
    showNotification(error.response?.data?.error || t('userManagement.errorDeletingUser'), 'error');
  }
};

const viewUserDetails = (userId) => {
  const user = users.value.find(u => u.id === userId);
  if (!user) return;
  
  const details = `
${t('homePortal.userName')}: ${user.name}
${t('homePortal.userEmail')}: ${user.email}
${t('homePortal.phoneNumber')}: ${user.phone || t('userManagement.notAvailable')}
${t('homePortal.userRole')}: ${getRoleLabel(user.role)}
${t('homePortal.userStatus')}: ${getStatusLabel(user.status)}
${t('userManagement.created')}: ${formatDate(user.createdAt || user.created_at)}
${t('homePortal.lastLogin')}: ${formatDate(user.lastLogin || user.last_login)}
${t('homePortal.lastActivity')}: ${formatDate(user.lastActivity || user.last_activity)}
${t('homePortal.notes')}: ${user.notes || t('userManagement.notAvailable')}
  `;
    showNotification(details, 'info', 5000);
};

const resendVerificationEmail = async (userId) => {
  try {
    await api.post(`/api/users/${userId}/resend-verification`);
    showNotification(t('userManagement.verificationEmailSent'), 'success');
  } catch (error) {
    console.error('Error resending verification email:', error);
    showNotification(error.response?.data?.error || t('userManagement.errorResendingVerification'), 'error');
  }
};

const getRoleBadgeClass = (role) => {
  const roleLower = (role || '').toLowerCase().replace(/-/g, '_');
  const classes = {
    'admin': 'bg-red-100 text-red-800',
    'manager': 'bg-purple-100 text-purple-800',
    'supervisor': 'bg-indigo-100 text-indigo-800',
    'logistics_manager': 'bg-blue-100 text-blue-800',
    'warehouse_manager': 'bg-amber-100 text-amber-800',
    'branch_manager': 'bg-teal-100 text-teal-800',
    'driver': 'bg-slate-100 text-slate-800',
    'finance': 'bg-emerald-100 text-emerald-800',
    'auditor': 'bg-orange-100 text-orange-800',
    'procurement': 'bg-cyan-100 text-cyan-800',
    'inventory_manager': 'bg-lime-100 text-lime-800',
    'user': 'bg-[#284b44] bg-opacity-10 text-[#284b44]',
    'viewer': 'bg-gray-100 text-gray-800'
  };
  return classes[roleLower] || classes['user'];
};

const getStatusBadgeClass = (status) => {
  const statusLower = (status || '').toLowerCase();
  const classes = {
    'active': 'bg-green-100 text-green-800',
    'inactive': 'bg-yellow-100 text-yellow-800',
    'suspended': 'bg-red-100 text-red-800'
  };
  return classes[statusLower] || 'bg-gray-100 text-gray-800';
};

const getRoleLabel = (role) => {
  const roleLower = (role || '').toLowerCase().replace(/-/g, '_');
  const labels = {
    'admin': t('userManagement.roleAdmin'),
    'manager': t('userManagement.roleManager'),
    'supervisor': t('userManagement.roleSupervisor'),
    'logistics_manager': t('userManagement.roleLogisticsManager'),
    'warehouse_manager': t('userManagement.roleWarehouseManager'),
    'branch_manager': t('userManagement.roleBranchManager'),
    'driver': t('userManagement.roleDriver'),
    'finance': t('userManagement.roleFinance'),
    'auditor': t('userManagement.roleAuditor'),
    'procurement': t('userManagement.roleProcurement'),
    'inventory_manager': t('userManagement.roleInventoryManager'),
    'user': t('userManagement.roleUser'),
    'viewer': t('userManagement.roleViewer')
  };
  return labels[roleLower] || role;
};

const getStatusLabel = (status) => {
  const statusLower = (status || '').toLowerCase();
  if (statusLower === 'inactive') {
    return t('userManagement.pendingApproval');
  }
  const labels = {
    'active': t('userManagement.statusActive'),
    'suspended': t('userManagement.statusSuspended')
  };
  return labels[statusLower] || status;
};

const isEmailVerified = (user) => {
  return user.email_verified === true || user.email_verified === 'true';
};

// Use global date formatter for correct locale-aware formatting with Arabic numerals
const formatDate = (dateString) => {
  if (!dateString) return t('userManagement.never');
  try {
    // Use formatDateUtil with options for the specific format needed
    return formatDateUtil(new Date(dateString), locale.value, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });
  } catch {
    return t('userManagement.invalidDate');
  }
};

const handleImageError = (event) => {
  event.target.style.display = 'none';
  if (event.target.nextElementSibling) {
    event.target.nextElementSibling.style.display = 'flex';
  }
};

const showNotification = (message, type = 'success') => {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = 'fixed top-4 right-4 z-50 px-6 py-3 rounded-lg shadow-lg flex items-center gap-2 animate-slide-in';
  
  // Set colors based on type
  const colors = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-yellow-500 text-white',
    info: 'bg-[#284b44] text-white'
  };
  
  notification.className += ' ' + (colors[type] || colors.success);
  
  const icons = {
    success: 'fa-check-circle',
    error: 'fa-exclamation-circle',
    warning: 'fa-exclamation-triangle',
    info: 'fa-info-circle'
  };
  
  notification.innerHTML = `
    <i class="fas ${icons[type] || icons.success}"></i>
    <span>${message}</span>
    <button onclick="this.parentElement.remove()" class="ml-2 text-white hover:text-gray-200">
      <i class="fas fa-times"></i>
    </button>
  `;
  
  document.body.appendChild(notification);
  
  // Auto remove after 4 seconds
  setTimeout(() => {
    notification.style.opacity = '0';
    notification.style.transition = 'opacity 0.3s';
    setTimeout(() => notification.remove(), 300);
  }, 4000);
};

// Lifecycle
onMounted(() => {
  loadUsers();
  
  // Initialize language
  const savedLang = localStorage.getItem('portalLang') || 'en';
  translatePage(savedLang);
  
  // Listen for language changes
  const handleLanguageChange = (event) => {
    if (event.data && event.data.type === 'LANGUAGE_CHANGE') {
      translatePage(event.data.language);
    }
  };
  
  window.addEventListener('message', handleLanguageChange);
  
  // Also listen for storage changes (when language is changed in another component)
  const handleStorageChange = (e) => {
    if (e.key === 'portalLang') {
      translatePage(e.newValue || 'en');
    }
  };
  
  window.addEventListener('storage', handleStorageChange);
  
  // Cleanup
  onUnmounted(() => {
    window.removeEventListener('message', handleLanguageChange);
    window.removeEventListener('storage', handleStorageChange);
  });
});
</script>

<style scoped>
@keyframes slide-in {
  from {
    transform: translateX(400px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

.animate-slide-in {
  animation: slide-in 0.3s ease-out;
}
.kpi-card {
  background: linear-gradient(135deg, #f0e1cd 0%, #e8d5c0 100%);
  border-radius: 0.75rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  padding: 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  border: 1px solid rgba(149, 108, 42, 0.2);
}

.kpi-card .icon {
  width: 3rem;
  height: 3rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 1.5rem;
}

.kpi-card .title {
  color: #284b44;
  font-weight: 600;
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
}

.kpi-card .value {
  font-size: 1.75rem;
  font-weight: 700;
  color: #284b44;
}

.loading-spinner {
  border: 4px solid #f3f3f3;
  border-top: 4px solid #284b44;
  border-radius: 50%;
  width: 48px;
  height: 48px;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>

