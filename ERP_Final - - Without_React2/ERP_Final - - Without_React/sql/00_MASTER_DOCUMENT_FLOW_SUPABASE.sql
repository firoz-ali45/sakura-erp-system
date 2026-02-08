-- ============================================================================
-- 00_MASTER_DOCUMENT_FLOW_SUPABASE.sql
-- SAP-STYLE DOCUMENT FLOW — SUPABASE (PO id = BIGINT, others UUID)
-- ============================================================================

-- ============================================================================
-- PART 1 — doc_graph TABLE (SAP VBFA STYLE) + BACKFILL
-- ============================================================================

CREATE TABLE IF NOT EXISTS doc_graph (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type TEXT NOT NULL,
    source_id TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_doc_graph_unique
ON doc_graph(source_type, source_id, target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_doc_graph_source ON doc_graph(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_doc_graph_target ON doc_graph(target_type, target_id);

-- Backfill PR → PO
INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'PR', pr_id::TEXT, 'PO', po_id::TEXT
FROM pr_po_linkage
ON CONFLICT DO NOTHING;

-- Backfill PO → GRN (purchase_order_id::TEXT for BIGINT)
INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'PO', purchase_order_id::TEXT, 'GRN', id::TEXT
FROM grn_inspections
WHERE purchase_order_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
ON CONFLICT DO NOTHING;

-- Backfill GRN → PUR
INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'GRN', grn_id::TEXT, 'PUR', id::TEXT
FROM purchasing_invoices
WHERE grn_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 2 — AUTO GRAPH TRIGGERS (FUTURE SAFE)
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_pr_po_graph()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
  VALUES ('PR', NEW.pr_id::TEXT, 'PO', NEW.po_id::TEXT)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS pr_po_graph ON pr_po_linkage;
CREATE TRIGGER pr_po_graph
AFTER INSERT ON pr_po_linkage
FOR EACH ROW EXECUTE FUNCTION trg_pr_po_graph();

CREATE OR REPLACE FUNCTION trg_po_grn_graph()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.purchase_order_id IS NOT NULL THEN
    INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
    VALUES ('PO', NEW.purchase_order_id::TEXT, 'GRN', NEW.id::TEXT)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS po_grn_graph ON grn_inspections;
CREATE TRIGGER po_grn_graph
AFTER INSERT ON grn_inspections
FOR EACH ROW EXECUTE FUNCTION trg_po_grn_graph();

CREATE OR REPLACE FUNCTION trg_grn_pur_graph()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.grn_id IS NOT NULL THEN
    INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
    VALUES ('GRN', NEW.grn_id::TEXT, 'PUR', NEW.id::TEXT)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS grn_pur_graph ON purchasing_invoices;
CREATE TRIGGER grn_pur_graph
AFTER INSERT ON purchasing_invoices
FOR EACH ROW EXECUTE FUNCTION trg_grn_pur_graph();

-- ============================================================================
-- PART 3 — fn_trace_graph (RECURSIVE OVER doc_graph, RETURNS pr/po/grn/pur IDs)
-- ============================================================================
-- Traverses doc_graph bidirectionally from any start. All IDs stored as TEXT (UUID + BIGINT).
DROP FUNCTION IF EXISTS fn_trace_graph(TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_trace_graph(input_type TEXT, input_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_type TEXT := UPPER(TRIM(COALESCE(input_type, '')));
    v_id TEXT := NULLIF(TRIM(input_id), '');
    v_result JSONB;
BEGIN
    v_type := CASE v_type
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GOODS_RECEIPT' THEN 'GRN'
        WHEN 'GR' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        ELSE v_type
    END;

    IF v_type NOT IN ('PR', 'PO', 'GRN', 'PUR') OR v_id IS NULL OR v_id = '' THEN
        RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
    END IF;
    
    WITH RECURSIVE graph(source_type, source_id, target_type, target_id, path) AS (
        SELECT source_type, source_id, target_type, target_id,
               ARRAY[source_type || ':' || source_id || '->' || target_type || ':' || target_id]
        FROM doc_graph
        WHERE (source_type = v_type AND source_id = v_id)
           OR (target_type = v_type AND target_id = v_id)

        UNION ALL

        SELECT g.source_type, g.source_id, g.target_type, g.target_id,
               r.path || (g.source_type || ':' || g.source_id || '->' || g.target_type || ':' || g.target_id)
        FROM doc_graph g
        JOIN graph r ON (g.source_type = r.target_type AND g.source_id = r.target_id)
                    OR (g.target_type = r.source_type AND g.target_id = r.source_id)
        WHERE NOT (g.source_type || ':' || g.source_id || '->' || g.target_type || ':' || g.target_id) = ANY(r.path)
          AND array_length(r.path, 1) < 50
    )
    SELECT jsonb_build_object(
        'pr',  COALESCE((SELECT source_id FROM graph WHERE source_type = 'PR' LIMIT 1), (SELECT target_id FROM graph WHERE target_type = 'PR' LIMIT 1)),
        'po',  COALESCE((SELECT source_id FROM graph WHERE source_type = 'PO' LIMIT 1), (SELECT target_id FROM graph WHERE target_type = 'PO' LIMIT 1)),
        'grn', COALESCE((SELECT source_id FROM graph WHERE source_type = 'GRN' LIMIT 1), (SELECT target_id FROM graph WHERE target_type = 'GRN' LIMIT 1)),
        'pur', COALESCE((SELECT source_id FROM graph WHERE source_type = 'PUR' LIMIT 1), (SELECT target_id FROM graph WHERE target_type = 'PUR' LIMIT 1))
    ) INTO v_result;

    RETURN COALESCE(v_result, jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trace_graph(TEXT, TEXT) TO authenticated, anon;

-- ============================================================================
-- 1) TRUE SAP RECURSIVE DOCUMENT GRAPH ENGINE (RELATIONAL — no doc_graph)
-- ============================================================================
DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_trace_document_graph(
    p_input_type TEXT,
    p_input_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_input_type TEXT := UPPER(TRIM(COALESCE(p_input_type, '')));
    v_result JSONB;
BEGIN
    v_input_type := CASE v_input_type
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GOODS_RECEIPT' THEN 'GRN'
        WHEN 'GR' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        ELSE v_input_type
    END;

    IF v_input_type NOT IN ('PR', 'PO', 'GRN', 'PUR') OR p_input_id IS NULL OR p_input_id = '' THEN
        RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
    END IF;

    WITH RECURSIVE doc_chain(doc_type, doc_id, path) AS (
        -- Base: seed from input (any type)
        SELECT v_input_type, p_input_id, ARRAY[v_input_type || ':' || p_input_id]
        WHERE p_input_id IS NOT NULL AND p_input_id != ''

        UNION ALL

        -- PR → PO
        SELECT 'PO'::TEXT, l.po_id::TEXT, d.path || ('PO:' || l.po_id::TEXT)
        FROM pr_po_linkage l
        JOIN doc_chain d ON d.doc_type = 'PR' AND l.pr_id::TEXT = d.doc_id
        WHERE NOT (('PO:' || l.po_id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- PO → PR
        SELECT 'PR'::TEXT, l.pr_id::TEXT, d.path || ('PR:' || l.pr_id::TEXT)
        FROM pr_po_linkage l
        JOIN doc_chain d ON d.doc_type = 'PO' AND l.po_id::TEXT = d.doc_id
        WHERE NOT (('PR:' || l.pr_id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- PO → GRN (purchase_order_id::TEXT for BIGINT)
        SELECT 'GRN'::TEXT, g.id::TEXT, d.path || ('GRN:' || g.id::TEXT)
        FROM grn_inspections g
        JOIN doc_chain d ON d.doc_type = 'PO' AND g.purchase_order_id::TEXT = d.doc_id
        WHERE (g.deleted = FALSE OR g.deleted IS NULL)
          AND NOT (('GRN:' || g.id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- GRN → PO
        SELECT 'PO'::TEXT, g.purchase_order_id::TEXT, d.path || ('PO:' || g.purchase_order_id::TEXT)
        FROM grn_inspections g
        JOIN doc_chain d ON d.doc_type = 'GRN' AND g.id::TEXT = d.doc_id
        WHERE g.purchase_order_id IS NOT NULL
          AND NOT (('PO:' || g.purchase_order_id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- GRN → PUR
        SELECT 'PUR'::TEXT, pi.id::TEXT, d.path || ('PUR:' || pi.id::TEXT)
        FROM purchasing_invoices pi
        JOIN doc_chain d ON d.doc_type = 'GRN' AND pi.grn_id::TEXT = d.doc_id
        WHERE (pi.deleted = FALSE OR pi.deleted IS NULL)
          AND NOT (('PUR:' || pi.id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- PUR → GRN
        SELECT 'GRN'::TEXT, pi.grn_id::TEXT, d.path || ('GRN:' || pi.grn_id::TEXT)
        FROM purchasing_invoices pi
        JOIN doc_chain d ON d.doc_type = 'PUR' AND pi.id::TEXT = d.doc_id
        WHERE pi.grn_id IS NOT NULL
          AND NOT (('GRN:' || pi.grn_id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- PO → PUR (direct)
        SELECT 'PUR'::TEXT, pi.id::TEXT, d.path || ('PUR:' || pi.id::TEXT)
        FROM purchasing_invoices pi
        JOIN doc_chain d ON d.doc_type = 'PO' AND pi.purchase_order_id::TEXT = d.doc_id
        WHERE (pi.deleted = FALSE OR pi.deleted IS NULL)
          AND NOT (('PUR:' || pi.id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20

        UNION ALL

        -- PUR → PO
        SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT, d.path || ('PO:' || pi.purchase_order_id::TEXT)
        FROM purchasing_invoices pi
        JOIN doc_chain d ON d.doc_type = 'PUR' AND pi.id::TEXT = d.doc_id
        WHERE pi.purchase_order_id IS NOT NULL
          AND NOT (('PO:' || pi.purchase_order_id::TEXT) = ANY(d.path)) AND array_length(d.path, 1) < 20
    ),
    unique_docs AS (
        SELECT DISTINCT doc_type, doc_id FROM doc_chain WHERE doc_id IS NOT NULL AND doc_id != ''
    )
    SELECT jsonb_build_object(
        'pr', (SELECT row_to_json(r) FROM purchase_requests r WHERE r.id::TEXT = (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR' LIMIT 1) AND (r.deleted = FALSE OR r.deleted IS NULL)),
        'po', (SELECT row_to_json(p) FROM purchase_orders p WHERE p.id::TEXT = (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO' LIMIT 1) AND (p.deleted = FALSE OR p.deleted IS NULL)),
        'grn', (SELECT row_to_json(g) FROM grn_inspections g WHERE g.id::TEXT = (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN' LIMIT 1) AND g.deleted = FALSE),
        'pur', (SELECT row_to_json(pi) FROM purchasing_invoices pi WHERE pi.id::TEXT = (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR' LIMIT 1) AND (pi.deleted = FALSE OR pi.deleted IS NULL))
    ) INTO v_result;

    RETURN COALESCE(v_result, jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trace_document_graph(TEXT, TEXT) TO authenticated, anon;

-- ============================================================================
-- 2) PR LINKED PO COUNT (PR LIST COLUMN)
-- ============================================================================
DROP VIEW IF EXISTS v_pr_linked_po_count CASCADE;

CREATE OR REPLACE VIEW v_pr_linked_po_count AS
SELECT pr_id, COUNT(DISTINCT po_id) AS po_count
FROM pr_po_linkage
GROUP BY pr_id;

GRANT SELECT ON v_pr_linked_po_count TO authenticated, anon;

-- ============================================================================
-- 5) OPTIONAL — SAP VBFA STYLE BACKFILL document_flow
-- ============================================================================
-- Ensure document_flow has (source_type, source_id, target_type, target_id).
-- Run once; adjust column names if your table differs.

-- INSERT INTO document_flow(source_type, source_id, target_type, target_id)
-- SELECT 'PR', pr_id::TEXT, 'PO', po_id::TEXT FROM pr_po_linkage
-- ON CONFLICT DO NOTHING;

-- INSERT INTO document_flow(source_type, source_id, target_type, target_id)
-- SELECT 'PO', purchase_order_id::TEXT, 'GRN', id::TEXT FROM grn_inspections
-- WHERE purchase_order_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
-- ON CONFLICT DO NOTHING;

-- INSERT INTO document_flow(source_type, source_id, target_type, target_id)
-- SELECT 'GRN', grn_id::TEXT, 'PUR', id::TEXT FROM purchasing_invoices
-- WHERE grn_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
-- ON CONFLICT DO NOTHING;

-- ============================================================================
-- VERIFICATION & TEST QUERIES
-- ============================================================================
-- 1) Ensure doc_graph exists and is populated (PR → PO → GRN → PUR):
--    SELECT source_type, source_id, target_type, target_id FROM doc_graph ORDER BY created_at LIMIT 20;
--
-- 2) Full chain from any document (replace with real IDs; PO id = BIGINT as text):
--    SELECT fn_trace_graph('PR', '<PR_UUID>');
--    SELECT fn_trace_graph('PO', '<PO_ID>');
--    SELECT fn_trace_graph('GRN', '<GRN_UUID>');
--    SELECT fn_trace_graph('PUR', '<PUR_UUID>');
--
-- 3) Confirm JSON returns full chain: { "pr": "<uuid>", "po": "<bigint>", "grn": "<uuid>", "pur": "<uuid>" }
--    (null for missing links; all IDs as TEXT — no UUID vs BIGINT join mismatch in doc_graph.)
--
-- 4) DocumentFlow.vue uses fn_trace_graph only (input_type, input_id). exists(id) = id != null && id !== ''.
--
-- 5) Routing: /homeportal/pr-detail/:id, purchase-order-detail/:id, grn-detail/:id, purchasing-detail/:id.
--
-- 6) Join mismatch: doc_graph stores source_id/target_id as TEXT; PR/GRN/PUR = UUID, PO = BIGINT — all cast to TEXT.
