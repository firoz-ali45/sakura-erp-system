-- ============================================================================
-- 01_COMPLETE_DOCUMENT_FLOW_FIX.sql
-- RUN THIS ONE FILE — Fixes broken Document Flow (PR→PO→GRN→PUR)
-- ============================================================================
-- ROOT CAUSE: grn_inspections.purchase_order_id & purchasing_invoices.purchase_order_id
-- are often NULL while purchase_order_number is populated. Graph could not traverse.
-- ============================================================================

-- ============================================================================
-- STEP 0: FIX NULL purchase_order_id (use po_number to lookup)
-- ============================================================================

UPDATE grn_inspections gi
SET purchase_order_id = po.id
FROM purchase_orders po
WHERE gi.purchase_order_id IS NULL
  AND gi.purchase_order_number IS NOT NULL
  AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)
  AND (gi.deleted IS NOT TRUE)
  AND (po.deleted IS NOT TRUE);

UPDATE purchasing_invoices pi
SET purchase_order_id = po.id
FROM purchase_orders po
WHERE pi.purchase_order_id IS NULL
  AND pi.purchase_order_number IS NOT NULL
  AND TRIM(pi.purchase_order_number) = TRIM(po.po_number)
  AND (pi.deleted IS NOT TRUE)
  AND (po.deleted IS NOT TRUE);

-- ============================================================================
-- STEP 0.5: BACKFILL pr_po_linkage (from purchase_request_items.po_id if column exists)
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchase_request_items' AND column_name = 'po_id') THEN
    INSERT INTO pr_po_linkage (pr_id, pr_number, pr_item_id, pr_item_number, po_id, po_number, pr_quantity, converted_quantity, remaining_quantity, unit, conversion_type, status, converted_at)
    SELECT pri.pr_id, pr.pr_number, pri.id, pri.item_number, pri.po_id, po.po_number,
           COALESCE(pri.quantity, 0), COALESCE(pri.quantity, 0), 0, COALESCE(pri.unit, 'EA'), 'full', 'active', NOW()
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id
    JOIN purchase_orders po ON po.id = pri.po_id
    WHERE pri.po_id IS NOT NULL
      AND (pri.deleted IS NOT TRUE)
      AND (pr.deleted IS NOT TRUE)
      AND (po.deleted IS NOT TRUE)
      AND NOT EXISTS (SELECT 1 FROM pr_po_linkage ppl WHERE ppl.pr_item_id = pri.id AND ppl.po_id = pri.po_id);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL; -- Skip if table/column structure differs
END $$;

