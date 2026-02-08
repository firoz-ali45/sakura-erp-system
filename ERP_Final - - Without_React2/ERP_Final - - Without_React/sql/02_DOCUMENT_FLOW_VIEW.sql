-- ============================================================================
-- 02_DOCUMENT_FLOW_VIEW.sql
-- ENTERPRISE VIEW: Full Document Flow Chain
-- SAP VBFA (Sales Document Flow) Equivalent
-- ============================================================================

-- Drop existing views
DROP VIEW IF EXISTS v_document_flow_full_chain CASCADE;
DROP VIEW IF EXISTS v_pr_to_pur_chain CASCADE;

-- ============================================================================
-- VIEW 1: Complete PR → PO → GRN → PUR Chain
-- ============================================================================
CREATE OR REPLACE VIEW v_document_flow_full_chain AS

-- PR → PO Links
SELECT 
    'PR_TO_PO' AS flow_type,
    'PR' AS source_type,
    pr.id::TEXT AS source_id,
    pr.pr_number AS source_number,
    pr.status AS source_status,
    pr.created_at AS source_date,
    'PO' AS target_type,
    po.id::TEXT AS target_id,
    po.po_number AS target_number,
    po.status AS target_status,
    po.order_date AS target_date,
    ppl.converted_at AS link_date
FROM pr_po_linkage ppl
JOIN purchase_requests pr ON pr.id = ppl.pr_id
JOIN purchase_orders po ON po.id = ppl.po_id
WHERE ppl.status = 'active'
  AND pr.deleted = FALSE
  AND po.deleted = FALSE

UNION ALL

-- PO → GRN Links
SELECT 
    'PO_TO_GRN' AS flow_type,
    'PO' AS source_type,
    po.id::TEXT AS source_id,
    po.po_number AS source_number,
    po.status AS source_status,
    po.order_date AS source_date,
    'GRN' AS target_type,
    gi.id::TEXT AS target_id,
    gi.grn_number AS target_number,
    gi.status AS target_status,
    gi.grn_date AS target_date,
    gi.created_at AS link_date
FROM grn_inspections gi
JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.deleted = FALSE
  AND po.deleted = FALSE

UNION ALL

-- GRN → PUR Links
SELECT 
    'GRN_TO_PUR' AS flow_type,
    'GRN' AS source_type,
    gi.id::TEXT AS source_id,
    gi.grn_number AS source_number,
    gi.status AS source_status,
    gi.grn_date AS source_date,
    'PUR' AS target_type,
    pi.id::TEXT AS target_id,
    pi.purchasing_number AS target_number,
    pi.status AS target_status,
    pi.created_at AS target_date,
    pi.created_at AS link_date
FROM purchasing_invoices pi
JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE pi.deleted = FALSE
  AND gi.deleted = FALSE

UNION ALL

-- PO → PUR Direct Links (when no GRN)
SELECT 
    'PO_TO_PUR' AS flow_type,
    'PO' AS source_type,
    po.id::TEXT AS source_id,
    po.po_number AS source_number,
    po.status AS source_status,
    po.order_date AS source_date,
    'PUR' AS target_type,
    pi.id::TEXT AS target_id,
    pi.purchasing_number AS target_number,
    pi.status AS target_status,
    pi.created_at AS target_date,
    pi.created_at AS link_date
FROM purchasing_invoices pi
JOIN purchase_orders po ON po.id = pi.purchase_order_id
WHERE pi.deleted = FALSE
  AND po.deleted = FALSE
  AND pi.grn_id IS NULL;

-- ============================================================================
-- VIEW 2: Complete Chain Summary (PR to PUR)
-- ============================================================================
CREATE OR REPLACE VIEW v_pr_to_pur_chain AS
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    pr.requester_name,
    pr.department,
    pr.estimated_total_value AS pr_total,
    
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.supplier_name,
    po.total_amount AS po_total,
    
    gi.id AS grn_id,
    gi.grn_number,
    gi.status AS grn_status,
    gi.total_received_quantity,
    
    pi.id AS pur_id,
    pi.purchasing_number AS pur_number,
    pi.status AS pur_status,
    pi.grand_total AS pur_total,
    pi.payment_status,
    
    CASE 
        WHEN pi.id IS NOT NULL THEN 'invoiced'
        WHEN gi.id IS NOT NULL THEN 'received'
        WHEN po.id IS NOT NULL THEN 'ordered'
        ELSE 'requested'
    END AS chain_status,
    
    pr.created_at AS pr_date,
    po.order_date AS po_date,
    gi.grn_date,
    pi.invoice_date AS pur_date

FROM purchase_requests pr
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id AND ppl.status = 'active'
LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = po.id AND gi.deleted = FALSE
LEFT JOIN purchasing_invoices pi ON (pi.grn_id = gi.id OR pi.purchase_order_id = po.id) AND pi.deleted = FALSE
WHERE pr.deleted = FALSE;

-- ============================================================================
-- VIEW 3: Document Flow Timeline (for UI)
-- ============================================================================
CREATE OR REPLACE VIEW v_document_flow_timeline AS
SELECT 
    df.id,
    df.source_type,
    df.source_id,
    df.source_number,
    df.target_type,
    df.target_id,
    df.target_number,
    df.flow_type,
    df.created_at,
    df.created_by,
    
    -- Source status
    CASE df.source_type
        WHEN 'PR' THEN (SELECT status FROM purchase_requests WHERE id = df.source_id::UUID LIMIT 1)
        WHEN 'PO' THEN (SELECT status FROM purchase_orders WHERE id = df.source_id::BIGINT LIMIT 1)
        WHEN 'GRN' THEN (SELECT status FROM grn_inspections WHERE id = df.source_id::UUID LIMIT 1)
        WHEN 'PUR' THEN (SELECT status FROM purchasing_invoices WHERE id = df.source_id::UUID LIMIT 1)
    END AS source_status,
    
    -- Target status
    CASE df.target_type
        WHEN 'PR' THEN (SELECT status FROM purchase_requests WHERE id = df.target_id::UUID LIMIT 1)
        WHEN 'PO' THEN (SELECT status FROM purchase_orders WHERE id = df.target_id::BIGINT LIMIT 1)
        WHEN 'GRN' THEN (SELECT status FROM grn_inspections WHERE id = df.target_id::UUID LIMIT 1)
        WHEN 'PUR' THEN (SELECT status FROM purchasing_invoices WHERE id = df.target_id::UUID LIMIT 1)
    END AS target_status

FROM document_flow df;

-- Grant permissions
GRANT SELECT ON v_document_flow_full_chain TO authenticated;
GRANT SELECT ON v_document_flow_full_chain TO anon;
GRANT SELECT ON v_pr_to_pur_chain TO authenticated;
GRANT SELECT ON v_pr_to_pur_chain TO anon;
GRANT SELECT ON v_document_flow_timeline TO authenticated;
GRANT SELECT ON v_document_flow_timeline TO anon;

COMMENT ON VIEW v_document_flow_full_chain IS 'SAP VBFA equivalent - shows all document links in procurement chain';
COMMENT ON VIEW v_pr_to_pur_chain IS 'Complete procurement chain from PR to Purchasing Invoice';
COMMENT ON VIEW v_document_flow_timeline IS 'Document flow with current statuses for timeline display';
