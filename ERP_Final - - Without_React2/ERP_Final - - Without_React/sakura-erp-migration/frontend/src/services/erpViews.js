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
 * Force refresh after PR create, PO create, GRN approve, Purchase create, Payment post.
 * Returns { itemStock, transactionStatus, documentFlow } — no cache.
 */
export async function forceRefreshAfterAction() {
  const [itemStock, transactionStatus, documentFlow] = await Promise.all([
    fetchItemStockFull(),
    fetchTransactionStatus(),
    fetchDocumentFlowFull()
  ]);
  return { itemStock, transactionStatus, documentFlow };
}
