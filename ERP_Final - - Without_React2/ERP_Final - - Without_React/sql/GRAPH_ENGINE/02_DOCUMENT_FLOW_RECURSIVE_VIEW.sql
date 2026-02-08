-- ============================================================================
-- 02_DOCUMENT_FLOW_RECURSIVE_VIEW.sql
-- DOCUMENT FLOW VIEWS - Flattened recursive results for frontend
-- ============================================================================

-- Drop existing views
DROP VIEW IF EXISTS v_document_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_pr_complete_chain CASCADE;
DROP VIEW IF EXISTS v_po_complete_chain CASCADE;
DROP VIEW IF EXISTS v_grn_complete_chain CASCADE;
DROP VIEW IF EXISTS v_pur_complete_chain CASCADE;
DROP VIEW IF EXISTS v_document_flow_full_chain CASCADE;

-- ============================================================================
-- VIEW 1: v_document_flow_recursive
-- Unified view for all documents - join with any starting point
-- ============================================================================
CREATE OR REPLACE VIEW v_document_flow_recursive AS

-- PR-based chains
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    pr.requester_name,
    pr.department,
    pr.created_at AS pr_date,
    COALESCE(pr.estimated_total_value, 0) AS pr_total,
    
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.supplier_name,
    po.order_date AS po_date,
    COALESCE(po.total_amount, 0) AS po_total,
    
    gi.id AS grn_id,
    gi.grn_number,
    gi.status AS grn_status,
    gi.received_by,
    gi.grn_date,
    gi.total_received_quantity AS grn_total_qty,
    
    pi.id AS pur_id,
    pi.purchasing_number AS pur_number,
    pi.status AS pur_status,
    pi.payment_status,
    COALESCE(pi.invoice_date, pi.created_at) AS pur_date,
    COALESCE(pi.grand_total, 0) AS pur_total,
    
    -- Chain status
    CASE 
        WHEN pi.id IS NOT NULL AND pi.status = 'posted' THEN 'invoiced'
        WHEN pi.id IS NOT NULL THEN 'invoice_created'
        WHEN gi.id IS NOT NULL AND gi.status = 'approved' THEN 'received'
        WHEN gi.id IS NOT NULL THEN 'receiving'
        WHEN po.id IS NOT NULL AND po.status = 'approved' THEN 'ordered'
        WHEN po.id IS NOT NULL THEN 'order_pending'
        WHEN pr.status = 'approved' THEN 'approved'
        ELSE 'requested'
    END AS chain_status,
    
    'PR' AS origin_type

FROM purchase_requests pr
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id
LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = po.id AND gi.deleted = FALSE
LEFT JOIN purchasing_invoices pi ON (pi.grn_id = gi.id OR (pi.purchase_order_id = po.id AND gi.id IS NULL)) AND pi.deleted = FALSE
WHERE pr.deleted = FALSE

UNION ALL

-- PO-based chains (for POs without PR linkage)
SELECT 
    NULL AS pr_id,
    NULL AS pr_number,
    NULL AS pr_status,
    NULL AS requester_name,
    NULL AS department,
    NULL AS pr_date,
    0 AS pr_total,
    
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.supplier_name,
    po.order_date AS po_date,
    COALESCE(po.total_amount, 0) AS po_total,
    
    gi.id AS grn_id,
    gi.grn_number,
    gi.status AS grn_status,
    gi.received_by,
    gi.grn_date,
    gi.total_received_quantity AS grn_total_qty,
    
    pi.id AS pur_id,
    pi.purchasing_number AS pur_number,
    pi.status AS pur_status,
    pi.payment_status,
    COALESCE(pi.invoice_date, pi.created_at) AS pur_date,
    COALESCE(pi.grand_total, 0) AS pur_total,
    
    CASE 
        WHEN pi.id IS NOT NULL AND pi.status = 'posted' THEN 'invoiced'
        WHEN pi.id IS NOT NULL THEN 'invoice_created'
        WHEN gi.id IS NOT NULL AND gi.status = 'approved' THEN 'received'
        WHEN gi.id IS NOT NULL THEN 'receiving'
        WHEN po.status = 'approved' THEN 'ordered'
        ELSE 'order_pending'
    END AS chain_status,
    
    'PO' AS origin_type

