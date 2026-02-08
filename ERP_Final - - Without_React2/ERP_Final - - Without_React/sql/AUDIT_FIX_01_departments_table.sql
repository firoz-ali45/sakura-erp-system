-- ============================================================
-- AUDIT FIX 01: DEPARTMENTS - SINGLE SOURCE OF TRUTH
-- Department dropdown must come from DB, not hardcoded.
-- ============================================================

-- Create departments table if not exists
CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add department_id to purchase_requests if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_requests' AND column_name = 'department_id') THEN
    ALTER TABLE purchase_requests ADD COLUMN department_id uuid REFERENCES departments(id);
  END IF;
END $$;

-- Seed default departments (migrate from hardcoded list)
INSERT INTO departments (code, name, is_active) VALUES
  ('PROC', 'Procurement', true),
  ('KIT', 'Kitchen', true),
  ('WH', 'Warehouse', true),
  ('OPS', 'Operations', true),
  ('ADMIN', 'Administration', true),
  ('FIN', 'Finance', true),
  ('IT', 'IT', true),
  ('PROD', 'Production', true),
  ('QC', 'Quality Control', true),
  ('SALES', 'Sales', true)
ON CONFLICT (code) DO NOTHING;

-- Backfill department_id from department text (if department column exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_requests' AND column_name = 'department') THEN
    UPDATE purchase_requests pr
    SET department_id = d.id
    FROM departments d
    WHERE LOWER(TRIM(pr.department)) = LOWER(d.name)
      AND pr.department_id IS NULL;
  END IF;
END $$;

COMMENT ON TABLE departments IS 'Single source of truth for departments. PR/PO must use department_id.';
GRANT SELECT ON departments TO anon, authenticated;
