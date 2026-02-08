-- ============================================================================
-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║         SAP S/4HANA VBFA-STYLE DOCUMENT FLOW ENGINE V2                    ║
-- ║              ENHANCED RECURSIVE GRAPH TRAVERSAL                           ║
-- ║                                                                           ║
-- ║  COPY THIS ENTIRE FILE AND PASTE INTO SUPABASE SQL EDITOR                 ║
-- ║  THEN CLICK "RUN"                                                         ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝
-- ============================================================================
--
-- This script creates a TRUE bidirectional recursive graph engine
-- that discovers ALL connected documents from ANY starting point.
--
-- ============================================================================

-- ============================================================================
-- PART 1: CLEANUP
-- ============================================================================

DROP TRIGGER IF EXISTS trg_log_inv ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_log_pr_po ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_log_po_grn ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;

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

DROP VIEW IF EXISTS v_sap_document_flow_global CASCADE;
DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;
DROP VIEW IF EXISTS v_sap_item_flow CASCADE;
DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_document_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_pr_linked_po_summary CASCADE;

-- ============================================================================
-- PART 2: MAIN RECURSIVE DOCUMENT GRAPH FUNCTION
-- ============================================================================
-- Uses WITH RECURSIVE to traverse ALL edges bidirectionally
-- Finds complete document chain from ANY starting document
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
    v_type TEXT;
    v_result JSONB;
