-- ============================================================
-- ENTERPRISE RECIPE / BOM — unit_conversions, recipe versioning,
-- recipe_ingredients (unit, storage_unit, conversion_factor).
-- ============================================================

-- ---------- 1) Unit conversion system ----------
CREATE TABLE IF NOT EXISTS public.unit_conversions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_unit text NOT NULL,
  to_unit text NOT NULL,
  conversion_factor numeric(18,6) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(from_unit, to_unit)
);

CREATE INDEX IF NOT EXISTS idx_unit_conversions_from ON public.unit_conversions(from_unit);
CREATE INDEX IF NOT EXISTS idx_unit_conversions_to ON public.unit_conversions(to_unit);

COMMENT ON TABLE public.unit_conversions IS 'Unit conversion factors, e.g. 1 KG = 1000 Gram.';

-- Seed common conversions (idempotent)
INSERT INTO public.unit_conversions (from_unit, to_unit, conversion_factor) VALUES
  ('KG', 'Gram', 1000),
  ('Gram', 'KG', 0.001),
  ('L', 'ML', 1000),
  ('ML', 'L', 0.001),
  ('L', 'Liter', 1),
  ('Liter', 'ML', 1000),
  ('Pcs', 'Pcs', 1)
ON CONFLICT (from_unit, to_unit) DO NOTHING;

-- ---------- 2) Extend recipes: versioning, base_quantity, base_unit, status, created_by ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'recipe_version') THEN
    ALTER TABLE public.recipes ADD COLUMN recipe_version int NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'base_quantity') THEN
    ALTER TABLE public.recipes ADD COLUMN base_quantity numeric(18,4) NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'base_unit') THEN
    ALTER TABLE public.recipes ADD COLUMN base_unit text DEFAULT 'Pcs';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'status') THEN
    ALTER TABLE public.recipes ADD COLUMN status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'created_by') THEN
    ALTER TABLE public.recipes ADD COLUMN created_by uuid REFERENCES public.users(id);
  END IF;
END$$;

-- Backfill base_quantity from output_qty_per_batch where base_quantity might be 1
UPDATE public.recipes SET base_quantity = output_qty_per_batch WHERE base_quantity = 0 OR base_quantity IS NULL;

-- item_id alias: recipes.output_item_id is the FG item; add unique (item_id, recipe_version) for versioning
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'item_id') THEN
    ALTER TABLE public.recipes ADD COLUMN item_id uuid REFERENCES public.inventory_items(id);
  END IF;
END$$;
UPDATE public.recipes SET item_id = output_item_id WHERE item_id IS NULL AND output_item_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_recipes_item_version
  ON public.recipes(COALESCE(item_id, output_item_id), recipe_version);

-- ---------- 3) Extend recipe_ingredients: storage_unit, conversion_factor, ingredient_item_id alias ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipe_ingredients' AND column_name = 'storage_unit') THEN
    ALTER TABLE public.recipe_ingredients ADD COLUMN storage_unit text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipe_ingredients' AND column_name = 'conversion_factor') THEN
    ALTER TABLE public.recipe_ingredients ADD COLUMN conversion_factor numeric(18,6) NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipe_ingredients' AND column_name = 'ingredient_item_id') THEN
    ALTER TABLE public.recipe_ingredients ADD COLUMN ingredient_item_id uuid REFERENCES public.inventory_items(id);
  END IF;
END$$;
UPDATE public.recipe_ingredients SET ingredient_item_id = item_id WHERE ingredient_item_id IS NULL AND item_id IS NOT NULL;

-- quantity alias (recipe_ingredients.quantity_required is the required qty)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'recipe_ingredients' AND column_name = 'quantity') THEN
    ALTER TABLE public.recipe_ingredients ADD COLUMN quantity numeric(18,4) NOT NULL DEFAULT 1;
  END IF;
END$$;
UPDATE public.recipe_ingredients SET quantity = quantity_required WHERE quantity = 0 OR quantity IS NULL;

-- ---------- 4) RLS for unit_conversions ----------
ALTER TABLE public.unit_conversions ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'unit_conversions' AND policyname = 'unit_conversions_all') THEN
    CREATE POLICY unit_conversions_all ON public.unit_conversions FOR ALL USING (true) WITH CHECK (true);
  END IF;
END$$;

-- ---------- 5) View: recipe with FG item name and ingredient count ----------
DROP VIEW IF EXISTS public.v_recipes_bom CASCADE;
CREATE VIEW public.v_recipes_bom AS
SELECT
  r.id,
  r.code,
  r.name,
  r.item_id,
  r.output_item_id,
  ii.name AS output_item_name,
  ii.sku AS output_item_sku,
  r.recipe_version,
  r.base_quantity,
  r.base_unit,
  r.status,
  r.output_qty_per_batch,
  r.company_id,
  r.tenant_id,
  r.created_by,
  r.created_at,
  r.updated_at,
  (SELECT COUNT(*) FROM public.recipe_ingredients ri WHERE ri.recipe_id = r.id) AS ingredient_count
FROM public.recipes r
LEFT JOIN public.inventory_items ii ON ii.id = COALESCE(r.item_id, r.output_item_id);

GRANT SELECT ON public.v_recipes_bom TO authenticated, anon;

-- ---------- 6) Production orders: store recipe_version used ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'production_orders' AND column_name = 'recipe_version') THEN
    ALTER TABLE public.production_orders ADD COLUMN recipe_version int;
  END IF;
END$$;
COMMENT ON COLUMN public.production_orders.recipe_version IS 'Recipe version used for this production (from recipes.recipe_version).';
