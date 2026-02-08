-- 01_TRACE_DOCUMENT_GRAPH.sql
-- UNIVERSAL DOCUMENT GRAPH TRACE ENGINE (SAP STYLE)
-- GRAPH TRAVERSAL: PR <-> PO <-> GRN <-> PUR
-- Dynamic reconstruction from relational tables (Single Source of Truth)
DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, TEXT);
DROP FUNCTION IF EXISTS fn_trace_document_graph(TEXT, UUID);
CREATE OR REPLACE FUNCTION fn_trace_document_graph(p_input_type TEXT, p_input_id TEXT) RETURNS JSONB AS $$
DECLARE -- Collections to hold unique IDs discovered during traversal
    v_pr_ids UUID [] := '{}';
v_po_ids BIGINT [] := '{}';
v_grn_ids UUID [] := '{}';
v_pur_ids UUID [] := '{}';
-- Loop control
v_found_new BOOLEAN := TRUE;
v_iteration INTEGER := 0;
-- Temp arrays for current iteration discovery
v_new_pr_ids UUID [];
v_new_po_ids BIGINT [];
v_new_grn_ids UUID [];
v_new_pur_ids UUID [];
v_result JSONB;
BEGIN -- Normalize Input
p_input_type := UPPER(TRIM(p_input_type));
-- ==================================================================
-- 1. INITIAL SEEDING (Root Node)
-- ==================================================================
IF p_input_type = 'PR' THEN v_pr_ids := ARRAY [p_input_id::UUID];
ELSIF p_input_type = 'PO' THEN v_po_ids := ARRAY [p_input_id::BIGINT];
ELSIF p_input_type IN ('GRN', 'GR') THEN v_grn_ids := ARRAY [p_input_id::UUID];
ELSIF p_input_type IN ('PUR', 'INV', 'INVOICE') THEN v_pur_ids := ARRAY [p_input_id::UUID];
END IF;
-- ==================================================================
-- 2. GRAPH TRAVERSAL LOOP (Breadth-First Search Style)
-- ==================================================================
-- We loop until no new links are found. This handles complex N:M chains.
-- Limit iterations to prevent infinite loops in case of circular refs (unlikely but safe).
WHILE v_found_new
AND v_iteration < 10 LOOP v_iteration := v_iteration + 1;
v_found_new := FALSE;
-- -------------------------------------------------
-- A. DISCOVER POs
-- -------------------------------------------------
-- From PRs (Forward)
SELECT ARRAY(
        SELECT DISTINCT po_id
        FROM pr_po_linkage
        WHERE pr_id = ANY(v_pr_ids)
            AND status = 'active'
            AND po_id != ALL(v_po_ids) -- Only new ones
    ) INTO v_new_po_ids;
IF array_length(v_new_po_ids, 1) > 0 THEN v_po_ids := v_po_ids || v_new_po_ids;
v_found_new := TRUE;
END IF;
-- From GRNs (Backward)
SELECT ARRAY(
        SELECT DISTINCT purchase_order_id::BIGINT
        FROM grn_inspections
        WHERE id = ANY(v_grn_ids)
            AND purchase_order_id IS NOT NULL
            AND purchase_order_id::BIGINT != ALL(v_po_ids)
    ) INTO v_new_po_ids;
IF array_length(v_new_po_ids, 1) > 0 THEN v_po_ids := v_po_ids || v_new_po_ids;
v_found_new := TRUE;
END IF;
-- From PURs (Backward)
SELECT ARRAY(
        SELECT DISTINCT purchase_order_id::BIGINT
        FROM purchasing_invoices
        WHERE id = ANY(v_pur_ids)
            AND purchase_order_id IS NOT NULL
            AND purchase_order_id::BIGINT != ALL(v_po_ids)
    ) INTO v_new_po_ids;
IF array_length(v_new_po_ids, 1) > 0 THEN v_po_ids := v_po_ids || v_new_po_ids;
v_found_new := TRUE;
END IF;
-- -------------------------------------------------
-- B. DISCOVER PRs
-- -------------------------------------------------
-- From POs (Backward)
SELECT ARRAY(
        SELECT DISTINCT pr_id
        FROM pr_po_linkage
        WHERE po_id = ANY(v_po_ids)
            AND status = 'active'
            AND pr_id != ALL(v_pr_ids)
    ) INTO v_new_pr_ids;
