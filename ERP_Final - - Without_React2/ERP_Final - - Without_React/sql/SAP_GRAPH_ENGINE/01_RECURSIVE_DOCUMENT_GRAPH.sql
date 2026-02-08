-- ============================================================================
-- 01_recursive_document_graph.sql
-- SAP S/4HANA STYLE TRUE RECURSIVE DOCUMENT GRAPH ENGINE
-- ============================================================================
-- Document Flow MUST be reconstructed dynamically using recursive graph traversal.
-- No UI guessing, no manual joins, no document_flow dependency only.
-- System detects chain from ANY document: PR, PO, GRN, PUR (any direction).
--
-- DATABASE SCHEMA LINKS:
--   PR ↔ PO: pr_po_linkage.pr_id / po_id
--   PO ↔ GRN: grn_inspections.purchase_order_id
--   GRN ↔ PUR: purchasing_invoices.grn_id
--   PO ↔ PUR: purchasing_invoices.purchase_order_id
-- ============================================================================

DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, TEXT) CASCADE;

-- ============================================================================
-- fn_trace_document_graph(input_type TEXT, input_uuid UUID)
-- fn_trace_document_graph(input_type TEXT, input_id TEXT)  -- accepts UUID string or PO bigint string
-- ============================================================================
-- Returns FULL chain JSON. Single object per type (or null). UI uses this only.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trace_document_graph(
    p_input_type TEXT,
    p_input_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_normalized_type TEXT;
    v_result JSONB;
BEGIN
    v_normalized_type := UPPER(TRIM(COALESCE(p_input_type, '')));
    v_normalized_type := CASE v_normalized_type
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GOODS_RECEIPT' THEN 'GRN'
        WHEN 'GR' THEN 'GRN'
        WHEN 'MIGO' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        WHEN 'MIRO' THEN 'PUR'
        ELSE v_normalized_type
    END;

    IF v_normalized_type NOT IN ('PR', 'PO', 'GRN', 'PUR') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid document type. Use: PR, PO, GRN, or PUR',
            'pr', NULL,
            'po', NULL,
            'grn', NULL,
            'pur', NULL
        );
    END IF;

    IF p_input_id IS NULL OR p_input_id = '' OR p_input_id = 'null' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Document ID is required',
            'pr', NULL,
            'po', NULL,
            'grn', NULL,
            'pur', NULL
        );
    END IF;

    -- ========================================================================
    -- RECURSIVE GRAPH TRAVERSAL (both directions)
    -- ========================================================================
    WITH RECURSIVE document_graph AS (
        SELECT
            v_normalized_type AS doc_type,
            p_input_id AS doc_id,
            ARRAY[v_normalized_type || ':' || p_input_id] AS visited,
            0 AS depth
        UNION ALL
        SELECT
            edges.target_type,
            edges.target_id,
            g.visited || (edges.target_type || ':' || edges.target_id),
            g.depth + 1
        FROM document_graph g
        CROSS JOIN LATERAL (
            SELECT 'PO'::TEXT AS target_type, l.po_id::TEXT AS target_id
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PR' AND l.pr_id::TEXT = g.doc_id AND l.po_id IS NOT NULL
            UNION ALL
            SELECT 'PR'::TEXT, l.pr_id::TEXT
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PO' AND l.po_id::TEXT = g.doc_id AND l.pr_id IS NOT NULL
            UNION ALL
            SELECT 'GRN'::TEXT, gi.id::TEXT
            FROM grn_inspections gi
            WHERE g.doc_type = 'PO' AND gi.purchase_order_id::TEXT = g.doc_id AND gi.deleted = FALSE
            UNION ALL
            SELECT 'PO'::TEXT, gi.purchase_order_id::TEXT
            FROM grn_inspections gi
            WHERE g.doc_type = 'GRN' AND gi.id::TEXT = g.doc_id AND gi.purchase_order_id IS NOT NULL
            UNION ALL
            SELECT 'PUR'::TEXT, pi.id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'GRN' AND pi.grn_id::TEXT = g.doc_id AND pi.deleted = FALSE
            UNION ALL
            SELECT 'GRN'::TEXT, pi.grn_id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.grn_id IS NOT NULL
            UNION ALL
            SELECT 'PUR'::TEXT, pi.id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PO' AND pi.purchase_order_id::TEXT = g.doc_id AND pi.deleted = FALSE
            UNION ALL
            SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.purchase_order_id IS NOT NULL
        ) AS edges
        WHERE NOT (edges.target_type || ':' || edges.target_id) = ANY(g.visited)
          AND edges.target_id IS NOT NULL AND edges.target_id != ''
          AND g.depth < 10
    ),
    unique_docs AS (
        SELECT DISTINCT doc_type, doc_id
        FROM document_graph
        WHERE doc_id IS NOT NULL AND doc_id != ''
    ),
    -- Single representative doc per type (first by date for stable UI)
    pr_one AS (
        SELECT jsonb_build_object(
            'id', pr.id,
            'pr_number', pr.pr_number,
            'status', pr.status,
            'date', pr.created_at
        ) AS j
        FROM purchase_requests pr
        WHERE pr.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR')
          AND (pr.deleted = FALSE OR pr.deleted IS NULL)
        ORDER BY pr.created_at
        LIMIT 1
    ),
    po_one AS (
        SELECT jsonb_build_object(
            'id', po.id,
            'po_number', po.po_number,
            'status', po.status,
            'date', po.order_date
        ) AS j
        FROM purchase_orders po
        WHERE po.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO')
          AND (po.deleted = FALSE OR po.deleted IS NULL)
        ORDER BY po.order_date
        LIMIT 1
    ),
    grn_one AS (
        SELECT jsonb_build_object(
            'id', gi.id,
            'grn_number', gi.grn_number,
            'status', gi.status,
            'date', gi.grn_date
        ) AS j
        FROM grn_inspections gi
        WHERE gi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN')
          AND gi.deleted = FALSE
        ORDER BY gi.grn_date
        LIMIT 1
    ),
    pur_one AS (
        SELECT jsonb_build_object(
            'id', pi.id,
            'purchasing_number', pi.purchasing_number,
            'status', pi.status,
            'date', COALESCE(pi.invoice_date, pi.created_at::DATE)
        ) AS j
        FROM purchasing_invoices pi
        WHERE pi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR')
          AND pi.deleted = FALSE
        ORDER BY pi.created_at
        LIMIT 1
    )
    SELECT jsonb_build_object(
        'success', true,
        'root_type', v_normalized_type,
        'root_id', p_input_id,
        'pr', (SELECT j FROM pr_one),
        'po', (SELECT j FROM po_one),
        'grn', (SELECT j FROM grn_one),
        'pur', (SELECT j FROM pur_one)
    ) INTO v_result;

    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'root_type', v_normalized_type,
        'root_id', p_input_id,
        'pr', NULL,
        'po', NULL,
        'grn', NULL,
        'pur', NULL
    );
