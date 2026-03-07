-- Unified data: stock_transfer_items.batch_id references public.batches (GRN batches).
-- View was joining _deprecated_inventory_batches so batch_no/batch_expiry were null after picking.
-- Fix: join public.batches so BATCH and EXPIRY display correctly in Transfer Sending UI.
CREATE OR REPLACE VIEW public.v_stock_transfer_items_full AS
SELECT
  sti.id,
  sti.transfer_id,
  sti.item_id,
  sti.batch_id,
  sti.transfer_qty,
  sti.picked_qty,
  sti.received_qty,
  sti.damaged_qty,
  sti.rejected_qty,
  sti.variance_qty,
  sti.lot_number,
  sti.expiry_date,
  sti.unit_cost,
  ii.name AS item_name,
  ii.sku,
  b.batch_number AS batch_no,
  b.expiry_date AS batch_expiry,
  b.vendor_batch_number AS lot_no
FROM stock_transfer_items sti
LEFT JOIN inventory_items ii ON ii.id = sti.item_id AND (ii.deleted IS NOT TRUE OR ii.deleted IS NULL)
LEFT JOIN public.batches b ON b.id = sti.batch_id;