FROM purchase_orders po
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = po.id AND gi.deleted = FALSE
LEFT JOIN purchasing_invoices pi ON (pi.grn_id = gi.id OR (pi.purchase_order_id = po.id AND gi.id IS NULL)) AND pi.deleted = FALSE
WHERE po.deleted = FALSE
  AND NOT EXISTS (
    SELECT 1 FROM pr_po_linkage ppl WHERE ppl.po_id = po.id
  );

-- ============================================================================
-- VIEW 2: v_pr_complete_chain
-- All documents linked to each PR
-- ============================================================================
CREATE OR REPLACE VIEW v_pr_complete_chain AS
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    pr.requester_name,
    pr.department,
    
    -- PO aggregation
    (SELECT COUNT(DISTINCT ppl2.po_id) FROM pr_po_linkage ppl2 WHERE ppl2.pr_id = pr.id) AS po_count,
    (SELECT STRING_AGG(DISTINCT po2.po_number, ', ' ORDER BY po2.po_number) 
     FROM pr_po_linkage ppl2 
     JOIN purchase_orders po2 ON po2.id = ppl2.po_id 
     WHERE ppl2.pr_id = pr.id AND po2.deleted = FALSE) AS po_numbers,
    
    -- GRN aggregation
    (SELECT COUNT(DISTINCT gi2.id) 
     FROM pr_po_linkage ppl2 
     JOIN grn_inspections gi2 ON gi2.purchase_order_id = ppl2.po_id 
     WHERE ppl2.pr_id = pr.id AND gi2.deleted = FALSE) AS grn_count,
    (SELECT STRING_AGG(DISTINCT gi2.grn_number, ', ' ORDER BY gi2.grn_number) 
     FROM pr_po_linkage ppl2 
     JOIN grn_inspections gi2 ON gi2.purchase_order_id = ppl2.po_id 
     WHERE ppl2.pr_id = pr.id AND gi2.deleted = FALSE) AS grn_numbers,
    
    -- PUR aggregation
    (SELECT COUNT(DISTINCT pi2.id) 
     FROM pr_po_linkage ppl2 
     LEFT JOIN grn_inspections gi2 ON gi2.purchase_order_id = ppl2.po_id
     LEFT JOIN purchasing_invoices pi2 ON (pi2.grn_id = gi2.id OR pi2.purchase_order_id = ppl2.po_id)
     WHERE ppl2.pr_id = pr.id AND pi2.deleted = FALSE) AS pur_count,
    (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ' ORDER BY pi2.purchasing_number) 
     FROM pr_po_linkage ppl2 
     LEFT JOIN grn_inspections gi2 ON gi2.purchase_order_id = ppl2.po_id
     LEFT JOIN purchasing_invoices pi2 ON (pi2.grn_id = gi2.id OR pi2.purchase_order_id = ppl2.po_id)
     WHERE ppl2.pr_id = pr.id AND pi2.deleted = FALSE) AS pur_numbers,
    
    pr.created_at
FROM purchase_requests pr
WHERE pr.deleted = FALSE;

