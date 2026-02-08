-- ============================================================
-- VALIDATION: Batch sequence + GRN batch display
-- Run after applying FIX_BATCH_SEQUENCE_GRN_DISPLAY.sql
-- ============================================================

-- Test 1 — Sequence increments 001 → 002 → 003 (same GRN + same item)
-- Uses a dummy grn_id/item_id; in real use these come from grn_inspections
DO $$
DECLARE
  v_grn uuid := '00000000-0000-0000-0000-000000000001';
  v_item uuid := '00000000-0000-0000-0000-000000000002';
  v1 text; v2 text; v3 text;
BEGIN
  -- Reset for test
  DELETE FROM grn_batch_sequence WHERE grn_id = v_grn AND item_id = v_item;
  v1 := fn_generate_batch_number_from_grn(v_grn, v_item, '2026-02-05'::date);
  v2 := fn_generate_batch_number_from_grn(v_grn, v_item, '2026-02-10'::date);
  v3 := fn_generate_batch_number_from_grn(v_grn, v_item, '2026-02-20'::date);
  IF v1 LIKE '%-001' AND v2 LIKE '%-002' AND v3 LIKE '%-003' THEN
    RAISE NOTICE 'Test 1 PASS: sequence 001 → 002 → 003';
  ELSE
    RAISE WARNING 'Test 1 FAIL: got %, %, %', v1, v2, v3;
  END IF;
END $$;

-- Test 2 — v_grn_batches_with_batch_number view exists and returns batch_number
SELECT COUNT(*) AS view_row_count FROM v_grn_batches_with_batch_number;

-- Test 3 — Sample batches with batch_number (if any data exists)
SELECT id, grn_id, item_id, batch_number, quantity
FROM v_grn_batches_with_batch_number
LIMIT 5;
