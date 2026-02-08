-- ============================================================================
-- 01_RECURSIVE_DOCUMENT_GRAPH.sql
-- SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE
-- 
-- CRITICAL: This is the MASTER TRUTH for document flow
-- Uses WITH RECURSIVE CTE for true graph traversal
-- NEVER depends on document_flow table - uses relational tables directly
-- 
-- Supports: PR ↔ PO ↔ GRN ↔ PUR (many-to-many)
-- ============================================================================

-- Drop existing functions to ensure clean slate
DROP FUNCTION IF EXISTS fn_recursive_document_graph(TEXT, UUID, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow_json(TEXT, TEXT) CASCADE;

-- ============================================================================
-- FUNCTION 1: fn_recursive_document_graph
-- Core recursive engine - returns JSONB with arrays for all doc types
-- ============================================================================
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
    -- Normalize input type
    v_start_type := UPPER(TRIM(COALESCE(p_input_type, '')));
    
    -- Determine start node ID based on type
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
        -- Return empty result for invalid input
        RETURN jsonb_build_object(
            'pr', '[]'::jsonb,
            'po', '[]'::jsonb,
            'grn', '[]'::jsonb,
            'pur', '[]'::jsonb,
            'error', 'Invalid document type: ' || COALESCE(p_input_type, 'NULL')
        );
    END IF;
    
    -- Validate start ID
    IF v_start_id IS NULL OR v_start_id = '' OR v_start_id = 'null' THEN
        RETURN jsonb_build_object(
            'pr', '[]'::jsonb,
            'po', '[]'::jsonb,
            'grn', '[]'::jsonb,
            'pur', '[]'::jsonb,
            'error', 'Invalid document ID'
        );
    END IF;
    
    -- ========================================================================
    -- RECURSIVE CTE: Traverse the document graph
    -- ========================================================================
    WITH RECURSIVE doc_graph(doc_type, doc_id, visited_path, depth) AS (
        -- Base Case: Start from the input document
        SELECT 
            v_start_type,
            v_start_id,
            ARRAY[v_start_type || ':' || v_start_id],
            1
        
        UNION ALL
        
        -- Recursive Case: Find all connected documents
        SELECT 
            neighbor.doc_type,
            neighbor.doc_id,
            g.visited_path || (neighbor.doc_type || ':' || neighbor.doc_id),
            g.depth + 1
        FROM doc_graph g
        CROSS JOIN LATERAL (
            -- ================================================
            -- EDGE: PR → PO (via pr_po_linkage)
            -- ================================================
            SELECT 'PO'::TEXT AS doc_type, l.po_id::TEXT AS doc_id
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PR'
              AND l.pr_id::TEXT = g.doc_id
              AND l.po_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================
            -- EDGE: PO → PR (via pr_po_linkage - reverse)
            -- ================================================
            SELECT 'PR'::TEXT AS doc_type, l.pr_id::TEXT AS doc_id
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PO'
              AND l.po_id::TEXT = g.doc_id
              AND l.pr_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================
            -- EDGE: PO → GRN (via grn_inspections.purchase_order_id)
            -- ================================================
            SELECT 'GRN'::TEXT AS doc_type, gi.id::TEXT AS doc_id
            FROM grn_inspections gi
            WHERE g.doc_type = 'PO'
              AND gi.purchase_order_id::TEXT = g.doc_id
              AND gi.deleted = FALSE
            
            UNION ALL
            
            -- ================================================
            -- EDGE: GRN → PO (via grn_inspections.purchase_order_id - reverse)
            -- ================================================
            SELECT 'PO'::TEXT AS doc_type, gi.purchase_order_id::TEXT AS doc_id
            FROM grn_inspections gi
            WHERE g.doc_type = 'GRN'
              AND gi.id::TEXT = g.doc_id
              AND gi.purchase_order_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================
            -- EDGE: GRN → PUR (via purchasing_invoices.grn_id)
            -- ================================================
            SELECT 'PUR'::TEXT AS doc_type, pi.id::TEXT AS doc_id
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'GRN'
              AND pi.grn_id::TEXT = g.doc_id
              AND pi.deleted = FALSE
            
            UNION ALL
            
            -- ================================================
            -- EDGE: PUR → GRN (via purchasing_invoices.grn_id - reverse)
            -- ================================================
            SELECT 'GRN'::TEXT AS doc_type, pi.grn_id::TEXT AS doc_id
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR'
              AND pi.id::TEXT = g.doc_id
              AND pi.grn_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================
            -- EDGE: PO → PUR (via purchasing_invoices.purchase_order_id - direct invoice)
            -- ================================================
            SELECT 'PUR'::TEXT AS doc_type, pi.id::TEXT AS doc_id
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PO'
              AND pi.purchase_order_id::TEXT = g.doc_id
              AND pi.deleted = FALSE
            
            UNION ALL
            
            -- ================================================
            -- EDGE: PUR → PO (via purchasing_invoices.purchase_order_id - reverse)
            -- ================================================
            SELECT 'PO'::TEXT AS doc_type, pi.purchase_order_id::TEXT AS doc_id
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR'
              AND pi.id::TEXT = g.doc_id
              AND pi.purchase_order_id IS NOT NULL
              
        ) AS neighbor
        WHERE NOT (neighbor.doc_type || ':' || neighbor.doc_id) = ANY(g.visited_path)  -- Prevent cycles
          AND neighbor.doc_id IS NOT NULL
          AND neighbor.doc_id != ''
          AND g.depth < 20  -- Safety limit
    ),
    -- Get unique document IDs by type
    unique_docs AS (
        SELECT DISTINCT doc_type, doc_id FROM doc_graph
    )
    -- Build the final JSON result
    SELECT jsonb_build_object(
        'pr', COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'id', pr.id,
                    'number', pr.pr_number,
                    'status', pr.status,
                    'date', pr.created_at,
                    'requester', pr.requester_name,
                    'department', pr.department,
                    'total_amount', COALESCE(pr.estimated_total_value, 0)
                ) ORDER BY pr.created_at
            )
            FROM purchase_requests pr
            WHERE pr.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR')
              AND pr.deleted = FALSE),
            '[]'::jsonb
        ),
        'po', COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'id', po.id,
                    'number', po.po_number,
                    'status', po.status,
                    'date', po.order_date,
                    'supplier', po.supplier_name,
                    'total_amount', COALESCE(po.total_amount, 0)
                ) ORDER BY po.order_date
            )
            FROM purchase_orders po
            WHERE po.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO')
              AND po.deleted = FALSE),
            '[]'::jsonb
        ),
        'grn', COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'id', gi.id,
                    'number', gi.grn_number,
                    'status', gi.status,
                    'date', gi.grn_date,
                    'received_by', gi.received_by,
                    'total_quantity', gi.total_received_quantity
                ) ORDER BY gi.grn_date
            )
            FROM grn_inspections gi
            WHERE gi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN')
              AND gi.deleted = FALSE),
            '[]'::jsonb
        ),
        'pur', COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'id', pi.id,
                    'number', pi.purchasing_number,
                    'status', pi.status,
                    'date', COALESCE(pi.invoice_date, pi.created_at),
                    'payment_status', pi.payment_status,
                    'grand_total', COALESCE(pi.grand_total, 0)
                ) ORDER BY COALESCE(pi.invoice_date, pi.created_at)
            )
            FROM purchasing_invoices pi
            WHERE pi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR')
              AND pi.deleted = FALSE),
            '[]'::jsonb
        ),
        'start_type', v_start_type,
        'start_id', v_start_id
    ) INTO v_result;
    
    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'pr', '[]'::jsonb,
        'po', '[]'::jsonb,
        'grn', '[]'::jsonb,
        'pur', '[]'::jsonb,
        'error', SQLERRM,
        'start_type', v_start_type,
        'start_id', v_start_id
    );
