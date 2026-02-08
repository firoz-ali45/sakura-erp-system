-- 05_PR_STATUS_TRIGGERS.sql
-- Updates PR Item quantities and PR Status when PR is linked to PO

CREATE OR REPLACE FUNCTION public.fn_update_pr_status_on_linkage()
RETURNS TRIGGER AS $$
DECLARE
    v_total_ordered numeric;
    v_total_required numeric;
    v_pr_item_status text;
    v_pr_id uuid;
BEGIN
    -- Determine PR Item ID and PR ID
    IF (TG_OP = 'DELETE') THEN
        v_pr_id := OLD.pr_id;
        
        -- Recalculate ordered quantity for this item
        SELECT COALESCE(SUM(converted_quantity), 0)
        INTO v_total_ordered
        FROM pr_po_linkage
        WHERE pr_item_id = OLD.pr_item_id;
        
        -- Get original required quantity
        SELECT quantity INTO v_total_required
        FROM purchase_request_items
        WHERE id = OLD.pr_item_id;
        
        -- Update PR Item
        UPDATE purchase_request_items
        SET 
            quantity_ordered = v_total_ordered,
            quantity_remaining = v_total_required - v_total_ordered,
            status = CASE 
                WHEN v_total_ordered = 0 THEN 'open'
                WHEN v_total_ordered < v_total_required THEN 'partially_converted'
                ELSE 'converted_to_po'
            END,
            updated_at = NOW()
        WHERE id = OLD.pr_item_id;
        
    ELSE
        -- INSERT or UPDATE
        v_pr_id := NEW.pr_id;

        -- Recalculate ordered quantity for this item
        SELECT COALESCE(SUM(converted_quantity), 0)
        INTO v_total_ordered
        FROM pr_po_linkage
        WHERE pr_item_id = NEW.pr_item_id;
        
        -- Get original required quantity
        SELECT quantity INTO v_total_required
        FROM purchase_request_items
        WHERE id = NEW.pr_item_id;
        
        -- Update PR Item
        UPDATE purchase_request_items
        SET 
            quantity_ordered = v_total_ordered,
            quantity_remaining = v_total_required - v_total_ordered,
            status = CASE 
                WHEN v_total_ordered = 0 THEN 'open'
                WHEN v_total_ordered < v_total_required THEN 'partially_converted'
                ELSE 'converted_to_po'
            END,
            updated_at = NOW()
        WHERE id = NEW.pr_item_id;
        
    END IF;

    -- Now Update the Header Status (Purchase Request)
    -- Check if all items are fully converted
    IF NOT EXISTS (
        SELECT 1 FROM purchase_request_items 
        WHERE pr_id = v_pr_id 
        AND quantity_remaining > 0
        AND status != 'cancelled'
    ) THEN
        UPDATE purchase_requests 
        SET status = 'fully_ordered', updated_at = NOW() 
        WHERE id = v_pr_id;
    ELSE
        -- Check if at least one item is converted
        IF EXISTS (
            SELECT 1 FROM purchase_request_items 
            WHERE pr_id = v_pr_id 
            AND quantity_ordered > 0
        ) THEN
            UPDATE purchase_requests 
            SET status = 'partially_ordered', updated_at = NOW() 
            WHERE id = v_pr_id;
        ELSE
            -- Revert to approved if no items ordered (and was approved)
            -- Note: safer to leave as is or set to approved if it was 'partially_ordered'
            UPDATE purchase_requests 
            SET status = 'approved', updated_at = NOW() 
            WHERE id = v_pr_id AND status IN ('partially_ordered', 'fully_ordered');
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_pr_po_linkage_update_pr ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_update_pr
AFTER INSERT OR UPDATE OR DELETE ON pr_po_linkage
FOR EACH ROW EXECUTE FUNCTION fn_update_pr_status_on_linkage();
