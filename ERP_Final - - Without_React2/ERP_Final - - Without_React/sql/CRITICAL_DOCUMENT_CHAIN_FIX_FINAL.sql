-- ============================================================
-- CRITICAL: DOCUMENT CHAIN FIX — FINAL
-- Chain exists in DB but views not resolving. PR/PO/GRN/PUR show "Not Created".
-- ROOT: v_item_transaction_flow and DocumentFlow use pr_po_linkage ONLY.
--       When pr_po_linkage empty (or source_pr_id/pr_item_id not set), chain breaks.
-- FIX: 1) Backfill source_pr_id from pr_po_linkage + purchase_request_items.po_id
--      2) Backfill pr_item_id, po_item_id
--      3) INSERT pr_po_linkage from direct chain (source_pr_id + pr_item_id)
--      4) Recreate views using DIRECT chain primary, pr_po_linkage fallback
--      5) DocumentFlow.vue: resolve PR via source_pr_id first
-- ============================================================
-- RUN: Supabase Dashboard → SQL Editor → paste and run
-- ============================================================

-- ============ DIAGNOSTIC (run first, optional) ============
-- SELECT id, pr_number, created_at FROM purchase_requests WHERE deleted IS NOT TRUE ORDER BY created_at DESC LIMIT 10;
-- SELECT id, po_number, source_pr_id FROM purchase_orders WHERE deleted IS NOT TRUE ORDER BY created_at DESC LIMIT 15;
-- SELECT * FROM pr_po_linkage WHERE status = 'active' OR status IS NULL ORDER BY converted_at DESC LIMIT 20;

-- ============ STEP 1: Ensure columns exist ============
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

-- ============ STEP 2: Backfill source_pr_id (multiple paths) ============
-- Path A: From pr_po_linkage
UPDATE purchase_orders po
SET source_pr_id = sub.pr_id
FROM (
  SELECT DISTINCT ON (po_id) po_id, pr_id
  FROM pr_po_linkage
  WHERE (status = 'active' OR status IS NULL) AND pr_id IS NOT NULL
  ORDER BY po_id, converted_at ASC NULLS LAST
) sub
WHERE po.id = sub.po_id AND po.source_pr_id IS NULL;

-- Path B: From purchase_request_items.po_id (when conversion set po_id on PR items)
UPDATE purchase_orders po
SET source_pr_id = sub.pr_id
FROM (
  SELECT DISTINCT ON (po_id) po_id, pr_id
  FROM purchase_request_items
  WHERE po_id IS NOT NULL AND deleted IS NOT TRUE
  ORDER BY po_id, created_at ASC
) sub
WHERE po.id = sub.po_id AND po.source_pr_id IS NULL;

-- ============ STEP 3: Backfill purchase_order_items.pr_item_id ============
-- From pr_po_linkage
UPDATE purchase_order_items poi
SET pr_item_id = ppl.pr_item_id
FROM pr_po_linkage ppl
WHERE poi.purchase_order_id = ppl.po_id
  AND poi.pr_item_id IS NULL
  AND ppl.pr_item_id IS NOT NULL
  AND (ppl.status = 'active' OR ppl.status IS NULL);

-- From direct match: same PO + source_pr_id + pri.item_id = poi.item_id (use subquery to avoid poi ref in JOIN)
UPDATE purchase_order_items poi
SET pr_item_id = sub.pri_id
FROM (
  SELECT poi2.id AS poi_id, pri.id AS pri_id
  FROM purchase_order_items poi2
  JOIN purchase_orders po ON po.id = poi2.purchase_order_id AND po.source_pr_id IS NOT NULL
  JOIN purchase_request_items pri ON pri.pr_id = po.source_pr_id AND pri.item_id = poi2.item_id AND pri.deleted IS NOT TRUE
  WHERE poi2.pr_item_id IS NULL
) sub
WHERE poi.id = sub.poi_id;

