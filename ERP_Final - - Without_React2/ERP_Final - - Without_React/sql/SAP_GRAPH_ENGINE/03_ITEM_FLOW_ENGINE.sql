-- ============================================================================
-- 03_ITEM_FLOW_ENGINE.sql
-- SAP EKBE-STYLE ITEM LEVEL FLOW TRACKING
-- Tracks quantities through the entire procurement chain
-- ============================================================================

DROP VIEW IF EXISTS v_sap_item_flow CASCADE;
DROP FUNCTION IF EXISTS fn_get_item_flow(UUID) CASCADE;

-- ============================================================================
-- VIEW: v_sap_item_flow
-- Per-item tracking through PR → PO → GRN → PUR
-- ============================================================================

CREATE OR REPLACE VIEW v_sap_item_flow AS
WITH 
-- PR Items base
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
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND pr.deleted = FALSE
    WHERE pri.deleted = FALSE OR pri.deleted IS NULL
),

-- PO quantities from pr_po_linkage
po_quantities AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
        STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers,
        ARRAY_AGG(DISTINCT ppl.po_id) AS po_ids
    FROM pr_po_linkage ppl
    WHERE ppl.status = 'active' OR ppl.status IS NULL
    GROUP BY ppl.pr_item_id
),

-- GRN quantities 
grn_quantities AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
        STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN grn_inspection_items gii ON gii.grn_inspection_id IN (
        SELECT id FROM grn_inspections 
        WHERE purchase_order_id = ppl.po_id AND deleted = FALSE
    ) AND (gii.item_id = pri.item_id OR gii.item_name = pri.item_name OR gii.po_item_id = poi.id)
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    WHERE ppl.status = 'active' OR ppl.status IS NULL
    GROUP BY ppl.pr_item_id
),

-- PUR quantities
pur_quantities AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoice_items pii ON pii.item_id = pri.item_id OR pii.item_name = pri.item_name
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id 
        AND pi.deleted = FALSE
        AND (pi.purchase_order_id = ppl.po_id OR pi.grn_id IN (
            SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id
        ))
    WHERE ppl.status = 'active' OR ppl.status IS NULL
    GROUP BY ppl.pr_item_id
)

-- Final view combining all
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
    
    -- Quantities
    p.pr_qty,
    COALESCE(po.po_qty, 0) AS po_qty,
    COALESCE(grn.grn_qty, 0) AS grn_qty,
    COALESCE(pur.pur_qty, 0) AS pur_qty,
    
    -- Remaining quantities
    GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
    
    -- Document references
    COALESCE(po.po_numbers, '') AS po_numbers,
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    
    -- Status determination (SAP EKBE logic)
    CASE
        WHEN COALESCE(po.po_qty, 0) = 0 THEN 'PENDING'
        WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'ORDERED'
        WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'PARTIAL_RECEIVED'
        WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'FULLY_RECEIVED'
        WHEN COALESCE(pur.pur_qty, 0) < COALESCE(grn.grn_qty, 0) THEN 'PARTIAL_INVOICED'
        ELSE 'INVOICED'
    END AS item_status

FROM pr_items p
LEFT JOIN po_quantities po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_quantities grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_quantities pur ON pur.pr_item_id = p.pr_item_id;

-- ============================================================================
-- FUNCTION: fn_get_item_flow
-- Returns item flow for a specific PR
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (
    pr_item_id UUID,
    pr_pos INT,
    item_name TEXT,
    item_code TEXT,
    unit TEXT,
    pr_qty NUMERIC,
    po_qty NUMERIC,
    grn_qty NUMERIC,
    pur_qty NUMERIC,
    remaining_pr NUMERIC,
    remaining_po NUMERIC,
    remaining_grn NUMERIC,
    item_status TEXT,
    po_numbers TEXT,
    grn_numbers TEXT,
    pur_numbers TEXT
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        v.pr_item_id,
        v.pr_pos,
        v.item_name,
        v.item_code,
        v.unit,
        v.pr_qty,
        v.po_qty,
        v.grn_qty,
        v.pur_qty,
        v.remaining_pr,
        v.remaining_po,
        v.remaining_grn,
        v.item_status,
        v.po_numbers,
        v.grn_numbers,
        v.pur_numbers
    FROM v_sap_item_flow v
    WHERE v.pr_id = p_pr_id
    ORDER BY v.pr_pos;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT SELECT ON v_sap_item_flow TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;
