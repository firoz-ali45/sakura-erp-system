-- ============================================================================
-- 02_document_flow_global_view.sql
-- GLOBAL VIEW FOR DOCUMENT FLOW UI
-- ============================================================================
-- View: v_document_flow_global
-- Columns: current_type, current_id, pr_id, pr_number, pr_status,
--          po_id, po_number, po_status, grn_id, grn_number, grn_status,
--          pur_id, purchasing_number, pur_status
-- Built from fn_trace_document_graph so UI never depends on document_flow table.
-- ============================================================================

DROP VIEW IF EXISTS v_document_flow_global CASCADE;

CREATE OR REPLACE VIEW v_document_flow_global AS

-- Rows where current document is PR
SELECT
    'PR'::TEXT AS current_type,
    pr.id::TEXT AS current_id,
    (j->'pr'->>'id')::UUID AS pr_id,
    j->'pr'->>'pr_number' AS pr_number,
    j->'pr'->>'status' AS pr_status,
    (j->'po'->>'id')::BIGINT AS po_id,
    j->'po'->>'po_number' AS po_number,
    j->'po'->>'status' AS po_status,
    (j->'grn'->>'id')::UUID AS grn_id,
    j->'grn'->>'grn_number' AS grn_number,
    j->'grn'->>'status' AS grn_status,
    (j->'pur'->>'id')::UUID AS pur_id,
    j->'pur'->>'purchasing_number' AS purchasing_number,
    j->'pur'->>'status' AS pur_status
FROM purchase_requests pr
CROSS JOIN LATERAL (SELECT fn_trace_document_graph('PR', pr.id::TEXT) AS j) t
WHERE (pr.deleted = FALSE OR pr.deleted IS NULL)
  AND (t.j->>'success')::BOOLEAN = TRUE

UNION ALL

-- Rows where current document is PO
SELECT
    'PO'::TEXT,
    po.id::TEXT,
    (j->'pr'->>'id')::UUID,
    j->'pr'->>'pr_number',
    j->'pr'->>'status',
    (j->'po'->>'id')::BIGINT,
    j->'po'->>'po_number',
    j->'po'->>'status',
    (j->'grn'->>'id')::UUID,
    j->'grn'->>'grn_number',
    j->'grn'->>'status',
    (j->'pur'->>'id')::UUID AS pur_id,
    j->'pur'->>'purchasing_number' AS purchasing_number,
    j->'pur'->>'status' AS pur_status
FROM purchase_orders po
CROSS JOIN LATERAL (SELECT fn_trace_document_graph('PO', po.id::TEXT) AS j) t
WHERE (po.deleted = FALSE OR po.deleted IS NULL)
  AND (t.j->>'success')::BOOLEAN = TRUE

UNION ALL

-- Rows where current document is GRN
SELECT
    'GRN'::TEXT,
    gi.id::TEXT,
    (j->'pr'->>'id')::UUID,
    j->'pr'->>'pr_number',
    j->'pr'->>'status',
    (j->'po'->>'id')::BIGINT,
    j->'po'->>'po_number',
    j->'po'->>'status',
    (j->'grn'->>'id')::UUID,
    j->'grn'->>'grn_number',
    j->'grn'->>'status',
    (j->'pur'->>'id')::UUID AS pur_id,
    j->'pur'->>'purchasing_number' AS purchasing_number,
    j->'pur'->>'status' AS pur_status
FROM grn_inspections gi
CROSS JOIN LATERAL (SELECT fn_trace_document_graph('GRN', gi.id::TEXT) AS j) t
WHERE gi.deleted = FALSE
  AND (t.j->>'success')::BOOLEAN = TRUE

UNION ALL

-- Rows where current document is PUR
SELECT
    'PUR'::TEXT,
    pi.id::TEXT,
    (j->'pr'->>'id')::UUID,
    j->'pr'->>'pr_number',
    j->'pr'->>'status',
    (j->'po'->>'id')::BIGINT,
    j->'po'->>'po_number',
    j->'po'->>'status',
    (j->'grn'->>'id')::UUID,
    j->'grn'->>'grn_number',
    j->'grn'->>'status',
    (j->'pur'->>'id')::UUID AS pur_id,
    j->'pur'->>'purchasing_number' AS purchasing_number,
    j->'pur'->>'status' AS pur_status
FROM purchasing_invoices pi
CROSS JOIN LATERAL (SELECT fn_trace_document_graph('PUR', pi.id::TEXT) AS j) t
WHERE pi.deleted = FALSE
  AND (t.j->>'success')::BOOLEAN = TRUE;

-- Alias pur_number column for user spec (purchasing_number in spec = pur_number in view)
COMMENT ON VIEW v_document_flow_global IS 'Flattened document flow per current document. Query by current_type/current_id. Do not rely on document_flow table.';

GRANT SELECT ON v_document_flow_global TO authenticated, anon;
