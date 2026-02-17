<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <button @click="$router.push('/homeportal/user-management/users')" class="text-[#284b44] hover:underline mb-4 flex items-center gap-2">
        <i class="fas fa-arrow-left"></i> {{ $t('common.back') }}
      </button>
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.users') }} → {{ isNew ? $t('userManagement.createUser') : (user?.name || '...') }}</h2>
    </div>

    <!-- Create User Form -->
    <div v-if="isNew" class="bg-white rounded-lg shadow p-6 max-w-2xl">
      <form @submit.prevent="submitCreate" class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name *</label>
            <input v-model="createForm.name" type="text" required class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
            <input v-model="createForm.email" type="email" required class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Password *</label>
            <input v-model="createForm.password" type="password" required class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Phone</label>
            <input v-model="createForm.phone" type="text" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Employee ID</label>
            <input v-model="createForm.employee_id" type="text" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Department</label>
            <input v-model="createForm.department" type="text" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Role</label>
            <select v-model="createForm.roleId" class="w-full px-3 py-2 border rounded-lg">
              <option value="">Select role</option>
              <option v-for="r in roles" :key="r.id" :value="r.id">{{ r.role_name }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select v-model="createForm.status" class="w-full px-3 py-2 border rounded-lg">
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>
        </div>
        <p v-if="createError" class="text-red-600 text-sm">{{ createError }}</p>
        <div class="flex gap-2 pt-2">
          <button type="submit" class="px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="saving">{{ saving ? 'Creating...' : 'Create User' }}</button>
          <button type="button" @click="$router.push('/homeportal/user-management/users')" class="px-4 py-2 bg-gray-200 rounded-lg">Cancel</button>
        </div>
      </form>
    </div>

    <!-- Full User Profile -->
    <template v-else-if="user">
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left column: Basic Info, Roles, Locations -->
        <div class="lg:col-span-1 space-y-6">
          <!-- Basic Info (editable) -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="font-bold text-lg">Basic Info</h3>
              <button v-if="!editingBasic" @click="editingBasic = true" class="text-sm text-[#284b44] hover:underline">
                <i class="fas fa-edit mr-1"></i> Edit
              </button>
              <div v-else class="flex gap-2">
                <button @click="saveBasicInfo" class="text-sm px-3 py-1 bg-[#284b44] text-white rounded" :disabled="savingBasic">Save</button>
                <button @click="cancelEditBasic" class="text-sm px-3 py-1 bg-gray-200 rounded">Cancel</button>
              </div>
            </div>
            <div v-if="!editingBasic" class="space-y-2">
              <p><strong>Name:</strong> {{ user.name }}</p>
              <p><strong>Email:</strong> {{ user.email }}</p>
              <p><strong>Phone:</strong> {{ user.phone || '-' }}</p>
              <p><strong>Employee ID:</strong> {{ user.employee_id || '-' }}</p>
              <p><strong>Department:</strong> {{ user.department || '-' }}</p>
              <p><strong>Status:</strong> <span :class="statusClass">{{ user.status }}</span></p>
              <p class="text-xs text-gray-500 mt-2">Created: {{ formatDate(user.created_at) }}</p>
            </div>
            <form v-else @submit.prevent="saveBasicInfo" class="space-y-3">
              <div>
                <label class="block text-sm text-gray-600 mb-1">Name</label>
                <input v-model="editForm.name" class="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Phone</label>
                <input v-model="editForm.phone" class="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Employee ID</label>
                <input v-model="editForm.employee_id" class="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Department</label>
                <input v-model="editForm.department" class="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">Status</label>
                <select v-model="editForm.status" class="w-full px-3 py-2 border rounded-lg">
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="suspended">Suspended</option>
                </select>
              </div>
            </form>
          </div>

          <!-- Roles (Assign/Edit - DB persistent) -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-4">
              <h3 class="font-bold text-lg">Roles</h3>
              <button v-if="!editingRoles" @click="editingRoles = true" class="text-sm text-[#284b44] hover:underline">
                <i class="fas fa-edit mr-1"></i> Assign Role
              </button>
              <div v-else class="flex gap-2">
                <button @click="saveUserRoles" class="text-sm px-3 py-1 bg-[#284b44] text-white rounded" :disabled="savingRoles">Save</button>
                <button @click="cancelEditRoles" class="text-sm px-3 py-1 bg-gray-200 rounded">Cancel</button>
              </div>
            </div>
            <div v-if="!editingRoles" class="space-y-2">
              <div v-if="userRoles.length" class="space-y-2">
                <div v-for="r in userRoles" :key="r.role_id" class="flex items-center gap-2">
                  <span class="px-2 py-1 text-xs font-semibold rounded-full bg-[#284b44]/10 text-[#284b44]">
                    {{ r.role_name || r.role_code }}
                    <span v-if="r.is_primary" class="ml-1 text-[10px]">(Primary)</span>
                  </span>
                </div>
              </div>
              <p v-else class="text-gray-500 text-sm">No roles assigned</p>
            </div>
            <div v-else class="space-y-3">
              <label class="block text-sm font-medium text-gray-700">Select role(s)</label>
              <div class="space-y-2 max-h-40 overflow-y-auto">
                <label v-for="r in roles" :key="r.id" class="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" :value="r.id" v-model="selectedRoleIds" class="rounded" />
                  <span class="text-sm">{{ r.role_name }} ({{ r.role_code }})</span>
                </label>
              </div>
              <div v-if="selectedRoleIds.length">
                <label class="block text-sm text-gray-600 mb-1">Primary role</label>
                <select v-model="primaryRoleId" class="w-full px-3 py-2 border rounded-lg text-sm">
                  <option v-for="rid in selectedRoleIds" :key="rid" :value="rid">
                    {{ roles.find(r => r.id === rid)?.role_name || rid }}
                  </option>
                </select>
              </div>
            </div>
          </div>

          <!-- Locations -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="font-bold text-lg mb-4">Assigned Locations</h3>
            <div v-if="userLocations.length">
              <p class="text-sm text-gray-600 mb-2">User override:</p>
              <div class="flex flex-wrap gap-2">
                <span v-for="loc in userLocations" :key="loc.id" class="px-2 py-1 bg-gray-100 rounded text-sm">{{ loc.location_name || loc.location_code }}</span>
              </div>
            </div>
            <div v-else-if="primaryRole">
              <p class="text-sm text-gray-600 mb-2">From role {{ primaryRole.role_name }}:</p>
              <p v-if="primaryRole.access_all_locations !== false" class="text-sm font-medium">All locations</p>
              <div v-else class="flex flex-wrap gap-2">
                <span v-for="loc in roleLocations" :key="loc.id" class="px-2 py-1 bg-gray-100 rounded text-sm">{{ loc.location_name || loc.location_code }}</span>
              </div>
            </div>
            <p v-else class="text-gray-500 text-sm">No location access</p>
          </div>
        </div>

        <!-- Right column: Modules, Activity, Security, Audit -->
        <div class="lg:col-span-2 space-y-6">
          <!-- Modules (Permissions) -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="font-bold text-lg mb-4">Modules & Permissions</h3>
            <div v-if="permissionsByModule && Object.keys(permissionsByModule).length" class="space-y-2">
              <div v-for="(perms, module) in permissionsByModule" :key="module" class="border rounded-lg overflow-hidden">
                <button type="button" @click="toggleModule(module)" class="w-full flex items-center justify-between p-3 bg-gray-50 hover:bg-gray-100 text-left">
                  <span class="font-medium">{{ module }}</span>
                  <i :class="['fas', expandedModules.has(module) ? 'fa-chevron-down' : 'fa-chevron-right']"></i>
                </button>
                <div v-show="expandedModules.has(module)" class="p-3 border-t space-y-1">
                  <div v-for="p in perms" :key="p.permission_code" class="flex items-center gap-2 text-sm">
                    <i class="fas fa-check text-green-600 w-4"></i>
                    <span>{{ p.description || p.permission_code }}</span>
                  </div>
                </div>
              </div>
            </div>
            <p v-else class="text-gray-500 text-sm">No permissions assigned</p>
          </div>

          <!-- Security -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="font-bold text-lg mb-4">Security</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p class="text-sm text-gray-600">Last login</p>
                <p class="font-medium">{{ formatDate(user.last_login) || $t('userManagement.never') }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-600">Last activity</p>
                <p class="font-medium">{{ formatDate(user.last_activity) || $t('userManagement.never') }}</p>
              </div>
            </div>
            <div v-if="sessions.length" class="mt-4">
              <h4 class="font-semibold text-sm mb-2">Active sessions</h4>
              <div class="space-y-2 max-h-32 overflow-y-auto">
                <div v-for="s in sessions" :key="s.id" class="flex items-center justify-between text-sm py-2 border-b">
                  <span>{{ s.device || 'Unknown' }} · {{ formatDate(s.login_time) }}</span>
                  <button @click="forceLogout(s.id)" class="text-red-600 hover:underline text-xs">Force logout</button>
                </div>
              </div>
            </div>
          </div>

          <!-- Activity & Audit -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="font-bold text-lg mb-4">Activity & Audit</h3>
            <div v-if="activityLogs.length" class="space-y-2 max-h-64 overflow-y-auto">
              <div v-for="log in activityLogs" :key="log.id" class="text-sm py-2 border-b border-gray-100">
                <span class="font-medium">{{ log.action }}</span>
                <span v-if="log.entity_type"> · {{ log.entity_type }}</span>
                <span class="text-gray-500 block text-xs mt-0.5">{{ formatDate(log.created_at) }}</span>
              </div>
            </div>
            <p v-else class="text-gray-500 text-sm">No activity recorded</p>
          </div>
        </div>
      </div>
    </template>

    <div v-else-if="loading" class="text-center py-12">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
      <p class="text-gray-600 mt-2">Loading...</p>
    </div>
    <p v-else class="text-red-600">User not found</p>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  getUsersEnriched,
  getRoles,
  createUserWithRole,
  getUserById,
  getUserRoles,
  getUserLocationAccess,
  getRoleLocationAccess,
  getActivityLogs,
  getLoginSessionsByUser,
  forceLogoutSession,
  getPermissionsMaster,
  setUserRoles
} from '@/services/userManagementService';
import { getUserPermissions } from '@/services/permissionEngine';
import { updateUserInSupabase } from '@/services/supabase';

const route = useRoute();
const router = useRouter();
const user = ref(null);
const loading = ref(true);
const roles = ref([]);
const userRoles = ref([]);
const userLocations = ref([]);
const roleLocations = ref([]);
const activityLogs = ref([]);
const sessions = ref([]);
const userPermissionCodes = ref([]);
const allPermissions = ref([]);
const expandedModules = ref(new Set());
const createForm = ref({ name: '', email: '', password: '', phone: '', employee_id: '', department: '', roleId: '', status: 'active' });
const createError = ref('');
const saving = ref(false);
const editingBasic = ref(false);
const editForm = ref({});
const savingBasic = ref(false);
const editingRoles = ref(false);
const selectedRoleIds = ref([]);
const primaryRoleId = ref(null);
const savingRoles = ref(false);

const isNew = computed(() => route.params.id === 'new');

const primaryRole = computed(() => userRoles.value.find(r => r.is_primary) || userRoles.value[0]);

const permissionsByModule = computed(() => {
  const codes = new Set(userPermissionCodes.value);
  if (codes.has('*')) return { 'Full Access': [{ permission_code: '*', description: 'All permissions' }] };
  const byModule = {};
  for (const p of allPermissions.value) {
    if (codes.has(p.permission_code)) {
      if (!byModule[p.module]) byModule[p.module] = [];
      byModule[p.module].push(p);
    }
  }
  return byModule;
});

const statusClass = computed(() => {
  const s = user.value?.status || '';
  if (s === 'active') return 'text-green-600';
  if (s === 'suspended') return 'text-red-600';
  return 'text-gray-600';
});

function formatDate(d) {
  if (!d) return '-';
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? '-' : dt.toLocaleString();
  } catch { return '-'; }
}

