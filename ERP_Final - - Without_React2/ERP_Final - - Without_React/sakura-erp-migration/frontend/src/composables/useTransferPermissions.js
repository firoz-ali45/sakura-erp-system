/**
 * Transfer Order permissions: RBAC-based (TRANSFER_DISPATCH, TRANSFER_RECEIVE, TO_APPROVE).
 * Falls back to legacy role checks when RBAC not configured. Default true for testing when no role set.
 */
import { ref, onMounted } from 'vue';

export function useTransferPermissions() {
  const canDispatch = ref(true);
  const canReceive = ref(true);
  const canApprove = ref(true);

  async function resolve() {
    try {
      // Prefer RBAC (usePermissions)
      const { usePermissions } = await import('@/composables/usePermissions.js');
      const { hasPermission, loadPermissions } = usePermissions();
      await loadPermissions();

      if (hasPermission('*')) {
        canDispatch.value = true;
        canReceive.value = true;
        canApprove.value = true;
        return;
      }
      canDispatch.value = hasPermission('transfer_dispatch') || hasPermission('transfer_approve');
      canReceive.value = hasPermission('transfer_receive') || hasPermission('transfer_approve');
      canApprove.value = hasPermission('transfer_approve');
      if (canDispatch.value || canReceive.value || canApprove.value) return;

      // Fallback: legacy role from localStorage
      const u = localStorage.getItem('sakura_current_user');
      if (!u) return;
      const user = JSON.parse(u);
      const role = (user.role || user.permissions?.role || '').toLowerCase();
      const perms = user.permissions || {};

      if (role === 'warehouse_manager' || role === 'warehouse' || perms.warehouse) {
        canDispatch.value = true;
        canReceive.value = false;
        canApprove.value = false;
        return;
      }
      if (role === 'branch_manager' || role === 'branch' || perms.branch) {
        canDispatch.value = false;
        canReceive.value = true;
        canApprove.value = false;
        return;
      }
      if (role === 'driver') {
        canDispatch.value = false;
        canReceive.value = false;
        canApprove.value = false;
        return;
      }
      if (role === 'manager' || role === 'admin' || role === 'supervisor' || perms.userManagement || perms.admin) {
        canDispatch.value = false;
        canReceive.value = false;
        canApprove.value = true;
        return;
      }
      if (role === 'superadmin' || role === 'logistics_manager' || perms['*']) {
        canDispatch.value = true;
        canReceive.value = true;
        canApprove.value = true;
      }
    } catch (_) {
      // Default: allow all for testing
    }
  }

  onMounted(resolve);

  return { canDispatch, canReceive, canApprove, resolve };
}
