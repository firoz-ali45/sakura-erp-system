-- 05_BACKFILL_DOCUMENT_FLOW.sql
-- BACKFILL HISTORICAL DATA into document_flow
BEGIN;
-- 1. PR -> PO
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
SELECT DISTINCT 'PR',
    pr_id::text,
    pr_number,
    'PO',
    po_id::text,
    po_number,
    'ordered',
    created_at
FROM pr_po_linkage
WHERE status = 'active' ON CONFLICT DO NOTHING;
-- 2. PO -> GRN
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
SELECT DISTINCT 'PO',
    purchase_order_id::text,
    purchase_order_number,
    'GRN',
    id::text,
    grn_number,
    'received',
    created_at
FROM grn_inspections
WHERE purchase_order_id IS NOT NULL
    AND deleted = false ON CONFLICT DO NOTHING;
-- 3. GRN -> PUR
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
SELECT DISTINCT 'GRN',
    grn_id::text,
    grn_number,
    'PUR',
    id::text,
    purchasing_number,
    'invoiced',
    created_at
FROM purchasing_invoices
WHERE grn_id IS NOT NULL
    AND deleted = false ON CONFLICT DO NOTHING;
-- 4. PO -> PUR (Direct)
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
SELECT DISTINCT 'PO',
    purchase_order_id::text,
    purchasing_number,
    'PUR',
    id::text,
    purchasing_number,
    'invoiced',
    created_at
FROM purchasing_invoices
WHERE purchase_order_id IS NOT NULL
    AND grn_id IS NULL
    AND deleted = false ON CONFLICT DO NOTHING;
COMMIT;