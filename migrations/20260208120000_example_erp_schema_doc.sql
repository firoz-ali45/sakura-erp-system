-- Example migration: schema documentation / placeholder.
-- Your real schema is already applied via Supabase; use this as a template for new migrations.
-- Apply from /migrations in timestamp order (or copy to supabase/migrations and run supabase db push).

-- Example: add a column only if it does not exist (idempotent).
-- ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS reorder_level numeric DEFAULT 0;

-- Example: create table only if not exists.
-- CREATE TABLE IF NOT EXISTS public.erp_module_registry (
--   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
--   module_key text NOT NULL UNIQUE,
--   enabled boolean NOT NULL DEFAULT true,
--   created_at timestamptz DEFAULT now(),
--   updated_at timestamptz DEFAULT now()
-- );

-- This migration is intentionally a no-op so existing DB is unchanged.
-- Add your DDL above (e.g. CREATE TABLE, ALTER TABLE, CREATE INDEX).
