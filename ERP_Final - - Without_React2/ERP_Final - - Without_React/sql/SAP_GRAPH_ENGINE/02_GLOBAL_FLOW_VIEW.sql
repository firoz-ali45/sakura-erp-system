-- ============================================================================
-- 02_GLOBAL_FLOW_VIEW.sql
-- SAP DOCUMENT FLOW GLOBAL VIEW
-- Provides flat view of document relationships for easy querying
-- ============================================================================

-- Drop existing views
DROP VIEW IF EXISTS v_sap_document_flow_global CASCADE;
DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;

-- ============================================================================
-- VIEW: v_sap_document_flow_global
-- Flattened view of all document chains
-- ============================================================================

CREATE OR REPLACE VIEW v_sap_document_flow_global AS

-- PR-based chains (start from PR, trace forward)
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    pr.requester_name,
    pr.department,
    pr.created_at AS pr_date,
    
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.supplier_name,
    po.order_date AS po_date,
    
    gi.id AS grn_id,
    gi.grn_number,
    gi.status AS grn_status,
    gi.grn_date,
    
    pi.id AS pur_id,
    pi.purchasing_number AS pur_number,
    pi.status AS pur_status,
    pi.invoice_date AS pur_date,
    pi.payment_status,
    
    -- Chain status
    CASE 
        WHEN pi.id IS NOT NULL AND pi.status = 'posted' THEN 'COMPLETE'
        WHEN pi.id IS NOT NULL THEN 'INVOICED'
        WHEN gi.id IS NOT NULL AND gi.status IN ('approved', 'passed') THEN 'RECEIVED'
        WHEN po.id IS NOT NULL AND po.status = 'approved' THEN 'ORDERED'
        WHEN pr.status = 'approved' THEN 'APPROVED'
        ELSE 'DRAFT'
    END AS chain_status
    
FROM purchase_requests pr
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id
LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = po.id AND gi.deleted = FALSE
LEFT JOIN purchasing_invoices pi ON (pi.grn_id = gi.id OR pi.purchase_order_id = po.id) AND pi.deleted = FALSE
WHERE pr.deleted = FALSE;

-- ============================================================================
-- VIEW: v_pr_linked_pos
-- Shows all POs linked to each PR (for PR list page)
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_linked_pos AS
SELECT 
    ppl.pr_id,
    ppl.po_id,
    COALESCE(ppl.po_number, po.po_number) AS po_number,
    po.supplier_name,
    po.status AS po_status,
    po.receiving_status,
    SUM(COALESCE(ppl.converted_quantity, 0)) AS converted_qty,
    COUNT(*) AS item_count,
    COALESCE(po.total_amount, 0) AS po_total,
    COALESCE(po.order_date, ppl.converted_at) AS po_date
FROM pr_po_linkage ppl
LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
GROUP BY 
    ppl.pr_id, 
    ppl.po_id, 
    ppl.po_number, 
    po.po_number, 
    po.supplier_name, 
    po.status, 
    po.receiving_status, 
    po.total_amount, 
    po.order_date, 
    ppl.converted_at;

-- ============================================================================
-- FUNCTION: get_pr_linked_pos
-- Returns linked POs for a specific PR
-- ============================================================================

DROP FUNCTION IF EXISTS get_pr_linked_pos(UUID) CASCADE;

CREATE OR REPLACE FUNCTION get_pr_linked_pos(p_pr_id UUID)
RETURNS TABLE (
    po_id BIGINT,
    po_number TEXT,
    supplier_name TEXT,
    po_status TEXT,
    receiving_status TEXT,
    converted_qty NUMERIC,
    item_count BIGINT,
    po_total NUMERIC,
    po_date TIMESTAMPTZ
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        v.po_id,
        v.po_number,
        v.supplier_name,
        v.po_status,
        v.receiving_status,
        v.converted_qty,
        v.item_count,
        v.po_total,
        v.po_date
    FROM v_pr_linked_pos v
    WHERE v.pr_id = p_pr_id;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT SELECT ON v_sap_document_flow_global TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos(UUID) TO authenticated, anon;
