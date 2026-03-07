/**
 * SAP Transfer Order Engine - Frontend Service
 * All data from Supabase views/RPC. No fake data.
 */

import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function asUuidOrNull(v) {
  return (v && UUID_REGEX.test(String(v))) ? v : null;
}

// --- Stock Transfers (TRS-000001, separate from TO) ---

export async function removeItemFromStockTransfer(transferId, itemId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_remove_item_from_stock_transfer', {
    p_transfer_id: transferId,
    p_item_id: itemId
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function addItemToStockTransfer(transferId, itemId, transferQty) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_add_item_to_stock_transfer', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_transfer_qty: Number(transferQty) || 0
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function createDirectTransfer(fromLocationId, toLocationId, businessDate, createdBy) {
  const ready = await ensureSupabaseReady();
  if (!ready || !fromLocationId || !toLocationId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_create_direct_transfer', {
    p_from_location_id: fromLocationId,
    p_to_location_id: toLocationId,
    p_business_date: businessDate ? String(businessDate).slice(0, 10) : null,
    p_created_by: asUuidOrNull(createdBy)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function createTransferFromTo(toId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !toId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_create_transfer_from_to', { p_to_id: toId });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function getStockTransferById(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return null;
  const { data, error } = await supabaseClient
    .from('v_stock_transfers_full')
    .select('*')
    .eq('id', transferId)
    .single();
  if (error) return null;
  return data;
}

export async function fetchStockTransferItems(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('v_stock_transfer_items_full')
    .select('*')
    .eq('transfer_id', transferId)
    .order('item_id');
  if (error) return [];
  return data || [];
}

export async function fetchStockTransfersList() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient
    .from('v_stock_transfers_full')
    .select('*')
    .order('created_at', { ascending: false });
  if (error) return [];
  return data || [];
}

export async function startPickingStockTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_start_picking_stock_transfer', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function updateStockTransferItemPicking(transferId, itemId, batchId, pickedQty, damagedQty, unitCost) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_update_stock_transfer_item_picking', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_batch_id: batchId || null,
    p_picked_qty: Number(pickedQty) || 0,
    p_damaged_qty: Number(damagedQty) || 0,
    p_unit_cost: unitCost != null ? Number(unitCost) : null
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

/** Save multiple batch allocations for one transfer item (FEFO multi-batch pick). */
export async function updateStockTransferItemPickingMulti(transferId, itemId, allocations) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { ok: false, error: 'Not ready' };
  const payload = Array.isArray(allocations)
    ? allocations
        .filter((a) => a.batchId && (Number(a.pickedQty) || 0) > 0)
        .map((a) => ({
          batch_id: a.batchId,
          picked_qty: Number(a.pickedQty) || 0,
          damaged_qty: Number(a.damagedQty) || 0,
          unit_cost: a.unitCost != null ? Number(a.unitCost) : null
        }))
    : [];
  const { data, error } = await supabaseClient.rpc('fn_update_stock_transfer_item_picking_multi', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_allocations: payload
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function confirmPickingStockTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_confirm_picking_stock_transfer', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

/** Drivers: DB source of truth. users JOIN user_roles JOIN roles WHERE role_code=DRIVER, status=active. */
export async function fetchDrivers() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { getActiveDrivers } = await import('@/services/userManagementService.js');
  return getActiveDrivers();
}

export async function dispatchToDriver(transferId, driverId, vehicleNo, sealNumber, expectedDeliveryTime, notes, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !driverId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_dispatch_to_driver', {
    p_transfer_id: transferId,
    p_driver_id: driverId,
    p_vehicle_no: vehicleNo || null,
    p_seal_number: sealNumber || null,
    p_expected_delivery_time: expectedDeliveryTime || null,
    p_notes: notes || null,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  if (userId) {
    const { logActivity } = await import('@/services/userManagementService.js');
    logActivity(userId, 'transfer_dispatch', 'transfer', transferId, { driver_id: driverId });
  }
  return data || { ok: false };
}

export async function warehouseMarkInTransit(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_warehouse_mark_in_transit', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function driverAcceptTransfer(transferId, driverId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !driverId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_driver_accept_transfer', {
    p_transfer_id: transferId,
    p_driver_id: driverId
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function driverArrived(transferId, driverId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !driverId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_driver_arrived', {
    p_transfer_id: transferId,
    p_driver_id: driverId
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function warehouseMarkArrived(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_warehouse_mark_arrived', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function qualityCheckTransfer(transferId, conditionStatus, temperature, damageFlag, expiredItemsFlag, notes, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_quality_check_transfer', {
    p_transfer_id: transferId,
    p_condition_status: conditionStatus,
    p_temperature: temperature != null ? Number(temperature) : null,
    p_damage_flag: !!damageFlag,
    p_expired_items_flag: !!expiredItemsFlag,
    p_notes: notes || null,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function generateDeliveryOtp(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_generate_delivery_otp', { p_transfer_id: transferId });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function verifyDeliveryOtp(transferId, otp, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !otp) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_verify_delivery_otp', {
    p_transfer_id: transferId,
    p_otp: String(otp).trim(),
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function fetchLogisticsHandover(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return null;
  const { data, error } = await supabaseClient
    .from('v_logistics_handover_full')
    .select('*')
    .eq('transfer_id', transferId)
    .order('handover_time', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) return null;
  return data;
}

export async function fetchQualityChecks(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('transfer_quality_checks')
    .select('*')
    .eq('transfer_id', transferId)
    .order('created_at', { ascending: false });
  if (error) return [];
  return data || [];
}

export async function insertTransferLogisticsEvent(transferId, payload, createdBy) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_insert_transfer_logistics_event', {
    p_transfer_id: transferId,
    p_vehicle_no: payload?.vehicle_no || null,
    p_driver_name: payload?.driver_name || null,
    p_temp_check: payload?.temp_check || null,
    p_damage_check: payload?.damage_check || null,
    p_notes: payload?.notes || null,
    p_created_by: asUuidOrNull(createdBy)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function dispatchStockTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_dispatch_stock_transfer', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function insertTransferDamageReport(transferId, itemId, damagedQty, responsibility, notes, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId || !responsibility) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_insert_transfer_damage_report', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_damaged_qty: Number(damagedQty) || 0,
    p_responsibility: responsibility,
    p_notes: notes || null,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function receiveStockTransferItem(transferId, itemId, batchId, receivedQty, damagedQty, rejectedQty, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_receive_stock_transfer_item', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_batch_id: batchId || null,
    p_received_qty: Number(receivedQty) || 0,
    p_damaged_qty: Number(damagedQty) || 0,
    p_rejected_qty: Number(rejectedQty) || 0,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function deleteStockTransfer(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_delete_stock_transfer', { p_transfer_id: transferId });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function fetchStockTransferAudit(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  let { data, error } = await supabaseClient
    .from('stock_transfer_audit')
    .select('*, users:performed_by(name)')
    .eq('transfer_id', transferId)
    .order('performed_at', { ascending: true });
  if (error) {
    // Fallback when relation embed is unavailable.
    const retry = await supabaseClient
      .from('stock_transfer_audit')
      .select('*')
      .eq('transfer_id', transferId)
      .order('performed_at', { ascending: true });
    data = retry.data;
    error = retry.error;
  }
  if (error) return [];
  return (data || []).map((row) => ({
    ...row,
    performed_by_name: row?.users?.name ?? row?.performed_by_name ?? null
  }));
}

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
    p_approved_by: asUuidOrNull(approvedBy)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function rejectTransfer(transferId, rejectedBy) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_reject_transfer', {
    p_transfer_id: transferId,
    p_rejected_by: asUuidOrNull(rejectedBy)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

export async function dispatchTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_dispatch_transfer', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  if (userId) {
    const { logActivity } = await import('@/services/userManagementService.js');
    logActivity(userId, 'transfer_dispatch', 'transfer', transferId, {});
  }
  return data || { ok: false };
}

export async function receiveTransfer(transferId, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_receive_transfer', {
    p_transfer_id: transferId,
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  if (userId) {
    const { logActivity } = await import('@/services/userManagementService.js');
    logActivity(userId, 'transfer_receive', 'transfer', transferId, {});
  }
  return data || { ok: false };
}

export async function receiveTransferItem(transferId, itemId, qty, userId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { ok: false, error: 'Not ready' };
  const { data, error } = await supabaseClient.rpc('fn_receive_transfer_item', {
    p_transfer_id: transferId,
    p_item_id: itemId,
    p_received_qty: Number(qty),
    p_user_id: asUuidOrNull(userId)
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false };
}

// --- CRUD (transfer_orders + transfer_order_items) ---

/** Create minimal draft — source + destination only. Items added on detail page. */
export async function createTransferDraft(payload) {
  const ready = await ensureSupabaseReady();
  if (!ready) return { success: false, error: 'Supabase not ready' };
  const { from_location_id, to_location_id, requested_by } = payload;
  if (!from_location_id || !to_location_id) return { success: false, error: 'From and To location required' };
  if (from_location_id === to_location_id) return { success: false, error: 'Source and destination must be different' };

  try {
    const { dbInsert, dbInsertMany } = await import('@/services/db.js');
    const insertPayload = {
      from_location_id,
      to_location_id,
      status: 'draft',
      requested_by: asUuidOrNull(requested_by),
      transfer_number: null, // TO number generated ONLY on submit
      business_date: new Date().toISOString().slice(0, 10) // auto today
    };

    const header = await dbInsert(supabaseClient, 'transfer_orders', insertPayload);
    if (!header) return { success: false, error: 'Insert failed' };

    const items = payload.items || [];
    const rows = items.map((it) => ({
      transfer_id: header.id,
      item_id: it.item_id,
      requested_qty: Number(it.requested_qty) || 0
    })).filter((r) => r.requested_qty > 0);

    if (rows.length > 0) {
      try {
        await dbInsertMany(supabaseClient, 'transfer_order_items', rows);
      } catch (itemsError) {
        await supabaseClient.from('transfer_orders').delete().eq('id', header.id);
        return { success: false, error: itemsError?.message || 'Items insert failed' };
      }
    }

    return { success: true, data: header };
  } catch (e) {
    return { success: false, error: e?.message || 'Unknown error' };
  }
}

export async function updateTransferDraft(transferId, payload) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return { success: false, error: 'Invalid' };

  const { from_location_id, to_location_id, remarks, business_date, items } = payload;

  try {
    const updates = {};
    if (from_location_id) updates.from_location_id = from_location_id;
    if (to_location_id) updates.to_location_id = to_location_id;
    if (remarks !== undefined) updates.remarks = remarks;
    if (business_date !== undefined) updates.business_date = business_date ? String(business_date).slice(0, 10) : null;

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
        const { dbInsertMany } = await import('@/services/db.js');
        await dbInsertMany(supabaseClient, 'transfer_order_items', rows);
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

/** Raw transfer_order_items for draft. Used for add/update/remove. */
export async function fetchTransferOrderItemsRaw(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('transfer_order_items')
    .select('id, item_id, requested_qty')
    .eq('transfer_id', transferId);
  if (error) return [];
  return data || [];
}

/** Add items to draft transfer. */
export async function addItemsToTransferOrder(transferId, newItems) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !newItems?.length) return { success: false, error: 'Invalid' };
  const existing = await fetchTransferOrderItemsRaw(transferId);
  const items = [
    ...existing.map((r) => ({ item_id: r.item_id, requested_qty: Number(r.requested_qty) || 0 })),
    ...newItems.map((it) => ({ item_id: it.item_id, requested_qty: Number(it.requested_qty) || 0 }))
  ].filter((r) => r.requested_qty > 0);
  const merged = new Map();
  items.forEach((it) => {
    const k = it.item_id;
    merged.set(k, (merged.get(k) || 0) + it.requested_qty);
  });
  const final = Array.from(merged.entries()).map(([item_id, requested_qty]) => ({ item_id, requested_qty }));
  return updateTransferDraft(transferId, { items: final });
}

/** Update single item qty in draft. */
export async function updateTransferItemQty(transferId, itemId, requestedQty) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { success: false, error: 'Invalid' };
  const existing = await fetchTransferOrderItemsRaw(transferId);
  const items = existing.map((r) => ({
    item_id: r.item_id,
    requested_qty: r.item_id === itemId ? Number(requestedQty) || 0 : Number(r.requested_qty) || 0
  })).filter((r) => r.requested_qty > 0);
  return updateTransferDraft(transferId, { items });
}

/** Remove item from draft. */
export async function removeTransferItem(transferId, itemId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !itemId) return { success: false, error: 'Invalid' };
  const existing = await fetchTransferOrderItemsRaw(transferId);
  const items = existing.filter((r) => r.item_id !== itemId).map((r) => ({
    item_id: r.item_id,
    requested_qty: Number(r.requested_qty) || 0
  })).filter((r) => r.requested_qty > 0);
  return updateTransferDraft(transferId, { items });
}

/** Import items from Excel rows (SKU, Quantity). Returns { success, added, errors }. */
export async function importTransferItemsFromRows(transferId, fromLocationId, rows) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId || !fromLocationId || !rows?.length) return { success: false, added: [], errors: ['Invalid input'] };
  const errors = [];
  const { data: allItemsData } = await supabaseClient
    .from('inventory_items')
    .select('id, sku, name')
    .or('deleted.eq.false,deleted.is.null');
  const skuToItem = (allItemsData || []).reduce((acc, it) => {
    acc[(it.sku || '').toLowerCase()] = it;
    return acc;
  }, {});

  const toAdd = [];
  for (let i = 0; i < rows.length; i++) {
    const sku = String(rows[i].SKU || rows[i].sku || '').trim();
    const qty = parseFloat(rows[i].Quantity || rows[i].quantity || rows[i].Qty || 0);
    if (!sku) continue;
    const item = skuToItem[sku.toLowerCase()];
    if (!item) {
      errors.push(`Row ${i + 1}: SKU "${sku}" not found`);
      continue;
    }
    if (qty <= 0) {
      errors.push(`Row ${i + 1}: Invalid quantity for ${sku}`);
      continue;
    }
    toAdd.push({ item_id: item.id, requested_qty: qty });
  }

  if (toAdd.length === 0 && errors.length === 0) return { success: false, added: [], errors: ['No valid rows'] };
  const result = await addItemsToTransferOrder(transferId, toAdd);
  if (!result.success) return { success: false, added: [], errors: [result.error] };
  return { success: true, added: toAdd, errors };
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

/** v_inventory_balance at location — available stock per item. NOT cached. */
export async function fetchInventoryBalanceAtLocation(locationId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !locationId) return [];
  const { data, error } = await supabaseClient
    .from('v_inventory_balance')
    .select('item_id, item_name, sku, storage_unit, location_name, batch_no, current_qty, avg_cost, total_value')
    .eq('location_id', locationId)
    .gt('current_qty', 0);
  if (error) {
    console.warn('fetchInventoryBalanceAtLocation:', error);
    return [];
  }
  return data || [];
}

/** Aggregate balance per item at location (sum across batches for available qty). */
export async function fetchItemStockAtLocation(locationId) {
  const rows = await fetchInventoryBalanceAtLocation(locationId);
  const byItem = {};
  rows.forEach((r) => {
    const k = r.item_id;
    if (!byItem[k]) {
      byItem[k] = { item_id: k, item_name: r.item_name, sku: r.sku, storage_unit: r.storage_unit, available_qty: 0, avg_cost: 0, total_value: 0, batches: [] };
    }
    byItem[k].available_qty = (byItem[k].available_qty || 0) + Number(r.current_qty || 0);
    byItem[k].total_value = (byItem[k].total_value || 0) + Number(r.total_value || 0);
    if (r.batch_no) byItem[k].batches.push(r.batch_no);
  });
  return Object.values(byItem).map((x) => {
    x.avg_cost = x.available_qty > 0 ? x.total_value / x.available_qty : 0;
    return x;
  });
}

/** Batches for item at location, FEFO (nearest expiry first). For batch selection in picking. */
export async function fetchBatchesForItemAtLocation(locationId, itemId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !locationId || !itemId) return [];
  const { data, error } = await supabaseClient
    .from('v_inventory_balance')
    .select('batch_id, batch_no, current_qty, avg_cost, total_value')
    .eq('location_id', locationId)
    .eq('item_id', itemId)
    .gt('current_qty', 0)
    .order('batch_no'); // FEFO: order by expiry - v_inventory_balance may need expiry; use batch_no as fallback
  if (error) return [];
  return data || [];
}

/** Batches with expiry for FEFO. Uses inventory_batches for expiry. */
export async function fetchBatchesFefoAtLocation(locationId, itemId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !locationId || !itemId) return [];
  const { data, error } = await supabaseClient
    .from('v_inventory_balance')
    .select('batch_id, batch_no, current_qty, avg_cost, total_value')
    .eq('location_id', locationId)
    .eq('item_id', itemId)
    .gt('current_qty', 0);
  if (error) return [];
  const rows = data || [];
  const batchIds = rows.map((r) => r.batch_id).filter(Boolean);
  if (!batchIds.length) return rows;
  const { data: batchData } = await supabaseClient
    .from('batches')
    .select('id, expiry_date')
    .in('id', batchIds);
  const expiryMap = (batchData || []).reduce((acc, b) => {
    acc[b.id] = b.expiry_date ? new Date(b.expiry_date).getTime() : 9999999999999;
    return acc;
  }, {});
  return rows
    .map((r) => ({ ...r, expiry_date: batchData?.find((b) => b.id === r.batch_id)?.expiry_date }))
    .sort((a, b) => (expiryMap[a.batch_id] || 9999999999999) - (expiryMap[b.batch_id] || 9999999999999));
}

/** Map item_id -> { available_qty, avg_cost, batches } at location. For enriching transfer items. */
export async function fetchStockMapForItems(locationId, itemIds) {
  const ready = await ensureSupabaseReady();
  if (!ready || !locationId || !itemIds?.length) return {};
  const ids = [...new Set(itemIds)];
  const { data, error } = await supabaseClient
    .from('v_inventory_balance')
    .select('item_id, batch_no, current_qty, avg_cost, total_value')
    .eq('location_id', locationId)
    .in('item_id', ids)
    .gt('current_qty', 0);
  if (error) return {};
  const byItem = {};
  (data || []).forEach((r) => {
    const k = r.item_id;
    if (!byItem[k]) {
      byItem[k] = { available_qty: 0, total_value: 0, batches: [] };
    }
    byItem[k].available_qty = (byItem[k].available_qty || 0) + Number(r.current_qty || 0);
    byItem[k].total_value = (byItem[k].total_value || 0) + Number(r.total_value || 0);
    if (r.batch_no) byItem[k].batches.push(r.batch_no);
  });
  return Object.fromEntries(
    Object.entries(byItem).map(([k, v]) => [
      k,
      { ...v, avg_cost: v.available_qty > 0 ? v.total_value / v.available_qty : 0 }
    ])
  );
}

/** transfer_dispatches for timeline. */
export async function fetchTransferDispatches(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('transfer_dispatches')
    .select('*')
    .eq('transfer_id', transferId)
    .order('dispatched_at', { ascending: false });
  if (error) return [];
  return data || [];
}

/** transfer_receipts for timeline. */
export async function fetchTransferReceipts(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('transfer_receipts')
    .select('*')
    .eq('transfer_id', transferId)
    .order('received_at', { ascending: false });
  if (error) return [];
  return data || [];
}

/** transfer_approvals for timeline. */
export async function fetchTransferApprovals(transferId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !transferId) return [];
  const { data, error } = await supabaseClient
    .from('transfer_approvals')
    .select('*')
    .eq('transfer_id', transferId)
    .order('approval_level');
  if (error) {
    console.warn('fetchTransferApprovals:', error);
    return [];
  }
  return data || [];
}

/** inventory_items search — NOT cached. For Add Items search. */
export async function searchInventoryItems(query, limit = 50) {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  let q = supabaseClient
    .from('inventory_items')
    .select('id, name, sku, barcode, storage_unit, cost')
    .or('deleted.eq.false,deleted.is.null')
    .limit(limit);
  if (query && String(query).trim()) {
    const ql = String(query).trim();
    q = q.or(`name.ilike.%${ql}%,sku.ilike.%${ql}%,barcode.ilike.%${ql}%`);
  }
  const { data, error } = await q.order('name');
  if (error) {
    console.warn('searchInventoryItems:', error);
    return [];
  }
  return data || [];
}
