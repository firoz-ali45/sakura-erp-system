-- One-time: fix existing ledger rows for GRN batches that were posted with wrong location_id.
-- (e.g. GRN-000077 batches had storage_location Sadiyan (B01) but ledger used default Main Warehouse.)
-- Temporarily allow UPDATE on inventory_stock_ledger, backfill location_id from batch.storage_location, then re-enable immutability.

DROP TRIGGER IF EXISTS trg_ledger_immutable_update ON inventory_stock_ledger;
DROP TRIGGER IF EXISTS trg_ledger_immutable_delete ON inventory_stock_ledger;

UPDATE inventory_stock_ledger isl
SET location_id = sub.new_location_id
FROM (
  SELECT isl2.id AS ledger_id, public.fn_resolve_storage_location_to_id(b.storage_location) AS new_location_id
  FROM inventory_stock_ledger isl2
  JOIN batches b ON b.id = isl2.batch_id
  WHERE isl2.reference_type = 'GRN'
    AND isl2.batch_id IS NOT NULL
    AND b.storage_location IS NOT NULL
    AND TRIM(b.storage_location) <> ''
    AND public.fn_resolve_storage_location_to_id(b.storage_location) IS NOT NULL
    AND public.fn_resolve_storage_location_to_id(b.storage_location) <> isl2.location_id
) sub
WHERE isl.id = sub.ledger_id;

CREATE TRIGGER trg_ledger_immutable_update
  BEFORE UPDATE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION prevent_update_delete_ledger();
CREATE TRIGGER trg_ledger_immutable_delete
  BEFORE DELETE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION prevent_update_delete_ledger();
