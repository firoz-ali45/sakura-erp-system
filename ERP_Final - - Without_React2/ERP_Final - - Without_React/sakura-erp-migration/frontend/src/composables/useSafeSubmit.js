/**
 * Enterprise safe submit: double-submit prevention + audit trail.
 * Use for critical mutations (PR submit, GRN post, payment, transfer dispatch).
 *
 * @example
 * const { safeSubmit, submitting } = useSafeSubmit();
 * await safeSubmit(async () => {
 *   const r = await submitPR(id);
 *   return r;
 * }, { entityType: 'purchase_requests', entityId: id, action: 'SUBMIT' });
 */
import { useSubmitGuard } from './useSubmitGuard.js';
import { useAuditLog } from './useAuditLog.js';

export function useSafeSubmit() {
  const { submitting, guard } = useSubmitGuard();
  const { logAction } = useAuditLog();

  /**
   * Execute handler with submit guard and optional audit.
   * @param {() => Promise<any>} handler - Async mutation
   * @param {Object} opts - { entityType, entityId, action, idempotencyKey, auditOldValues, auditNewValues }
   * @returns {Promise<any>} Handler result
   */
  const safeSubmit = async (handler, opts = {}) => {
    const {
      entityType,
      entityId,
      action = 'UPDATE',
      idempotencyKey,
      auditOldValues,
      auditNewValues,
      skipAudit = false
    } = opts;

    return guard(async () => {
      const result = await handler();

      if (!skipAudit && entityType && (auditOldValues != null || auditNewValues != null || result)) {
        try {
          await logAction(
            action,
            entityType,
            entityId ?? result?.id ?? result?.data?.id ?? null,
            auditOldValues ?? null,
            auditNewValues ?? (result ? { result } : null)
          );
        } catch (e) {
          console.warn('Audit log failed (non-blocking):', e);
        }
      }

      return result;
    }, { idempotencyKey, entityType: entityType || 'mutation' });
  };

  return { safeSubmit, submitting };
}
