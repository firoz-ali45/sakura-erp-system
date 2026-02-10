-- ============================================================
-- SAP/FOODICS INVENTORY: Ledger + Locations + Report Views
-- Idempotent. Single source of truth: inventory_locations + inventory_stock_ledger.
-- No stored stock. No UI calculations. All from ledger/views.
-- ============================================================

-- ---------- 1) ENUM: inventory_movement_type (add missing values) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_movement_type') THEN
    CREATE TYPE inventory_movement_type AS ENUM (
      'GRN', 'TRANSFER_IN', 'TRANSFER_OUT', 'PRODUCTION_IN', 'PRODUCTION_CONSUMPTION',
      'SALE_CONSUMPTION', 'RETURN_FROM_ORDER', 'RETURN_TO_SUPPLIER', 'WASTE', 'EXPIRY',
      'ADJUSTMENT', 'COST_ADJUSTMENT', 'COUNT_VARIANCE'
    );
  END IF;
END$$;

-- Add enum values only if not already present
DO $$
DECLARE
  r text;
  vals text[] := ARRAY['PRODUCTION_IN','SALE_CONSUMPTION','RETURN_FROM_ORDER','RETURN_TO_SUPPLIER','WASTE','EXPIRY','ADJUSTMENT','COST_ADJUSTMENT','COUNT_VARIANCE'];
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_movement_type') THEN
    FOREACH r IN ARRAY vals LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'inventory_movement_type' AND e.enumlabel = r) THEN
        EXECUTE format('ALTER TYPE inventory_movement_type ADD VALUE %L', r);
      END IF;
    END LOOP;
  END IF;
END$$;

-- ---------- 2) LEDGER: ensure notes column (and reason if referenced by views) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'notes') THEN
    ALTER TABLE inventory_stock_ledger ADD COLUMN notes text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'reason') THEN
    ALTER TABLE inventory_stock_ledger ADD COLUMN reason text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'submitted_by') THEN
    ALTER TABLE inventory_stock_ledger ADD COLUMN submitted_by text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'submitted_at') THEN
    ALTER TABLE inventory_stock_ledger ADD COLUMN submitted_at timestamptz;
  END IF;
END$$;

-- ---------- 3) TRIGGER: prevent UPDATE/DELETE on ledger (immutable) ----------
CREATE OR REPLACE FUNCTION prevent_update_delete_ledger()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'inventory_stock_ledger is immutable: UPDATE not allowed.';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'inventory_stock_ledger is immutable: DELETE not allowed.';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_update ON inventory_stock_ledger;
DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_delete ON inventory_stock_ledger;
DROP TRIGGER IF EXISTS trg_ledger_immutable ON inventory_stock_ledger;

CREATE TRIGGER trg_ledger_immutable_update
  BEFORE UPDATE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION prevent_update_delete_ledger();
CREATE TRIGGER trg_ledger_immutable_delete
  BEFORE DELETE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION prevent_update_delete_ledger();

-- ---------- 4) v_inventory_balance: realtime, ledger-only (item_name, sku, storage_unit, location_name, batch_no, current_qty, avg_cost, total_value) ----------
DROP VIEW IF EXISTS v_inventory_balance CASCADE;
CREATE VIEW v_inventory_balance AS
SELECT
  b.item_id,
  b.location_id,
  b.batch_id,
  ii.name    AS item_name,
  ii.sku,
  ii.storage_unit,
  il.location_name,
  ib.batch_number AS batch_no,
  b.total_in,
  b.total_out,
  (b.total_in - b.total_out) AS current_qty,
  b.avg_cost,
  b.total_value
