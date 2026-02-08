-- ============================================================
-- DOCUMENT CHAIN BACKFILL — missing pr_po_linkage, pr_item_id, po_item_id
-- ROOT CAUSE: PR Convert sets source_pr_id but pr_po_linkage/pr_item_id not populated
-- Run in Supabase SQL Editor
-- ============================================================

-- STEP 1: Backfill purchase_order_items.pr_item_id (use subquery)
UPDATE purchase_order_items poi
SET pr_item_id = sub.pr_item_id
FROM (
  SELECT poi2.id AS poi_id, pri.id AS pr_item_id
  FROM purchase_order_items poi2
  JOIN purchase_orders po ON po.id = poi2.purchase_order_id AND po.source_pr_id IS NOT NULL AND po.deleted IS NOT TRUE
  JOIN purchase_request_items pri ON pri.pr_id = po.source_pr_id AND pri.item_id = poi2.item_id AND pri.deleted IS NOT TRUE
  WHERE poi2.pr_item_id IS NULL
) sub
WHERE poi.id = sub.poi_id;

-- STEP 2: Backfill grn_inspection_items.po_item_id
UPDATE grn_inspection_items gii
SET po_item_id = sub.poi_id
FROM (
  SELECT gii2.id AS gii_id, poi.id AS poi_id
  FROM grn_inspection_items gii2
  JOIN grn_inspections gi ON gi.id = gii2.grn_inspection_id AND gi.deleted IS NOT TRUE
  JOIN purchase_orders po ON (po.id = gi.purchase_order_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(po.po_number) = TRIM(gi.purchase_order_number))) AND po.deleted IS NOT TRUE
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.item_id = gii2.item_id
  WHERE gii2.po_item_id IS NULL
) sub
WHERE gii.id = sub.gii_id;

-- STEP 3: Insert pr_po_linkage for POs with source_pr_id but no linkage
INSERT INTO pr_po_linkage (pr_id, pr_number, pr_item_id, pr_item_number, po_id, po_number, pr_quantity, converted_quantity, remaining_quantity, unit, conversion_type, status, converted_at, created_at, updated_at)
SELECT 
  po.source_pr_id, pr.pr_number, pri.id, COALESCE(pri.item_number, 10),
  po.id, po.po_number, pri.quantity, poi.quantity,
  GREATEST(0, COALESCE(pri.quantity, 0) - COALESCE(poi.quantity, 0)),
  COALESCE(pri.unit, 'EA'), 'full', 'active',
  COALESCE(po.order_date, po.created_at), NOW(), NOW()
FROM purchase_orders po
JOIN purchase_requests pr ON pr.id = po.source_pr_id AND pr.deleted IS NOT TRUE
JOIN purchase_request_items pri ON pri.pr_id = po.source_pr_id AND pri.deleted IS NOT TRUE
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND poi.pr_item_id = pri.id
WHERE po.source_pr_id IS NOT NULL AND po.deleted IS NOT TRUE
  AND NOT EXISTS (SELECT 1 FROM pr_po_linkage ppl WHERE ppl.pr_id = po.source_pr_id AND ppl.po_id = po.id AND ppl.pr_item_id = pri.id);

-- STEP 4: Delete duplicate pr_po_linkage
DELETE FROM pr_po_linkage a USING pr_po_linkage b
WHERE a.id > b.id AND a.pr_id = b.pr_id AND a.pr_item_id = b.pr_item_id AND a.po_id = b.po_id;
