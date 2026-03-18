-- ============================================================
-- NEXORA ERP (SaaS) — Multi-company isolation + subscription gating (v2).
-- Fix: inventory_stock_ledger is immutable (no UPDATE). We DO NOT backfill
-- ledger rows; instead, we allow legacy visibility via tenant_id when
-- company_id is null, and ensure NEW ledger inserts include company_id.
-- ============================================================

-- ---------- 1) Companies: SaaS subscription fields ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='name') THEN
    ALTER TABLE public.companies ADD COLUMN name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='subscription_plan') THEN
    ALTER TABLE public.companies ADD COLUMN subscription_plan text DEFAULT 'free';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='status') THEN
    ALTER TABLE public.companies ADD COLUMN status text DEFAULT 'active' CHECK (status IN ('active','suspended','deleted'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='trial_days') THEN
    ALTER TABLE public.companies ADD COLUMN trial_days int NOT NULL DEFAULT 14;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='subscription_status') THEN
    ALTER TABLE public.companies ADD COLUMN subscription_status text NOT NULL DEFAULT 'trial'
      CHECK (subscription_status IN ('trial','active','past_due','expired','canceled'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='companies' AND column_name='expiry_date') THEN
    ALTER TABLE public.companies ADD COLUMN expiry_date date;
  END IF;
END$$;

UPDATE public.companies
SET name = COALESCE(NULLIF(TRIM(name), ''), NULLIF(TRIM(company_name), ''))
WHERE name IS NULL OR TRIM(name) = '';

CREATE INDEX IF NOT EXISTS idx_companies_status ON public.companies(status);
CREATE INDEX IF NOT EXISTS idx_companies_subscription_status ON public.companies(subscription_status);

-- ---------- 2) Users: bind each user to a company ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='company_id') THEN
    ALTER TABLE public.users ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
END$$;

UPDATE public.users
SET company_id = '00000000-0000-0000-0000-000000000000'::uuid
WHERE company_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_company_id ON public.users(company_id);

-- ---------- 3) Core tables: ensure company_id exists ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='inventory_items' AND column_name='company_id') THEN
    ALTER TABLE public.inventory_items ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='suppliers' AND column_name='company_id') THEN
    ALTER TABLE public.suppliers ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='purchase_orders' AND column_name='company_id') THEN
    ALTER TABLE public.purchase_orders ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;

  -- Ledger: add company_id column, but do NOT backfill (immutable table)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='inventory_stock_ledger' AND column_name='company_id') THEN
    ALTER TABLE public.inventory_stock_ledger ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;

  -- Manufacturing
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='recipe_ingredients' AND column_name='company_id') THEN
    ALTER TABLE public.recipe_ingredients ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='production_items' AND column_name='company_id') THEN
    ALTER TABLE public.production_items ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='production_consumption' AND column_name='company_id') THEN
    ALTER TABLE public.production_consumption ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='wip_lots' AND column_name='company_id') THEN
    ALTER TABLE public.wip_lots ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='fg_batches' AND column_name='company_id') THEN
    ALTER TABLE public.fg_batches ADD COLUMN company_id uuid REFERENCES public.companies(id);
  END IF;
END$$;

-- Backfill company_id on mutable tables
UPDATE public.inventory_items SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;
UPDATE public.suppliers SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;
UPDATE public.purchase_orders SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;

UPDATE public.recipe_ingredients ri
SET company_id = r.company_id
FROM public.recipes r
WHERE ri.recipe_id = r.id AND ri.company_id IS NULL;
UPDATE public.recipe_ingredients SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;

UPDATE public.production_items pi
SET company_id = po.company_id
FROM public.production_orders po
WHERE pi.production_id = po.id AND pi.company_id IS NULL;
UPDATE public.production_consumption pc
SET company_id = po.company_id
FROM public.production_orders po
WHERE pc.production_id = po.id AND pc.company_id IS NULL;
UPDATE public.wip_lots wl
SET company_id = po.company_id
FROM public.production_orders po
WHERE wl.production_id = po.id AND wl.company_id IS NULL;
UPDATE public.fg_batches fg
SET company_id = po.company_id
FROM public.production_orders po
WHERE fg.production_id = po.id AND fg.company_id IS NULL;

