-- BUSINESS LOGIC HARDENING: Document state control
-- 1) fn_can_create_next_document: PR = false if status CLOSED or has linked PO; GRN = false if CLOSED or has purchasing invoice
-- 2) Trigger on purchasing_invoices: block duplicate INSERT for same grn_id

-- ---------- 1) fn_can_create_next_document: strict document state ----------
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
  v_pr_status text;
  v_grn_status text;
  v_has_link boolean;
  v_has_invoice boolean;
BEGIN
  p_doc_type := UPPER(TRIM(COALESCE(p_doc_type, '')));
  IF p_doc_id IS NULL OR TRIM(p_doc_id) = '' THEN
    RETURN false;
  END IF;

  -- PR: can create PO only if status is not CLOSED and no linked PO exists
  IF p_doc_type = 'PR' THEN
    SELECT status INTO v_pr_status FROM purchase_requests WHERE id = p_doc_id::uuid;
    IF v_pr_status IS NULL THEN
      RETURN false;
    END IF;
    IF LOWER(TRIM(v_pr_status)) = 'closed' THEN
      RETURN false;
    END IF;
    SELECT EXISTS (SELECT 1 FROM pr_po_linkage WHERE pr_id = p_doc_id::uuid LIMIT 1) INTO v_has_link;
    IF v_has_link THEN
      RETURN false;
    END IF;
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

  -- GRN: can create Purchase only if status is not CLOSED and no purchasing invoice exists for this GRN
  IF p_doc_type = 'GRN' THEN
    SELECT status INTO v_grn_status FROM grn_inspections WHERE id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    IF v_grn_status IS NULL THEN
      RETURN false;
    END IF;
    IF LOWER(TRIM(v_grn_status)) IN ('closed') THEN
      RETURN false;
    END IF;
    SELECT EXISTS (SELECT 1 FROM purchasing_invoices WHERE grn_id = p_doc_id::uuid AND (deleted IS NOT TRUE) LIMIT 1) INTO v_has_invoice;
    IF v_has_invoice THEN
      RETURN false;
    END IF;
    RETURN true;
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

COMMENT ON FUNCTION fn_can_create_next_document IS 'Document state control: PR=false if closed or has linked PO; GRN=false if closed or has purchasing invoice. Frontend button visibility + backend enforcement.';

-- ---------- 2) Trigger: prevent duplicate purchasing invoice per GRN ----------
CREATE OR REPLACE FUNCTION fn_prevent_duplicate_purchasing_per_grn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.grn_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM purchasing_invoices WHERE grn_id = NEW.grn_id AND (deleted IS NOT TRUE) AND id IS DISTINCT FROM NEW.id) THEN
      RAISE EXCEPTION 'Purchasing invoice already exists for this GRN. Duplicate creation is not allowed.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_purchasing_per_grn ON purchasing_invoices;
CREATE TRIGGER trg_prevent_duplicate_purchasing_per_grn
  BEFORE INSERT OR UPDATE OF grn_id ON purchasing_invoices
  FOR EACH ROW
  WHEN (NEW.grn_id IS NOT NULL)
  EXECUTE FUNCTION fn_prevent_duplicate_purchasing_per_grn();

COMMENT ON FUNCTION fn_prevent_duplicate_purchasing_per_grn IS 'Enforces one purchasing invoice per GRN; blocks duplicate at DB level.';
