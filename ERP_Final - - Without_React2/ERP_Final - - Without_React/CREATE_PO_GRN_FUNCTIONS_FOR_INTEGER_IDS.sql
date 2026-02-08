-- Create PO-GRN Functions for INTEGER ID Types
-- Use this if your purchase_orders.id is INTEGER/BIGINT instead of UUID
-- Run this SQL in Supabase SQL Editor

-- Step 1: Check actual ID type
SELECT 
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name IN ('purchase_orders', 'grn_inspections')
  AND column_name IN ('id', 'purchase_order_id')
ORDER BY table_name, column_name;

-- Step 2: Create INTEGER version of calculate function (if needed)
CREATE OR REPLACE FUNCTION calculate_po_received_quantities_int(po_id_param BIGINT)
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

-- Step 3: Create INTEGER version of update function (if needed)
CREATE OR REPLACE FUNCTION update_po_received_quantities_int(po_id_param BIGINT)
RETURNS VOID AS $$
DECLARE
    calculated_data RECORD;
BEGIN
    -- Calculate received quantities
    SELECT * INTO calculated_data
    FROM calculate_po_received_quantities_int(po_id_param);
    
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

-- Step 4: Create trigger function that works with both UUID and INTEGER
CREATE OR REPLACE FUNCTION trigger_update_po_quantities_universal()
RETURNS TRIGGER AS $$
DECLARE
    po_id_val TEXT;
    po_id_type TEXT;
BEGIN
    -- Get PO ID from GRN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        po_id_val := NEW.purchase_order_id::TEXT;
    ELSIF TG_OP = 'DELETE' THEN
        po_id_val := OLD.purchase_order_id::TEXT;
    END IF;
    
    -- Update PO quantities if PO ID exists
    IF po_id_val IS NOT NULL THEN
        -- Check ID type
        SELECT data_type INTO po_id_type
        FROM information_schema.columns
        WHERE table_name = 'purchase_orders'
          AND column_name = 'id'
          AND table_schema = 'public';
        
        -- Call appropriate function based on type
        IF po_id_type = 'uuid' THEN
            PERFORM update_po_received_quantities(po_id_val::UUID);
        ELSIF po_id_type IN ('integer', 'bigint', 'smallint') THEN
            PERFORM update_po_received_quantities_int(po_id_val::BIGINT);
        ELSE
            -- Try UUID first
            BEGIN
                PERFORM update_po_received_quantities(po_id_val::UUID);
            EXCEPTION WHEN OTHERS THEN
                -- Fallback to INTEGER
                BEGIN
                    PERFORM update_po_received_quantities_int(po_id_val::BIGINT);
                EXCEPTION WHEN OTHERS THEN
                    RAISE WARNING 'Could not update PO quantities: %', SQLERRM;
                END;
            END;
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 5: Verify functions created
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%po_received_quantities%'
ORDER BY routine_name;

