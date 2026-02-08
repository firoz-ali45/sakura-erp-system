-- 02_PR_PO_QUANTITY_TRACKING.sql
-- FIX: PR -> PO Quantity Tracking

-- Drop view first to avoid "cannot drop columns from view" error
DROP VIEW IF EXISTS v_pr_po_summary CASCADE;

CREATE OR REPLACE VIEW v_pr_po_summary AS
SELECT 
    pr_id,
    pr_item_id,
    COUNT(DISTINCT po_id) as linked_po_count,
    SUM(converted_quantity) as total_ordered_qty,
    MAX(pr_quantity) as pr_qty,
    (MAX(pr_quantity) - SUM(converted_quantity)) as remaining_qty
FROM pr_po_linkage
GROUP BY pr_id, pr_item_id;
