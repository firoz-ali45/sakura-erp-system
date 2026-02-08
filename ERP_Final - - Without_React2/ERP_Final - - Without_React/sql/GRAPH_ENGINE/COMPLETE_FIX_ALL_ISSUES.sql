-- ============================================================================
-- COMPLETE_FIX_ALL_ISSUES.sql
-- FIXES ALL DOCUMENT FLOW AND LINKED POS ISSUES
-- 
-- Run this file in Supabase SQL Editor to fix:
-- 1. Document Flow not showing (fn_get_document_flow_json not working)
-- 2. PR Linked POs not showing (get_pr_linked_pos function missing)
-- 3. Purchasing module errors (tables need to exist)
-- ============================================================================

-- ============================================================================
-- PART 1: CORE RECURSIVE DOCUMENT GRAPH FUNCTION
-- ============================================================================

DROP FUNCTION IF EXISTS fn_recursive_document_graph(TEXT, UUID, BIGINT) CASCADE;

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
            'error', 'Invalid document type'
        );
    END IF;
    
    IF v_start_id IS NULL OR v_start_id = '' OR v_start_id = 'null' THEN
        RETURN jsonb_build_object(
            'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb,
            'error', 'Invalid document ID'
        );
    END IF;
    
    -- Recursive graph traversal
    WITH RECURSIVE doc_graph(doc_type, doc_id, visited_path, depth) AS (
        -- Base case
        SELECT v_start_type, v_start_id, ARRAY[v_start_type || ':' || v_start_id], 1
        
        UNION ALL
        
        -- Recursive case
        SELECT neighbor.doc_type, neighbor.doc_id, 
               g.visited_path || (neighbor.doc_type || ':' || neighbor.doc_id), 
               g.depth + 1
        FROM doc_graph g
        CROSS JOIN LATERAL (
            -- PR → PO via pr_po_linkage
            SELECT 'PO'::TEXT AS doc_type, l.po_id::TEXT AS doc_id
            FROM pr_po_linkage l 
            WHERE g.doc_type = 'PR' AND l.pr_id::TEXT = g.doc_id AND l.po_id IS NOT NULL
            
            UNION ALL
            
            -- PO → PR via pr_po_linkage (reverse)
            SELECT 'PR'::TEXT, l.pr_id::TEXT 
            FROM pr_po_linkage l 
            WHERE g.doc_type = 'PO' AND l.po_id::TEXT = g.doc_id AND l.pr_id IS NOT NULL
            
            UNION ALL
            
            -- PO → GRN via grn_inspections.purchase_order_id
            SELECT 'GRN'::TEXT, gi.id::TEXT 
            FROM grn_inspections gi 
            WHERE g.doc_type = 'PO' AND gi.purchase_order_id::TEXT = g.doc_id AND gi.deleted = FALSE
            
            UNION ALL
            
            -- GRN → PO via grn_inspections.purchase_order_id (reverse)
            SELECT 'PO'::TEXT, gi.purchase_order_id::TEXT 
            FROM grn_inspections gi 
            WHERE g.doc_type = 'GRN' AND gi.id::TEXT = g.doc_id AND gi.purchase_order_id IS NOT NULL
            
            UNION ALL
            
            -- GRN → PUR via purchasing_invoices.grn_id
            SELECT 'PUR'::TEXT, pi.id::TEXT 
            FROM purchasing_invoices pi 
            WHERE g.doc_type = 'GRN' AND pi.grn_id::TEXT = g.doc_id AND pi.deleted = FALSE
            
            UNION ALL
            
            -- PUR → GRN via purchasing_invoices.grn_id (reverse)
            SELECT 'GRN'::TEXT, pi.grn_id::TEXT 
            FROM purchasing_invoices pi 
            WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.grn_id IS NOT NULL
            
            UNION ALL
            
            -- PO → PUR via purchasing_invoices.purchase_order_id (direct invoice)
            SELECT 'PUR'::TEXT, pi.id::TEXT 
            FROM purchasing_invoices pi 
            WHERE g.doc_type = 'PO' AND pi.purchase_order_id::TEXT = g.doc_id AND pi.deleted = FALSE
            
            UNION ALL
            
            -- PUR → PO via purchasing_invoices.purchase_order_id (reverse)
            SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT 
            FROM purchasing_invoices pi 
            WHERE g.doc_type = 'PUR' AND pi.id::TEXT = g.doc_id AND pi.purchase_order_id IS NOT NULL
        ) AS neighbor
        WHERE NOT (neighbor.doc_type || ':' || neighbor.doc_id) = ANY(g.visited_path)
          AND neighbor.doc_id IS NOT NULL 
          AND neighbor.doc_id != '' 
          AND g.depth < 20
    ),
    unique_docs AS (
        SELECT DISTINCT doc_type, doc_id FROM doc_graph
    )
    -- Build JSON result
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
    RETURN jsonb_build_object(
        'pr', '[]'::jsonb, 
        'po', '[]'::jsonb, 
        'grn', '[]'::jsonb, 
        'pur', '[]'::jsonb, 
        'error', SQLERRM
    );
