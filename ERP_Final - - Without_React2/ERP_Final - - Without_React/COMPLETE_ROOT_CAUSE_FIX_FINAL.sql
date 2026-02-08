-- COMPLETE_ROOT_CAUSE_FIX_FINAL.sql
-- FULL ENTERPRISE MIGRATION SCRIPT
-- Fixes PR -> PO -> GRN -> Invoice Architecture (SAP MM Logic)

BEGIN;

-------------------------------------------------------------------------
-- 1. ARCHITECTURE FIXES (Schema)
-------------------------------------------------------------------------

-- 1.1 Fix Document Flow to support Polymorphic IDs (UUID and BigInt via Text)
-- ensure columns are text
ALTER TABLE document_flow ALTER COLUMN source_id TYPE text;
ALTER TABLE document_flow ALTER COLUMN target_id TYPE text;

-- 1.2 Link GRN Items to PO Items (Direct Linkage)
-- Add po_item_id to grn_inspection_items if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspection_items' AND column_name='po_item_id') THEN
        ALTER TABLE grn_inspection_items ADD COLUMN po_item_id uuid REFERENCES purchase_order_items(id);
    END IF;
END $$;

-- 1.3 Create SAP-style Purchase Order Receipt History (EKBE)
CREATE TABLE IF NOT EXISTS po_receipt_history (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    purchase_order_id bigint NOT NULL REFERENCES purchase_orders(id),
    po_item_id uuid NOT NULL REFERENCES purchase_order_items(id),
    grn_id uuid REFERENCES grn_inspections(id),
    grn_item_id uuid REFERENCES grn_inspection_items(id),
    transaction_type text NOT NULL CHECK (transaction_type IN ('GRN', 'RETURN', 'REVERSAL')),
    quantity numeric NOT NULL,
    amount_local numeric DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_po_receipt_history_po ON po_receipt_history(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_po_receipt_history_item ON po_receipt_history(po_item_id);

-------------------------------------------------------------------------
-- 2. VIEWS (Logic Layer)
-------------------------------------------------------------------------

-- 2.1 PR -> PO Summary (Aggregated Quantity Tracking)
DROP VIEW IF EXISTS v_pr_po_summary CASCADE;
CREATE OR REPLACE VIEW v_pr_po_summary AS
SELECT 
    l.pr_id,
    l.pr_item_id,
    COUNT(DISTINCT l.po_id) as linked_po_count,
    SUM(l.converted_quantity) as total_ordered_qty,
    MAX(pri.quantity) as pr_req_qty,
    GREATEST(0, MAX(pri.quantity) - SUM(l.converted_quantity)) as remaining_qty,
    CASE 
        WHEN SUM(l.converted_quantity) >= MAX(pri.quantity) THEN 'fully_ordered'
        WHEN SUM(l.converted_quantity) > 0 THEN 'partially_ordered'
        ELSE 'open'
    END as status
FROM pr_po_linkage l
JOIN purchase_request_items pri ON pri.id = l.pr_item_id
WHERE l.status = 'active'
GROUP BY l.pr_id, l.pr_item_id;

-- 2.2 PO Item Receipts (EKBE Summary)
DROP VIEW IF EXISTS v_po_item_receipts CASCADE;
CREATE OR REPLACE VIEW v_po_item_receipts AS
SELECT 
    poi.id as po_item_id,
    poi.purchase_order_id,
    poi.item_id,
    poi.quantity as ordered_qty,
    COALESCE(SUM(h.quantity), 0) as received_qty,
    GREATEST(0, poi.quantity - COALESCE(SUM(h.quantity), 0)) as remaining_qty,
    CASE 
        WHEN COALESCE(SUM(h.quantity), 0) <= 0 THEN 'not_received'
        WHEN COALESCE(SUM(h.quantity), 0) >= poi.quantity THEN 'fully_received'
        ELSE 'partial_received'
    END as status
FROM purchase_order_items poi
LEFT JOIN po_receipt_history h ON h.po_item_id = poi.id
GROUP BY poi.id, poi.purchase_order_id, poi.item_id, poi.quantity;

-- 2.3 PO Header Receipt Summary
DROP VIEW IF EXISTS v_po_receipt_summary CASCADE;
CREATE OR REPLACE VIEW v_po_receipt_summary AS
SELECT 
    po.id as po_id,
    po.po_number,
    COUNT(poi.id) as total_items,
    SUM(poi.quantity) as total_ordered,
    SUM(COALESCE(v.received_qty, 0)) as total_received,
    CASE 
        WHEN COUNT(poi.id) > 0 AND EVERY(COALESCE(v.status, 'not_received') = 'fully_received') THEN 'fully_received'
        WHEN SUM(COALESCE(v.received_qty, 0)) > 0 THEN 'partial_received'
        ELSE 'not_received'
    END as receiving_status
FROM purchase_orders po
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
LEFT JOIN v_po_item_receipts v ON v.po_item_id = poi.id
GROUP BY po.id, po.po_number;

-- 2.4 Document Flow Timeline View
DROP VIEW IF EXISTS v_document_flow_timeline CASCADE;
CREATE OR REPLACE VIEW v_document_flow_timeline AS
SELECT 
    source_id,
    source_type,
    target_id,
    target_type,
    flow_type,
    created_at
FROM document_flow
ORDER BY created_at ASC;

-------------------------------------------------------------------------
-- 3. TRIGGERS (Automation Layer)
-------------------------------------------------------------------------

-- 3.1 Maintain po_receipt_history on GRN changes
CREATE OR REPLACE FUNCTION fn_update_po_receipt_history() RETURNS TRIGGER AS $$
DECLARE
    v_po_item_id uuid;
BEGIN
    IF NEW.po_item_id IS NULL AND NEW.purchase_order_id IS NOT NULL AND NEW.item_id IS NOT NULL THEN
        SELECT id INTO v_po_item_id FROM purchase_order_items 
        WHERE purchase_order_id = NEW.purchase_order_id AND item_id = NEW.item_id LIMIT 1;
        
        IF v_po_item_id IS NOT NULL THEN
            UPDATE grn_inspection_items SET po_item_id = v_po_item_id WHERE id = NEW.id;
            NEW.po_item_id := v_po_item_id;
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1 FROM grn_inspections 
        WHERE id = NEW.grn_inspection_id 
        AND status IN ('passed', 'approved')
    ) THEN
        DELETE FROM po_receipt_history WHERE grn_item_id = NEW.id;
        
        IF NEW.purchase_order_id IS NOT NULL AND NEW.po_item_id IS NOT NULL THEN
            INSERT INTO po_receipt_history (
                purchase_order_id, po_item_id, grn_id, grn_item_id, 
                transaction_type, quantity, created_by
            ) VALUES (
                NEW.purchase_order_id, NEW.po_item_id, NEW.grn_inspection_id, NEW.id,
                'GRN', NEW.received_quantity, NULL
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_grn_item_history ON grn_inspection_items;
CREATE TRIGGER trg_grn_item_history
AFTER INSERT OR UPDATE ON grn_inspection_items
FOR EACH ROW EXECUTE FUNCTION fn_update_po_receipt_history();


-- 3.2 Update PO Items & Header when History changes
CREATE OR REPLACE FUNCTION fn_sync_po_from_history() RETURNS TRIGGER AS $$
DECLARE
    v_po_id bigint;
    v_po_item_id uuid;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_po_id := OLD.purchase_order_id;
        v_po_item_id := OLD.po_item_id;
    ELSE
        v_po_id := NEW.purchase_order_id;
        v_po_item_id := NEW.po_item_id;
    END IF;

    UPDATE purchase_order_items
    SET quantity_received = (
        SELECT COALESCE(SUM(quantity), 0) 
        FROM po_receipt_history 
        WHERE po_item_id = v_po_item_id
    )
    WHERE id = v_po_item_id;

    UPDATE purchase_orders
    SET 
        total_received_quantity = (
            SELECT COALESCE(SUM(quantity_received), 0) 
            FROM purchase_order_items 
            WHERE purchase_order_id = v_po_id
        ),
        receiving_status = (
            SELECT receiving_status 
            FROM v_po_receipt_summary 
            WHERE po_id = v_po_id
        )
    WHERE id = v_po_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_po_history_sync ON po_receipt_history;
CREATE TRIGGER trg_po_history_sync
AFTER INSERT OR UPDATE OR DELETE ON po_receipt_history
FOR EACH ROW EXECUTE FUNCTION fn_sync_po_from_history();

-- 3.3 PR -> PO Linkage Automation
CREATE OR REPLACE FUNCTION fn_update_pr_status_on_linkage() RETURNS TRIGGER AS $$
DECLARE
    v_pr_id uuid;
BEGIN
    IF (TG_OP = 'DELETE') THEN v_pr_id := OLD.pr_id; ELSE v_pr_id := NEW.pr_id; END IF;

    UPDATE purchase_request_items pri
    SET 
        quantity_ordered = (SELECT COALESCE(SUM(converted_quantity),0) FROM pr_po_linkage WHERE pr_item_id = pri.id AND status='active'),
        quantity_remaining = pri.quantity - (SELECT COALESCE(SUM(converted_quantity),0) FROM pr_po_linkage WHERE pr_item_id = pri.id AND status='active'),
        status = CASE 
            WHEN (SELECT COALESCE(SUM(converted_quantity),0) FROM pr_po_linkage WHERE pr_item_id = pri.id AND status='active') >= pri.quantity THEN 'converted_to_po'
            WHEN (SELECT COALESCE(SUM(converted_quantity),0) FROM pr_po_linkage WHERE pr_item_id = pri.id AND status='active') > 0 THEN 'partially_converted'
            ELSE 'open'
        END
    WHERE pri.pr_id = v_pr_id;

    UPDATE purchase_requests
    SET status = CASE 
        WHEN NOT EXISTS (SELECT 1 FROM purchase_request_items WHERE pr_id = v_pr_id AND status != 'converted_to_po') THEN 'fully_ordered'
        WHEN EXISTS (SELECT 1 FROM purchase_request_items WHERE pr_id = v_pr_id AND quantity_ordered > 0) THEN 'partially_ordered'
        ELSE 'approved'
    END
    WHERE id = v_pr_id AND status NOT IN ('cancelled', 'closed', 'rejected', 'draft');

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pr_po_link_status ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_link_status
AFTER INSERT OR UPDATE OR DELETE ON pr_po_linkage
FOR EACH ROW EXECUTE FUNCTION fn_update_pr_status_on_linkage();

-------------------------------------------------------------------------
-- 4. DOCUMENT FLOW AUTOMATION
-------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_auto_create_document_flow() RETURNS TRIGGER AS $$
BEGIN
    IF (TG_TABLE_NAME = 'pr_po_linkage') THEN
        INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type)
        VALUES ('purchase_request', NEW.pr_id::text, NEW.pr_number, 'purchase_order', NEW.po_id::text, NEW.po_number, 'converted_to_po')
        ON CONFLICT DO NOTHING;
        
    ELSIF (TG_TABLE_NAME = 'grn_inspections') THEN
        IF NEW.purchase_order_id IS NOT NULL THEN
            INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type)
            VALUES ('purchase_order', NEW.purchase_order_id::text, NEW.purchase_order_number, 'grn', NEW.id::text, NEW.grn_number, 'received')
            ON CONFLICT DO NOTHING;
        END IF;

    ELSIF (TG_TABLE_NAME = 'purchasing_invoices') THEN
        IF NEW.grn_id IS NOT NULL THEN
            INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type)
            VALUES ('grn', NEW.grn_id::text, NEW.grn_number, 'purchasing_invoice', NEW.id::text, NEW.invoice_number, 'invoiced')
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_flow_pr_po ON pr_po_linkage;
CREATE TRIGGER trg_flow_pr_po AFTER INSERT ON pr_po_linkage FOR EACH ROW EXECUTE FUNCTION fn_auto_create_document_flow();

