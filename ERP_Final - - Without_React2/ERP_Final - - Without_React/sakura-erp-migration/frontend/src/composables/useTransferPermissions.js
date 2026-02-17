/**
 * Transfer Order permissions: RBAC-based (TRANSFER_DISPATCH, TRANSFER_RECEIVE, TRANSFER_APPROVE).
 * No hardcoded roles. All DB-driven via fn_user_permissions.
 */
import { ref, onMounted } from 'vue';

export function useTransferPermissions() {
  const canDispatch = ref(false);
  const canReceive = ref(false);
  const canApprove = ref(false);

  async function resolve() {
    try {
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
    } catch (_) {
      canDispatch.value = false;
      canReceive.value = false;
      canApprove.value = false;
    }
  }

  onMounted(resolve);

  return { canDispatch, canReceive, canApprove, resolve };
}
