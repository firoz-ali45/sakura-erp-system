-- 04_PO_RECEIPT_TRIGGERS.sql
-- FIX: Update PO Materialized Columns on GRN

CREATE OR REPLACE FUNCTION fn_update_po_on_grn_change() RETURNS TRIGGER AS $$
DECLARE
    v_po_id bigint;
    v_item_id uuid;
    v_received numeric;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_po_id := OLD.purchase_order_id;
        v_item_id := OLD.item_id;
    ELSE
        v_po_id := NEW.purchase_order_id;
        v_item_id := NEW.item_id;
    END IF;

    IF v_po_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 1. Update PO Item
    -- Calculate total received for this item from all approved GRNs
    UPDATE purchase_order_items
    SET quantity_received = (
        SELECT COALESCE(SUM(gii.received_quantity), 0)
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE gii.purchase_order_id = v_po_id 
        AND gii.item_id = v_item_id
        AND gi.status IN ('passed', 'approved')
    )
    WHERE purchase_order_id = v_po_id AND item_id = v_item_id;

    -- 2. Update PO Header
    UPDATE purchase_orders
    SET 
        total_received_quantity = (
            SELECT SUM(quantity_received) 
            FROM purchase_order_items 
            WHERE purchase_order_id = v_po_id
        ),
        receiving_status = (
             SELECT receiving_status FROM v_po_receipt_summary WHERE po_id = v_po_id
        ),
        updated_at = NOW()
    WHERE id = v_po_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_po_on_grn ON grn_inspection_items;
CREATE TRIGGER trg_update_po_on_grn
AFTER INSERT OR UPDATE OR DELETE ON grn_inspection_items
FOR EACH ROW EXECUTE FUNCTION fn_update_po_on_grn_change();

-- Also trigger on GRN Status change
CREATE OR REPLACE FUNCTION fn_update_po_on_grn_status() RETURNS TRIGGER AS $$
DECLARE
    r RECORD;
BEGIN
    -- Only run if status changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        FOR r IN SELECT purchase_order_id, item_id FROM grn_inspection_items WHERE grn_inspection_id = NEW.id
        LOOP
           -- Update each item affected
           UPDATE purchase_order_items
            SET quantity_received = (
                SELECT COALESCE(SUM(gii.received_quantity), 0)
                FROM grn_inspection_items gii
                JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
                WHERE gii.purchase_order_id = r.purchase_order_id 
                AND gii.item_id = r.item_id
                AND gi.status IN ('passed', 'approved')
            )
            WHERE purchase_order_id = r.purchase_order_id AND item_id = r.item_id;
        END LOOP;
        
        -- Update PO Header (just once per PO)
        IF NEW.purchase_order_id IS NOT NULL THEN
            UPDATE purchase_orders
            SET 
                total_received_quantity = (
                    SELECT SUM(quantity_received) 
                    FROM purchase_order_items 
                    WHERE purchase_order_id = NEW.purchase_order_id
                ),
                receiving_status = (
                     SELECT receiving_status FROM v_po_receipt_summary WHERE po_id = NEW.purchase_order_id
                ),
                updated_at = NOW()
            WHERE id = NEW.purchase_order_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_po_on_grn_status ON grn_inspections;
CREATE TRIGGER trg_update_po_on_grn_status
AFTER UPDATE OF status ON grn_inspections
FOR EACH ROW EXECUTE FUNCTION fn_update_po_on_grn_status();
