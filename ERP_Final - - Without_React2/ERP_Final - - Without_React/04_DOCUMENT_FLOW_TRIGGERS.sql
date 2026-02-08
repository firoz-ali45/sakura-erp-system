-- 04_DOCUMENT_FLOW_TRIGGERS.sql
-- AUTO LOGGING TRIGGERS (SAP VBFA)
-- Logs events to document_flow table for historical record or cache
-- 1. PR -> PO
CREATE OR REPLACE FUNCTION fn_log_pr_po_flow() RETURNS TRIGGER AS $$ BEGIN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type
    )
VALUES (
        'PR',
        NEW.pr_id::text,
        NEW.pr_number,
        'PO',
        NEW.po_id::text,
        NEW.po_number,
        'ordered'
    ) ON CONFLICT DO NOTHING;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_log_pr_po ON pr_po_linkage;
CREATE TRIGGER trg_log_pr_po
AFTER
INSERT ON pr_po_linkage FOR EACH ROW EXECUTE FUNCTION fn_log_pr_po_flow();
-- 2. PO -> GRN
CREATE OR REPLACE FUNCTION fn_log_po_grn_flow() RETURNS TRIGGER AS $$ BEGIN IF NEW.purchase_order_id IS NOT NULL THEN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type
    )
VALUES (
        'PO',
        NEW.purchase_order_id::text,
        NEW.purchase_order_number,
        'GRN',
        NEW.id::text,
        NEW.grn_number,
        'received'
    ) ON CONFLICT DO NOTHING;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_log_po_grn ON grn_inspections;
CREATE TRIGGER trg_log_po_grn
AFTER
INSERT ON grn_inspections FOR EACH ROW EXECUTE FUNCTION fn_log_po_grn_flow();
-- 3. GRN -> PUR (or PO -> PUR)
CREATE OR REPLACE FUNCTION fn_log_inv_flow() RETURNS TRIGGER AS $$ BEGIN IF NEW.grn_id IS NOT NULL THEN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type
    )
VALUES (
        'GRN',
        NEW.grn_id::text,
        NEW.grn_number,
        'PUR',
        NEW.id::text,
        NEW.purchasing_number,
        'invoiced'
    ) ON CONFLICT DO NOTHING;
ELSIF NEW.purchase_order_id IS NOT NULL THEN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type
    )
VALUES (
        'PO',
        NEW.purchase_order_id::text,
        NEW.purchasing_number,
        'PUR',
        NEW.id::text,
        NEW.purchasing_number,
        'invoiced'
    ) ON CONFLICT DO NOTHING;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_log_inv ON purchasing_invoices;
CREATE TRIGGER trg_log_inv
AFTER
INSERT ON purchasing_invoices FOR EACH ROW EXECUTE FUNCTION fn_log_inv_flow();