-- ============================================================================
-- STEP 0.6: BACKFILL pr_po_linkage BY ITEM MATCHING (when po_id is NULL in pri)
-- Links PR↔PO by matching purchase_order_items to purchase_request_items (item_id or item_name)
-- ============================================================================
DO $$
BEGIN
  INSERT INTO pr_po_linkage (pr_id, pr_number, pr_item_id, pr_item_number, po_id, po_number, pr_quantity, converted_quantity, remaining_quantity, unit, conversion_type, status, converted_at)
  SELECT pri.pr_id, pr.pr_number, pri.id, pri.item_number, poi.purchase_order_id AS po_id, po.po_number,
    COALESCE(pri.quantity, 0), COALESCE(pri.quantity, 0), 0, COALESCE(pri.unit, 'EA'), 'full', 'active', NOW()
  FROM purchase_request_items pri
  JOIN purchase_requests pr ON pr.id = pri.pr_id
  JOIN purchase_order_items poi ON (poi.item_id = pri.item_id OR (poi.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND (TRIM(poi.item_name) = TRIM(pri.item_name) OR LOWER(poi.item_name) LIKE '%' || LOWER(SUBSTRING(pri.item_name, 1, 25)) || '%')))
  JOIN purchase_orders po ON po.id = poi.purchase_order_id
  WHERE (pri.deleted IS NOT TRUE)
    AND (pr.deleted IS NOT TRUE)
    AND (po.deleted IS NOT TRUE)
    AND pr.status IN ('approved', 'partially_ordered', 'fully_ordered', 'submitted', 'draft')
    AND NOT EXISTS (SELECT 1 FROM pr_po_linkage ppl WHERE ppl.pr_item_id = pri.id AND ppl.po_id = poi.purchase_order_id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'STEP 0.6 item-matching backfill skipped: %', SQLERRM;
END $$;

-- ============================================================================
-- STEP 0.7: BACKFILL pr_po_linkage FROM GRN/PO PATH (PR page forward trace fix)
-- For each PO that has GRN/PUR, find PRs via item_id match and ensure linkage exists
-- ============================================================================
DO $$
BEGIN
  INSERT INTO pr_po_linkage (pr_id, pr_number, pr_item_id, pr_item_number, po_id, po_number, pr_quantity, converted_quantity, remaining_quantity, unit, conversion_type, status, converted_at)
  SELECT pri.pr_id, pr.pr_number, pri.id, pri.item_number, po.id AS po_id, po.po_number,
    COALESCE(pri.quantity, 0), COALESCE(pri.quantity, 0), 0, COALESCE(pri.unit, 'EA'), 'full', 'active', NOW()
  FROM purchase_orders po
  JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
  JOIN purchase_request_items pri ON (pri.item_id = poi.item_id OR (pri.item_name IS NOT NULL AND poi.item_name IS NOT NULL AND (TRIM(pri.item_name) = TRIM(poi.item_name) OR LOWER(pri.item_name) LIKE '%' || LOWER(SUBSTRING(poi.item_name, 1, 30)) || '%')))
  JOIN purchase_requests pr ON pr.id = pri.pr_id
  WHERE (po.deleted IS NOT TRUE)
    AND (pr.deleted IS NOT TRUE)
    AND (pri.deleted IS NOT TRUE)
    AND (EXISTS (SELECT 1 FROM grn_inspections gi WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number))) AND (gi.deleted IS NOT TRUE))
         OR EXISTS (SELECT 1 FROM purchasing_invoices pi WHERE (pi.purchase_order_id = po.id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number)))) AND (pi.deleted IS NOT TRUE)))
    AND NOT EXISTS (SELECT 1 FROM pr_po_linkage ppl WHERE ppl.pr_item_id = pri.id AND ppl.po_id = po.id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'STEP 0.7 GRN-path backfill skipped: %', SQLERRM;
END $$;

-- ============================================================================
-- STEP 1: doc_graph TABLE + UNIQUE INDEX
-- ============================================================================

CREATE TABLE IF NOT EXISTS doc_graph (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type TEXT NOT NULL,
    source_id TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_doc_graph_unique ON doc_graph(source_type, source_id, target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_doc_graph_source ON doc_graph(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_doc_graph_target ON doc_graph(target_type, target_id);

-- ============================================================================
-- STEP 2: BACKFILL doc_graph (PR→PO, PO→GRN, GRN→PUR, PO→PUR)
-- Include number-based fallback where purchase_order_id was null
-- ============================================================================

INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'PR', ppl.pr_id::TEXT, 'PO', ppl.po_id::TEXT
FROM pr_po_linkage ppl
WHERE ppl.status = 'active' OR ppl.status IS NULL
ON CONFLICT DO NOTHING;

INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'PO', COALESCE(gi.purchase_order_id, po.id)::TEXT, 'GRN', gi.id::TEXT
FROM grn_inspections gi
LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(gi.purchase_order_number) AND (po.deleted = FALSE OR po.deleted IS NULL)
WHERE (gi.purchase_order_id IS NOT NULL OR po.id IS NOT NULL)
  AND (gi.deleted = FALSE OR gi.deleted IS NULL)
ON CONFLICT DO NOTHING;

INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'GRN', pi.grn_id::TEXT, 'PUR', pi.id::TEXT
FROM purchasing_invoices pi
WHERE pi.grn_id IS NOT NULL AND (pi.deleted = FALSE OR pi.deleted IS NULL)
ON CONFLICT DO NOTHING;

INSERT INTO doc_graph(source_type, source_id, target_type, target_id)
SELECT 'PO', COALESCE(pi.purchase_order_id, po.id)::TEXT, 'PUR', pi.id::TEXT
FROM purchasing_invoices pi
LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(pi.purchase_order_number) AND (po.deleted = FALSE OR po.deleted IS NULL)
WHERE (pi.purchase_order_id IS NOT NULL OR po.id IS NOT NULL)
  AND (pi.deleted = FALSE OR pi.deleted IS NULL)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 3: fn_trace_graph — RELATIONAL + doc_graph HYBRID
-- Uses direct table joins so works even when doc_graph is incomplete.
-- Returns { pr: {id, pr_number, status}, po: {...}, grn: {...}, pur: {...} }
-- ============================================================================

DROP FUNCTION IF EXISTS fn_trace_graph(TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_trace_graph(input_type TEXT, input_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_type TEXT := UPPER(TRIM(COALESCE(input_type, '')));
    v_id TEXT := NULLIF(TRIM(input_id), '');
    v_pr_id UUID; v_po_id BIGINT; v_grn_id UUID; v_pur_id UUID;
    v_result JSONB;
BEGIN
    v_type := CASE v_type
        WHEN 'PURCHASE_REQUEST' THEN 'PR'
        WHEN 'PURCHASE_ORDER' THEN 'PO'
        WHEN 'GOODS_RECEIPT' THEN 'GRN'
        WHEN 'GR' THEN 'GRN'
        WHEN 'INVOICE' THEN 'PUR'
        WHEN 'INV' THEN 'PUR'
        WHEN 'PURCHASING' THEN 'PUR'
        ELSE v_type
    END;

    IF v_type NOT IN ('PR', 'PO', 'GRN', 'PUR') OR v_id IS NULL OR v_id = '' THEN
        RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
    END IF;

    -- Resolve IDs from any starting point (uses ID + number fallback)
    IF v_type = 'PR' THEN
        v_pr_id := v_id::UUID;
        SELECT po_id INTO v_po_id FROM pr_po_linkage WHERE pr_id = v_pr_id AND (status = 'active' OR status IS NULL) LIMIT 1;
    ELSIF v_type = 'PO' THEN
        v_po_id := v_id::BIGINT;
        SELECT pr_id INTO v_pr_id FROM pr_po_linkage WHERE po_id = v_po_id AND (status = 'active' OR status IS NULL) LIMIT 1;
    ELSIF v_type = 'GRN' THEN
        v_grn_id := v_id::UUID;
        SELECT COALESCE(gi.purchase_order_id, po.id) INTO v_po_id
        FROM grn_inspections gi
        LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(gi.purchase_order_number) AND (po.deleted IS NOT TRUE)
        WHERE gi.id = v_grn_id AND (gi.deleted IS NOT TRUE);
        IF v_po_id IS NOT NULL THEN
            SELECT pr_id INTO v_pr_id FROM pr_po_linkage WHERE po_id = v_po_id AND (status = 'active' OR status IS NULL) LIMIT 1;
        END IF;
        SELECT id INTO v_pur_id FROM purchasing_invoices WHERE grn_id = v_grn_id AND (deleted IS NOT TRUE) LIMIT 1;
    ELSIF v_type = 'PUR' THEN
        v_pur_id := v_id::UUID;
        SELECT grn_id INTO v_grn_id FROM purchasing_invoices WHERE id = v_pur_id AND (deleted IS NOT TRUE);
        SELECT COALESCE(pi.purchase_order_id, po.id) INTO v_po_id
        FROM purchasing_invoices pi
        LEFT JOIN purchase_orders po ON TRIM(po.po_number) = TRIM(pi.purchase_order_number) AND (po.deleted IS NOT TRUE)
        WHERE pi.id = v_pur_id AND (pi.deleted IS NOT TRUE);
        -- CRITICAL: If PO still NULL, get it via GRN (PUR→GRN→PO)
        IF v_po_id IS NULL AND v_grn_id IS NOT NULL THEN
            SELECT COALESCE(gi.purchase_order_id, po2.id) INTO v_po_id
            FROM grn_inspections gi
            LEFT JOIN purchase_orders po2 ON TRIM(po2.po_number) = TRIM(gi.purchase_order_number) AND (po2.deleted IS NOT TRUE)
            WHERE gi.id = v_grn_id AND (gi.deleted IS NOT TRUE);
        END IF;
        IF v_po_id IS NOT NULL THEN
            SELECT pr_id INTO v_pr_id FROM pr_po_linkage WHERE po_id = v_po_id AND (status = 'active' OR status IS NULL) LIMIT 1;
        END IF;
        IF v_grn_id IS NULL AND v_po_id IS NOT NULL THEN
            SELECT id INTO v_grn_id FROM grn_inspections
            WHERE (purchase_order_id = v_po_id OR purchase_order_number IN (SELECT po_number FROM purchase_orders WHERE id = v_po_id))
              AND (deleted IS NOT TRUE) LIMIT 1;
        END IF;
    END IF;

    -- From PR/PO: get PO if missing
    IF v_pr_id IS NOT NULL AND v_po_id IS NULL THEN
        SELECT po_id INTO v_po_id FROM pr_po_linkage WHERE pr_id = v_pr_id AND (status = 'active' OR status IS NULL) LIMIT 1;
    END IF;
    -- From PO: get GRN, PUR
    IF v_po_id IS NOT NULL THEN
        IF v_grn_id IS NULL THEN
            SELECT id INTO v_grn_id FROM grn_inspections
            WHERE (purchase_order_id = v_po_id OR (purchase_order_number IS NOT NULL AND purchase_order_number IN (SELECT po_number FROM purchase_orders WHERE id = v_po_id)))
              AND (deleted IS NOT TRUE) LIMIT 1;
        END IF;
        IF v_pur_id IS NULL AND v_grn_id IS NOT NULL THEN
            SELECT id INTO v_pur_id FROM purchasing_invoices WHERE grn_id = v_grn_id AND (deleted IS NOT TRUE) LIMIT 1;
        END IF;
        IF v_pur_id IS NULL THEN
            SELECT id INTO v_pur_id FROM purchasing_invoices
            WHERE (purchase_order_id = v_po_id OR (purchase_order_number IS NOT NULL AND purchase_order_number IN (SELECT po_number FROM purchase_orders WHERE id = v_po_id)))
              AND (deleted IS NOT TRUE) LIMIT 1;
        END IF;
    END IF;
    -- From GRN: get PUR if missing
    IF v_grn_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id INTO v_pur_id FROM purchasing_invoices WHERE grn_id = v_grn_id AND (deleted IS NOT TRUE) LIMIT 1;
    END IF;

    -- CRITICAL: Always include the INPUT document (current page) — fixes PR/PO/GRN/PUR showing "Not Created"
    IF v_type = 'PR' THEN v_pr_id := COALESCE(v_pr_id, v_id::UUID); END IF;
    IF v_type = 'PO' THEN v_po_id := COALESCE(v_po_id, v_id::BIGINT); END IF;
    IF v_type = 'GRN' THEN v_grn_id := COALESCE(v_grn_id, v_id::UUID); END IF;
    IF v_type = 'PUR' THEN v_pur_id := COALESCE(v_pur_id, v_id::UUID); END IF;

    -- Build JSON with full doc info for UI (use deleted IS NOT TRUE to be inclusive)
    SELECT jsonb_build_object(
        'pr', (SELECT jsonb_build_object('id', id, 'pr_number', pr_number, 'status', status)
               FROM purchase_requests WHERE id = v_pr_id AND (deleted IS NOT TRUE)),
        'po', (SELECT jsonb_build_object('id', id, 'po_number', po_number, 'status', status)
               FROM purchase_orders WHERE id = v_po_id AND (deleted IS NOT TRUE)),
        'grn', (SELECT jsonb_build_object('id', id, 'grn_number', grn_number, 'status', status)
                FROM grn_inspections WHERE id = v_grn_id AND (deleted IS NOT TRUE)),
        'pur', (SELECT jsonb_build_object('id', id, 'purchasing_number', COALESCE(purchasing_number, 'PUR-' || id::TEXT), 'status', status)
                FROM purchasing_invoices WHERE id = v_pur_id AND (deleted IS NOT TRUE))
    ) INTO v_result;

    RETURN COALESCE(v_result, jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL));
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('pr', NULL, 'po', NULL, 'grn', NULL, 'pur', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trace_graph(TEXT, TEXT) TO authenticated, anon;

-- ============================================================================
-- STEP 4: ITEM-WISE DOCUMENT FLOW (SAP EKBE STYLE)
-- ============================================================================

DROP VIEW IF EXISTS v_item_flow_recursive CASCADE;
DROP VIEW IF EXISTS v_item_transaction_flow CASCADE;

CREATE OR REPLACE VIEW v_item_transaction_flow AS
WITH
pr_items AS (
    SELECT pri.id AS pr_item_id, pri.pr_id, pr.pr_number, pri.item_number AS pr_pos,
           pri.item_id, pri.item_name, pri.item_code, COALESCE(pri.quantity, 0) AS pr_qty, pri.unit, pri.estimated_price AS pr_price
    FROM purchase_request_items pri
    JOIN purchase_requests pr ON pr.id = pri.pr_id AND (pr.deleted IS NOT TRUE)
    WHERE (pri.deleted IS NOT TRUE)
),
po_quantities AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(ppl.converted_quantity, 0)) AS po_qty,
           STRING_AGG(DISTINCT ppl.po_number, ', ' ORDER BY ppl.po_number) AS po_numbers
    FROM pr_po_linkage ppl
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
grn_quantities AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(gii.received_quantity, 0)) AS grn_qty,
           STRING_AGG(DISTINCT gi.grn_number, ', ' ORDER BY gi.grn_number) AS grn_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_order_items poi ON poi.purchase_order_id = ppl.po_id
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchase_orders po2 ON po2.id = ppl.po_id
    JOIN grn_inspections gi ON (gi.purchase_order_id = ppl.po_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po2.po_number)))
        AND (gi.deleted IS NOT TRUE)
    JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id AND (gii.item_id = pri.item_id OR (gii.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(gii.item_name) = TRIM(pri.item_name)))
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
),
pur_quantities AS (
    SELECT ppl.pr_item_id, SUM(COALESCE(pii.quantity, 0)) AS pur_qty,
           STRING_AGG(DISTINCT pi.purchasing_number, ', ' ORDER BY pi.purchasing_number) AS pur_numbers
    FROM pr_po_linkage ppl
    JOIN purchase_request_items pri ON pri.id = ppl.pr_item_id
    JOIN purchasing_invoices pi ON (pi.deleted IS NOT TRUE)
        AND (pi.purchase_order_id = ppl.po_id
             OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = ppl.po_id
                              OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = (SELECT TRIM(po_number) FROM purchase_orders WHERE id = ppl.po_id LIMIT 1))))
    JOIN purchasing_invoice_items pii ON pii.purchasing_invoice_id = pi.id AND (pii.item_id = pri.item_id OR pii.item_name = pri.item_name)
    WHERE (ppl.status = 'active' OR ppl.status IS NULL)
    GROUP BY ppl.pr_item_id
)
SELECT p.pr_item_id, p.pr_id, p.pr_number, p.pr_pos, p.item_id, p.item_name, p.item_code, p.unit, p.pr_price,
       p.pr_qty, COALESCE(po.po_qty, 0) AS po_qty, COALESCE(grn.grn_qty, 0) AS grn_qty, COALESCE(pur.pur_qty, 0) AS pur_qty,
       GREATEST(0, p.pr_qty - COALESCE(po.po_qty, 0)) AS remaining_pr,
       GREATEST(0, COALESCE(po.po_qty, 0) - COALESCE(grn.grn_qty, 0)) AS remaining_po,
       GREATEST(0, COALESCE(grn.grn_qty, 0) - COALESCE(pur.pur_qty, 0)) AS remaining_grn,
       CASE WHEN COALESCE(po.po_qty, 0) = 0 THEN 'Pending'
            WHEN COALESCE(grn.grn_qty, 0) = 0 THEN 'Ordered'
            WHEN COALESCE(grn.grn_qty, 0) < COALESCE(po.po_qty, 0) THEN 'Partial Received'
            WHEN COALESCE(pur.pur_qty, 0) = 0 THEN 'Fully Received'
            ELSE 'Invoiced' END AS chain_status,
       COALESCE(po.po_numbers, '') AS po_numbers, COALESCE(grn.grn_numbers, '') AS grn_numbers, COALESCE(pur.pur_numbers, '') AS pur_numbers