DROP TRIGGER IF EXISTS trg_flow_grn ON grn_inspections;
CREATE TRIGGER trg_flow_grn AFTER INSERT ON grn_inspections FOR EACH ROW EXECUTE FUNCTION fn_auto_create_document_flow();

DROP TRIGGER IF EXISTS trg_flow_inv ON purchasing_invoices;
CREATE TRIGGER trg_flow_inv AFTER INSERT ON purchasing_invoices FOR EACH ROW EXECUTE FUNCTION fn_auto_create_document_flow();

-------------------------------------------------------------------------
-- 5. BACKFILL (Data Repair)
-------------------------------------------------------------------------

-- 5.1 Link GRN items to PO items where missing
UPDATE grn_inspection_items gii
SET po_item_id = poi.id
FROM purchase_order_items poi
WHERE gii.purchase_order_id = poi.purchase_order_id
AND gii.item_id = poi.item_id
AND gii.po_item_id IS NULL;

-- 5.2 Populate Receipt History from Existing GRNs
INSERT INTO po_receipt_history (purchase_order_id, po_item_id, grn_id, grn_item_id, transaction_type, quantity)
SELECT 
    gii.purchase_order_id, 
    gii.po_item_id, 
    gii.grn_inspection_id, 
    gii.id, 
    'GRN', 
    gii.received_quantity
FROM grn_inspection_items gii
JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
WHERE gi.status IN ('passed', 'approved')
AND gii.po_item_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 5.3 Force Update PO Statuses
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT purchase_order_id FROM purchase_order_items LOOP
        UPDATE purchase_orders SET updated_at = NOW() WHERE id = r.purchase_order_id;
    END LOOP;
END $$;

-- 5.4 Update PR Statuses
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT pr_id FROM pr_po_linkage LOOP
        UPDATE purchase_requests SET updated_at = NOW() WHERE id = r.pr_id;
    END LOOP;
END $$;

-- 5.5 Backfill Document Flow
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type)
SELECT 'purchase_request', pr_id::text, pr_number, 'purchase_order', po_id::text, po_number, 'converted_to_po' FROM pr_po_linkage ON CONFLICT DO NOTHING;

INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type)
SELECT 'purchase_order', purchase_order_id::text, purchase_order_number, 'grn', id::text, grn_number, 'received' FROM grn_inspections WHERE purchase_order_id IS NOT NULL ON CONFLICT DO NOTHING;

COMMIT;
