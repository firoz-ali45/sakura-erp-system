-- ============================================================================
-- 03_DOCUMENT_FLOW_TRIGGERS.sql
-- AUTO-INSERT DOCUMENT FLOW TRIGGERS
-- SAP-style automatic document linking
-- ============================================================================

-- ============================================================================
-- HELPER FUNCTION: Safe insert into document_flow
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_insert_document_flow(
    p_source_type TEXT,
    p_source_id TEXT,
    p_source_number TEXT,
    p_target_type TEXT,
    p_target_id TEXT,
    p_target_number TEXT,
    p_flow_type TEXT DEFAULT 'created_from'
)
RETURNS VOID
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
        p_source_type,
        p_source_id,
        p_source_number,
        p_target_type,
        p_target_id,
        p_target_number,
        p_flow_type,
        NOW()
    )
    ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    -- Log but don't fail
    RAISE NOTICE 'Document flow insert failed: %', SQLERRM;
END;
$$;

-- ============================================================================
-- TRIGGER 1: PR → PO (When pr_po_linkage is inserted)
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_pr_po_linkage_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_pr_number TEXT;
BEGIN
    -- Get PR number if not provided
    IF NEW.pr_number IS NULL THEN
        SELECT pr_number INTO v_pr_number
        FROM purchase_requests
        WHERE id = NEW.pr_id;
    ELSE
        v_pr_number := NEW.pr_number;
    END IF;
    
    -- Insert document flow: PR → PO
    PERFORM fn_insert_document_flow(
        'PR',
        NEW.pr_id::TEXT,
        v_pr_number,
        'PO',
        NEW.po_id::TEXT,
        NEW.po_number,
        'converted_to_po'
    );
    
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_document_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_pr_po_linkage_document_flow();

