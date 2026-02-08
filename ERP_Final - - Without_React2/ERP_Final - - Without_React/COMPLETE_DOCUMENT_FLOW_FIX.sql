-- ============================================================================
-- SAKURA ERP - COMPLETE DOCUMENT FLOW FIX
-- ============================================================================
-- Version: 2.0.0
-- Date: 2026-01-26
-- SINGLE FILE - Run this entire file in Supabase SQL Editor
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- STEP 1: DROP EXISTING FUNCTIONS (to avoid return type conflicts)
-- ============================================================================

-- Drop ALL overloaded versions of functions using DO block
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all versions of update_po_receiving_status
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'update_po_receiving_status'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of insert_document_flow
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'insert_document_flow'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of insert_document_flow_bigint
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'insert_document_flow_bigint'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of get_pr_linked_pos
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'get_pr_linked_pos'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of get_pr_status_history
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'get_pr_status_history'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of get_document_flow
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'get_document_flow'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of update_po_received_quantities
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'update_po_received_quantities'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of recalculate_all_po_receiving
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'recalculate_all_po_receiving'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of get_po_receipt_status
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'get_po_receipt_status'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all versions of get_po_item_receipts
    FOR r IN 
        SELECT oid::regprocedure AS func_sig
        FROM pg_proc 
        WHERE proname = 'get_po_item_receipts'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_sig || ' CASCADE';
    END LOOP;
    
    RAISE NOTICE 'All existing functions dropped successfully';
END $$;

-- ============================================================================
-- STEP 2: DROP EXISTING VIEWS (to avoid column name conflicts)
-- ============================================================================

DROP VIEW IF EXISTS v_po_item_receipts_enhanced CASCADE;
DROP VIEW IF EXISTS v_po_grn_receipts CASCADE;
DROP VIEW IF EXISTS v_po_receipt_summary CASCADE;
DROP VIEW IF EXISTS v_po_item_receipts CASCADE;
DROP VIEW IF EXISTS v_pr_linked_pos CASCADE;
DROP VIEW IF EXISTS v_pr_po_summary CASCADE;
DROP VIEW IF EXISTS v_pr_item_po_summary CASCADE;
DROP VIEW IF EXISTS v_document_flow_chain CASCADE;

-- ============================================================================
-- STEP 3: DROP EXISTING TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS trg_pr_po_linkage_doc_flow ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_grn_doc_flow ON grn_inspections;
DROP TRIGGER IF EXISTS trg_purchasing_doc_flow ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_ap_payment_doc_flow ON ap_payments;
DROP TRIGGER IF EXISTS trg_pr_po_linkage_update_pr ON pr_po_linkage;
DROP TRIGGER IF EXISTS trg_pr_status_log ON purchase_requests;
DROP TRIGGER IF EXISTS trg_grn_item_po_qty ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_status_po_update ON grn_inspections;

-- ============================================================================
-- STEP 4: DROP EXISTING TRIGGER FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS trg_pr_po_linkage_document_flow() CASCADE;
DROP FUNCTION IF EXISTS trg_grn_document_flow() CASCADE;
DROP FUNCTION IF EXISTS trg_purchasing_invoice_document_flow() CASCADE;
DROP FUNCTION IF EXISTS trg_ap_payment_document_flow() CASCADE;
DROP FUNCTION IF EXISTS trg_update_pr_item_on_linkage() CASCADE;
DROP FUNCTION IF EXISTS trg_pr_status_history() CASCADE;
DROP FUNCTION IF EXISTS trg_grn_item_update_po_qty() CASCADE;
DROP FUNCTION IF EXISTS trg_grn_status_update_po() CASCADE;

-- ============================================================================
-- STEP 5: CREATE DOCUMENT FLOW HELPER FUNCTIONS
-- ============================================================================

-- Function: Insert document flow record
CREATE OR REPLACE FUNCTION insert_document_flow(
    p_source_type TEXT,
    p_source_id UUID,
    p_source_number TEXT,
    p_target_type TEXT,
    p_target_id UUID,
    p_target_number TEXT,
    p_flow_type TEXT DEFAULT 'follows'
)
RETURNS UUID AS $$
DECLARE
    v_flow_id UUID;
