<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <button @click="$router.push('/homeportal')" class="text-[#284b44] hover:underline mb-4 flex items-center gap-2">
        <i class="fas fa-arrow-left"></i> Back
      </button>
      <h2 class="text-2xl font-bold text-gray-800">ERP Health Monitor</h2>
      <p class="text-sm text-gray-600 mt-1">Database integrity, relations, orphan records. SAP-style internal health check.</p>
    </div>

    <div v-if="!canAccess" class="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
      <p class="text-red-700 font-medium">Admin access required</p>
      <p class="text-sm text-red-600 mt-1">This page is hidden and requires administrator permissions.</p>
    </div>

    <template v-else>
      <div class="flex gap-4 mb-6">
        <button @click="runHealthCheck" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3a36]" :disabled="loading">
          {{ loading ? 'Checking...' : 'Run Health Check' }}
        </button>
        <span v-if="health?.checked_at" class="text-sm text-gray-500 self-center">
          Last checked: {{ formatDate(health.checked_at) }}
        </span>
      </div>

      <div v-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700 mb-6">
        {{ error }}
      </div>

      <div v-if="health" class="space-y-6">
        <!-- Summary -->
        <div class="bg-white rounded-lg shadow p-6" :class="health.healthy ? 'border-l-4 border-green-500' : 'border-l-4 border-amber-500'">
          <h3 class="font-bold text-lg flex items-center gap-2">
            <i :class="['fas', health.healthy ? 'fa-check-circle text-green-600' : 'fa-exclamation-triangle text-amber-600']"></i>
            {{ health.healthy ? 'System Healthy' : 'Issues Detected' }}
          </h3>
          <p class="text-sm text-gray-600 mt-1">
            {{ health.healthy ? 'No orphan records or broken relations found.' : 'Review the sections below and fix any orphan records or broken references.' }}
          </p>
        </div>

        <!-- Orphan user_roles -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-bold text-lg mb-2">Orphan User Roles</h3>
          <p class="text-sm text-gray-600 mb-3">user_roles where user_id does not exist in users</p>
          <div v-if="(health.orphan_user_roles || []).length" class="space-y-2">
            <div v-for="(o, i) in health.orphan_user_roles" :key="i" class="flex gap-2 text-sm py-2 border-b">
              <span class="font-mono text-red-600">{{ o.user_id }}</span>
              <span>→</span>
              <span class="font-mono">{{ o.role_id }}</span>
            </div>
          </div>
          <p v-else class="text-green-600 text-sm">None</p>
        </div>

        <!-- Orphan role refs -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-bold text-lg mb-2">Orphan Role References</h3>
          <p class="text-sm text-gray-600 mb-3">user_roles where role_id is deleted or missing</p>
          <div v-if="(health.orphan_role_refs || []).length" class="space-y-2">
            <div v-for="(o, i) in health.orphan_role_refs" :key="i" class="flex gap-2 text-sm py-2 border-b">
              <span class="font-mono">{{ o.user_id }}</span>
              <span>→</span>
              <span class="font-mono text-red-600">{{ o.role_id }}</span>
            </div>
          </div>
          <p v-else class="text-green-600 text-sm">None</p>
        </div>

        <!-- Orphan role_permissions -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="font-bold text-lg mb-2">Orphan Role Permissions</h3>
          <p class="text-sm text-gray-600 mb-3">role_permissions where role_id does not exist</p>
          <div v-if="(health.orphan_role_permissions || []).length" class="space-y-2">
            <div v-for="(o, i) in health.orphan_role_permissions" :key="i" class="flex gap-2 text-sm py-2 border-b">
              <span class="font-mono text-red-600">{{ o.role_id }}</span>
              <span>→</span>
              <span class="font-mono">{{ o.permission_id }}</span>
            </div>
          </div>
          <p v-else class="text-green-600 text-sm">None</p>
        </div>

        <!-- Counts -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="bg-white rounded-lg shadow p-4">
            <h4 class="font-semibold text-gray-700">Users without roles</h4>
            <p class="text-2xl font-bold mt-1" :class="health.users_without_roles_count ? 'text-amber-600' : 'text-gray-800'">
              {{ health.users_without_roles_count ?? 0 }}
            </p>
          </div>
          <div class="bg-white rounded-lg shadow p-4">
            <h4 class="font-semibold text-gray-700">Roles without permissions</h4>
            <p class="text-2xl font-bold mt-1" :class="health.roles_without_permissions_count ? 'text-amber-600' : 'text-gray-800'">
              {{ health.roles_without_permissions_count ?? 0 }}
            </p>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { supabaseClient, ensureSupabaseReady } from '@/services/supabase.js';
import { getUserPermissions } from '@/services/permissionEngine';

const health = ref(null);
const loading = ref(false);
const error = ref('');
const canAccess = ref(false);

function formatDate(d) {
  if (!d) return '-';
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? '-' : dt.toLocaleString();
  } catch { return '-'; }
}

async function runHealthCheck() {
  loading.value = true;
  error.value = '';
  try {
    await ensureSupabaseReady();
    const { data, err } = await supabaseClient.rpc('fn_erp_health_check');
    if (err) throw err;
    health.value = data;
  } catch (e) {
    error.value = e.message || 'Health check failed';
    health.value = null;
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  try {
    const u = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
    const perms = await getUserPermissions(u?.id);
    canAccess.value = perms?.includes('*') || perms?.includes('user_management_security') || perms?.includes('user_management_users');
    if (canAccess.value) await runHealthCheck();
  } catch {
    canAccess.value = false;
  }
});
</script>