-- ============================================================================
-- TRIGGER 2: PO → GRN (When GRN is created with purchase_order_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_po_number TEXT;
BEGIN
    -- Only process if purchase_order_id is set
    IF NEW.purchase_order_id IS NOT NULL THEN
        -- Get PO number
        SELECT po_number INTO v_po_number
        FROM purchase_orders
        WHERE id = NEW.purchase_order_id;
        
        -- Insert document flow: PO → GRN
        PERFORM fn_insert_document_flow(
            'PO',
            NEW.purchase_order_id::TEXT,
            COALESCE(v_po_number, NEW.purchase_order_number),
            'GRN',
            NEW.id::TEXT,
            NEW.grn_number,
            'goods_received'
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;
CREATE TRIGGER trg_grn_document_flow
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_grn_document_flow();

-- ============================================================================
-- TRIGGER 3: GRN → PUR (When Purchasing Invoice is created with grn_id)
-- ============================================================================
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
        
        -- Insert document flow: GRN → PUR
        PERFORM fn_insert_document_flow(
            'GRN',
            NEW.grn_id::TEXT,
            COALESCE(v_grn_number, NEW.grn_number),
            'PUR',
            NEW.id::TEXT,
            NEW.purchasing_number,
            'invoice_created'
        );
    END IF;
    
    -- If linked directly to PO (and no GRN)
    IF NEW.purchase_order_id IS NOT NULL AND NEW.grn_id IS NULL THEN
        -- Get PO number
        SELECT po_number INTO v_po_number
        FROM purchase_orders
        WHERE id = NEW.purchase_order_id;
        
        -- Insert document flow: PO → PUR
        PERFORM fn_insert_document_flow(
            'PO',
            NEW.purchase_order_id::TEXT,
            COALESCE(v_po_number, NEW.purchase_order_number),
            'PUR',
            NEW.id::TEXT,
            NEW.purchasing_number,
            'invoice_created'
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
CREATE TRIGGER trg_purchasing_invoice_document_flow
    AFTER INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_purchasing_invoice_document_flow();

-- ============================================================================
-- TRIGGER 4: Update PR items when linked to PO
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_pr_po_linkage_update_pr_items()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_ordered NUMERIC;
BEGIN
    -- Calculate total ordered quantity for this PR item
    SELECT COALESCE(SUM(converted_quantity), 0)
    INTO v_total_ordered
    FROM pr_po_linkage
    WHERE pr_item_id = NEW.pr_item_id
      AND status = 'active';
    
    -- Update PR item
    UPDATE purchase_request_items
    SET 
        quantity_ordered = v_total_ordered,
        po_id = NEW.po_id,
        po_number = NEW.po_number,
        status = CASE
            WHEN v_total_ordered >= quantity THEN 'converted_to_po'
            WHEN v_total_ordered > 0 THEN 'partially_converted'
            ELSE status
        END,
        conversion_date = CASE WHEN v_total_ordered >= quantity THEN NOW() ELSE conversion_date END,
        is_locked = (v_total_ordered >= quantity),
        updated_at = NOW()
    WHERE id = NEW.pr_item_id;
    
    -- Update PR status
    PERFORM fn_update_pr_status_from_items(NEW.pr_id);
    
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_pr_po_linkage_update_pr_items ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_update_pr_items
    AFTER INSERT OR UPDATE ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_pr_po_linkage_update_pr_items();

-- ============================================================================
-- HELPER FUNCTION: Update PR status from items
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_update_pr_status_from_items(p_pr_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_items INT;
    v_converted_items INT;
    v_partial_items INT;
    v_new_status TEXT;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN status = 'converted_to_po' THEN 1 END),
        COUNT(CASE WHEN status = 'partially_converted' THEN 1 END)
    INTO v_total_items, v_converted_items, v_partial_items
    FROM purchase_request_items
    WHERE pr_id = p_pr_id
      AND (deleted = FALSE OR deleted IS NULL);
    
    IF v_total_items = 0 THEN
        RETURN;
    END IF;
    
    IF v_converted_items >= v_total_items THEN
        v_new_status := 'fully_ordered';
    ELSIF v_converted_items > 0 OR v_partial_items > 0 THEN
        v_new_status := 'partially_ordered';
    ELSE
        RETURN; -- Keep current status
    END IF;
    
    UPDATE purchase_requests
    SET status = v_new_status, updated_at = NOW()
    WHERE id = p_pr_id
      AND status NOT IN ('closed', 'cancelled', 'rejected');
END;
$$;

-- ============================================================================
-- TRIGGER 5: Update PO receiving status when GRN items change
-- ============================================================================
CREATE OR REPLACE FUNCTION trg_fn_grn_items_update_po()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_po_id BIGINT;
    v_total_ordered NUMERIC;
    v_total_received NUMERIC;
    v_new_status TEXT;
BEGIN
    -- Get PO ID from the GRN
    SELECT purchase_order_id INTO v_po_id
    FROM grn_inspections
    WHERE id = COALESCE(NEW.grn_inspection_id, OLD.grn_inspection_id);
    
    IF v_po_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Calculate totals
    SELECT 
        COALESCE(SUM(poi.quantity), 0),
        COALESCE(SUM(poi.quantity_received), 0)
    INTO v_total_ordered, v_total_received
    FROM purchase_order_items poi
    WHERE poi.purchase_order_id = v_po_id;
    
    -- Update each PO item's received quantity
    UPDATE purchase_order_items poi
    SET quantity_received = (
        SELECT COALESCE(SUM(gii.received_quantity), 0)
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE gi.purchase_order_id = v_po_id
          AND gii.item_id = poi.item_id
          AND gi.status IN ('approved', 'passed', 'completed')
    )
    WHERE poi.purchase_order_id = v_po_id;
    
    -- Recalculate totals after update
    SELECT 
        COALESCE(SUM(quantity), 0),
        COALESCE(SUM(quantity_received), 0)
    INTO v_total_ordered, v_total_received
    FROM purchase_order_items
    WHERE purchase_order_id = v_po_id;
    
    -- Determine status
    IF v_total_received >= v_total_ordered AND v_total_ordered > 0 THEN
        v_new_status := 'fully_received';
    ELSIF v_total_received > 0 THEN
        v_new_status := 'partial_received';
    ELSE
        v_new_status := 'not_received';
    END IF;
    
    -- Update PO
    UPDATE purchase_orders
    SET 
        total_received_quantity = v_total_received,
        remaining_quantity = GREATEST(0, v_total_ordered - v_total_received),
        receiving_status = v_new_status,
        updated_at = NOW()
    WHERE id = v_po_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trg_grn_items_update_po ON grn_inspection_items;
CREATE TRIGGER trg_grn_items_update_po
    AFTER INSERT OR UPDATE OR DELETE ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_grn_items_update_po();

-- ============================================================================
-- Grant execute permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION fn_insert_document_flow TO authenticated;
GRANT EXECUTE ON FUNCTION fn_update_pr_status_from_items TO authenticated;

COMMENT ON FUNCTION fn_insert_document_flow IS 'Helper to safely insert document flow records';
COMMENT ON FUNCTION fn_update_pr_status_from_items IS 'Updates PR status based on item conversion status';
