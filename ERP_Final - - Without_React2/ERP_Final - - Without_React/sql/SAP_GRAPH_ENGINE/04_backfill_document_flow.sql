-- ============================================================================
-- 04_backfill_document_flow.sql
-- BACKFILL DOCUMENT GRAPH (document_flow table)
-- ============================================================================
-- Scan all existing PR → PO → GRN → PUR relationships from relational tables.
-- Insert missing document_flow records. Fix broken chains.
-- Run ONCE after installing the graph engine. document_flow is audit only;
-- UI MUST use fn_trace_document_graph(), not this table.
--
-- Assumes document_flow has: source_type, source_id, source_number,
-- target_type, target_id, target_number, flow_type, created_at
-- (source_id/target_id as TEXT for UUID and BIGINT compatibility)
-- ============================================================================

-- STEP 1: PR → PO
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PR',
    ppl.pr_id::TEXT,
    COALESCE(pr.pr_number, ppl.pr_number),
    'PO',
    ppl.po_id::TEXT,
    COALESCE(ppl.po_number, po.po_number),
    'PR_TO_PO',
    COALESCE(ppl.converted_at, ppl.created_at, NOW())
FROM pr_po_linkage ppl
LEFT JOIN purchase_requests pr ON pr.id = ppl.pr_id
LEFT JOIN purchase_orders po ON po.id = ppl.po_id
WHERE NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PR'
      AND df.source_id = ppl.pr_id::TEXT
      AND df.target_type = 'PO'
      AND df.target_id = ppl.po_id::TEXT
      AND (df.flow_type = 'PR_TO_PO' OR df.flow_type = 'converted_to_po')
);

-- STEP 2: PO → GRN
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PO',
    gi.purchase_order_id::TEXT,
    COALESCE(gi.purchase_order_number, po.po_number),
    'GRN',
    gi.id::TEXT,
    gi.grn_number,
    'PO_TO_GRN',
    gi.created_at
FROM grn_inspections gi
LEFT JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE (gi.deleted = FALSE OR gi.deleted IS NULL)
  AND gi.purchase_order_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PO'
      AND df.source_id = gi.purchase_order_id::TEXT
      AND df.target_type = 'GRN'
      AND df.target_id = gi.id::TEXT
      AND (df.flow_type = 'PO_TO_GRN' OR df.flow_type = 'goods_received')
);

-- STEP 3: GRN → PUR
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'GRN',
    pi.grn_id::TEXT,
    COALESCE(gi.grn_number, pi.grn_number),
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'GRN_TO_PUR',
    pi.created_at
FROM purchasing_invoices pi
LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE (pi.deleted = FALSE OR pi.deleted IS NULL)
  AND pi.grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'GRN'
      AND df.source_id = pi.grn_id::TEXT
      AND df.target_type = 'PUR'
      AND df.target_id = pi.id::TEXT
      AND (df.flow_type = 'GRN_TO_PUR' OR df.flow_type = 'invoice_created')
);

-- STEP 4: PO → PUR (direct, no GRN)
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PO',
    pi.purchase_order_id::TEXT,
    COALESCE(pi.purchase_order_number, po.po_number),
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'PO_TO_PUR',
    pi.created_at
FROM purchasing_invoices pi
LEFT JOIN purchase_orders po ON po.id = pi.purchase_order_id
WHERE (pi.deleted = FALSE OR pi.deleted IS NULL)
  AND pi.purchase_order_id IS NOT NULL
  AND pi.grn_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PO'
      AND df.source_id = pi.purchase_order_id::TEXT
      AND df.target_type = 'PUR'
      AND df.target_id = pi.id::TEXT
      AND (df.flow_type = 'PO_TO_PUR' OR df.flow_type = 'invoice_created')
);

-- Verification
SELECT flow_type, COUNT(*) AS record_count
FROM document_flow
GROUP BY flow_type
ORDER BY flow_type;

SELECT 'BACKFILL COMPLETE. UI must use fn_trace_document_graph(); document_flow is audit only.' AS message;