FROM (
  SELECT
    isl.item_id,
    isl.location_id,
    isl.batch_id,
    SUM(isl.qty_in) AS total_in,
    SUM(isl.qty_out) AS total_out,
    SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS total_value,
    CASE
      WHEN SUM(isl.qty_in) - SUM(isl.qty_out) > 0
      THEN SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) / NULLIF(SUM(isl.qty_in) - SUM(isl.qty_out), 0)
      ELSE 0
    END AS avg_cost
  FROM inventory_stock_ledger isl
  GROUP BY isl.item_id, isl.location_id, isl.batch_id
) b
LEFT JOIN inventory_items ii ON ii.id = b.item_id AND COALESCE(ii.deleted, false) = false
LEFT JOIN inventory_locations il ON il.id = b.location_id
LEFT JOIN inventory_batches ib ON ib.id = b.batch_id;

COMMENT ON VIEW v_inventory_balance IS 'Realtime balance from ledger only. item_name, sku, storage_unit, location_name, batch_no, current_qty, avg_cost, total_value.';

-- ---------- 5) v_inventory_history: audit (item, sku, barcode, location, transaction_type, reference, qty, cost, reason, notes, created_by, created_at) ----------
DROP VIEW IF EXISTS v_inventory_history CASCADE;
CREATE VIEW v_inventory_history AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  ii.name    AS item_name,
  ii.sku,
  ii.barcode,
  il.location_name AS location,
  isl.movement_type::text AS transaction_type,
  isl.reference_type || ' ' || COALESCE(isl.reference_id::text, '') AS reference,
  CASE WHEN isl.qty_in > 0 THEN isl.qty_in ELSE -isl.qty_out END AS qty,
  isl.unit_cost,
  isl.total_cost AS cost,
  isl.reason,
  isl.notes,
  isl.created_by,
  isl.created_at
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
ORDER BY isl.created_at DESC, isl.id;

COMMENT ON VIEW v_inventory_history IS 'Ledger audit. item_name, sku, barcode, location, transaction_type, reference, qty, cost, reason, notes, created_by, created_at.';

-- ---------- 6) v_inventory_control: date-range report (opening, in/out buckets, closing) ----------
-- Function so frontend can pass from_date, to_date. Returns one row per (item_id, location_id) for the period.
CREATE OR REPLACE FUNCTION fn_inventory_control_report(p_from_date date, p_to_date date)
RETURNS TABLE (
  item_id uuid,
  location_id uuid,
  item_name text,
  sku text,
  location_name text,
  opening_qty numeric,
  opening_cost numeric,
  purchasing_qty numeric,
  transfer_in_qty numeric,
  production_in_qty numeric,
  return_qty numeric,
  transfer_out_qty numeric,
  consumption_qty numeric,
  waste_qty numeric,
  adjustment_qty numeric,
  total_in numeric,
  total_out numeric,
  closing_qty numeric,
  closing_cost numeric
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  WITH
  opening AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) - SUM(isl.qty_out) AS qty,
      SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS cost
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date < p_from_date
    GROUP BY isl.item_id, isl.location_id
  ),
  period_in AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text = 'GRN') AS grn_qty,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('TRANSFER_IN')) AS transfer_in,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('PRODUCTION_IN','PRODUCTION_OUTPUT')) AS production_in,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('RETURN_FROM_ORDER','RETURN_TO_SUPPLIER','RETURN')) AS return_in,
      SUM(isl.qty_in) AS total_in
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date >= p_from_date AND isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  period_out AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('TRANSFER_OUT')) AS transfer_out,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('SALE_CONSUMPTION','SALE')) AS consumption,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('WASTE','SCRAP','EXPIRY','EXPIRED')) AS waste,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('ADJUSTMENT','ADJUSTMENT_OUT','COUNT_VARIANCE')) AS adjustment_out,
      SUM(isl.qty_out) AS total_out
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date >= p_from_date AND isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  closing AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) - SUM(isl.qty_out) AS qty,
      SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS cost
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  keys AS (
    SELECT DISTINCT k.ciid, k.clid
    FROM (
      SELECT o.item_id AS ciid, o.location_id AS clid FROM opening o
      UNION SELECT pin.item_id, pin.location_id FROM period_in pin
      UNION SELECT pout.item_id, pout.location_id FROM period_out pout
      UNION SELECT c.item_id, c.location_id FROM closing c
    ) k
  )
  SELECT
    k.ciid,
    k.clid,
    ii.name,
    ii.sku,
    il.location_name,
    COALESCE(o.qty, 0),
    COALESCE(o.cost, 0),
    COALESCE(pi.grn_qty, 0),
    COALESCE(pi.transfer_in, 0),
    COALESCE(pi.production_in, 0),
    COALESCE(pi.return_in, 0),
    COALESCE(po.transfer_out, 0),
    COALESCE(po.consumption, 0),
    COALESCE(po.waste, 0),
    COALESCE(po.adjustment_out, 0),
    COALESCE(pi.total_in, 0),
    COALESCE(po.total_out, 0),
    COALESCE(c.qty, 0),
    COALESCE(c.cost, 0)
  FROM keys k
  LEFT JOIN opening o ON o.item_id = k.ciid AND o.location_id = k.clid
  LEFT JOIN period_in pi ON pi.item_id = k.ciid AND pi.location_id = k.clid
  LEFT JOIN period_out po ON po.item_id = k.ciid AND po.location_id = k.clid
  LEFT JOIN closing c ON c.item_id = k.ciid AND c.location_id = k.clid
  LEFT JOIN inventory_items ii ON ii.id = k.ciid AND (ii.deleted IS NOT TRUE)
  LEFT JOIN inventory_locations il ON il.id = k.clid;