BEGIN
    -- Check if flow already exists
    SELECT id INTO v_flow_id
    FROM document_flow
    WHERE source_type = p_source_type
      AND source_number = p_source_number
      AND target_type = p_target_type
      AND target_number = p_target_number;
    
    IF v_flow_id IS NOT NULL THEN
        RETURN v_flow_id;
    END IF;
    
    -- Insert new flow record
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
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function: Insert document flow with BIGINT source ID
CREATE OR REPLACE FUNCTION insert_document_flow_bigint(
    p_source_type TEXT,
    p_source_id BIGINT,
    p_source_number TEXT,
    p_target_type TEXT,
    p_target_id UUID,
    p_target_number TEXT,
    p_flow_type TEXT DEFAULT 'follows'
)
RETURNS UUID AS $$
DECLARE
    v_flow_id UUID;
    v_source_uuid UUID;
BEGIN
    -- Convert BIGINT to deterministic UUID
    v_source_uuid := uuid_generate_v5(uuid_ns_oid(), p_source_type || '-' || p_source_id::TEXT);
    
    RETURN insert_document_flow(
        p_source_type, v_source_uuid, p_source_number,
        p_target_type, p_target_id, p_target_number,
        p_flow_type
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 6: CREATE PO RECEIVING STATUS FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION update_po_receiving_status(p_po_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_total_ordered NUMERIC := 0;
    v_total_received NUMERIC := 0;
    v_new_status TEXT;
    v_poi RECORD;
    v_received_qty NUMERIC;
BEGIN
    -- Calculate received quantities for each PO item
    FOR v_poi IN 
        SELECT poi.id, poi.item_id, poi.quantity
        FROM purchase_order_items poi
        WHERE poi.purchase_order_id = p_po_id
    LOOP
        -- Calculate received quantity from approved GRNs
        SELECT COALESCE(SUM(gii.received_quantity), 0) INTO v_received_qty
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE gi.purchase_order_id = p_po_id
          AND gii.item_id = v_poi.item_id
          AND gi.status IN ('passed', 'approved', 'conditional')
          AND (gi.deleted = FALSE OR gi.deleted IS NULL);
        
        -- Update each PO item's received quantity (without updated_at)
        UPDATE purchase_order_items
        SET quantity_received = v_received_qty
        WHERE id = v_poi.id;
    END LOOP;
    
    -- Calculate totals
    SELECT 
        COALESCE(SUM(quantity), 0),
        COALESCE(SUM(COALESCE(quantity_received, 0)), 0)
    INTO v_total_ordered, v_total_received
    FROM purchase_order_items
    WHERE purchase_order_id = p_po_id;
    
    -- Determine receiving status
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
        total_received_quantity = v_total_received,
        remaining_quantity = v_total_ordered - v_total_received,
        ordered_quantity = v_total_ordered,
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
-- STEP 7: CREATE DOCUMENT FLOW TRIGGERS
-- ============================================================================

-- Trigger function: PR → PO document flow
CREATE OR REPLACE FUNCTION trg_pr_po_linkage_document_flow()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM insert_document_flow(
            'PR', NEW.pr_id, NEW.pr_number,
            'PO', uuid_generate_v5(uuid_ns_oid(), 'PO-' || NEW.po_id::TEXT), NEW.po_number,
            'converted_to'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pr_po_linkage_doc_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW EXECUTE FUNCTION trg_pr_po_linkage_document_flow();

-- Trigger function: PO → GRN document flow
CREATE OR REPLACE FUNCTION trg_grn_document_flow()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.purchase_order_id IS NOT NULL AND NEW.purchase_order_number IS NOT NULL THEN
        PERFORM insert_document_flow(
            'PO', uuid_generate_v5(uuid_ns_oid(), 'PO-' || NEW.purchase_order_id::TEXT), NEW.purchase_order_number,
            'GRN', NEW.id, NEW.grn_number,
            'goods_received'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grn_doc_flow
    AFTER INSERT OR UPDATE OF purchase_order_id, purchase_order_number, grn_number ON grn_inspections
    FOR EACH ROW EXECUTE FUNCTION trg_grn_document_flow();

-- Trigger function: GRN → Purchasing Invoice document flow
CREATE OR REPLACE FUNCTION trg_purchasing_invoice_document_flow()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grn_id IS NOT NULL AND NEW.grn_number IS NOT NULL THEN
        PERFORM insert_document_flow(
            'GRN', NEW.grn_id, NEW.grn_number,
            'PURCHASING', NEW.id, COALESCE(NEW.purchasing_number, NEW.invoice_number),
            'invoiced'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_doc_flow
    AFTER INSERT OR UPDATE OF grn_id, grn_number ON purchasing_invoices
    FOR EACH ROW EXECUTE FUNCTION trg_purchasing_invoice_document_flow();

-- ============================================================================
-- STEP 8: CREATE PR QUANTITY TRACKING TRIGGERS
-- ============================================================================

-- Trigger function: Update PR item quantities when linkage created
CREATE OR REPLACE FUNCTION trg_update_pr_item_on_linkage()
RETURNS TRIGGER AS $$
DECLARE
    v_total_ordered NUMERIC;
    v_item_qty NUMERIC;
    v_pr_total_ordered NUMERIC;
    v_pr_total_qty NUMERIC;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Get item quantity
        SELECT quantity INTO v_item_qty
        FROM purchase_request_items
        WHERE id = NEW.pr_item_id;
        
        -- Calculate total ordered for this item
        SELECT COALESCE(SUM(converted_quantity), 0) INTO v_total_ordered
        FROM pr_po_linkage
        WHERE pr_item_id = NEW.pr_item_id AND status = 'active';
        
        -- Update PR item
        UPDATE purchase_request_items
        SET 
            quantity_ordered = v_total_ordered,
            quantity_remaining = COALESCE(v_item_qty, quantity) - v_total_ordered,
            po_id = NEW.po_id,
            po_number = NEW.po_number,
            status = CASE 
                WHEN v_total_ordered >= COALESCE(v_item_qty, quantity) THEN 'converted_to_po'
                WHEN v_total_ordered > 0 THEN 'partially_converted'
                ELSE status
            END,
            is_locked = CASE WHEN v_total_ordered >= COALESCE(v_item_qty, quantity) THEN TRUE ELSE is_locked END,
            updated_at = NOW()
        WHERE id = NEW.pr_item_id;
        
        -- Update PR header status
        SELECT 
            COALESCE(SUM(COALESCE(quantity_ordered, 0)), 0),
            COALESCE(SUM(quantity), 0)
        INTO v_pr_total_ordered, v_pr_total_qty
        FROM purchase_request_items
        WHERE pr_id = NEW.pr_id AND (deleted = FALSE OR deleted IS NULL);
        
        UPDATE purchase_requests
        SET 
            status = CASE 
                WHEN v_pr_total_qty > 0 AND v_pr_total_ordered >= v_pr_total_qty THEN 'fully_ordered'
                WHEN v_pr_total_ordered > 0 THEN 'partially_ordered'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = NEW.pr_id AND status NOT IN ('closed', 'cancelled', 'rejected');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pr_po_linkage_update_pr
    AFTER INSERT OR UPDATE ON pr_po_linkage
    FOR EACH ROW EXECUTE FUNCTION trg_update_pr_item_on_linkage();

-- Trigger function: PR Status History
CREATE OR REPLACE FUNCTION trg_pr_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO pr_status_history (
            pr_id, previous_status, new_status, changed_by, changed_by_name, change_reason, change_date
        ) VALUES (
            NEW.id, OLD.status, NEW.status, NEW.updated_by,
            COALESCE((SELECT name FROM users WHERE id = NEW.updated_by), 'System'),
            CASE 
                WHEN NEW.status = 'submitted' THEN 'Submitted for approval'
                WHEN NEW.status = 'approved' THEN 'Approved'
                WHEN NEW.status = 'rejected' THEN COALESCE(NEW.rejection_reason, 'Rejected')
                WHEN NEW.status = 'partially_ordered' THEN 'Partial quantity converted to PO'
                WHEN NEW.status = 'fully_ordered' THEN 'All quantities converted to PO'
                WHEN NEW.status = 'closed' THEN 'PR closed'
                WHEN NEW.status = 'cancelled' THEN 'PR cancelled'
                ELSE 'Status changed to ' || NEW.status
            END,
            NOW()
        );
    END IF;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pr_status_log
    AFTER UPDATE OF status ON purchase_requests
    FOR EACH ROW EXECUTE FUNCTION trg_pr_status_history();

-- ============================================================================
-- STEP 9: CREATE GRN → PO QUANTITY TRIGGERS
-- ============================================================================

-- Trigger function: Update PO quantities when GRN status changes
CREATE OR REPLACE FUNCTION trg_grn_status_update_po()
RETURNS TRIGGER AS $$
BEGIN
    -- When GRN status changes to approved/passed, update PO quantities
    IF NEW.status IN ('passed', 'approved', 'conditional') 
       AND (OLD.status IS NULL OR OLD.status NOT IN ('passed', 'approved', 'conditional')) THEN
        IF NEW.purchase_order_id IS NOT NULL THEN
            PERFORM update_po_receiving_status(NEW.purchase_order_id);
        END IF;
    END IF;
    
    -- When GRN is rejected/cancelled, also recalculate
    IF NEW.status IN ('rejected', 'cancelled') 
       AND OLD.status IN ('passed', 'approved', 'conditional') THEN
        IF NEW.purchase_order_id IS NOT NULL THEN
            PERFORM update_po_receiving_status(NEW.purchase_order_id);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grn_status_po_update
    AFTER UPDATE OF status ON grn_inspections
    FOR EACH ROW EXECUTE FUNCTION trg_grn_status_update_po();

-- ============================================================================
-- STEP 10: CREATE VIEWS FOR PR-PO TRACKING
-- ============================================================================

-- View: PR Summary with Linked POs
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
    pr.created_at,
    COALESCE(item_summary.total_items, 0) AS total_items,
    COALESCE(item_summary.total_qty, 0) AS total_requested_qty,
    COALESCE(item_summary.ordered_qty, 0) AS total_ordered_qty,
    COALESCE(item_summary.remaining_qty, 0) AS total_remaining_qty,
    COALESCE(po_summary.linked_po_count, 0) AS linked_po_count,
    po_summary.linked_po_numbers,
    CASE 
        WHEN COALESCE(item_summary.total_qty, 0) > 0 THEN 
            ROUND((COALESCE(item_summary.ordered_qty, 0) / item_summary.total_qty * 100), 2)
        ELSE 0 
    END AS order_percentage,
    CASE 
        WHEN COALESCE(item_summary.remaining_qty, 0) <= 0 THEN FALSE
        WHEN pr.status NOT IN ('approved', 'partially_ordered') THEN FALSE
        ELSE TRUE
    END AS can_convert_to_po
FROM purchase_requests pr
LEFT JOIN (
    SELECT pr_id, COUNT(*) AS total_items, SUM(quantity) AS total_qty,
           SUM(COALESCE(quantity_ordered, 0)) AS ordered_qty,
           SUM(COALESCE(quantity_remaining, quantity - COALESCE(quantity_ordered, 0))) AS remaining_qty
    FROM purchase_request_items
    WHERE deleted = FALSE OR deleted IS NULL
    GROUP BY pr_id
) item_summary ON item_summary.pr_id = pr.id
LEFT JOIN (
    SELECT pr_id, COUNT(DISTINCT po_id) AS linked_po_count,
           STRING_AGG(DISTINCT po_number, ', ' ORDER BY po_number) AS linked_po_numbers
    FROM pr_po_linkage WHERE status = 'active'
    GROUP BY pr_id
) po_summary ON po_summary.pr_id = pr.id
WHERE pr.deleted = FALSE OR pr.deleted IS NULL;

-- View: Linked POs for a PR
CREATE OR REPLACE VIEW v_pr_linked_pos AS
SELECT 
    ppl.pr_id, ppl.pr_number, ppl.po_id, ppl.po_number,
    po.supplier_name, po.status AS po_status, po.receiving_status,
    po.total_amount AS po_total, po.order_date AS po_date,
    SUM(ppl.converted_quantity) AS converted_qty,
    COUNT(DISTINCT ppl.pr_item_id) AS item_count
FROM pr_po_linkage ppl
JOIN purchase_orders po ON po.id = ppl.po_id
WHERE ppl.status = 'active'
GROUP BY ppl.pr_id, ppl.pr_number, ppl.po_id, ppl.po_number,
         po.supplier_name, po.status, po.receiving_status, po.total_amount, po.order_date;

-- ============================================================================
-- STEP 11: CREATE VIEWS FOR PO RECEIPT TRACKING
-- ============================================================================

-- View: PO Item Receipts
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
    poi.quantity - COALESCE(poi.quantity_received, 0) AS remaining_qty,
    CASE 
        WHEN poi.quantity > 0 THEN ROUND((COALESCE(poi.quantity_received, 0) / poi.quantity * 100), 2)
        ELSE 0 
    END AS received_percentage,
    CASE 
        WHEN COALESCE(poi.quantity_received, 0) >= poi.quantity THEN 'fully_received'
        WHEN COALESCE(poi.quantity_received, 0) > 0 THEN 'partial_received'
        ELSE 'not_received'
    END AS item_receiving_status,
    poi.total_amount AS ordered_value,
    COALESCE(poi.quantity_received, 0) * poi.unit_price AS received_value
FROM purchase_order_items poi
JOIN purchase_orders po ON po.id = poi.purchase_order_id
WHERE po.deleted = FALSE OR po.deleted IS NULL;

-- View: PO Receipt Summary
CREATE OR REPLACE VIEW v_po_receipt_summary AS
SELECT 
    po.id AS po_id, po.po_number, po.supplier_id, po.supplier_name,
    po.destination, po.status, po.business_date, po.order_date,
    po.expected_date, po.total_amount, po.vat_amount, po.notes, po.created_at,
    po.receiving_status,
    po.total_received_quantity,
    po.remaining_quantity,
    po.ordered_quantity,
    COALESCE(item_summary.total_items, 0) AS total_items,
    COALESCE(item_summary.fully_received_items, 0) AS fully_received_items,
    COALESCE(item_summary.partial_received_items, 0) AS partial_received_items,
    COALESCE(item_summary.not_received_items, 0) AS not_received_items,
    COALESCE(item_summary.total_ordered_qty, 0) AS total_ordered_qty,
    COALESCE(item_summary.total_received_qty, 0) AS total_received_qty,
    COALESCE(item_summary.total_remaining_qty, 0) AS total_remaining_qty,
    CASE 
        WHEN COALESCE(item_summary.total_ordered_qty, 0) > 0 THEN 
            ROUND((COALESCE(item_summary.total_received_qty, 0) / item_summary.total_ordered_qty * 100), 2)
        ELSE 0 
    END AS receiving_percentage,
    CASE 
        WHEN COALESCE(item_summary.total_ordered_qty, 0) = 0 THEN 'not_received'
        WHEN COALESCE(item_summary.total_received_qty, 0) >= COALESCE(item_summary.total_ordered_qty, 0) THEN 'fully_received'
        WHEN COALESCE(item_summary.total_received_qty, 0) > 0 THEN 'partial_received'
        ELSE 'not_received'
    END AS calculated_receiving_status,
    COALESCE(grn_info.grn_count, 0) AS grn_count,
    grn_info.grn_numbers
FROM purchase_orders po
LEFT JOIN (
    SELECT purchase_order_id, COUNT(*) AS total_items,
           SUM(CASE WHEN item_receiving_status = 'fully_received' THEN 1 ELSE 0 END) AS fully_received_items,
           SUM(CASE WHEN item_receiving_status = 'partial_received' THEN 1 ELSE 0 END) AS partial_received_items,
           SUM(CASE WHEN item_receiving_status = 'not_received' THEN 1 ELSE 0 END) AS not_received_items,
           SUM(ordered_qty) AS total_ordered_qty,
           SUM(received_qty) AS total_received_qty,
           SUM(remaining_qty) AS total_remaining_qty
    FROM v_po_item_receipts
    GROUP BY purchase_order_id
) item_summary ON item_summary.purchase_order_id = po.id
LEFT JOIN (
    SELECT purchase_order_id, COUNT(DISTINCT id) AS grn_count,
           STRING_AGG(grn_number, ', ' ORDER BY grn_date DESC) AS grn_numbers
    FROM grn_inspections
    WHERE status IN ('passed', 'approved', 'conditional', 'pending', 'draft')
      AND (deleted = FALSE OR deleted IS NULL)
    GROUP BY purchase_order_id
) grn_info ON grn_info.purchase_order_id = po.id
WHERE po.deleted = FALSE OR po.deleted IS NULL;

-- ============================================================================
-- STEP 12: CREATE HELPER RPC FUNCTIONS
-- ============================================================================

-- Function: Get PR linked POs
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
    WHERE v.pr_id = p_pr_id
    ORDER BY v.po_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Get PR status history
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
        psh.id AS history_id,
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

-- Function: Get document flow for a document
CREATE OR REPLACE FUNCTION get_document_flow(
    p_doc_type TEXT,
    p_doc_id UUID DEFAULT NULL,
    p_doc_number TEXT DEFAULT NULL
)
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
    -- Downstream documents
    SELECT 
        df.id AS flow_id,
        df.source_type,
        df.source_number,
        df.target_type,
        df.target_number,
        df.flow_type,
        'downstream'::TEXT AS direction,
        df.created_at
    FROM document_flow df
    WHERE (df.source_type = p_doc_type AND (df.source_id = p_doc_id OR df.source_number = p_doc_number))
    
    UNION ALL
    
    -- Upstream documents
    SELECT 
        df.id AS flow_id,
        df.source_type,
        df.source_number,
        df.target_type,
        df.target_number,
        df.flow_type,
        'upstream'::TEXT AS direction,
        df.created_at
    FROM document_flow df
    WHERE (df.target_type = p_doc_type AND (df.target_id = p_doc_id OR df.target_number = p_doc_number))
    
    ORDER BY created_at;
END;
$$ LANGUAGE plpgsql;

-- Function: Update PO received quantities (RPC callable)
CREATE OR REPLACE FUNCTION update_po_received_quantities(p_po_id_param TEXT)
RETURNS JSON AS $$
DECLARE
    v_po_id BIGINT;
    v_result JSON;
BEGIN
    v_po_id := p_po_id_param::BIGINT;
    PERFORM update_po_receiving_status(v_po_id);
    
    SELECT json_build_object(
        'success', true, 
        'po_id', po.id, 
        'po_number', po.po_number,
        'receiving_status', po.receiving_status,
        'total_received', po.total_received_quantity,
        'total_ordered', po.ordered_quantity,
        'remaining', po.remaining_quantity
    ) INTO v_result
    FROM purchase_orders po 
    WHERE po.id = v_po_id;
    
    RETURN COALESCE(v_result, json_build_object('success', false, 'error', 'PO not found'));
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 13: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION insert_document_flow TO authenticated, anon;
GRANT EXECUTE ON FUNCTION insert_document_flow_bigint TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_po_receiving_status TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_status_history TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_document_flow TO authenticated, anon;
GRANT EXECUTE ON FUNCTION update_po_received_quantities TO authenticated, anon;

GRANT SELECT ON v_pr_po_summary TO authenticated, anon;
GRANT SELECT ON v_pr_linked_pos TO authenticated, anon;
GRANT SELECT ON v_po_item_receipts TO authenticated, anon;
GRANT SELECT ON v_po_receipt_summary TO authenticated, anon;

-- ============================================================================
-- STEP 14: CREATE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_doc_flow_source_type_num ON document_flow(source_type, source_number);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target_type_num ON document_flow(target_type, target_number);
CREATE INDEX IF NOT EXISTS idx_ppl_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_ppl_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_ppl_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_ppl_status ON pr_po_linkage(status);
CREATE INDEX IF NOT EXISTS idx_psh_pr_id ON pr_status_history(pr_id);
CREATE INDEX IF NOT EXISTS idx_psh_change_date ON pr_status_history(change_date DESC);
CREATE INDEX IF NOT EXISTS idx_grn_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_gii_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_gii_grn_id ON grn_inspection_items(grn_inspection_id);

-- ============================================================================
-- STEP 15: BACKFILL EXISTING DATA
-- ============================================================================

-- Backfill PR → PO document flow from pr_po_linkage
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 
    'PR', 
    ppl.pr_id, 
    ppl.pr_number,
    'PO', 
    uuid_generate_v5(uuid_ns_oid(), 'PO-' || ppl.po_id::TEXT), 
    ppl.po_number,
    'converted_to', 
    COALESCE(ppl.converted_at, NOW())
FROM pr_po_linkage ppl
WHERE ppl.pr_number IS NOT NULL 
  AND ppl.po_number IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PR' 
      AND df.source_number = ppl.pr_number
      AND df.target_type = 'PO' 
      AND df.target_number = ppl.po_number
)
ON CONFLICT DO NOTHING;

-- Backfill PO → GRN document flow from grn_inspections
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 
    'PO', 
    uuid_generate_v5(uuid_ns_oid(), 'PO-' || gi.purchase_order_id::TEXT), 
    gi.purchase_order_number,
    'GRN', 
    gi.id, 
    gi.grn_number, 
    'goods_received', 
    COALESCE(gi.grn_date, NOW())
FROM grn_inspections gi
WHERE gi.purchase_order_id IS NOT NULL 
  AND gi.purchase_order_number IS NOT NULL
  AND gi.grn_number IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'PO' 
      AND df.source_number = gi.purchase_order_number
      AND df.target_type = 'GRN' 
      AND df.target_number = gi.grn_number
)
ON CONFLICT DO NOTHING;

-- Backfill GRN → Purchasing Invoice document flow
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 
    'GRN', 
    pi.grn_id, 
    pi.grn_number,
    'PURCHASING', 
    pi.id, 
    COALESCE(pi.purchasing_number, pi.invoice_number), 
    'invoiced', 
    pi.created_at
FROM purchasing_invoices pi
WHERE pi.grn_id IS NOT NULL 
  AND pi.grn_number IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM document_flow df
    WHERE df.source_type = 'GRN' 
      AND df.source_number = pi.grn_number
      AND df.target_type = 'PURCHASING'
)
ON CONFLICT DO NOTHING;

-- Recalculate all PO receiving quantities
DO $$
DECLARE 
    v_po RECORD;
    v_count INT := 0;
BEGIN
    FOR v_po IN 
        SELECT id FROM purchase_orders 
        WHERE deleted = FALSE OR deleted IS NULL
    LOOP
        PERFORM update_po_receiving_status(v_po.id);
        v_count := v_count + 1;
    END LOOP;
    RAISE NOTICE 'Recalculated receiving status for % POs', v_count;
END $$;

-- ============================================================================
-- STEP 16: VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_df_count INT;
    v_link_count INT;
    v_po_count INT;
    v_pr_count INT;
BEGIN
    SELECT COUNT(*) INTO v_df_count FROM document_flow;
    SELECT COUNT(*) INTO v_link_count FROM pr_po_linkage;
    SELECT COUNT(*) INTO v_po_count FROM purchase_orders WHERE deleted = FALSE OR deleted IS NULL;
    SELECT COUNT(*) INTO v_pr_count FROM purchase_requests WHERE deleted = FALSE OR deleted IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'COMPLETE DOCUMENT FLOW FIX - SUCCESS';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Document Flow Records: %', v_df_count;
    RAISE NOTICE 'PR-PO Linkage Records: %', v_link_count;
    RAISE NOTICE 'Purchase Orders: %', v_po_count;
    RAISE NOTICE 'Purchase Requests: %', v_pr_count;
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Triggers Created:';
    RAISE NOTICE '  - PR -> PO document flow';
    RAISE NOTICE '  - PO -> GRN document flow';
    RAISE NOTICE '  - GRN -> Purchasing document flow';
    RAISE NOTICE '  - PR status history logging';
    RAISE NOTICE '  - PR quantity tracking';
    RAISE NOTICE '  - GRN -> PO quantity updates';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Views Created:';
    RAISE NOTICE '  - v_pr_po_summary';
    RAISE NOTICE '  - v_pr_linked_pos';
    RAISE NOTICE '  - v_po_item_receipts';
    RAISE NOTICE '  - v_po_receipt_summary';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'NEXT: Refresh your browser (Ctrl+Shift+R)';
    RAISE NOTICE '============================================';
END $$;
