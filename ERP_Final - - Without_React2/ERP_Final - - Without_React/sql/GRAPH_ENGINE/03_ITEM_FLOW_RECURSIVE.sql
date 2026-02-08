-- ============================================================================
-- 03_ITEM_FLOW_RECURSIVE.sql
-- SAP EKBE-STYLE ITEM TRANSACTION FLOW
-- 
-- Tracks item-level quantities across the procurement chain:
-- PR Qty → PO Qty (ordered) → GRN Qty (received) → PUR Qty (invoiced)
-- ============================================================================

-- Drop existing views
DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_item_flow_simple CASCADE;
DROP VIEW IF EXISTS v_item_flow_by_po CASCADE;
DROP VIEW IF EXISTS v_item_flow_by_grn CASCADE;

-- ============================================================================
-- VIEW 1: v_item_flow_recursive
-- Master item flow view - tracks quantities from PR through to PUR
-- ============================================================================
CREATE OR REPLACE VIEW v_item_flow_recursive AS
WITH 
-- Step 1: Get PR items with their basic info
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
        COALESCE(pri.estimated_price, 0) AS pr_price
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND pr.deleted = FALSE
),

-- Step 2: Aggregate PO quantities by PR item
po_aggregation AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(ppl.converted_quantity, 0)) AS ordered_qty,
        STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers,
        COUNT(DISTINCT ppl.po_id) AS po_count,
        ARRAY_AGG(DISTINCT ppl.po_id) AS po_ids
    FROM pr_po_linkage ppl
    WHERE ppl.pr_item_id IS NOT NULL
    GROUP BY ppl.pr_item_id
),

-- Step 3: Aggregate GRN quantities by PR item (via PO linkage)
grn_aggregation AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(gii.received_quantity, 0)) AS received_qty,
        STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers,
        COUNT(DISTINCT gi.id) AS grn_count
    FROM pr_po_linkage ppl
    -- Join to PO items that match the item
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id 
        AND (poi.item_id = pri.item_id OR poi.item_name = pri.item_name)
    -- Join to GRN items via PO item
    JOIN grn_inspection_items gii ON gii.po_item_id = poi.id
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    WHERE ppl.pr_item_id IS NOT NULL
    GROUP BY ppl.pr_item_id
),

-- Step 4: Aggregate PUR quantities by PR item (via GRN or PO)
pur_aggregation AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS invoiced_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers,
        COUNT(DISTINCT pi.id) AS pur_count
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    -- Join to purchasing invoice items that match
    JOIN purchasing_invoice_items pii ON pii.item_id = pri.item_id
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted = FALSE
    -- Ensure the invoice is linked to the same PO chain
    LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id AND gi.deleted = FALSE
    WHERE ppl.pr_item_id IS NOT NULL
      AND (pi.purchase_order_id = ppl.po_id OR gi.purchase_order_id = ppl.po_id)
    GROUP BY ppl.pr_item_id
)

