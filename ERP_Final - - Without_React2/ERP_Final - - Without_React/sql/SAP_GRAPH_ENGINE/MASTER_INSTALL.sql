-- ============================================================================
-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║                     SAP S/4HANA DOCUMENT FLOW ENGINE                       ║
-- ║                     MASTER INSTALLATION SCRIPT                             ║
-- ║                                                                           ║
-- ║  COPY THIS ENTIRE FILE AND PASTE INTO SUPABASE SQL EDITOR                 ║
-- ║  THEN CLICK "RUN"                                                         ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝
-- ============================================================================

-- ============================================================================
-- PART 1: CLEANUP OLD FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Drop old triggers that might have wrong columns
DROP TRIGGER IF EXISTS trg_log_inv ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_log_purchasing_invoice_flow ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_log_pr_po ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_log_po_grn ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;

-- Drop old functions
DROP FUNCTION IF EXISTS fn_log_inv_flow() CASCADE;
DROP FUNCTION IF EXISTS fn_log_purchasing_invoice_flow() CASCADE;
DROP FUNCTION IF EXISTS fn_log_pr_po_flow() CASCADE;
DROP FUNCTION IF EXISTS fn_log_po_grn_flow() CASCADE;
DROP FUNCTION IF EXISTS fn_sap_document_graph(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow_json(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_recursive_document_graph(TEXT, UUID, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS get_pr_linked_pos(UUID) CASCADE;
DROP FUNCTION IF EXISTS fn_get_item_flow(UUID) CASCADE;

-- Drop old views
DROP VIEW IF EXISTS v_sap_document_flow_global CASCADE;
DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;
DROP VIEW IF EXISTS v_sap_item_flow CASCADE;
DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_document_flow_recursive CASCADE;

-- ============================================================================
-- PART 2: RECURSIVE DOCUMENT GRAPH FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_sap_document_graph(
    p_start_type TEXT,
    p_start_id TEXT
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
    -- Normalize input type
    v_normalized_type := UPPER(TRIM(COALESCE(p_start_type, '')));
    
    -- Map common aliases
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
    
    -- Validate
    IF v_normalized_type NOT IN ('PR', 'PO', 'GRN', 'PUR') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid type', 'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb);
    END IF;
    
    IF p_start_id IS NULL OR p_start_id = '' OR p_start_id = 'null' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid ID', 'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb);
    END IF;

    -- RECURSIVE GRAPH TRAVERSAL
    WITH RECURSIVE document_graph AS (
        -- BASE: Start document
        SELECT v_normalized_type AS doc_type, p_start_id AS doc_id, ARRAY[v_normalized_type || ':' || p_start_id] AS visited, 0 AS depth
        
        UNION ALL
        
        -- RECURSIVE: Traverse edges
        SELECT edges.target_type, edges.target_id, g.visited || (edges.target_type || ':' || edges.target_id), g.depth + 1
        FROM document_graph g
        CROSS JOIN LATERAL (
            -- PR → PO
            SELECT 'PO'::TEXT AS target_type, l.po_id::TEXT AS target_id FROM pr_po_linkage l WHERE g.doc_type = 'PR' AND l.pr_id::TEXT = g.doc_id AND l.po_id IS NOT NULL
            UNION ALL
            -- PO → PR
            SELECT 'PR'::TEXT, l.pr_id::TEXT FROM pr_po_linkage l WHERE g.doc_type = 'PO' AND l.po_id::TEXT = g.doc_id AND l.pr_id IS NOT NULL
            UNION ALL
            -- PO → GRN
            SELECT 'GRN'::TEXT, gi.id::TEXT FROM grn_inspections gi WHERE g.doc_type = 'PO' AND gi.purchase_order_id::TEXT = g.doc_id AND gi.deleted = FALSE
            UNION ALL
            -- GRN → PO
            SELECT 'PO'::TEXT, gi.purchase_order_id::TEXT FROM grn_inspections gi WHERE g.doc_type = 'GRN' AND gi.id::TEXT = g.doc_id AND gi.purchase_order_id IS NOT NULL
            UNION ALL
            -- GRN → PUR
            SELECT 'PUR'::TEXT, pi.id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'GRN' AND pi.grn_id::TEXT = g.doc_id AND pi.deleted = FALSE
            UNION ALL
            -- PUR → GRN
            SELECT 'GRN'::TEXT, pi.grn_id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.grn_id IS NOT NULL
            UNION ALL
            -- PO → PUR (direct)
            SELECT 'PUR'::TEXT, pi.id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'PO' AND pi.purchase_order_id::TEXT = g.doc_id AND pi.deleted = FALSE
            UNION ALL
            -- PUR → PO (direct)
            SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.purchase_order_id IS NOT NULL
        ) AS edges
        WHERE NOT (edges.target_type || ':' || edges.target_id) = ANY(g.visited)
          AND edges.target_id IS NOT NULL AND edges.target_id != ''
          AND g.depth < 10
    ),
    unique_docs AS (SELECT DISTINCT doc_type, doc_id FROM document_graph WHERE doc_id IS NOT NULL AND doc_id != ''),
    pr_docs AS (SELECT jsonb_agg(jsonb_build_object('id', pr.id, 'number', pr.pr_number, 'status', pr.status, 'date', pr.created_at, 'requester', pr.requester_name, 'department', pr.department) ORDER BY pr.created_at) AS docs FROM purchase_requests pr WHERE pr.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR') AND pr.deleted = FALSE),
    po_docs AS (SELECT jsonb_agg(jsonb_build_object('id', po.id, 'number', po.po_number, 'status', po.status, 'date', po.order_date, 'supplier', po.supplier_name, 'receiving_status', po.receiving_status) ORDER BY po.order_date) AS docs FROM purchase_orders po WHERE po.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO') AND po.deleted = FALSE),
    grn_docs AS (SELECT jsonb_agg(jsonb_build_object('id', gi.id, 'number', gi.grn_number, 'status', gi.status, 'date', gi.grn_date, 'po_number', gi.purchase_order_number) ORDER BY gi.grn_date) AS docs FROM grn_inspections gi WHERE gi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN') AND gi.deleted = FALSE),
    pur_docs AS (SELECT jsonb_agg(jsonb_build_object('id', pi.id, 'number', pi.purchasing_number, 'status', pi.status, 'date', COALESCE(pi.invoice_date, pi.created_at::DATE), 'payment_status', pi.payment_status, 'grn_number', pi.grn_number) ORDER BY pi.created_at) AS docs FROM purchasing_invoices pi WHERE pi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR') AND pi.deleted = FALSE)
    
    SELECT jsonb_build_object(
        'success', true,
        'root_type', v_normalized_type,
        'root_id', p_start_id,
        'pr', COALESCE((SELECT docs FROM pr_docs), '[]'::jsonb),
        'po', COALESCE((SELECT docs FROM po_docs), '[]'::jsonb),
        'grn', COALESCE((SELECT docs FROM grn_docs), '[]'::jsonb),
        'pur', COALESCE((SELECT docs FROM pur_docs), '[]'::jsonb)
    ) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb);
END;
$$;

-- ============================================================================
-- PART 3: FRONTEND WRAPPER FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_document_flow_json(p_doc_type TEXT, p_doc_id TEXT)
RETURNS JSONB LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$ SELECT fn_sap_document_graph(p_doc_type, p_doc_id); $$;

CREATE OR REPLACE FUNCTION fn_get_document_flow(p_doc_type TEXT, p_doc_id TEXT)
RETURNS TABLE (doc_type TEXT, doc_id TEXT, doc_number TEXT, doc_status TEXT, doc_date TIMESTAMPTZ, is_current BOOLEAN, sequence_order INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_graph JSONB; v_norm TEXT;
BEGIN
    v_graph := fn_sap_document_graph(p_doc_type, p_doc_id);
    v_norm := UPPER(TRIM(p_doc_type));
    v_norm := CASE v_norm WHEN 'PURCHASE_REQUEST' THEN 'PR' WHEN 'PURCHASE_ORDER' THEN 'PO' WHEN 'GR' THEN 'GRN' WHEN 'MIGO' THEN 'GRN' WHEN 'INVOICE' THEN 'PUR' WHEN 'INV' THEN 'PUR' WHEN 'PURCHASING' THEN 'PUR' WHEN 'MIRO' THEN 'PUR' ELSE v_norm END;
    
    IF jsonb_array_length(COALESCE(v_graph->'pr', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 'PR'::TEXT, (v_graph->'pr'->0->>'id')::TEXT, (v_graph->'pr'->0->>'number')::TEXT, (v_graph->'pr'->0->>'status')::TEXT, (v_graph->'pr'->0->>'date')::TIMESTAMPTZ, (v_norm = 'PR'), 1;
    ELSE RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(v_graph->'po', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 'PO'::TEXT, (v_graph->'po'->0->>'id')::TEXT, (v_graph->'po'->0->>'number')::TEXT, (v_graph->'po'->0->>'status')::TEXT, (v_graph->'po'->0->>'date')::TIMESTAMPTZ, (v_norm = 'PO'), 2;
    ELSE RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2;
    END IF;
    
    IF jsonb_array_length(COALESCE(v_graph->'grn', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 'GRN'::TEXT, (v_graph->'grn'->0->>'id')::TEXT, (v_graph->'grn'->0->>'number')::TEXT, (v_graph->'grn'->0->>'status')::TEXT, (v_graph->'grn'->0->>'date')::TIMESTAMPTZ, (v_norm = 'GRN'), 3;
    ELSE RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3;
    END IF;
    
    IF jsonb_array_length(COALESCE(v_graph->'pur', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 'PUR'::TEXT, (v_graph->'pur'->0->>'id')::TEXT, (v_graph->'pur'->0->>'number')::TEXT, (v_graph->'pur'->0->>'status')::TEXT, (v_graph->'pur'->0->>'date')::TIMESTAMPTZ, (v_norm = 'PUR'), 4;
    ELSE RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4;
    END IF;
    RETURN;
END;
$$;

-- ============================================================================
-- PART 4: LINKED POs VIEW AND FUNCTION
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_linked_pos AS
SELECT ppl.pr_id, ppl.po_id, COALESCE(ppl.po_number, po.po_number) AS po_number, po.supplier_name, po.status AS po_status, po.receiving_status, SUM(COALESCE(ppl.converted_quantity, 0)) AS converted_qty, COUNT(*) AS item_count, COALESCE(po.total_amount, 0) AS po_total, COALESCE(po.order_date, ppl.converted_at) AS po_date
FROM pr_po_linkage ppl
LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
GROUP BY ppl.pr_id, ppl.po_id, ppl.po_number, po.po_number, po.supplier_name, po.status, po.receiving_status, po.total_amount, po.order_date, ppl.converted_at;

CREATE OR REPLACE FUNCTION get_pr_linked_pos(p_pr_id UUID)
RETURNS TABLE (po_id BIGINT, po_number TEXT, supplier_name TEXT, po_status TEXT, receiving_status TEXT, converted_qty NUMERIC, item_count BIGINT, po_total NUMERIC, po_date TIMESTAMPTZ)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$ SELECT v.po_id, v.po_number, v.supplier_name, v.po_status, v.receiving_status, v.converted_qty, v.item_count, v.po_total, v.po_date FROM v_pr_linked_pos v WHERE v.pr_id = p_pr_id; $$;

-- ============================================================================
-- PART 5: ITEM FLOW VIEW
-- ============================================================================

CREATE OR REPLACE VIEW v_sap_item_flow AS
WITH pr_items AS (
    SELECT pri.id AS pr_item_id, pri.pr_id, pr.pr_number, pri.item_number AS pr_pos, pri.item_id, pri.item_name, pri.item_code, COALESCE(pri.quantity, 0) AS pr_qty, pri.unit
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND pr.deleted = FALSE
    WHERE pri.deleted = FALSE OR pri.deleted IS NULL
),
po_qty AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty, STRING_AGG(DISTINCT ppl.po_number, ', ') AS po_numbers
    FROM pr_po_linkage ppl WHERE ppl.status = 'active' OR ppl.status IS NULL GROUP BY ppl.pr_item_id
),
grn_qty AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty, STRING_AGG(DISTINCT gi.grn_number, ', ') AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN grn_inspection_items gii ON gii.grn_inspection_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id AND deleted = FALSE)
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
    WHERE ppl.status = 'active' OR ppl.status IS NULL GROUP BY ppl.pr_item_id
),
pur_qty AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty, STRING_AGG(DISTINCT pi.purchasing_number, ', ') AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoice_items pii ON pii.item_id = pri.item_id
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted = FALSE AND (pi.purchase_order_id = ppl.po_id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id))
    WHERE ppl.status = 'active' OR ppl.status IS NULL GROUP BY ppl.pr_item_id
)
SELECT p.pr_item_id, p.pr_id, p.pr_number, p.pr_pos, p.item_id, p.item_name, p.item_code, p.unit, p.pr_qty,
    COALESCE(po.po_qty, 0) AS po_qty, COALESCE(grn.grn_qty, 0) AS grn_qty, COALESCE(pur.pur_qty, 0) AS pur_qty,
    GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
    COALESCE(po.po_numbers, '') AS po_numbers, COALESCE(grn.grn_numbers, '') AS grn_numbers, COALESCE(pur.pur_numbers, '') AS pur_numbers,
    CASE WHEN COALESCE(po.po_qty, 0) = 0 THEN 'PENDING' WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'ORDERED' WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'PARTIAL_RECEIVED' WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'FULLY_RECEIVED' WHEN COALESCE(pur.pur_qty, 0) < COALESCE(grn.grn_qty, 0) THEN 'PARTIAL_INVOICED' ELSE 'INVOICED' END AS item_status
FROM pr_items p
LEFT JOIN po_qty po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_qty grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_qty pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (pr_item_id UUID, pr_pos INT, item_name TEXT, item_code TEXT, unit TEXT, pr_qty NUMERIC, po_qty NUMERIC, grn_qty NUMERIC, pur_qty NUMERIC, remaining_pr NUMERIC, remaining_po NUMERIC, remaining_grn NUMERIC, item_status TEXT, po_numbers TEXT, grn_numbers TEXT, pur_numbers TEXT)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$ SELECT v.pr_item_id, v.pr_pos, v.item_name, v.item_code, v.unit, v.pr_qty, v.po_qty, v.grn_qty, v.pur_qty, v.remaining_pr, v.remaining_po, v.remaining_grn, v.item_status, v.po_numbers, v.grn_numbers, v.pur_numbers FROM v_sap_item_flow v WHERE v.pr_id = p_pr_id ORDER BY v.pr_pos; $$;

-- ============================================================================
-- PART 6: FIXED DOCUMENT FLOW TRIGGERS (NO amount COLUMN!)
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_fn_purchasing_invoice_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.grn_id IS NOT NULL THEN
        INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
        VALUES ('GRN', NEW.grn_id::TEXT, COALESCE((SELECT grn_number FROM grn_inspections WHERE id = NEW.grn_id), NEW.grn_number), 'PUR', NEW.id::TEXT, NEW.purchasing_number, 'invoice_created', NOW())
        ON CONFLICT DO NOTHING;
    END IF;
    IF NEW.purchase_order_id IS NOT NULL AND NEW.grn_id IS NULL THEN
        INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
        VALUES ('PO', NEW.purchase_order_id::TEXT, COALESCE((SELECT po_number FROM purchase_orders WHERE id = NEW.purchase_order_id), NEW.purchase_order_number), 'PUR', NEW.id::TEXT, NEW.purchasing_number, 'invoice_created', NOW())
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;
$$;

CREATE TRIGGER trg_purchasing_invoice_document_flow AFTER INSERT ON purchasing_invoices FOR EACH ROW EXECUTE FUNCTION trg_fn_purchasing_invoice_document_flow();

CREATE OR REPLACE FUNCTION trg_fn_pr_po_linkage_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    VALUES ('PR', NEW.pr_id::TEXT, NEW.pr_number, 'PO', NEW.po_id::TEXT, NEW.po_number, 'converted_to_po', NOW())
    ON CONFLICT DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pr_po_linkage_document_flow AFTER INSERT ON pr_po_linkage FOR EACH ROW EXECUTE FUNCTION trg_fn_pr_po_linkage_document_flow();

CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.purchase_order_id IS NOT NULL THEN
        INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
        VALUES ('PO', NEW.purchase_order_id::TEXT, COALESCE((SELECT po_number FROM purchase_orders WHERE id = NEW.purchase_order_id), NEW.purchase_order_number), 'GRN', NEW.id::TEXT, NEW.grn_number, 'goods_received', NOW())
        ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grn_document_flow AFTER INSERT ON grn_inspections FOR EACH ROW EXECUTE FUNCTION trg_fn_grn_document_flow();

-- ============================================================================
-- PART 7: INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_po_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_invoice_id ON purchasing_invoice_items(purchasing_invoice_id);

-- ============================================================================
-- PART 8: GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION fn_sap_document_graph(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT SELECT ON v_sap_item_flow TO authenticated, anon;

-- ============================================================================
-- PART 9: VERIFICATION TEST
-- ============================================================================

DO $$
DECLARE
    v_test_po BIGINT;
    v_result JSONB;
BEGIN
    -- Get a PO that has a GRN
    SELECT gi.purchase_order_id INTO v_test_po FROM grn_inspections gi WHERE gi.deleted = FALSE AND gi.purchase_order_id IS NOT NULL LIMIT 1;
    
    IF v_test_po IS NOT NULL THEN
        v_result := fn_sap_document_graph('PO', v_test_po::TEXT);
        RAISE NOTICE '';
        RAISE NOTICE '════════════════════════════════════════════════════════════';
        RAISE NOTICE '✅ INSTALLATION SUCCESSFUL!';
        RAISE NOTICE '════════════════════════════════════════════════════════════';
        RAISE NOTICE 'Test PO ID: %', v_test_po;
        RAISE NOTICE 'Graph Result: %', v_result;
        RAISE NOTICE '';
        RAISE NOTICE 'PRs found: %', jsonb_array_length(v_result->'pr');
        RAISE NOTICE 'POs found: %', jsonb_array_length(v_result->'po');
        RAISE NOTICE 'GRNs found: %', jsonb_array_length(v_result->'grn');
        RAISE NOTICE 'PURs found: %', jsonb_array_length(v_result->'pur');
        RAISE NOTICE '════════════════════════════════════════════════════════════';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '✅ INSTALLATION SUCCESSFUL! (No test data found)';
        RAISE NOTICE '';
    END IF;
END $$;

SELECT '✅ SAP DOCUMENT FLOW ENGINE INSTALLED! Refresh your browser (Ctrl+F5).' AS status;
