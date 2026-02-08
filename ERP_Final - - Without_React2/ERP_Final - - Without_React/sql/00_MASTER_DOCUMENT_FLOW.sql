-- ============================================================================
-- 00_MASTER_DOCUMENT_FLOW.sql
-- MASTER SCRIPT: RUN ALL DOCUMENT FLOW MIGRATIONS
-- ============================================================================
-- 
-- EXECUTION ORDER:
-- 1. Functions
-- 2. Views  
-- 3. Triggers
-- 4. Indexes
-- 5. Backfill Data
--
-- ============================================================================

\echo '============================================='
\echo 'SAP-STYLE ENTERPRISE DOCUMENT FLOW MIGRATION'
\echo '============================================='

-- ============================================================================
-- STEP 1: Create Functions
-- ============================================================================
\echo ''
\echo '>>> STEP 1: Creating document flow function...'

-- Helper function for safe document flow insertion
CREATE OR REPLACE FUNCTION fn_insert_document_flow(
    p_source_type TEXT,
    p_source_id TEXT,
    p_source_number TEXT,
    p_target_type TEXT,
    p_target_id TEXT,
    p_target_number TEXT,
    p_flow_type TEXT DEFAULT 'created_from'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type, created_at
    ) VALUES (
        p_source_type, p_source_id, p_source_number,
        p_target_type, p_target_id, p_target_number,
        p_flow_type, NOW()
    )
    ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Document flow insert failed: %', SQLERRM;
END;
$$;

-- Main document flow function
DROP FUNCTION IF EXISTS fn_get_document_flow(TEXT, TEXT);

