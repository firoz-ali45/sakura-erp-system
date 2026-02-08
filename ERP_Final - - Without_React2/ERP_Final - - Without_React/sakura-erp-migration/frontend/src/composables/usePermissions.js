/**
 * Enterprise RBAC: permission checks for UI (hide/disable) and workflow.
 * Server must enforce; this is for UX only.
 */
import { ref, computed } from 'vue';

let cachedPermissions = null;
let cachedUserId = null;

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
      const userId = user?.id ?? user?.email ?? user?.name ?? (typeof window !== 'undefined' && localStorage.getItem('sakura_current_user') ? (() => { try { const u = JSON.parse(localStorage.getItem('sakura_current_user') || '{}'); return u.id ?? u.email ?? u.name; } catch { return ''; } })() : '');
      cachedUserId = userId || cachedUserId;
      if (cachedPermissions && cachedUserId === userId) {
        permissions.value = cachedPermissions;
        return;
      }
      const { supabaseClient } = await import('@/services/supabase.js');
      try {
        const { data: rpcData } = await supabaseClient.rpc('fn_user_has_permission', { p_user_id: String(cachedUserId || userId), p_permission_code: 'ADMIN' });
        if (rpcData === true) {
          permissions.value = new Set(['*']);
          cachedPermissions = permissions.value;
          return;
        }
      } catch (_) {}
      const { data: ur } = await supabaseClient.from('user_roles').select('role_id').eq('user_id', String(cachedUserId || userId));
      const roleIds = (ur || []).map(r => r.role_id).filter(Boolean);
      if (roleIds.length === 0) {
        permissions.value = new Set();
        cachedPermissions = permissions.value;
        return;
      }
      const { data: rp } = await supabaseClient.from('role_permissions').select('permission_id').in('role_id', roleIds);
      const permIds = [...new Set((rp || []).map(r => r.permission_id).filter(Boolean))];
      if (permIds.length === 0) {
        permissions.value = new Set();
        cachedPermissions = permissions.value;
        return;
      }
      const { data: perms } = await supabaseClient.from('permissions').select('code').in('id', permIds);
      permissions.value = new Set((perms || []).map(p => p.code).filter(Boolean));
      cachedPermissions = permissions.value;
    } catch (e) {
      console.warn('Load permissions:', e);
      permissions.value = new Set();
    } finally {
      loading.value = false;
    }
  };

  return { permissions, loading, hasPermission, loadPermissions };
}