FROM pr_items p
LEFT JOIN po_quantities po ON po.pr_item_id = p.pr_item_id
LEFT JOIN grn_quantities grn ON grn.pr_item_id = p.pr_item_id
LEFT JOIN pur_quantities pur ON pur.pr_item_id = p.pr_item_id;

CREATE OR REPLACE VIEW v_item_flow_recursive AS SELECT * FROM v_item_transaction_flow;

DROP FUNCTION IF EXISTS fn_get_item_flow(UUID);
CREATE OR REPLACE FUNCTION fn_get_item_flow(p_pr_id UUID)
RETURNS TABLE (pr_item_id UUID, pr_id UUID, pr_number TEXT, pr_pos INT, item_name TEXT, item_code TEXT, unit TEXT,
               pr_qty NUMERIC, po_qty NUMERIC, grn_qty NUMERIC, pur_qty NUMERIC,
               remaining_pr NUMERIC, remaining_po NUMERIC, remaining_grn NUMERIC, chain_status TEXT,
               po_numbers TEXT, grn_numbers TEXT, pur_numbers TEXT)
LANGUAGE SQL SECURITY DEFINER SET search_path = public AS $$
    SELECT v.pr_item_id, v.pr_id, v.pr_number, v.pr_pos, v.item_name, v.item_code, v.unit,
           v.pr_qty, v.po_qty, v.grn_qty, v.pur_qty, v.remaining_pr, v.remaining_po, v.remaining_grn, v.chain_status,
           v.po_numbers, v.grn_numbers, v.pur_numbers
    FROM v_item_transaction_flow v WHERE v.pr_id = p_pr_id ORDER BY v.pr_pos;
