/**
 * UUID → Name display mapping for UI.
 * DB stores UUID. UI shows name.
 * Uses fn_list_company_users (SECURITY DEFINER) — direct users SELECT fails under SaaS RLS when auth.uid() ≠ public.users.id.
 */
import { shallowRef } from 'vue';
import { supabaseClient, ensureSupabaseReady } from '@/services/supabase';
import { getCurrentCompanyId } from '@/services/db.js';
import { parseFnListCompanyUsers } from '@/services/userManagementService';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
let _userMap = null;
let _fetchPromise = null;
let _mapCompanyId = null;

export function useUserDisplay() {
  const userMap = shallowRef(_userMap || {});

  async function loadUserMap(userIds = []) {
    const companyId = getCurrentCompanyId();
    if (!companyId) return {};
    const needIds = [...new Set((userIds || []).filter(Boolean))];
    if (needIds.length === 0) return {};

    try {
      const ready = await ensureSupabaseReady();
      if (!ready || !supabaseClient) return {};

      if (_mapCompanyId !== companyId) {
        _userMap = {};
        _mapCompanyId = companyId;
        userMap.value = _userMap;
      }

      const missing = needIds.filter((id) => !(_userMap && Object.prototype.hasOwnProperty.call(_userMap, id)));
      if (missing.length === 0) {
        const out = {};
        needIds.forEach((id) => {
          if (_userMap[id] != null) out[id] = _userMap[id];
        });
        return out;
      }

      if (_fetchPromise) await _fetchPromise;

      _fetchPromise = (async () => {
        const { data: rawUsers, error } = await supabaseClient.rpc('fn_list_company_users', { p_company_id: companyId });
        if (error) {
          console.warn('loadUserMap fn_list_company_users:', error.message);
          return;
        }
        const rows = parseFnListCompanyUsers(rawUsers);
        const map = { ...(_userMap || {}) };
        rows.forEach((r) => {
          if (r?.id) map[r.id] = r.name || r.email?.split('@')[0] || '—';
        });
        needIds.forEach((id) => {
          if (!(id in map)) map[id] = '—';
        });
        _userMap = map;
        userMap.value = _userMap;
      })();

      await _fetchPromise;
      _fetchPromise = null;

      const out = {};
      needIds.forEach((id) => {
        if (_userMap[id] != null) out[id] = _userMap[id];
      });
      return out;
    } catch {
      return {};
    }
  }

  function getUserDisplayName(uuid) {
    if (!uuid) return '—';
    const u = userMap.value || _userMap || {};
    const key = String(uuid);
    return u[key] || (UUID_REGEX.test(key) ? '—' : key);
  }

  return { userMap, loadUserMap, getUserDisplayName };
}
