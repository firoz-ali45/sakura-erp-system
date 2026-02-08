-- ============================================================================
-- 02_SAP_DOCUMENT_FLOW_MASTER.sql
-- SAP S/4HANA MM GRADE — Document Flow (VBFA Style)
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================================

-- ============================================================================
-- PART 1 — SAP VBFA STYLE DOCUMENT FLOW TABLE + BACKFILL
-- ============================================================================
-- IDs stored as TEXT to support UUID (PR,GRN,PUR) + BIGINT (PO)

-- Create table with correct schema (source_id, target_id as TEXT for mixed IDs)
CREATE TABLE IF NOT EXISTS document_flow (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type text NOT NULL,
  source_id text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- If existing table has UUID columns, migrate (run separately if needed)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns c JOIN information_schema.tables t ON c.table_name = t.table_name WHERE t.table_name = 'document_flow' AND c.column_name = 'source_id' AND c.data_type = 'uuid') THEN
    ALTER TABLE document_flow ADD COLUMN IF NOT EXISTS source_id_text text;
    ALTER TABLE document_flow ADD COLUMN IF NOT EXISTS target_id_text text;
    UPDATE document_flow SET source_id_text = source_id::text WHERE source_id_text IS NULL;
    UPDATE document_flow SET target_id_text = target_id::text WHERE target_id_text IS NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Clean and backfill
TRUNCATE document_flow CASCADE;

-- PR → PO
INSERT INTO document_flow (source_type, source_id, target_type, target_id)
SELECT 'PR', pr_id::TEXT, 'PO', po_id::TEXT
FROM pr_po_linkage
WHERE pr_id IS NOT NULL AND po_id IS NOT NULL
  AND (status = 'active' OR status IS NULL);

-- PO → GRN (handle NULL purchase_order_id via purchase_order_number)
INSERT INTO document_flow (source_type, source_id, target_type, target_id)
SELECT 'PO', COALESCE(gi.purchase_order_id, po.id)::TEXT, 'GRN', gi.id::TEXT
FROM grn_inspections gi
LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(gi.purchase_order_number) AND (po.deleted IS NOT TRUE)
WHERE (gi.purchase_order_id IS NOT NULL OR po.id IS NOT NULL)
  AND (gi.deleted IS NOT TRUE);

-- GRN → PUR
INSERT INTO document_flow (source_type, source_id, target_type, target_id)
SELECT 'GRN', grn_id::TEXT, 'PUR', id::TEXT
FROM purchasing_invoices
WHERE grn_id IS NOT NULL AND (deleted IS NOT TRUE);

