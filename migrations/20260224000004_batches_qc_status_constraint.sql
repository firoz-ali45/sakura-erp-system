-- Fix batches_qc_status_check: accept pending, passed, failed, on_hold, expired
-- Frontend maps approved->passed, rejected->failed

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'batches') THEN
    ALTER TABLE public.batches DROP CONSTRAINT IF EXISTS batches_qc_status_check;
    ALTER TABLE public.batches ADD CONSTRAINT batches_qc_status_check
      CHECK (qc_status IN ('pending', 'passed', 'failed', 'on_hold', 'expired'));
    RAISE NOTICE 'Updated batches_qc_status_check constraint';
  END IF;
END $$;
