-- Custom app login uses PostgREST role "anon" without JWT; RLS policies on inventory_items
-- are TO authenticated only. This RPC inserts as DEFINER after validating the user row.

CREATE OR REPLACE FUNCTION public.fn_app_insert_inventory_item(
  p_user_id uuid,
  p_id uuid,
  p_name text,
  p_sku text,
  p_name_localized text,
  p_category text,
  p_storage_unit text,
  p_ingredient_unit text,
  p_storage_to_ingredient numeric,
  p_costing_method text,
  p_cost numeric,
  p_barcode text,
  p_min_level text,
  p_max_level text,
  p_par_level text,
  p_inventory_item_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company uuid;
  rec public.inventory_items%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_id IS NULL THEN
    RAISE EXCEPTION 'missing user or item id' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_user_id) THEN
    RAISE EXCEPTION 'invalid user' USING ERRCODE = '28000';
  END IF;

  SELECT u.company_id INTO v_company
  FROM public.users u
  WHERE u.id = p_user_id
  LIMIT 1;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'user has no company' USING ERRCODE = '28000';
  END IF;

  IF NOT public.fn_subscription_active(v_company) THEN
    RAISE EXCEPTION 'subscription inactive for company' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.inventory_items (
    id,
    company_id,
    name,
    name_localized,
    sku,
    category,
    storage_unit,
    ingredient_unit,
    storage_to_ingredient,
    costing_method,
    cost,
    barcode,
    min_level,
    max_level,
    par_level,
    inventory_item_id,
    deleted,
    created_at,
    updated_at
  )
  VALUES (
    p_id,
    v_company,
    NULLIF(btrim(p_name), ''),
    NULLIF(btrim(COALESCE(p_name_localized, '')), ''),
    NULLIF(btrim(p_sku), ''),
    NULLIF(btrim(COALESCE(p_category, '')), ''),
    COALESCE(NULLIF(btrim(COALESCE(p_storage_unit, '')), ''), 'Pcs'),
    COALESCE(NULLIF(btrim(COALESCE(p_ingredient_unit, '')), ''), 'Pcs'),
    COALESCE(p_storage_to_ingredient, 1),
    COALESCE(NULLIF(btrim(COALESCE(p_costing_method, '')), ''), 'From Transactions'),
    COALESCE(p_cost, 0),
    NULLIF(btrim(COALESCE(p_barcode, '')), ''),
    NULLIF(btrim(COALESCE(p_min_level, '')), ''),
    NULLIF(btrim(COALESCE(p_max_level, '')), ''),
    NULLIF(btrim(COALESCE(p_par_level, '')), ''),
    NULLIF(btrim(COALESCE(p_inventory_item_id, '')), ''),
    false,
    now(),
    now()
  )
  RETURNING * INTO rec;

  RETURN to_jsonb(rec);
END;
$$;

COMMENT ON FUNCTION public.fn_app_insert_inventory_item IS
  'Insert inventory_items for custom app auth (anon). Validates user and company; bypasses RLS.';

REVOKE ALL ON FUNCTION public.fn_app_insert_inventory_item(
  uuid, uuid, text, text, text, text, text, text, numeric, text, numeric, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_insert_inventory_item(
  uuid, uuid, text, text, text, text, text, text, numeric, text, numeric, text, text, text, text, text
) TO anon, authenticated;
