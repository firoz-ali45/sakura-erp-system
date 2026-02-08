-- 03_ITEM_TRANSACTION_FLOW.sql
-- ITEM TRANSACTION FLOW ENGINE (SAP EKBE STYLE)
-- Aggregates quantities across the chain: PR -> PO -> GRN -> PUR
DROP VIEW IF EXISTS v_item_transaction_flow CASCADE;
CREATE OR REPLACE VIEW v_item_transaction_flow AS
SELECT -- PR ITEM (Base)
    pri.id AS pr_item_id,
    pri.pr_id,
    pr.pr_number,
    pri.item_number AS pr_pos,
    pri.item_name,
    pri.quantity AS pr_qty,
    -- PO Aggregation
    COALESCE(po_data.ordered_qty, 0) AS po_qty,
    -- GRN Aggregation
    COALESCE(grn_data.received_qty, 0) AS grn_qty,
    -- PUR Aggregation (Invoice)
    COALESCE(pur_data.invoiced_qty, 0) AS pur_qty,
    -- Balances
    GREATEST(
        0,
        pri.quantity - COALESCE(po_data.ordered_qty, 0)
    ) AS remaining_pr,
    GREATEST(
        0,
        COALESCE(po_data.ordered_qty, 0) - COALESCE(grn_data.received_qty, 0)
    ) AS remaining_po,
    COALESCE(grn_data.received_qty, 0) - COALESCE(pur_data.invoiced_qty, 0) AS remaining_grn_to_invoice,
    -- String Aggregations for UI
    COALESCE(po_data.po_numbers, '') AS po_numbers,
    COALESCE(grn_data.grn_numbers, '') AS grn_numbers,
    COALESCE(pur_data.pur_numbers, '') AS pur_numbers,
    -- Status Logic
    CASE
        WHEN COALESCE(po_data.ordered_qty, 0) = 0 THEN 'Pending'
        WHEN COALESCE(po_data.ordered_qty, 0) > 0
        AND COALESCE(grn_data.received_qty, 0) = 0 THEN 'Ordered'
        WHEN COALESCE(grn_data.received_qty, 0) > 0
        AND COALESCE(grn_data.received_qty, 0) < COALESCE(po_data.ordered_qty, 0) THEN 'Partial Received'
        WHEN COALESCE(grn_data.received_qty, 0) >= COALESCE(po_data.ordered_qty, 0)
        AND COALESCE(pur_data.invoiced_qty, 0) < COALESCE(grn_data.received_qty, 0) THEN 'Fully Received'
        WHEN COALESCE(pur_data.invoiced_qty, 0) >= COALESCE(grn_data.received_qty, 0)
        AND COALESCE(grn_data.received_qty, 0) > 0 THEN 'Invoiced'
        ELSE 'Processing'
    END AS chain_status
FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id -- 1. PO Data: Linked via pr_po_linkage
    LEFT JOIN (
        SELECT l.pr_item_id,
            SUM(l.converted_quantity) AS ordered_qty,
            STRING_AGG(DISTINCT l.po_number, ', ') AS po_numbers
        FROM pr_po_linkage l
        WHERE l.status = 'active'
        GROUP BY l.pr_item_id
    ) po_data ON po_data.pr_item_id = pri.id -- 2. GRN Data: Linked via PO Items -> GRN Inspection Items
    LEFT JOIN (
        SELECT l.pr_item_id,
            SUM(gii.received_quantity) AS received_qty,
            STRING_AGG(DISTINCT gi.grn_number, ', ') AS grn_numbers
        FROM pr_po_linkage l
            JOIN purchase_order_items poi ON poi.purchase_order_id = l.po_id -- Attempt to match Item ID for accuracy, if available
            -- Assuming pr_po_linkage converts PR Item -> PO Item conceptually (quantity mapping)
            -- AND poi.item_id = (SELECT item_id FROM purchase_request_items WHERE id = l.pr_item_id)
            -- NOTE: Since pr_po_linkage doesn't store po_item_id, we link via PO and Item ID match
            -- Safest is to join PO items that match the PR item's product ID
            JOIN purchase_request_items pri_inner ON pri_inner.id = l.pr_item_id
            JOIN purchase_order_items poi_inner ON poi_inner.purchase_order_id = l.po_id
            AND poi_inner.item_id = pri_inner.item_id
            JOIN grn_inspection_items gii ON gii.po_item_id = poi_inner.id
            JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE l.status = 'active'
            AND gi.deleted = false
        GROUP BY l.pr_item_id
    ) grn_data ON grn_data.pr_item_id = pri.id -- 3. PUR Data: Linked via GRN -> Invoice Items OR PO -> Invoice Items
    LEFT JOIN (
        SELECT l.pr_item_id,
            SUM(inv_item.quantity) AS invoiced_qty,
            -- Use the unified invoice alias (final_inv) for the number
            STRING_AGG(DISTINCT final_inv.purchasing_number, ', ') AS pur_numbers
        FROM pr_po_linkage l
            JOIN purchase_request_items pri_inner ON pri_inner.id = l.pr_item_id
            JOIN purchase_order_items poi_inner ON poi_inner.purchase_order_id = l.po_id
            AND poi_inner.item_id = pri_inner.item_id -- Option A: Invoice from GRN
            LEFT JOIN grn_inspection_items gii ON gii.po_item_id = poi_inner.id
            LEFT JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            LEFT JOIN purchasing_invoices inv_grn ON inv_grn.grn_id = gi.id
            AND inv_grn.deleted = false -- Option B: Invoice from PO directly
            LEFT JOIN purchasing_invoices inv_po ON inv_po.purchase_order_id = l.po_id
            AND inv_po.deleted = false -- Combine to find relevant invoice items
            JOIN purchasing_invoice_items inv_item ON (
                inv_item.purchasing_invoice_id = inv_grn.id
                OR inv_item.purchasing_invoice_id = inv_po.id
            )
            AND inv_item.item_id = pri_inner.item_id -- Ensure item match
            -- Final Join to get valid invoice details
            JOIN purchasing_invoices final_inv ON final_inv.id = inv_item.purchasing_invoice_id
        WHERE l.status = 'active'
        GROUP BY l.pr_item_id
    ) pur_data ON pur_data.pr_item_id = pri.id;