function toggleModule(module) {
  const s = new Set(expandedModules.value);
  if (s.has(module)) s.delete(module);
  else s.add(module);
  expandedModules.value = s;
}

async function saveBasicInfo() {
  if (!user.value) return;
  savingBasic.value = true;
  try {
    const res = await updateUserInSupabase(user.value.id, {
      name: editForm.value.name,
      phone: editForm.value.phone || null,
      employee_id: editForm.value.employee_id || null,
      department: editForm.value.department || null,
      status: editForm.value.status
    });
    if (res.success) {
      // Enterprise: reload from DB - never trust frontend state
      user.value = await getUserById(user.value.id);
      editingBasic.value = false;
    } else {
      console.error(res.error);
    }
  } catch (e) {
    console.error(e);
  } finally {
    savingBasic.value = false;
  }
}

function cancelEditBasic() {
  editingBasic.value = false;
  editForm.value = { ...getEditFormFromUser(user.value) };
}

async function saveUserRoles() {
  if (!user.value) return;
  savingRoles.value = true;
  try {
    await setUserRoles(user.value.id, selectedRoleIds.value, primaryRoleId.value || selectedRoleIds.value[0]);
    editingRoles.value = false;
    // Enterprise: reload from DB - never trust frontend state
    userRoles.value = await getUserRoles(user.value.id);
    const primary = userRoles.value.find(r => r.is_primary) || userRoles.value[0];
    if (primary) {
      roleLocations.value = await getRoleLocationAccess(primary.role_id);
    } else {
      roleLocations.value = [];
    }
    // Reload permissions (from primary role)
    userPermissionCodes.value = await getUserPermissions(user.value.id);
    if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('erp:refresh-drivers'));
  } catch (e) {
    console.error(e);
    alert('Failed to save roles: ' + (e.message || 'Unknown error'));
  } finally {
    savingRoles.value = false;
  }
}

