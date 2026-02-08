-- ============================================================================
-- COMPLETE_FIX_RUN_THIS.sql
-- 
-- COMPLETE FIX FOR DOCUMENT FLOW ISSUES
-- RUN THIS ENTIRE FILE IN SUPABASE SQL EDITOR
-- ============================================================================

-- ============================================================================
-- STEP 1: Ensure purchasing_invoices table exists with all required columns
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchasing_invoices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference Links
    grn_id uuid,
    grn_number text,
    purchase_order_id bigint,
    purchase_order_number text,
    
    -- Supplier Information
    supplier_id bigint,
    supplier_name text,
    
    -- Invoice Details
    purchasing_number text,  -- SAP document number
    invoice_number text,     -- Vendor invoice number
    invoice_date date,
    receiving_location text,
    
    -- Financial Fields
    subtotal numeric(15,2) DEFAULT 0,
    tax_rate numeric(5,2) DEFAULT 15,
    tax_amount numeric(15,2) DEFAULT 0,
    discount_amount numeric(15,2) DEFAULT 0,
    total_amount numeric(15,2) DEFAULT 0,
    grand_total numeric(15,2) DEFAULT 0,
    currency text DEFAULT 'SAR',
    
    -- Payment Terms
    payment_terms_days integer DEFAULT 30,
    due_date date,
    payment_status text DEFAULT 'unpaid',
    
    -- Workflow Status
    status text DEFAULT 'draft',
    
    -- Audit Fields
    created_by text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    approved_by text,
    approved_at timestamptz,
    posted_by text,
    posted_at timestamptz,
    
    -- GL Posting Reference
    gl_journal_id uuid,
    
    -- Soft Delete
    deleted boolean DEFAULT false,
    deleted_at timestamptz,
    
    -- Notes
    notes text,
    external_reference text
);

-- Add purchasing_number column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchasing_invoices' AND column_name = 'purchasing_number'
    ) THEN
        ALTER TABLE purchasing_invoices ADD COLUMN purchasing_number text;
    END IF;
END $$;

-- Create purchasing_invoice_items table if not exists
CREATE TABLE IF NOT EXISTS purchasing_invoice_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    purchasing_invoice_id uuid NOT NULL REFERENCES purchasing_invoices(id) ON DELETE CASCADE,
    
    -- Item Reference
    item_id uuid,
    item_name text,
    item_code text,
    
    -- Quantities
    quantity numeric(15,3) NOT NULL DEFAULT 0,
    unit_of_measure text,
    
    -- Pricing
    unit_cost numeric(15,4) DEFAULT 0,
    total_cost numeric(15,2) DEFAULT 0,
    tax_amount numeric(15,2) DEFAULT 0,
    
    -- Batch Reference
    batch_id text,
    batch_number text,
    
    -- GL Account
    gl_account_code text,
    cost_center text,
    
    -- Metadata
    created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- STEP 2: Create simple document flow functions
-- ============================================================================

-- Drop existing functions
DROP FUNCTION IF EXISTS fn_get_document_flow_json(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT) CASCADE;

