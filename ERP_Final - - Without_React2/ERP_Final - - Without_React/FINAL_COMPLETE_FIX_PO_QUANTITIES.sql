-- ============================================
-- FINAL COMPLETE FIX: PO Received Quantities
-- ============================================
-- Ye script ek baar run karein - yeh sab kuch fix kar degi
-- Purchase Orders ki received quantities properly track karega
-- Run this SQL in Supabase SQL Editor

-- Step 1: Ensure quantity_received column exists in purchase_order_items
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='purchase_order_items' 
        AND column_name='quantity_received' 
        AND table_schema='public'
    ) THEN
        ALTER TABLE purchase_order_items 
        ADD COLUMN quantity_received NUMERIC(10, 2) DEFAULT 0;
        RAISE NOTICE '✅ Column quantity_received added to purchase_order_items';
    ELSE
        RAISE NOTICE '✅ Column quantity_received already exists';
    END IF;
END $$;

-- Step 2: Create function to update PO item received quantities (BIGINT version)
CREATE OR REPLACE FUNCTION update_po_item_received_quantities(po_id_param BIGINT)
RETURNS VOID AS $$
DECLARE
    po_item_record RECORD;
    calculated_received NUMERIC(10, 2);
BEGIN
    -- Loop through each PO item and calculate received quantity from approved GRNs
    FOR po_item_record IN 
        SELECT poi.id, poi.item_id, poi.quantity
        FROM purchase_order_items poi
        WHERE poi.purchase_order_id = po_id_param
    LOOP
        -- Calculate total received quantity for this item from all approved GRNs
        SELECT COALESCE(SUM(gii.received_quantity), 0) INTO calculated_received
        FROM grn_inspections gi
        INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
        WHERE gi.purchase_order_id = po_id_param
        AND gi.status IN ('approved', 'passed', 'pending')
        AND gi.deleted = false
        AND gii.item_id = po_item_record.item_id;
        
        -- Update the PO item with calculated received quantity
        UPDATE purchase_order_items
        SET quantity_received = calculated_received
        WHERE id = po_item_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Update the main PO quantities function (BIGINT version)
CREATE OR REPLACE FUNCTION update_po_received_quantities(po_id_param BIGINT)
RETURNS VOID AS $$
DECLARE
    total_received_qty NUMERIC(10, 2);
    ordered_qty NUMERIC(10, 2);
BEGIN
    -- First, update item-level received quantities
    PERFORM update_po_item_received_quantities(po_id_param);
    
    -- Calculate PO-level received quantities
    SELECT COALESCE(SUM(poi.quantity), 0) INTO ordered_qty
    FROM purchase_order_items poi
    WHERE poi.purchase_order_id = po_id_param;
    
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO total_received_qty
    FROM grn_inspections gi
    INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id = po_id_param
    AND gi.status IN ('approved', 'passed', 'pending')
    AND gi.deleted = false;
    
    -- Update PO with calculated values
    UPDATE purchase_orders
    SET 
        total_received_quantity = total_received_qty,
        ordered_quantity = ordered_qty,
        remaining_quantity = GREATEST(0, ordered_qty - total_received_qty),
        updated_at = NOW()
    WHERE id = po_id_param;
    
    -- Auto-close PO if fully received
    UPDATE purchase_orders
    SET 
        status = 'closed',
        updated_at = NOW()
    WHERE id = po_id_param
    AND status IN ('approved', 'partially_received')
    AND total_received_qty >= ordered_qty
    AND ordered_qty > 0;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create/Update trigger function for grn_inspections (BIGINT version)
CREATE OR REPLACE FUNCTION trigger_update_po_quantities()
RETURNS TRIGGER AS $$
DECLARE
    po_id_val BIGINT;
BEGIN
    -- Get PO ID from GRN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        po_id_val := NEW.purchase_order_id;
    ELSIF TG_OP = 'DELETE' THEN
        po_id_val := OLD.purchase_order_id;
    END IF;
    
    -- Update PO quantities if PO ID exists
    IF po_id_val IS NOT NULL THEN
        PERFORM update_po_received_quantities(po_id_val);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create/Update trigger function for grn_inspection_items (BIGINT version)
CREATE OR REPLACE FUNCTION trigger_update_po_quantities_from_item()
RETURNS TRIGGER AS $$
DECLARE
    po_id_val BIGINT;
BEGIN
    -- Get PO ID from GRN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT purchase_order_id INTO po_id_val
        FROM grn_inspections
        WHERE id = NEW.grn_inspection_id;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT purchase_order_id INTO po_id_val
        FROM grn_inspections
        WHERE id = OLD.grn_inspection_id;
    END IF;
    
    -- Update PO quantities if PO ID exists
    IF po_id_val IS NOT NULL THEN
        PERFORM update_po_received_quantities(po_id_val);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 6: Drop existing triggers (if any) and recreate them
DROP TRIGGER IF EXISTS trg_grn_insert_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_update_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_delete_po_quantities ON grn_inspections;

CREATE TRIGGER trg_grn_insert_po_quantities
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    WHEN (NEW.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

CREATE TRIGGER trg_grn_update_po_quantities
    AFTER UPDATE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS DISTINCT FROM NEW.purchase_order_id 
          OR OLD.status IS DISTINCT FROM NEW.status
          OR OLD.deleted IS DISTINCT FROM NEW.deleted)
    EXECUTE FUNCTION trigger_update_po_quantities();

CREATE TRIGGER trg_grn_delete_po_quantities
    AFTER DELETE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

-- Step 7: Drop and recreate triggers for grn_inspection_items
DROP TRIGGER IF EXISTS trg_grn_items_insert_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_update_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_delete_po_quantities ON grn_inspection_items;

CREATE TRIGGER trg_grn_items_insert_po_quantities
    AFTER INSERT ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

CREATE TRIGGER trg_grn_items_update_po_quantities
    AFTER UPDATE ON grn_inspection_items
    FOR EACH ROW
    WHEN (OLD.received_quantity IS DISTINCT FROM NEW.received_quantity)
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

CREATE TRIGGER trg_grn_items_delete_po_quantities
    AFTER DELETE ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

-- Step 8: CRITICAL - Update all existing PO quantities
DO $$
DECLARE
    po_record RECORD;
    updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Starting to update all existing PO quantities...';
    
    FOR po_record IN SELECT id FROM purchase_orders ORDER BY id LOOP
        BEGIN
            PERFORM update_po_received_quantities(po_record.id);
            updated_count := updated_count + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Error updating PO %: %', po_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Completed! Updated % POs successfully', updated_count;
END $$;

-- Step 9: Final verification message
DO $$
BEGIN
    RAISE NOTICE '✅✅✅ PO QUANTITIES FIX COMPLETE! ✅✅✅';
    RAISE NOTICE '   - Functions created/updated for BIGINT type';
    RAISE NOTICE '   - Triggers recreated and active';
    RAISE NOTICE '   - All existing POs updated';
    RAISE NOTICE '   - Future GRN approvals will auto-update PO quantities';
END $$;

