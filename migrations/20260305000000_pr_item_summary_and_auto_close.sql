-- DOCUMENT CONSISTENCY & AGGREGATION
-- 1) View v_pr_item_summary: per PR item, DB-aggregated ordered (PO), received (GRN), invoiced (PUR)
-- 2) Trigger: sync quantity_ordered/quantity_remaining from pr_po_linkage; auto-close PR when sum(ordered) >= total

-- ---------- 1) View: PR item summary (ordered from PO, received from GRN, invoiced from PUR) ----------
DROP VIEW IF EXISTS v_pr_item_summary CASCADE;

CREATE VIEW v_pr_item_summary AS
WITH po_agg AS (
  SELECT
    ppl.pr_item_id,
    SUM(COALESCE(ppl.converted_quantity, 0)) AS ordered_po_qty
  FROM pr_po_linkage ppl
  WHERE (ppl.status IS NULL OR ppl.status = 'active')
  GROUP BY ppl.pr_item_id
),
grn_agg AS (
  SELECT
    pri.id AS pr_item_id,
    pri.item_id,
    SUM(COALESCE(gii.received_quantity, 0)) AS received_grn_qty
  FROM purchase_request_items pri
  JOIN pr_po_linkage ppl ON ppl.pr_item_id = pri.id
  JOIN grn_inspections gi ON gi.purchase_order_id = ppl.po_id AND (gi.deleted IS NOT TRUE)
  JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id AND gii.item_id = pri.item_id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id, pri.item_id
),
pur_agg AS (
  SELECT
    pri.id AS pr_item_id,
    pri.item_id,
    SUM(COALESCE(pii.quantity, 0)) AS invoiced_pur_qty
  FROM purchase_request_items pri
  JOIN pr_po_linkage ppl ON ppl.pr_item_id = pri.id
  JOIN grn_inspections gi ON gi.purchase_order_id = ppl.po_id AND (gi.deleted IS NOT TRUE)
  JOIN purchasing_invoices pi ON pi.grn_id = gi.id AND (pi.deleted IS NOT TRUE)
  JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND pii.item_id = pri.item_id
  WHERE (pri.deleted IS NOT TRUE)
  GROUP BY pri.id, pri.item_id
)
SELECT
  pri.id AS pr_item_id,
  pri.pr_id,
  pri.item_id,
  COALESCE(pri.quantity, 0) AS pr_quantity,
  COALESCE(po_agg.ordered_po_qty, 0) AS ordered_po_qty,
  COALESCE(grn_agg.received_grn_qty, 0) AS received_grn_qty,
  COALESCE(pur_agg.invoiced_pur_qty, 0) AS invoiced_pur_qty
FROM purchase_request_items pri
LEFT JOIN po_agg ON po_agg.pr_item_id = pri.id
LEFT JOIN grn_agg ON grn_agg.pr_item_id = pri.id AND grn_agg.item_id = pri.item_id
LEFT JOIN pur_agg ON pur_agg.pr_item_id = pri.id AND pur_agg.item_id = pri.item_id
WHERE (pri.deleted IS NOT TRUE);

COMMENT ON VIEW v_pr_item_summary IS 'Per PR item: DB-aggregated ordered (PO from pr_po_linkage), received (GRN), invoiced (PUR). Use for PR detail item summary.';

-- ---------- 2) Sync quantity_ordered from pr_po_linkage and auto-close PR when fully ordered ----------
CREATE OR REPLACE FUNCTION fn_pr_po_linkage_sync_and_close()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_pr_id uuid;
  v_total_ordered numeric;
  v_total_pr numeric;
BEGIN
  v_pr_id := COALESCE(NEW.pr_id, OLD.pr_id);
  IF v_pr_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Sync quantity_ordered and quantity_remaining on purchase_request_items from pr_po_linkage
  -- quantity_remaining is a generated column (quantity - quantity_ordered); only set quantity_ordered
  UPDATE purchase_request_items pri
  SET quantity_ordered = sub.ordered_qty, updated_at = now()
  FROM (
    SELECT pr_item_id, SUM(COALESCE(converted_quantity, 0)) AS ordered_qty
    FROM pr_po_linkage
    WHERE pr_id = v_pr_id AND (status IS NULL OR status = 'active')
    GROUP BY pr_item_id
  ) sub
  WHERE pri.id = sub.pr_item_id AND pri.pr_id = v_pr_id AND (pri.deleted IS NOT TRUE);

  -- If sum(ordered) >= sum(PR quantity), set PR status = closed
  SELECT COALESCE(SUM(converted_quantity), 0) INTO v_total_ordered
  FROM pr_po_linkage WHERE pr_id = v_pr_id AND (status IS NULL OR status = 'active');

  SELECT COALESCE(SUM(quantity), 0) INTO v_total_pr
  FROM purchase_request_items WHERE pr_id = v_pr_id AND (deleted IS NOT TRUE);

  IF v_total_pr > 0 AND v_total_ordered >= v_total_pr THEN
    UPDATE purchase_requests SET status = 'closed', updated_at = now() WHERE id = v_pr_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_pr_po_linkage_sync_and_close ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_sync_and_close
  AFTER INSERT OR UPDATE OF converted_quantity, status OR DELETE ON pr_po_linkage
  FOR EACH ROW EXECUTE FUNCTION fn_pr_po_linkage_sync_and_close();

COMMENT ON FUNCTION fn_pr_po_linkage_sync_and_close IS 'Syncs quantity_ordered/quantity_remaining from pr_po_linkage; closes PR when sum(ordered) >= total.';

-- One-time backfill: set quantity_ordered/quantity_remaining from current pr_po_linkage for existing rows
UPDATE purchase_request_items pri
SET quantity_ordered = sub.ordered_qty, updated_at = now()
FROM (
  SELECT pr_item_id, SUM(COALESCE(converted_quantity, 0)) AS ordered_qty
  FROM pr_po_linkage WHERE (status IS NULL OR status = 'active')
  GROUP BY pr_item_id
) sub
WHERE pri.id = sub.pr_item_id AND (pri.deleted IS NOT TRUE)
  AND (COALESCE(pri.quantity_ordered, 0) <> sub.ordered_qty OR pri.quantity_ordered IS NULL);

-- Close PRs that are fully ordered
UPDATE purchase_requests pr
SET status = 'closed', updated_at = now()
WHERE pr.status IS DISTINCT FROM 'closed'
  AND EXISTS (
    SELECT 1 FROM (
      SELECT
        p.id,
        COALESCE(SUM(ppl.converted_quantity), 0) AS tot_ord,
        COALESCE(SUM(pri.quantity), 0) AS tot_pr
      FROM purchase_requests p
      LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = p.id AND (ppl.status IS NULL OR ppl.status = 'active')
      LEFT JOIN purchase_request_items pri ON pri.pr_id = p.id AND (pri.deleted IS NOT TRUE)
      WHERE p.id = pr.id
      GROUP BY p.id
    ) x
    WHERE x.tot_pr > 0 AND x.tot_ord >= x.tot_pr
  );