-- FUNCTION: fn_get_document_flow_json
CREATE OR REPLACE FUNCTION fn_get_document_flow_json(p_doc_type TEXT, p_doc_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_type TEXT;
    v_pr_id UUID;
    v_po_id BIGINT;
    v_grn_id UUID;
    v_pur_id UUID;
    v_result JSONB;
    v_pr_data JSONB := '[]'::JSONB;
    v_po_data JSONB := '[]'::JSONB;
    v_grn_data JSONB := '[]'::JSONB;
    v_pur_data JSONB := '[]'::JSONB;
BEGIN
    v_type := UPPER(TRIM(COALESCE(p_doc_type, '')));
    
    -- Parse input ID based on type
    IF v_type IN ('PR', 'PURCHASE_REQUEST') THEN
        v_pr_id := p_doc_id::UUID;
    ELSIF v_type IN ('PO', 'PURCHASE_ORDER') THEN
        BEGIN
            v_po_id := p_doc_id::BIGINT;
        EXCEPTION WHEN OTHERS THEN
            v_po_id := NULL;
        END;
    ELSIF v_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN
        v_grn_id := p_doc_id::UUID;
    ELSIF v_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN
        v_pur_id := p_doc_id::UUID;
    END IF;
    
    -- Trace from PUR backwards
    IF v_pur_id IS NOT NULL THEN
        SELECT grn_id, purchase_order_id INTO v_grn_id, v_po_id
        FROM purchasing_invoices WHERE id = v_pur_id;
    END IF;
    
    -- Trace from GRN backwards
    IF v_grn_id IS NOT NULL AND v_po_id IS NULL THEN
        SELECT purchase_order_id INTO v_po_id
        FROM grn_inspections WHERE id = v_grn_id;
    END IF;
    
    -- Trace from PO backwards to PR
    IF v_po_id IS NOT NULL AND v_pr_id IS NULL THEN
        SELECT pr_id INTO v_pr_id
        FROM pr_po_linkage WHERE po_id = v_po_id LIMIT 1;
    END IF;
    
    -- Trace from PR forwards to PO
    IF v_pr_id IS NOT NULL AND v_po_id IS NULL THEN
        SELECT po_id INTO v_po_id
        FROM pr_po_linkage WHERE pr_id = v_pr_id LIMIT 1;
    END IF;
    
    -- Trace from PO forwards to GRN
    IF v_po_id IS NOT NULL AND v_grn_id IS NULL THEN
        SELECT id INTO v_grn_id
        FROM grn_inspections 
        WHERE purchase_order_id = v_po_id AND deleted = FALSE 
        LIMIT 1;
    END IF;
    
    -- Trace from GRN forwards to PUR
    IF v_grn_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id INTO v_pur_id
        FROM purchasing_invoices 
        WHERE grn_id = v_grn_id AND deleted = FALSE 
        LIMIT 1;
    END IF;
    
    -- Trace from PO forwards to PUR (direct)
    IF v_po_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id INTO v_pur_id
        FROM purchasing_invoices 
        WHERE purchase_order_id = v_po_id AND deleted = FALSE 
        LIMIT 1;
    END IF;
    
    -- Get PR data
    IF v_pr_id IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', id, 'number', pr_number, 'status', status, 
            'date', created_at, 'requester', requester_name,
            'department', department, 'total_amount', COALESCE(estimated_total_value, 0)
        )) INTO v_pr_data
        FROM purchase_requests WHERE id = v_pr_id AND deleted = FALSE;
    END IF;
    
    -- Get PO data
    IF v_po_id IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', id, 'number', po_number, 'status', status,
            'date', order_date, 'supplier', supplier_name,
            'total_amount', COALESCE(total_amount, 0)
        )) INTO v_po_data
        FROM purchase_orders WHERE id = v_po_id AND deleted = FALSE;
    END IF;
    
    -- Get GRN data
    IF v_grn_id IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', id, 'number', grn_number, 'status', status,
            'date', grn_date, 'received_by', received_by,
            'total_quantity', total_received_quantity
        )) INTO v_grn_data
        FROM grn_inspections WHERE id = v_grn_id AND deleted = FALSE;
    END IF;
    
    -- Get PUR data
    IF v_pur_id IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_object(
            'id', id, 'number', COALESCE(purchasing_number, invoice_number), 
            'status', status, 'date', COALESCE(invoice_date, created_at),
            'payment_status', payment_status, 'grand_total', COALESCE(grand_total, 0)
        )) INTO v_pur_data
        FROM purchasing_invoices WHERE id = v_pur_id AND deleted = FALSE;
    END IF;
    
    RETURN jsonb_build_object(
        'pr', COALESCE(v_pr_data, '[]'::JSONB),
        'po', COALESCE(v_po_data, '[]'::JSONB),
        'grn', COALESCE(v_grn_data, '[]'::JSONB),
        'pur', COALESCE(v_pur_data, '[]'::JSONB),
        'start_type', v_type,
        'start_id', p_doc_id,
        'debug', jsonb_build_object('pr_id', v_pr_id, 'po_id', v_po_id, 'grn_id', v_grn_id, 'pur_id', v_pur_id)
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'error', SQLERRM,
        'pr', '[]'::JSONB, 'po', '[]'::JSONB, 'grn', '[]'::JSONB, 'pur', '[]'::JSONB
    );
END;
$$;

