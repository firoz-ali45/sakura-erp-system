/**
 * UUID utilities for Supabase DB columns (created_by, approved_by, etc.)
 * FULL UUID ALIGNMENT - Database is UUID-native. NEVER send user name to DB.
 *
 * ROOT CAUSE FIX: "invalid input syntax for type uuid" errors occur when
 * frontend sends TEXT (e.g. "Ali") to UUID columns. Use these helpers everywhere.
 */

import { useAuthStore } from '@/stores/auth';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Returns value if it's a valid UUID, otherwise null.
 * Use for created_by, approved_by, posted_by, deleted_by - NEVER pass user name.
 */
export function safeUUID(value) {
  if (value == null || value === '') return null;
  const s = String(value).trim();
  return UUID_REGEX.test(s) ? s : null;
}

/** Alias for backward compatibility */
export const asUuidOrNull = safeUUID;

/**
 * Extract a DB-safe user id from a session user object.
 */
function uuidFromSessionUser(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const id = raw.id ?? raw.user_id ?? raw.userId ?? null;
  return safeUUID(id);
}

/**
 * Get current user UUID for DB writes. NEVER returns name.
 * Handles Pinia ref: store.user may be ref, use .value to unwrap.
 * Falls back to persisted session in localStorage when Pinia is not active
 * or the in-memory user is empty. Tries `nexora_current_user` first (current
 * auth store key), then legacy `sakura_current_user`.
 * Non-UUID ids (e.g. legacy text names) → safeUUID returns null.
 */
export function getCurrentUserUUID() {
  try {
    const store = useAuthStore();
    const u = store.user;
    const raw = u && typeof u === 'object' && 'value' in u ? u.value : u;
    const fromStore = uuidFromSessionUser(raw);
    if (fromStore) return fromStore;
  } catch {
    /* no active Pinia — fall through */
  }

  try {
    if (typeof window === 'undefined' || !window.localStorage) return null;
    for (const key of ['nexora_current_user', 'sakura_current_user']) {
      const s = localStorage.getItem(key);
      if (!s) continue;
      const parsed = JSON.parse(s);
      const id = uuidFromSessionUser(parsed);
      if (id) return id;
    }
    return null;
  } catch {
    return null;
  }
}
