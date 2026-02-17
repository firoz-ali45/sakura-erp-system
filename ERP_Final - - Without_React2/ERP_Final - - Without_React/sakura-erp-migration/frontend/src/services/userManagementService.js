/**
 * Enterprise User Management Service
 * SAP-style RBAC. Supabase = source of truth.
 * NO hardcoded roles. All DB-driven.
 */
import { supabaseClient, ensureSupabaseReady } from '@/services/supabase.js';

function _currentUserId() {
  try {
    const u = localStorage.getItem('sakura_current_user');
    if (!u) return null;
    const parsed = JSON.parse(u);
    return parsed?.id || null;
  } catch { return null; }
}

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

export async function createRole({ role_name, role_code, description, is_active = true }, actingUserId = null) {
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
  const uid = actingUserId || _currentUserId();
  if (uid) logActivity(uid, 'role_create', 'roles', data?.id, { role_name, role_code: code });
  return data;
}

export async function getRoleById(id) {
  const client = await sb();
  if (!client) return null;
  const { data, error } = await client.from('roles').select('*').eq('id', id).single();
  if (error) return null;
  return data;
}

export async function getUsersByRoleId(roleId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('user_roles')
    .select('user_id, is_primary, users(id, name, email, status)')
    .eq('role_id', roleId);
  if (error) return [];
  return (data || []).map(r => r.users).filter(Boolean);
}

export async function getUsersByRoleCode(roleCode) {
  const client = await sb();
  if (!client) return [];
  const { data: roles } = await client.from('roles').select('id').ilike('role_code', roleCode).limit(1);
  if (!roles?.length) return [];
  return getUsersByRoleId(roles[0].id);
}

export async function updateRole(id, payload, actingUserId = null) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { data, error } = await client.from('roles').update({
    ...payload,
    updated_at: new Date().toISOString()
  }).eq('id', id).select().single();
  if (error) throw error;
  const uid = actingUserId || _currentUserId();
  if (uid) logActivity(uid, 'role_edit', 'roles', id, { changes: Object.keys(payload) });
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

export async function setRolePermissions(roleId, permissionCodes, actingUserId = null) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { data: perms } = await client.from('permissions_master').select('id, permission_code').in('permission_code', permissionCodes);
  const permIds = (perms || []).map(p => p.id);
  await client.from('role_permissions').delete().eq('role_id', roleId);
  if (permIds.length) {
    await client.from('role_permissions').insert(permIds.map(pid => ({ role_id: roleId, permission_id: pid })));
  }
  const uid = actingUserId || _currentUserId();
  if (uid) logActivity(uid, 'permission_change', 'roles', roleId, { permission_count: permIds.length });
  return { success: true };
}

// --- INVENTORY LOCATIONS (for role location picker) ---
export async function getInventoryLocations() {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('inventory_locations').select('id, location_code, location_name, location_type').eq('is_active', true).order('location_code');
  if (error) return [];
  return data || [];
}

// --- ROLE LOCATION ACCESS ---
export async function getRoleLocationAccess(roleId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('role_location_access')
    .select('location_id, inventory_locations(id, location_code, location_name, location_type)')
    .eq('role_id', roleId);
  if (error) return [];
  return (data || []).map(r => r.inventory_locations ? { ...r.inventory_locations, id: r.location_id } : null).filter(Boolean);
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

// --- USER PROFILE (single user with roles, locations, etc.) ---
export async function getUserById(userId) {
  const client = await sb();
  if (!client) return null;
  const { data, error } = await client.from('users').select('*').eq('id', userId).single();
  if (error) return null;
  return data;
}

export async function getUserRoles(userId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('user_roles')
    .select('role_id, is_primary, roles(id, role_name, role_code, description, access_all_locations)')
    .eq('user_id', userId);
  if (error) return [];
  return (data || []).map(ur => ({
    role_id: ur.role_id,
    is_primary: ur.is_primary,
    ...(ur.roles || {})
  })).filter(r => r.role_id);
}

export async function getUserLocationAccess(userId) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('user_location_access')
    .select('location_id, inventory_locations(id, location_code, location_name, location_type)')
    .eq('user_id', userId);
  if (error) return [];
  return (data || []).map(ul => ul.inventory_locations).filter(Boolean);
}

// --- USERS (enriched with RBAC role & locations) ---
export async function getUsersEnriched() {
  const client = await sb();
  if (!client) return [];
  const { data: users, error } = await client.from('users').select('*').order('created_at', { ascending: false });
  if (error) return [];
  const { data: roles } = await client.from('roles').select('id, role_name, role_code, access_all_locations');
  const roleMap = (roles || []).reduce((m, r) => { m[r.id] = r; return m; }, {});
  const { data: userRoles } = await client.from('user_roles').select('user_id, role_id, is_primary');
  const { data: userLocs } = await client.from('user_location_access').select('user_id, inventory_locations(location_name, location_code)');
  const { data: allLocs } = await client.from('inventory_locations').select('id, location_name, location_code');
  const locMap = (allLocs || []).reduce((m, l) => { m[l.id] = l; return m; }, {});
  const urByUser = (userRoles || []).reduce((m, ur) => {
    if (!m[ur.user_id]) m[ur.user_id] = [];
    m[ur.user_id].push(ur);
    return m;
  }, {});
  const ulByUser = (userLocs || []).reduce((m, ul) => {
    if (!m[ul.user_id]) m[ul.user_id] = [];
    const loc = ul.inventory_locations;
    if (loc) m[ul.user_id].push(loc.location_name || loc.location_code);
    return m;
  }, {});
  return (users || []).map(u => {
    const urs = urByUser[u.id] || [];
    const primary = urs.find(ur => ur.is_primary) || urs[0];
    const r = primary ? roleMap[primary.role_id] : null;
    const locs = ulByUser[u.id] || [];
    let assignedLocations = locs.length ? locs.join(', ') : null;
    if (!assignedLocations && r?.access_all_locations !== false) assignedLocations = 'All';
    if (!assignedLocations) assignedLocations = '-';
    return {
      ...u,
      primaryRoleCode: r?.role_code || u.role,
      primaryRoleName: r?.role_name || u.role,
      assignedLocations
    };
  });
}

