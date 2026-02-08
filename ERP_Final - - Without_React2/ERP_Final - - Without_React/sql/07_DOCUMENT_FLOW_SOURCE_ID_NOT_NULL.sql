-- ============================================================================
-- 07_DOCUMENT_FLOW_SOURCE_ID_NOT_NULL.sql
-- FIX: "null value in column source_id of relation document_flow violates not-null constraint"
-- RUN IN SUPABASE SQL EDITOR when Create GRN fails with that error.
-- ============================================================================
-- ROOT CAUSE: Trigger trg_fn_grn_document_flow uses NEW.purchase_order_id for
-- source_id. When grn_inspections.purchase_order_id is NULL (e.g. frontend
-- only sent purchase_order_number), the trigger inserted source_id = NULL.
-- FIX: Derive source_id from purchase_order_number when purchase_order_id is NULL.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_grn_document_flow ON grn_inspections;

CREATE OR REPLACE FUNCTION trg_fn_grn_document_flow()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_po_id   bigint;
    v_po_number text;
    v_source_id text;
BEGIN
    -- Only insert document_flow when we can provide a non-null source_id (PO link).
    v_po_id := NEW.purchase_order_id;
    v_po_number := NULL;

    IF v_po_id IS NOT NULL THEN
        v_source_id := v_po_id::TEXT;
        SELECT po_number INTO v_po_number FROM purchase_orders WHERE id = v_po_id;
    ELSIF NEW.purchase_order_number IS NOT NULL AND TRIM(NEW.purchase_order_number) <> '' THEN
        -- Derive PO id from purchase_order_number so source_id is never null.
        SELECT id, po_number INTO v_po_id, v_po_number
        FROM purchase_orders
        WHERE TRIM(po_number) = TRIM(NEW.purchase_order_number)
          AND (deleted IS NOT TRUE OR deleted IS NULL)
        LIMIT 1;
        IF v_po_id IS NOT NULL THEN
            v_source_id := v_po_id::TEXT;
        END IF;
    END IF;

    IF v_source_id IS NOT NULL THEN
        INSERT INTO document_flow (
            source_type,
            source_id,
            source_number,
            target_type,
            target_id,
            target_number,
            flow_type,
            created_at
        ) VALUES (
            'PO',
            v_source_id,
            COALESCE(v_po_number, NEW.purchase_order_number),
            'GRN',
            NEW.id::TEXT,
            NEW.grn_number,
            'goods_received',
            NOW()
        );
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PO-GRN document flow insert skipped: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grn_document_flow
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_grn_document_flow();