END;
$$;

-- ============================================================================
-- PART 2: DOCUMENT FLOW FUNCTIONS (FRONTEND CALLS THESE)
-- ============================================================================

DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow_json(TEXT, TEXT) CASCADE;

-- fn_get_document_flow - Returns TABLE format (legacy)
CREATE OR REPLACE FUNCTION fn_get_document_flow(p_doc_type TEXT, p_doc_id TEXT)
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
    v_input_uuid UUID;
    v_input_bigint BIGINT;
    v_graph JSONB;
    v_current_type TEXT;
BEGIN
    v_current_type := UPPER(TRIM(p_doc_type));
    
    -- Normalize type
    v_current_type := CASE 
        WHEN v_current_type IN ('PR', 'PURCHASE_REQUEST') THEN 'PR'
        WHEN v_current_type IN ('PO', 'PURCHASE_ORDER') THEN 'PO'
        WHEN v_current_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN 'GRN'
        WHEN v_current_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN 'PUR'
        ELSE v_current_type 
    END;
    
    -- Parse ID
    IF v_current_type = 'PO' THEN
        BEGIN 
            v_input_bigint := p_doc_id::BIGINT; 
        EXCEPTION WHEN OTHERS THEN 
            BEGIN v_input_uuid := p_doc_id::UUID; EXCEPTION WHEN OTHERS THEN NULL; END;
        END;
    ELSE
        BEGIN 
            v_input_uuid := p_doc_id::UUID; 
        EXCEPTION WHEN OTHERS THEN 
            BEGIN v_input_bigint := p_doc_id::BIGINT; EXCEPTION WHEN OTHERS THEN NULL; END;
        END;
    END IF;
    
    -- Get recursive graph
    v_graph := fn_recursive_document_graph(v_current_type, v_input_uuid, v_input_bigint);
    
    -- Return PR
    IF jsonb_array_length(COALESCE(v_graph->'pr', '[]'::jsonb)) > 0 THEN
        RETURN QUERY 
        SELECT 'PR'::TEXT, (d->>'id')::TEXT, (d->>'number')::TEXT, (d->>'status')::TEXT, 
               (d->>'date')::TIMESTAMPTZ, (v_current_type = 'PR'), 1 
        FROM jsonb_array_elements(v_graph->'pr') AS d LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1;
    END IF;
    
    -- Return PO
    IF jsonb_array_length(COALESCE(v_graph->'po', '[]'::jsonb)) > 0 THEN
        RETURN QUERY 
        SELECT 'PO'::TEXT, (d->>'id')::TEXT, (d->>'number')::TEXT, (d->>'status')::TEXT, 
               (d->>'date')::TIMESTAMPTZ, (v_current_type = 'PO'), 2 
        FROM jsonb_array_elements(v_graph->'po') AS d LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2;
    END IF;
    
    -- Return GRN
    IF jsonb_array_length(COALESCE(v_graph->'grn', '[]'::jsonb)) > 0 THEN
        RETURN QUERY 
        SELECT 'GRN'::TEXT, (d->>'id')::TEXT, (d->>'number')::TEXT, (d->>'status')::TEXT, 
               (d->>'date')::TIMESTAMPTZ, (v_current_type = 'GRN'), 3 
        FROM jsonb_array_elements(v_graph->'grn') AS d LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3;
    END IF;
    
    -- Return PUR
    IF jsonb_array_length(COALESCE(v_graph->'pur', '[]'::jsonb)) > 0 THEN
        RETURN QUERY 
        SELECT 'PUR'::TEXT, (d->>'id')::TEXT, (d->>'number')::TEXT, (d->>'status')::TEXT, 
               (d->>'date')::TIMESTAMPTZ, (v_current_type = 'PUR'), 4 
        FROM jsonb_array_elements(v_graph->'pur') AS d LIMIT 1;
    ELSE
        RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4;
    END IF;
    
    RETURN;
END;
$$;

