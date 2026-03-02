-- ============================================================
-- User names 100% from database (Supabase)
-- Fix: "User Name ki Jagah Not available" — GRN Received By, Approved By, QC Checked By
-- 1) Backfill grn_inspections.received_by_name, approved_by_name, quality_checked_by_name from users
-- 2) Trigger: keep names in sync on INSERT/UPDATE
-- 3) Helper: fn_user_display_name(uuid) for other modules
-- ============================================================

-- 1) Backfill from public.users (name or email prefix)
UPDATE public.grn_inspections gi
SET received_by_name = (SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1)) FROM public.users u WHERE u.id = gi.received_by LIMIT 1)
WHERE gi.received_by IS NOT NULL;

UPDATE public.grn_inspections gi
SET approved_by_name = (SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1)) FROM public.users u WHERE u.id = gi.approved_by LIMIT 1)
WHERE gi.approved_by IS NOT NULL;

UPDATE public.grn_inspections gi
SET quality_checked_by_name = (SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1)) FROM public.users u WHERE u.id = gi.quality_checked_by LIMIT 1)
WHERE gi.quality_checked_by IS NOT NULL;

-- 2) Trigger: auto-fill *_by_name from users on INSERT/UPDATE
CREATE OR REPLACE FUNCTION public.trg_grn_inspections_sync_user_names()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.received_by IS NOT NULL THEN
    SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1), NEW.received_by::text) INTO NEW.received_by_name FROM public.users u WHERE u.id = NEW.received_by LIMIT 1;
  ELSE
    NEW.received_by_name := NULL;
  END IF;
  IF NEW.approved_by IS NOT NULL THEN
    SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1), NEW.approved_by::text) INTO NEW.approved_by_name FROM public.users u WHERE u.id = NEW.approved_by LIMIT 1;
  ELSE
    NEW.approved_by_name := NULL;
  END IF;
  IF NEW.quality_checked_by IS NOT NULL THEN
    SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1), NEW.quality_checked_by::text) INTO NEW.quality_checked_by_name FROM public.users u WHERE u.id = NEW.quality_checked_by LIMIT 1;
  ELSE
    NEW.quality_checked_by_name := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_grn_inspections_sync_user_names ON public.grn_inspections;
CREATE TRIGGER trg_grn_inspections_sync_user_names
  BEFORE INSERT OR UPDATE OF received_by, approved_by, quality_checked_by
  ON public.grn_inspections
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_grn_inspections_sync_user_names();

-- 3) Helper for other modules (e.g. batches.created_by, purchasing_invoices.created_by)
CREATE OR REPLACE FUNCTION public.fn_user_display_name(p_user_id uuid)
RETURNS text AS $$
  SELECT COALESCE(NULLIF(TRIM(name), ''), SPLIT_PART(email, '@', 1), p_user_id::text)
  FROM public.users WHERE id = p_user_id LIMIT 1;
$$ LANGUAGE sql STABLE;
