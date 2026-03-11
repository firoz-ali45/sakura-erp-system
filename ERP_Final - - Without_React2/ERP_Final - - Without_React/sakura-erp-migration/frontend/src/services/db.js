/**
 * CENTRALIZED DATABASE LAYER — Strict alignment with Supabase schema.
 * All inserts/updates MUST go through this module. No direct supabase.from().insert().
 *
 * RULES:
 * - NEVER send user.name to DB (UUID columns only: created_by, approved_by, etc.)
 * - NEVER allow null company_id when required (multi-tenant enforcement)
 * - NEVER send invalid UUID or string IDs to UUID columns
 * - dbInsert auto-injects: company_id, created_by (UUID), created_at
 */

import { getCurrentUserUUID, safeUUID } from '@/utils/uuidUtils';

const FALLBACK_COMPANY_UUID = '00000000-0000-0000-0000-000000000000';
const STORAGE_KEY_COMPANY = 'sakura_company_id';
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Tables that need BOTH company_id and tenant_id (same context value) — production batches has company_id NOT NULL */
const BOTH_COMPANY_AND_TENANT_TABLES = new Set(['batches', 'grn_batches']);
/**
 * Schema alignment: tables that have NO company_id column (do not inject — avoid PGRST204).
 * Derived from actual Supabase schema for all tables used with dbInsert/dbInsertMany.
 */
const SKIP_COMPANY_TABLES = new Set([
  'grn_inspections', 'grn_inspection_items', 'grn_inspection_item',
  'purchase_order_items', 'purchasing_invoice_items', 'purchase_orders', 'purchase_requests', 'pr_po_linkage',
  'purchasing_invoices', 'finance_atms', 'finance_banks', 'finance_payments',
  'inventory_locations', 'roles', 'role_location_access',
  'transfer_orders', 'transfer_order_items',
  'production_items', 'wip_lots', 'fg_batches', 'recipe_ingredients'
]);
/**
 * Schema alignment: tables that have NO created_by column (do not inject — avoid schema cache error).
 */
const SKIP_CREATED_BY_TABLES = new Set([
  'grn_inspection_items', 'grn_inspection_item', 'purchase_order_items', 'purchasing_invoice_items',
  'finance_atms', 'finance_banks', 'inventory_locations', 'pr_po_linkage',
  'roles', 'role_location_access', 'transfer_orders', 'transfer_order_items',
  'production_items', 'production_consumption', 'wip_lots', 'fg_batches', 'recipe_ingredients'
]);

/** If value is a valid UUID return it, else null. Re-export from uuidUtils for DB layer. */
export { safeUUID };

const _safeUUID = (v) => {
  if (v == null || v === '') return null;
  const s = String(v).trim();
  return UUID_REGEX.test(s) ? s : null;
};

/**
 * Get current company/tenant ID for multi-tenant. Never returns null when enforced.
 * Source: localStorage sakura_company_id → VITE_COMPANY_ID → fallback UUID.
 */
export function getCurrentCompanyId() {
  try {
    if (typeof window !== 'undefined' && window.localStorage) {
      const stored = localStorage.getItem(STORAGE_KEY_COMPANY);
      if (stored && _safeUUID(stored)) return _safeUUID(stored);
    }
    const envId = typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_COMPANY_ID;
    const id = (envId && typeof envId === 'string' && envId.trim()) ? envId.trim() : null;
    return _safeUUID(id) || FALLBACK_COMPANY_UUID;
  } catch {
    return FALLBACK_COMPANY_UUID;
  }
}

/**
 * Set company context (e.g. after login). Call from auth flow.
 */
export function setCurrentCompanyId(companyId) {
  const valid = _safeUUID(companyId);
  if (valid && typeof window !== 'undefined' && window.localStorage) {
    localStorage.setItem(STORAGE_KEY_COMPANY, valid);
  }
}

/** Strip fields that must NEVER be sent to DB (user display names only; keep entity names like recipe name, item name). */
function sanitizePayload(data, options = {}) {
  const out = { ...data };
  delete out.userName;
  delete out.user_name;
  delete out.approved_by_name;
  delete out.created_by_name;
  if (options.stripNames !== false) {
    ['received_by_name', 'quality_checked_by_name', 'posted_by_name'].forEach(k => delete out[k]);
  }
  return out;
}