-- ============ STEP 4: Backfill grn_inspection_items.po_item_id ============
UPDATE grn_inspection_items gii
SET po_item_id = sub.poi_id
FROM (
  SELECT gii2.id AS gii_id, poi.id AS poi_id
  FROM grn_inspection_items gii2
  JOIN grn_inspections gi ON gi.id = gii2.grn_inspection_id AND gi.deleted IS NOT TRUE
  JOIN purchase_orders po ON (po.id = gi.purchase_order_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(po.po_number) = TRIM(gi.purchase_order_number))) AND (po.deleted IS NOT TRUE)
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.item_id = gii2.item_id
  WHERE gii2.po_item_id IS NULL
) sub
WHERE gii.id = sub.gii_id;

-- ============ STEP 5: INSERT pr_po_linkage from direct chain (CRITICAL) ============
-- When source_pr_id + pr_item_id exist but pr_po_linkage has no row
INSERT INTO pr_po_linkage (pr_id, pr_number, pr_item_id, pr_item_number, po_id, po_number, pr_quantity, converted_quantity, remaining_quantity, unit, conversion_type, status, converted_at)
SELECT pr.id, pr.pr_number, pri.id, COALESCE(pri.item_number, 10), po.id, po.po_number,
       COALESCE(pri.quantity, 0), COALESCE(poi.quantity, 0), 0,
       COALESCE(pri.unit, 'EA'), 'full', 'active', COALESCE(po.created_at, NOW())
FROM purchase_orders po
JOIN purchase_requests pr ON pr.id = po.source_pr_id AND (pr.deleted IS NOT TRUE)
JOIN purchase_request_items pri ON pri.pr_id = pr.id AND pri.deleted IS NOT TRUE
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
WHERE NOT EXISTS (
  SELECT 1 FROM pr_po_linkage ppl
  WHERE ppl.pr_id = pr.id AND ppl.po_id = po.id AND ppl.pr_item_id = pri.id
    AND (ppl.status = 'active' OR ppl.status IS NULL)
);

-- ============ STEP 6: Delete WRONG pr_po_linkage ============
DELETE FROM pr_po_linkage ppl
WHERE EXISTS (
  SELECT 1 FROM purchase_orders po
  WHERE po.id = ppl.po_id AND po.source_pr_id IS NOT NULL AND po.source_pr_id != ppl.pr_id
);

