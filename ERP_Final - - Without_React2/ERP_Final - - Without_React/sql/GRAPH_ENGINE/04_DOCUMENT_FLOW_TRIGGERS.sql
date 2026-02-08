-- ============================================================================
-- 04_DOCUMENT_FLOW_TRIGGERS.sql
-- DOCUMENT FLOW AUDIT LOGGING (SAP VBFA STYLE)
-- 
-- IMPORTANT: These triggers log to document_flow table for AUDIT purposes only.
-- The recursive graph engine DOES NOT use document_flow as source of truth.
-- Source of truth is always: pr_po_linkage, grn_inspections, purchasing_invoices
--
-- NOTE: Matches your actual document_flow table schema:
-- (id, source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
-- ============================================================================

-- ============================================================================
-- TRIGGER FUNCTION 1: Log PR → PO Conversion
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_log_pr_po_conversion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr_number TEXT;
BEGIN
    -- Get PR number
    SELECT pr_number INTO v_pr_number
    FROM purchase_requests
    WHERE id = NEW.pr_id;
    
    -- Insert document flow record
    INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type
    ) VALUES (
        'PR',
        NEW.pr_id::TEXT,
        v_pr_number,
        'PO',
        NEW.po_id::TEXT,
        NEW.po_number,
        'PR_TO_PO'
    )
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Don't fail the main transaction
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_document_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_log_pr_po_conversion();

-- ============================================================================
-- TRIGGER FUNCTION 2: Log PO → GRN Creation
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_log_po_grn_creation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_po_number TEXT;
BEGIN
    -- Only log when GRN is created (not updated)
    IF TG_OP = 'INSERT' AND NEW.purchase_order_id IS NOT NULL THEN
        -- Get PO number
        SELECT po_number INTO v_po_number
        FROM purchase_orders
        WHERE id = NEW.purchase_order_id;
        
        -- Insert document flow record
        INSERT INTO document_flow (
            source_type,
            source_id,
            source_number,
            target_type,
            target_id,
            target_number,
            flow_type
        ) VALUES (
            'PO',
            NEW.purchase_order_id::TEXT,
            v_po_number,
            'GRN',
            NEW.id::TEXT,
            NEW.grn_number,
            'PO_TO_GRN'
        )
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;
CREATE TRIGGER trg_grn_document_flow
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_log_po_grn_creation();

-- ============================================================================
-- TRIGGER FUNCTION 3: Log GRN → PUR Creation
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_log_grn_pur_creation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_grn_number TEXT;
    v_po_number TEXT;
BEGIN
    -- Only log when PUR is created (not updated)
    IF TG_OP = 'INSERT' THEN
        -- GRN-based invoice
        IF NEW.grn_id IS NOT NULL THEN
            SELECT grn_number INTO v_grn_number
            FROM grn_inspections
            WHERE id = NEW.grn_id;
            
            INSERT INTO document_flow (
                source_type,
                source_id,
                source_number,
                target_type,
                target_id,
                target_number,
                flow_type
            ) VALUES (
                'GRN',
                NEW.grn_id::TEXT,
                v_grn_number,
                'PUR',
                NEW.id::TEXT,
                NEW.purchasing_number,
                'GRN_TO_PUR'
            )
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Direct PO-based invoice (when no GRN)
        IF NEW.purchase_order_id IS NOT NULL AND NEW.grn_id IS NULL THEN
            SELECT po_number INTO v_po_number
            FROM purchase_orders
            WHERE id = NEW.purchase_order_id;
            
            INSERT INTO document_flow (
                source_type,
                source_id,
                source_number,
                target_type,
                target_id,
                target_number,
                flow_type
            ) VALUES (
                'PO',
                NEW.purchase_order_id::TEXT,
                v_po_number,
                'PUR',
                NEW.id::TEXT,
                NEW.purchasing_number,
                'PO_TO_PUR'
            )
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
CREATE TRIGGER trg_purchasing_invoice_document_flow
    AFTER INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_log_grn_pur_creation();

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON FUNCTION trg_fn_log_pr_po_conversion IS 'Trigger to log PR to PO conversions';
COMMENT ON FUNCTION trg_fn_log_po_grn_creation IS 'Trigger to log GRN creation from PO';
COMMENT ON FUNCTION trg_fn_log_grn_pur_creation IS 'Trigger to log purchasing invoice creation';

SELECT 'TRIGGERS CREATED!' AS message;
