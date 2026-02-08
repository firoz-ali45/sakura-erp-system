-- ============================================================
-- PHASE-2: FOODICS / SAP-LEVEL INVENTORY REPORT VIEWS
-- Derived ONLY from inventory_stock_ledger. READ-ONLY. No ledger mutation.
-- Single source of truth = ledger.
-- ============================================================

-- ============================================================
-- 1) v_inventory_balance — REAL-TIME STOCK
-- Group by: item_id, location_id, batch_id. No stored stock.
-- ============================================================
DROP VIEW IF EXISTS v_inventory_balance CASCADE;
CREATE VIEW v_inventory_balance AS
SELECT
    l.item_id,
    i.name       AS item_name,
    i.sku,
    i.storage_unit,
    l.location_id,
    loc.location_name,
    l.batch_id,
    b.batch_number,
    SUM(l.qty_in - l.qty_out) AS current_qty,
    CASE
        WHEN SUM(l.qty_in - l.qty_out) = 0 THEN 0
        ELSE SUM((l.qty_in - l.qty_out) * l.unit_cost)
             / NULLIF(SUM(l.qty_in - l.qty_out), 0)
    END AS avg_unit_cost,
    SUM((l.qty_in - l.qty_out) * l.unit_cost) AS total_value
FROM inventory_stock_ledger l
JOIN inventory_items i ON i.id = l.item_id
JOIN inventory_locations loc ON loc.id = l.location_id
LEFT JOIN inventory_batches b ON b.id = l.batch_id
GROUP BY
    l.item_id, i.name, i.sku, i.storage_unit,
    l.location_id, loc.location_name,
    l.batch_id, b.batch_number;

COMMENT ON VIEW v_inventory_balance IS 'Real-time stock from ledger only. Group by item, location, batch. Stock in UI must match this.';

-- ============================================================
-- 2) v_inventory_history — AUDIT / LEDGER VIEW
-- 1 row = 1 ledger entry. Ordered by date DESC. No aggregation.
-- ============================================================
DROP VIEW IF EXISTS v_inventory_history CASCADE;
CREATE VIEW v_inventory_history AS
SELECT
    i.name       AS item_name,
    i.sku,
    i.barcode,
    i.storage_unit,
    loc.location_name AS location,
    l.movement_type   AS transaction_type,
    l.reference_type,
    l.reference_id,
    CASE WHEN l.qty_in > 0 THEN l.qty_in ELSE -l.qty_out END AS quantity,
    (CASE WHEN l.qty_in > 0 THEN l.qty_in ELSE l.qty_out END) * l.unit_cost AS cost,
    l.movement_type   AS reason,
    NULL::text        AS notes,
    l.created_by,
    l.created_at
FROM inventory_stock_ledger l
JOIN inventory_items i ON i.id = l.item_id
JOIN inventory_locations loc ON loc.id = l.location_id;

COMMENT ON VIEW v_inventory_history IS 'Ledger-level audit. One row per ledger entry. History in UI must match this.';

