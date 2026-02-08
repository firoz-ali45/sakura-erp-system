-- 03_DOCUMENT_FLOW_TRIGGERS.sql
-- AUTOMATION: Auto-populate document_flow table when transactions occur.
-- Logic: INSERT OR DO NOTHING (Idempotent)
-- 1. TRIGGER: PR -> PO
-- (Handled in 01_DOCUMENT_FLOW_TRIGGERS.sql, reinforcing here)
CREATE OR REPLACE FUNCTION fn_trigger_flow_pr_po() RETURNS TRIGGER AS $$ BEGIN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type,
        created_at
    )
VALUES (
        'PR',
        NEW.pr_id::text,
        NEW.pr_number,
        'PO',
        NEW.po_id::text,
        NEW.po_number,
        'converted',
        NOW()
    ) ON CONFLICT DO NOTHING;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_flow_pr_po_insert ON pr_po_linkage;
CREATE TRIGGER trg_flow_pr_po_insert
AFTER
INSERT ON pr_po_linkage FOR EACH ROW EXECUTE FUNCTION fn_trigger_flow_pr_po();
-- 2. TRIGGER: PO -> GRN
CREATE OR REPLACE FUNCTION fn_trigger_flow_po_grn() RETURNS TRIGGER AS $$ BEGIN IF NEW.purchase_order_id IS NOT NULL THEN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type,
        created_at
    )
VALUES (
        'PO',
        NEW.purchase_order_id::text,
        NEW.purchase_order_number,
        'GRN',
        NEW.id::text,
        NEW.grn_number,
        'received',
        NOW()
    ) ON CONFLICT DO NOTHING;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_flow_po_grn_insert ON grn_inspections;
CREATE TRIGGER trg_flow_po_grn_insert
AFTER
INSERT ON grn_inspections FOR EACH ROW EXECUTE FUNCTION fn_trigger_flow_po_grn();
-- 3. TRIGGER: GRN -> PUR (Invoicing)
CREATE OR REPLACE FUNCTION fn_trigger_flow_grn_pur() RETURNS TRIGGER AS $$ BEGIN IF NEW.grn_id IS NOT NULL THEN
INSERT INTO document_flow (
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type,
        created_at
    )
VALUES (
        'GRN',
        NEW.grn_id::text,
        NEW.grn_number,
        'PUR',
        NEW.id::text,
        NEW.invoice_number,
        'invoiced',
        NOW()
    ) ON CONFLICT DO NOTHING;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_flow_grn_pur_insert ON purchasing_invoices;
CREATE TRIGGER trg_flow_grn_pur_insert
AFTER
INSERT ON purchasing_invoices FOR EACH ROW EXECUTE FUNCTION fn_trigger_flow_grn_pur();