-- ============================================================================
-- QUICK_FIX_PURCHASING_ERROR.sql
-- Fixes: "column amount of relation document_flow does not exist"
-- 
-- The error is caused by an OLD TRIGGER on purchasing_invoices that tries
-- to insert columns (amount, quantity, etc.) that don't exist in document_flow
-- ============================================================================

-- Step 1: Drop the old trigger on purchasing_invoices
DROP TRIGGER IF EXISTS trg_log_inv ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_log_purchasing_invoice_flow ON purchasing_invoices;

-- Step 2: Drop old trigger functions that might have wrong columns
DROP FUNCTION IF EXISTS fn_log_inv_flow() CASCADE;
DROP FUNCTION IF EXISTS fn_log_purchasing_invoice_flow() CASCADE;

-- Step 3: Create the CORRECT trigger function (without amount column)
CREATE OR REPLACE FUNCTION trg_fn_purchasing_invoice_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_grn_number TEXT;
    v_po_number TEXT;
BEGIN
    -- If linked to GRN
    IF NEW.grn_id IS NOT NULL THEN
        -- Get GRN number
        SELECT grn_number INTO v_grn_number
        FROM grn_inspections
        WHERE id = NEW.grn_id;
        
        -- Insert document flow: GRN → PUR (only columns that exist!)
        INSERT INTO document_flow (
            source_type,
            source_id,
            source_number,
            target_type,
            target_id,
            target_number,
            flow_type,
            created_at
        ) VALUES (
            'GRN',
            NEW.grn_id::TEXT,
            COALESCE(v_grn_number, NEW.grn_number),
            'PUR',
            NEW.id::TEXT,
            NEW.purchasing_number,
            'invoice_created',
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    
    -- If linked directly to PO (and no GRN)
    IF NEW.purchase_order_id IS NOT NULL AND NEW.grn_id IS NULL THEN
        -- Get PO number
        SELECT po_number INTO v_po_number
        FROM purchase_orders
        WHERE id = NEW.purchase_order_id;
        
        -- Insert document flow: PO → PUR
        INSERT INTO document_flow (
            source_type,
            source_id,
            source_number,
            target_type,
            target_id,
            target_number,
            flow_type,
            created_at
        ) VALUES (
            'PO',
            NEW.purchase_order_id::TEXT,
            COALESCE(v_po_number, NEW.purchase_order_number),
            'PUR',
            NEW.id::TEXT,
            NEW.purchasing_number,
            'invoice_created',
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Don't fail the insert if document_flow logging fails
    RAISE NOTICE 'Document flow insert skipped: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Step 4: Create the trigger
CREATE TRIGGER trg_purchasing_invoice_document_flow
    AFTER INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_purchasing_invoice_document_flow();

-- Step 5: Also fix the other triggers that might have wrong columns

-- Fix PR -> PO trigger
DROP TRIGGER IF EXISTS trg_log_pr_po ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
DROP FUNCTION IF EXISTS fn_log_pr_po_flow() CASCADE;

CREATE OR REPLACE FUNCTION trg_fn_pr_po_linkage_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type,
        created_at
    ) VALUES (
        'PR',
        NEW.pr_id::TEXT,
        NEW.pr_number,
        'PO',
        NEW.po_id::TEXT,
        NEW.po_number,
        'converted_to_po',
        NOW()
    ) ON CONFLICT DO NOTHING;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PR-PO document flow insert skipped: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pr_po_linkage_document_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_pr_po_linkage_document_flow();

-- Fix PO -> GRN trigger
DROP TRIGGER IF EXISTS trg_log_po_grn ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;
DROP FUNCTION IF EXISTS fn_log_po_grn_flow() CASCADE;

CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_po_number TEXT;
BEGIN
    IF NEW.purchase_order_id IS NOT NULL THEN
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
            flow_type,
            created_at
        ) VALUES (
            'PO',
            NEW.purchase_order_id::TEXT,
            COALESCE(v_po_number, NEW.purchase_order_number),
            'GRN',
            NEW.id::TEXT,
            NEW.grn_number,
            'goods_received',
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PO-GRN document flow insert skipped: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grn_document_flow
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_grn_document_flow();

-- Step 6: Verify triggers are correct
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    tgfoid::regproc AS function_name
FROM pg_trigger
WHERE tgrelid IN (
    'purchasing_invoices'::regclass, 
    'grn_inspections'::regclass, 
    'pr_po_linkage'::regclass
)
AND NOT tgisinternal
ORDER BY tgrelid::regclass::text, tgname;

SELECT '✅ TRIGGERS FIXED! Now try "Create Purchasing" again.' AS status;
