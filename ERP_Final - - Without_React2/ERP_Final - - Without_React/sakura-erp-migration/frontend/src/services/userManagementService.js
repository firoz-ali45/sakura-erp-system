/**
 * Enterprise User Management Service
 * SAP-style RBAC. Supabase = source of truth.
 * NO hardcoded roles. All DB-driven.
 */
import { supabaseClient, ensureSupabaseReady } from '@/services/supabase.js';

async function sb() {
  await ensureSupabaseReady();
  return supabaseClient;
}

// --- ROLES (DB-driven) ---
export async function getRoles(filters = {}) {
  const client = await sb();
  if (!client) return [];
  let q = client.from('roles').select('*').order('role_name');
  if (filters.is_active !== undefined) {
    q = q.eq('is_active', filters.is_active);
  }
  const { data, error } = await q;
  if (error) {
    console.error('getRoles error:', error);
    return [];
  }
  return data || [];
}

export async function createRole({ role_name, role_code, description, is_active = true }) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const code = role_code || role_name?.toUpperCase().replace(/\s+/g, '_');
  const { data, error } = await client.from('roles').insert({
    role_name,
    role_code: code,
    description,
    is_active: is_active ?? true
  }).select().single();
  if (error) throw error;
  return data;
}

export async function updateRole(id, payload) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { data, error } = await client.from('roles').update({
    ...payload,
    updated_at: new Date().toISOString()
  }).eq('id', id).select().single();
  if (error) throw error;
  return data;
}

// --- PERMISSIONS MASTER ---
export async function getPermissionsMaster() {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('permissions_master').select('*').order('module').order('permission_code');
  if (error) {
    console.error('getPermissionsMaster error:', error);
    return [];
  }
  return data || [];
}

// --- ROLE PERMISSIONS (permission matrix) ---
export async function getRolePermissions(roleId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('role_permissions')
    .select('permission_id, permissions_master(permission_code, module, action, description)')
    .eq('role_id', roleId);
  if (error) {
    console.error('getRolePermissions error:', error);
    return [];
  }
  return (data || []).map(r => r.permissions_master).filter(Boolean);
}

export async function setRolePermissions(roleId, permissionCodes) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { data: perms } = await client.from('permissions_master').select('id, permission_code').in('permission_code', permissionCodes);
  const permIds = (perms || []).map(p => p.id);
  await client.from('role_permissions').delete().eq('role_id', roleId);
  if (permIds.length) {
    await client.from('role_permissions').insert(permIds.map(pid => ({ role_id: roleId, permission_id: pid })));
  }
  return { success: true };
}

// --- ROLE LOCATION ACCESS ---
export async function getRoleLocationAccess(roleId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('role_location_access')
    .select('location_id, inventory_locations(location_code, location_name, location_type)')
    .eq('role_id', roleId);
  if (error) return [];
  return (data || []).map(r => r.inventory_locations).filter(Boolean);
}

export async function setRoleLocationAccess(roleId, locationIds, accessAllLocations) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  await client.from('role_location_access').delete().eq('role_id', roleId);
  if (!accessAllLocations && locationIds?.length) {
    await client.from('role_location_access').insert(locationIds.map(lid => ({ role_id: roleId, location_id: lid })));
  }
  await client.from('roles').update({ access_all_locations: !!accessAllLocations, updated_at: new Date().toISOString() }).eq('id', roleId);
  return { success: true };
}

// --- fn_user_has_permission (RPC) ---
export async function userHasPermission(userId, permissionCode) {
  const client = await sb();
  if (!client) return false;
  const { data, error } = await client.rpc('fn_user_has_permission', { p_user_id: userId, p_permission_code: permissionCode });
  if (error) {
    console.warn('userHasPermission error:', error);
    return false;
  }
  return !!data;
}

// --- USER ACTIVITY LOGS ---
export async function logActivity(userId, action, entityType = null, entityId = null, details = {}) {
  const client = await sb();
  if (!client) return;
  await client.from('user_activity_logs').insert({
    user_id: userId,
    action,
    entity_type: entityType,
    entity_id: entityId,
    metadata: details
  });
}

export async function getActivityLogs(filters = {}) {
  const client = await sb();
  if (!client) return [];
  let q = client.from('user_activity_logs').select('*, users(name, email)').order('created_at', { ascending: false }).limit(500);
  if (filters.user_id) q = q.eq('user_id', filters.user_id);
  if (filters.action) q = q.eq('action', filters.action);
  const { data, error } = await q;
  if (error) return [];
  return data || [];
}

// --- LOGIN SESSIONS ---
export async function getLoginSessions(activeOnly = true) {
  const client = await sb();
  if (!client) return [];
  let q = client.from('login_sessions').select('*, users(name, email)').order('login_time', { ascending: false });
  if (activeOnly) q = q.eq('is_active', true);
  const { data, error } = await q;
  if (error) return [];
  return data || [];
}

export async function forceLogoutSession(sessionId) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  await client.from('login_sessions').update({ is_active: false, logout_time: new Date().toISOString() }).eq('id', sessionId);
  return { success: true };
}

// --- SECURITY SETTINGS ---
export async function getSecuritySettings() {
  const client = await sb();
  if (!client) return {};
  const { data, error } = await client.from('security_settings').select('*');
  if (error) return {};
  return (data || []).reduce((acc, r) => {
    acc[r.setting_key] = r.setting_value;
    return acc;
  }, {});
}

export async function updateSecuritySetting(key, value) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  await client.from('security_settings').upsert({ setting_key: key, setting_value: value, updated_at: new Date().toISOString() }, { onConflict: 'setting_key' });
  return { success: true };
}
