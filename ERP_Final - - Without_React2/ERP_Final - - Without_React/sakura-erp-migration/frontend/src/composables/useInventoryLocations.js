import { ref } from 'vue';

const locationsCache = ref([]);

/**
 * Load GRN/PO destinations from inventory_locations ONLY.
 * WHERE is_active = true AND allow_grn = true. No hardcoded list, no fallback to all locations (no ghost locations).
 */
export async function loadLocationsForGRN() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name, location_type')
      .eq('is_active', true)
      .eq('allow_grn', true)
      .order('location_name');
    if (error) {
      console.warn('loadLocationsForGRN:', error);
      return [];
    }
    locationsCache.value = data || [];
    return (data || []).map(loc => `${loc.location_name} (${loc.location_code})`);
  } catch (e) {
    console.warn('loadLocationsForGRN:', e);
    return [];
  }
}

/**
 * Load all inventory_locations (optionally active only). Returns full rows.
 */
export async function loadInventoryLocations(activeOnly = false) {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    let q = supabaseClient
      .from('inventory_locations')
      .select('*')
      .order('location_name');
    if (activeOnly) q = q.eq('is_active', true);
    const { data, error } = await q;
    if (error) throw error;
    return data || [];
  } catch (e) {
    console.warn('loadInventoryLocations:', e);
    return [];
  }
}

/**
 * PO destination = allow_grn = true (same as GRN). Returns display strings "Name (code)".
 */
export async function loadLocationsForPO() {
  return loadLocationsForGRN();
}

/**
 * Transfer OUT source: allow_transfer_out = true. Returns display strings.
 */
export async function loadLocationsForTransferSource() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .eq('allow_transfer_out', true)
      .order('location_name');
    if (error) return [];
    return (data || []).map(loc => `${loc.location_name} (${loc.location_code})`);
  } catch (e) {
    return [];
  }
}

/**
 * Transfer destination: is_active = true only.
 */
export async function loadLocationsForTransferDestination() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .order('location_name');
    if (error) return [];
    return (data || []).map(loc => `${loc.location_name} (${loc.location_code})`);
  } catch (e) {
    return [];
  }
}

/**
 * Transfer source: warehouse OR branch, is_active = true.
 */
export async function loadTransferSourceLocations() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .in('location_type', ['WAREHOUSE', 'BRANCH'])
      .order('location_name');
    if (error) return [];
    return data || [];
  } catch (e) {
    return [];
  }
}

/**
 * Transfer destination: full objects { id, location_code, location_name } for SAP transfer engine.
 */
export async function loadTransferDestLocations() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .order('location_name');
    if (error) return [];
    return data || [];
  } catch (e) {
    return [];
  }
}

/** @deprecated Use loadLocationsForTransferSource for display strings. */
export async function loadLocationsForTransferOut() {
  return loadLocationsForTransferSource();
}

/**
 * Production: allow_production = true. Returns display strings.
 */
export async function loadLocationsForProduction() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .eq('allow_production', true)
      .order('location_name');
    if (error) return [];
    return (data || []).map(loc => `${loc.location_name} (${loc.location_code})`);
  } catch (e) {
    return [];
  }
}

/**
 * POS: allow_pos_sale = true.
 */
export async function loadLocationsForPOS() {
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready || !supabaseClient) return [];
    const { data, error } = await supabaseClient
      .from('inventory_locations')
      .select('id, location_code, location_name')
      .eq('is_active', true)
      .eq('allow_pos_sale', true)
      .order('location_name');
    if (error) return [];
    return (data || []).map(loc => `${loc.location_name} (${loc.location_code})`);
  } catch (e) {
    return [];
  }
}

/**
 * Reports / filters: is_active = true only.
 */
export async function loadLocationsForReports() {
  const list = await loadInventoryLocations(true);
  return list.map(loc => `${loc.location_name} (${loc.location_code})`);
}

export function useInventoryLocations() {
  return {
    loadLocationsForGRN,
    loadLocationsForPO,
    loadLocationsForTransferSource,
    loadLocationsForTransferDestination,
    loadTransferSourceLocations,
    loadTransferDestLocations,
    loadLocationsForTransferOut,
    loadLocationsForProduction,
    loadLocationsForPOS,
    loadLocationsForReports,
    loadInventoryLocations,
    locationsCache
  };
}
