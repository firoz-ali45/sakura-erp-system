-- Ensure fn_can_create_next_document runs as definer so client always gets correct result (RLS bypass for document state)
CREATE OR REPLACE FUNCTION public.fn_can_create_next_document(p_doc_type text, p_doc_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_remaining numeric;
  v_pr_status text;
  v_grn_status text;
  v_has_link boolean;
  v_has_invoice boolean;
  v_paid numeric;
  v_total numeric;
BEGIN
  p_doc_type := UPPER(TRIM(COALESCE(p_doc_type, '')));
  IF p_doc_id IS NULL OR TRIM(p_doc_id) = '' THEN
    RETURN false;
  END IF;

  IF p_doc_type = 'PR' THEN
    SELECT status INTO v_pr_status FROM purchase_requests WHERE id = p_doc_id::uuid;
    IF v_pr_status IS NULL THEN RETURN false; END IF;
    IF LOWER(TRIM(v_pr_status)) = 'closed' THEN RETURN false; END IF;
    SELECT EXISTS (SELECT 1 FROM pr_po_linkage WHERE pr_id = p_doc_id::uuid LIMIT 1) INTO v_has_link;
    IF v_has_link THEN RETURN false; END IF;
    SELECT COALESCE(SUM(quantity_remaining), 0) INTO v_remaining
    FROM purchase_request_items WHERE pr_id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_remaining, 0) > 0;
  END IF;

  IF p_doc_type = 'PO' THEN
    SELECT COALESCE(remaining_quantity, ordered_quantity - COALESCE(total_received_quantity, 0), 0)
    INTO v_remaining FROM purchase_orders WHERE id = (p_doc_id::bigint) AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_remaining, 0) > 0;
  END IF;

  IF p_doc_type = 'GRN' THEN
    SELECT status INTO v_grn_status FROM grn_inspections WHERE id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    IF v_grn_status IS NULL THEN RETURN false; END IF;
    IF LOWER(TRIM(v_grn_status)) IN ('closed') THEN RETURN false; END IF;
    SELECT EXISTS (SELECT 1 FROM purchasing_invoices WHERE grn_id = p_doc_id::uuid AND (deleted IS NOT TRUE) LIMIT 1) INTO v_has_invoice;
    IF v_has_invoice THEN RETURN false; END IF;
    RETURN true;
  END IF;

  IF p_doc_type IN ('PURCHASE', 'PUR', 'INVOICE') THEN
    SELECT COALESCE(paid_amount, 0), COALESCE(grand_total, total_amount, 0)
    INTO v_paid, v_total FROM purchasing_invoices WHERE id = p_doc_id::uuid AND (deleted IS NOT TRUE);
    RETURN COALESCE(v_total, 0) > 0 AND COALESCE(v_paid, 0) < COALESCE(v_total, 0);
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.fn_can_create_next_document(text, text) IS 'Document state: PR=false if closed or has linked PO; GRN=false if closed or has purchasing. SECURITY DEFINER so client gets correct visibility.';