-- fn_get_document_flow_json - Returns JSONB (for new frontend)
CREATE OR REPLACE FUNCTION fn_get_document_flow_json(p_doc_type TEXT, p_doc_id TEXT)
RETURNS JSONB 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
AS $$
DECLARE 
    v_input_uuid UUID; 
    v_input_bigint BIGINT;
    v_type TEXT;
BEGIN
    v_type := UPPER(TRIM(p_doc_type));
    
    IF v_type IN ('PO', 'PURCHASE_ORDER') THEN
        BEGIN v_input_bigint := p_doc_id::BIGINT; EXCEPTION WHEN OTHERS THEN v_input_uuid := p_doc_id::UUID; END;
    ELSE
        BEGIN v_input_uuid := p_doc_id::UUID; EXCEPTION WHEN OTHERS THEN v_input_bigint := p_doc_id::BIGINT; END;
    END IF;
    
    RETURN fn_recursive_document_graph(v_type, v_input_uuid, v_input_bigint);
END;
$$;

-- ============================================================================
-- PART 3: GET PR LINKED POS FUNCTION (FOR PR LIST PAGE)
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ppl.po_id,
        COALESCE(ppl.po_number, po.po_number) AS po_number,
        po.supplier_name,
        po.status AS po_status,
        po.receiving_status,
        SUM(COALESCE(ppl.converted_quantity, 0))::NUMERIC AS converted_qty,
        COUNT(*)::BIGINT AS item_count,
        COALESCE(po.total_amount, 0)::NUMERIC AS po_total,
        COALESCE(po.order_date, ppl.converted_at)::TIMESTAMPTZ AS po_date
    FROM pr_po_linkage ppl
    LEFT JOIN purchase_orders po ON po.id = ppl.po_id AND po.deleted = FALSE
    WHERE ppl.pr_id = p_pr_id
    GROUP BY ppl.po_id, ppl.po_number, po.po_number, po.supplier_name, po.status, 
             po.receiving_status, po.total_amount, po.order_date, ppl.converted_at;
END;
$$;

-- ============================================================================
-- PART 4: VIEW FOR PR LINKED POS
-- ============================================================================

DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;

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
GROUP BY ppl.pr_id, ppl.po_id, ppl.po_number, po.po_number, po.supplier_name, 
         po.status, po.receiving_status, po.total_amount, po.order_date, ppl.converted_at;

-- ============================================================================
-- PART 5: ITEM FLOW VIEW
-- ============================================================================

DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;

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
        COALESCE(pri.quantity, 0) AS pr_qty, 
        pri.unit
    FROM purchase_request_items pri 
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND pr.deleted = FALSE
),
po_agg AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(ppl.converted_quantity, 0)) AS ordered_qty, 
        STRING_AGG(DISTINCT ppl.po_number, ', ') AS po_numbers
    FROM pr_po_linkage ppl 
    WHERE ppl.pr_item_id IS NOT NULL 
    GROUP BY ppl.pr_item_id
),
grn_agg AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(gii.received_quantity, 0)) AS received_qty, 
        STRING_AGG(DISTINCT gi.grn_number, ', ') AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id 
        AND (poi.item_id = pri.item_id OR poi.item_name = pri.item_name)
    JOIN grn_inspection_items gii ON gii.po_item_id = poi.id
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id AND gi.deleted = FALSE
    WHERE ppl.pr_item_id IS NOT NULL 
    GROUP BY ppl.pr_item_id
),
pur_agg AS (
    SELECT 
        ppl.pr_item_id, 
        SUM(COALESCE(pii.quantity, 0)) AS invoiced_qty, 
        STRING_AGG(DISTINCT pi.purchasing_number, ', ') AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoice_items pii ON pii.item_id = pri.item_id
    JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.deleted = FALSE
    LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
    WHERE ppl.pr_item_id IS NOT NULL 
        AND (pi.purchase_order_id = ppl.po_id OR gi.purchase_order_id = ppl.po_id)
    GROUP BY ppl.pr_item_id
)
SELECT 
    p.pr_item_id, p.pr_id, p.pr_number, p.pr_pos, p.item_id, p.item_name, p.pr_qty, p.unit,
    COALESCE(po.ordered_qty, 0) AS po_qty, 
    COALESCE(po.po_numbers, '') AS po_numbers,
    COALESCE(grn.received_qty, 0) AS grn_qty, 
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(pur.invoiced_qty, 0) AS pur_qty, 
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    GREATEST(0, COALESCE(po.ordered_qty, 0) - COALESCE(grn.received_qty, 0)) AS remaining_po,
    CASE
        WHEN COALESCE(po.ordered_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(grn.received_qty, 0) = 0 THEN 'Ordered'
        WHEN COALESCE(grn.received_qty, 0) < COALESCE(po.ordered_qty, 0) THEN 'Partial Received'
        WHEN COALESCE(pur.invoiced_qty, 0) = 0 THEN 'Fully Received'
        WHEN COALESCE(pur.invoiced_qty, 0) < COALESCE(grn.received_qty, 0) THEN 'Partial Invoiced'
        ELSE 'Invoiced'
    END AS chain_status
FROM pr_items p
LEFT JOIN po_agg po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_agg grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_agg pur ON pur.pr_item_id = p.pr_item_id;

-- ============================================================================
-- PART 6: ITEM FLOW FUNCTION
-- ============================================================================

DROP FUNCTION IF EXISTS fn_get_item_flow(UUID) CASCADE;

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
LANGUAGE SQL 
SECURITY DEFINER 
SET search_path = public
AS $$ 
    SELECT 
        v.pr_item_id, v.pr_pos, v.item_name, v.pr_qty, 
        v.po_qty, v.grn_qty, v.pur_qty, v.remaining_po, 
        v.chain_status, v.po_numbers, v.grn_numbers, v.pur_numbers 
    FROM v_item_flow_recursive v 
    WHERE v.pr_id = p_pr_id 
    ORDER BY v.pr_pos; 
$$;

-- ============================================================================
-- PART 7: PERFORMANCE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_po_item ON grn_inspection_items(po_item_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_po ON purchasing_invoices(purchase_order_id);

-- ============================================================================
-- PART 8: GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION fn_recursive_document_graph(TEXT, UUID, BIGINT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;

-- ============================================================================
-- PART 9: ENSURE PURCHASING TABLES EXIST AND HAVE REQUIRED COLUMNS
-- ============================================================================

-- Add purchasing_number column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchasing_invoices' 
        AND column_name = 'purchasing_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchasing_invoices ADD COLUMN purchasing_number TEXT;
        RAISE NOTICE 'Added purchasing_number column to purchasing_invoices';
    END IF;
END $$;

-- Create purchasing_number sequence trigger if not exists
CREATE OR REPLACE FUNCTION fn_generate_purchasing_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_year TEXT;
    v_count INT;
    v_number TEXT;
BEGIN
    IF NEW.purchasing_number IS NULL OR NEW.purchasing_number = '' THEN
        v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
        
        SELECT COUNT(*) + 1 INTO v_count
        FROM purchasing_invoices
        WHERE purchasing_number LIKE 'PUR-' || v_year || '-%';
        
        v_number := 'PUR-' || v_year || '-' || LPAD(v_count::TEXT, 5, '0');
        NEW.purchasing_number := v_number;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_purchasing_number ON purchasing_invoices;
CREATE TRIGGER trg_generate_purchasing_number
    BEFORE INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION fn_generate_purchasing_number();

-- ============================================================================
-- PART 10: VERIFICATION
-- ============================================================================

-- Check functions
SELECT 'FUNCTIONS:' AS check_type, proname AS name 
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname IN ('fn_recursive_document_graph', 'fn_get_document_flow', 'fn_get_document_flow_json', 'get_pr_linked_pos', 'fn_get_item_flow', 'fn_generate_purchasing_number');

-- Check views  
SELECT 'VIEWS:' AS check_type, viewname AS name 
FROM pg_views WHERE schemaname = 'public' 
AND viewname IN ('v_pr_linked_pos', 'v_item_flow_recursive');

-- Check purchasing_invoices table has purchasing_number column
SELECT 'COLUMNS:' AS check_type, column_name AS name
FROM information_schema.columns 
WHERE table_name = 'purchasing_invoices' 
AND column_name = 'purchasing_number'
AND table_schema = 'public';

-- Test: Get a sample PR ID and test the function
DO $$
DECLARE
    v_pr_id UUID;
    v_result JSONB;
BEGIN
    -- Get first PR
    SELECT id INTO v_pr_id FROM purchase_requests WHERE deleted = FALSE LIMIT 1;
    
    IF v_pr_id IS NOT NULL THEN
        v_result := fn_get_document_flow_json('PR', v_pr_id::TEXT);
        RAISE NOTICE 'Test PR ID: %', v_pr_id;
        RAISE NOTICE 'Document Flow Result: %', v_result;
    ELSE
        RAISE NOTICE 'No PRs found for testing';
    END IF;
END $$;

SELECT '✅ INSTALLATION COMPLETE! Run the SQL and refresh your browser.' AS status;