-- FUNCTION: fn_get_document_flow (table format)
CREATE OR REPLACE FUNCTION fn_get_document_flow(p_doc_type TEXT, p_doc_id TEXT)
RETURNS TABLE (
    doc_type TEXT, doc_id TEXT, doc_number TEXT, doc_status TEXT,
    doc_date TIMESTAMPTZ, is_current BOOLEAN, sequence_order INT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_graph JSONB;
    v_current_type TEXT;
BEGIN
    v_current_type := UPPER(TRIM(COALESCE(p_doc_type, '')));
    v_current_type := CASE 
        WHEN v_current_type IN ('PR', 'PURCHASE_REQUEST') THEN 'PR'
        WHEN v_current_type IN ('PO', 'PURCHASE_ORDER') THEN 'PO'
        WHEN v_current_type IN ('GRN', 'GR', 'GOODS_RECEIPT', 'MIGO') THEN 'GRN'
        WHEN v_current_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING', 'MIRO') THEN 'PUR'
        ELSE v_current_type 
    END;
    
    v_graph := fn_get_document_flow_json(p_doc_type, p_doc_id);
    
    -- PR
    IF jsonb_array_length(COALESCE(v_graph->'pr', '[]'::JSONB)) > 0 THEN
        RETURN QUERY SELECT 'PR'::TEXT, (v_graph->'pr'->0->>'id'), (v_graph->'pr'->0->>'number'),
            (v_graph->'pr'->0->>'status'), (v_graph->'pr'->0->>'date')::TIMESTAMPTZ, (v_current_type = 'PR'), 1;
    ELSE
        RETURN QUERY SELECT 'PR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 1;
    END IF;
    
    -- PO
    IF jsonb_array_length(COALESCE(v_graph->'po', '[]'::JSONB)) > 0 THEN
        RETURN QUERY SELECT 'PO'::TEXT, (v_graph->'po'->0->>'id'), (v_graph->'po'->0->>'number'),
            (v_graph->'po'->0->>'status'), (v_graph->'po'->0->>'date')::TIMESTAMPTZ, (v_current_type = 'PO'), 2;
    ELSE
        RETURN QUERY SELECT 'PO'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 2;
    END IF;
    
    -- GRN
    IF jsonb_array_length(COALESCE(v_graph->'grn', '[]'::JSONB)) > 0 THEN
        RETURN QUERY SELECT 'GRN'::TEXT, (v_graph->'grn'->0->>'id'), (v_graph->'grn'->0->>'number'),
            (v_graph->'grn'->0->>'status'), (v_graph->'grn'->0->>'date')::TIMESTAMPTZ, (v_current_type = 'GRN'), 3;
    ELSE
        RETURN QUERY SELECT 'GRN'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 3;
    END IF;
    
    -- PUR
    IF jsonb_array_length(COALESCE(v_graph->'pur', '[]'::JSONB)) > 0 THEN
        RETURN QUERY SELECT 'PUR'::TEXT, (v_graph->'pur'->0->>'id'), (v_graph->'pur'->0->>'number'),
            (v_graph->'pur'->0->>'status'), (v_graph->'pur'->0->>'date')::TIMESTAMPTZ, (v_current_type = 'PUR'), 4;
    ELSE
        RETURN QUERY SELECT 'PUR'::TEXT, NULL::TEXT, NULL::TEXT, 'not_created'::TEXT, NULL::TIMESTAMPTZ, FALSE, 4;
    END IF;
    
    RETURN;
END;
$$;

-- ============================================================================
-- STEP 3: Grant permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION fn_get_document_flow_json(TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON purchasing_invoices TO authenticated;
GRANT SELECT, INSERT, UPDATE ON purchasing_invoice_items TO authenticated;

-- ============================================================================
-- STEP 4: Create indexes for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_purchase_order_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_purchase_order_id ON purchasing_invoices(purchase_order_id);

-- ============================================================================
-- STEP 5: VERIFICATION - Test the functions
-- ============================================================================
SELECT 'INSTALLATION COMPLETE!' AS status;
SELECT 'Testing functions...' AS step;

-- Test with a sample GRN
DO $$
DECLARE
    v_grn_id TEXT;
    v_result JSONB;
BEGIN
    SELECT id::TEXT INTO v_grn_id 
    FROM grn_inspections 
    WHERE deleted = FALSE AND purchase_order_id IS NOT NULL 
    LIMIT 1;
    
    IF v_grn_id IS NOT NULL THEN
        v_result := fn_get_document_flow_json('GRN', v_grn_id);
        RAISE NOTICE '✅ Test Result for GRN: %', v_result;
    ELSE
        RAISE NOTICE '⚠️ No GRN with linked PO found for testing';
    END IF;
END $$;

-- Show function verification
SELECT 
    proname AS function_name,
    '✅ Created' AS status
FROM pg_proc 
WHERE proname IN ('fn_get_document_flow_json', 'fn_get_document_flow')
AND pronamespace = 'public'::regnamespace;