/** Ensure created_by, approved_by, etc. are UUID only (null if invalid) */
function enforceUUIDColumns(data) {
  const out = { ...data };
  const uuidKeys = ['created_by', 'approved_by', 'received_by', 'quality_checked_by', 'posted_by', 'updated_by', 'deleted_by'];
  uuidKeys.forEach(k => {
    if (k in out && out[k] != null && _safeUUID(out[k]) === null) {
      out[k] = null;
    }
  });
  return out;
}

/**
 * Prepare payload for insert: inject company_id/tenant_id, created_by (UUID only), created_at.
 * @param {string} table - Table name
 * @param {object} data - Row data
 * @param {{ skipCompanyId?: boolean, skipCreatedBy?: boolean, skipCreatedAt?: boolean, requireCompanyId?: boolean }} options
 */
function prepareInsertPayload(table, data, options = {}) {
  const sanitized = sanitizePayload(enforceUUIDColumns(data));
  const companyId = getCurrentCompanyId();

  if (options.requireCompanyId !== false && !options.skipCompanyId && companyId == null) {
    throw new Error('DB insert requires company context. Set sakura_company_id or VITE_COMPANY_ID.');
  }

  if (!options.skipCompanyId && companyId != null && !SKIP_COMPANY_TABLES.has(table)) {
    sanitized.company_id = sanitized.company_id ?? companyId;
    if (BOTH_COMPANY_AND_TENANT_TABLES.has(table)) {
      sanitized.tenant_id = sanitized.tenant_id ?? companyId;
    }
  }
  if (!options.skipCreatedBy && !SKIP_CREATED_BY_TABLES.has(table)) {
    const uid = getCurrentUserUUID();
    if (sanitized.created_by != null && _safeUUID(sanitized.created_by) === null) {
      sanitized.created_by = uid;
    } else if (sanitized.created_by == null) {
      sanitized.created_by = uid;
    } else {
      sanitized.created_by = _safeUUID(sanitized.created_by);
    }
  } else if (SKIP_CREATED_BY_TABLES.has(table)) {
    delete sanitized.created_by;
  }
  if (!options.skipCreatedAt && sanitized.created_at == null) {
    sanitized.created_at = new Date().toISOString();
  }
  return sanitized;
}

/**
 * Insert one row. Auto-injects company_id (or tenant_id for batch tables), created_by (UUID only), created_at.
 * @param {object} client - Supabase client (from supabase.js)
 * @param {string} table - Table name
 * @param {object} data - Row data (no user names; UUID columns must be valid or omitted)
 * @param {{ skipCompanyId?: boolean, skipCreatedBy?: boolean, skipCreatedAt?: boolean, requireCompanyId?: boolean }} options
 */
export async function dbInsert(client, table, data, options = {}) {
  if (!client) throw new Error('DB client required');
  const payload = prepareInsertPayload(table, data, options);
  const { data: rows, error } = await client.from(table).insert([payload]).select();
  if (error) throw error;
  const result = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
  if (!result) throw new Error(`Insert into ${table} succeeded but no row returned (check RLS or RETURNING)`);
  return result;
}

/**
 * Insert multiple rows. Same injection rules per row.
 */
export async function dbInsertMany(client, table, rows, options = {}) {
  if (!client) throw new Error('DB client required');
  const payloads = rows.map(row => prepareInsertPayload(table, row, options));
  const { data, error } = await client.from(table).insert(payloads).select();
  if (error) throw error;
  return data || [];
}

/**
 * Update rows. Validates UUID columns; does not inject company_id.
 */
export async function dbUpdate(client, table, data, filters) {
  if (!client) throw new Error('DB client required');
  const sanitized = sanitizePayload(enforceUUIDColumns(data));
  let q = client.from(table).update(sanitized);
  if (filters && typeof filters === 'object') {
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null) q = q.eq(key, value);
    });
  }
  const { data: rows, error } = await q.select();
  if (error) throw error;
  const result = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
  if (!result && filters && Object.keys(filters).length > 0) {
    console.warn(`dbUpdate: ${table} matched 0 rows (filters: ${JSON.stringify(filters)}) — update may have applied; continuing`);
  }
  return result;
}

/**
 * Delete rows by filters.
 */
export async function dbDelete(client, table, filters) {
  if (!client) throw new Error('DB client required');
  let q = client.from(table).delete();
  if (filters && typeof filters === 'object') {
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null) q = q.eq(key, value);
    });
  }
  const { error } = await q;
  if (error) throw error;
}

export { getCurrentUserUUID };