-- ============ STEP 7: Recreate v_item_transaction_flow — DIRECT CHAIN PRIMARY ============
-- Use BOTH: (1) pr_po_linkage (2) DIRECT chain via source_pr_id + pr_item_id
-- UNION to cover all cases. NO item_id anywhere.
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
-- po_quantities: DIRECT chain primary (source_pr_id + pr_item_id), pr_po_linkage fallback for legacy
po_from_direct AS (
  SELECT pri.id AS pr_item_id, SUM(COALESCE(poi.quantity, 0)) AS po_qty,
         STRING_AGG(DISTINCT po.po_number, ', ' ORDER BY po.po_number) AS po_numbers
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  JOIN purchase_orders po ON po.source_pr_id = pr.id AND (po.deleted IS NOT TRUE)
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id
),
po_from_linkage AS (
  SELECT ppl.pr_item_id, SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
         STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers
  FROM pr_po_linkage ppl
  WHERE (ppl.status = 'active' OR ppl.status IS NULL) AND ppl.pr_item_id NOT IN (SELECT pr_item_id FROM po_from_direct)
  GROUP BY ppl.pr_item_id
),
po_quantities AS (
  SELECT pr_item_id, po_qty, po_numbers FROM po_from_direct
  UNION ALL
  SELECT pr_item_id, po_qty, po_numbers FROM po_from_linkage
),
-- grn_quantities: DIRECT chain primary, pr_po_linkage fallback for legacy
grn_from_direct AS (
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
grn_from_linkage AS (
  SELECT ppl.pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
         STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
  FROM pr_po_linkage ppl
  JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id AND poi.pr_item_id = ppl.pr_item_id
  JOIN grn_inspections gi ON (gi.purchase_order_id = ppl.po_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = (SELECT TRIM(po_number) FROM purchase_orders WHERE id = ppl.po_id LIMIT 1))) AND (gi.deleted IS NOT TRUE)
  JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id AND gii.po_item_id = poi.id
  WHERE (ppl.status = 'active' OR ppl.status IS NULL) AND ppl.pr_item_id NOT IN (SELECT pr_item_id FROM grn_from_direct)
  GROUP BY ppl.pr_item_id
),
grn_quantities AS (
  SELECT pr_item_id, grn_qty, grn_numbers FROM grn_from_direct
  UNION ALL
  SELECT pr_item_id, grn_qty, grn_numbers FROM grn_from_linkage
),
-- pur_quantities: direct chain primary, pr_po_linkage fallback (pii uses item_id for now)
pur_from_direct AS (
  SELECT pri.id AS pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
         STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
  JOIN purchase_orders po ON po.source_pr_id = pr.id AND (po.deleted IS NOT TRUE)
  JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE) AND (pi.purchase_order_id = po.id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number))))
  JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND (pii.item_id = pri.item_id OR (pii.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(pii.item_name) = TRIM(pri.item_name)))
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id
),
pur_from_linkage AS (
  SELECT ppl.pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
         STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
  FROM pr_po_linkage ppl
  JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
  JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE) AND (pi.purchase_order_id = ppl.po_id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = (SELECT TRIM(po_number) FROM purchase_orders WHERE id = ppl.po_id LIMIT 1))))
  JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND (pii.item_id = pri.item_id OR (pii.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(pii.item_name) = TRIM(pri.item_name)))
  WHERE (ppl.status = 'active' OR ppl.status IS NULL) AND ppl.pr_item_id NOT IN (SELECT pr_item_id FROM pur_from_direct)
  GROUP BY ppl.pr_item_id
),
pur_quantities_merged AS (
  SELECT pr_item_id, pur_qty, pur_numbers FROM pur_from_direct
  UNION ALL
  SELECT pr_item_id, pur_qty, pur_numbers FROM pur_from_linkage
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
LEFT JOIN pur_quantities_merged pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE VIEW v_item_flow_recursive AS SELECT * FROM v_item_transaction_flow;

-- ============ STEP 8: Recreate v_item_flow_by_po — pr_number via source_pr_id FIRST ============
DROP VIEW IF EXISTS v_item_flow_by_po CASCADE;
CREATE OR REPLACE VIEW v_item_flow_by_po AS
SELECT
  poi.id AS po_item_id, po.id AS po_id, po.po_number,
  COALESCE(
    (SELECT pr.pr_number FROM purchase_requests pr WHERE pr.id = po.source_pr_id LIMIT 1),
    (SELECT pr.pr_number FROM pr_po_linkage ppl JOIN purchase_requests pr ON pr.id = ppl.pr_id
     WHERE ppl.po_id = po.id AND (ppl.status = 'active' OR ppl.status IS NULL) LIMIT 1)
  ) AS pr_number,
  poi.item_name, COALESCE(poi.quantity, 0) AS po_qty,
  GREATEST(COALESCE(poi.quantity_received, 0), COALESCE((
    SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted IS NOT TRUE
    WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
      AND (gii.po_item_id = poi.id)
  ), 0)) AS grn_qty,
  COALESCE((
    SELECT SUM(pii.quantity) FROM purchasing_invoice_items pii
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted IS NOT TRUE
    WHERE (pi.purchase_order_id = po.id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number))))
      AND (pii.item_id = poi.item_id OR (pii.item_name IS NOT NULL AND poi.item_name IS NOT NULL AND TRIM(pii.item_name) = TRIM(poi.item_name)))
  ), 0) AS pur_qty,
  GREATEST(0, COALESCE(poi.quantity, 0) - GREATEST(COALESCE(poi.quantity_received, 0), COALESCE((
    SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted IS NOT TRUE
    WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
      AND (gii.po_item_id = poi.id)
  ), 0))) AS remaining_to_receive,
  (SELECT STRING_AGG(DISTINCT gi.grn_number, ', ') FROM grn_inspections gi
   WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number))) AND gi.deleted IS NOT TRUE) AS grn_numbers,
  (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ') FROM purchasing_invoices pi2
   WHERE (pi2.purchase_order_id = po.id OR pi2.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number)))) AND pi2.deleted IS NOT TRUE) AS pur_numbers,
  (row_number() OVER (PARTITION BY po.id ORDER BY poi.id))::integer AS po_pos,
  CASE WHEN GREATEST(COALESCE(poi.quantity_received, 0), COALESCE((
    SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted IS NOT TRUE
    WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
      AND (gii.po_item_id = poi.id)
  ), 0)) >= COALESCE(poi.quantity, 0) THEN 'Fully Received' ELSE 'Partial Received' END AS item_status
