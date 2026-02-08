-- ============================================================
-- 24: FIX WRONG pr_po_linkage (document flow showing wrong data)
-- ROOT CAUSE: Backfill in 01_COMPLETE_DOCUMENT_FLOW_FIX links by item_id
--             → same item in different PRs gets linked to wrong PO
-- FIX: Remove pr_po_linkage rows that are NOT from actual conversion
--      (Keep only rows where document_flow confirms PR→PO conversion)
-- Run in Supabase SQL Editor AFTER 23_departments.
-- ============================================================

-- Step 1: If document_flow table exists, delete pr_po_linkage rows that
-- contradict document_flow (i.e. pr_po_linkage says PR X → PO Y but
-- document_flow says a different PR converted to PO Y)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'document_flow') THEN
    -- Delete wrong linkages: pr_po_linkage rows where (pr_id, po_id) is NOT in document_flow
    -- (document_flow has source_type='PR', source_id=pr_id, target_type='PO', target_id=po_id)
    DELETE FROM pr_po_linkage ppl
    WHERE NOT EXISTS (
      SELECT 1 FROM document_flow df
      WHERE df.source_type = 'PR' AND df.target_type = 'PO'
        AND (df.source_id::text = ppl.pr_id::text OR df.source_id = ppl.pr_id::text)
        AND (df.target_id::text = ppl.po_id::text OR df.target_id = ppl.po_id::text)
    );
    RAISE NOTICE 'Removed pr_po_linkage rows not confirmed by document_flow';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Step 1 skipped: %', SQLERRM;
END $$;

-- Step 2: For POs that have multiple pr_ids in pr_po_linkage (wrong from item_id backfill),
-- keep only the one that matches the PO's creation source.
-- If purchase_orders has pr_id or source_pr_id, use that.
DO $$
BEGIN
  -- Delete duplicate wrong linkages: when multiple PRs link to same PO, keep first by created_at
  -- This is a heuristic - ideally conversion populates pr_po_linkage correctly
  WITH ranked AS (
    SELECT id, pr_id, po_id,
      row_number() OVER (PARTITION BY po_id ORDER BY converted_at ASC NULLS LAST, id) AS rn
    FROM pr_po_linkage
  )
  DELETE FROM pr_po_linkage WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
  RAISE NOTICE 'Removed duplicate pr_po_linkage per PO (kept earliest)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Step 2 skipped: %', SQLERRM;
END $$;

-- NOTE: After this migration, PRs without pr_po_linkage will show "No linked PO" 
-- until user converts PR to PO (which creates correct linkage).
-- Do NOT re-run the item_id backfill from 01_COMPLETE_DOCUMENT_FLOW_FIX.
