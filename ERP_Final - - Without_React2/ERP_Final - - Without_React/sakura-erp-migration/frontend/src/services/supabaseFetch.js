/**
 * Safe Supabase fetch helpers for custom anon auth (RLS bypass via RPC where needed).
 */
import { supabaseClient, getCurrentCompanyId } from '@/services/supabase';
import { getCurrentUserUUID, safeUUID } from '@/utils/uuidUtils';

function authCtx() {
  return {
    uid: getCurrentUserUUID(),
    companyId: safeUUID(getCurrentCompanyId())
  };
}

function unwrapRpcRow(data) {
  return Array.isArray(data) ? data[0] : data;
}

export async function fetchByUUID(table, uuid) {
  if (!uuid) throw new Error(`${table}: missing id`);
  const { uid, companyId } = authCtx();

  if (table === 'grn_inspections' && (uid || companyId)) {
    const { data, error } = await supabaseClient.rpc('fn_app_get_grn', {
      p_user_id: uid || null,
      p_grn_id: uuid,
      p_company_id: companyId || null
    }).maybeSingle();
    if (!error && data) return data;
    if (error && error.code !== 'PGRST202') {
      throw new Error(`grn_inspections fetch failed: ${error.message}`);
    }
  }

  if (table === 'purchase_orders' && (uid || companyId)) {
    const poNumeric = typeof uuid === 'string' ? parseInt(uuid, 10) : Number(uuid);
    if (Number.isFinite(poNumeric)) {
      const { data, error } = await supabaseClient.rpc('fn_app_get_purchase_order', {
        p_user_id: uid || null,
        p_po_id: poNumeric,
        p_company_id: companyId || null
      }).maybeSingle();
      if (!error && data) return data;
      if (error && error.code !== 'PGRST202') {
        throw new Error(`purchase_orders fetch failed: ${error.message}`);
      }
    }
  }

  const { data, error } = await supabaseClient
    .from(table)
    .select('*')
    .eq('id', uuid)
    .maybeSingle();

  if (error) throw new Error(`${table} fetch failed: ${error.message}`);
  if (!data) throw new Error(`${table} record not found for id: ${uuid}`);
  return data;
}

export async function updateGrnHeaderViaRpc(grnId, fields = {}) {
  const { uid, companyId } = authCtx();
  const { data, error } = await supabaseClient.rpc('fn_app_update_grn', {
    p_user_id: uid || null,
    p_grn_id: grnId,
    p_company_id: companyId || null,
    p_status: fields.status ?? null,
    p_approved_by: fields.approved_by ?? null,
    p_approval_date: fields.approval_date ?? fields.approved_at ?? null,
    p_received_by: fields.received_by ?? null,
    p_submitted_for_approval: fields.submitted_for_approval ?? null
  }).maybeSingle();

  if (error) {
    const missing = error.code === 'PGRST202' || String(error.message || '').includes('fn_app_update_grn');
    if (missing) return null;
    throw new Error(`GRN update failed: ${error.message}`);
  }
  return unwrapRpcRow(data);
}