END;
$$;

-- Overload: accept UUID for RPC clients that pass UUID type
CREATE OR REPLACE FUNCTION fn_trace_document_graph(
    p_input_type TEXT,
    p_input_uuid UUID
)
RETURNS JSONB
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT fn_trace_document_graph(p_input_type, p_input_uuid::TEXT);
$$;

-- ============================================================================
-- GRANTS & COMMENTS
-- ============================================================================
GRANT EXECUTE ON FUNCTION fn_trace_document_graph(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_trace_document_graph(TEXT, UUID) TO authenticated, anon;
COMMENT ON FUNCTION fn_trace_document_graph(TEXT, TEXT) IS 'SAP VBFA-style recursive document graph. Returns { pr, po, grn, pur } as single objects or null. Use this for Document Flow UI only.';

-- ============================================================================
-- TEST EXAMPLES
-- ============================================================================
-- By PR (UUID):
--   SELECT fn_trace_document_graph('PR', '7bceaea5-fa29-4463-ba3a-1f8c3df44b74');
-- By PO (BIGINT as text):
--   SELECT fn_trace_document_graph('PO', '74');
-- By GRN (UUID):
--   SELECT fn_trace_document_graph('GRN', '06dfa2a6-bee2-4da1-bd59-20fd4b1b972f');
-- By PUR (UUID):
--   SELECT fn_trace_document_graph('PUR', '029770fb-6bf2-4f46-9298-6625a2033dd0');
--
-- Global view (all chains where current document is GRN):
--   SELECT * FROM v_document_flow_global WHERE current_type = 'GRN';
-- Single chain by current document id:
--   SELECT * FROM v_document_flow_global WHERE current_type = 'PO' AND current_id = '74';
