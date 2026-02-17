-- ============================================================
-- ADVANCED LOGISTICS LAYER - VERIFICATION
-- SAP-level accountability: driver, vehicle, quality, OTP, damage
-- Run after migrations to confirm all objects exist.
-- ============================================================

-- 1) Tables
SELECT 'logistics_handover' AS obj, CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END AS status
FROM information_schema.tables WHERE table_schema='public' AND table_name='logistics_handover'
UNION ALL
SELECT 'transfer_quality_checks', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_quality_checks'
UNION ALL
SELECT 'transfer_damage_reports', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='transfer_damage_reports'
UNION ALL
SELECT 'delivery_otp_logs', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.tables WHERE table_schema='public' AND table_name='delivery_otp_logs';

-- 2) logistics_handover columns (driver, vehicle, GPS-ready)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='logistics_handover'
AND column_name IN ('id','transfer_id','driver_id','vehicle_no','seal_number','handover_time','status','start_lat','start_lng','end_lat','end_lng')
ORDER BY ordinal_position;

-- 3) transfer_quality_checks columns (condition, temperature, damage)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='transfer_quality_checks'
AND column_name IN ('id','transfer_id','condition_status','temperature','damage_flag','notes')
ORDER BY ordinal_position;

-- 4) transfer_damage_reports columns (responsibility: WAREHOUSE | DRIVER | BRANCH)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='transfer_damage_reports'
AND column_name IN ('id','transfer_id','item_id','damaged_qty','responsibility','created_by')
ORDER BY ordinal_position;

-- 5) delivery_otp_logs columns (OTP verification)
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='delivery_otp_logs'
AND column_name IN ('id','transfer_id','otp_code','generated_at','verified_at','verified_by')
ORDER BY ordinal_position;

-- 6) Views (driver from users, no manual names)
SELECT 'v_drivers' AS obj, CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END AS status
FROM information_schema.views WHERE table_schema='public' AND table_name='v_drivers'
UNION ALL
SELECT 'v_logistics_handover_full', CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END
FROM information_schema.views WHERE table_schema='public' AND table_name='v_logistics_handover_full';

-- 7) RPCs (driver handover, quality, OTP, damage)
SELECT routine_name AS fn FROM information_schema.routines
WHERE routine_schema='public' AND routine_type='FUNCTION'
AND routine_name IN (
  'fn_dispatch_to_driver',
  'fn_driver_accept_transfer',
  'fn_driver_arrived',
  'fn_warehouse_mark_in_transit',
  'fn_warehouse_mark_arrived',
  'fn_quality_check_transfer',
  'fn_generate_delivery_otp',
  'fn_verify_delivery_otp',
  'fn_insert_transfer_damage_report'
)
ORDER BY routine_name;

-- 8) stock_transfer_audit (timeline)
SELECT 'stock_transfer_audit' AS obj, CASE WHEN COUNT(*) = 1 THEN 'OK' ELSE 'MISSING' END AS status
FROM information_schema.tables WHERE table_schema='public' AND table_name='stock_transfer_audit';

-- 9) Timeline actions expected
SELECT DISTINCT action FROM stock_transfer_audit
WHERE action IN ('created','picking_started','picked','dispatched','handed_to_driver','driver_accepted','marked_in_transit','arrived','quality_checked','received','completed')
ORDER BY action;

-- 10) Driver must come from users (v_drivers filters role=driver)
SELECT pg_get_viewdef('v_drivers'::regclass, true);