function cancelEditRoles() {
  editingRoles.value = false;
  selectedRoleIds.value = userRoles.value.map(r => r.role_id).filter(Boolean);
  primaryRoleId.value = (userRoles.value.find(r => r.is_primary) || userRoles.value[0])?.role_id || null;
}

function getEditFormFromUser(u) {
  if (!u) return {};
  return {
    name: u.name || '',
    phone: u.phone || '',
    employee_id: u.employee_id || '',
    department: u.department || '',
    status: u.status || 'active'
  };
}

async function forceLogout(sessionId) {
  try {
    await forceLogoutSession(sessionId);
    sessions.value = sessions.value.filter(s => s.id !== sessionId);
  } catch (e) {
    console.error(e);
  }
}

async function submitCreate() {
  createError.value = '';
  saving.value = true;
  try {
    const u = await createUserWithRole({
      name: createForm.value.name,
      email: createForm.value.email,
      password: createForm.value.password,
      phone: createForm.value.phone || null,
      status: createForm.value.status,
      role: roles.value.find(r => r.id === createForm.value.roleId)?.role_code || 'user',
      department: createForm.value.department || null,
      employee_id: createForm.value.employee_id || null
    }, createForm.value.roleId || null);
    router.push(`/homeportal/user-management/user/${u.id}`);
  } catch (e) {
    createError.value = e.message || 'Failed to create user';
  } finally {
    saving.value = false;
  }
}