export async function createUserWithRole(userData, roleId = null, actingUserId = null) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { createUserInSupabase } = await import('@/services/supabase.js');
  const res = await createUserInSupabase(userData);
  if (!res.success) throw new Error(res.error || 'Failed to create user');
  const user = res.data;
  if (roleId && user?.id) {
    await client.from('user_roles').insert({ user_id: user.id, role_id: roleId, is_primary: true });
  }
  const uid = actingUserId || _currentUserId();
  if (uid) logActivity(uid, 'user_create', 'users', user?.id, { email: user?.email });
  return user;
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
  try {
    const ua = typeof navigator !== 'undefined' ? navigator.userAgent?.slice(0, 500) : null;
    await client.rpc('fn_log_user_action', {
      p_user_id: userId,
      p_action: action,
      p_entity_type: entityType,
      p_entity_id: entityId,
      p_metadata: details && typeof details === 'object' ? details : {},
      p_ip: null,
      p_user_agent: ua
    });
  } catch (e) {
    console.warn('logActivity:', e);
  }
}

export async function getActivityLogs(filters = {}) {
  const client = await sb();
  if (!client) return [];
  let q = client.from('user_activity_logs').select('*, users(name, email)').order('created_at', { ascending: false }).limit(500);
  if (filters.user_id) q = q.eq('user_id', filters.user_id);
  if (filters.action?.trim()) q = q.ilike('action', `%${filters.action.trim()}%`);
  const { data, error } = await q;
  if (error) return [];
  return data || [];
}

// --- LOGIN SESSIONS ---
export async function getLoginSessions(activeOnly = true, userId = null) {
  const client = await sb();
  if (!client) return [];
  let q = client.from('login_sessions').select('*, users(name, email)').order('login_time', { ascending: false });
  if (activeOnly) q = q.eq('is_active', true);
  if (userId) q = q.eq('user_id', userId);
  const { data, error } = await q;
  if (error) return [];
  return data || [];
}

export async function getLoginSessionsByUser(userId, activeOnly = false) {
  return getLoginSessions(activeOnly, userId);
}

export async function forceLogoutSession(sessionId) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { error } = await client.rpc('fn_close_login_session', { p_session_id: sessionId, p_forced: true });
  if (error) throw error;
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

export async function updateSecuritySetting(key, value, actingUserId = null) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  await client.from('security_settings').upsert({ setting_key: key, setting_value: value, updated_at: new Date().toISOString() }, { onConflict: 'setting_key' });
  const uid = actingUserId || _currentUserId();
  if (uid) logActivity(uid, 'settings_change', 'security_settings', key, { key, value });
  return { success: true };
}

// --- LOGIN ATTEMPTS ---
export async function getLoginAttempts(limit = 200) {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('login_attempts').select('*').order('created_at', { ascending: false }).limit(limit);
  if (error) return [];
  return data || [];
}

// --- API TOKENS ---
export async function getApiTokens() {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('api_access_tokens').select('*, users(name, email)').order('created_at', { ascending: false });
  if (error) return [];
  return data || [];
}

// --- BLOCKED USERS ---
export async function getBlockedUsers() {
  const client = await sb();
  if (!client) return [];
  const { data, error } = await client.from('users').select('id, name, email, status').in('status', ['suspended', 'blocked']).order('name');
  if (error) return [];
  return data || [];
}

export async function updateUserStatus(userId, status) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { error } = await client.from('users').update({ status, updated_at: new Date().toISOString() }).eq('id', userId);
  if (error) throw error;
  const uid = _currentUserId();
  if (uid) logActivity(uid, status === 'deleted' ? 'user_delete' : 'user_status_change', 'users', userId, { status });
  return { success: true };
}

export async function forceLogoutUser(userId) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { data, error } = await client.rpc('fn_force_logout_user', { p_user_id: userId });
  if (error) throw error;
  const uid = _currentUserId();
  if (uid) logActivity(uid, 'force_logout_user', 'users', userId, { sessions_closed: data ?? 0 });
  return { sessionsClosed: data ?? 0 };
}

export async function resetUserPassword(userId, newPassword) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const { error } = await client.rpc('fn_reset_user_password', { p_user_id: userId, p_new_password: newPassword });
  if (error) throw error;
  const uid = _currentUserId();
  if (uid) logActivity(uid, 'password_reset', 'users', userId, {});
  return { success: true };
}

export async function cloneRole(roleId) {
  const client = await sb();
  if (!client) throw new Error('Supabase not ready');
  const role = await getRoleById(roleId);
  if (!role) throw new Error('Role not found');
  const perms = await getRolePermissions(roleId);
  const permCodes = perms.map(p => p.permission_code);
  const locs = await getRoleLocationAccess(roleId);
  const locIds = locs.map(l => l.id).filter(Boolean);
  const accessAll = role.access_all_locations !== false;
  const newName = (role.role_name || '') + ' (Copy)';
  const newCode = (role.role_code || '') + '_COPY_' + Date.now();
  const created = await createRole({ role_name: newName, role_code: newCode, description: role.description || '' });
  if (permCodes.length) await setRolePermissions(created.id, permCodes);
  await setRoleLocationAccess(created.id, locIds, accessAll);
  return created;
}