END;
$$;

-- ============================================================================
-- FUNCTION 2: fn_get_document_flow
-- Legacy-compatible wrapper - returns TABLE format for backward compatibility
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_document_flow(
    p_doc_type TEXT,
    p_doc_id TEXT
)
RETURNS TABLE (
    doc_type TEXT,
    doc_id TEXT,
    doc_number TEXT,
    doc_status TEXT,
    doc_date TIMESTAMPTZ,
    is_current BOOLEAN,
    sequence_order INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_input_type TEXT;
    v_input_uuid UUID;
    v_input_bigint BIGINT;
    v_graph JSONB;
    v_current_type TEXT;
BEGIN
    -- Normalize input type
    v_input_type := UPPER(TRIM(p_doc_type));
    v_current_type := CASE 
        WHEN v_input_type IN ('PR', 'PURCHASE_REQUEST') THEN 'PR'
        WHEN v_input_type IN ('PO', 'PURCHASE_ORDER') THEN 'PO'
        WHEN v_input_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN 'GRN'
        WHEN v_input_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN 'PUR'
        ELSE v_input_type
    END;
    
    -- Parse the ID based on type
    IF v_current_type = 'PO' THEN
        BEGIN
            v_input_bigint := p_doc_id::BIGINT;
        EXCEPTION WHEN OTHERS THEN
            v_input_uuid := p_doc_id::UUID;
        END;
    ELSE
        BEGIN
            v_input_uuid := p_doc_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_input_bigint := p_doc_id::BIGINT;
        END;
    END IF;
    
    -- Get the recursive graph
    v_graph := fn_recursive_document_graph(v_current_type, v_input_uuid, v_input_bigint);
    
    -- Return PR (sequence 1)
    IF jsonb_array_length(v_graph->'pr') > 0 THEN
        RETURN QUERY
        SELECT 
            'PR'::TEXT,
            (pr_doc->>'id')::TEXT,
            (pr_doc->>'number')::TEXT,
            (pr_doc->>'status')::TEXT,
            (pr_doc->>'date')::TIMESTAMPTZ,
            (v_current_type = 'PR'),
            1
        FROM jsonb_array_elements(v_graph->'pr') AS pr_doc
        LIMIT 1;  -- Take first for legacy compatibility
    ELSE
        RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1;
    END IF;
    
    -- Return PO (sequence 2)
    IF jsonb_array_length(v_graph->'po') > 0 THEN
        RETURN QUERY
        SELECT 
            'PO'::TEXT,
            (po_doc->>'id')::TEXT,
            (po_doc->>'number')::TEXT,
            (po_doc->>'status')::TEXT,
            (po_doc->>'date')::TIMESTAMPTZ,
            (v_current_type = 'PO'),
            2
        FROM jsonb_array_elements(v_graph->'po') AS po_doc
        LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2;
    END IF;
    
    -- Return GRN (sequence 3)
    IF jsonb_array_length(v_graph->'grn') > 0 THEN
        RETURN QUERY
        SELECT 
            'GRN'::TEXT,
            (grn_doc->>'id')::TEXT,
            (grn_doc->>'number')::TEXT,
            (grn_doc->>'status')::TEXT,
            (grn_doc->>'date')::TIMESTAMPTZ,
            (v_current_type = 'GRN'),
            3
        FROM jsonb_array_elements(v_graph->'grn') AS grn_doc
        LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3;
    END IF;
    
    -- Return PUR (sequence 4)
    IF jsonb_array_length(v_graph->'pur') > 0 THEN
        RETURN QUERY
        SELECT 
            'PUR'::TEXT,
            (pur_doc->>'id')::TEXT,
            (pur_doc->>'number')::TEXT,
            (pur_doc->>'status')::TEXT,
            (pur_doc->>'date')::TIMESTAMPTZ,
            (v_current_type = 'PUR'),
            4
        FROM jsonb_array_elements(v_graph->'pur') AS pur_doc
        LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4;
    END IF;
    
    RETURN;
END;
$$;

-- ============================================================================
-- FUNCTION 3: fn_get_document_flow_json
-- Returns full JSON with arrays (for frontend that supports multiple docs)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_document_flow_json(
    p_doc_type TEXT,
    p_doc_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_input_type TEXT;
    v_input_uuid UUID;
    v_input_bigint BIGINT;
BEGIN
    v_input_type := UPPER(TRIM(p_doc_type));
    
    IF v_input_type IN ('PO', 'PURCHASE_ORDER') THEN
        BEGIN
            v_input_bigint := p_doc_id::BIGINT;
        EXCEPTION WHEN OTHERS THEN
            v_input_uuid := p_doc_id::UUID;
        END;
    ELSE
        BEGIN
            v_input_uuid := p_doc_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_input_bigint := p_doc_id::BIGINT;
        END;
    END IF;
    
    RETURN fn_recursive_document_graph(v_input_type, v_input_uuid, v_input_bigint);
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
GRANT EXECUTE ON FUNCTION fn_recursive_document_graph(TEXT, UUID, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_recursive_document_graph(TEXT, UUID, BIGINT) TO anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO anon;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON FUNCTION fn_recursive_document_graph IS 
'SAP VBFA-grade recursive document graph engine. 
Returns JSONB with arrays for all connected documents (PR, PO, GRN, PUR).
Uses WITH RECURSIVE CTE for true graph traversal - NOT static joins.
Supports many-to-many relationships.';

COMMENT ON FUNCTION fn_get_document_flow IS 
'Legacy-compatible document flow function. Returns TABLE format with one document per type.
Internally uses fn_recursive_document_graph for recursive traversal.';

COMMENT ON FUNCTION fn_get_document_flow_json IS 
'JSON wrapper for document flow. Returns full JSONB with arrays for frontend use.';

-- ============================================================================
-- TEST QUERIES
-- ============================================================================
/*
-- Test from PR
SELECT * FROM fn_get_document_flow('PR', 'your-pr-uuid-here');
SELECT fn_get_document_flow_json('PR', 'your-pr-uuid-here');
SELECT fn_recursive_document_graph('PR', 'your-pr-uuid-here'::UUID, NULL);

-- Test from PO
SELECT * FROM fn_get_document_flow('PO', '70');
SELECT fn_get_document_flow_json('PO', '70');
SELECT fn_recursive_document_graph('PO', NULL, 70);

-- Test from GRN
SELECT * FROM fn_get_document_flow('GRN', 'your-grn-uuid-here');
SELECT fn_get_document_flow_json('GRN', 'your-grn-uuid-here');

-- Test from PUR
SELECT * FROM fn_get_document_flow('PUR', 'your-pur-uuid-here');
SELECT fn_get_document_flow_json('PUR', 'your-pur-uuid-here');
*/