$$;

GRANT SELECT ON v_item_transaction_flow TO authenticated, anon;
GRANT SELECT ON v_item_flow_recursive TO authenticated, anon;
GRANT EXECUTE ON FUNCTION fn_get_item_flow(UUID) TO authenticated, anon;

-- v_item_flow_by_grn: Item flow from GRN perspective (avoids 404 when ItemFlow loads by grnId)
DROP VIEW IF EXISTS v_item_flow_by_grn CASCADE;
CREATE OR REPLACE VIEW v_item_flow_by_grn AS
SELECT
  gii.id AS grn_item_id,
  gi.id AS grn_id,
  gi.grn_number AS grn_number,
  gi.purchase_order_number AS po_number,
  COALESCE(
    (SELECT pr.pr_number FROM pr_po_linkage ppl
     JOIN purchase_requests pr ON pr.id = ppl.pr_id
     WHERE (ppl.po_id = gi.purchase_order_id OR ppl.po_id IN (SELECT id FROM purchase_orders WHERE TRIM(po_number) = TRIM(gi.purchase_order_number)))
     AND (ppl.status = 'active' OR ppl.status IS NULL) LIMIT 1),
    (SELECT pr.pr_number FROM purchase_requests pr
     JOIN purchase_request_items pri ON pri.pr_id = pr.id
     JOIN purchase_orders po ON (po.id = gi.purchase_order_id OR (gi.purchase_order_number IS NOT NULL AND TRIM(po.po_number) = TRIM(gi.purchase_order_number)))
     JOIN purchase_order_items poi ON poi.purchase_order_id = po.id AND (poi.item_id = pri.item_id OR (poi.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(poi.item_name) = TRIM(pri.item_name)))
     WHERE (pri.deleted IS NOT TRUE) AND (pr.deleted IS NOT TRUE) LIMIT 1)
  ) AS pr_number,
  gii.item_name AS item_name,
  COALESCE(gii.ordered_quantity, gii.received_quantity, 0) AS ordered_qty,
  COALESCE(gii.received_quantity, 0) AS received_qty,
  (SELECT COALESCE(SUM(pii.quantity), 0) FROM purchasing_invoice_items pii
   JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND pi.grn_id = gi.id AND (pi.deleted IS NOT TRUE)
   WHERE pii.item_id = gii.item_id OR pii.item_name = gii.item_name) AS invoiced_qty,
  (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ') FROM purchasing_invoices pi2
   WHERE pi2.grn_id = gi.id AND (pi2.deleted IS NOT TRUE)) AS pur_numbers,
  CASE WHEN COALESCE(gii.received_quantity, 0) >= COALESCE(gii.ordered_quantity, gii.received_quantity, 0)
       THEN 'Fully Received' ELSE 'Partial Received' END AS item_status