END;
$$;

COMMENT ON FUNCTION fn_inventory_control_report IS 'Date-range inventory control. Opening/In/Out/Closing from ledger only.';

-- View wrapper for v_inventory_control (all-time movements by item/location/date for simple listing; date filter in app)
DROP VIEW IF EXISTS v_inventory_control CASCADE;
CREATE VIEW v_inventory_control AS
SELECT
  isl.item_id,
  isl.location_id,
  isl.created_at::date AS movement_date,
  ii.name AS item_name,
  ii.sku,
  il.location_name,
  isl.movement_type::text,
  isl.qty_in,
  isl.qty_out,
  isl.total_cost
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
ORDER BY isl.created_at DESC;

COMMENT ON VIEW v_inventory_control IS 'Movement listing by date. Use fn_inventory_control_report(from, to) for opening/closing report.';

-- ---------- 7) Supporting report views ----------
DROP VIEW IF EXISTS v_purchase_orders_report CASCADE;
CREATE VIEW v_purchase_orders_report AS
SELECT po.id, po.po_number, po.supplier_id, po.order_date, po.status, po.destination, po.total_amount, po.notes,
  il.id AS location_id, il.location_code, il.location_name
FROM purchase_orders po
LEFT JOIN inventory_locations il ON il.is_active = true AND (il.location_name || ' (' || il.location_code || ')') = po.destination
WHERE COALESCE(po.deleted, false) = false;

