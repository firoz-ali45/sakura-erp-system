-- ============================================================================
-- 01_DOCUMENT_FLOW_FUNCTION.sql
-- SAP S/4HANA Style - Enterprise Document Flow Function
-- Traces: PR → PO → GRN → PUR (bidirectional)
-- ============================================================================

-- Drop existing function if exists
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT);

-- ============================================================================
-- MAIN FUNCTION: Get full document flow chain for any document
-- Works bidirectionally - traces both forward and backward
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_document_flow(
    p_doc_type TEXT,   -- 'PR', 'PO', 'GRN', 'PUR'
    p_doc_id TEXT      -- UUID or BIGINT as text
)
RETURNS TABLE (
    doc_order INT,
    doc_type TEXT,
    doc_id TEXT,
    doc_number TEXT,
    doc_status TEXT,
    doc_date TIMESTAMPTZ,
    is_current BOOLEAN,
    is_exists BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr_id UUID := NULL;
    v_po_id BIGINT := NULL;
    v_grn_id UUID := NULL;
    v_pur_id UUID := NULL;
    v_pr_number TEXT := NULL;
    v_po_number TEXT := NULL;
    v_grn_number TEXT := NULL;
    v_pur_number TEXT := NULL;
    v_pr_status TEXT := NULL;
    v_po_status TEXT := NULL;
    v_grn_status TEXT := NULL;
    v_pur_status TEXT := NULL;
    v_pr_date TIMESTAMPTZ := NULL;
    v_po_date TIMESTAMPTZ := NULL;
    v_grn_date TIMESTAMPTZ := NULL;
    v_pur_date TIMESTAMPTZ := NULL;
    v_input_type TEXT;
BEGIN
    v_input_type := UPPER(TRIM(p_doc_type));
    
    -- ========================================================================
    -- STEP 1: IDENTIFY STARTING POINT AND TRACE TO FIND ALL RELATED DOCS
    -- ========================================================================
    
    -- CASE 1: Starting from PR
    IF v_input_type = 'PR' THEN
        BEGIN
            v_pr_id := p_doc_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_pr_id := NULL;
        END;
        
    -- CASE 2: Starting from PO
    ELSIF v_input_type = 'PO' THEN
        BEGIN
            v_po_id := p_doc_id::BIGINT;
        EXCEPTION WHEN OTHERS THEN
            v_po_id := NULL;
        END;
        
    -- CASE 3: Starting from GRN
    ELSIF v_input_type = 'GRN' THEN
        BEGIN
            v_grn_id := p_doc_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_grn_id := NULL;
        END;
        
    -- CASE 4: Starting from PUR (Purchasing Invoice)
    ELSIF v_input_type IN ('PUR', 'INV', 'INVOICE') THEN
        BEGIN
            v_pur_id := p_doc_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_pur_id := NULL;
        END;
    END IF;

    -- ========================================================================
    -- STEP 2: TRACE BACKWARD TO FIND ROOT (PR)
    -- ========================================================================
    
    -- From PUR → find GRN and PO
    IF v_pur_id IS NOT NULL THEN
        SELECT grn_id, purchase_order_id
        INTO v_grn_id, v_po_id
        FROM purchasing_invoices
        WHERE id = v_pur_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;
    
    -- From GRN → find PO
    IF v_grn_id IS NOT NULL AND v_po_id IS NULL THEN
        SELECT purchase_order_id
        INTO v_po_id
        FROM grn_inspections
        WHERE id = v_grn_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;
    
    -- From PO → find PR
    IF v_po_id IS NOT NULL AND v_pr_id IS NULL THEN
        -- Try pr_po_linkage first
        SELECT pr_id INTO v_pr_id
        FROM pr_po_linkage
        WHERE po_id = v_po_id AND status = 'active'
        LIMIT 1;
        
        -- Fallback to purchase_request_items.po_id
        IF v_pr_id IS NULL THEN
            SELECT pr_id INTO v_pr_id
            FROM purchase_request_items
            WHERE po_id = v_po_id AND (deleted = FALSE OR deleted IS NULL)
            LIMIT 1;
        END IF;
    END IF;

    -- ========================================================================
    -- STEP 3: TRACE FORWARD FROM PR TO FIND ALL DOWNSTREAM DOCS
    -- ========================================================================
    
    -- From PR → find PO
    IF v_pr_id IS NOT NULL AND v_po_id IS NULL THEN
        -- Try pr_po_linkage
        SELECT po_id INTO v_po_id
        FROM pr_po_linkage
        WHERE pr_id = v_pr_id AND status = 'active'
        LIMIT 1;
        
        -- Fallback to purchase_request_items.po_id
        IF v_po_id IS NULL THEN
            SELECT po_id INTO v_po_id
            FROM purchase_request_items
            WHERE pr_id = v_pr_id AND po_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
            LIMIT 1;
        END IF;
    END IF;
    
    -- From PO → find GRN
    IF v_po_id IS NOT NULL AND v_grn_id IS NULL THEN
        SELECT id INTO v_grn_id
        FROM grn_inspections
        WHERE purchase_order_id = v_po_id AND (deleted = FALSE OR deleted IS NULL)
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- From GRN → find PUR
    IF v_grn_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id INTO v_pur_id
        FROM purchasing_invoices
        WHERE grn_id = v_grn_id AND (deleted = FALSE OR deleted IS NULL)
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- From PO → find PUR (if no GRN link)
    IF v_po_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id INTO v_pur_id
        FROM purchasing_invoices
        WHERE purchase_order_id = v_po_id AND (deleted = FALSE OR deleted IS NULL)
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;

    -- ========================================================================
    -- STEP 4: FETCH DOCUMENT DETAILS
    -- ========================================================================
    
    -- Get PR details
    IF v_pr_id IS NOT NULL THEN
        SELECT pr_number, status, created_at
        INTO v_pr_number, v_pr_status, v_pr_date
        FROM purchase_requests
        WHERE id = v_pr_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;
    
    -- Get PO details
    IF v_po_id IS NOT NULL THEN
        SELECT po_number, status, created_at
        INTO v_po_number, v_po_status, v_po_date
        FROM purchase_orders
        WHERE id = v_po_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;
    
    -- Get GRN details
    IF v_grn_id IS NOT NULL THEN
        SELECT grn_number, status, created_at
        INTO v_grn_number, v_grn_status, v_grn_date
        FROM grn_inspections
        WHERE id = v_grn_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;
    
    -- Get PUR details
    IF v_pur_id IS NOT NULL THEN
        SELECT purchasing_number, status, created_at
        INTO v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices
        WHERE id = v_pur_id AND (deleted = FALSE OR deleted IS NULL);
    END IF;

    -- ========================================================================
    -- STEP 5: RETURN UNIFIED FLOW (Always 4 rows: PR, PO, GRN, PUR)
    -- ========================================================================
    
    -- Return PR
    RETURN QUERY SELECT 
        1::INT,
        'PR'::TEXT,
        COALESCE(v_pr_id::TEXT, '')::TEXT,
        COALESCE(v_pr_number, '')::TEXT,
        COALESCE(v_pr_status, '')::TEXT,
        v_pr_date,
        (v_input_type = 'PR')::BOOLEAN,
        (v_pr_id IS NOT NULL)::BOOLEAN;
    
    -- Return PO
    RETURN QUERY SELECT 
        2::INT,
        'PO'::TEXT,
        COALESCE(v_po_id::TEXT, '')::TEXT,
        COALESCE(v_po_number, '')::TEXT,
        COALESCE(v_po_status, '')::TEXT,
        v_po_date,
        (v_input_type = 'PO')::BOOLEAN,
        (v_po_id IS NOT NULL)::BOOLEAN;
    
    -- Return GRN
    RETURN QUERY SELECT 
        3::INT,
        'GRN'::TEXT,
        COALESCE(v_grn_id::TEXT, '')::TEXT,
        COALESCE(v_grn_number, '')::TEXT,
        COALESCE(v_grn_status, '')::TEXT,
        v_grn_date,
        (v_input_type = 'GRN')::BOOLEAN,
        (v_grn_id IS NOT NULL)::BOOLEAN;
    
    -- Return PUR
    RETURN QUERY SELECT 
        4::INT,
        'PUR'::TEXT,
        COALESCE(v_pur_id::TEXT, '')::TEXT,
        COALESCE(v_pur_number, '')::TEXT,
        COALESCE(v_pur_status, '')::TEXT,
        v_pur_date,
        (v_input_type IN ('PUR', 'INV', 'INVOICE'))::BOOLEAN,
        (v_pur_id IS NOT NULL)::BOOLEAN;
    
    RETURN;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO anon;

-- ============================================================================
-- TEST THE FUNCTION
-- ============================================================================
-- SELECT * FROM fn_get_document_flow('PR', 'your-pr-uuid-here');
-- SELECT * FROM fn_get_document_flow('PO', '70');
-- SELECT * FROM fn_get_document_flow('GRN', 'your-grn-uuid-here');
-- SELECT * FROM fn_get_document_flow('PUR', 'your-pur-uuid-here');

COMMENT ON FUNCTION fn_get_document_flow IS 
'SAP S/4HANA style document flow function. 
Returns full chain PR→PO→GRN→PUR for any document in the chain.
Works bidirectionally - traces both forward and backward.';