FROM grn_inspections gi
JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
WHERE (gi.deleted IS NOT TRUE);

GRANT SELECT ON v_item_flow_by_grn TO authenticated, anon;

-- v_item_flow_by_po: Item flow from PO perspective (grn_qty from grn_inspection_items when poi.quantity_received=0)
DROP VIEW IF EXISTS v_item_flow_by_po CASCADE;
CREATE OR REPLACE VIEW v_item_flow_by_po AS
SELECT
  poi.id AS po_item_id,
  po.id AS po_id,
  po.po_number AS po_number,
  COALESCE((SELECT pr.pr_number FROM pr_po_linkage ppl
   JOIN purchase_requests pr ON pr.id = ppl.pr_id
   WHERE ppl.po_id = po.id AND (ppl.status = 'active' OR ppl.status IS NULL) LIMIT 1),
   (SELECT pr.pr_number FROM purchase_requests pr
    JOIN purchase_request_items pri ON pri.pr_id = pr.id
    JOIN purchase_order_items poi2 ON (poi2.item_id = pri.item_id OR (poi2.item_name IS NOT NULL AND pri.item_name IS NOT NULL AND TRIM(poi2.item_name) = TRIM(pri.item_name)))
    WHERE poi2.id = poi.id AND (pri.deleted IS NOT TRUE) LIMIT 1)
  ) AS pr_number,
  poi.item_name AS item_name,
  COALESCE(poi.quantity, 0) AS po_qty,
  GREATEST(COALESCE(poi.quantity_received, 0),
    COALESCE((SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
     JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
     WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
       AND (gi.deleted IS NOT TRUE)
       AND (gii.item_id = poi.item_id OR (gii.item_name IS NOT NULL AND poi.item_name IS NOT NULL AND TRIM(gii.item_name) = TRIM(poi.item_name)))), 0)
  ) AS grn_qty,
  (SELECT COALESCE(SUM(pii.quantity), 0) FROM purchasing_invoice_items pii
   JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id AND (pi.purchase_order_id = po.id OR pi.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number))))
   WHERE pii.item_id = poi.item_id OR pii.item_name = poi.item_name) AS pur_qty,
  GREATEST(0, COALESCE(poi.quantity, 0) - GREATEST(COALESCE(poi.quantity_received, 0),
    COALESCE((SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
     JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
     WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
       AND (gi.deleted IS NOT TRUE)
       AND (gii.item_id = poi.item_id OR (gii.item_name IS NOT NULL AND poi.item_name IS NOT NULL AND TRIM(gii.item_name) = TRIM(poi.item_name)))), 0)
  )) AS remaining_to_receive,
  (SELECT STRING_AGG(DISTINCT gi.grn_number, ', ') FROM grn_inspections gi
   WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number))) AND (gi.deleted IS NOT TRUE)) AS grn_numbers,
  (SELECT STRING_AGG(DISTINCT pi2.purchasing_number, ', ') FROM purchasing_invoices pi2
   WHERE (pi2.purchase_order_id = po.id OR pi2.grn_id IN (SELECT id FROM grn_inspections WHERE purchase_order_id = po.id OR (purchase_order_number IS NOT NULL AND TRIM(purchase_order_number) = TRIM(po.po_number)))) AND (pi2.deleted IS NOT TRUE)) AS pur_numbers,
  ROW_NUMBER() OVER (PARTITION BY po.id ORDER BY poi.id)::INT AS po_pos,
  CASE WHEN GREATEST(COALESCE(poi.quantity_received, 0),
    COALESCE((SELECT SUM(gii.received_quantity) FROM grn_inspection_items gii
     JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
     WHERE (gi.purchase_order_id = po.id OR (gi.purchase_order_number IS NOT NULL AND TRIM(gi.purchase_order_number) = TRIM(po.po_number)))
       AND (gi.deleted IS NOT TRUE)
       AND (gii.item_id = poi.item_id OR (gii.item_name IS NOT NULL AND poi.item_name IS NOT NULL AND TRIM(gii.item_name) = TRIM(poi.item_name)))), 0)
  ) >= COALESCE(poi.quantity, 0) THEN 'Fully Received' ELSE 'Partial Received' END AS item_status
FROM purchase_orders po
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
WHERE (po.deleted IS NOT TRUE);

GRANT SELECT ON v_item_flow_by_po TO authenticated, anon;

-- ============================================================================
-- DONE. Test: SELECT fn_trace_graph('PR','<uuid>'); SELECT fn_trace_graph('PO','74');
-- ============================================================================
