-- 03_PO_RECEIPT_VIEWS.sql
-- FIX: PO Receiving Status

-- Drop views first to avoid "cannot drop columns from view" error or dependency issues
DROP VIEW IF EXISTS v_po_receipt_summary CASCADE;
DROP VIEW IF EXISTS v_po_item_receipts_detailed CASCADE;
DROP VIEW IF EXISTS v_po_item_receipts CASCADE;

-- View for PO Item receipts (Base calculation)
CREATE OR REPLACE VIEW v_po_item_receipts AS
SELECT 
    poi.id as po_item_id,
    poi.purchase_order_id,
    poi.item_id,
    poi.quantity as ordered_qty,
    -- Calculate received directly from GRN Items which belong to Passed/Approved GRNs
    COALESCE((
        SELECT SUM(gii.received_quantity)
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE gii.purchase_order_id = poi.purchase_order_id 
        AND gii.item_id = poi.item_id
        AND gi.status IN ('passed', 'approved')
    ), 0) as received_qty
FROM purchase_order_items poi;

-- Add remaining qty and status to the view (Detailed view)
CREATE OR REPLACE VIEW v_po_item_receipts_detailed AS
SELECT
    po_item_id,
    purchase_order_id,
    item_id,
    ordered_qty,
    received_qty,
    (ordered_qty - received_qty) as remaining_qty,
    CASE 
        WHEN received_qty <= 0 THEN 'not_received'
        WHEN received_qty >= ordered_qty THEN 'fully_received'
        ELSE 'partial_received'
    END as status
FROM v_po_item_receipts;

-- View for PO Header receipts
CREATE OR REPLACE VIEW v_po_receipt_summary AS
SELECT 
    po.id as po_id,
    po.po_number,
    COUNT(poi.id) as total_items,
    SUM(poi.quantity) as total_ordered_qty,
    SUM(COALESCE(v.received_qty, 0)) as total_received_qty,
    SUM(COALESCE(v.remaining_qty, 0)) as total_remaining_qty,
    CASE 
        -- If all items are fully received
        WHEN COUNT(poi.id) > 0 AND EVERY(COALESCE(v.status, 'not_received') = 'fully_received') THEN 'fully_received'
        -- If no items received
        WHEN COUNT(poi.id) > 0 AND EVERY(COALESCE(v.status, 'not_received') = 'not_received') THEN 'not_received'
        -- Otherwise partial
        ELSE 'partial_received'
    END as receiving_status,
    CASE 
        WHEN SUM(poi.quantity) > 0 THEN round((SUM(COALESCE(v.received_qty, 0)) / SUM(poi.quantity) * 100), 2)
        ELSE 0
    END as received_percent
FROM purchase_orders po
JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
LEFT JOIN v_po_item_receipts_detailed v ON v.po_item_id = poi.id
GROUP BY po.id, po.po_number;