UPDATE public.production_items SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;
UPDATE public.production_consumption SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;
UPDATE public.wip_lots SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;
UPDATE public.fg_batches SET company_id = '00000000-0000-0000-0000-000000000000'::uuid WHERE company_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_items_company_id ON public.inventory_items(company_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_company_id ON public.suppliers(company_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_company_id ON public.purchase_orders(company_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_company_id ON public.recipe_ingredients(company_id);
CREATE INDEX IF NOT EXISTS idx_production_items_company_id ON public.production_items(company_id);
CREATE INDEX IF NOT EXISTS idx_production_consumption_company_id ON public.production_consumption(company_id);
CREATE INDEX IF NOT EXISTS idx_wip_lots_company_id ON public.wip_lots(company_id);
CREATE INDEX IF NOT EXISTS idx_fg_batches_company_id ON public.fg_batches(company_id);
CREATE INDEX IF NOT EXISTS idx_ledger_company_id ON public.inventory_stock_ledger(company_id);

-- ---------- 4) Helpers: current company + current tenant + subscription gating ----------
CREATE OR REPLACE FUNCTION public.fn_current_company_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.company_id
  FROM public.users u
  WHERE u.id = auth.uid()
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.fn_current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.tenant_id
  FROM public.users u
  WHERE u.id = auth.uid()
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.fn_subscription_active(p_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(c.is_active, true) = true
    AND COALESCE(c.is_deleted, false) = false
    AND COALESCE(c.status, 'active') = 'active'
    AND (
      COALESCE(c.subscription_status, 'trial') IN ('trial','active')
      AND (c.expiry_date IS NULL OR c.expiry_date >= CURRENT_DATE)
    )
  FROM public.companies c
  WHERE c.id = p_company_id
  LIMIT 1
$$;

-- ---------- 5) RLS: replace permissive policies with company isolation ----------
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_stock_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wip_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fg_batches ENABLE ROW LEVEL SECURITY;

-- Drop existing open policies
DROP POLICY IF EXISTS production_orders_all ON public.production_orders;
DROP POLICY IF EXISTS production_items_all ON public.production_items;
DROP POLICY IF EXISTS production_consumption_all ON public.production_consumption;
DROP POLICY IF EXISTS wip_lots_all ON public.wip_lots;
DROP POLICY IF EXISTS fg_batches_all ON public.fg_batches;
DROP POLICY IF EXISTS recipes_all ON public.recipes;
DROP POLICY IF EXISTS recipe_ingredients_all ON public.recipe_ingredients;

DROP POLICY IF EXISTS "Allow all for authenticated users - items" ON public.inventory_items;
DROP POLICY IF EXISTS inv_items_select_anon ON public.inventory_items;
DROP POLICY IF EXISTS inv_items_select_authenticated ON public.inventory_items;
DROP POLICY IF EXISTS inv_items_insert_authenticated ON public.inventory_items;
DROP POLICY IF EXISTS inv_items_update_authenticated ON public.inventory_items;
DROP POLICY IF EXISTS inv_items_delete_authenticated ON public.inventory_items;

DROP POLICY IF EXISTS suppliers_select_anon ON public.suppliers;
DROP POLICY IF EXISTS suppliers_select_authenticated ON public.suppliers;
DROP POLICY IF EXISTS suppliers_insert_authenticated ON public.suppliers;
DROP POLICY IF EXISTS suppliers_update_authenticated ON public.suppliers;
DROP POLICY IF EXISTS suppliers_delete_authenticated ON public.suppliers;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.suppliers;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.suppliers;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.suppliers;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.suppliers;

DROP POLICY IF EXISTS po_select_anon ON public.purchase_orders;
DROP POLICY IF EXISTS po_select_authenticated ON public.purchase_orders;
DROP POLICY IF EXISTS po_insert_anon ON public.purchase_orders;
DROP POLICY IF EXISTS po_insert_authenticated ON public.purchase_orders;
DROP POLICY IF EXISTS po_update_anon ON public.purchase_orders;
DROP POLICY IF EXISTS po_update_authenticated ON public.purchase_orders;
DROP POLICY IF EXISTS po_delete_authenticated ON public.purchase_orders;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.purchase_orders;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.purchase_orders;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.purchase_orders;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.purchase_orders;
DROP POLICY IF EXISTS "Allow all read purchase_orders" ON public.purchase_orders;
DROP POLICY IF EXISTS "Allow all write purchase_orders" ON public.purchase_orders;

DROP POLICY IF EXISTS stock_ledger_select_anon ON public.inventory_stock_ledger;
DROP POLICY IF EXISTS stock_ledger_select_authenticated ON public.inventory_stock_ledger;
DROP POLICY IF EXISTS stock_ledger_insert_anon ON public.inventory_stock_ledger;
DROP POLICY IF EXISTS stock_ledger_insert_authenticated ON public.inventory_stock_ledger;

DROP POLICY IF EXISTS "Allow all SELECT" ON public.users;
DROP POLICY IF EXISTS "Allow all INSERT" ON public.users;
DROP POLICY IF EXISTS "Allow all UPDATE" ON public.users;
DROP POLICY IF EXISTS "Allow all DELETE" ON public.users;

-- Companies: user can see only their company
DROP POLICY IF EXISTS companies_select_own ON public.companies;
CREATE POLICY companies_select_own
  ON public.companies
  FOR SELECT
  TO authenticated
  USING (id = public.fn_current_company_id());

-- Users: user can see/update only their own profile
DROP POLICY IF EXISTS users_select_self ON public.users;
CREATE POLICY users_select_self
  ON public.users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS users_update_self ON public.users;
CREATE POLICY users_update_self
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Inventory Items
DROP POLICY IF EXISTS inventory_items_company_select ON public.inventory_items;
CREATE POLICY inventory_items_company_select
  ON public.inventory_items
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS inventory_items_company_write ON public.inventory_items;
CREATE POLICY inventory_items_company_write
  ON public.inventory_items
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- Suppliers
DROP POLICY IF EXISTS suppliers_company_select ON public.suppliers;
CREATE POLICY suppliers_company_select
  ON public.suppliers
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS suppliers_company_write ON public.suppliers;
CREATE POLICY suppliers_company_write
  ON public.suppliers
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- Purchase Orders
DROP POLICY IF EXISTS purchase_orders_company_select ON public.purchase_orders;
CREATE POLICY purchase_orders_company_select
  ON public.purchase_orders
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS purchase_orders_company_write ON public.purchase_orders;
CREATE POLICY purchase_orders_company_write
  ON public.purchase_orders
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- Recipes + Ingredients
DROP POLICY IF EXISTS recipes_company_select ON public.recipes;
CREATE POLICY recipes_company_select
  ON public.recipes
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS recipes_company_write ON public.recipes;
CREATE POLICY recipes_company_write
  ON public.recipes
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

DROP POLICY IF EXISTS recipe_ingredients_company_select ON public.recipe_ingredients;
CREATE POLICY recipe_ingredients_company_select
  ON public.recipe_ingredients
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS recipe_ingredients_company_write ON public.recipe_ingredients;
CREATE POLICY recipe_ingredients_company_write
  ON public.recipe_ingredients
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- Production tables
DROP POLICY IF EXISTS production_orders_company_select ON public.production_orders;
CREATE POLICY production_orders_company_select
  ON public.production_orders
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS production_orders_company_write ON public.production_orders;
CREATE POLICY production_orders_company_write
  ON public.production_orders
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

DROP POLICY IF EXISTS production_items_company_select ON public.production_items;
CREATE POLICY production_items_company_select
  ON public.production_items
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS production_items_company_write ON public.production_items;
CREATE POLICY production_items_company_write
  ON public.production_items
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

DROP POLICY IF EXISTS production_consumption_company_select ON public.production_consumption;
CREATE POLICY production_consumption_company_select
  ON public.production_consumption
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS production_consumption_company_write ON public.production_consumption;
CREATE POLICY production_consumption_company_write
  ON public.production_consumption
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

DROP POLICY IF EXISTS wip_lots_company_select ON public.wip_lots;
CREATE POLICY wip_lots_company_select
  ON public.wip_lots
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS wip_lots_company_write ON public.wip_lots;
CREATE POLICY wip_lots_company_write
  ON public.wip_lots
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

DROP POLICY IF EXISTS fg_batches_company_select ON public.fg_batches;
CREATE POLICY fg_batches_company_select
  ON public.fg_batches
  FOR SELECT TO authenticated
  USING (company_id = public.fn_current_company_id());

DROP POLICY IF EXISTS fg_batches_company_write ON public.fg_batches;
CREATE POLICY fg_batches_company_write
  ON public.fg_batches
  FOR ALL TO authenticated
  USING (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id))
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- Ledger: allow legacy visibility via tenant_id if company_id is null
DROP POLICY IF EXISTS stock_ledger_company_select ON public.inventory_stock_ledger;
CREATE POLICY stock_ledger_company_select
  ON public.inventory_stock_ledger
  FOR SELECT TO authenticated
  USING (\n+    (company_id IS NOT NULL AND company_id = public.fn_current_company_id())\n+    OR (company_id IS NULL AND tenant_id IS NOT NULL AND tenant_id = public.fn_current_tenant_id())\n+  );

DROP POLICY IF EXISTS stock_ledger_company_insert ON public.inventory_stock_ledger;
CREATE POLICY stock_ledger_company_insert
  ON public.inventory_stock_ledger
  FOR INSERT TO authenticated
  WITH CHECK (company_id = public.fn_current_company_id() AND public.fn_subscription_active(company_id));

-- ---------- 6) Production: company-scoped recipe lookup + new ledger inserts include company_id ----------
CREATE OR REPLACE FUNCTION public.fn_execute_production(
  p_production_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_po RECORD;
  v_item RECORD;
  v_recipe_id uuid;
  v_base_qty numeric;
  v_ing RECORD;
  v_required numeric;
  v_consumption RECORD;
  v_batch_id uuid;
  v_unit_cost numeric;
  v_total_rm_cost numeric;
  v_location_id uuid;
  v_storage_location text;
  v_bal RECORD;
  v_deduct numeric;
  v_ingredient_item_id uuid;
  v_ing_qty numeric;
BEGIN
  SELECT id, production_number, branch_id, status, company_id, tenant_id
  INTO v_po
  FROM public.production_orders
  WHERE id = p_production_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Production order not found');
  END IF;
  IF v_po.status NOT IN ('draft', 'released') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Production already closed or invalid status');
  END IF;

  IF v_po.production_number IS NULL OR trim(v_po.production_number) = '' OR v_po.production_number LIKE 'Draft%' THEN
    UPDATE public.production_orders
    SET production_number = public.fn_next_production_number(v_po.tenant_id)
    WHERE id = p_production_id;
    SELECT id, production_number, branch_id, status, company_id, tenant_id
    INTO v_po
    FROM public.production_orders
    WHERE id = p_production_id;
  END IF;

  v_location_id := v_po.branch_id;
  SELECT branch_name INTO v_storage_location FROM public.branches WHERE id = v_po.branch_id;

  FOR v_item IN
    SELECT pi.id AS production_item_id, pi.item_id, pi.quantity_planned, pi.recipe_id
    FROM public.production_items pi
    WHERE pi.production_id = p_production_id AND pi.quantity_planned > 0
  LOOP
    v_recipe_id := v_item.recipe_id;
    IF v_recipe_id IS NULL THEN
      SELECT r.id INTO v_recipe_id
      FROM public.recipes r
      WHERE (r.item_id = v_item.item_id OR r.output_item_id = v_item.item_id)
        AND r.company_id = v_po.company_id
        AND r.status IN ('active', 'draft')
      ORDER BY r.recipe_version DESC NULLS LAST
      LIMIT 1;
    END IF;

    IF v_recipe_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.production_consumption pc
      WHERE pc.production_id = p_production_id AND pc.production_item_id = v_item.production_item_id
    ) THEN
      SELECT COALESCE(r.base_quantity, 1) INTO v_base_qty
      FROM public.recipes r WHERE r.id = v_recipe_id;
      v_base_qty := NULLIF(v_base_qty, 0);
      IF v_base_qty IS NULL THEN v_base_qty := 1; END IF;

      FOR v_ing IN
        SELECT COALESCE(ri.ingredient_item_id, ri.item_id) AS ingredient_item_id,
               COALESCE(ri.quantity, ri.quantity_required) AS qty_per_base
        FROM public.recipe_ingredients ri
        WHERE ri.recipe_id = v_recipe_id AND ri.company_id = v_po.company_id
      LOOP
        v_ingredient_item_id := v_ing.ingredient_item_id;
        v_ing_qty := COALESCE(v_ing.qty_per_base, 0);
        IF v_ingredient_item_id IS NULL OR v_ing_qty <= 0 THEN CONTINUE; END IF;

        v_required := (v_ing_qty / v_base_qty) * v_item.quantity_planned;
        IF v_required <= 0 THEN CONTINUE; END IF;

        FOR v_bal IN
          SELECT vb.batch_id, vb.current_qty AS cur_qty, COALESCE(vb.avg_cost, 0) AS avg_cost
          FROM public.v_inventory_balance vb
          WHERE vb.item_id = v_ingredient_item_id AND vb.location_id = v_location_id AND vb.current_qty > 0
          ORDER BY vb.batch_id
        LOOP
          EXIT WHEN v_required <= 0;
          v_deduct := LEAST(v_required, v_bal.cur_qty);
          INSERT INTO public.production_consumption (
            production_id, production_item_id, item_id, batch_id, quantity, cost, company_id, tenant_id
          ) VALUES (
            p_production_id, v_item.production_item_id, v_ingredient_item_id, v_bal.batch_id,
            v_deduct, v_deduct * v_bal.avg_cost, v_po.company_id, v_po.tenant_id
          );
          v_required := v_required - v_deduct;
        END LOOP;

        IF v_required > 0.0001 THEN
          RAISE EXCEPTION 'Insufficient stock for ingredient item % (required: %, short: %)',
            v_ingredient_item_id, (v_ing_qty / v_base_qty) * v_item.quantity_planned, v_required;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  FOR v_consumption IN
    SELECT pc.item_id, pc.batch_id, pc.quantity, pc.cost
    FROM public.production_consumption pc
    WHERE pc.production_id = p_production_id
  LOOP
    INSERT INTO public.inventory_stock_ledger (
      item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
      movement_type, reference_type, reference_id, created_by, tenant_id, company_id
    ) VALUES (
      v_consumption.item_id, v_location_id, v_consumption.batch_id,
      0, v_consumption.quantity,
      CASE WHEN v_consumption.quantity > 0 THEN v_consumption.cost / v_consumption.quantity ELSE 0 END,
      v_consumption.cost,
      'PRODUCTION_CONSUMPTION'::inventory_movement_type,
      'PRODUCTION'::inventory_reference_type,
      p_production_id::text,
      p_user_id,
      v_po.tenant_id,
      v_po.company_id
    );
  END LOOP;

  FOR v_item IN
    SELECT pi.id AS production_item_id, pi.item_id, pi.quantity_planned,
           (SELECT COALESCE(SUM(pc.cost), 0) FROM public.production_consumption pc
            WHERE pc.production_id = p_production_id AND pc.production_item_id = pi.id) AS linked_cost
    FROM public.production_items pi
    WHERE pi.production_id = p_production_id AND pi.quantity_planned > 0
  LOOP
    v_total_rm_cost := COALESCE(v_item.linked_cost, 0);
    v_unit_cost := CASE WHEN v_item.quantity_planned > 0 THEN v_total_rm_cost / v_item.quantity_planned ELSE 0 END;

    INSERT INTO public.batches (
      item_id, source_doc_type, source_doc_id, qty_received, branch_id,
      storage_location, tenant_id, company_id, created_by
    ) VALUES (
      v_item.item_id, 'PRODUCTION', p_production_id, v_item.quantity_planned, v_po.branch_id,
      v_storage_location, v_po.tenant_id, v_po.company_id, p_user_id
    )
    RETURNING id INTO v_batch_id;

    INSERT INTO public.fg_batches (production_id, production_item_id, item_id, batch_id, quantity, unit_cost, expiry_date, company_id)
    VALUES (p_production_id, v_item.production_item_id, v_item.item_id, v_batch_id, v_item.quantity_planned, v_unit_cost, NULL, v_po.company_id);

    INSERT INTO public.inventory_stock_ledger (
      item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
      movement_type, reference_type, reference_id, created_by, tenant_id, company_id
    ) VALUES (
      v_item.item_id, v_location_id, v_batch_id,
      v_item.quantity_planned, 0, v_unit_cost, v_total_rm_cost,
      'PRODUCTION_IN'::inventory_movement_type,
      'PRODUCTION'::inventory_reference_type,
      p_production_id::text,
      p_user_id,
      v_po.tenant_id,
      v_po.company_id
    );
  END LOOP;

  UPDATE public.production_items SET quantity_produced = quantity_planned WHERE production_id = p_production_id;
  UPDATE public.production_orders
  SET produced_qty = (SELECT COALESCE(SUM(quantity_planned), 0) FROM public.production_items WHERE production_id = p_production_id),
      status = 'closed',
      updated_at = now()
  WHERE id = p_production_id;

  RETURN jsonb_build_object('ok', true, 'production_id', p_production_id, 'production_number', v_po.production_number);
END;
$$;

COMMENT ON FUNCTION public.fn_execute_production(uuid, uuid) IS 'SaaS v2: company-scoped execute production, new ledger inserts include company_id; legacy ledger rows visible via tenant_id.';

