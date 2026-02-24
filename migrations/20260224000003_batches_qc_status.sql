-- Add qc_status to batches if missing (for QC approval flow)
-- grn_batches is typically a view over batches; updating view updates batches

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'batches') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'batches' AND column_name = 'qc_status') THEN
      ALTER TABLE public.batches ADD COLUMN qc_status text DEFAULT 'pending';
      RAISE NOTICE 'Added qc_status to batches';
    END IF;
  END IF;
  -- grn_batches as base table (not view)
  IF EXISTS (SELECT 1 FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_name = 'grn_batches')
     AND NOT EXISTS (SELECT 1 FROM information_schema.views v WHERE v.table_schema = 'public' AND v.table_name = 'grn_batches') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_batches' AND column_name = 'qc_status') THEN
      ALTER TABLE public.grn_batches ADD COLUMN qc_status text DEFAULT 'pending';
      RAISE NOTICE 'Added qc_status to grn_batches';
    END IF;
  END IF;
END $$;