async function loadProfile(userId) {
  loading.value = true;
  try {
    const [u, rolesData, locs, logs, sess, perms, permsMaster] = await Promise.all([
      getUserById(userId),
      getUserRoles(userId),
      getUserLocationAccess(userId),
      getActivityLogs({ user_id: userId }),
      getLoginSessionsByUser(userId, false),
      getUserPermissions(userId),
      getPermissionsMaster()
    ]);
    user.value = u;
    userRoles.value = rolesData;
    selectedRoleIds.value = rolesData.map(r => r.role_id).filter(Boolean);
    primaryRoleId.value = (rolesData.find(r => r.is_primary) || rolesData[0])?.role_id || null;
    userLocations.value = locs;
    activityLogs.value = logs;
    sessions.value = sess.filter(s => s.is_active);
    userPermissionCodes.value = perms;
    allPermissions.value = permsMaster;
    editForm.value = getEditFormFromUser(u);
    const primary = rolesData.find(r => r.is_primary) || rolesData[0];
    if (primary) {
      roleLocations.value = await getRoleLocationAccess(primary.role_id);
    }
    const byMod = perms.includes('*')
      ? { 'Full Access': [] }
      : perms.reduce((acc, code) => {
          const p = permsMaster.find(m => m.permission_code === code);
          if (p) { if (!acc[p.module]) acc[p.module] = []; acc[p.module].push(p); }
          return acc;
        }, {});
    if (Object.keys(byMod).length) expandedModules.value = new Set(Object.keys(byMod));
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  roles.value = (await getRoles({ is_active: true })) || [];
  if (route.params.id === 'new') {
    loading.value = false;
    return;
  }
  if (route.params.id) {
    await loadProfile(route.params.id);
  } else {
    loading.value = false;
  }
});

watch(() => route.params.id, async (id) => {
  if (id && id !== 'new') await loadProfile(id);
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
