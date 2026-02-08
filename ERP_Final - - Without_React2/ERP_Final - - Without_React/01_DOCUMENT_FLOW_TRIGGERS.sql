-- 01_DOCUMENT_FLOW_TRIGGERS.sql
-- FIX: Document Flow Architecture

-- 1. Modify document_flow to support BigInt IDs (by using TEXT)
DO $$ 
BEGIN
    -- Check if source_id is already text, if not alter it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='document_flow' AND column_name='source_id' AND data_type='uuid') THEN
        ALTER TABLE document_flow ALTER COLUMN source_id TYPE text;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='document_flow' AND column_name='target_id' AND data_type='uuid') THEN
        ALTER TABLE document_flow ALTER COLUMN target_id TYPE text;
    END IF;
END $$;

-- 2. Trigger for PR -> PO
CREATE OR REPLACE FUNCTION fn_log_pr_to_po() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type, created_at
    ) VALUES (
        'purchase_request', NEW.pr_id::text, NEW.pr_number,
        'purchase_order', NEW.po_id::text, NEW.po_number,
        'converted_to_po', NOW()
    ) ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_pr_po ON pr_po_linkage;
CREATE TRIGGER trg_log_pr_po
AFTER INSERT ON pr_po_linkage
FOR EACH ROW EXECUTE FUNCTION fn_log_pr_to_po();

-- 3. Trigger for PO -> GRN
CREATE OR REPLACE FUNCTION fn_log_po_to_grn() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type, created_at
    ) VALUES (
        'purchase_order', NEW.purchase_order_id::text, NEW.purchase_order_number,
        'grn', NEW.id::text, NEW.grn_number,
        'received', NOW()
    ) ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_po_grn ON grn_inspections;
CREATE TRIGGER trg_log_po_grn
AFTER INSERT ON grn_inspections
FOR EACH ROW EXECUTE FUNCTION fn_log_po_to_grn();

-- 4. Trigger for GRN -> Invoice
CREATE OR REPLACE FUNCTION fn_log_grn_to_invoice() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grn_id IS NOT NULL THEN
        INSERT INTO document_flow (
            source_type, source_id, source_number,
            target_type, target_id, target_number,
            flow_type, created_at
        ) VALUES (
            'grn', NEW.grn_id::text, NEW.grn_number,
            'purchasing_invoice', NEW.id::text, NEW.invoice_number,
            'invoiced', NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_grn_invoice ON purchasing_invoices;
CREATE TRIGGER trg_log_grn_invoice
AFTER INSERT ON purchasing_invoices
FOR EACH ROW EXECUTE FUNCTION fn_log_grn_to_invoice();
