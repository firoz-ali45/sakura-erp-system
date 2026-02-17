<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <button @click="$router.push('/homeportal/user-management/roles')" class="text-[#284b44] hover:underline mb-4 flex items-center gap-2">
      <i class="fas fa-arrow-left"></i> {{ $t('userManagement.roles') }}
    </button>

    <div v-if="loading" class="text-center py-12">Loading...</div>
    <template v-else-if="role">
      <h2 class="text-2xl font-bold text-gray-800">{{ role.role_name }}</h2>
      <p class="text-gray-600 mt-1">{{ role.description || '-' }}</p>
      <p class="text-sm text-gray-500">{{ role.role_code }}</p>

      <!-- Users assigned -->
      <div class="mt-6 bg-white rounded-lg shadow p-4">
        <h3 class="font-semibold text-gray-800 mb-2">Users assigned</h3>
        <ul v-if="usersAssigned.length" class="space-y-1">
          <li v-for="u in usersAssigned" :key="u.id" class="flex items-center gap-2">
            <span>{{ u.name }}</span>
            <span class="text-gray-500 text-sm">({{ u.email }})</span>
          </li>
        </ul>
        <p v-else class="text-gray-500 text-sm">No users assigned</p>
      </div>

      <!-- Permission matrix -->
      <div class="mt-6 bg-white rounded-lg shadow p-4">
        <h3 class="font-semibold text-gray-800 mb-3">Permission matrix</h3>
        <div class="space-y-2">
          <div v-for="(perms, module) in permissionsByModule" :key="module" class="border rounded-lg overflow-hidden">
            <button
              type="button"
              @click="toggleModule(module)"
              class="w-full flex items-center justify-between p-3 bg-gray-50 hover:bg-gray-100 text-left"
            >
              <span class="font-medium">{{ module }}</span>
              <i :class="['fas', expandedModules.has(module) ? 'fa-chevron-down' : 'fa-chevron-right']"></i>
            </button>
            <div v-show="expandedModules.has(module)" class="p-3 border-t space-y-2">
              <label
                v-for="p in perms"
                :key="p.permission_code"
                class="flex items-center gap-2 cursor-pointer"
              >
                <input
                  type="checkbox"
                  :checked="selectedPermissions.has(p.permission_code)"
                  @change="togglePermission(p.permission_code)"
                >
                <span class="text-sm">{{ p.description || p.permission_code }}</span>
              </label>
            </div>
          </div>
        </div>
        <button @click="savePermissions" class="mt-4 px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="saving">
          {{ saving ? 'Saving...' : 'Save permissions' }}
        </button>
        <span v-if="permSaved" class="ml-2 text-green-600 text-sm">Saved</span>
      </div>

      <!-- Location access -->
      <div class="mt-6 bg-white rounded-lg shadow p-4">
        <h3 class="font-semibold text-gray-800 mb-3">Location access</h3>
        <div class="space-y-3">
          <label class="flex items-center gap-2">
            <input type="radio" :value="true" v-model="accessAllLocations">
            <span>All locations</span>
          </label>
          <label class="flex items-center gap-2">
            <input type="radio" :value="false" v-model="accessAllLocations">
            <span>Selected warehouses / branches</span>
          </label>
          <div v-if="!accessAllLocations" class="pl-6 mt-2">
            <div class="flex flex-wrap gap-2">
              <label
                v-for="loc in allLocations"
                :key="loc.id"
                class="flex items-center gap-2 px-3 py-2 bg-gray-50 rounded cursor-pointer"
              >
                <input type="checkbox" :value="loc.id" v-model="selectedLocationIds">
                <span class="text-sm">{{ loc.location_name }} ({{ loc.location_code }})</span>
              </label>
            </div>
          </div>
        </div>
        <button @click="saveLocationAccess" class="mt-4 px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="savingLoc">
          {{ savingLoc ? 'Saving...' : 'Save location access' }}
        </button>
        <span v-if="locSaved" class="ml-2 text-green-600 text-sm">Saved</span>
      </div>
    </template>
    <p v-else class="text-red-600">Role not found</p>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import {
  getRoleById,
  getUsersByRoleId,
  getPermissionsMaster,
  getRolePermissions,
  setRolePermissions,
  getRoleLocationAccess,
  setRoleLocationAccess,
  getInventoryLocations
} from '@/services/userManagementService';

const route = useRoute();
const role = ref(null);
const loading = ref(true);
const usersAssigned = ref([]);
const allPermissions = ref([]);
const rolePermissions = ref([]);
const selectedPermissions = ref(new Set());
const expandedModules = ref(new Set());
const accessAllLocations = ref(true);
const allLocations = ref([]);
const selectedLocationIds = ref([]);
const saving = ref(false);
const savingLoc = ref(false);
const permSaved = ref(false);
const locSaved = ref(false);

const permissionsByModule = computed(() => {
  const byModule = {};
  for (const p of allPermissions.value) {
    if (!byModule[p.module]) byModule[p.module] = [];
    byModule[p.module].push(p);
  }
  return byModule;
});

function toggleModule(module) {
  const s = new Set(expandedModules.value);
  if (s.has(module)) s.delete(module);
  else s.add(module);
  expandedModules.value = s;
}

function togglePermission(code) {
  const s = new Set(selectedPermissions.value);
  if (s.has(code)) s.delete(code);
  else s.add(code);
  selectedPermissions.value = s;
}

async function savePermissions() {
  if (!role.value) return;
  saving.value = true;
  permSaved.value = false;
  try {
    await setRolePermissions(role.value.id, [...selectedPermissions.value]);
    permSaved.value = true;
    setTimeout(() => { permSaved.value = false; }, 2000);
  } catch (e) {
    console.error(e);
  } finally {
    saving.value = false;
  }
}

async function saveLocationAccess() {
  if (!role.value) return;
  savingLoc.value = true;
  locSaved.value = false;
  try {
    await setRoleLocationAccess(role.value.id, selectedLocationIds.value, accessAllLocations.value);
    locSaved.value = true;
    setTimeout(() => { locSaved.value = false; }, 2000);
  } catch (e) {
    console.error(e);
  } finally {
    savingLoc.value = false;
  }
}

onMounted(async () => {
  const id = route.params.id;
  if (!id || id === 'new') {
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    role.value = await getRoleById(id);
    if (role.value) {
      usersAssigned.value = await getUsersByRoleId(id);
      allPermissions.value = await getPermissionsMaster();
      rolePermissions.value = await getRolePermissions(id);
      selectedPermissions.value = new Set(rolePermissions.value.map(p => p.permission_code));
      expandedModules.value = new Set([...new Set(allPermissions.value.map(p => p.module))]);
      accessAllLocations.value = role.value.access_all_locations !== false;
      allLocations.value = await getInventoryLocations();
      const locs = await getRoleLocationAccess(id);
      selectedLocationIds.value = locs.map(l => l.id).filter(Boolean);
    }
  } finally {
    loading.value = false;
  }
});
</script>