FROM purchase_orders po
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
WHERE po.deleted IS NOT TRUE;

-- ============ STEP 9: Recreate v_item_flow_by_grn ============
DROP VIEW IF EXISTS v_item_flow_by_grn CASCADE;
CREATE OR REPLACE VIEW v_item_flow_by_grn AS
SELECT
  gii.id AS grn_item_id, gi.id AS grn_id, gi.grn_number, gi.purchase_order_number AS po_number,
  COALESCE(
    (SELECT pr.pr_number FROM purchase_orders po2 JOIN purchase_requests pr ON pr.id = po2.source_pr_id
     WHERE (po2.id = gi.purchase_order_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(po2.po_number) = TRIM(gi.purchase_order_number))) LIMIT 1),
    (SELECT pr.pr_number FROM pr_po_linkage ppl JOIN purchase_requests pr ON pr.id = ppl.pr_id
     WHERE (ppl.po_id = gi.purchase_order_id OR ppl.po_id IN (SELECT id FROM purchase_orders WHERE TRIM(po_number) = TRIM(gi.purchase_order_number)))
       AND (ppl.status = 'active' OR ppl.status IS NULL) LIMIT 1)
  ) AS pr_number,
  gii.item_name,
  COALESCE(gii.ordered_quantity, gii.received_quantity, 0) AS ordered_qty,
  COALESCE(gii.received_quantity, 0) AS received_qty,
  COALESCE((SELECT SUM(pii.quantity) FROM purchasing_invoice_items pii
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.grn_id = gi.id AND pi.deleted IS NOT TRUE
    WHERE (pii.item_id = gii.item_id OR (pii.item_name IS NOT NULL AND gii.item_name IS NOT NULL AND TRIM(pii.item_name) = TRIM(gii.item_name)))), 0) AS invoiced_qty,
  (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ') FROM purchasing_invoices pi2 WHERE pi2.grn_id = gi.id AND pi2.deleted IS NOT TRUE) AS pur_numbers,
  CASE WHEN COALESCE(gii.received_quantity, 0) >= COALESCE(gii.ordered_quantity, gii.received_quantity, 0) THEN 'Fully Received' ELSE 'Partial Received' END AS item_status
FROM grn_inspections gi
JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
WHERE gi.deleted IS NOT TRUE;

-- ============ GRANTS ============
GRANT SELECT ON v_item_transaction_flow TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;
GRANT SELECT ON v_item_flow_by_po TO authenticated, anon;
GRANT SELECT ON v_item_flow_by_grn TO authenticated, anon;

-- ============ DEBUG QUERIES (run after migration) ============
-- SELECT * FROM v_item_transaction_flow WHERE pr_number = 'PR-2026-00028';
-- SELECT po_item_id, po_id, po_number, pr_number, item_name, po_qty, grn_qty FROM v_item_flow_by_po ORDER BY po_id DESC LIMIT 5;
