-- Fix batches_qc_status_check: accept both UI terms (approved/rejected) and DB terms (passed/failed)
-- Ensures approval works regardless of frontend or constraint history

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'batches') THEN
    ALTER TABLE public.batches DROP CONSTRAINT IF EXISTS batches_qc_status_check;
    ALTER TABLE public.batches ADD CONSTRAINT batches_qc_status_check
      CHECK (qc_status IN ('pending', 'passed', 'failed', 'on_hold', 'expired', 'approved', 'rejected', 'PASS', 'HOLD', 'FAIL', 'REJECT'));
    RAISE NOTICE 'Updated batches_qc_status_check - accepts approved/rejected/passed/failed';
  END IF;
END $$;