BEGIN
    -- Normalize input type
    v_type := UPPER(TRIM(COALESCE(p_start_type, '')));
    v_type := CASE v_type
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GOODS_RECEIPT' THEN 'GRN'
        WHEN 'GR' THEN 'GRN'
        WHEN 'MIGO' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        WHEN 'MIRO' THEN 'PUR'
        ELSE v_type
    END;
    
    -- Validate inputs
    IF v_type NOT IN ('PR', 'PO', 'GRN', 'PUR') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid type. Use: PR, PO, GRN, or PUR',
            'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb
        );
    END IF;
    
    IF p_start_id IS NULL OR p_start_id = '' OR p_start_id = 'null' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Document ID required',
            'pr', '[]'::jsonb, 'po', '[]'::jsonb, 'grn', '[]'::jsonb, 'pur', '[]'::jsonb
        );
    END IF;

    -- ========================================================================
    -- RECURSIVE GRAPH TRAVERSAL - BIDIRECTIONAL
    -- ========================================================================
    WITH RECURSIVE graph AS (
        -- Base case: starting document
        SELECT 
            v_type AS doc_type,
            p_start_id AS doc_id,
            ARRAY[v_type || ':' || p_start_id] AS path,
            0 AS depth
        
        UNION ALL
        
        -- Recursive case: traverse ALL edges in BOTH directions
        SELECT 
            e.target_type,
            e.target_id,
            g.path || (e.target_type || ':' || e.target_id),
            g.depth + 1
        FROM graph g
        CROSS JOIN LATERAL (
            -- ================================================================
            -- PR → PO (via pr_po_linkage.po_id)
            -- ================================================================
            SELECT 'PO'::TEXT AS target_type, l.po_id::TEXT AS target_id
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PR' 
              AND l.pr_id::TEXT = g.doc_id
              AND l.po_id IS NOT NULL
              AND (l.status = 'active' OR l.status IS NULL)
            
            UNION ALL
            
            -- ================================================================
            -- PO → PR (reverse via pr_po_linkage.pr_id)
            -- ================================================================
            SELECT 'PR'::TEXT, l.pr_id::TEXT
            FROM pr_po_linkage l
            WHERE g.doc_type = 'PO' 
              AND l.po_id::TEXT = g.doc_id
              AND l.pr_id IS NOT NULL
              AND (l.status = 'active' OR l.status IS NULL)
            
            UNION ALL
            
            -- ================================================================
            -- PO → GRN (via grn_inspections.purchase_order_id)
            -- ================================================================
            SELECT 'GRN'::TEXT, gi.id::TEXT
            FROM grn_inspections gi
            WHERE g.doc_type = 'PO' 
              AND gi.purchase_order_id::TEXT = g.doc_id
              AND (gi.deleted = FALSE OR gi.deleted IS NULL)
            
            UNION ALL
            
            -- ================================================================
            -- GRN → PO (reverse via grn_inspections.purchase_order_id)
            -- ================================================================
            SELECT 'PO'::TEXT, gi.purchase_order_id::TEXT
            FROM grn_inspections gi
            WHERE g.doc_type = 'GRN' 
              AND gi.id::TEXT = g.doc_id
              AND gi.purchase_order_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================================
            -- GRN → PUR (via purchasing_invoices.grn_id)
            -- ================================================================
            SELECT 'PUR'::TEXT, pi.id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'GRN' 
              AND pi.grn_id::TEXT = g.doc_id
              AND (pi.deleted = FALSE OR pi.deleted IS NULL)
            
            UNION ALL
            
            -- ================================================================
            -- PUR → GRN (reverse via purchasing_invoices.grn_id)
            -- ================================================================
            SELECT 'GRN'::TEXT, pi.grn_id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR' 
              AND pi.id::TEXT = g.doc_id
              AND pi.grn_id IS NOT NULL
            
            UNION ALL
            
            -- ================================================================
            -- PO → PUR (direct via purchasing_invoices.purchase_order_id)
            -- ================================================================
            SELECT 'PUR'::TEXT, pi.id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PO' 
              AND pi.purchase_order_id::TEXT = g.doc_id
              AND (pi.deleted = FALSE OR pi.deleted IS NULL)
            
            UNION ALL
            
            -- ================================================================
            -- PUR → PO (reverse via purchasing_invoices.purchase_order_id)
            -- ================================================================
            SELECT 'PO'::TEXT, pi.purchase_order_id::TEXT
            FROM purchasing_invoices pi
            WHERE g.doc_type = 'PUR' 
              AND pi.id::TEXT = g.doc_id
              AND pi.purchase_order_id IS NOT NULL
              
        ) AS e
        WHERE 
            -- Prevent cycles: don't revisit already visited nodes
            NOT (e.target_type || ':' || e.target_id) = ANY(g.path)
            AND e.target_id IS NOT NULL
            AND e.target_id != ''
            AND e.target_id != 'null'
            -- Safety limit
            AND g.depth < 15
    ),
    
    -- Get unique documents
    unique_docs AS (
        SELECT DISTINCT doc_type, doc_id 
        FROM graph
        WHERE doc_id IS NOT NULL AND doc_id != '' AND doc_id != 'null'
    ),
    
    -- Build PR array
    pr_array AS (
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', pr.id,
                    'number', pr.pr_number,
                    'status', pr.status,
                    'date', pr.created_at,
                    'requester', pr.requester_name,
                    'department', pr.department,
                    'total', COALESCE(pr.estimated_total_value, 0)
                ) ORDER BY pr.created_at
            ),
            '[]'::jsonb
        ) AS arr
        FROM purchase_requests pr
        WHERE pr.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PR')
          AND (pr.deleted = FALSE OR pr.deleted IS NULL)
    ),
    
    -- Build PO array
    po_array AS (
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', po.id,
                    'number', po.po_number,
                    'status', po.status,
                    'date', po.order_date,
                    'supplier', po.supplier_name,
                    'total', COALESCE(po.total_amount, 0),
                    'receiving_status', po.receiving_status
                ) ORDER BY po.order_date
            ),
            '[]'::jsonb
        ) AS arr
        FROM purchase_orders po
        WHERE po.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PO')
          AND (po.deleted = FALSE OR po.deleted IS NULL)
    ),
    
    -- Build GRN array
    grn_array AS (
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', gi.id,
                    'number', gi.grn_number,
                    'status', gi.status,
                    'date', gi.grn_date,
                    'received_by', gi.received_by_name,
                    'po_number', gi.purchase_order_number
                ) ORDER BY gi.grn_date
            ),
            '[]'::jsonb
        ) AS arr
        FROM grn_inspections gi
        WHERE gi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'GRN')
          AND (gi.deleted = FALSE OR gi.deleted IS NULL)
    ),
    
    -- Build PUR array
    pur_array AS (
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', pi.id,
                    'number', pi.purchasing_number,
                    'status', pi.status,
                    'date', COALESCE(pi.invoice_date, pi.created_at::DATE),
                    'payment_status', pi.payment_status,
                    'total', COALESCE(pi.grand_total, 0),
                    'grn_number', pi.grn_number
                ) ORDER BY pi.created_at
            ),
            '[]'::jsonb
        ) AS arr
        FROM purchasing_invoices pi
        WHERE pi.id::TEXT IN (SELECT doc_id FROM unique_docs WHERE doc_type = 'PUR')
          AND (pi.deleted = FALSE OR pi.deleted IS NULL)
    )
    
    -- Combine results
    SELECT jsonb_build_object(
        'success', true,
        'root_type', v_type,
        'root_id', p_start_id,
        'pr', (SELECT arr FROM pr_array),
        'po', (SELECT arr FROM po_array),
        'grn', (SELECT arr FROM grn_array),
        'pur', (SELECT arr FROM pur_array)
    ) INTO v_result;
    
    RETURN v_result;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'root_type', v_type,
        'root_id', p_start_id,
        'pr', '[]'::jsonb,
        'po', '[]'::jsonb,
        'grn', '[]'::jsonb,
        'pur', '[]'::jsonb
    );
