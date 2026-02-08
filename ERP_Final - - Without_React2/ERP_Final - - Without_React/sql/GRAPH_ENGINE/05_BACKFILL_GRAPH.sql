-- ============================================================================
-- 05_BACKFILL_GRAPH.sql
-- BACKFILL DOCUMENT FLOW FOR EXISTING DATA
-- 
-- Run this ONCE after installing the graph engine to populate
-- document_flow audit table with existing document relationships.
--
-- NOTE: This script matches your actual document_flow table schema:
-- (id, source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
-- ============================================================================

-- ============================================================================
-- STEP 1: Backfill PR → PO Linkages
-- ============================================================================
INSERT INTO document_flow (
    source_type,
    source_id,
    source_number,
    target_type,
    target_id,
    target_number,
    flow_type,
    created_at
)
SELECT DISTINCT
    'PR',
    ppl.pr_id::TEXT,
    pr.pr_number,
    'PO',
    ppl.po_id::TEXT,
    ppl.po_number,
    'PR_TO_PO',
    COALESCE(ppl.converted_at, ppl.created_at, NOW())
FROM pr_po_linkage ppl
JOIN purchase_requests pr ON pr.id = ppl.pr_id
WHERE NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PR'
      AND df.source_id = ppl.pr_id::TEXT
      AND df.target_type = 'PO'
      AND df.target_id = ppl.po_id::TEXT
      AND df.flow_type = 'PR_TO_PO'
);

-- ============================================================================
-- STEP 2: Backfill PO → GRN Linkages
-- ============================================================================
INSERT INTO document_flow (
    source_type,
    source_id,
    source_number,
    target_type,
    target_id,
    target_number,
    flow_type,
    created_at
)
SELECT DISTINCT
    'PO',
    gi.purchase_order_id::TEXT,
    po.po_number,
    'GRN',
    gi.id::TEXT,
    gi.grn_number,
    'PO_TO_GRN',
    gi.created_at
FROM grn_inspections gi
JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.deleted = FALSE
  AND gi.purchase_order_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PO'
      AND df.source_id = gi.purchase_order_id::TEXT
      AND df.target_type = 'GRN'
      AND df.target_id = gi.id::TEXT
      AND df.flow_type = 'PO_TO_GRN'
);

-- ============================================================================
-- STEP 3: Backfill GRN → PUR Linkages
-- ============================================================================
INSERT INTO document_flow (
    source_type,
    source_id,
    source_number,
    target_type,
    target_id,
    target_number,
    flow_type,
    created_at
)
SELECT DISTINCT
    'GRN',
    pi.grn_id::TEXT,
    gi.grn_number,
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'GRN_TO_PUR',
    pi.created_at
FROM purchasing_invoices pi
JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE pi.deleted = FALSE
  AND pi.grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'GRN'
      AND df.source_id = pi.grn_id::TEXT
      AND df.target_type = 'PUR'
      AND df.target_id = pi.id::TEXT
      AND df.flow_type = 'GRN_TO_PUR'
);

-- ============================================================================
-- STEP 4: Backfill PO → PUR Direct Linkages (no GRN)
-- ============================================================================
INSERT INTO document_flow (
    source_type,
    source_id,
    source_number,
    target_type,
    target_id,
    target_number,
    flow_type,
    created_at
)
SELECT DISTINCT
    'PO',
    pi.purchase_order_id::TEXT,
    po.po_number,
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'PO_TO_PUR',
    pi.created_at
FROM purchasing_invoices pi
JOIN purchase_orders po ON po.id = pi.purchase_order_id
WHERE pi.deleted = FALSE
  AND pi.purchase_order_id IS NOT NULL
  AND pi.grn_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PO'
      AND df.source_id = pi.purchase_order_id::TEXT
      AND df.target_type = 'PUR'
      AND df.target_id = pi.id::TEXT
      AND df.flow_type = 'PO_TO_PUR'
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 
    flow_type,
    COUNT(*) AS record_count
FROM document_flow
GROUP BY flow_type
ORDER BY flow_type;

SELECT 'BACKFILL COMPLETE!' AS message;
