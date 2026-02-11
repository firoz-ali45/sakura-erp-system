-- ============================================================
-- SAP TRANSFER ORDER ENGINE - VERIFICATION
-- Run after migrations to confirm all objects exist.
-- ============================================================

-- 1) Tables
SELECT 'transfer_orders' AS obj, CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END AS status
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_orders'
UNION ALL
SELECT 'transfer_order_items', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_order_items'
UNION ALL
SELECT 'transfer_approvals', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_approvals'
UNION ALL
SELECT 'transfer_dispatches', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_dispatches'
UNION ALL
SELECT 'transfer_receipts', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_receipts';

-- 2) Views
SELECT 'v_transfer_orders_full' AS obj, CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END AS status
FROM information_schema.views WHERE table_schema='public' AND table_name='v_transfer_orders_full'
UNION ALL
SELECT 'v_transfer_items_flow', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.views WHERE table_schema='public' AND table_name='v_transfer_items_flow'
UNION ALL
SELECT 'v_transfer_variance', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.views WHERE table_schema='public' AND table_name='v_transfer_variance';

-- 3) Functions
SELECT routine_name AS fn FROM information_schema.routines
WHERE routine_schema='public' AND routine_type='FUNCTION'
AND routine_name IN (
  'fn_dispatch_transfer','fn_receive_transfer','fn_receive_transfer_item',
  'fn_can_dispatch_transfer','fn_can_receive_transfer',
  'fn_submit_transfer','fn_approve_transfer_level','fn_reject_transfer',
  'fn_next_transfer_approval_step'
)
ORDER BY routine_name;

-- 4) Sample flow (requires locations and items)
-- INSERT INTO transfer_orders (from_location_id, to_location_id, requested_by) 
-- SELECT (SELECT id FROM inventory_locations LIMIT 1), (SELECT id FROM inventory_locations OFFSET 1 LIMIT 1), 'user1';
-- INSERT INTO transfer_order_items (transfer_id, item_id, requested_qty)
-- SELECT (SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1), (SELECT id FROM inventory_items LIMIT 1), 10;
-- SELECT fn_submit_transfer((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1));
-- SELECT fn_approve_transfer_level((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1), 1, 'approver1');
-- SELECT fn_approve_transfer_level((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1), 2, 'approver2');
-- SELECT fn_can_dispatch_transfer((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1));
-- SELECT fn_dispatch_transfer((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1), 'dispatcher1');
-- SELECT fn_can_receive_transfer((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1));
-- SELECT fn_receive_transfer((SELECT id FROM transfer_orders ORDER BY created_at DESC LIMIT 1), 'receiver1');
