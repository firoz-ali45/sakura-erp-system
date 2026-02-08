-- ============================================================
-- AUDIT FIX 03: DOCUMENT FLOW - FIX ITEM_ID CROSS-LINKING
-- ROOT CAUSE: pr_po_linkage backfill links by item_id across ALL PRs/POs
--             causing PR-2026-00027 to show PO/GRN from OLD PR (PR-2026-000004)
-- FIX: pr_po_linkage must only link when PO was created FROM that PR
--      Use source_pr_id on purchase_orders to restrict linkage
-- ============================================================

-- STEP 1: Add source_pr_id to purchase_orders (which PR created this PO)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_orders' AND column_name = 'source_pr_id') THEN
    ALTER TABLE purchase_orders ADD COLUMN source_pr_id uuid REFERENCES purchase_requests(id);
    COMMENT ON COLUMN purchase_orders.source_pr_id IS 'PR from which this PO was converted. Used for document chain integrity.';
  END IF;
END $$;

-- STEP 2: Add po_item_id to grn_inspection_items (link GRN line to PO line)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_inspection_items' AND column_name = 'po_item_id') THEN
    ALTER TABLE grn_inspection_items ADD COLUMN po_item_id uuid REFERENCES purchase_order_items(id);
    CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_po_item_id ON grn_inspection_items(po_item_id);
    COMMENT ON COLUMN grn_inspection_items.po_item_id IS 'Links GRN line to specific PO line for document chain.';
  END IF;
END $$;

-- STEP 3: Add pr_item_id to purchase_order_items (link PO line to PR line)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_order_items' AND column_name = 'pr_item_id') THEN
    ALTER TABLE purchase_order_items ADD COLUMN pr_item_id uuid REFERENCES purchase_request_items(id);
    CREATE INDEX IF NOT EXISTS idx_purchase_order_items_pr_item_id ON purchase_order_items(pr_item_id);
    COMMENT ON COLUMN purchase_order_items.pr_item_id IS 'Links PO line to specific PR line for document chain.';
  END IF;
END $$;

-- STEP 4: Restrict pr_po_linkage - delete rows where pr_id != PO's source_pr_id (when source_pr_id is set)
-- This cleans up incorrect cross-links
DELETE FROM pr_po_linkage ppl
WHERE EXISTS (
  SELECT 1 FROM purchase_orders po
  WHERE po.id = ppl.po_id
    AND po.source_pr_id IS NOT NULL
    AND po.source_pr_id != ppl.pr_id
);

-- STEP 5: Recreate v_item_transaction_flow to use pr_item_id/po_item_id when available
-- and filter grn_quantities by po_item_id (document chain) not item_id
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
    -- FIX: Prefer po_item_id (document chain); fallback to item_id only when po_item_id not available
    SELECT ppl.pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
           STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
        AND (poi.pr_item_id = ppl.pr_item_id OR (poi.pr_item_id IS NULL AND poi.item_id = (SELECT item_id FROM purchase_request_items WHERE id = ppl.pr_item_id)))
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchase_orders po2 ON po2.id = ppl.po_id
    JOIN grn_inspections gi ON (gi.purchase_order_id = ppl.po_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po2.po_number)))
        AND (gi.deleted IS NOT TRUE)
    JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
        AND (
          (gii.po_item_id IS NOT NULL AND gii.po_item_id = poi.id)
          OR (gii.po_item_id IS NULL AND (gii.item_id = pri.item_id OR (gii.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(gii.item_name) = TRIM(pri.item_name))))
        )
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
pur_quantities AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
           STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE)
        AND (pi.purchase_order_id = ppl.po_id
             OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id
                              OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = (SELECT TRIM(po_number) FROM purchase_orders WHERE id = ppl.po_id LIMIT 1))))
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND (pii.item_id = pri.item_id OR pii.item_name = pri.item_name)
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
-- IMPORTANT: Convert PR to PO flow MUST:
-- 1. Set purchase_orders.source_pr_id = the PR being converted
-- 2. Set purchase_order_items.pr_item_id = the PR item being converted
-- 3. When creating GRN from PO, set grn_inspection_items.po_item_id = the PO item
-- 4. pr_po_linkage should be created during Convert PR to PO, not by item_id backfill
-- ============================================================
