-- ============================================================
-- SAP-LEVEL — PART 6: FIX EXISTING BROKEN DATA
-- Backfill stock_batches from grn_batches; fix batch numbers; no duplicate flows (already deduped).
-- ============================================================

-- 1. Backfill stock_batches from existing grn_batches (where not already present)
INSERT INTO stock_batches (item_id, grn_id, batch_no, expiry_date, qty_received, remaining_qty)
SELECT
  sub.item_id,
  sub.grn_id,
  sub.batch_no,
  sub.expiry_date,
  sub.qty_received,
  sub.remaining_qty
FROM (
  SELECT
    COALESCE(gb.item_id, (SELECT item_id FROM grn_inspection_items WHERE grn_inspection_id = gb.grn_id LIMIT 1)) AS item_id,
    gb.grn_id,
    COALESCE(NULLIF(TRIM(gb.batch_number), ''), fn_next_item_batch_number(COALESCE(gb.item_id, (SELECT item_id FROM grn_inspection_items WHERE grn_inspection_id = gb.grn_id LIMIT 1)))) AS batch_no,
    gb.expiry_date::date AS expiry_date,
    COALESCE(gb.quantity, 0) AS qty_received,
    COALESCE(gb.quantity, 0) AS remaining_qty
  FROM grn_batches gb
  WHERE gb.grn_id IS NOT NULL
) sub
WHERE sub.item_id IS NOT NULL
ON CONFLICT (grn_id, item_id, batch_no) DO UPDATE SET
  qty_received = EXCLUDED.qty_received,
  remaining_qty = GREATEST(0, COALESCE(stock_batches.remaining_qty, EXCLUDED.remaining_qty));

-- 2. Ensure document_flow.source_document_type/source_document_id populated from source_type/source_id
UPDATE document_flow SET source_document_type = source_type, source_document_id = source_id WHERE source_document_type IS NULL;

-- 3. Set PR status = closed where all items have quantity_remaining <= 0
UPDATE purchase_requests pr SET status = 'closed', updated_at = now()
WHERE pr.status IS DISTINCT FROM 'closed'
  AND (SELECT COALESCE(SUM(quantity_remaining), 0) FROM purchase_request_items WHERE pr_id = pr.id AND (deleted IS NOT TRUE)) <= 0;

-- 4. Set PO status = closed where remaining_quantity <= 0
UPDATE purchase_orders SET status = 'closed', receiving_status = 'closed', updated_at = now()
WHERE (deleted IS NOT TRUE) AND COALESCE(remaining_quantity, 0) <= 0 AND COALESCE(ordered_quantity, 0) > 0;

-- 5. Set purchasing_invoices status = posted, payment_status = paid where fully paid
UPDATE purchasing_invoices SET status = 'posted', payment_status = 'paid', updated_at = now()
WHERE (deleted IS NOT TRUE) AND COALESCE(paid_amount, 0) >= COALESCE(grand_total, total_amount, 0) AND COALESCE(grand_total, total_amount, 0) > 0;