-- PO → PUR (direct link when no GRN)
INSERT INTO document_flow (source_type, source_id, target_type, target_id)
SELECT 'PO', COALESCE(pi.purchase_order_id, po.id)::TEXT, 'PUR', pi.id::TEXT
FROM purchasing_invoices pi
LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(pi.purchase_order_number) AND (po.deleted IS NOT TRUE)
WHERE (pi.purchase_order_id IS NOT NULL OR po.id IS NOT NULL)
  AND (pi.deleted IS NOT TRUE)
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_doc_flow_source ON document_flow(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target ON document_flow(target_type, target_id);

-- ============================================================================
-- PART 2 — GLOBAL RECURSIVE DOCUMENT GRAPH (SAP VBFA)
-- BIDIRECTIONAL: Traces forward and backward from any document
-- ============================================================================

DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_trace_document_graph(p_type TEXT, p_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type TEXT := UPPER(TRIM(COALESCE(p_type, '')));
  v_id TEXT := NULLIF(TRIM(p_id), '');
  v_pr_id TEXT; v_po_id TEXT; v_grn_id TEXT; v_pur_id TEXT;
  v_result JSONB;
BEGIN
  v_type := CASE v_type
    WHEN 'INV' THEN 'PUR' WHEN 'INVOICE' THEN 'PUR'
    WHEN 'GR' THEN 'GRN' WHEN 'PURCHASE_REQUEST' THEN 'PR'
    WHEN 'PURCHASE_ORDER' THEN 'PO' WHEN 'GOODS_RECEIPT' THEN 'GRN'
    WHEN 'PURCHASING' THEN 'PUR' ELSE v_type
  END;

  IF v_type NOT IN ('PR','PO','GRN','PUR') OR v_id IS NULL OR v_id = '' THEN
    RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
  END IF;

  WITH RECURSIVE g AS (
    SELECT source_type, source_id, target_type, target_id
    FROM document_flow
    WHERE (source_id = v_id AND source_type = v_type)
       OR (target_id = v_id AND target_type = v_type)
    UNION
    SELECT df.source_type, df.source_id, df.target_type, df.target_id
    FROM document_flow df
    JOIN g ON (g.target_id = df.source_id AND g.target_type = df.source_type)
    UNION
    SELECT df.source_type, df.source_id, df.target_type, df.target_id
    FROM document_flow df
    JOIN g ON (g.source_id = df.target_id AND g.source_type = df.target_type)
  ),
  all_ids AS (
    SELECT 'PR' AS doc_type, source_id AS doc_id FROM g WHERE source_type = 'PR'
    UNION SELECT 'PR', target_id FROM g WHERE target_type = 'PR'
    UNION SELECT 'PO', source_id FROM g WHERE source_type = 'PO'
    UNION SELECT 'PO', target_id FROM g WHERE target_type = 'PO'
    UNION SELECT 'GRN', source_id FROM g WHERE source_type = 'GRN'
    UNION SELECT 'GRN', target_id FROM g WHERE target_type = 'GRN'
    UNION SELECT 'PUR', source_id FROM g WHERE source_type = 'PUR'
    UNION SELECT 'PUR', target_id FROM g WHERE target_type = 'PUR'
  )
  SELECT
    (SELECT doc_id FROM all_ids WHERE doc_type = 'PR' LIMIT 1),
    (SELECT doc_id FROM all_ids WHERE doc_type = 'PO' LIMIT 1),
    (SELECT doc_id FROM all_ids WHERE doc_type = 'GRN' LIMIT 1),
    (SELECT doc_id FROM all_ids WHERE doc_type = 'PUR' LIMIT 1)
  INTO v_pr_id, v_po_id, v_grn_id, v_pur_id;

  -- Always include current document
  IF v_type = 'PR' THEN v_pr_id := COALESCE(v_pr_id, v_id); END IF;
  IF v_type = 'PO' THEN v_po_id := COALESCE(v_po_id, v_id); END IF;
  IF v_type = 'GRN' THEN v_grn_id := COALESCE(v_grn_id, v_id); END IF;
  IF v_type = 'PUR' THEN v_pur_id := COALESCE(v_pur_id, v_id); END IF;

  SELECT jsonb_build_object(
    'pr',  (SELECT jsonb_build_object('id', id, 'pr_number', pr_number, 'status', status) FROM purchase_requests WHERE id::TEXT = v_pr_id AND (deleted IS NOT TRUE) LIMIT 1),
    'po',  (SELECT jsonb_build_object('id', id, 'po_number', po_number, 'status', status) FROM purchase_orders WHERE id::TEXT = v_po_id AND (deleted IS NOT TRUE) LIMIT 1),
    'grn', (SELECT jsonb_build_object('id', id, 'grn_number', grn_number, 'status', status) FROM grn_inspections WHERE id::TEXT = v_grn_id AND (deleted IS NOT TRUE) LIMIT 1),
    'pur', (SELECT jsonb_build_object('id', id, 'purchasing_number', COALESCE(purchasing_number, 'PUR-'||id::TEXT), 'status', status) FROM purchasing_invoices WHERE id::TEXT = v_pur_id AND (deleted IS NOT TRUE) LIMIT 1)
  ) INTO v_result;

  RETURN COALESCE(v_result, jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL));
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trace_document_graph(TEXT, TEXT) TO authenticated, anon;

-- ============================================================================
-- PART 3 — PR LIST "LINKED PO(s)" COLUMN
-- ============================================================================

DROP VIEW IF EXISTS v_pr_linked_po_count CASCADE;
CREATE OR REPLACE VIEW v_pr_linked_po_count AS
SELECT pr_id, COUNT(DISTINCT po_id)::INT AS po_count
FROM pr_po_linkage
WHERE pr_id IS NOT NULL AND po_id IS NOT NULL
  AND (status = 'active' OR status IS NULL)
GROUP BY pr_id;

GRANT SELECT ON v_pr_linked_po_count TO authenticated, anon;

-- ============================================================================
-- DONE. Test:
--   SELECT fn_trace_document_graph('PR', '<pr_uuid>');
--   SELECT fn_trace_document_graph('PO', '84');
--   SELECT fn_trace_document_graph('GRN', '<grn_uuid>');
--   SELECT fn_trace_document_graph('PUR', '<pur_uuid>');
-- ============================================================================