-- ============================================================================
-- VIEW 3: v_po_complete_chain
-- All documents linked to each PO
-- ============================================================================
CREATE OR REPLACE VIEW v_po_complete_chain AS
SELECT 
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.supplier_name,
    po.order_date,
    
    -- PR linkage
    (SELECT STRING_AGG(DISTINCT pr2.pr_number, ', ' ORDER BY pr2.pr_number) 
     FROM pr_po_linkage ppl2 
     JOIN purchase_requests pr2 ON pr2.id = ppl2.pr_id 
     WHERE ppl2.po_id = po.id AND pr2.deleted = FALSE) AS pr_numbers,
    
    -- GRN aggregation
    (SELECT COUNT(DISTINCT gi2.id) FROM grn_inspections gi2 WHERE gi2.purchase_order_id = po.id AND gi2.deleted = FALSE) AS grn_count,
    (SELECT STRING_AGG(DISTINCT gi2.grn_number, ', ' ORDER BY gi2.grn_number) 
     FROM grn_inspections gi2 WHERE gi2.purchase_order_id = po.id AND gi2.deleted = FALSE) AS grn_numbers,
    
    -- PUR aggregation
    (SELECT COUNT(DISTINCT pi2.id) 
     FROM purchasing_invoices pi2 
     LEFT JOIN grn_inspections gi2 ON gi2.id = pi2.grn_id
     WHERE (pi2.purchase_order_id = po.id OR gi2.purchase_order_id = po.id) AND pi2.deleted = FALSE) AS pur_count,
    (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ' ORDER BY pi2.purchasing_number) 
     FROM purchasing_invoices pi2 
     LEFT JOIN grn_inspections gi2 ON gi2.id = pi2.grn_id
     WHERE (pi2.purchase_order_id = po.id OR gi2.purchase_order_id = po.id) AND pi2.deleted = FALSE) AS pur_numbers,
    
    po.total_amount,
    po.created_at
FROM purchase_orders po
WHERE po.deleted = FALSE;

-- ============================================================================
-- VIEW 4: v_grn_complete_chain
-- All documents linked to each GRN
-- ============================================================================
CREATE OR REPLACE VIEW v_grn_complete_chain AS
SELECT 
    gi.id AS grn_id,
    gi.grn_number,
    gi.status AS grn_status,
    gi.grn_date,
    gi.received_by,
    
    -- PO linkage
    po.id AS po_id,
    po.po_number,
    po.supplier_name,
    
    -- PR linkage (through PO)
    (SELECT STRING_AGG(DISTINCT pr2.pr_number, ', ' ORDER BY pr2.pr_number) 
     FROM pr_po_linkage ppl2 
     JOIN purchase_requests pr2 ON pr2.id = ppl2.pr_id 
     WHERE ppl2.po_id = gi.purchase_order_id AND pr2.deleted = FALSE) AS pr_numbers,
    
    -- PUR aggregation
    (SELECT COUNT(DISTINCT pi2.id) FROM purchasing_invoices pi2 WHERE pi2.grn_id = gi.id AND pi2.deleted = FALSE) AS pur_count,
    (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ' ORDER BY pi2.purchasing_number) 
     FROM purchasing_invoices pi2 WHERE pi2.grn_id = gi.id AND pi2.deleted = FALSE) AS pur_numbers,
    
    gi.total_received_quantity,
    gi.created_at
FROM grn_inspections gi
LEFT JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.deleted = FALSE;

-- ============================================================================
-- VIEW 5: v_pur_complete_chain
-- All documents linked to each PUR
-- ============================================================================
CREATE OR REPLACE VIEW v_pur_complete_chain AS
SELECT 
    pi.id AS pur_id,
    pi.purchasing_number AS pur_number,
    pi.status AS pur_status,
    pi.payment_status,
    pi.invoice_date,
    pi.grand_total,
    
    -- GRN linkage
    gi.id AS grn_id,
    gi.grn_number,
    
    -- PO linkage
    COALESCE(gi.purchase_order_id, pi.purchase_order_id) AS po_id,
    COALESCE(po_grn.po_number, po_direct.po_number) AS po_number,
    COALESCE(po_grn.supplier_name, po_direct.supplier_name) AS supplier_name,
    
    -- PR linkage (through PO)
    (SELECT STRING_AGG(DISTINCT pr2.pr_number, ', ' ORDER BY pr2.pr_number) 
     FROM pr_po_linkage ppl2 
     JOIN purchase_requests pr2 ON pr2.id = ppl2.pr_id 
     WHERE ppl2.po_id = COALESCE(gi.purchase_order_id, pi.purchase_order_id) 
       AND pr2.deleted = FALSE) AS pr_numbers,
    
    pi.created_at
