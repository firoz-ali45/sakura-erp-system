-- ============================================================
-- INVENTORY REPORT ENGINE — Verification
-- All reports must read from ledger/views only. No frontend calc.
-- ============================================================

-- 1) v_inventory_balance: ledger-only, has category
SELECT 'v_inventory_balance' AS view_name, COUNT(*) AS row_count FROM v_inventory_balance;
SELECT * FROM v_inventory_balance LIMIT 2;

-- 2) v_inventory_history: full audit
SELECT 'v_inventory_history' AS view_name, COUNT(*) AS row_count FROM v_inventory_history;
SELECT * FROM v_inventory_history ORDER BY created_at DESC LIMIT 2;

-- 3) fn_inventory_control_report: date-range opening/closing
SELECT * FROM fn_inventory_control_report(
  (current_date - interval '30 days')::date,
  current_date
) LIMIT 2;

-- 4) v_transfers_report: TRANSFER_IN/OUT from ledger
SELECT 'v_transfers_report' AS view_name, COUNT(*) AS row_count FROM v_transfers_report;

-- 5) v_cost_adjustment_history: ADJUSTMENT, COST_ADJUSTMENT etc
SELECT 'v_cost_adjustment_history' AS view_name, COUNT(*) AS row_count FROM v_cost_adjustment_history;

-- 6) v_purchasing_report
SELECT 'v_purchasing_report' AS view_name, COUNT(*) AS row_count FROM v_purchasing_report;

-- 7) v_transfer_orders_report
SELECT 'v_transfer_orders_report' AS view_name, COUNT(*) AS row_count FROM v_transfer_orders_report;

-- 8) No negative stock (ledger integrity)
SELECT item_id, location_id, SUM(qty_in)-SUM(qty_out) AS balance
FROM inventory_stock_ledger
GROUP BY item_id, location_id
HAVING SUM(qty_in)-SUM(qty_out) < 0;
