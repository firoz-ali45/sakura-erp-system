-- ============================================================
-- GRN BATCH + PR FLOW — ROOT FIX (ALL 5 PROBLEMS)
-- PROBLEM 1: GRN batches not showing — load from inventory_batches + grn_batches
-- PROBLEM 2: QC tab locked — (frontend fix)
-- PROBLEM 3: PR item flow ZERO — v_item_transaction_flow STRICT chain only
-- PROBLEM 4: Batch sequence 001 — fn per GRN+item using COUNT
-- PROBLEM 5: GRN batch number empty — sync grn_batches via trigger
-- ============================================================
-- RUN IN SUPABASE SQL EDITOR
-- ============================================================

-- ============ PROBLEM 4: BATCH SEQUENCE — per (grn_id, item_id) incremental ============
-- Sequence = COUNT(*) + 1 from inventory_batches. Atomic with advisory lock.

CREATE OR REPLACE FUNCTION fn_generate_batch_number_from_grn(p_grn_id uuid, p_item_id uuid DEFAULT NULL, p_expiry_date date DEFAULT NULL)
RETURNS text AS $$
DECLARE
  v_grn_number text;
  v_seq        integer;
  v_key_id     uuid;
  v_expiry_str text;
BEGIN
  IF p_grn_id IS NULL THEN
    RETURN 'BATCH-UNKNOWN-' || to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD') || '-' || lpad((floor(random() * 1000))::text, 3, '0');
  END IF;

  v_key_id := COALESCE(p_item_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_expiry_str := to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD');

  SELECT COALESCE(NULLIF(TRIM(gi.grn_number), ''), 'GRN')
    INTO v_grn_number
  FROM grn_inspections gi
  WHERE gi.id = p_grn_id;
  v_grn_number := regexp_replace(COALESCE(v_grn_number, 'GRN'), '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  -- Atomic: advisory lock per (grn_id, item_id) then COUNT+1
  PERFORM pg_advisory_xact_lock(hashtext(p_grn_id::text || '-' || v_key_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM inventory_batches
  WHERE received_from_grn_id = p_grn_id AND item_id = v_key_id;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger: BEFORE INSERT on inventory_batches
CREATE OR REPLACE FUNCTION trg_set_batch_number_from_grn()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '' THEN
    NEW.batch_number := fn_generate_batch_number_from_grn(NEW.received_from_grn_id, NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;
CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();


-- ============ PROBLEM 5 + 1: SYNC grn_batches + unified view for GRN screen ============
-- After inventory_batches insert: update grn_batches with batch_number and batch_id

CREATE OR REPLACE FUNCTION trg_sync_grn_batches_after_inv_batch()
RETURNS trigger AS $$
BEGIN
  UPDATE grn_batches
  SET batch_number = NEW.batch_number,
      batch_id = NEW.id::text,
      updated_at = NOW()
  WHERE grn_id = NEW.received_from_grn_id
    AND item_id = NEW.item_id
    AND (expiry_date::date = NEW.expiry_date::date OR (expiry_date IS NULL AND NEW.expiry_date IS NULL));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_grn_batches_after_inv_batch ON inventory_batches;
CREATE TRIGGER trg_sync_grn_batches_after_inv_batch
  AFTER INSERT ON inventory_batches
  FOR EACH ROW
  WHEN (NEW.received_from_grn_id IS NOT NULL)
  EXECUTE FUNCTION trg_sync_grn_batches_after_inv_batch();


-- ============ PROBLEM 1: v_grn_all_batches — UNION grn_batches + orphan inventory_batches ============
-- GRN screen loads from this. Shows all batches for a GRN (grn_batches + inventory_batches without grn_batch row).

DROP VIEW IF EXISTS v_grn_all_batches CASCADE;
DROP VIEW IF EXISTS v_grn_batches_with_batch_number CASCADE;

CREATE OR REPLACE VIEW v_grn_batches_with_batch_number AS
SELECT
  gb.id,
  gb.grn_id,
  gb.item_id,
  gb.batch_id,
  COALESCE(ib.batch_number, gb.batch_number) AS batch_number,
  gb.expiry_date,
  gb.quantity,
  gb.quantity AS batch_quantity,
  NULL::text AS storage_location,
  NULL::text AS vendor_batch_number,
  COALESCE(ib.qc_status, gb.qc_data->>'qcStatus', gb.qc_data->>'qc_status') AS qc_status,
  gb.qc_data,
  gb.created_at,
  gb.created_by
FROM grn_batches gb
LEFT JOIN inventory_batches ib ON (gb.batch_id IS NOT NULL AND ib.id::text = gb.batch_id)
   OR (ib.received_from_grn_id = gb.grn_id AND ib.item_id = gb.item_id AND (ib.expiry_date::date = gb.expiry_date::date OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)));

CREATE OR REPLACE VIEW v_grn_all_batches AS
SELECT * FROM v_grn_batches_with_batch_number
UNION ALL
SELECT
  ib.id,
  ib.received_from_grn_id AS grn_id,
  ib.item_id,
  ib.id::text AS batch_id,
  ib.batch_number,
  ib.expiry_date,
  NULL::numeric AS quantity,
  NULL::numeric AS batch_quantity,
  NULL::text AS storage_location,
  ib.supplier_lot_number AS vendor_batch_number,
  ib.qc_status,
  NULL::jsonb AS qc_data,
  ib.created_at,
  NULL::uuid AS created_by
FROM inventory_batches ib
WHERE ib.received_from_grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM grn_batches gb
    WHERE gb.grn_id = ib.received_from_grn_id
      AND gb.item_id = ib.item_id
      AND (gb.expiry_date::date = ib.expiry_date::date OR (gb.expiry_date IS NULL AND ib.expiry_date IS NULL))
  );

GRANT SELECT ON v_grn_batches_with_batch_number TO authenticated, anon;
GRANT SELECT ON v_grn_all_batches TO authenticated, anon;


-- ============ PROBLEM 3: v_item_transaction_flow — STRICT chain, NO item_id fallback ============
-- Add po_item_id to purchasing_invoice_items if missing (for strict PUR chain)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchasing_invoice_items' AND column_name = 'po_item_id') THEN
    ALTER TABLE purchasing_invoice_items ADD COLUMN po_item_id uuid REFERENCES purchase_order_items(id);
  END IF;
END $$;

-- Backfill po_item_id on purchasing_invoice_items from grn_inspection_items
UPDATE purchasing_invoice_items pii
SET po_item_id = sub.po_item_id
FROM (
  SELECT pii2.id AS pii_id, gii.po_item_id
  FROM purchasing_invoice_items pii2
  JOIN purchasing_invoices pi ON pi.id = pii2.purchasing_invoice_id AND pi.deleted IS NOT TRUE AND pi.grn_id IS NOT NULL
  JOIN grn_inspection_items gii ON gii.grn_inspection_id = pi.grn_id AND gii.item_id = pii2.item_id
  WHERE pii2.po_item_id IS NULL AND gii.po_item_id IS NOT NULL
) sub
WHERE pii.id = sub.pii_id;

DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_item_transaction_flow CASCADE;

CREATE OR REPLACE VIEW v_item_transaction_flow AS
WITH
pr_items AS (
  SELECT pri.id AS pr_item_id, pri.pr_id, pr.pr_number, pri.item_number AS pr_pos,
         pri.item_id, pri.item_name, pri.item_code, COALESCE(pri.quantity, 0) AS pr_qty, pri.unit, pri.estimated_price AS pr_price
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  WHERE (pri.deleted IS NOT TRUE)
),
po_quantities AS (
  SELECT pri.id AS pr_item_id, SUM(COALESCE(poi.quantity, 0)) AS po_qty,
         STRING_AGG(DISTINCT po.po_number, ', ' ORDER BY po.po_number) AS po_numbers
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  JOIN purchase_orders po ON po.source_pr_id = pr.id AND (po.deleted IS NOT TRUE)
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id
),
grn_quantities AS (
  SELECT pri.id AS pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
         STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  JOIN purchase_orders po ON po.source_pr_id = pr.id AND (po.deleted IS NOT TRUE)
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
  JOIN grn_inspections gi ON (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number))) AND (gi.deleted IS NOT TRUE)
  JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id AND gii.po_item_id = poi.id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id
),
-- PUR: STRICT chain via pii.po_item_id -> poi -> pri (NO item_id)
pur_quantities AS (
  SELECT pri.id AS pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
         STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  JOIN purchase_orders po ON po.source_pr_id = pr.id AND (po.deleted IS NOT TRUE)
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
  JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE) AND (pi.purchase_order_id = po.id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number))))
  JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND pii.po_item_id = poi.id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id
)
SELECT p.pr_item_id, p.pr_id, p.pr_number, p.pr_pos, p.item_id, p.item_name, p.item_code, p.unit, p.pr_price,
       p.pr_qty, COALESCE(po.po_qty, 0) AS po_qty, COALESCE(grn.grn_qty, 0) AS grn_qty, COALESCE(pur.pur_qty, 0) AS pur_qty,
       GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
       GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
       GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
       CASE WHEN COALESCE(po.po_qty, 0) = 0 THEN 'Pending'
            WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'Ordered'
            WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'Partial Received'
            WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'Fully Received'
            ELSE 'Invoiced' END AS chain_status,
       COALESCE(NULLIF(TRIM(po.po_numbers), ''), '') AS po_numbers,
       COALESCE(NULLIF(TRIM(grn.grn_numbers), ''), '') AS grn_numbers,
       COALESCE(NULLIF(TRIM(pur.pur_numbers), ''), '') AS pur_numbers
FROM pr_items p
LEFT JOIN po_quantities po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_quantities grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_quantities pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE VIEW v_item_flow_recursive AS SELECT * FROM v_item_transaction_flow;

GRANT SELECT ON v_item_transaction_flow TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;

-- ============================================================
-- NOTE: Run CRITICAL_DOCUMENT_CHAIN_FIX_FINAL.sql first to backfill source_pr_id, pr_item_id, po_item_id
-- ============================================================
