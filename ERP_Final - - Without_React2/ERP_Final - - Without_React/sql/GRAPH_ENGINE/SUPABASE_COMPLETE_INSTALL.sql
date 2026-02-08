-- ============================================================================
-- SUPABASE_COMPLETE_INSTALL.sql
-- SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE
-- COMPLETE INSTALLATION FILE FOR SUPABASE SQL EDITOR
-- 
-- Copy and paste this entire file into Supabase SQL Editor and run.
-- ============================================================================

-- ============================================================================
-- PART 1: RECURSIVE DOCUMENT GRAPH FUNCTIONS
-- ============================================================================

-- Drop existing functions
DROP FUNCTION IF EXISTS fn_recursive_document_graph(TEXT, UUID, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow_json(TEXT, TEXT) CASCADE;

-- FUNCTION 1: fn_recursive_document_graph - Core recursive engine
CREATE OR REPLACE FUNCTION fn_recursive_document_graph(
    p_input_type TEXT,
    p_input_uuid UUID DEFAULT NULL,
    p_input_bigint BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_start_type TEXT;
    v_start_id TEXT;
    v_result JSONB;
BEGIN
    v_start_type := UPPER(TRIM(COALESCE(p_input_type, '')));
    
    IF v_start_type IN ('PO', 'PURCHASE_ORDER') THEN
        v_start_type := 'PO';
        v_start_id := COALESCE(p_input_bigint::TEXT, p_input_uuid::TEXT);
    ELSIF v_start_type IN ('PR', 'PURCHASE_REQUEST') THEN
        v_start_type := 'PR';
        v_start_id := p_input_uuid::TEXT;
    ELSIF v_start_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN
        v_start_type := 'GRN';
        v_start_id := p_input_uuid::TEXT;
    ELSIF v_start_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN
        v_start_type := 'PUR';
        v_start_id := p_input_uuid::TEXT;
    ELSE
        RETURN jsonb_build_object(
            'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb,
            'error', 'Invalid document type: ' || COALESCE(p_input_type, 'NULL')
        );
    END IF;
    
    IF v_start_id IS NULL OR v_start_id = '' OR v_start_id = 'null' THEN
        RETURN jsonb_build_object(
            'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb,
            'error', 'Invalid document ID'
        );
    END IF;
    
    WITH RECURSIVE doc_graph(doc_type, doc_id, visited_path, depth) AS (
        SELECT v_start_type, v_start_id, ARRAY[v_start_type || ':' || v_start_id], 1
        UNION ALL
        SELECT neighbor.doc_type, neighbor.doc_id, g.visited_path || (neighbor.doc_type || ':' || neighbor.doc_id), g.depth + 1
        FROM doc_graph g
        CROSS JOIN LATERAL (
            -- PR → PO
            SELECT 'PO'::TEXT AS doc_type, l.po_id::TEXT AS doc_id
            FROM pr_po_linkage l WHERE g.doc_type = 'PR' AND l.pr_id::TEXT = g.doc_id AND l.po_id IS NOT NULL
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
            -- PO → PUR
            SELECT 'PUR'::TEXT, pi.id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'PO' AND pi.purchase_order_id::TEXT = g.doc_id AND pi.deleted = FALSE
            UNION ALL
            -- PUR → PO
            SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT FROM purchasing_invoices pi WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.purchase_order_id IS NOT NULL
        ) AS neighbor
        WHERE NOT (neighbor.doc_type || ':' || neighbor.doc_id) = ANY(g.visited_path)
          AND neighbor.doc_id IS NOT NULL AND neighbor.doc_id != '' AND g.depth < 20
    ),
    unique_docs AS (SELECT DISTINCT doc_type, doc_id FROM doc_graph)
    SELECT jsonb_build_object(
        'pr', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', pr.id, 
                'number', pr.pr_number, 
                'status', pr.status, 
                'date', pr.created_at, 
                'requester', pr.requester_name, 
                'department', pr.department, 
                'total_amount', COALESCE(pr.estimated_total_value, 0)
            ) ORDER BY pr.created_at) 
            FROM purchase_requests pr 
            WHERE pr.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR') 
            AND pr.deleted = FALSE
        ), '[]'::jsonb),
        'po', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', po.id, 
                'number', po.po_number, 
                'status', po.status, 
                'date', po.order_date, 
                'supplier', po.supplier_name, 
                'total_amount', COALESCE(po.total_amount, 0)
            ) ORDER BY po.order_date) 
            FROM purchase_orders po 
            WHERE po.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO') 
            AND po.deleted = FALSE
        ), '[]'::jsonb),
        'grn', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', gi.id, 
                'number', gi.grn_number, 
                'status', gi.status, 
                'date', gi.grn_date, 
                'received_by', gi.received_by, 
                'total_quantity', gi.total_received_quantity
            ) ORDER BY gi.grn_date) 
            FROM grn_inspections gi 
            WHERE gi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN') 
            AND gi.deleted = FALSE
        ), '[]'::jsonb),
        'pur', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', pi.id, 
                'number', pi.purchasing_number, 
                'status', pi.status, 
                'date', COALESCE(pi.invoice_date, pi.created_at), 
                'payment_status', pi.payment_status, 
                'grand_total', COALESCE(pi.grand_total, 0)
            ) ORDER BY COALESCE(pi.invoice_date, pi.created_at)) 
            FROM purchasing_invoices pi 
            WHERE pi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR') 
            AND pi.deleted = FALSE
        ), '[]'::jsonb),
        'start_type', v_start_type, 
        'start_id', v_start_id
    ) INTO v_result;
    
    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb, 'error', SQLERRM, 'start_type', v_start_type, 'start_id', v_start_id);
