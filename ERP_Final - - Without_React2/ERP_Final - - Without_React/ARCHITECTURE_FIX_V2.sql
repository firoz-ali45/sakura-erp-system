-- ============================================================================
-- SAKURA ERP - COMPLETE ARCHITECTURE FIX V2
-- ============================================================================
-- Version: 3.1.0
-- Date: 2026-01-26
-- FIX: Removed direct updates to generated column quantity_remaining
-- SAP Reference: EBAN → EKKO/EKPO → EKBE → RBKP/RSEG
-- ============================================================================

-- ============================================================================
-- PART 1: DROP ALL EXISTING TRIGGERS AND FUNCTIONS
-- ============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all triggers on relevant tables
    FOR r IN 
        SELECT tgname, relname 
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE relname IN ('grn_inspection_items', 'grn_inspections', 'pr_po_linkage', 
                          'purchase_requests', 'purchase_orders', 'purchase_order_items',
                          'purchasing_invoices', 'ap_payments')
        AND NOT tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I', r.tgname, r.relname);
    END LOOP;
    
    -- Drop all related functions
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname IN (
            'trg_grn_item_update_po_qty',
            'trg_grn_status_update_po',
            'trg_pr_po_linkage_update_pr',
            'trg_pr_po_linkage_document_flow',
            'trg_pr_status_history',
            'trg_grn_document_flow',
            'trg_purchasing_invoice_document_flow',
            'trg_ap_payment_document_flow',
            'trg_update_pr_item_on_linkage',
            'update_po_receiving_status',
            'update_po_receiving_status_v2',
            'insert_document_flow',
            'insert_document_flow_bigint',
            'get_pr_linked_pos',
            'get_pr_status_history',
            'get_document_flow',
            'update_po_received_quantities',
            'recalculate_all_po_receiving',
            'trg_grn_item_update_po_receipt',
            'trg_grn_status_change_update_po',
            'trg_pr_log_status_history',
            'trg_purchasing_invoice_doc_flow'
        )
    LOOP
        BEGIN
            EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;
    
    RAISE NOTICE 'All existing triggers and functions dropped';
END $$;

-- ============================================================================
-- PART 2: DROP AND RECREATE VIEWS
-- ============================================================================

DROP VIEW IF EXISTS v_po_receipt_summary CASCADE;
DROP VIEW IF EXISTS v_po_item_receipts_detailed CASCADE;
DROP VIEW IF EXISTS v_po_item_receipts CASCADE;
DROP VIEW IF EXISTS v_pr_po_summary CASCADE;
DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;
DROP VIEW IF EXISTS v_document_flow_timeline CASCADE;

-- ============================================================================
-- PART 3: CORE FUNCTION - INSERT DOCUMENT FLOW (TEXT-BASED POLYMORPHIC)
-- ============================================================================

CREATE OR REPLACE FUNCTION insert_document_flow(
    p_source_type TEXT,
    p_source_id TEXT,
    p_source_number TEXT,
    p_target_type TEXT,
    p_target_id TEXT,
    p_target_number TEXT,
    p_flow_type TEXT DEFAULT 'follows'
)
RETURNS UUID AS $$
DECLARE
    v_flow_id UUID;
BEGIN
    -- Check if already exists
    SELECT id INTO v_flow_id
    FROM document_flow
    WHERE source_type = p_source_type
      AND source_number = p_source_number
      AND target_type = p_target_type
      AND target_number = p_target_number;
    
    IF v_flow_id IS NOT NULL THEN
        RETURN v_flow_id;
    END IF;
    
    -- Insert new
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type, created_at
    ) VALUES (
        p_source_type, p_source_id, p_source_number,
        p_target_type, p_target_id, p_target_number,
        p_flow_type, NOW()
    )
    RETURNING id INTO v_flow_id;
    
    RETURN v_flow_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'insert_document_flow error: %', SQLERRM;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 4: TRIGGER - GRN ITEM → UPDATE PO ITEM QUANTITY_RECEIVED
-- (SAP EKBE → EKPO Logic)
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_grn_item_update_po_receipt()
RETURNS TRIGGER AS $$
DECLARE
    v_po_id BIGINT;
    v_po_item_id UUID;
    v_grn_status TEXT;
    v_total_received NUMERIC;