-- Final output: Combine all aggregations
SELECT 
    p.pr_item_id,
    p.pr_id,
    p.pr_number,
    p.pr_pos,
    p.item_id,
    p.item_name,
    p.item_code,
    p.pr_qty,
    p.unit,
    p.pr_price,
    
    -- PO quantities
    COALESCE(po.ordered_qty, 0) AS po_qty,
    COALESCE(po.po_numbers, '') AS po_numbers,
    COALESCE(po.po_count, 0) AS po_count,
    
    -- GRN quantities  
    COALESCE(grn.received_qty, 0) AS grn_qty,
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(grn.grn_count, 0) AS grn_count,
    
    -- PUR quantities
    COALESCE(pur.invoiced_qty, 0) AS pur_qty,
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    COALESCE(pur.pur_count, 0) AS pur_count,
    
    -- Remaining/Open quantities
    GREATEST(0, p.pr_qty - COALESCE(po.ordered_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.ordered_qty, 0) - COALESCE(grn.received_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.received_qty, 0) - COALESCE(pur.invoiced_qty, 0)) AS remaining_grn,
    
    -- Calculated status
    CASE
        WHEN COALESCE(po.ordered_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(po.ordered_qty, 0) > 0 AND COALESCE(grn.received_qty, 0) = 0 THEN 'Ordered'
        WHEN COALESCE(grn.received_qty, 0) > 0 AND COALESCE(grn.received_qty, 0) < COALESCE(po.ordered_qty, 0) THEN 'Partial Received'
        WHEN COALESCE(grn.received_qty, 0) >= COALESCE(po.ordered_qty, 0) AND COALESCE(pur.invoiced_qty, 0) = 0 THEN 'Fully Received'
        WHEN COALESCE(pur.invoiced_qty, 0) > 0 AND COALESCE(pur.invoiced_qty, 0) < COALESCE(grn.received_qty, 0) THEN 'Partial Invoiced'
        WHEN COALESCE(pur.invoiced_qty, 0) >= COALESCE(grn.received_qty, 0) AND COALESCE(grn.received_qty, 0) > 0 THEN 'Invoiced'
        ELSE 'Processing'
    END AS chain_status,
    
    -- Progress percentages
    CASE WHEN p.pr_qty > 0 THEN ROUND((COALESCE(po.ordered_qty, 0) / p.pr_qty * 100)::NUMERIC, 1) ELSE 0 END AS order_progress,
    CASE WHEN COALESCE(po.ordered_qty, 0) > 0 THEN ROUND((COALESCE(grn.received_qty, 0) / po.ordered_qty * 100)::NUMERIC, 1) ELSE 0 END AS receive_progress,
    CASE WHEN COALESCE(grn.received_qty, 0) > 0 THEN ROUND((COALESCE(pur.invoiced_qty, 0) / grn.received_qty * 100)::NUMERIC, 1) ELSE 0 END AS invoice_progress
    
FROM pr_items p
LEFT JOIN po_aggregation po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_aggregation grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_aggregation pur ON pur.pr_item_id = p.pr_item_id;

-- ============================================================================
-- VIEW 2: v_item_flow_simple
-- Simplified item flow view for quick lookups
-- ============================================================================
CREATE OR REPLACE VIEW v_item_flow_simple AS
SELECT 
    pr_item_id,
    pr_id,
    pr_number,
    pr_pos,
    item_name,
    pr_qty,
    po_qty,
    grn_qty,
    pur_qty,
    remaining_po,
    chain_status
FROM v_item_flow_recursive;

-- ============================================================================
-- VIEW 3: v_item_flow_by_po
-- Item flow view anchored on PO items
-- ============================================================================
CREATE OR REPLACE VIEW v_item_flow_by_po AS
WITH po_items AS (
    SELECT 
        poi.id AS po_item_id,
        poi.purchase_order_id AS po_id,
        po.po_number,
        1 AS po_pos,  -- purchase_order_items does not have item_number column
        poi.item_id,
        poi.item_name,
        COALESCE(poi.quantity, 0) AS po_qty,
        poi.unit,
        COALESCE(poi.unit_price, 0) AS po_price,
        COALESCE(poi.received_quantity, 0) AS po_received_qty
    FROM purchase_order_items poi
    JOIN purchase_orders po ON po.id = poi.purchase_order_id AND po.deleted = FALSE
),
grn_agg AS (
    SELECT 
        gii.po_item_id,
        SUM(COALESCE(gii.received_quantity, 0)) AS received_qty,
        STRING_AGG(DISTINCT gi.grn_number, ', ') AS grn_numbers
    FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    GROUP BY gii.po_item_id
),
pur_agg AS (
    SELECT 
        poi.id AS po_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS invoiced_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ') AS pur_numbers
    FROM purchase_order_items poi
    JOIN purchasing_invoice_items pii ON pii.item_id = poi.item_id
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted = FALSE
    LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
    WHERE pi.purchase_order_id = poi.purchase_order_id OR gi.purchase_order_id = poi.purchase_order_id
    GROUP BY poi.id
)
SELECT 
    p.po_item_id,
    p.po_id,
    p.po_number,
    p.po_pos,
    p.item_id,
    p.item_name,
    p.po_qty,
    COALESCE(grn.received_qty, 0) AS grn_qty,
    COALESCE(pur.invoiced_qty, 0) AS pur_qty,
    GREATEST(0, p.po_qty - COALESCE(grn.received_qty, 0)) AS remaining_to_receive,
    GREATEST(0, COALESCE(grn.received_qty, 0) - COALESCE(pur.invoiced_qty, 0)) AS remaining_to_invoice,
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    CASE
        WHEN COALESCE(grn.received_qty, 0) = 0 THEN 'Not Received'
        WHEN COALESCE(grn.received_qty, 0) < p.po_qty THEN 'Partial Received'
        WHEN COALESCE(pur.invoiced_qty, 0) = 0 THEN 'Fully Received'
        WHEN COALESCE(pur.invoiced_qty, 0) < COALESCE(grn.received_qty, 0) THEN 'Partial Invoiced'
        ELSE 'Invoiced'
    END AS item_status
FROM po_items p
LEFT JOIN grn_agg grn ON grn.po_item_id = p.po_item_id
LEFT JOIN pur_agg pur ON pur.po_item_id = p.po_item_id;

-- ============================================================================
-- VIEW 4: v_item_flow_by_grn
-- Item flow view anchored on GRN items
-- ============================================================================
CREATE OR REPLACE VIEW v_item_flow_by_grn AS
WITH grn_items AS (
    SELECT 
        gii.id AS grn_item_id,
        gii.grn_inspection_id AS grn_id,
        gi.grn_number,
        gi.purchase_order_id AS po_id,
        po.po_number,
        gii.po_item_id,
        gii.item_id,
        gii.item_name,
        COALESCE(gii.received_quantity, 0) AS received_qty,
        gii.unit,
        COALESCE(poi.quantity, 0) AS ordered_qty
    FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    LEFT JOIN purchase_orders po ON po.id = gi.purchase_order_id
    LEFT JOIN purchase_order_items poi ON poi.id = gii.po_item_id
),
pur_agg AS (
    SELECT 
        gii.id AS grn_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS invoiced_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ') AS pur_numbers
    FROM grn_inspection_items gii
    JOIN purchasing_invoices pi ON pi.grn_id = gii.grn_inspection_id AND pi.deleted = FALSE
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND pii.item_id = gii.item_id
    GROUP BY gii.id
)
SELECT 
    g.grn_item_id,
    g.grn_id,
    g.grn_number,
    g.po_id,
    g.po_number,
    g.item_id,
    g.item_name,
    g.ordered_qty,
    g.received_qty,
    COALESCE(pur.invoiced_qty, 0) AS invoiced_qty,
    GREATEST(0, g.received_qty - COALESCE(pur.invoiced_qty, 0)) AS remaining_to_invoice,
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    CASE
        WHEN COALESCE(pur.invoiced_qty, 0) = 0 THEN 'Not Invoiced'
        WHEN COALESCE(pur.invoiced_qty, 0) < g.received_qty THEN 'Partial Invoiced'
        ELSE 'Invoiced'
    END AS item_status
FROM grn_items g
LEFT JOIN pur_agg pur ON pur.grn_item_id = g.grn_item_id;

-- ============================================================================
-- FUNCTION: fn_get_item_flow
-- Get item flow for a specific PR
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (
    pr_item_id UUID,
    pr_pos INT,
    item_name TEXT,
    pr_qty NUMERIC,
    po_qty NUMERIC,
    grn_qty NUMERIC,
    pur_qty NUMERIC,
    remaining_po NUMERIC,
    chain_status TEXT,
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
        v.pr_qty,
        v.po_qty,
        v.grn_qty,
        v.pur_qty,
        v.remaining_po,
        v.chain_status,
        v.po_numbers,
        v.grn_numbers,
        v.pur_numbers
    FROM v_item_flow_recursive v
    WHERE v.pr_id = p_pr_id
    ORDER BY v.pr_pos;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;
GRANT SELECT ON v_item_flow_simple TO authenticated, anon;
GRANT SELECT ON v_item_flow_by_po TO authenticated, anon;
GRANT SELECT ON v_item_flow_by_grn TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON VIEW v_item_flow_recursive IS 'SAP EKBE-style item transaction flow. Tracks PR→PO→GRN→PUR quantities.';
COMMENT ON VIEW v_item_flow_simple IS 'Simplified item flow for quick lookups';
COMMENT ON VIEW v_item_flow_by_po IS 'Item flow anchored on PO items';
COMMENT ON VIEW v_item_flow_by_grn IS 'Item flow anchored on GRN items';
COMMENT ON FUNCTION fn_get_item_flow IS 'Get item flow for a specific PR';
