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
 * Get current user UUID for DB writes. NEVER returns name.
 * Use for: created_by, approved_by, posted_by, deleted_by
 */
export function getCurrentUserUUID() {
  try {
    const store = useAuthStore();
    const id = store?.user?.id;
    return safeUUID(id);
  } catch {
    return null;
  }
}