BEGIN
    -- Get GRN status and PO info
    SELECT gi.status, gi.purchase_order_id 
    INTO v_grn_status, v_po_id
    FROM grn_inspections gi
    WHERE gi.id = COALESCE(NEW.grn_inspection_id, OLD.grn_inspection_id);
    
    -- Only process for approved GRNs
    IF v_grn_status NOT IN ('passed', 'approved', 'conditional') THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get PO Item ID - try from GRN item first, then match by item_id
    v_po_item_id := COALESCE(NEW.po_item_id, OLD.po_item_id);
    
    IF v_po_item_id IS NULL AND v_po_id IS NOT NULL THEN
        SELECT poi.id INTO v_po_item_id
        FROM purchase_order_items poi
        WHERE poi.purchase_order_id = v_po_id
          AND poi.item_id = COALESCE(NEW.item_id, OLD.item_id)
        LIMIT 1;
    END IF;
    
    IF v_po_item_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Calculate total received for this PO item from all approved GRNs
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO v_total_received
    FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
    WHERE (gii.po_item_id = v_po_item_id OR 
           (gii.item_id = COALESCE(NEW.item_id, OLD.item_id) AND gi.purchase_order_id = v_po_id))
      AND gi.status IN ('passed', 'approved', 'conditional')
      AND (gi.deleted = FALSE OR gi.deleted IS NULL);
    
    -- Update PO item quantity_received
    UPDATE purchase_order_items
    SET quantity_received = v_total_received
    WHERE id = v_po_item_id;
    
    -- Insert into po_receipt_history (SAP EKBE)
    IF TG_OP = 'INSERT' AND v_grn_status IN ('passed', 'approved', 'conditional') THEN
        INSERT INTO po_receipt_history (
            purchase_order_id,
            po_item_id,
            grn_id,
            grn_item_id,
            transaction_type,
            quantity,
            amount_local,
            created_at
        ) VALUES (
            v_po_id,
            v_po_item_id,
            NEW.grn_inspection_id,
            NEW.id,
            'GRN',
            NEW.received_quantity,
            COALESCE(NEW.received_quantity * (SELECT unit_price FROM purchase_order_items WHERE id = v_po_item_id), 0),
            NOW()
        )
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Trigger PO header update
    IF v_po_id IS NOT NULL THEN
        PERFORM update_po_receiving_status_v2(v_po_id);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grn_item_po_receipt
    AFTER INSERT OR UPDATE OF received_quantity OR DELETE ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trg_grn_item_update_po_receipt();

