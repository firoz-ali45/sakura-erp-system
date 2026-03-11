-- ============================================================
-- ENTERPRISE MANUFACTURING MODULE — Production Orders, Items,
-- Raw Material Consumption, WIP Lots, Finished Goods Batches.
-- Full traceability: FG Batch → WIP Lot → RM Batches.
-- ============================================================

-- ---------- 1) Recipes (BOM: output item + ingredients) ----------
CREATE TABLE IF NOT EXISTS public.recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  output_item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  output_qty_per_batch numeric(18,4) NOT NULL DEFAULT 1,
  company_id uuid REFERENCES public.companies(id),
  tenant_id uuid REFERENCES public.tenants(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, code)
);

CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id uuid NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  quantity_required numeric(18,4) NOT NULL,
  unit text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(recipe_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_output_item ON public.recipes(output_item_id);
CREATE INDEX IF NOT EXISTS idx_recipes_company ON public.recipes(company_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON public.recipe_ingredients(recipe_id);

-- ---------- 2) Production number sequence ----------
CREATE TABLE IF NOT EXISTS public.production_number_sequence (
  id int PRIMARY KEY DEFAULT 1,
  next_val int NOT NULL DEFAULT 1,
  year_val int NOT NULL DEFAULT EXTRACT(year FROM current_date)::int,
  CONSTRAINT one_row CHECK (id = 1)
);

INSERT INTO public.production_number_sequence (id, next_val, year_val)
SELECT 1, 1, EXTRACT(year FROM current_date)::int
WHERE NOT EXISTS (SELECT 1 FROM public.production_number_sequence WHERE id = 1);

-- Next production number: PRD-YYYY-NNNNNN (e.g. PRD-2026-000001)
CREATE OR REPLACE FUNCTION public.fn_next_production_number(p_tenant_id uuid DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_year int := EXTRACT(year FROM current_date)::int;
  v_next int;
BEGIN
  UPDATE public.production_number_sequence
  SET next_val = CASE WHEN year_val = v_year THEN next_val + 1 ELSE 1 END,
      year_val = v_year
  WHERE id = 1
  RETURNING next_val INTO v_next;
  IF v_next IS NULL THEN
    INSERT INTO public.production_number_sequence (id, next_val, year_val) VALUES (1, 1, v_year)
    ON CONFLICT (id) DO UPDATE SET next_val = production_number_sequence.next_val + 1, year_val = v_year
    RETURNING next_val INTO v_next;
  END IF;
  RETURN 'PRD-' || v_year || '-' || lpad(COALESCE(v_next, 1)::text, 6, '0');
END;
$$;

-- ---------- 3) Production Orders ----------
CREATE TABLE IF NOT EXISTS public.production_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_number text NOT NULL,
  branch_id uuid NOT NULL REFERENCES public.branches(id),
  recipe_id uuid REFERENCES public.recipes(id),
  planned_qty numeric(18,4) NOT NULL DEFAULT 0,
  produced_qty numeric(18,4) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'released', 'closed')),
  production_date date,
  company_id uuid REFERENCES public.companies(id),
  tenant_id uuid REFERENCES public.tenants(id),
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_production_orders_number_tenant
  ON public.production_orders(tenant_id, production_number);
CREATE INDEX IF NOT EXISTS idx_production_orders_branch ON public.production_orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_production_orders_status ON public.production_orders(status);
CREATE INDEX IF NOT EXISTS idx_production_orders_company ON public.production_orders(company_id);

