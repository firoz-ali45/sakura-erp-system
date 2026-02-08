-- 06_BACKFILL_DOCUMENT_FLOW.sql

-- 1. Backfill PR -> PO
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT 
    'purchase_request', pr_id::text, pr_number,
    'purchase_order', po_id::text, po_number,
    'converted_to_po', converted_at
FROM pr_po_linkage
ON CONFLICT DO NOTHING;

-- 2. Backfill PO -> GRN
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT
    'purchase_order', purchase_order_id::text, purchase_order_number,
    'grn', id::text, grn_number,
    'received', created_at
FROM grn_inspections
WHERE purchase_order_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3. Backfill GRN -> Invoice
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT 
    'grn', grn_id::text, grn_number,
    'purchasing_invoice', id::text, invoice_number,
    'invoiced', created_at
FROM purchasing_invoices
WHERE grn_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 4. Recalculate PO Receipts
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT purchase_order_id FROM purchase_order_items
    LOOP
        -- Update Items
        UPDATE purchase_order_items poi
         SET quantity_received = (
            SELECT COALESCE(SUM(gii.received_quantity), 0)
            FROM grn_inspection_items gii
            JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            WHERE gii.purchase_order_id = r.purchase_order_id 
            AND gii.item_id = poi.item_id
            AND gi.status IN ('passed', 'approved')
        )
        WHERE purchase_order_id = r.purchase_order_id;
        
        -- Update Header
        UPDATE purchase_orders po
        SET 
            total_received_quantity = (SELECT SUM(quantity_received) FROM purchase_order_items WHERE purchase_order_id = po.id),
            receiving_status = (SELECT receiving_status FROM v_po_receipt_summary WHERE po_id = po.id)
        WHERE id = r.purchase_order_id;
    END LOOP;
END $$;
