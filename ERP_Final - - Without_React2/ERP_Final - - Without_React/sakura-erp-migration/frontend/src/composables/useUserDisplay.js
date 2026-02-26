/**
 * UUID → Name display mapping for UI.
 * DB stores UUID. UI shows name.
 * Load user map once, use everywhere for created_by, approved_by, etc.
 */
import { shallowRef } from 'vue';
import { supabaseClient, ensureSupabaseReady } from '@/services/supabase';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
let _userMap = null;
let _loadPromise = null;

export function useUserDisplay() {
  const userMap = shallowRef(_userMap || {});

  async function loadUserMap(userIds = []) {
    if (!userIds.length) return {};
    const ids = [...new Set(userIds.filter(Boolean))];
    if (ids.length === 0) return {};
    try {
      const ready = await ensureSupabaseReady();
      if (!ready || !supabaseClient) return {};
      const { data } = await supabaseClient
        .from('users')
        .select('id, name, email')
        .in('id', ids);
      const map = {};
      (data || []).forEach((r) => {
        map[r.id] = r.name || r.email?.split('@')[0] || '—';
      });
      _userMap = { ...(_userMap || {}), ...map };
      userMap.value = _userMap;
      return map;
    } catch {
      return {};
    }
  }

  function getUserDisplayName(uuid) {
    if (!uuid) return '—';
    const u = userMap.value || _userMap || {};
    return u[uuid] || (UUID_REGEX.test(String(uuid)) ? '—' : uuid);
  }

  return { userMap, loadUserMap, getUserDisplayName };
}
