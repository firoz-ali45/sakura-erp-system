-- RESET operational data for ONE company (inventory, ledger, batches, GRN, PR/PO, transfers, production).
-- Does NOT delete: users, companies, suppliers, categories, branches.
--
-- Supabase → SQL Editor (backup first):
--   SELECT id, name FROM public.companies;
--   CALL public.reset_company_inventory_and_procurement('<company-uuid>'::uuid);

CREATE OR REPLACE PROCEDURE public.reset_company_inventory_and_procurement(p_company_id uuid)
LANGUAGE plpgsql
AS $proc$
DECLARE
  v_c uuid := p_company_id;
BEGIN
  IF v_c IS NULL THEN
    RAISE EXCEPTION 'p_company_id is required.';
  END IF;

  IF to_regclass('public.inventory_stock_ledger') IS NOT NULL THEN
    DELETE FROM public.inventory_stock_ledger l
    WHERE l.company_id = v_c
       OR EXISTS (SELECT 1 FROM public.inventory_items i WHERE i.id = l.item_id AND i.company_id = v_c);
  END IF;

  IF to_regclass('public.inventory_stock_ledger_legacy') IS NOT NULL THEN
    DELETE FROM public.inventory_stock_ledger_legacy l
    WHERE EXISTS (SELECT 1 FROM public.inventory_items i WHERE i.id = l.item_id AND i.company_id = v_c);
  END IF;

  IF to_regclass('public.fg_batches') IS NOT NULL THEN
    DELETE FROM public.fg_batches fg WHERE fg.company_id = v_c;
  END IF;
  IF to_regclass('public.wip_lots') IS NOT NULL THEN
    DELETE FROM public.wip_lots wl WHERE wl.company_id = v_c;
  END IF;
  IF to_regclass('public.production_consumption') IS NOT NULL THEN
    DELETE FROM public.production_consumption pc WHERE pc.company_id = v_c;
  END IF;
  IF to_regclass('public.production_items') IS NOT NULL THEN
    DELETE FROM public.production_items pi WHERE pi.company_id = v_c;
  END IF;
  IF to_regclass('public.production_orders') IS NOT NULL THEN
    DELETE FROM public.production_orders po WHERE po.company_id = v_c;
  END IF;

  IF to_regclass('public.recipe_ingredients') IS NOT NULL THEN
    DELETE FROM public.recipe_ingredients ri WHERE ri.company_id = v_c;
  END IF;
  IF to_regclass('public.recipes') IS NOT NULL THEN
    DELETE FROM public.recipes r WHERE r.company_id = v_c;
  END IF;

  IF to_regclass('public.stock_transfer_items') IS NOT NULL THEN
    DELETE FROM public.stock_transfer_items sti
    WHERE EXISTS (SELECT 1 FROM public.inventory_items i WHERE i.id = sti.item_id AND i.company_id = v_c);
  END IF;
  IF to_regclass('public.stock_transfers') IS NOT NULL THEN
    DELETE FROM public.stock_transfers st
    WHERE NOT EXISTS (SELECT 1 FROM public.stock_transfer_items x WHERE x.stock_transfer_id = st.id);
  END IF;

  IF to_regclass('public.transfer_order_items') IS NOT NULL THEN
    DELETE FROM public.transfer_order_items toi
    USING public.inventory_items i
    WHERE toi.item_id = i.id AND i.company_id = v_c;
  END IF;
  IF to_regclass('public.transfer_approvals') IS NOT NULL THEN
    DELETE FROM public.transfer_approvals ta
    WHERE NOT EXISTS (
      SELECT 1 FROM public.transfer_order_items x WHERE x.transfer_order_id = ta.transfer_id
    );
  END IF;
  IF to_regclass('public.transfer_dispatches') IS NOT NULL THEN
    DELETE FROM public.transfer_dispatches td
    WHERE NOT EXISTS (
      SELECT 1 FROM public.transfer_order_items x WHERE x.transfer_order_id = td.transfer_id
    );
  END IF;
  IF to_regclass('public.transfer_receipts') IS NOT NULL THEN
    DELETE FROM public.transfer_receipts tr
    WHERE NOT EXISTS (
      SELECT 1 FROM public.transfer_order_items x WHERE x.transfer_order_id = tr.transfer_id
    );
  END IF;
  IF to_regclass('public.transfer_orders') IS NOT NULL THEN
    DELETE FROM public.transfer_orders t
    WHERE NOT EXISTS (SELECT 1 FROM public.transfer_order_items x WHERE x.transfer_order_id = t.id);
  END IF;

  IF to_regclass('public.pr_po_linkage') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'pr_po_linkage' AND column_name = 'po_id'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'pr_po_linkage' AND column_name = 'pr_id'
    ) THEN
      DELETE FROM public.pr_po_linkage l
      WHERE EXISTS (SELECT 1 FROM public.purchase_orders po WHERE po.id = l.po_id AND po.company_id = v_c)
         OR EXISTS (
           SELECT 1 FROM public.purchase_requests pr
           JOIN public.users u ON u.id = pr.requester_id
           WHERE pr.id = l.pr_id AND u.company_id = v_c
         );
    ELSE
      DELETE FROM public.pr_po_linkage;
    END IF;
  END IF;

  IF to_regclass('public.po_receipt_history') IS NOT NULL THEN
    DELETE FROM public.po_receipt_history h
    WHERE EXISTS (
      SELECT 1 FROM public.purchase_orders po
      WHERE po.id = h.purchase_order_id AND po.company_id = v_c
    );
  END IF;

  IF to_regclass('public.purchasing_invoice_items') IS NOT NULL THEN
    DELETE FROM public.purchasing_invoice_items pii
    USING public.purchasing_invoices pi
    WHERE pii.purchasing_invoice_id = pi.id
      AND (
        EXISTS (
          SELECT 1 FROM public.purchase_orders po
          WHERE po.id = pi.purchase_order_id AND po.company_id = v_c
        )
        OR EXISTS (
          SELECT 1 FROM public.inventory_items i
          WHERE i.id = pii.item_id AND i.company_id = v_c
        )
      );
  END IF;
  IF to_regclass('public.purchasing_invoices') IS NOT NULL THEN
    DELETE FROM public.purchasing_invoices pi
    WHERE EXISTS (
      SELECT 1 FROM public.purchase_orders po
      WHERE po.id = pi.purchase_order_id AND po.company_id = v_c
    )
    OR EXISTS (
      SELECT 1 FROM public.purchasing_invoice_items pii
      JOIN public.inventory_items i ON i.id = pii.item_id
      WHERE pii.purchasing_invoice_id = pi.id AND i.company_id = v_c
    );
  END IF;

  -- GRN before purchase_orders (FK from grn_inspections → purchase_orders)
  IF to_regclass('public.grn_inspection_items') IS NOT NULL THEN
    DELETE FROM public.grn_inspection_items gii
    USING public.inventory_items i
    WHERE gii.item_id = i.id AND i.company_id = v_c;
  END IF;
  IF to_regclass('public.grn_inspections') IS NOT NULL THEN
    DELETE FROM public.grn_inspections g
    WHERE g.purchase_order_id IN (SELECT po.id FROM public.purchase_orders po WHERE po.company_id = v_c);
    DELETE FROM public.grn_inspections g2
    WHERE NOT EXISTS (
      SELECT 1 FROM public.grn_inspection_items x WHERE x.grn_inspection_id = g2.id
    );
  END IF;

  IF to_regclass('public.purchase_order_items') IS NOT NULL THEN
    DELETE FROM public.purchase_order_items poi
    USING public.purchase_orders po
    WHERE poi.purchase_order_id = po.id AND po.company_id = v_c;
  END IF;
  IF to_regclass('public.purchase_orders') IS NOT NULL THEN
    DELETE FROM public.purchase_orders po WHERE po.company_id = v_c;
  END IF;

  IF to_regclass('public.purchase_request_items') IS NOT NULL THEN
    DELETE FROM public.purchase_request_items pri
    USING public.purchase_requests pr
    WHERE pri.pr_id = pr.id
      AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = pr.requester_id AND u.company_id = v_c);
  END IF;
  IF to_regclass('public.purchase_requests') IS NOT NULL THEN
    DELETE FROM public.purchase_requests pr
    WHERE EXISTS (SELECT 1 FROM public.users u WHERE u.id = pr.requester_id AND u.company_id = v_c);
  END IF;

  IF to_regclass('public.batches') IS NOT NULL THEN
    DELETE FROM public.batches b WHERE b.company_id = v_c;
  END IF;

  IF to_regclass('public.inventory_count_items') IS NOT NULL THEN
    DELETE FROM public.inventory_count_items ici
    USING public.inventory_items i
    WHERE ici.item_id = i.id AND i.company_id = v_c;
  END IF;
  IF to_regclass('public.inventory_counts') IS NOT NULL THEN
    DELETE FROM public.inventory_counts ic
    WHERE NOT EXISTS (SELECT 1 FROM public.inventory_count_items x WHERE x.inventory_count_id = ic.id);
  END IF;

  IF to_regclass('public.inventory_items') IS NOT NULL THEN
    DELETE FROM public.inventory_items ii WHERE ii.company_id = v_c;
  END IF;

  IF to_regclass('public.production_number_sequence') IS NOT NULL THEN
    UPDATE public.production_number_sequence
    SET next_val = 1,
        year_val = EXTRACT(year FROM CURRENT_DATE)::int
    WHERE id = 1;
  END IF;

  RAISE NOTICE 'reset_company_inventory_and_procurement completed for company %', v_c;
END;
$proc$;