FROM purchasing_invoices pi
LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id AND gi.deleted = FALSE
LEFT JOIN purchase_orders po_grn ON po_grn.id = gi.purchase_order_id AND po_grn.deleted = FALSE
LEFT JOIN purchase_orders po_direct ON po_direct.id = pi.purchase_order_id AND po_direct.deleted = FALSE
WHERE pi.deleted = FALSE;

-- ============================================================================
-- VIEW 6: v_document_flow_full_chain (edge list format)
-- For graph visualization
-- ============================================================================
CREATE OR REPLACE VIEW v_document_flow_full_chain AS

-- PR → PO edges
SELECT 
    'PR_TO_PO' AS edge_type,
    'PR' AS source_type,
    pr.id::TEXT AS source_id,
    pr.pr_number AS source_number,
    pr.status AS source_status,
    'PO' AS target_type,
    po.id::TEXT AS target_id,
    po.po_number AS target_number,
    po.status AS target_status,
    ppl.converted_at AS link_date
FROM pr_po_linkage ppl
JOIN purchase_requests pr ON pr.id = ppl.pr_id AND pr.deleted = FALSE
JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE

UNION ALL

-- PO → GRN edges
SELECT 
    'PO_TO_GRN' AS edge_type,
    'PO' AS source_type,
    po.id::TEXT AS source_id,
    po.po_number AS source_number,
    po.status AS source_status,
    'GRN' AS target_type,
    gi.id::TEXT AS target_id,
    gi.grn_number AS target_number,
    gi.status AS target_status,
    gi.created_at AS link_date
FROM grn_inspections gi
JOIN purchase_orders po ON po.id = gi.purchase_order_id AND po.deleted = FALSE
WHERE gi.deleted = FALSE

UNION ALL

-- GRN → PUR edges
SELECT 
    'GRN_TO_PUR' AS edge_type,
    'GRN' AS source_type,
    gi.id::TEXT AS source_id,
    gi.grn_number AS source_number,
    gi.status AS source_status,
    'PUR' AS target_type,
    pi.id::TEXT AS target_id,
    pi.purchasing_number AS target_number,
    pi.status AS target_status,
    pi.created_at AS link_date
FROM purchasing_invoices pi
JOIN grn_inspections gi ON gi.id = pi.grn_id AND gi.deleted = FALSE
WHERE pi.deleted = FALSE

UNION ALL

-- PO → PUR direct edges (when no GRN)
SELECT 
    'PO_TO_PUR' AS edge_type,
    'PO' AS source_type,
    po.id::TEXT AS source_id,
    po.po_number AS source_number,
    po.status AS source_status,
    'PUR' AS target_type,
    pi.id::TEXT AS target_id,
    pi.purchasing_number AS target_number,
    pi.status AS target_status,
    pi.created_at AS link_date
FROM purchasing_invoices pi
JOIN purchase_orders po ON po.id = pi.purchase_order_id AND po.deleted = FALSE
WHERE pi.deleted = FALSE AND pi.grn_id IS NULL;

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT SELECT ON v_document_flow_recursive TO authenticated, anon;
GRANT SELECT ON v_pr_complete_chain TO authenticated, anon;
GRANT SELECT ON v_po_complete_chain TO authenticated, anon;
GRANT SELECT ON v_grn_complete_chain TO authenticated, anon;
GRANT SELECT ON v_pur_complete_chain TO authenticated, anon;
GRANT SELECT ON v_document_flow_full_chain TO authenticated, anon;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON VIEW v_document_flow_recursive IS 'Unified document flow view - flattened chains from PR/PO origin';
COMMENT ON VIEW v_pr_complete_chain IS 'Complete chain summary for each PR';
COMMENT ON VIEW v_po_complete_chain IS 'Complete chain summary for each PO';
COMMENT ON VIEW v_grn_complete_chain IS 'Complete chain summary for each GRN';
COMMENT ON VIEW v_pur_complete_chain IS 'Complete chain summary for each PUR';
COMMENT ON VIEW v_document_flow_full_chain IS 'Edge list format for document graph visualization';
