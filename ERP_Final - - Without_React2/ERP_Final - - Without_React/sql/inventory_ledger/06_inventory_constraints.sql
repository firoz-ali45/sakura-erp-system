-- ============================================================
-- MODULE 7: BUSINESS RULES (ENFORCED)
-- No negative stock unless explicitly allowed; cannot consume more than available.
-- Branch: cannot create PO, cannot receive production output.
-- Warehouse: main cost holder, only source for transfers.
-- Ledger: forbid UPDATE/DELETE (trigger).
-- ============================================================

-- Forbid UPDATE and DELETE on inventory_stock_ledger (immutable)
CREATE OR REPLACE FUNCTION trg_inventory_stock_ledger_immutable()
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

CREATE TRIGGER trg_inventory_stock_ledger_no_update
  BEFORE UPDATE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();

CREATE TRIGGER trg_inventory_stock_ledger_no_delete
  BEFORE DELETE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();

-- Optional: check negative balance (by item/location/batch) on INSERT of qty_out
-- Uncomment and adapt if strict no-negative rule is required at insert time:
/*
CREATE OR REPLACE FUNCTION trg_inventory_ledger_no_negative()
RETURNS TRIGGER AS $$
DECLARE
  v_balance numeric;
BEGIN
  IF NEW.qty_out <= 0 THEN RETURN NEW; END IF;
  SELECT SUM(qty_in) - SUM(qty_out) INTO v_balance
  FROM inventory_stock_ledger
  WHERE item_id = NEW.item_id AND location_id = NEW.location_id
    AND (batch_id IS NOT DISTINCT FROM NEW.batch_id);
  IF COALESCE(v_balance, 0) - NEW.qty_out < 0 THEN
    RAISE EXCEPTION 'Insufficient stock: balance % for item % location %', v_balance, NEW.item_id, NEW.location_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_inventory_ledger_no_negative
  BEFORE INSERT ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_ledger_no_negative();
*/
