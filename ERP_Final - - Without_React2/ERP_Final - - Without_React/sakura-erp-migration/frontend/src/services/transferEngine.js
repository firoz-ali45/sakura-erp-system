/**
 * SAP Transfer Order Engine - Frontend Service
 * All data from Supabase views/RPC. No fake data.
 */

import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

// --- Views ---

export async function fetchTransferOrdersFull() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_transfer_orders_full').select('*').order('created_at', { ascending: false });
  if (error) {
    console.warn('fetchTransferOrdersFull:', error);
    return [];
  }
  return data || [];
}

export async function fetchTransferItemsFlow(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('v_transfer_items_flow')
    .select('*')
    .eq('transfer_id', transferId)
    .order('item_id');
  if (error) {
    console.warn('fetchTransferItemsFlow:', error);
    return [];
  }
  return data || [];
}

// --- RPCs ---

export async function canDispatchTransfer(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return false;
  const { data, error } = await supabaseClient.rpc('fn_can_dispatch_transfer', { p_transfer_id: transferId });
  if (error) {
    console.warn('canDispatchTransfer:', error);
    return false;
  }
  return data === true;
}

export async function canReceiveTransfer(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return false;
  const { data, error } = await supabaseClient.rpc('fn_can_receive_transfer', { p_transfer_id: transferId });
  if (error) {
    console.warn('canReceiveTransfer:', error);
    return false;
  }
  return data === true;
}

export async function getNextTransferApprovalStep(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return null;
  const { data, error } = await supabaseClient.rpc('fn_next_transfer_approval_step', { p_transfer_id: transferId });
  if (error) {
    console.warn('getNextTransferApprovalStep:', error);
    return null;
  }
  const row = Array.isArray(data) ? data[0] : data;
  return row || null;
}

export async function submitTransfer(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_submit_transfer', { p_transfer_id: transferId });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function approveTransferLevel(transferId, level, approvedBy) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_approve_transfer_level', {
    p_transfer_id: transferId,
    p_level: level,
    p_approved_by: approvedBy
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function rejectTransfer(transferId, rejectedBy) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_reject_transfer', {
    p_transfer_id: transferId,
    p_rejected_by: rejectedBy
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function dispatchTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_dispatch_transfer', {
    p_transfer_id: transferId,
    p_user_id: userId || 'user'
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function receiveTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_receive_transfer', {
    p_transfer_id: transferId,
    p_user_id: userId || 'user'
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function receiveTransferItem(transferId, itemId, qty, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_receive_transfer_item', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_received_qty: Number(qty),
    p_user_id: userId || 'user'
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

// --- CRUD (transfer_orders + transfer_order_items) ---

export async function createTransferDraft(payload) {
  const ready = await ensureSupabaseReady();
  if (!ready) return { success: false, error: 'Supabase not ready' };
  const { from_location_id, to_location_id, requested_by, items } = payload;
  if (!from_location_id || !to_location_id) return { success: false, error: 'From and To location required' };
  if (!items || items.length === 0) return { success: false, error: 'At least one item required' };

  try {
    const { data: header, error: headerError } = await supabaseClient
      .from('transfer_orders')
      .insert({
        from_location_id,
        to_location_id,
        status: 'draft',
        requested_by: requested_by || null
      })
      .select()
      .single();

    if (headerError) return { success: false, error: headerError.message };
    if (!header) return { success: false, error: 'Insert failed' };

    const rows = items.map((it) => ({
      transfer_id: header.id,
      item_id: it.item_id,
      requested_qty: Number(it.requested_qty) || 0
    })).filter((r) => r.requested_qty > 0);

    if (rows.length === 0) return { success: false, error: 'No valid items' };

    const { error: itemsError } = await supabaseClient.from('transfer_order_items').insert(rows);
    if (itemsError) {
      await supabaseClient.from('transfer_orders').delete().eq('id', header.id);
      return { success: false, error: itemsError.message };
    }

    return { success: true, data: header };
  } catch (e) {
    return { success: false, error: e?.message || 'Unknown error' };
  }
}

export async function updateTransferDraft(transferId, payload) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { success: false, error: 'Invalid' };

  const { from_location_id, to_location_id, items } = payload;

  try {
    const updates = {};
    if (from_location_id) updates.from_location_id = from_location_id;
    if (to_location_id) updates.to_location_id = to_location_id;

    if (Object.keys(updates).length > 0) {
      const { error: upErr } = await supabaseClient
        .from('transfer_orders')
        .update(updates)
        .eq('id', transferId)
        .eq('status', 'draft');
      if (upErr) return { success: false, error: upErr.message };
    }

    if (items && Array.isArray(items)) {
      await supabaseClient.from('transfer_order_items').delete().eq('transfer_id', transferId);
      const rows = items.map((it) => ({
        transfer_id: transferId,
        item_id: it.item_id,
        requested_qty: Number(it.requested_qty) || 0
      })).filter((r) => r.requested_qty > 0);
      if (rows.length > 0) {
        const { error: insErr } = await supabaseClient.from('transfer_order_items').insert(rows);
        if (insErr) return { success: false, error: insErr.message };
      }
    }

    return { success: true };
  } catch (e) {
    return { success: false, error: e?.message || 'Unknown error' };
  }
}

export async function deleteTransferDraft(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { success: false, error: 'Invalid' };
  try {
    await supabaseClient.from('transfer_order_items').delete().eq('transfer_id', transferId);
    const { error } = await supabaseClient.from('transfer_orders').delete().eq('id', transferId).eq('status', 'draft');
    if (error) return { success: false, error: error.message };
    return { success: true };
  } catch (e) {
    return { success: false, error: e?.message || 'Unknown error' };
  }
}

export async function getTransferOrderById(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return null;
  const { data, error } = await supabaseClient
    .from('v_transfer_orders_full')
    .select('*')
    .eq('id', transferId)
    .single();
  if (error) return null;
  return data;
}
