/**
 * UUID utilities for Supabase DB columns (created_by, approved_by, etc.)
 * CRITICAL: Never send user name or non-UUID to UUID columns - causes "invalid input syntax for type uuid" error.
 */

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Returns value if it's a valid UUID, otherwise null.
 * Use for created_by, approved_by, posted_by, etc. - never pass user name.
 */
export function asUuidOrNull(value) {
  if (value == null || value === '') return null;
  const s = String(value).trim();
  return UUID_REGEX.test(s) ? s : null;
}
