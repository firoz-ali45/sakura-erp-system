-- 04_ITEM_FLOW_FUNCTION.sql
-- Function to get timeline of a specific PR ITEM
CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_item_id UUID) RETURNS JSON AS $$
DECLARE v_result JSONB := '[]'::jsonb;
BEGIN -- 1. PR Info
SELECT v_result || jsonb_build_object(
        'doc',
        'PR',
        'qty',
        quantity,
        'date',
        created_at,
        'status',
        'Created'
    ) INTO v_result
FROM purchase_request_items
WHERE id = p_pr_item_id;
-- 2. PO Info (via Linkage)
SELECT v_result || jsonb_agg(
        jsonb_build_object(
            'doc',
            'PO',
            'qty',
            l.converted_quantity,
            'number',
            l.po_number,
            'status',
            'Ordered'
        )
    ) INTO v_result
FROM pr_po_linkage l
WHERE l.pr_item_id = p_pr_item_id
    AND l.status = 'active'
GROUP BY l.pr_item_id;
-- 3. GRN Info (Recursive via PO Item match)
-- Complex: Need to find GRN items linked to the PO items that came from this PR item
SELECT v_result || jsonb_agg(
        jsonb_build_object(
            'doc',
            'GRN',
            'qty',
            gii.received_quantity,
            'number',
            gi.grn_number,
            'status',
            gi.status
        )
    ) INTO v_result
FROM pr_po_linkage l
    JOIN purchase_order_items poi ON poi.purchase_order_id = l.po_id
    AND poi.item_id = (
        SELECT item_id
        FROM purchase_request_items
        WHERE id = p_pr_item_id
    )
    JOIN grn_inspection_items gii ON gii.po_item_id = poi.id
    JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
WHERE l.pr_item_id = p_pr_item_id
GROUP BY l.pr_item_id;
RETURN v_result::JSON;
END;
$$ LANGUAGE plpgsql;