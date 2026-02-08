-- ============================================================================
-- 03_item_transaction_flow.sql
-- SAP EKBE-STYLE ITEM TRANSACTION FLOW
-- ============================================================================
-- For each PR item: pr_qty, po_qty, grn_qty, pur_qty,
-- remaining_pr, remaining_po, remaining_grn,
-- Status: Pending | Ordered | Partial Received | Fully Received | Invoiced
--
-- po_qty = SUM(pr_po_linkage.converted_quantity)
-- grn_qty = SUM(grn_inspection_items.received_quantity)
-- pur_qty = SUM(purchasing_invoice_items.quantity)
-- ============================================================================

DROP VIEW IF EXISTS v_item_transaction_flow CASCADE;

CREATE OR REPLACE VIEW v_item_transaction_flow AS
WITH
pr_items AS (
    SELECT
        pri.id AS pr_item_id,
        pri.pr_id,
        pr.pr_number,
        pri.item_number AS pr_pos,
        pri.item_id,
        pri.item_name,
        pri.item_code,
        COALESCE(pri.quantity, 0) AS pr_qty,
        pri.unit,
        pri.estimated_price AS pr_price
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted = FALSE OR pr.deleted IS NULL)
    WHERE (pri.deleted = FALSE OR pri.deleted IS NULL)
),
po_quantities AS (
    SELECT
        ppl.pr_item_id,
        SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
        STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers
    FROM pr_po_linkage ppl
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
grn_quantities AS (
    SELECT
        ppl.pr_item_id,
        SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
        STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN grn_inspections gi ON gi.purchase_order_id = ppl.po_id AND gi.deleted = FALSE
    JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
        AND (gii.item_id = pri.item_id OR gii.po_item_id = poi.id)
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
pur_quantities AS (
    SELECT
        ppl.pr_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoices pi ON pi.deleted = FALSE
        AND (pi.purchase_order_id = ppl.po_id OR pi.grn_id IN (
            SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id
        ))
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id
        AND (pii.item_id = pri.item_id OR pii.item_name = pri.item_name)
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
)
SELECT
    p.pr_item_id,
    p.pr_id,
    p.pr_number,
    p.pr_pos,
    p.item_id,
    p.item_name,
    p.item_code,
    p.unit,
    p.pr_price,
    p.pr_qty,
    COALESCE(po.po_qty, 0) AS po_qty,
    COALESCE(grn.grn_qty, 0) AS grn_qty,
    COALESCE(pur.pur_qty, 0) AS pur_qty,
    GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
    CASE
        WHEN COALESCE(po.po_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'Ordered'
        WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'Partial Received'
        WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'Fully Received'
        WHEN COALESCE(pur.pur_qty, 0) >= COALESCE(grn.grn_qty, 0) THEN 'Invoiced'
        ELSE 'Partial Received'
    END AS status,
    COALESCE(po.po_numbers, '') AS po_numbers,
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(pur.pur_numbers, '') AS pur_numbers
FROM pr_items p
LEFT JOIN po_quantities po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_quantities grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_quantities pur ON pur.pr_item_id = p.pr_item_id;

COMMENT ON VIEW v_item_transaction_flow IS 'SAP EKBE-style item flow: pr/po/grn/pur qty and remaining; status Pending|Ordered|Partial Received|Fully Received|Invoiced.';

GRANT SELECT ON v_item_transaction_flow TO authenticated, anon;
