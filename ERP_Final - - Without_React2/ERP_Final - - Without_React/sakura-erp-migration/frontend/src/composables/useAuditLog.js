/**
 * Enterprise audit trail composable.
 * Logs actions to audit_logs for compliance and traceability.
 */
let _auditLogger = null;

export function useAuditLog() {
  const logAction = async (action, entityType, entityId, oldValues = null, newValues = null) => {
    try {
      if (!_auditLogger) {
        const { supabaseClient } = await import('@/services/supabase.js');
        const { AuditLogger } = await import('@/services/advancedERPFeatures.js');
        _auditLogger = new AuditLogger(supabaseClient);
      }
      await _auditLogger.logAction(action, entityType, entityId, oldValues, newValues);
    } catch (e) {
      console.warn('Audit log failed (non-blocking):', e);
    }
  };

  return { logAction };
}
