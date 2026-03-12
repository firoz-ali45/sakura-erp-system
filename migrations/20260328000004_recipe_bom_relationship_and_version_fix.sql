-- ============================================================
-- FIX: Recipe BOM — single FK for ingredients, unique version.
-- Resolves: "more than one relationship between recipe_ingredients and inventory_items"
-- and "duplicate key idx_recipes_item_version".
-- ============================================================

-- ---------- 1) Recipes: ensure item_id used for versioning, unique (item_id, recipe_version) ----------
-- Use item_id; backfill from output_item_id where needed
UPDATE public.recipes SET item_id = output_item_id WHERE item_id IS NULL AND output_item_id IS NOT NULL;

-- Drop old unique index (may use COALESCE)
DROP INDEX IF EXISTS public.idx_recipes_item_version;

-- Unique on (item_id, recipe_version). For rows where item_id is null, use output_item_id in a partial index or expression.
-- PostgreSQL: unique index on (COALESCE(item_id, output_item_id), recipe_version) so same item cannot have duplicate version
CREATE UNIQUE INDEX idx_recipes_item_version
  ON public.recipes(COALESCE(item_id, output_item_id), recipe_version);

COMMENT ON INDEX public.idx_recipes_item_version IS 'One recipe version per item; prevents duplicate (item_id, recipe_version).';

-- ---------- 2) recipe_ingredients: keep only ingredient_item_id as the canonical FK for "ingredient item" ----------
-- Both item_id and ingredient_item_id exist; app must use only ingredient_item_id for new rows and for embedding.
-- Ensure ingredient_item_id is populated from item_id where missing
UPDATE public.recipe_ingredients SET ingredient_item_id = item_id WHERE ingredient_item_id IS NULL AND item_id IS NOT NULL;

-- No schema change to drop item_id (kept for legacy). Frontend will use explicit FK on ingredient_item_id when selecting.
