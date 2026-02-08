-- Add PO Received Quantity Tracking Columns
-- ERP-Grade Implementation: Auto-calculate total_received_quantity and remaining_quantity
-- Run this SQL in Supabase SQL Editor

DO $$
BEGIN
    -- Check if purchase_orders table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        
        -- Step 1: Add total_received_quantity column (calculated field)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='purchase_orders' 
            AND column_name='total_received_quantity' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE purchase_orders 
            ADD COLUMN total_received_quantity NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column total_received_quantity added';
        END IF;
        
        -- Step 2: Add remaining_quantity column (calculated field)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='purchase_orders' 
            AND column_name='remaining_quantity' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE purchase_orders 
            ADD COLUMN remaining_quantity NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column remaining_quantity added';
        END IF;
        
        -- Step 3: Add ordered_quantity column if not exists (for PO-level aggregation)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='purchase_orders' 
            AND column_name='ordered_quantity' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE purchase_orders 
            ADD COLUMN ordered_quantity NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column ordered_quantity added';
        END IF;
        
        RAISE NOTICE '✅ PO received quantity columns added successfully!';
    ELSE
        RAISE NOTICE '❌ Table purchase_orders does not exist. Please run CREATE_PURCHASE_ORDERS_TABLES.sql first.';
    END IF;
END $$;

-- Step 4: Create function to calculate PO received quantities
CREATE OR REPLACE FUNCTION calculate_po_received_quantities(po_id_param UUID)
RETURNS TABLE(
    total_received NUMERIC(10, 2),
    ordered_qty NUMERIC(10, 2)
) AS $$
BEGIN
    RETURN QUERY
    WITH po_items_summary AS (
        -- Get ordered quantity from PO items
        SELECT 
            COALESCE(SUM(poi.quantity), 0) as ordered_qty
        FROM purchase_order_items poi
        WHERE poi.purchase_order_id = po_id_param
    ),
    grn_received_summary AS (
        -- Get total received quantity from all approved GRNs
        SELECT 
            COALESCE(SUM(gii.received_quantity), 0) as total_received
        FROM grn_inspections gi
        INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
        WHERE gi.purchase_order_id = po_id_param
        AND gi.status IN ('approved', 'passed', 'pending')
        AND gi.deleted = false
    )
    SELECT 
        COALESCE(grn_received_summary.total_received, 0)::NUMERIC(10, 2) as total_received,
        COALESCE(po_items_summary.ordered_qty, 0)::NUMERIC(10, 2) as ordered_qty
    FROM po_items_summary
    CROSS JOIN grn_received_summary;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create function to update PO received quantities
CREATE OR REPLACE FUNCTION update_po_received_quantities(po_id_param UUID)
RETURNS VOID AS $$
DECLARE
    calculated_data RECORD;
BEGIN
    -- Calculate received quantities
    SELECT * INTO calculated_data
    FROM calculate_po_received_quantities(po_id_param);
    
    -- Update PO with calculated values
    UPDATE purchase_orders
    SET 
        total_received_quantity = calculated_data.total_received,
        ordered_quantity = calculated_data.ordered_qty,
        remaining_quantity = GREATEST(0, calculated_data.ordered_qty - calculated_data.total_received),
        updated_at = NOW()
    WHERE id = po_id_param;
    
    -- Auto-close PO if fully received
    UPDATE purchase_orders
    SET 
        status = 'closed',
        updated_at = NOW()
    WHERE id = po_id_param
    AND status IN ('approved', 'partially_received')
    AND calculated_data.total_received >= calculated_data.ordered_qty
    AND calculated_data.ordered_qty > 0;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create trigger function to auto-update PO quantities when GRN changes
CREATE OR REPLACE FUNCTION trigger_update_po_quantities()
RETURNS TRIGGER AS $$
DECLARE
    po_id_val UUID;
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

-- Step 7: Create triggers on grn_inspections table
-- Note: We need separate triggers for INSERT and UPDATE/DELETE because INSERT cannot reference OLD
DROP TRIGGER IF EXISTS trg_grn_insert_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_update_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_delete_po_quantities ON grn_inspections;

-- Trigger for INSERT (always update PO quantities when new GRN is created)
CREATE TRIGGER trg_grn_insert_po_quantities
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    WHEN (NEW.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

-- Trigger for UPDATE (only when relevant fields change)
CREATE TRIGGER trg_grn_update_po_quantities
    AFTER UPDATE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS DISTINCT FROM NEW.purchase_order_id 
          OR OLD.status IS DISTINCT FROM NEW.status
          OR OLD.deleted IS DISTINCT FROM NEW.deleted)
    EXECUTE FUNCTION trigger_update_po_quantities();

-- Trigger for DELETE (always update PO quantities when GRN is deleted)
CREATE TRIGGER trg_grn_delete_po_quantities
    AFTER DELETE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

-- Step 8: Create trigger function for grn_inspection_items (must be created before trigger)
CREATE OR REPLACE FUNCTION trigger_update_po_quantities_from_item()
RETURNS TRIGGER AS $$
DECLARE
    po_id_val UUID;
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

-- Step 9: Create triggers on grn_inspection_items table
-- Note: We need separate triggers for INSERT and UPDATE/DELETE because INSERT cannot reference OLD
DROP TRIGGER IF EXISTS trg_grn_items_insert_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_update_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_delete_po_quantities ON grn_inspection_items;

-- Trigger for INSERT (always update PO quantities when new GRN item is created)
CREATE TRIGGER trg_grn_items_insert_po_quantities
    AFTER INSERT ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

-- Trigger for UPDATE (only when received_quantity changes)
CREATE TRIGGER trg_grn_items_update_po_quantities
    AFTER UPDATE ON grn_inspection_items
    FOR EACH ROW
    WHEN (OLD.received_quantity IS DISTINCT FROM NEW.received_quantity)
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

-- Trigger for DELETE (always update PO quantities when GRN item is deleted)
CREATE TRIGGER trg_grn_items_delete_po_quantities
    AFTER DELETE ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

-- Step 10: Add CHECK constraint to prevent over-receiving at database level
DO $$
BEGIN
    -- Add constraint to ensure total_received_quantity <= ordered_quantity
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_po_received_not_exceed_ordered'
    ) THEN
        ALTER TABLE purchase_orders
        ADD CONSTRAINT check_po_received_not_exceed_ordered
        CHECK (total_received_quantity <= ordered_quantity OR ordered_quantity = 0);
        RAISE NOTICE 'Constraint check_po_received_not_exceed_ordered added';
    END IF;
END $$;

-- Step 11: Initialize existing PO quantities
DO $$
DECLARE
    po_record RECORD;
BEGIN
    FOR po_record IN SELECT id FROM purchase_orders LOOP
        PERFORM update_po_received_quantities(po_record.id);
    END LOOP;
    RAISE NOTICE '✅ Initialized received quantities for all existing POs';
END $$;

-- Step 12: Verify the changes and print summary
DO $$
BEGIN
    RAISE NOTICE '✅ PO received quantity tracking system installed successfully!';
    RAISE NOTICE '   - Columns added: total_received_quantity, remaining_quantity, ordered_quantity';
    RAISE NOTICE '   - Triggers created: Auto-update on GRN changes';
    RAISE NOTICE '   - Constraints added: Prevent over-receiving';
    RAISE NOTICE '   - Functions created: calculate_po_received_quantities, update_po_received_quantities';
END $$;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'purchase_orders'
AND table_schema = 'public'
AND column_name IN ('total_received_quantity', 'remaining_quantity', 'ordered_quantity')
ORDER BY column_name;
