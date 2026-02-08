-- ============================================================================
-- 01_DOCUMENT_FLOW_FUNCTION.sql
-- ENTERPRISE SAP-STYLE DOCUMENT FLOW FUNCTION
-- Traces PR → PO → GRN → PUR bidirectionally
-- ============================================================================

-- Drop existing function if exists
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT);

-- ============================================================================
-- MAIN FUNCTION: Get full document flow chain for any document
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_document_flow(
    p_doc_type TEXT,    -- 'PR', 'PO', 'GRN', 'PUR'
    p_doc_id TEXT       -- UUID or BIGINT as TEXT
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
AS $$
DECLARE
    v_pr_id UUID;
    v_pr_number TEXT;
    v_pr_status TEXT;
    v_pr_date TIMESTAMPTZ;
    
    v_po_id BIGINT;
    v_po_number TEXT;
    v_po_status TEXT;
    v_po_date TIMESTAMPTZ;
    
    v_grn_id UUID;
    v_grn_number TEXT;
    v_grn_status TEXT;
    v_grn_date TIMESTAMPTZ;
    
    v_pur_id UUID;
    v_pur_number TEXT;
    v_pur_status TEXT;
    v_pur_date TIMESTAMPTZ;
    
    v_normalized_type TEXT;
BEGIN
    -- Normalize the document type
    v_normalized_type := UPPER(TRIM(p_doc_type));
    
    -- ========================================================================
    -- STEP 1: Identify starting point and trace to find all documents
    -- ========================================================================
    
    -- CASE 1: Starting from PR
    IF v_normalized_type IN ('PR', 'PURCHASE_REQUEST') THEN
        -- Get PR details
        SELECT id, pr_number, status, created_at
        INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM purchase_requests
        WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        -- Find linked PO via pr_po_linkage
        SELECT DISTINCT ppl.po_id, po.po_number, po.status, po.order_date
        INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM pr_po_linkage ppl
        JOIN purchase_orders po ON po.id = ppl.po_id
        WHERE ppl.pr_id = v_pr_id AND ppl.status = 'active' AND po.deleted = FALSE
        LIMIT 1;
        
        -- If no linkage, try purchase_request_items.po_id
        IF v_po_id IS NULL THEN
            SELECT DISTINCT pri.po_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM purchase_request_items pri
            JOIN purchase_orders po ON po.id = pri.po_id
            WHERE pri.pr_id = v_pr_id AND pri.po_id IS NOT NULL AND po.deleted = FALSE
            LIMIT 1;
        END IF;
        
    -- CASE 2: Starting from PO
    ELSIF v_normalized_type IN ('PO', 'PURCHASE_ORDER') THEN
        -- Get PO details
        SELECT id, po_number, status, order_date
        INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM purchase_orders
        WHERE id = p_doc_id::BIGINT AND deleted = FALSE;
        
        -- Find linked PR via pr_po_linkage (BACKWARD)
        SELECT DISTINCT ppl.pr_id, pr.pr_number, pr.status, pr.created_at
        INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM pr_po_linkage ppl
        JOIN purchase_requests pr ON pr.id = ppl.pr_id
        WHERE ppl.po_id = v_po_id AND ppl.status = 'active' AND pr.deleted = FALSE
        LIMIT 1;
        
        -- If no linkage, try purchase_request_items.po_id
        IF v_pr_id IS NULL THEN
            SELECT DISTINCT pri.pr_id, pr.pr_number, pr.status, pr.created_at
            INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
            FROM purchase_request_items pri
            JOIN purchase_requests pr ON pr.id = pri.pr_id
            WHERE pri.po_id = v_po_id AND pr.deleted = FALSE
            LIMIT 1;
        END IF;
        
    -- CASE 3: Starting from GRN
    ELSIF v_normalized_type IN ('GRN', 'GOODS_RECEIPT') THEN
        -- Get GRN details
        SELECT id, grn_number, status, grn_date
        INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM grn_inspections
        WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        -- Find linked PO (BACKWARD)
        SELECT gi.purchase_order_id, po.po_number, po.status, po.order_date
        INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM grn_inspections gi
        JOIN purchase_orders po ON po.id = gi.purchase_order_id
        WHERE gi.id = v_grn_id AND po.deleted = FALSE;
        
    -- CASE 4: Starting from PUR (Purchasing Invoice)
    ELSIF v_normalized_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING_INVOICE') THEN
        -- Get PUR details
        SELECT id, purchasing_number, status, created_at
        INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices
        WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        -- Find linked GRN (BACKWARD)
        SELECT pi.grn_id, gi.grn_number, gi.status, gi.grn_date
        INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM purchasing_invoices pi
        LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
        WHERE pi.id = v_pur_id;
        
        -- Find linked PO (BACKWARD) - from invoice or from GRN
        IF v_grn_id IS NOT NULL THEN
            SELECT gi.purchase_order_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM grn_inspections gi
            JOIN purchase_orders po ON po.id = gi.purchase_order_id
            WHERE gi.id = v_grn_id AND po.deleted = FALSE;
        ELSE
            SELECT pi.purchase_order_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM purchasing_invoices pi
            JOIN purchase_orders po ON po.id = pi.purchase_order_id
            WHERE pi.id = v_pur_id AND po.deleted = FALSE;
        END IF;
    END IF;
    
    -- ========================================================================
    -- STEP 2: Now we have PO, trace missing links
    -- ========================================================================
    
    -- If we have PO but no PR, find PR
    IF v_po_id IS NOT NULL AND v_pr_id IS NULL THEN
        SELECT DISTINCT ppl.pr_id, pr.pr_number, pr.status, pr.created_at
        INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM pr_po_linkage ppl
        JOIN purchase_requests pr ON pr.id = ppl.pr_id
        WHERE ppl.po_id = v_po_id AND ppl.status = 'active' AND pr.deleted = FALSE
        LIMIT 1;
        
        IF v_pr_id IS NULL THEN
            SELECT DISTINCT pri.pr_id, pr.pr_number, pr.status, pr.created_at
            INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
            FROM purchase_request_items pri
            JOIN purchase_requests pr ON pr.id = pri.pr_id
            WHERE pri.po_id = v_po_id AND pr.deleted = FALSE
            LIMIT 1;
        END IF;
    END IF;
    
    -- If we have PO but no GRN, find GRN
    IF v_po_id IS NOT NULL AND v_grn_id IS NULL THEN
        SELECT id, grn_number, status, grn_date
        INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM grn_inspections
        WHERE purchase_order_id = v_po_id AND deleted = FALSE
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- If we have GRN but no PUR, find PUR
    IF v_grn_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id, purchasing_number, status, created_at
        INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices
        WHERE grn_id = v_grn_id AND deleted = FALSE
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- If we have PO but no PUR (and no GRN path), find PUR via PO
    IF v_po_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id, purchasing_number, status, created_at
        INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices
        WHERE purchase_order_id = v_po_id AND deleted = FALSE
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;
    
    -- ========================================================================
    -- STEP 3: Return results in order
    -- ========================================================================
    
    -- Return PR
    IF v_pr_id IS NOT NULL THEN
        RETURN QUERY SELECT 
            'PR'::TEXT,
            v_pr_id::TEXT,
            v_pr_number,
            v_pr_status,
            v_pr_date,
            (v_normalized_type IN ('PR', 'PURCHASE_REQUEST')),
            1;
    ELSE
        -- Return placeholder for missing PR
        RETURN QUERY SELECT 
            'PR'::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            'not_created'::TEXT,
            NULL::TIMESTAMPTZ,
            FALSE,
            1;
    END IF;
    
    -- Return PO
    IF v_po_id IS NOT NULL THEN
        RETURN QUERY SELECT 
            'PO'::TEXT,
            v_po_id::TEXT,
            v_po_number,
            v_po_status,
            v_po_date,
            (v_normalized_type IN ('PO', 'PURCHASE_ORDER')),
            2;
    ELSE
        RETURN QUERY SELECT 
            'PO'::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            'not_created'::TEXT,
            NULL::TIMESTAMPTZ,
            FALSE,
            2;
    END IF;
    
    -- Return GRN
    IF v_grn_id IS NOT NULL THEN
        RETURN QUERY SELECT 
            'GRN'::TEXT,
            v_grn_id::TEXT,
            v_grn_number,
            v_grn_status,
            v_grn_date,
            (v_normalized_type IN ('GRN', 'GOODS_RECEIPT')),
            3;
    ELSE
        RETURN QUERY SELECT 
            'GRN'::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            'not_created'::TEXT,
            NULL::TIMESTAMPTZ,
            FALSE,
            3;
    END IF;
    
    -- Return PUR
    IF v_pur_id IS NOT NULL THEN
        RETURN QUERY SELECT 
            'PUR'::TEXT,
            v_pur_id::TEXT,
            v_pur_number,
            v_pur_status,
            v_pur_date,
            (v_normalized_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING_INVOICE')),
            4;
    ELSE
        RETURN QUERY SELECT 
            'PUR'::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            'not_created'::TEXT,
            NULL::TIMESTAMPTZ,
            FALSE,
            4;
    END IF;
    
    RETURN;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO anon;

-- ============================================================================
-- TEST QUERY
-- ============================================================================
-- SELECT * FROM fn_get_document_flow('PR', 'your-pr-uuid-here');
-- SELECT * FROM fn_get_document_flow('PO', '70');
-- SELECT * FROM fn_get_document_flow('GRN', 'your-grn-uuid-here');
-- SELECT * FROM fn_get_document_flow('PUR', 'your-pur-uuid-here');

COMMENT ON FUNCTION fn_get_document_flow IS 'SAP VBFA-style document flow function. Returns full chain PR→PO→GRN→PUR for any document.';