IF array_length(v_new_pr_ids, 1) > 0 THEN v_pr_ids := v_pr_ids || v_new_pr_ids;
v_found_new := TRUE;
END IF;
-- -------------------------------------------------
-- C. DISCOVER GRNs
-- -------------------------------------------------
-- From POs (Forward)
SELECT ARRAY(
        SELECT DISTINCT id
        FROM grn_inspections
        WHERE purchase_order_id = ANY(v_po_ids)
            AND deleted = false
            AND id != ALL(v_grn_ids)
    ) INTO v_new_grn_ids;
IF array_length(v_new_grn_ids, 1) > 0 THEN v_grn_ids := v_grn_ids || v_new_grn_ids;
v_found_new := TRUE;
END IF;
-- From PURs (Sideways/Backward - Invoice linked to GRN)
SELECT ARRAY(
        SELECT DISTINCT grn_id
        FROM purchasing_invoices
        WHERE id = ANY(v_pur_ids)
            AND grn_id IS NOT NULL
            AND grn_id != ALL(v_grn_ids)
    ) INTO v_new_grn_ids;
IF array_length(v_new_grn_ids, 1) > 0 THEN v_grn_ids := v_grn_ids || v_new_grn_ids;
v_found_new := TRUE;
END IF;
-- -------------------------------------------------
-- D. DISCOVER PURs (Invoices)
-- -------------------------------------------------
-- From GRNs (Forward)
SELECT ARRAY(
        SELECT DISTINCT id
        FROM purchasing_invoices
        WHERE grn_id = ANY(v_grn_ids)
            AND deleted = false
            AND id != ALL(v_pur_ids)
    ) INTO v_new_pur_ids;
IF array_length(v_new_pur_ids, 1) > 0 THEN v_pur_ids := v_pur_ids || v_new_pur_ids;
v_found_new := TRUE;
END IF;
-- From POs (Forward - Direct Invoice)
SELECT ARRAY(
        SELECT DISTINCT id
        FROM purchasing_invoices
        WHERE purchase_order_id = ANY(v_po_ids)
            AND deleted = false
            AND id != ALL(v_pur_ids)
    ) INTO v_new_pur_ids;
IF array_length(v_new_pur_ids, 1) > 0 THEN v_pur_ids := v_pur_ids || v_new_pur_ids;
v_found_new := TRUE;
END IF;
END LOOP;
-- ==================================================================
-- 3. BUILD JSON RESPONSE
-- ==================================================================
SELECT jsonb_build_object(
        'pr',
        (
            SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            pr_number,
                            'status',
                            status,
                            'date',
                            created_at,
                            'total_amount',
                            estimated_total
                        )
                        ORDER BY created_at
                    ),
                    '[]'::jsonb
                )
            FROM purchase_requests
            WHERE id = ANY(v_pr_ids)
        ),
        'po',
        (
            SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            po_number,
                            'status',
                            status,
                            'date',
                            order_date,
                            'total_amount',
                            total_amount
                        )
                        ORDER BY order_date
                    ),
                    '[]'::jsonb
                )
            FROM purchase_orders
            WHERE id = ANY(v_po_ids)
        ),
        'grn',
        (
            SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            grn_number,
                            'status',
                            status,
                            'date',
                            grn_date,
                            -- assuming grn_date exists, or use created_at
                            'received_by',
                            received_by
                        )
                        ORDER BY grn_date
                    ),
                    '[]'::jsonb
                )
            FROM grn_inspections
            WHERE id = ANY(v_grn_ids)
        ),
        'pur',
        (
            SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            purchasing_number,
                            'status',
                            status,
                            'date',
                            invoice_date,
                            'grand_total',
                            grand_total
                        )
                        ORDER BY invoice_date
                    ),
                    '[]'::jsonb
                )
            FROM purchasing_invoices
            WHERE id = ANY(v_pur_ids)
        )
    ) INTO v_result;
RETURN v_result;
EXCEPTION
WHEN OTHERS THEN -- Return empty structure with error info in case of catastrophic failure
RETURN jsonb_build_object(
    'pr',
    '[]'::jsonb,
    'po',
    '[]'::jsonb,
    'grn',
    '[]'::jsonb,
    'pur',
    '[]'::jsonb,
    'error',
    SQLERRM
);
END;
$$ LANGUAGE plpgsql;