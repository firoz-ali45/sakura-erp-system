-- Fix PO Items Received Quantities Tracking
-- This script adds item-level received quantity tracking for purchase_order_items
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
        RAISE NOTICE 'Column quantity_received added to purchase_order_items';
    ELSE
        RAISE NOTICE 'Column quantity_received already exists in purchase_order_items';
    END IF;
END $$;

-- Step 2: Create function to update PO item received quantities
CREATE OR REPLACE FUNCTION update_po_item_received_quantities(po_id_param UUID)
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
        
        RAISE NOTICE 'Updated PO item %: Received quantity = %', po_item_record.id, calculated_received;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Update the main PO quantities function to also update item-level quantities
CREATE OR REPLACE FUNCTION update_po_received_quantities(po_id_param UUID)
RETURNS VOID AS $$
DECLARE
    calculated_data RECORD;
BEGIN
    -- First, update item-level received quantities
    PERFORM update_po_item_received_quantities(po_id_param);
    
    -- Then calculate PO-level received quantities
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

-- Step 4: Initialize existing PO item quantities
DO $$
DECLARE
    po_record RECORD;
BEGIN
    FOR po_record IN SELECT id FROM purchase_orders LOOP
        PERFORM update_po_item_received_quantities(po_record.id);
    END LOOP;
    RAISE NOTICE '✅ Initialized received quantities for all existing PO items';
END $$;

-- Step 5: Verify the function exists and can be called
DO $$
BEGIN
    RAISE NOTICE '✅ PO item received quantity tracking functions created successfully!';
    RAISE NOTICE '   - Function: update_po_item_received_quantities(po_id)';
    RAISE NOTICE '   - Function: update_po_received_quantities (updated to include item-level tracking)';
    RAISE NOTICE '   - Triggers will automatically call these functions when GRN status changes';
END $$;

-- Step 6: Test query to verify item-level quantities (optional - comment out if not needed)
-- Uncomment the lines below to see current PO item received quantities
/*
SELECT 
    poi.id,
    poi.item_id,
    poi.quantity as ordered_qty,
    poi.quantity_received,
    (poi.quantity - poi.quantity_received) as remaining_qty,
    poi.purchase_order_id
FROM purchase_order_items poi
ORDER BY poi.purchase_order_id, poi.id
LIMIT 20;
*/