END;
$$;

-- ============================================================================
-- PART 3: FRONTEND WRAPPER FUNCTIONS
-- ============================================================================

-- JSON wrapper (primary for frontend)
CREATE OR REPLACE FUNCTION fn_get_document_flow_json(p_doc_type TEXT, p_doc_id TEXT)
RETURNS JSONB
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT fn_sap_document_graph(p_doc_type, p_doc_id);
$$;

-- Table wrapper (legacy compatibility)
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
    v_graph JSONB;
    v_norm TEXT;
BEGIN
    v_graph := fn_sap_document_graph(p_doc_type, p_doc_id);
    
    v_norm := UPPER(TRIM(p_doc_type));
    v_norm := CASE v_norm
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GR' THEN 'GRN'
        WHEN 'MIGO' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        WHEN 'MIRO' THEN 'PUR'
        ELSE v_norm
    END;
    
    -- PR row
    IF jsonb_array_length(COALESCE(v_graph->'pr', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 
            'PR'::TEXT, 
            (v_graph->'pr'->0->>'id')::TEXT, 
            (v_graph->'pr'->0->>'number')::TEXT, 
            (v_graph->'pr'->0->>'status')::TEXT, 
            (v_graph->'pr'->0->>'date')::TIMESTAMPTZ, 
            (v_norm = 'PR'), 
            1;
    ELSE
        RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1;
    END IF;
    
    -- PO row
    IF jsonb_array_length(COALESCE(v_graph->'po', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 
            'PO'::TEXT, 
            (v_graph->'po'->0->>'id')::TEXT, 
            (v_graph->'po'->0->>'number')::TEXT, 
            (v_graph->'po'->0->>'status')::TEXT, 
            (v_graph->'po'->0->>'date')::TIMESTAMPTZ, 
            (v_norm = 'PO'), 
            2;
    ELSE
        RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2;
    END IF;
    
    -- GRN row
    IF jsonb_array_length(COALESCE(v_graph->'grn', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 
            'GRN'::TEXT, 
            (v_graph->'grn'->0->>'id')::TEXT, 
            (v_graph->'grn'->0->>'number')::TEXT, 
            (v_graph->'grn'->0->>'status')::TEXT, 
            (v_graph->'grn'->0->>'date')::TIMESTAMPTZ, 
            (v_norm = 'GRN'), 
            3;
    ELSE
        RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3;
    END IF;
    
    -- PUR row
    IF jsonb_array_length(COALESCE(v_graph->'pur', '[]'::jsonb)) > 0 THEN
        RETURN QUERY SELECT 
            'PUR'::TEXT, 
            (v_graph->'pur'->0->>'id')::TEXT, 
            (v_graph->'pur'->0->>'number')::TEXT, 
            (v_graph->'pur'->0->>'status')::TEXT, 
            (v_graph->'pur'->0->>'date')::TIMESTAMPTZ, 
            (v_norm = 'PUR'), 
            4;
    ELSE
        RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4;
    END IF;
    
    RETURN;
END;
$$;

-- ============================================================================
-- PART 4: PR LINKED PO SUMMARY VIEW AND FUNCTION
-- ============================================================================

-- View: All PRs with their linked PO counts
CREATE OR REPLACE VIEW v_pr_linked_po_summary AS
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    COUNT(DISTINCT ppl.po_id) AS po_count,
    ARRAY_AGG(DISTINCT ppl.po_number) FILTER (WHERE ppl.po_number IS NOT NULL) AS po_numbers,
    SUM(COALESCE(ppl.converted_quantity, 0)) AS total_converted_qty
FROM purchase_requests pr
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id 
    AND (ppl.status = 'active' OR ppl.status IS NULL)
WHERE pr.deleted = FALSE OR pr.deleted IS NULL
GROUP BY pr.id, pr.pr_number, pr.status;

-- View: Detailed linked POs per PR
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
LEFT JOIN purchase_orders po ON po.id = ppl.po_id 
    AND (po.deleted = FALSE OR po.deleted IS NULL)
WHERE ppl.status = 'active' OR ppl.status IS NULL
GROUP BY 
    ppl.pr_id, 
    ppl.po_id, 
    ppl.po_number, 
    po.po_number, 
    po.supplier_name, 
    po.status, 
    po.receiving_status, 
    po.total_amount, 
    po.order_date, 
    ppl.converted_at;

-- Function: Get linked POs for a specific PR
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
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        v.po_id,
        v.po_number,
        v.supplier_name,
        v.po_status,
        v.receiving_status,
        v.converted_qty,
        v.item_count,
        v.po_total,
        v.po_date
    FROM v_pr_linked_pos v
    WHERE v.pr_id = p_pr_id;
$$;

-- ============================================================================
-- PART 5: SAP EKBE-STYLE ITEM FLOW VIEW
-- ============================================================================

CREATE OR REPLACE VIEW v_sap_item_flow AS
WITH 
-- Base PR items
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
        pri.estimated_price AS pr_price
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id 
        AND (pr.deleted = FALSE OR pr.deleted IS NULL)
    WHERE pri.deleted = FALSE OR pri.deleted IS NULL
),

-- PO quantities from pr_po_linkage
po_agg AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
        STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers,
        ARRAY_AGG(DISTINCT ppl.po_id) AS po_ids
    FROM pr_po_linkage ppl
    WHERE ppl.status = 'active' OR ppl.status IS NULL
    GROUP BY ppl.pr_item_id
),

-- GRN quantities
grn_agg AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
        STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN grn_inspections gi ON gi.purchase_order_id = ppl.po_id 
        AND (gi.deleted = FALSE OR gi.deleted IS NULL)
    JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),

-- PUR quantities
pur_agg AS (
    SELECT 
        ppl.pr_item_id,
        SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
        STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchasing_invoices pi ON (
        pi.purchase_order_id = ppl.po_id 
        OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id)
    ) AND (pi.deleted = FALSE OR pi.deleted IS NULL)
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
)

SELECT 
    p.pr_item_id,
    p.pr_id,
    p.pr_number,
    p.pr_pos,
    p.item_id,
    p.item_name,
    p.item_code,
    p.unit,
    p.pr_price,
    
    -- Quantities
    p.pr_qty,
    COALESCE(po.po_qty, 0) AS po_qty,
    COALESCE(grn.grn_qty, 0) AS grn_qty,
    COALESCE(pur.pur_qty, 0) AS pur_qty,
    
    -- Remaining quantities
    GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
    GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
    GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
    
    -- Document references
    COALESCE(po.po_numbers, '') AS po_numbers,
    COALESCE(grn.grn_numbers, '') AS grn_numbers,
    COALESCE(pur.pur_numbers, '') AS pur_numbers,
    
    -- Status (SAP EKBE logic)
    CASE
        WHEN COALESCE(po.po_qty, 0) = 0 THEN 'PENDING'
        WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'ORDERED'
        WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'PARTIAL_RECEIVED'
        WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'FULLY_RECEIVED'
        WHEN COALESCE(pur.pur_qty, 0) < COALESCE(grn.grn_qty, 0) THEN 'PARTIAL_INVOICED'
        ELSE 'INVOICED'
    END AS item_status

FROM pr_items p
LEFT JOIN po_agg po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_agg grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_agg pur ON pur.pr_item_id = p.pr_item_id;

-- Function: Get item flow for a specific PR
CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (
    pr_item_id UUID,
    pr_pos INT,
    item_name TEXT,
    item_code TEXT,
    unit TEXT,
    pr_qty NUMERIC,
    po_qty NUMERIC,
    grn_qty NUMERIC,
    pur_qty NUMERIC,
    remaining_pr NUMERIC,
    remaining_po NUMERIC,
    remaining_grn NUMERIC,
    item_status TEXT,
    po_numbers TEXT,
    grn_numbers TEXT,
    pur_numbers TEXT
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        v.pr_item_id,
        v.pr_pos,
        v.item_name,
        v.item_code,
        v.unit,
        v.pr_qty,
        v.po_qty,
        v.grn_qty,
        v.pur_qty,
        v.remaining_pr,
        v.remaining_po,
        v.remaining_grn,
        v.item_status,
        v.po_numbers,
        v.grn_numbers,
        v.pur_numbers
    FROM v_sap_item_flow v
    WHERE v.pr_id = p_pr_id
    ORDER BY v.pr_pos;
$$;

-- ============================================================================
-- PART 6: DOCUMENT FLOW TRIGGERS (CORRECT COLUMNS ONLY)
-- ============================================================================

-- Trigger: PR → PO linkage
CREATE OR REPLACE FUNCTION trg_fn_pr_po_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type, created_at
    ) VALUES (
        'PR', NEW.pr_id::TEXT, NEW.pr_number,
        'PO', NEW.po_id::TEXT, NEW.po_number,
        'converted_to_po', NOW()
    ) ON CONFLICT DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pr_po_linkage_document_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_pr_po_document_flow();

-- Trigger: GRN creation
CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_po_number TEXT;
BEGIN
    IF NEW.purchase_order_id IS NOT NULL THEN
        SELECT po_number INTO v_po_number 
        FROM purchase_orders WHERE id = NEW.purchase_order_id;
        
        INSERT INTO document_flow (
            source_type, source_id, source_number,
            target_type, target_id, target_number,
            flow_type, created_at
        ) VALUES (
            'PO', NEW.purchase_order_id::TEXT, COALESCE(v_po_number, NEW.purchase_order_number),
            'GRN', NEW.id::TEXT, NEW.grn_number,
            'goods_received', NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grn_document_flow
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_grn_document_flow();

-- Trigger: Purchasing Invoice creation
CREATE OR REPLACE FUNCTION trg_fn_pur_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_grn_number TEXT;
    v_po_number TEXT;
BEGIN
    IF NEW.grn_id IS NOT NULL THEN
        SELECT grn_number INTO v_grn_number 
        FROM grn_inspections WHERE id = NEW.grn_id;
        
        INSERT INTO document_flow (
            source_type, source_id, source_number,
            target_type, target_id, target_number,
            flow_type, created_at
        ) VALUES (
            'GRN', NEW.grn_id::TEXT, COALESCE(v_grn_number, NEW.grn_number),
            'PUR', NEW.id::TEXT, NEW.purchasing_number,
            'invoice_created', NOW()
        ) ON CONFLICT DO NOTHING;
    ELSIF NEW.purchase_order_id IS NOT NULL THEN
        SELECT po_number INTO v_po_number 
        FROM purchase_orders WHERE id = NEW.purchase_order_id;
        
        INSERT INTO document_flow (
            source_type, source_id, source_number,
            target_type, target_id, target_number,
            flow_type, created_at
        ) VALUES (
            'PO', NEW.purchase_order_id::TEXT, COALESCE(v_po_number, NEW.purchase_order_number),
            'PUR', NEW.id::TEXT, NEW.purchasing_number,
            'invoice_created', NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_purchasing_invoice_document_flow
    AFTER INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_pur_document_flow();

-- ============================================================================
-- PART 7: BACKFILL DOCUMENT FLOW
-- ============================================================================

-- Backfill PR → PO from pr_po_linkage
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT
    'PR', ppl.pr_id::TEXT, ppl.pr_number,
    'PO', ppl.po_id::TEXT, ppl.po_number,
    'converted_to_po', COALESCE(ppl.converted_at, NOW())
FROM pr_po_linkage ppl
WHERE (ppl.status = 'active' OR ppl.status IS NULL)
ON CONFLICT DO NOTHING;

-- Backfill PO → GRN from grn_inspections
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT
    'PO', gi.purchase_order_id::TEXT, COALESCE(gi.purchase_order_number, po.po_number),
    'GRN', gi.id::TEXT, gi.grn_number,
    'goods_received', gi.created_at
FROM grn_inspections gi
LEFT JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.purchase_order_id IS NOT NULL
  AND (gi.deleted = FALSE OR gi.deleted IS NULL)
ON CONFLICT DO NOTHING;

-- Backfill GRN → PUR from purchasing_invoices
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT
    'GRN', pi.grn_id::TEXT, COALESCE(pi.grn_number, gi.grn_number),
    'PUR', pi.id::TEXT, pi.purchasing_number,
    'invoice_created', pi.created_at
FROM purchasing_invoices pi
LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE pi.grn_id IS NOT NULL
  AND (pi.deleted = FALSE OR pi.deleted IS NULL)
ON CONFLICT DO NOTHING;

-- Backfill PO → PUR (direct) from purchasing_invoices
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT
    'PO', pi.purchase_order_id::TEXT, COALESCE(pi.purchase_order_number, po.po_number),
    'PUR', pi.id::TEXT, pi.purchasing_number,
    'invoice_created', pi.created_at
FROM purchasing_invoices pi
LEFT JOIN purchase_orders po ON po.id = pi.purchase_order_id
WHERE pi.purchase_order_id IS NOT NULL
  AND pi.grn_id IS NULL
  AND (pi.deleted = FALSE OR pi.deleted IS NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- PART 8: INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status ON pr_po_linkage(status);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_deleted ON grn_inspections(deleted);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_po_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_deleted ON purchasing_invoices(deleted);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_inv_id ON purchasing_invoice_items(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_item_id ON purchasing_invoice_items(item_id);
CREATE INDEX IF NOT EXISTS idx_document_flow_source ON document_flow(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_document_flow_target ON document_flow(target_type, target_id);

-- ============================================================================
-- PART 9: GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION fn_sap_document_graph(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT SELECT ON v_pr_linked_po_summary TO authenticated, anon;
GRANT SELECT ON v_sap_item_flow TO authenticated, anon;

-- ============================================================================
-- PART 10: VERIFICATION TEST
-- ============================================================================

DO $$
DECLARE
    v_pr_id UUID;
    v_po_id BIGINT;
    v_result JSONB;
    v_linked_count INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '           SAP VBFA DOCUMENT FLOW ENGINE V2 INSTALLED           ';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    
    -- Test 1: Find a PR with linked PO
    SELECT pr_id INTO v_pr_id 
    FROM pr_po_linkage 
    WHERE status = 'active' OR status IS NULL 
    LIMIT 1;
    
    IF v_pr_id IS NOT NULL THEN
        v_result := fn_sap_document_graph('PR', v_pr_id::TEXT);
        RAISE NOTICE '';
        RAISE NOTICE 'TEST 1: Starting from PR %', v_pr_id;
        RAISE NOTICE '  PRs found: %', jsonb_array_length(v_result->'pr');
        RAISE NOTICE '  POs found: %', jsonb_array_length(v_result->'po');
        RAISE NOTICE '  GRNs found: %', jsonb_array_length(v_result->'grn');
        RAISE NOTICE '  PURs found: %', jsonb_array_length(v_result->'pur');
    END IF;
    
    -- Test 2: Find a PO with GRN
    SELECT gi.purchase_order_id INTO v_po_id 
    FROM grn_inspections gi 
    WHERE gi.purchase_order_id IS NOT NULL 
      AND (gi.deleted = FALSE OR gi.deleted IS NULL)
    LIMIT 1;
    
    IF v_po_id IS NOT NULL THEN
        v_result := fn_sap_document_graph('PO', v_po_id::TEXT);
        RAISE NOTICE '';
        RAISE NOTICE 'TEST 2: Starting from PO %', v_po_id;
        RAISE NOTICE '  PRs found: %', jsonb_array_length(v_result->'pr');
        RAISE NOTICE '  POs found: %', jsonb_array_length(v_result->'po');
        RAISE NOTICE '  GRNs found: %', jsonb_array_length(v_result->'grn');
        RAISE NOTICE '  PURs found: %', jsonb_array_length(v_result->'pur');
    END IF;
    
    -- Test 3: Count linked POs
    SELECT COUNT(DISTINCT po_id) INTO v_linked_count FROM v_pr_linked_pos;
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 3: Total unique linked POs: %', v_linked_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ INSTALLATION COMPLETE! Refresh browser with Ctrl+F5';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

SELECT '✅ SAP DOCUMENT FLOW ENGINE V2 INSTALLED!' AS status;
