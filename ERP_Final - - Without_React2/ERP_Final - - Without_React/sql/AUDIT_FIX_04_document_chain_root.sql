-- ============================================================
-- AUDIT FIX 04: ROOT DOCUMENT CHAIN FIX
-- PROBLEM: PR-2026-000028 converted to PO/GRN/PUR shows wrong PR (PR-2026-000004)
-- ROOT CAUSE: pr_po_linkage backfill (01_COMPLETE_DOCUMENT_FLOW_FIX STEP 0.6/0.7)
--             links by item_id across PRs — creates wrong cross-links
-- FIX: 1) Set source_pr_id for POs from earliest pr_po_linkage
--      2) Delete wrong pr_po_linkage (pr_id != po.source_pr_id)
--      3) v_item_transaction_flow: STRICT document chain, NO item_id fallback
-- ============================================================

-- STEP 1: Ensure columns exist (from AUDIT_FIX_03)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_orders' AND column_name = 'source_pr_id') THEN
    ALTER TABLE purchase_orders ADD COLUMN source_pr_id uuid REFERENCES purchase_requests(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_order_items' AND column_name = 'pr_item_id') THEN
    ALTER TABLE purchase_order_items ADD COLUMN pr_item_id uuid REFERENCES purchase_request_items(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_inspection_items' AND column_name = 'po_item_id') THEN
    ALTER TABLE grn_inspection_items ADD COLUMN po_item_id uuid REFERENCES purchase_order_items(id);
  END IF;
END $$;

-- STEP 1.5a: Backfill purchase_order_items.pr_item_id from pr_po_linkage
UPDATE purchase_order_items poi
SET pr_item_id = ppl.pr_item_id
FROM pr_po_linkage ppl
JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id AND pri.item_id = poi.item_id
WHERE poi.purchase_order_id = ppl.po_id
  AND poi.pr_item_id IS NULL
  AND (ppl.status = 'active' OR ppl.status IS NULL);

-- STEP 1.5b: Backfill grn_inspection_items.po_item_id from PO items (same PO + item_id)
UPDATE grn_inspection_items gii
SET po_item_id = poi.id
FROM grn_inspections gi
JOIN purchase_order_items poi ON poi.purchase_order_id = gi.purchase_order_id AND poi.item_id = gii.item_id
WHERE gii.grn_inspection_id = gi.id
  AND gii.po_item_id IS NULL
  AND gi.deleted IS NOT TRUE
  AND gi.purchase_order_id IS NOT NULL;

-- Also match by po_number when purchase_order_id is NULL on GRN
UPDATE grn_inspection_items gii
SET po_item_id = poi.id
FROM grn_inspections gi
JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(gi.purchase_order_number) AND (po.deleted IS NOT TRUE)
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.item_id = gii.item_id
WHERE gii.grn_inspection_id = gi.id
  AND gii.po_item_id IS NULL
  AND gi.purchase_order_id IS NULL
  AND gi.purchase_order_number IS NOT NULL
  AND gi.deleted IS NOT TRUE;

-- STEP 2: Set source_pr_id for POs where NULL — use earliest pr_po_linkage per PO
-- (Conversion inserts first; backfill inserts later — earliest = correct)
UPDATE purchase_orders po
SET source_pr_id = sub.pr_id
FROM (
  SELECT DISTINCT ON (po_id) po_id, pr_id
  FROM pr_po_linkage
  WHERE status = 'active' OR status IS NULL
  ORDER BY po_id, converted_at ASC NULLS LAST
) sub
WHERE po.id = sub.po_id
  AND po.source_pr_id IS NULL;

-- STEP 3: Delete WRONG pr_po_linkage — rows where pr_id != PO's source_pr_id
DELETE FROM pr_po_linkage ppl
WHERE EXISTS (
  SELECT 1 FROM purchase_orders po
  WHERE po.id = ppl.po_id
    AND po.source_pr_id IS NOT NULL
    AND po.source_pr_id != ppl.pr_id
);

-- STEP 4: Recreate v_item_transaction_flow — STRICT document chain, NO item_id fallback
-- Rule: Only use pr_item_id, po_item_id. If NULL, no cross-link.
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
    SELECT ppl.pr_item_id, SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
           STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers
    FROM pr_po_linkage ppl
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
grn_quantities AS (
    -- STRICT: Only gii.po_item_id = poi.id (document chain). NO item_id fallback.
    SELECT ppl.pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
           STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id AND poi.pr_item_id = ppl.pr_item_id
    JOIN purchase_orders po2 ON po2.id = ppl.po_id
    JOIN grn_inspections gi ON (gi.purchase_order_id = ppl.po_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po2.po_number)))
        AND (gi.deleted IS NOT TRUE)
    JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id AND gii.po_item_id = poi.id
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
pur_quantities AS (
    -- PUR: join via PO/GRN path. pii joins by item_id to pri — required until purchasing_invoice_items has po_item_id
    SELECT ppl.pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
           STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE)
        AND (pi.purchase_order_id = ppl.po_id
             OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id
                              OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = (SELECT TRIM(po_number) FROM purchase_orders WHERE id = ppl.po_id LIMIT 1))))
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND (pii.item_id = pri.item_id OR (pii.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(pii.item_name) = TRIM(pri.item_name)))
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
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
       COALESCE(po.po_numbers, '') AS po_numbers, COALESCE(grn.grn_numbers, '') AS grn_numbers, COALESCE(pur.pur_numbers, '') AS pur_numbers
FROM pr_items p
LEFT JOIN po_quantities po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_quantities grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_quantities pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE VIEW v_item_flow_recursive AS SELECT * FROM v_item_transaction_flow;

GRANT SELECT ON v_item_transaction_flow TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;

-- ============================================================
-- IMPORTANT: grn_quantities now requires:
-- - poi.pr_item_id = ppl.pr_item_id (no item_id fallback)
-- - gii.po_item_id = poi.id (document chain only)
-- If GRN was created without po_item_id, run backfill for grn_inspection_items
-- ============================================================
