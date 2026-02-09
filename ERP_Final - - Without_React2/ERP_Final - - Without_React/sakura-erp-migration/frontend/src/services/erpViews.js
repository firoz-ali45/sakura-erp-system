/**
 * ERP DB-driven views and RPC — single source of truth.
 * No local calculations. All data from Supabase views/functions.
 */

import { ensureSupabaseReady, supabaseClient } from '@/services/supabase.js';

/**
 * Stock Overview: v_item_stock_full
 * Fields: item_id, item_code, item_name, total_stock, batch_count, latest_batch, batch_numbers
 */
export async function fetchItemStockFull() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_item_stock_full').select('*');
  if (error) {
    console.warn('fetchItemStockFull:', error);
    return [];
  }
  return data || [];
}

/**
 * GRN batch column: v_grn_batch_summary — join by grn_id, use display_batch
 */
export async function fetchGrnBatchSummary() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_grn_batch_summary').select('grn_id, batch_count, display_batch');
  if (error) {
    console.warn('fetchGrnBatchSummary:', error);
    return [];
  }
  return data || [];
}

/**
 * Button visibility: fn_can_create_next_document(doc_type, doc_id)
 * Returns true if next document in chain can be created.
 */
export async function canCreateNextDocument(docType, docId) {
  const ready = await ensureSupabaseReady();
  if (!ready || !docId) return false;
  const { data, error } = await supabaseClient.rpc('fn_can_create_next_document', {
    p_doc_type: String(docType).toUpperCase(),
    p_doc_id: String(docId)
  });
  if (error) {
    console.warn('canCreateNextDocument:', error);
    return false;
  }
  return data === true;
}

/**
 * v_transaction_status — for dashboard / status refresh after actions
 */
export async function fetchTransactionStatus() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_transaction_status').select('*');
  if (error) {
    console.warn('fetchTransactionStatus:', error);
    return [];
  }
  return data || [];
}

/**
 * v_document_flow_full — document chain
 */
export async function fetchDocumentFlowFull() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_document_flow_full').select('*').order('created_at', { ascending: false }).limit(500);
  if (error) {
    console.warn('fetchDocumentFlowFull:', error);
    return [];
  }
  return data || [];
}

/**
 * v_item_batches_full — after GRN approval, reload batch data
 */
export async function fetchItemBatchesFull() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_item_batches_full').select('*');
  if (error) {
    console.warn('fetchItemBatchesFull:', error);
    return [];
  }
  return data || [];
}

/**
 * v_inventory_balance — ledger-only balance (item_name, sku, storage_unit, location_name, batch_no, current_qty, avg_cost, total_value)
 */
export async function fetchInventoryBalance() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_inventory_balance').select('*');
  if (error) {
    console.warn('fetchInventoryBalance:', error);
    return [];
  }
  return data || [];
}

/**
 * v_inventory_history — ledger audit (item_name, sku, location, transaction_type, reference, qty, cost, reason, notes, created_by, created_at)
 */
export async function fetchInventoryHistory() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_inventory_history').select('*').order('created_at', { ascending: false }).limit(1000);
  if (error) {
    console.warn('fetchInventoryHistory:', error);
    return [];
  }
  return data || [];
}

/**
 * fn_inventory_control_report(from_date, to_date) — date-range report: opening, in/out buckets, closing from ledger only
 */
export async function fetchInventoryControlReport(fromDate, toDate) {
  const ready = await ensureSupabaseReady();
  if (!ready || !fromDate || !toDate) return [];
  const { data, error } = await supabaseClient.rpc('fn_inventory_control_report', {
    p_from_date: fromDate,
    p_to_date: toDate
  });
  if (error) {
    console.warn('fetchInventoryControlReport:', error);
    return [];
  }
  return data || [];
}

/**
 * v_purchase_orders_report, v_transfer_orders_report, v_transfers_report, v_purchasing_report, v_cost_adjustment_history
 */
export async function fetchPurchasingReport() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_purchasing_report').select('*');
  if (error) { console.warn('fetchPurchasingReport:', error); return []; }
  return data || [];
}
export async function fetchTransferOrdersReport() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_transfer_orders_report').select('*');
  if (error) { console.warn('fetchTransferOrdersReport:', error); return []; }
  return data || [];
}
export async function fetchTransfersReport() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_transfers_report').select('*');
  if (error) { console.warn('fetchTransfersReport:', error); return []; }
  return data || [];
}
export async function fetchCostAdjustmentHistory() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  const { data, error } = await supabaseClient.from('v_cost_adjustment_history').select('*');
  if (error) { console.warn('fetchCostAdjustmentHistory:', error); return []; }
  return data || [];
}

/**
 * Force refresh after PR create, PO create, GRN approve, Purchase create, Payment post.
 * Returns { itemStock, transactionStatus, documentFlow, itemBatches } — no cache.
 * Dispatches 'erp:refresh-stock' so Stock Overview can auto-refresh.
 */
export async function forceRefreshAfterAction() {
  return forceSystemSync();
}

/**
 * Force live refresh: reloads v_item_stock_full, v_document_flow_full, v_transaction_status, v_inventory_balance, v_inventory_history.
 * Call after: GRN approve, PO create, Purchase create, Payment post, Transfer, Production, Sale, Adjustment.
 */
export async function forceSystemSync() {
  const [itemStock, transactionStatus, documentFlow, itemBatches, inventoryBalance, inventoryHistory] = await Promise.all([
    fetchItemStockFull(),
    fetchTransactionStatus(),
    fetchDocumentFlowFull(),
    fetchItemBatchesFull(),
    fetchInventoryBalance(),
    fetchInventoryHistory()
  ]);
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('erp:refresh-stock'));
    window.dispatchEvent(new CustomEvent('erp:refresh-inventory-views'));
  }
  return { itemStock, transactionStatus, documentFlow, itemBatches, inventoryBalance, inventoryHistory };
}

/**
 * Reload v_inventory_balance, v_inventory_control (via date range), v_inventory_history. No cached state.
 * Call after GRN, Transfer, Production, Sale, Adjustment.
 */
export async function forceInventoryViewsRefresh() {
  const [balance, history] = await Promise.all([fetchInventoryBalance(), fetchInventoryHistory()]);
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('erp:refresh-inventory-views'));
  }
  return { balance, history };
}
