/**
 * Transfer Order permissions: Warehouse=dispatch, Branch=receive, Manager=approval.
 * Reads from user role/permissions. Default true for testing when no role set.
 */
import { ref, onMounted } from 'vue';

export function useTransferPermissions() {
  const canDispatch = ref(true);
  const canReceive = ref(true);
  const canApprove = ref(true);

  function resolve() {
    try {
      const u = localStorage.getItem('sakura_current_user');
      if (!u) return;
      const user = JSON.parse(u);
      const role = (user.role || user.permissions?.role || '').toLowerCase();
      const perms = user.permissions || {};

      // Warehouse / warehouse_manager → dispatch only
      if (role === 'warehouse' || role === 'warehouse_manager' || perms.warehouse) {
        canDispatch.value = true;
        canReceive.value = false;
        canApprove.value = false;
        return;
      }
      // Branch / branch_manager → receive only
      if (role === 'branch' || role === 'branch_manager' || perms.branch) {
        canDispatch.value = false;
        canReceive.value = true;
        canApprove.value = false;
        return;
      }
      // Manager / admin → approval
      if (role === 'manager' || role === 'admin' || perms.userManagement || perms.admin) {
        canDispatch.value = false;
        canReceive.value = false;
        canApprove.value = true;
        return;
      }
      // Full access
      if (role === 'superadmin' || perms['*']) {
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
