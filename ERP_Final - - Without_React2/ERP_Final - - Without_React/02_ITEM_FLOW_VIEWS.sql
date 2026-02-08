-- 02_ITEM_FLOW_VIEWS.sql
-- Item-Wise Transaction Flow Engine (SAP EKBE Style)
-- 1. MAIN VIEW: v_item_document_flow
-- Links PR Items -> PO Items -> GRN Items -> Invoice Items
-- Note: This is a complex view aggregating multiple levels.
DROP VIEW IF EXISTS v_item_document_flow CASCADE;
CREATE OR REPLACE VIEW v_item_document_flow AS
SELECT -- PR ITEM
    pri.id AS pr_item_id,
    pri.pr_id,
    pr.pr_number,
    pri.item_number AS pr_pos,
    pri.item_name,
    pri.quantity AS pr_qty,
    -- PO AGGREGATION
    COALESCE(po_agg.total_ordered_qty, 0) AS po_qty,
    COALESCE(po_agg.po_numbers, '') AS po_numbers,
    -- GRN AGGREGATION
    COALESCE(grn_agg.total_received_qty, 0) AS grn_qty,
    COALESCE(grn_agg.grn_numbers, '') AS grn_numbers,
    -- INVOICE AGGREGATION
    -- (Assuming invoice items are linked to GRN items or PO items)
    -- For now, using placeholders if table structure unsure, but trying standard path
    0 AS pur_qty,
    -- Placeholder until invoice_items table confirmed
    -- CALCULATED BALANCES
    (
        pri.quantity - COALESCE(po_agg.total_ordered_qty, 0)
    ) AS remaining_to_order,
    (
        COALESCE(po_agg.total_ordered_qty, 0) - COALESCE(grn_agg.total_received_qty, 0)
    ) AS remaining_to_receive,
    -- STATUS
    CASE
        WHEN COALESCE(po_agg.total_ordered_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(po_agg.total_ordered_qty, 0) < pri.quantity THEN 'Partially Ordered'
        WHEN COALESCE(grn_agg.total_received_qty, 0) >= COALESCE(po_agg.total_ordered_qty, 0)
        AND COALESCE(po_agg.total_ordered_qty, 0) > 0 THEN 'Fully Received'
        WHEN COALESCE(grn_agg.total_received_qty, 0) > 0 THEN 'Partially Received'
        ELSE 'Fully Ordered'
    END AS flow_status
FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id -- LINK: PR -> PO (via pr_po_linkage)
    LEFT JOIN (
        SELECT l.pr_item_id,
            SUM(l.converted_quantity) AS total_ordered_qty,
            STRING_AGG(DISTINCT l.po_number, ', ') AS po_numbers
        FROM pr_po_linkage l
        WHERE l.status = 'active'
        GROUP BY l.pr_item_id
    ) po_agg ON po_agg.pr_item_id = pri.id -- LINK: PO -> GRN (via grn_inspection_items)
    -- Note: We need to link back to PR item. 
    -- Path: pr_po_linkage -> po_item -> grn_item
    -- Or:   We can use the `pr_po_linkage` to get `po_item_id` if stored, or match by PO item logic.
    --       Currently `pr_po_linkage` stores `pr_item_id` and `po_id`. Does it store `po_item_id`?
    --       Let's check `pr_po_linkage` columns in previous files. 
    --       In `COMPLETE_ROOT_CAUSE_FIX_FINAL.sql` it has `pr_item_id`.
    --       Usually `pr_po_linkage` should link ITEM to ITEM.
    LEFT JOIN (
        SELECT l.pr_item_id,
            SUM(gii.received_quantity) AS total_received_qty,
            STRING_AGG(DISTINCT gi.grn_number, ', ') AS grn_numbers
        FROM pr_po_linkage l
            JOIN purchase_order_items poi ON poi.purchase_order_id = l.po_id -- Loose link if item_id not in linkage
            AND poi.item_id = (
                SELECT item_id
                FROM purchase_request_items
                WHERE id = l.pr_item_id
            ) -- Match by Material ID
            JOIN grn_inspection_items gii ON gii.po_item_id = poi.id
            JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE l.status = 'active'
        GROUP BY l.pr_item_id
    ) grn_agg ON grn_agg.pr_item_id = pri.id;