END;
$$;

-- FUNCTION 2: fn_get_document_flow - Legacy table format
CREATE OR REPLACE FUNCTION fn_get_document_flow(p_doc_type TEXT, p_doc_id TEXT)
RETURNS TABLE (doc_type TEXT, doc_id TEXT, doc_number TEXT, doc_status TEXT, doc_date TIMESTAMPTZ, is_current BOOLEAN, sequence_order INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_input_type TEXT; v_input_uuid UUID; v_input_bigint BIGINT; v_graph JSONB; v_current_type TEXT;
BEGIN
    v_input_type := UPPER(TRIM(p_doc_type));
    v_current_type := CASE 
        WHEN v_input_type IN ('PR', 'PURCHASE_REQUEST') THEN 'PR'
        WHEN v_input_type IN ('PO', 'PURCHASE_ORDER') THEN 'PO'
        WHEN v_input_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN 'GRN'
        WHEN v_input_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN 'PUR'
        ELSE v_input_type END;
    
    IF v_current_type = 'PO' THEN
        BEGIN v_input_bigint := p_doc_id::BIGINT; EXCEPTION WHEN OTHERS THEN v_input_uuid := p_doc_id::UUID; END;
    ELSE
        BEGIN v_input_uuid := p_doc_id::UUID; EXCEPTION WHEN OTHERS THEN v_input_bigint := p_doc_id::BIGINT; END;
    END IF;
    
    v_graph := fn_recursive_document_graph(v_current_type, v_input_uuid, v_input_bigint);
    
    IF jsonb_array_length(v_graph->'pr') > 0 THEN
        RETURN QUERY SELECT 'PR'::TEXT, (pr_doc->>'id')::TEXT, (pr_doc->>'number')::TEXT, (pr_doc->>'status')::TEXT, (pr_doc->>'date')::TIMESTAMPTZ, (v_current_type = 'PR'), 1 FROM jsonb_array_elements(v_graph->'pr') AS pr_doc LIMIT 1;
    ELSE RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1; END IF;
    
    IF jsonb_array_length(v_graph->'po') > 0 THEN
        RETURN QUERY SELECT 'PO'::TEXT, (po_doc->>'id')::TEXT, (po_doc->>'number')::TEXT, (po_doc->>'status')::TEXT, (po_doc->>'date')::TIMESTAMPTZ, (v_current_type = 'PO'), 2 FROM jsonb_array_elements(v_graph->'po') AS po_doc LIMIT 1;
    ELSE RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2; END IF;
    
    IF jsonb_array_length(v_graph->'grn') > 0 THEN
        RETURN QUERY SELECT 'GRN'::TEXT, (grn_doc->>'id')::TEXT, (grn_doc->>'number')::TEXT, (grn_doc->>'status')::TEXT, (grn_doc->>'date')::TIMESTAMPTZ, (v_current_type = 'GRN'), 3 FROM jsonb_array_elements(v_graph->'grn') AS grn_doc LIMIT 1;
    ELSE RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3; END IF;
    
    IF jsonb_array_length(v_graph->'pur') > 0 THEN
        RETURN QUERY SELECT 'PUR'::TEXT, (pur_doc->>'id')::TEXT, (pur_doc->>'number')::TEXT, (pur_doc->>'status')::TEXT, (pur_doc->>'date')::TIMESTAMPTZ, (v_current_type = 'PUR'), 4 FROM jsonb_array_elements(v_graph->'pur') AS pur_doc LIMIT 1;
    ELSE RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4; END IF;
    
    RETURN;
END;
$$;

-- FUNCTION 3: fn_get_document_flow_json - JSON wrapper
CREATE OR REPLACE FUNCTION fn_get_document_flow_json(p_doc_type TEXT, p_doc_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_input_type TEXT; v_input_uuid UUID; v_input_bigint BIGINT;
BEGIN
    v_input_type := UPPER(TRIM(p_doc_type));
    IF v_input_type IN ('PO', 'PURCHASE_ORDER') THEN
        BEGIN v_input_bigint := p_doc_id::BIGINT; EXCEPTION WHEN OTHERS THEN v_input_uuid := p_doc_id::UUID; END;
    ELSE
        BEGIN v_input_uuid := p_doc_id::UUID; EXCEPTION WHEN OTHERS THEN v_input_bigint := p_doc_id::BIGINT; END;
    END IF;
    RETURN fn_recursive_document_graph(v_input_type, v_input_uuid, v_input_bigint);
END;
$$;

-- ============================================================================
-- PART 2: ITEM FLOW VIEW (EKBE)
-- ============================================================================

DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_item_flow_simple CASCADE;

CREATE OR REPLACE VIEW v_item_flow_recursive AS
WITH 
pr_items AS (
    SELECT 
        pri.id AS pr_item_id, 
        pri.pr_id, 
        pr.pr_number, 
        pri.item_number AS pr_pos, 
        pri.item_id, 
        pri.item_name, 
        pri.item_code, 
        COALESCE(pri.quantity, 0) AS pr_qty, 
        pri.unit, 
        COALESCE(pri.estimated_price, 0) AS pr_price
    FROM purchase_request_items pri 
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND pr.deleted = FALSE
),
po_aggregation AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(ppl.converted_quantity, 0)) AS ordered_qty, 
        STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers, 
        COUNT(DISTINCT ppl.po_id) AS po_count
    FROM pr_po_linkage ppl 
    WHERE ppl.pr_item_id IS NOT NULL 
    GROUP BY ppl.pr_item_id
),
grn_aggregation AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(gii.received_quantity, 0)) AS received_qty, 
        STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers, 
        COUNT(DISTINCT gi.id) AS grn_count
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id 
        AND (poi.item_id = pri.item_id OR poi.item_name = pri.item_name)
    JOIN grn_inspection_items gii ON gii.po_item_id = poi.id
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    WHERE ppl.pr_item_id IS NOT NULL 
    GROUP BY ppl.pr_item_id
),
pur_aggregation AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(pii.quantity, 0)) AS invoiced_qty, 
        STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers, 
        COUNT(DISTINCT pi.id) AS pur_count
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoice_items pii ON pii.item_id = pri.item_id
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted = FALSE
    LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id AND gi.deleted = FALSE
    WHERE ppl.pr_item_id IS NOT NULL 
        AND (pi.purchase_order_id = ppl.po_id OR gi.purchase_order_id = ppl.po_id)
    GROUP BY ppl.pr_item_id
)
SELECT 
    p.pr_item_id, p.pr_id, p.pr_number, p.pr_pos, p.item_id, p.item_name, p.item_code, p.pr_qty, p.unit, p.pr_price,
    COALESCE(po.ordered_qty, 0) AS po_qty, 
    COALESCE(po.po_numbers, '') AS po_numbers, 
    COALESCE(po.po_count, 0) AS po_count,
    COALESCE(grn.received_qty, 0) AS grn_qty, 
    COALESCE(grn.grn_numbers, '') AS grn_numbers, 
    COALESCE(grn.grn_count, 0) AS grn_count,
    COALESCE(pur.invoiced_qty, 0) AS pur_qty, 
    COALESCE(pur.pur_numbers, '') AS pur_numbers, 
    COALESCE(pur.pur_count, 0) AS pur_count,
    GREATEST(0, p.pr_qty - COALESCE(po.ordered_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.ordered_qty, 0) - COALESCE(grn.received_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.received_qty, 0) - COALESCE(pur.invoiced_qty, 0)) AS remaining_grn,
    CASE
        WHEN COALESCE(po.ordered_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(po.ordered_qty, 0) > 0 AND COALESCE(grn.received_qty, 0) = 0 THEN 'Ordered'
        WHEN COALESCE(grn.received_qty, 0) > 0 AND COALESCE(grn.received_qty, 0) < COALESCE(po.ordered_qty, 0) THEN 'Partial Received'
        WHEN COALESCE(grn.received_qty, 0) >= COALESCE(po.ordered_qty, 0) AND COALESCE(pur.invoiced_qty, 0) = 0 THEN 'Fully Received'
        WHEN COALESCE(pur.invoiced_qty, 0) > 0 AND COALESCE(pur.invoiced_qty, 0) < COALESCE(grn.received_qty, 0) THEN 'Partial Invoiced'
        WHEN COALESCE(pur.invoiced_qty, 0) >= COALESCE(grn.received_qty, 0) AND COALESCE(grn.received_qty, 0) > 0 THEN 'Invoiced'
        ELSE 'Processing'
    END AS chain_status
FROM pr_items p
LEFT JOIN po_aggregation po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_aggregation grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_aggregation pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE VIEW v_item_flow_simple AS
SELECT pr_item_id, pr_id, pr_number, pr_pos, item_name, pr_qty, po_qty, grn_qty, pur_qty, remaining_po, chain_status 
FROM v_item_flow_recursive;

-- Item flow function
DROP FUNCTION IF EXISTS fn_get_item_flow(UUID);
CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (
    pr_item_id UUID, 
    pr_pos INT, 
    item_name TEXT, 
    pr_qty NUMERIC, 
    po_qty NUMERIC, 
    grn_qty NUMERIC, 
    pur_qty NUMERIC, 
    remaining_po NUMERIC, 
    chain_status TEXT, 
    po_numbers TEXT, 
    grn_numbers TEXT, 
    pur_numbers TEXT
)
LANGUAGE SQL SECURITY DEFINER SET search_path = public
AS $$ 
    SELECT 
        v.pr_item_id, 
        v.pr_pos, 
        v.item_name, 
        v.pr_qty, 
        v.po_qty, 
        v.grn_qty, 
        v.pur_qty, 
        v.remaining_po, 
        v.chain_status, 
        v.po_numbers, 
        v.grn_numbers, 
        v.pur_numbers 
    FROM v_item_flow_recursive v 
    WHERE v.pr_id = p_pr_id 
    ORDER BY v.pr_pos; 
$$;

-- ============================================================================
-- PART 3: PERFORMANCE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_purchase_order_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_po_item_id ON grn_inspection_items(po_item_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_purchase_order_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_invoice_id ON purchasing_invoice_items(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_item_id ON purchasing_invoice_items(item_id);

-- ============================================================================
-- PART 4: GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION fn_recursive_document_graph(TEXT, UUID, BIGINT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;
GRANT SELECT ON v_item_flow_simple TO authenticated, anon;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'Functions created:' AS status, COUNT(*) AS count 
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname IN ('fn_recursive_document_graph', 'fn_get_document_flow', 'fn_get_document_flow_json', 'fn_get_item_flow');

SELECT 'Views created:' AS status, COUNT(*) AS count 
FROM pg_views 
WHERE schemaname = 'public' 
AND viewname IN ('v_item_flow_recursive', 'v_item_flow_simple');

SELECT 'INSTALLATION COMPLETE!' AS message;
