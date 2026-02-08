-- ============================================================
-- SAP-LEVEL — PART 2: AUTO DOCUMENT CLOSING + PART 3: fn_can_create_next_document
-- PR→PO→GRN→PURCHASE→PAYMENT. Status = CLOSED when fully processed.
-- ============================================================

-- ---------- PART 3 first: fn_can_create_next_document(doc_type, doc_id) ----------
CREATE OR REPLACE FUNCTION fn_can_create_next_document(p_doc_type text, p_doc_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_remaining numeric;
  v_total_ordered numeric;
  v_total_received numeric;
  v_pr_id uuid;
  v_po_id bigint;
  v_grn_id uuid;
  v_inv_id uuid;
  v_paid numeric;
  v_total numeric;
BEGIN
  p_doc_type := UPPER(TRIM(p_doc_type));

  -- PR: can create PO if any item has quantity_remaining > 0
  IF p_doc_type = 'PR' THEN
    SELECT COALESCE(SUM(quantity_remaining), 0) INTO v_remaining
    FROM purchase_request_items WHERE pr_id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_remaining, 0) > 0;
  END IF;

  -- PO: can create GRN if remaining_quantity > 0
  IF p_doc_type = 'PO' THEN
    SELECT COALESCE(remaining_quantity, ordered_quantity - COALESCE(total_received_quantity, 0), 0)
    INTO v_remaining FROM purchase_orders WHERE id = (p_doc_id::bigint) AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_remaining, 0) > 0;
  END IF;

  -- GRN: can create Purchase if GRN not yet fully invoiced (simplified: status not CLOSED)
  IF p_doc_type = 'GRN' THEN
    SELECT 1 INTO v_remaining FROM grn_inspections WHERE id = p_doc_id::uuid AND (deleted IS NOT TRUE) AND status IS DISTINCT FROM 'closed';
    RETURN FOUND;
  END IF;

  -- PURCHASE (invoice): can create Payment if not fully paid
  IF p_doc_type IN ('PURCHASE', 'PUR', 'INVOICE') THEN
    SELECT COALESCE(paid_amount, 0), COALESCE(grand_total, total_amount, 0)
    INTO v_paid, v_total FROM purchasing_invoices WHERE id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_total, 0) > 0 AND COALESCE(v_paid, 0) < COALESCE(v_total, 0);
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION fn_can_create_next_document IS 'Returns true if next document in chain can be created (remaining qty > 0). Frontend must use this for button visibility.';

-- ---------- PART 2: Auto-close triggers ----------
-- PR: set status = CLOSED when all items quantity_remaining = 0
CREATE OR REPLACE FUNCTION fn_auto_close_pr_on_po_conversion()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_rem numeric;
BEGIN
  SELECT COALESCE(SUM(quantity_remaining), 0) INTO v_rem
  FROM purchase_request_items WHERE pr_id = COALESCE(NEW.pr_id, OLD.pr_id) AND (deleted IS NOT TRUE);
  IF COALESCE(v_rem, 0) <= 0 THEN
    UPDATE purchase_requests SET status = 'CLOSED', updated_at = now()
    WHERE id = COALESCE(NEW.pr_id, OLD.pr_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_pr_items_auto_close_pr ON purchase_request_items;
CREATE TRIGGER trg_pr_items_auto_close_pr
  AFTER INSERT OR UPDATE OF quantity_remaining, quantity_ordered ON purchase_request_items
  FOR EACH ROW EXECUTE FUNCTION fn_auto_close_pr_on_po_conversion();

-- PO: set status = CLOSED when remaining_quantity = 0 (AFTER update)
CREATE OR REPLACE FUNCTION fn_po_after_update_close()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF COALESCE(NEW.remaining_quantity, 0) <= 0 AND COALESCE(NEW.ordered_quantity, 0) > 0 THEN
    UPDATE purchase_orders SET status = 'CLOSED', receiving_status = 'CLOSED', updated_at = now() WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_po_auto_close_on_remaining ON purchase_orders;
DROP TRIGGER IF EXISTS trg_po_after_update_close ON purchase_orders;
CREATE TRIGGER trg_po_after_update_close
  AFTER UPDATE OF remaining_quantity, total_received_quantity ON purchase_orders
  FOR EACH ROW
  WHEN (COALESCE(NEW.remaining_quantity, 0) <= 0 AND COALESCE(OLD.remaining_quantity, 1) > 0)
  EXECUTE FUNCTION fn_po_after_update_close();

-- GRN: set status = CLOSED when linked invoice is fully paid or when marked closed (manual or by process)
CREATE OR REPLACE FUNCTION fn_auto_close_grn_on_purchase()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.payment_status = 'PAID' OR (COALESCE(NEW.paid_amount, 0) >= COALESCE(NEW.grand_total, NEW.total_amount, 0) AND NEW.grand_total IS NOT NULL) THEN
    UPDATE grn_inspections SET status = 'CLOSED', updated_at = now() WHERE id = NEW.grn_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_purchasing_invoice_auto_close_grn ON purchasing_invoices;
CREATE TRIGGER trg_purchasing_invoice_auto_close_grn
  AFTER INSERT OR UPDATE OF payment_status, paid_amount, grand_total ON purchasing_invoices
  FOR EACH ROW
  WHEN (NEW.grn_id IS NOT NULL)
  EXECUTE FUNCTION fn_auto_close_grn_on_purchase();

-- Purchasing invoice: set status = CLOSED when fully paid
CREATE OR REPLACE FUNCTION fn_auto_close_invoice_on_payment()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_paid numeric; v_total numeric;
BEGIN
  SELECT COALESCE(paid_amount, 0), COALESCE(grand_total, total_amount, 0) INTO v_paid, v_total
  FROM purchasing_invoices WHERE id = NEW.purchasing_invoice_id;
  IF COALESCE(v_total, 0) > 0 AND v_paid >= v_total THEN
    UPDATE purchasing_invoices SET status = 'CLOSED', payment_status = 'PAID', updated_at = now() WHERE id = NEW.purchasing_invoice_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ap_payment_auto_close_invoice ON ap_payments;
CREATE TRIGGER trg_ap_payment_auto_close_invoice
  AFTER INSERT ON ap_payments
  FOR EACH ROW EXECUTE FUNCTION fn_auto_close_invoice_on_payment();

-- Also trigger on finance_payments if it links to purchasing_invoice_id
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'finance_payments' AND column_name = 'purchasing_invoice_id') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_finance_payment_auto_close_invoice ON finance_payments';
    EXECUTE 'CREATE TRIGGER trg_finance_payment_auto_close_invoice AFTER INSERT ON finance_payments FOR EACH ROW EXECUTE FUNCTION fn_auto_close_invoice_on_payment()';
  END IF;
END$$;