DROP VIEW IF EXISTS v_transfer_orders_report CASCADE;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'transfer_orders') THEN
    CREATE VIEW v_transfer_orders_report AS
    SELECT NULL::uuid AS id, NULL::text AS transfer_number, NULL::uuid AS source_location_id, NULL::uuid AS dest_location_id,
      NULL::text AS status, NULL::date AS transfer_date,
      NULL::text AS source_code, NULL::text AS source_name, NULL::text AS dest_code, NULL::text AS dest_name
    WHERE false;
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'transfer_orders' AND column_name = 'source_location_id')
   AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'transfer_orders' AND column_name = 'dest_location_id') THEN
    CREATE VIEW v_transfer_orders_report AS
    SELECT t.id, t.transfer_number, t.source_location_id, t.dest_location_id, t.status, t.transfer_date::date AS transfer_date,
      sl.location_code AS source_code, sl.location_name AS source_name,
      dl.location_code AS dest_code, dl.location_name AS dest_name
    FROM transfer_orders t
    LEFT JOIN inventory_locations sl ON sl.id = t.source_location_id
    LEFT JOIN inventory_locations dl ON dl.id = t.dest_location_id
    WHERE COALESCE(t.deleted, false) = false;
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'transfer_orders' AND column_name = 'from_location')
   AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'transfer_orders' AND column_name = 'to_location') THEN
    -- transfer_orders with from_location / to_location (TEXT): match locations by name or "name (code)"
    CREATE VIEW v_transfer_orders_report AS
    SELECT t.id, t.transfer_number,
      sl.id AS source_location_id, dl.id AS dest_location_id,
      t.status, (t.transfer_date::timestamptz)::date AS transfer_date,
      sl.location_code AS source_code, sl.location_name AS source_name,
      dl.location_code AS dest_code, dl.location_name AS dest_name
    FROM transfer_orders t
    LEFT JOIN inventory_locations sl ON sl.is_active = true
      AND (sl.location_name = t.from_location OR (sl.location_name || ' (' || sl.location_code || ')') = t.from_location)
    LEFT JOIN inventory_locations dl ON dl.is_active = true
      AND (dl.location_name = t.to_location OR (dl.location_name || ' (' || dl.location_code || ')') = t.to_location)
    WHERE COALESCE(t.deleted, false) = false;
  ELSE
    -- transfer_orders exists but lacks location columns (e.g. only id, created_at): empty view
    CREATE VIEW v_transfer_orders_report AS
    SELECT NULL::uuid AS id, NULL::text AS transfer_number, NULL::uuid AS source_location_id, NULL::uuid AS dest_location_id,
      NULL::text AS status, NULL::date AS transfer_date,
      NULL::text AS source_code, NULL::text AS source_name, NULL::text AS dest_code, NULL::text AS dest_name
    WHERE false;
  END IF;
END$$;

DROP VIEW IF EXISTS v_transfers_report CASCADE;
CREATE VIEW v_transfers_report AS
SELECT isl.id, isl.item_id, isl.location_id, isl.movement_type, isl.qty_in, isl.qty_out, isl.unit_cost, isl.total_cost,
  isl.reference_type, isl.reference_id, isl.created_at,
  ii.name AS item_name, ii.sku, il.location_name, il.location_code
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
WHERE isl.movement_type::text IN ('TRANSFER_IN', 'TRANSFER_OUT')
ORDER BY isl.created_at DESC;

DROP VIEW IF EXISTS v_purchasing_report CASCADE;
CREATE VIEW v_purchasing_report AS
SELECT pi.id, pi.invoice_number, pi.purchasing_number, pi.grn_id, pi.grn_number, pi.purchase_order_id, pi.purchase_order_number,
  pi.supplier_id, pi.supplier_name, pi.invoice_date, pi.receiving_location, pi.subtotal, pi.tax_amount, pi.grand_total, pi.status,
  il.id AS location_id, il.location_code, il.location_name
FROM purchasing_invoices pi
LEFT JOIN inventory_locations il ON il.is_active = true AND (il.location_name || ' (' || il.location_code || ')') = pi.receiving_location
WHERE COALESCE(pi.deleted, false) = false;

DROP VIEW IF EXISTS v_cost_adjustment_history CASCADE;
CREATE VIEW v_cost_adjustment_history AS
SELECT isl.id, isl.item_id, isl.location_id, isl.movement_type, isl.qty_in, isl.qty_out, isl.unit_cost, isl.total_cost,
  isl.reason, isl.notes, isl.created_by, isl.created_at,
  ii.name AS item_name, ii.sku, il.location_name, il.location_code
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
WHERE isl.movement_type::text IN ('ADJUSTMENT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'COST_ADJUSTMENT', 'COUNT_VARIANCE', 'WASTE', 'EXPIRY', 'EXPIRED')
ORDER BY isl.created_at DESC;

-- ---------- 8) Location constraint: only active locations in dropdowns ----------
-- (Enforced in app: SELECT from inventory_locations WHERE is_active = true and allow_* as needed.)

-- ---------- 9) Verification: no ghost locations ----------
-- Run: SELECT * FROM inventory_locations WHERE is_active = true;
