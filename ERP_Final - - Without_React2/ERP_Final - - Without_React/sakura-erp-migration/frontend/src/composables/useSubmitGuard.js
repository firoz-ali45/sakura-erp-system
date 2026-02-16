/**
 * Enterprise double-submit prevention.
 * Wraps async handlers to block re-entry until completion.
 * Optional: idempotency key blocks same action within cooldown window.
 * Use with :disabled="submitting" on buttons.
 */
import { ref } from 'vue';

const IDEMPOTENCY_PREFIX = 'sakura_idem_';
const COOLDOWN_MS = 3000; // 3s cooldown after success

export function useSubmitGuard() {
  const submitting = ref(false);

  /**
   * Execute an async handler with submit guard.
   * Blocks re-entry until completion. Optionally uses idempotency key.
   * @param {() => Promise<any>} handler - Async function to run
   * @param {Object} options - { idempotencyKey?: string, entityType?: string }
   * @returns {Promise<any>} Handler result or undefined if blocked
   */
  const guard = async (handler, options = {}) => {
    if (submitting.value) return;
    if (typeof handler !== 'function') return;

    const { idempotencyKey, entityType = 'action' } = options;
    const key = idempotencyKey || `${entityType}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    const storageKey = IDEMPOTENCY_PREFIX + key;

    // Check cooldown (recent success with same key)
    if (typeof sessionStorage !== 'undefined') {
      const lastSuccess = sessionStorage.getItem(storageKey);
      if (lastSuccess) {
        const elapsed = Date.now() - parseInt(lastSuccess, 10);
        if (elapsed < COOLDOWN_MS) return;
        sessionStorage.removeItem(storageKey);
      }
    }

    submitting.value = true;
    try {
      const result = await handler();
      if (typeof sessionStorage !== 'undefined' && idempotencyKey) {
        sessionStorage.setItem(storageKey, String(Date.now()));
        setTimeout(() => sessionStorage.removeItem(storageKey), COOLDOWN_MS);
      }
      return result;
    } finally {
      submitting.value = false;
    }
  };

  return { submitting, guard };
}