-- ============================================================
-- 3) v_inventory_control — PERIOD-BASED (FOODICS LEVEL)
-- Opening = before period; Closing = opening + in − out.
-- Period = current month. All calculations from ledger.
-- Movement types aligned to ledger enum: GRN, TRANSFER_IN/OUT,
-- PRODUCTION_OUTPUT (in), PRODUCTION_CONSUMPTION (out), SALE,
-- ADJUSTMENT_IN/OUT, SCRAP, EXPIRED, RETURN.
-- ============================================================
DROP VIEW IF EXISTS v_inventory_control CASCADE;
CREATE VIEW v_inventory_control AS
WITH period_bounds AS (
    SELECT
        date_trunc('month', CURRENT_DATE)::date AS period_start,
        (date_trunc('month', CURRENT_DATE) + interval '1 month' - interval '1 day')::date AS period_end
),
base AS (
    SELECT
        l.item_id,
        l.location_id,
        l.created_at::date AS txn_date,
        l.movement_type,
        l.qty_in,
        l.qty_out,
        l.unit_cost
    FROM inventory_stock_ledger l
),
-- Driver: all (item_id, location_id) with ledger activity up to period end
driven AS (
    SELECT DISTINCT b.item_id, b.location_id
    FROM base b
    CROSS JOIN period_bounds p
    WHERE b.txn_date <= p.period_end
),
opening AS (
    SELECT
        b.item_id,
        b.location_id,
        SUM(b.qty_in - b.qty_out) AS opening_qty,
        SUM((b.qty_in - b.qty_out) * b.unit_cost) AS opening_cost
    FROM base b
    CROSS JOIN period_bounds p
    WHERE b.txn_date < p.period_start
    GROUP BY b.item_id, b.location_id
),
in_period AS (
    SELECT
        b.item_id,
        b.location_id,
        SUM(CASE WHEN b.movement_type IN ('GRN', 'TRANSFER_IN', 'PRODUCTION_OUTPUT', 'ADJUSTMENT_IN', 'RETURN')
            THEN b.qty_in ELSE 0 END) AS total_in_qty,
        SUM(CASE WHEN b.movement_type IN ('GRN', 'TRANSFER_IN', 'PRODUCTION_OUTPUT', 'ADJUSTMENT_IN', 'RETURN')
            THEN b.qty_in * b.unit_cost ELSE 0 END) AS total_in_cost,
        SUM(CASE WHEN b.movement_type IN ('TRANSFER_OUT', 'SALE', 'PRODUCTION_CONSUMPTION', 'ADJUSTMENT_OUT', 'SCRAP', 'EXPIRED')
            THEN b.qty_out ELSE 0 END) AS total_out_qty,
        SUM(CASE WHEN b.movement_type IN ('TRANSFER_OUT', 'SALE', 'PRODUCTION_CONSUMPTION', 'ADJUSTMENT_OUT', 'SCRAP', 'EXPIRED')
            THEN b.qty_out * b.unit_cost ELSE 0 END) AS total_out_cost
    FROM base b
    CROSS JOIN period_bounds p
    WHERE b.txn_date >= p.period_start AND b.txn_date <= p.period_end
    GROUP BY b.item_id, b.location_id
),
closing_raw AS (
    SELECT
        b.item_id,
        b.location_id,
        SUM(b.qty_in - b.qty_out) AS closing_qty,
        SUM((b.qty_in - b.qty_out) * b.unit_cost) AS closing_cost
    FROM base b
    CROSS JOIN period_bounds p
    WHERE b.txn_date <= p.period_end
    GROUP BY b.item_id, b.location_id
)
SELECT
    d.item_id,
    i.name   AS item_name,
    i.sku,
    i.storage_unit,
    d.location_id,
    loc.location_name,
    COALESCE(o.opening_qty, 0)     AS opening_qty,
    COALESCE(o.opening_cost, 0)     AS opening_cost,
    COALESCE(ip.total_in_qty, 0)   AS total_in_qty,
    COALESCE(ip.total_in_cost, 0)   AS total_in_cost,
    COALESCE(ip.total_out_qty, 0)   AS total_out_qty,
    COALESCE(ip.total_out_cost, 0)  AS total_out_cost,
    COALESCE(c.closing_qty, 0)     AS closing_qty,
    COALESCE(c.closing_cost, 0)     AS closing_cost
FROM driven d
JOIN inventory_items i ON i.id = d.item_id
JOIN inventory_locations loc ON loc.id = d.location_id
LEFT JOIN opening o ON o.item_id = d.item_id AND o.location_id = d.location_id
LEFT JOIN in_period ip ON ip.item_id = d.item_id AND ip.location_id = d.location_id
LEFT JOIN closing_raw c ON c.item_id = d.item_id AND c.location_id = d.location_id;

COMMENT ON VIEW v_inventory_control IS 'Period-based control (current month). Opening/In/Out/Closing from ledger only. Control totals must reconcile with ledger.';

-- Grants so UI (anon/authenticated) can SELECT
GRANT SELECT ON v_inventory_balance TO anon, authenticated;
GRANT SELECT ON v_inventory_history TO anon, authenticated;
GRANT SELECT ON v_inventory_control TO anon, authenticated;

-- ============================================================
-- 4) VERIFICATION QUERIES (MANDATORY)
-- ============================================================
-- Run after deployment to confirm:
--   Stock in UI == v_inventory_balance
--   History == v_inventory_history
--   Control totals reconcile with ledger
/*
-- Stock snapshot
SELECT * FROM v_inventory_balance ORDER BY item_name, location_name;

-- Audit trail (order by date DESC)
SELECT * FROM v_inventory_history ORDER BY created_at DESC LIMIT 100;

-- Control report
SELECT * FROM v_inventory_control;
*/