-- ============================================================================
-- PART 5: FUNCTION - UPDATE PO RECEIVING STATUS (SAP EKKO Logic)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_po_receiving_status_v2(p_po_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_total_ordered NUMERIC;
    v_total_received NUMERIC;
    v_new_status TEXT;
BEGIN
    -- Calculate from PO items
    SELECT 
        COALESCE(SUM(quantity), 0),
        COALESCE(SUM(COALESCE(quantity_received, 0)), 0)
    INTO v_total_ordered, v_total_received
    FROM purchase_order_items
    WHERE purchase_order_id = p_po_id;
    
    -- Determine status
    IF v_total_ordered = 0 THEN
        v_new_status := 'not_received';
    ELSIF v_total_received >= v_total_ordered THEN
        v_new_status := 'fully_received';
    ELSIF v_total_received > 0 THEN
        v_new_status := 'partial_received';
    ELSE
        v_new_status := 'not_received';
    END IF;
    
    -- Update PO header
    UPDATE purchase_orders
    SET 
        ordered_quantity = v_total_ordered,
        total_received_quantity = v_total_received,
        remaining_quantity = GREATEST(0, v_total_ordered - v_total_received),
        receiving_status = v_new_status,
        status = CASE 
            WHEN v_new_status = 'fully_received' AND status NOT IN ('closed', 'cancelled') THEN 'fully_received'
            ELSE status
        END,
        updated_at = NOW()
    WHERE id = p_po_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 6: TRIGGER - GRN STATUS CHANGE → UPDATE PO
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_grn_status_change_update_po()
RETURNS TRIGGER AS $$
BEGIN
    -- When GRN approved, recalculate all its items' PO quantities
    IF NEW.status IN ('passed', 'approved', 'conditional') 
       AND (OLD.status IS NULL OR OLD.status NOT IN ('passed', 'approved', 'conditional')) THEN
        
        -- Update all PO items from this GRN's items
        UPDATE purchase_order_items poi
        SET quantity_received = COALESCE((
            SELECT SUM(gii.received_quantity)
            FROM grn_inspection_items gii
            JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            WHERE (gii.po_item_id = poi.id OR (gii.item_id = poi.item_id AND gi.purchase_order_id = poi.purchase_order_id))
              AND gi.status IN ('passed', 'approved', 'conditional')
              AND (gi.deleted = FALSE OR gi.deleted IS NULL)
        ), 0)
        WHERE poi.purchase_order_id = NEW.purchase_order_id;
        
        -- Update PO header
        IF NEW.purchase_order_id IS NOT NULL THEN
            PERFORM update_po_receiving_status_v2(NEW.purchase_order_id);
        END IF;
        
        -- Insert document flow PO → GRN
        PERFORM insert_document_flow(
            'PO',
            NEW.purchase_order_id::TEXT,
            NEW.purchase_order_number,
            'GRN',
            NEW.id::TEXT,
            NEW.grn_number,
            'goods_received'
        );
    END IF;
    
    -- When GRN rejected/cancelled after being approved
    IF NEW.status IN ('rejected', 'cancelled') 
       AND OLD.status IN ('passed', 'approved', 'conditional') THEN
        
        IF NEW.purchase_order_id IS NOT NULL THEN
            -- Recalculate PO item quantities
            UPDATE purchase_order_items poi
            SET quantity_received = COALESCE((
                SELECT SUM(gii.received_quantity)
                FROM grn_inspection_items gii
                JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
                WHERE (gii.po_item_id = poi.id OR (gii.item_id = poi.item_id AND gi.purchase_order_id = poi.purchase_order_id))
                  AND gi.status IN ('passed', 'approved', 'conditional')
                  AND gi.id != NEW.id
                  AND (gi.deleted = FALSE OR gi.deleted IS NULL)
            ), 0)
            WHERE poi.purchase_order_id = NEW.purchase_order_id;
            
            PERFORM update_po_receiving_status_v2(NEW.purchase_order_id);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grn_status_po_update
    AFTER UPDATE OF status ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_grn_status_change_update_po();

-- ============================================================================
-- PART 7: TRIGGER - PR_PO_LINKAGE → UPDATE PR ITEMS (SAP EBAN Logic)
-- NOTE: quantity_remaining is GENERATED COLUMN - only update quantity_ordered
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_pr_po_linkage_update_pr()
RETURNS TRIGGER AS $$
DECLARE
    v_total_ordered NUMERIC;
    v_item_qty NUMERIC;
    v_pr_total_ordered NUMERIC;
    v_pr_total_qty NUMERIC;
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        -- Get PR item quantity
        SELECT quantity INTO v_item_qty
        FROM purchase_request_items
        WHERE id = NEW.pr_item_id;
        
        -- Calculate total ordered for this PR item
        SELECT COALESCE(SUM(converted_quantity), 0) INTO v_total_ordered
        FROM pr_po_linkage
        WHERE pr_item_id = NEW.pr_item_id 
          AND status = 'active';
        
        -- Update PR item (DO NOT update quantity_remaining - it's a generated column!)
        UPDATE purchase_request_items
        SET 
            quantity_ordered = v_total_ordered,
            -- quantity_remaining is auto-calculated: quantity - quantity_ordered
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
        
        -- Update PR header status
        SELECT 
            COALESCE(SUM(COALESCE(quantity_ordered, 0)), 0),
            COALESCE(SUM(quantity), 0)
        INTO v_pr_total_ordered, v_pr_total_qty
        FROM purchase_request_items
        WHERE pr_id = NEW.pr_id 
          AND (deleted = FALSE OR deleted IS NULL);
        
        UPDATE purchase_requests
        SET 
            status = CASE 
                WHEN v_pr_total_qty > 0 AND v_pr_total_ordered >= v_pr_total_qty THEN 'fully_ordered'
                WHEN v_pr_total_ordered > 0 THEN 'partially_ordered'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = NEW.pr_id 
          AND status NOT IN ('closed', 'cancelled', 'rejected');
        
        -- Insert document flow PR → PO
        PERFORM insert_document_flow(
            'PR',
            NEW.pr_id::TEXT,
            NEW.pr_number,
            'PO',
            NEW.po_id::TEXT,
            NEW.po_number,
            'converted_to'
        );
    END IF;
    
    IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND NEW.status = 'cancelled') THEN
        -- Recalculate when cancelled
        DECLARE
            v_pr_item_id UUID := COALESCE(NEW.pr_item_id, OLD.pr_item_id);
            v_pr_id UUID := COALESCE(NEW.pr_id, OLD.pr_id);
        BEGIN
            SELECT COALESCE(SUM(converted_quantity), 0) INTO v_total_ordered
            FROM pr_po_linkage
            WHERE pr_item_id = v_pr_item_id 
              AND status = 'active';
            
            -- Only update quantity_ordered, not quantity_remaining
            UPDATE purchase_request_items
            SET 
                quantity_ordered = v_total_ordered,
                status = CASE 
                    WHEN v_total_ordered >= quantity THEN 'converted_to_po'
                    WHEN v_total_ordered > 0 THEN 'partially_converted'
                    ELSE 'open'
                END
            WHERE id = v_pr_item_id;
        END;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pr_po_linkage_pr_update
    AFTER INSERT OR UPDATE OR DELETE ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION trg_pr_po_linkage_update_pr();

-- ============================================================================
-- PART 8: TRIGGER - PR STATUS HISTORY
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_pr_log_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO pr_status_history (
            pr_id, previous_status, new_status, 
            changed_by, changed_by_name, change_reason, change_date
        ) VALUES (
            NEW.id, OLD.status, NEW.status,
            NEW.updated_by,
            COALESCE((SELECT name FROM users WHERE id = NEW.updated_by), 'System'),
            CASE 
                WHEN NEW.status = 'submitted' THEN 'Submitted for approval'
                WHEN NEW.status = 'approved' THEN 'Approved'
                WHEN NEW.status = 'rejected' THEN COALESCE(NEW.rejection_reason, 'Rejected')
                WHEN NEW.status = 'partially_ordered' THEN 'Partial PO created'
                WHEN NEW.status = 'fully_ordered' THEN 'All items converted to PO'
                WHEN NEW.status = 'closed' THEN 'Closed'
                WHEN NEW.status = 'cancelled' THEN 'Cancelled'
                ELSE 'Status changed'
            END,
            NOW()
        );
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pr_status_history_log
    AFTER UPDATE OF status ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION trg_pr_log_status_history();

-- ============================================================================
-- PART 9: TRIGGER - PURCHASING INVOICE → DOCUMENT FLOW
-- ============================================================================

CREATE OR REPLACE FUNCTION trg_purchasing_invoice_doc_flow()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grn_id IS NOT NULL AND NEW.grn_number IS NOT NULL THEN
        PERFORM insert_document_flow(
            'GRN',
            NEW.grn_id::TEXT,
            NEW.grn_number,
            'INV',
            NEW.id::TEXT,
            COALESCE(NEW.purchasing_number, NEW.invoice_number),
            'invoiced'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_invoice_doc
    AFTER INSERT OR UPDATE OF grn_id, grn_number ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_purchasing_invoice_doc_flow();

-- ============================================================================
-- PART 10: CREATE ENTERPRISE VIEWS
-- ============================================================================

-- View: PO Item Receipts (SAP EKPO + EKBE aggregation)
CREATE OR REPLACE VIEW v_po_item_receipts AS
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    po.po_number,
    poi.item_id,
    poi.item_name,
    poi.item_sku,
    poi.unit,
    poi.unit_price,
    poi.quantity AS ordered_qty,
    COALESCE(poi.quantity_received, 0) AS received_qty,
    GREATEST(0, poi.quantity - COALESCE(poi.quantity_received, 0)) AS remaining_qty,
    CASE 
        WHEN poi.quantity > 0 THEN ROUND((COALESCE(poi.quantity_received, 0) / poi.quantity * 100), 2)
        ELSE 0 
    END AS received_pct,
    CASE 
        WHEN COALESCE(poi.quantity_received, 0) >= poi.quantity THEN 'fully_received'
        WHEN COALESCE(poi.quantity_received, 0) > 0 THEN 'partial_received'
        ELSE 'not_received'
    END AS item_status,
    poi.total_amount AS ordered_value,
    COALESCE(poi.quantity_received, 0) * poi.unit_price AS received_value
FROM purchase_order_items poi
JOIN purchase_orders po ON po.id = poi.purchase_order_id
WHERE po.deleted = FALSE OR po.deleted IS NULL;

-- View: PO Receipt Summary (SAP EKKO header level)
CREATE OR REPLACE VIEW v_po_receipt_summary AS
SELECT 
    po.id AS po_id,
    po.po_number,
    po.supplier_id,
    po.supplier_name,
    po.status,
    po.order_date,
    po.total_amount,
    po.receiving_status,
    COUNT(poi.id) AS total_items,
    COALESCE(SUM(poi.quantity), 0) AS total_ordered_qty,
    COALESCE(SUM(COALESCE(poi.quantity_received, 0)), 0) AS total_received_qty,
    COALESCE(SUM(GREATEST(0, poi.quantity - COALESCE(poi.quantity_received, 0))), 0) AS total_remaining_qty,
    SUM(CASE WHEN COALESCE(poi.quantity_received, 0) >= poi.quantity THEN 1 ELSE 0 END) AS fully_received_items,
    SUM(CASE WHEN COALESCE(poi.quantity_received, 0) > 0 AND COALESCE(poi.quantity_received, 0) < poi.quantity THEN 1 ELSE 0 END) AS partial_received_items,
    SUM(CASE WHEN COALESCE(poi.quantity_received, 0) = 0 THEN 1 ELSE 0 END) AS not_received_items,
    CASE 
        WHEN SUM(poi.quantity) > 0 THEN ROUND((SUM(COALESCE(poi.quantity_received, 0)) / SUM(poi.quantity) * 100), 2)
        ELSE 0 
    END AS received_pct,
    CASE 
        WHEN COUNT(poi.id) > 0 AND SUM(COALESCE(poi.quantity_received, 0)) >= SUM(poi.quantity) THEN 'fully_received'
        WHEN SUM(COALESCE(poi.quantity_received, 0)) > 0 THEN 'partial_received'
        ELSE 'not_received'
    END AS calculated_status
FROM purchase_orders po
LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
WHERE po.deleted = FALSE OR po.deleted IS NULL
GROUP BY po.id, po.po_number, po.supplier_id, po.supplier_name, po.status, po.order_date, po.total_amount, po.receiving_status;

-- View: PR-PO Summary (SAP EBAN → EKKO tracking)
-- NOTE: Uses COALESCE for quantity_remaining since it's a generated column
CREATE OR REPLACE VIEW v_pr_po_summary AS
SELECT 
    pr.id AS pr_id,
    pr.pr_number,
    pr.requester_name,
    pr.department,
    pr.status,
    pr.priority,
    pr.required_date,
    pr.estimated_total_value,
    COUNT(DISTINCT pri.id) AS total_items,
    COALESCE(SUM(pri.quantity), 0) AS total_qty,
    COALESCE(SUM(COALESCE(pri.quantity_ordered, 0)), 0) AS ordered_qty,
    COALESCE(SUM(pri.quantity - COALESCE(pri.quantity_ordered, 0)), 0) AS remaining_qty,
    COUNT(DISTINCT ppl.po_id) AS linked_po_count,
    STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS linked_po_numbers,
    CASE 
        WHEN SUM(pri.quantity) > 0 THEN ROUND((SUM(COALESCE(pri.quantity_ordered, 0)) / SUM(pri.quantity) * 100), 2)
        ELSE 0 
    END AS ordered_pct,
    CASE 
        WHEN SUM(pri.quantity - COALESCE(pri.quantity_ordered, 0)) <= 0 THEN FALSE
        WHEN pr.status NOT IN ('approved', 'partially_ordered') THEN FALSE
        ELSE TRUE
    END AS can_convert_to_po
FROM purchase_requests pr
LEFT JOIN purchase_request_items pri ON pri.pr_id = pr.id AND (pri.deleted = FALSE OR pri.deleted IS NULL)
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id AND ppl.status = 'active'
WHERE pr.deleted = FALSE OR pr.deleted IS NULL
GROUP BY pr.id, pr.pr_number, pr.requester_name, pr.department, pr.status, pr.priority, pr.required_date, pr.estimated_total_value;

-- View: PR Linked POs
CREATE OR REPLACE VIEW v_pr_linked_pos AS
SELECT 
    ppl.pr_id,
    ppl.pr_number,
    ppl.po_id,
    ppl.po_number,
    po.supplier_name,
    po.status AS po_status,
    po.receiving_status,
    po.total_amount AS po_total,
    po.order_date AS po_date,
    SUM(ppl.converted_quantity) AS converted_qty,
    COUNT(DISTINCT ppl.pr_item_id) AS item_count
FROM pr_po_linkage ppl
JOIN purchase_orders po ON po.id = ppl.po_id
WHERE ppl.status = 'active'
GROUP BY ppl.pr_id, ppl.pr_number, ppl.po_id, ppl.po_number, 
         po.supplier_name, po.status, po.receiving_status, po.total_amount, po.order_date;

-- View: Document Flow Timeline
CREATE OR REPLACE VIEW v_document_flow_timeline AS
SELECT 
    df.id,
    df.source_type,
    df.source_id,
    df.source_number,
    df.target_type,
    df.target_id,
    df.target_number,
    df.flow_type,
    df.created_at,
    -- Join to get source details
    CASE df.source_type
        WHEN 'PR' THEN (SELECT status FROM purchase_requests WHERE id::TEXT = df.source_id OR pr_number = df.source_number LIMIT 1)
        WHEN 'PO' THEN (SELECT status FROM purchase_orders WHERE id::TEXT = df.source_id OR po_number = df.source_number LIMIT 1)
        WHEN 'GRN' THEN (SELECT status FROM grn_inspections WHERE id::TEXT = df.source_id OR grn_number = df.source_number LIMIT 1)
        WHEN 'INV' THEN (SELECT status FROM purchasing_invoices WHERE id::TEXT = df.source_id LIMIT 1)
    END AS source_status,
    -- Join to get target details
    CASE df.target_type
        WHEN 'PR' THEN (SELECT status FROM purchase_requests WHERE id::TEXT = df.target_id OR pr_number = df.target_number LIMIT 1)
        WHEN 'PO' THEN (SELECT status FROM purchase_orders WHERE id::TEXT = df.target_id OR po_number = df.target_number LIMIT 1)
        WHEN 'GRN' THEN (SELECT status FROM grn_inspections WHERE id::TEXT = df.target_id OR grn_number = df.target_number LIMIT 1)
        WHEN 'INV' THEN (SELECT status FROM purchasing_invoices WHERE id::TEXT = df.target_id LIMIT 1)
    END AS target_status
FROM document_flow df
ORDER BY df.created_at DESC;

-- ============================================================================
-- PART 11: RPC FUNCTIONS FOR FRONTEND
-- ============================================================================

-- Get PR linked POs
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
) AS $$
BEGIN
    RETURN QUERY
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
END;
$$ LANGUAGE plpgsql;

-- Get PR status history
CREATE OR REPLACE FUNCTION get_pr_status_history(p_pr_id UUID)
RETURNS TABLE (
    history_id UUID, 
    previous_status TEXT, 
    new_status TEXT,
    changed_by_name TEXT, 
    change_reason TEXT, 
    change_date TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        psh.id,
        psh.previous_status,
        psh.new_status,
        psh.changed_by_name,
        psh.change_reason,
        psh.change_date
    FROM pr_status_history psh
    WHERE psh.pr_id = p_pr_id
    ORDER BY psh.change_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Get document flow for any document
CREATE OR REPLACE FUNCTION get_document_flow(p_doc_type TEXT, p_doc_number TEXT)
RETURNS TABLE (
    flow_id UUID, 
    source_type TEXT, 
    source_number TEXT,
    target_type TEXT, 
    target_number TEXT,
    flow_type TEXT, 
    direction TEXT, 
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT df.id, df.source_type, df.source_number, df.target_type, df.target_number, df.flow_type, 'downstream'::TEXT, df.created_at
    FROM document_flow df
    WHERE df.source_type = p_doc_type AND df.source_number = p_doc_number
    UNION ALL
    SELECT df.id, df.source_type, df.source_number, df.target_type, df.target_number, df.flow_type, 'upstream'::TEXT, df.created_at
    FROM document_flow df
    WHERE df.target_type = p_doc_type AND df.target_number = p_doc_number
    ORDER BY created_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 12: BACKFILL PR_PO_LINKAGE FROM PURCHASE_REQUEST_ITEMS
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
    v_pri RECORD;
    v_pr_number TEXT;
    v_po_number TEXT;
BEGIN
    RAISE NOTICE '>>> Backfilling pr_po_linkage from purchase_request_items...';
    
    FOR v_pri IN 
        SELECT pri.*, pr.pr_number
        FROM purchase_request_items pri
        JOIN purchase_requests pr ON pr.id = pri.pr_id
        WHERE pri.po_id IS NOT NULL
          AND (pri.deleted = FALSE OR pri.deleted IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM pr_po_linkage ppl
              WHERE ppl.pr_item_id = pri.id AND ppl.po_id = pri.po_id
          )
    LOOP
        -- Get PO number
        SELECT po_number INTO v_po_number FROM purchase_orders WHERE id = v_pri.po_id;
        
        INSERT INTO pr_po_linkage (
            pr_id, pr_number, pr_item_id, pr_item_number,
            po_id, po_number,
            pr_quantity, converted_quantity, remaining_quantity,
            unit, pr_estimated_price,
            conversion_type, status, converted_at
        ) VALUES (
            v_pri.pr_id, v_pri.pr_number, v_pri.id, v_pri.item_number,
            v_pri.po_id, COALESCE(v_pri.po_number, v_po_number),
            v_pri.quantity, v_pri.quantity, 0,
            COALESCE(v_pri.unit, 'EA'), v_pri.estimated_price,
            'full', 'active', COALESCE(v_pri.conversion_date, NOW())
        )
        ON CONFLICT DO NOTHING;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Created % pr_po_linkage records', v_count;
END $$;

-- ============================================================================
-- PART 13: BACKFILL DOCUMENT_FLOW
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Backfilling document_flow...';
    
    -- PR → PO from pr_po_linkage
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 'PR', ppl.pr_id::TEXT, ppl.pr_number, 'PO', ppl.po_id::TEXT, ppl.po_number, 'converted_to', COALESCE(ppl.converted_at, NOW())
    FROM pr_po_linkage ppl
    WHERE ppl.status = 'active'
      AND NOT EXISTS (
          SELECT 1 FROM document_flow df 
          WHERE df.source_type = 'PR' AND df.source_number = ppl.pr_number 
            AND df.target_type = 'PO' AND df.target_number = ppl.po_number
      )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % PR→PO document_flow records', v_count;
    
    -- PO → GRN from grn_inspections
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 'PO', gi.purchase_order_id::TEXT, gi.purchase_order_number, 'GRN', gi.id::TEXT, gi.grn_number, 'goods_received', COALESCE(gi.grn_date, NOW())
    FROM grn_inspections gi
    WHERE gi.purchase_order_id IS NOT NULL AND gi.purchase_order_number IS NOT NULL AND gi.grn_number IS NOT NULL
      AND (gi.deleted = FALSE OR gi.deleted IS NULL)
      AND NOT EXISTS (
          SELECT 1 FROM document_flow df 
          WHERE df.source_type = 'PO' AND df.source_number = gi.purchase_order_number 
            AND df.target_type = 'GRN' AND df.target_number = gi.grn_number
      )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % PO→GRN document_flow records', v_count;
    
    -- GRN → Invoice from purchasing_invoices
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 'GRN', pi.grn_id::TEXT, pi.grn_number, 'INV', pi.id::TEXT, COALESCE(pi.purchasing_number, pi.invoice_number), 'invoiced', pi.created_at
    FROM purchasing_invoices pi
    WHERE pi.grn_id IS NOT NULL AND pi.grn_number IS NOT NULL
      AND (pi.deleted = FALSE OR pi.deleted IS NULL)
      AND NOT EXISTS (
          SELECT 1 FROM document_flow df 
          WHERE df.source_type = 'GRN' AND df.source_number = pi.grn_number 
            AND df.target_type = 'INV'
      )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % GRN→INV document_flow records', v_count;
END $$;

-- ============================================================================
-- PART 14: BACKFILL PO_RECEIPT_HISTORY FROM GRN DATA
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Backfilling po_receipt_history...';
    
    INSERT INTO po_receipt_history (purchase_order_id, po_item_id, grn_id, grn_item_id, transaction_type, quantity, amount_local, created_at)
    SELECT 
        gi.purchase_order_id,
        COALESCE(gii.po_item_id, (
            SELECT poi.id FROM purchase_order_items poi 
            WHERE poi.purchase_order_id = gi.purchase_order_id AND poi.item_id = gii.item_id 
            LIMIT 1
        )),
        gi.id,
        gii.id,
        'GRN',
        gii.received_quantity,
        gii.received_quantity * COALESCE((
            SELECT poi.unit_price FROM purchase_order_items poi 
            WHERE poi.purchase_order_id = gi.purchase_order_id AND poi.item_id = gii.item_id 
            LIMIT 1
        ), 0),
        gi.grn_date
    FROM grn_inspection_items gii
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id IS NOT NULL
      AND gi.status IN ('passed', 'approved', 'conditional')
      AND (gi.deleted = FALSE OR gi.deleted IS NULL)
      AND NOT EXISTS (
          SELECT 1 FROM po_receipt_history prh 
          WHERE prh.grn_item_id = gii.id
      )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % po_receipt_history records', v_count;
END $$;

-- ============================================================================
-- PART 15: RECALCULATE ALL PO ITEM QUANTITIES
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Recalculating all PO item received quantities...';
    
    UPDATE purchase_order_items poi
    SET quantity_received = COALESCE((
        SELECT SUM(gii.received_quantity)
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE (gii.po_item_id = poi.id OR (gii.item_id = poi.item_id AND gi.purchase_order_id = poi.purchase_order_id))
          AND gi.status IN ('passed', 'approved', 'conditional')
          AND (gi.deleted = FALSE OR gi.deleted IS NULL)
    ), 0);
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Updated % PO item received quantities', v_count;
END $$;

-- ============================================================================
-- PART 16: RECALCULATE ALL PO HEADERS
-- ============================================================================

DO $$
DECLARE
    v_po RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Recalculating all PO header totals...';
    
    FOR v_po IN SELECT id FROM purchase_orders WHERE deleted = FALSE OR deleted IS NULL
    LOOP
        PERFORM update_po_receiving_status_v2(v_po.id);
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Updated % PO headers', v_count;
END $$;

-- ============================================================================
-- PART 17: RECALCULATE ALL PR ITEM QUANTITIES
-- NOTE: Only update quantity_ordered, NOT quantity_remaining (generated column)
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Recalculating all PR item ordered quantities...';
    
    -- Only update quantity_ordered - quantity_remaining will auto-calculate
    UPDATE purchase_request_items pri
    SET 
        quantity_ordered = COALESCE((
            SELECT SUM(converted_quantity) 
            FROM pr_po_linkage ppl 
            WHERE ppl.pr_item_id = pri.id AND ppl.status = 'active'
        ), CASE WHEN pri.po_id IS NOT NULL THEN pri.quantity ELSE 0 END),
        status = CASE 
            WHEN COALESCE((SELECT SUM(converted_quantity) FROM pr_po_linkage ppl WHERE ppl.pr_item_id = pri.id AND ppl.status = 'active'), 
                          CASE WHEN pri.po_id IS NOT NULL THEN pri.quantity ELSE 0 END) >= pri.quantity 
                THEN 'converted_to_po'
            WHEN COALESCE((SELECT SUM(converted_quantity) FROM pr_po_linkage ppl WHERE ppl.pr_item_id = pri.id AND ppl.status = 'active'), 
                          CASE WHEN pri.po_id IS NOT NULL THEN pri.quantity ELSE 0 END) > 0 
                THEN 'partially_converted'
            ELSE pri.status
        END
    WHERE deleted = FALSE OR deleted IS NULL;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Updated % PR items', v_count;
END $$;

-- ============================================================================
-- PART 18: RECALCULATE ALL PR HEADERS
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Recalculating all PR header status...';
    
    UPDATE purchase_requests pr
    SET status = CASE 
        WHEN (SELECT COALESCE(SUM(quantity), 0) FROM purchase_request_items WHERE pr_id = pr.id AND (deleted = FALSE OR deleted IS NULL)) > 0
             AND (SELECT COALESCE(SUM(COALESCE(quantity_ordered, 0)), 0) FROM purchase_request_items WHERE pr_id = pr.id AND (deleted = FALSE OR deleted IS NULL))
                 >= (SELECT COALESCE(SUM(quantity), 0) FROM purchase_request_items WHERE pr_id = pr.id AND (deleted = FALSE OR deleted IS NULL))
            THEN 'fully_ordered'
        WHEN (SELECT COALESCE(SUM(COALESCE(quantity_ordered, 0)), 0) FROM purchase_request_items WHERE pr_id = pr.id AND (deleted = FALSE OR deleted IS NULL)) > 0
            THEN 'partially_ordered'
        ELSE pr.status
    END
    WHERE (deleted = FALSE OR deleted IS NULL)
      AND status NOT IN ('draft', 'rejected', 'cancelled', 'closed');
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Updated % PR headers', v_count;
END $$;

-- ============================================================================
-- PART 19: CREATE STATUS HISTORY FOR PRs WITHOUT HISTORY
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Creating status history for PRs without history...';
    
    INSERT INTO pr_status_history (pr_id, previous_status, new_status, changed_by_name, change_reason, change_date)
    SELECT pr.id, NULL, 'draft', pr.requester_name, 'PR created', pr.created_at
    FROM purchase_requests pr
    WHERE NOT EXISTS (SELECT 1 FROM pr_status_history psh WHERE psh.pr_id = pr.id);
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % initial status history records', v_count;
END $$;

-- ============================================================================
-- PART 20: GRANT PERMISSIONS
-- ============================================================================

GRANT SELECT ON v_po_item_receipts TO authenticated, anon;
GRANT SELECT ON v_po_receipt_summary TO authenticated, anon;
GRANT SELECT ON v_pr_po_summary TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT SELECT ON v_document_flow_timeline TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_status_history TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_document_flow TO authenticated, anon;
GRANT EXECUTE ON FUNCTION insert_document_flow TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_po_receiving_status_v2 TO authenticated, anon;

-- ============================================================================
-- PART 21: CREATE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_doc_flow_source ON document_flow(source_type, source_number);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target ON document_flow(target_type, target_number);
CREATE INDEX IF NOT EXISTS idx_ppl_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_ppl_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_ppl_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_psh_pr_id ON pr_status_history(pr_id);
CREATE INDEX IF NOT EXISTS idx_grn_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_gii_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_gii_po_item_id ON grn_inspection_items(po_item_id);
CREATE INDEX IF NOT EXISTS idx_poi_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_poi_item_id ON purchase_order_items(item_id);
CREATE INDEX IF NOT EXISTS idx_prh_po_id ON po_receipt_history(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_prh_grn_id ON po_receipt_history(grn_id);

-- ============================================================================
-- PART 22: FINAL VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_linkage INT; v_doc_flow INT; v_pr_history INT; v_receipt_hist INT;
    v_po_with_received INT; v_pr_ordered INT;
BEGIN
    SELECT COUNT(*) INTO v_linkage FROM pr_po_linkage WHERE status = 'active';
    SELECT COUNT(*) INTO v_doc_flow FROM document_flow;
    SELECT COUNT(*) INTO v_pr_history FROM pr_status_history;
    SELECT COUNT(*) INTO v_receipt_hist FROM po_receipt_history;
    SELECT COUNT(*) INTO v_po_with_received FROM purchase_orders WHERE total_received_quantity > 0;
    SELECT COUNT(*) INTO v_pr_ordered FROM purchase_requests WHERE status IN ('partially_ordered', 'fully_ordered');
    
    RAISE NOTICE '';
    RAISE NOTICE '╔════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  ARCHITECTURE FIX V2 COMPLETE                              ║';
    RAISE NOTICE '╠════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  pr_po_linkage records:      %                         ║', LPAD(v_linkage::TEXT, 5);
    RAISE NOTICE '║  document_flow records:      %                         ║', LPAD(v_doc_flow::TEXT, 5);
    RAISE NOTICE '║  pr_status_history records:  %                         ║', LPAD(v_pr_history::TEXT, 5);
    RAISE NOTICE '║  po_receipt_history records: %                         ║', LPAD(v_receipt_hist::TEXT, 5);
    RAISE NOTICE '║  POs with received qty:      %                         ║', LPAD(v_po_with_received::TEXT, 5);
    RAISE NOTICE '║  PRs with ordered status:    %                         ║', LPAD(v_pr_ordered::TEXT, 5);
    RAISE NOTICE '╠════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  FIX: quantity_remaining is GENERATED COLUMN              ║';
    RAISE NOTICE '║  Only quantity_ordered is updated directly                ║';
    RAISE NOTICE '╠════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  NEXT: Hard refresh browser (Ctrl+Shift+R)               ║';
    RAISE NOTICE '╚════════════════════════════════════════════════════════════╝';
END $$;

-- ============================================================================
-- DEBUG QUERIES - RUN THESE TO VERIFY
-- ============================================================================

-- Check PO receiving status
SELECT po_number, status, receiving_status, ordered_quantity, total_received_quantity, remaining_quantity
FROM purchase_orders WHERE deleted = FALSE ORDER BY created_at DESC LIMIT 5;

-- Check PR with linked POs
SELECT pr_number, status, total_items, ordered_qty, remaining_qty, linked_po_count, linked_po_numbers
FROM v_pr_po_summary WHERE linked_po_count > 0 LIMIT 5;

-- Check document flow
SELECT source_type, source_number, target_type, target_number, flow_type FROM document_flow ORDER BY created_at DESC LIMIT 10;
