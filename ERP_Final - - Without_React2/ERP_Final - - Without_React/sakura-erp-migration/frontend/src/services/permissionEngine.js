/**
 * Enterprise RBAC Permission Engine
 * fn_user_has_permission RPC + utilities.
 */
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

let _permissionCache = null;
let _cacheUserId = null;
let _cacheTtl = 0;
const CACHE_MS = 60000;

async function client() {
  await ensureSupabaseReady();
  return supabaseClient;
}

export async function userHasPermission(userId, permissionCode) {
  if (!userId || !permissionCode) return false;
  const c = await client();
  if (!c) return false;
  const { data, error } = await c.rpc('fn_user_has_permission', {
    p_user_id: userId,
    p_permission_code: permissionCode
  });
  if (error) { console.warn('userHasPermission error:', error); return false; }
  return !!data;
}

/** 3-layer permission: role + location + action. p_location_id optional. */
export async function userHasPermissionWithLocation(userId, permissionCode, locationId = null) {
  if (!userId || !permissionCode) return false;
  const c = await client();
  if (!c) return false;
  const { data, error } = await c.rpc('fn_user_has_permission_with_location', {
    p_user_id: userId,
    p_permission_code: permissionCode,
    p_location_id: locationId || null
  });
  if (error) { console.warn('userHasPermissionWithLocation error:', error); return false; }
  return !!data;
}

export async function getUserPermissions(userId) {
  if (!userId) return [];
  const c = await client();
  if (!c) return [];
  const { data, error } = await c.rpc('fn_user_permissions', { p_user_id: userId });
  if (error) {
    if (error.code !== 'PGRST202' && error.message?.includes('not found') === false) {
      console.warn('getUserPermissions error:', error.message || error);
    }
    return [];
  }
  return Array.isArray(data) ? data : [];
}

export async function getCachedUserPermissions(userId) {
  if (!userId) return [];
  if (_permissionCache && _cacheUserId === userId && Date.now() < _cacheTtl) return _permissionCache;
  const perms = await getUserPermissions(userId);
  _permissionCache = perms;
  _cacheUserId = userId;
  _cacheTtl = Date.now() + CACHE_MS;
  return perms;
}

export function invalidatePermissionCache() { _permissionCache = null; _cacheUserId = null; _cacheTtl = 0; }

export async function userHasAnyPermission(userId, permissionCodes) {
  if (!Array.isArray(permissionCodes) || permissionCodes.length === 0) return false;
  const perms = await getCachedUserPermissions(userId);
  if (perms.includes('*')) return true;
  return permissionCodes.some(code => perms.includes(code));
}