CREATE OR REPLACE FUNCTION fn_get_document_flow(
    p_doc_type TEXT,
    p_doc_id TEXT
)
RETURNS TABLE (
    doc_type TEXT,
    doc_id TEXT,
    doc_number TEXT,
    doc_status TEXT,
    doc_date TIMESTAMPTZ,
    is_current BOOLEAN,
    sequence_order INT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr_id UUID; v_pr_number TEXT; v_pr_status TEXT; v_pr_date TIMESTAMPTZ;
    v_po_id BIGINT; v_po_number TEXT; v_po_status TEXT; v_po_date TIMESTAMPTZ;
    v_grn_id UUID; v_grn_number TEXT; v_grn_status TEXT; v_grn_date TIMESTAMPTZ;
    v_pur_id UUID; v_pur_number TEXT; v_pur_status TEXT; v_pur_date TIMESTAMPTZ;
    v_normalized_type TEXT;
BEGIN
    v_normalized_type := UPPER(TRIM(p_doc_type));
    
    -- Identify and trace documents based on starting point
    IF v_normalized_type IN ('PR', 'PURCHASE_REQUEST') THEN
        SELECT id, pr_number, status, created_at INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM purchase_requests WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        SELECT DISTINCT ppl.po_id, po.po_number, po.status, po.order_date
        INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM pr_po_linkage ppl JOIN purchase_orders po ON po.id = ppl.po_id
        WHERE ppl.pr_id = v_pr_id AND ppl.status = 'active' AND po.deleted = FALSE LIMIT 1;
        
        IF v_po_id IS NULL THEN
            SELECT DISTINCT pri.po_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM purchase_request_items pri JOIN purchase_orders po ON po.id = pri.po_id
            WHERE pri.pr_id = v_pr_id AND pri.po_id IS NOT NULL AND po.deleted = FALSE LIMIT 1;
        END IF;
        
    ELSIF v_normalized_type IN ('PO', 'PURCHASE_ORDER') THEN
        SELECT id, po_number, status, order_date INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM purchase_orders WHERE id = p_doc_id::BIGINT AND deleted = FALSE;
        
        SELECT DISTINCT ppl.pr_id, pr.pr_number, pr.status, pr.created_at
        INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM pr_po_linkage ppl JOIN purchase_requests pr ON pr.id = ppl.pr_id
        WHERE ppl.po_id = v_po_id AND ppl.status = 'active' AND pr.deleted = FALSE LIMIT 1;
        
    ELSIF v_normalized_type IN ('GRN', 'GOODS_RECEIPT') THEN
        SELECT id, grn_number, status, grn_date INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM grn_inspections WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        SELECT gi.purchase_order_id, po.po_number, po.status, po.order_date
        INTO v_po_id, v_po_number, v_po_status, v_po_date
        FROM grn_inspections gi JOIN purchase_orders po ON po.id = gi.purchase_order_id
        WHERE gi.id = v_grn_id AND po.deleted = FALSE;
        
    ELSIF v_normalized_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING_INVOICE') THEN
        SELECT id, purchasing_number, status, created_at INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices WHERE id = p_doc_id::UUID AND deleted = FALSE;
        
        SELECT pi.grn_id, gi.grn_number, gi.status, gi.grn_date
        INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM purchasing_invoices pi LEFT JOIN grn_inspections gi ON gi.id = pi.grn_id
        WHERE pi.id = v_pur_id;
        
        IF v_grn_id IS NOT NULL THEN
            SELECT gi.purchase_order_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM grn_inspections gi JOIN purchase_orders po ON po.id = gi.purchase_order_id
            WHERE gi.id = v_grn_id AND po.deleted = FALSE;
        ELSE
            SELECT pi.purchase_order_id, po.po_number, po.status, po.order_date
            INTO v_po_id, v_po_number, v_po_status, v_po_date
            FROM purchasing_invoices pi JOIN purchase_orders po ON po.id = pi.purchase_order_id
            WHERE pi.id = v_pur_id AND po.deleted = FALSE;
        END IF;
    END IF;
    
    -- Fill missing links
    IF v_po_id IS NOT NULL AND v_pr_id IS NULL THEN
        SELECT DISTINCT ppl.pr_id, pr.pr_number, pr.status, pr.created_at
        INTO v_pr_id, v_pr_number, v_pr_status, v_pr_date
        FROM pr_po_linkage ppl JOIN purchase_requests pr ON pr.id = ppl.pr_id
        WHERE ppl.po_id = v_po_id AND ppl.status = 'active' AND pr.deleted = FALSE LIMIT 1;
    END IF;
    
    IF v_po_id IS NOT NULL AND v_grn_id IS NULL THEN
        SELECT id, grn_number, status, grn_date INTO v_grn_id, v_grn_number, v_grn_status, v_grn_date
        FROM grn_inspections WHERE purchase_order_id = v_po_id AND deleted = FALSE
        ORDER BY created_at DESC LIMIT 1;
    END IF;
    
    IF v_grn_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id, purchasing_number, status, created_at INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices WHERE grn_id = v_grn_id AND deleted = FALSE
        ORDER BY created_at DESC LIMIT 1;
    END IF;
    
    IF v_po_id IS NOT NULL AND v_pur_id IS NULL THEN
        SELECT id, purchasing_number, status, created_at INTO v_pur_id, v_pur_number, v_pur_status, v_pur_date
        FROM purchasing_invoices WHERE purchase_order_id = v_po_id AND deleted = FALSE
        ORDER BY created_at DESC LIMIT 1;
    END IF;
    
    -- Return results
    RETURN QUERY SELECT 'PR'::TEXT, COALESCE(v_pr_id::TEXT, NULL), v_pr_number, 
        COALESCE(v_pr_status, 'not_created'), v_pr_date,
        (v_normalized_type IN ('PR', 'PURCHASE_REQUEST')), 1;
    
    RETURN QUERY SELECT 'PO'::TEXT, COALESCE(v_po_id::TEXT, NULL), v_po_number,
        COALESCE(v_po_status, 'not_created'), v_po_date,
        (v_normalized_type IN ('PO', 'PURCHASE_ORDER')), 2;
    
    RETURN QUERY SELECT 'GRN'::TEXT, COALESCE(v_grn_id::TEXT, NULL), v_grn_number,
        COALESCE(v_grn_status, 'not_created'), v_grn_date,
        (v_normalized_type IN ('GRN', 'GOODS_RECEIPT')), 3;
    
    RETURN QUERY SELECT 'PUR'::TEXT, COALESCE(v_pur_id::TEXT, NULL), v_pur_number,
        COALESCE(v_pur_status, 'not_created'), v_pur_date,
        (v_normalized_type IN ('PUR', 'INV', 'INVOICE', 'PURCHASING_INVOICE')), 4;
    
    RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_get_document_flow(TEXT, TEXT) TO anon;

\echo 'Functions created successfully!'

-- ============================================================================
-- STEP 2: Create Triggers
-- ============================================================================
\echo ''
\echo '>>> STEP 2: Creating triggers...'

-- PR→PO Trigger
CREATE OR REPLACE FUNCTION trg_fn_pr_po_linkage_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_pr_number TEXT;
BEGIN
    IF NEW.pr_number IS NULL THEN
        SELECT pr_number INTO v_pr_number FROM purchase_requests WHERE id = NEW.pr_id;
    ELSE v_pr_number := NEW.pr_number;
    END IF;
    PERFORM fn_insert_document_flow('PR', NEW.pr_id::TEXT, v_pr_number, 'PO', NEW.po_id::TEXT, NEW.po_number, 'converted_to_po');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pr_po_linkage_document_flow ON pr_po_linkage;
CREATE TRIGGER trg_pr_po_linkage_document_flow AFTER INSERT ON pr_po_linkage
FOR EACH ROW EXECUTE FUNCTION trg_fn_pr_po_linkage_document_flow();

-- GRN Trigger
CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_po_number TEXT;
BEGIN
    IF NEW.purchase_order_id IS NOT NULL THEN
        SELECT po_number INTO v_po_number FROM purchase_orders WHERE id = NEW.purchase_order_id;
        PERFORM fn_insert_document_flow('PO', NEW.purchase_order_id::TEXT, COALESCE(v_po_number, NEW.purchase_order_number), 'GRN', NEW.id::TEXT, NEW.grn_number, 'goods_received');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;
CREATE TRIGGER trg_grn_document_flow AFTER INSERT ON grn_inspections
FOR EACH ROW EXECUTE FUNCTION trg_fn_grn_document_flow();

-- PUR Trigger
CREATE OR REPLACE FUNCTION trg_fn_purchasing_invoice_document_flow()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_grn_number TEXT; v_po_number TEXT;
BEGIN
    IF NEW.grn_id IS NOT NULL THEN
        SELECT grn_number INTO v_grn_number FROM grn_inspections WHERE id = NEW.grn_id;
        PERFORM fn_insert_document_flow('GRN', NEW.grn_id::TEXT, COALESCE(v_grn_number, NEW.grn_number), 'PUR', NEW.id::TEXT, NEW.purchasing_number, 'invoice_created');
    END IF;
    IF NEW.purchase_order_id IS NOT NULL AND NEW.grn_id IS NULL THEN
        SELECT po_number INTO v_po_number FROM purchase_orders WHERE id = NEW.purchase_order_id;
        PERFORM fn_insert_document_flow('PO', NEW.purchase_order_id::TEXT, COALESCE(v_po_number, NEW.purchase_order_number), 'PUR', NEW.id::TEXT, NEW.purchasing_number, 'invoice_created');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_purchasing_invoice_document_flow ON purchasing_invoices;
CREATE TRIGGER trg_purchasing_invoice_document_flow AFTER INSERT ON purchasing_invoices
FOR EACH ROW EXECUTE FUNCTION trg_fn_purchasing_invoice_document_flow();

\echo 'Triggers created successfully!'

-- ============================================================================
-- STEP 3: Create Indexes
-- ============================================================================
\echo ''
\echo '>>> STEP 3: Creating indexes...'

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status ON pr_po_linkage(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_pri_po_id ON purchase_request_items(po_id) WHERE po_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_grn_po_id ON grn_inspections(purchase_order_id) WHERE deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_pi_grn_id ON purchasing_invoices(grn_id) WHERE deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_pi_po_id ON purchasing_invoices(purchase_order_id) WHERE deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_df_source ON document_flow(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_df_target ON document_flow(target_type, target_id);

\echo 'Indexes created successfully!'

-- ============================================================================
-- STEP 4: Backfill Historical Data
-- ============================================================================
\echo ''
\echo '>>> STEP 4: Backfilling historical data...'

-- Backfill PR → PO
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 'PR', ppl.pr_id::TEXT, ppl.pr_number, 'PO', ppl.po_id::TEXT, ppl.po_number, 'converted_to_po', COALESCE(ppl.converted_at, NOW())
FROM pr_po_linkage ppl WHERE ppl.status = 'active'
AND NOT EXISTS (SELECT 1 FROM document_flow df WHERE df.source_id = ppl.pr_id::TEXT AND df.target_id = ppl.po_id::TEXT)
ON CONFLICT DO NOTHING;

-- Backfill PO → GRN
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 'PO', gi.purchase_order_id::TEXT, po.po_number, 'GRN', gi.id::TEXT, gi.grn_number, 'goods_received', gi.created_at
FROM grn_inspections gi JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.deleted = FALSE AND gi.purchase_order_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM document_flow df WHERE df.source_id = gi.purchase_order_id::TEXT AND df.target_id = gi.id::TEXT)
ON CONFLICT DO NOTHING;

-- Backfill GRN → PUR
INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
SELECT DISTINCT 'GRN', pi.grn_id::TEXT, gi.grn_number, 'PUR', pi.id::TEXT, pi.purchasing_number, 'invoice_created', pi.created_at
FROM purchasing_invoices pi JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE pi.deleted = FALSE AND pi.grn_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM document_flow df WHERE df.source_id = pi.grn_id::TEXT AND df.target_id = pi.id::TEXT)
ON CONFLICT DO NOTHING;

\echo 'Backfill completed!'

-- ============================================================================
-- VERIFICATION
-- ============================================================================
\echo ''
\echo '>>> VERIFICATION:'
SELECT 'document_flow records' AS metric, COUNT(*) AS count FROM document_flow;
SELECT 'pr_po_linkage records' AS metric, COUNT(*) AS count FROM pr_po_linkage WHERE status = 'active';

\echo ''
\echo '============================================='
\echo 'DOCUMENT FLOW MIGRATION COMPLETE!'
\echo '============================================='
