/**
 * Enterprise RBAC: permission checks for UI (hide/disable) and workflow.
 * Uses fn_user_permissions RPC + permissionEngine. Server must enforce.
 */
import { ref } from 'vue';
import { getCachedUserPermissions, invalidatePermissionCache } from '@/services/permissionEngine.js';

export function usePermissions() {
  const permissions = ref(new Set());
  const loading = ref(false);

  const hasPermission = (code) => {
    if (!code) return false;
    return permissions.value.has(code) || permissions.value.has('*');
  };

  const loadPermissions = async () => {
    loading.value = true;
    try {
      const authStore = (await import('@/stores/auth')).useAuthStore();
      const user = authStore.user?.value ?? authStore.user;
      let userId = user?.id ?? (typeof window !== 'undefined' && localStorage.getItem('sakura_current_user') ? (() => { try { const u = JSON.parse(localStorage.getItem('sakura_current_user') || '{}'); return u.id; } catch { return null; } })() : null);
      if (!userId) {
        permissions.value = new Set();
        return;
      }
      const perms = await getCachedUserPermissions(userId);
      permissions.value = new Set(perms);
    } catch (e) {
      console.warn('Load permissions:', e);
      permissions.value = new Set();
    } finally {
      loading.value = false;
    }
  };

  const clearCache = () => {
    invalidatePermissionCache();
    permissions.value = new Set();
  };

  return { permissions, loading, hasPermission, loadPermissions, clearCache };
}