-- ---------- 4) Production Items (FG lines per order) ----------
CREATE TABLE IF NOT EXISTS public.production_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id uuid NOT NULL REFERENCES public.production_orders(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  recipe_id uuid REFERENCES public.recipes(id),
  quantity_planned numeric(18,4) NOT NULL,
  quantity_produced numeric(18,4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(production_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_production_items_production ON public.production_items(production_id);

-- ---------- 5) Raw Material Consumption ----------
CREATE TABLE IF NOT EXISTS public.production_consumption (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id uuid NOT NULL REFERENCES public.production_orders(id) ON DELETE CASCADE,
  production_item_id uuid REFERENCES public.production_items(id) ON DELETE SET NULL,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  batch_id uuid NOT NULL REFERENCES public.batches(id),
  quantity numeric(18,4) NOT NULL,
  cost numeric(18,4) NOT NULL DEFAULT 0,
  company_id uuid REFERENCES public.companies(id),
  tenant_id uuid REFERENCES public.tenants(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_production_consumption_production ON public.production_consumption(production_id);
CREATE INDEX IF NOT EXISTS idx_production_consumption_batch ON public.production_consumption(batch_id);

-- ---------- 6) WIP Lots ----------
CREATE TABLE IF NOT EXISTS public.wip_lots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id uuid NOT NULL REFERENCES public.production_orders(id) ON DELETE CASCADE,
  production_item_id uuid REFERENCES public.production_items(id) ON DELETE SET NULL,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  lot_number text NOT NULL,
  quantity numeric(18,4) NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  expiry_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wip_lots_production ON public.wip_lots(production_id);

-- ---------- 7) Finished Goods Batches ----------
CREATE TABLE IF NOT EXISTS public.fg_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id uuid NOT NULL REFERENCES public.production_orders(id) ON DELETE CASCADE,
  production_item_id uuid REFERENCES public.production_items(id) ON DELETE SET NULL,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id),
  batch_id uuid NOT NULL REFERENCES public.batches(id),
  quantity numeric(18,4) NOT NULL,
  unit_cost numeric(18,4) NOT NULL DEFAULT 0,
  expiry_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fg_batches_production ON public.fg_batches(production_id);
CREATE INDEX IF NOT EXISTS idx_fg_batches_batch ON public.fg_batches(batch_id);

-- ---------- 8) View: production orders with branch name and creator ----------
-- (fn_user_display_name may already exist from user-display-names migration; harmless if replaced)
CREATE OR REPLACE FUNCTION public.fn_user_display_name(p_user_id uuid) RETURNS text
  LANGUAGE sql STABLE AS $$SELECT COALESCE(NULLIF(TRIM(name), ''), SPLIT_PART(email, '@', 1), 'Not available') FROM public.users WHERE id = p_user_id LIMIT 1$$;

DROP VIEW IF EXISTS public.v_production_orders_full CASCADE;
CREATE VIEW public.v_production_orders_full AS
SELECT
  po.id,
  po.production_number,
  po.branch_id,
  br.branch_name,
  br.branch_code,
  po.recipe_id,
  r.name AS recipe_name,
  r.output_item_id AS recipe_output_item_id,
  po.planned_qty,
  po.produced_qty,
  po.status,
  po.production_date,
  po.company_id,
  po.tenant_id,
  po.created_by,
  public.fn_user_display_name(po.created_by) AS created_by_name,
  po.created_at,
  po.updated_at,
  (SELECT COUNT(*) FROM public.production_items pi WHERE pi.production_id = po.id) AS item_count
FROM public.production_orders po
LEFT JOIN public.branches br ON br.id = po.branch_id
LEFT JOIN public.recipes r ON r.id = po.recipe_id;

-- ---------- 9) RLS (allow authenticated to read/write; scope by tenant/company in app) ----------
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wip_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fg_batches ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'production_orders' AND policyname = 'production_orders_all') THEN
    CREATE POLICY production_orders_all ON public.production_orders FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'production_items' AND policyname = 'production_items_all') THEN
    CREATE POLICY production_items_all ON public.production_items FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'production_consumption' AND policyname = 'production_consumption_all') THEN
    CREATE POLICY production_consumption_all ON public.production_consumption FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'wip_lots' AND policyname = 'wip_lots_all') THEN
    CREATE POLICY wip_lots_all ON public.wip_lots FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'fg_batches' AND policyname = 'fg_batches_all') THEN
    CREATE POLICY fg_batches_all ON public.fg_batches FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'recipes' AND policyname = 'recipes_all') THEN
    CREATE POLICY recipes_all ON public.recipes FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'recipe_ingredients' AND policyname = 'recipe_ingredients_all') THEN
    CREATE POLICY recipe_ingredients_all ON public.recipe_ingredients FOR ALL USING (true) WITH CHECK (true);
  END IF;
END$$;

GRANT SELECT ON public.v_production_orders_full TO authenticated, anon;

COMMENT ON TABLE public.production_orders IS 'Manufacturing production order header. Status: draft, released, closed.';
COMMENT ON TABLE public.production_items IS 'FG items to produce per order (item_id = output item, quantity_planned/produced).';
COMMENT ON TABLE public.production_consumption IS 'Raw material consumption per production (batch_id = RM batch deducted).';
COMMENT ON TABLE public.wip_lots IS 'Work-in-progress lots for traceability.';
COMMENT ON TABLE public.fg_batches IS 'Finished goods batches created by production (batch_id = FG batch, adds to inventory).';
