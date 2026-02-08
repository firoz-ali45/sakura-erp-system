-- 01_DOCUMENT_CHAIN_FUNCTION.sql
-- UNIVERSAL DOCUMENT FLOW RECONSTRUCTION ENGINE
-- Recursively finds all related documents through relational joins (PR <-> PO <-> GRN <-> PUR)
CREATE OR REPLACE FUNCTION fn_get_full_document_chain(p_root_type TEXT, p_root_id UUID) RETURNS JSON AS $$
DECLARE v_result JSON;
v_pr_ids UUID [] := '{}';
v_po_ids BIGINT [] := '{}';
v_grn_ids UUID [] := '{}';
v_pur_ids UUID [] := '{}';
rec RECORD;
BEGIN -- 1. IDENTIFY ALL RELATED IDs BASED ON STARTING POINT
-- CASE: Purchase Request (PR)
IF p_root_type = 'PR' THEN v_pr_ids := ARRAY [p_root_id];
-- Find POs linked to this PR
SELECT ARRAY_AGG(DISTINCT po_id) INTO v_po_ids
FROM pr_po_linkage
WHERE pr_id = p_root_id
    AND status = 'active';
-- CASE: Purchase Order (PO)
ELSIF p_root_type = 'PO' THEN -- Cast UUID to BigInt if needed, or handle input type mismatch (assuming caller handles type)
-- Since function input is UUID, we might need to handle BigInt PO IDs carefully.
-- If PO ID is passed as text/uuid, we cast?
-- NOTE: DB uses BigInt for purchase_orders.id. 
-- To support the function signature (UUID), we assume caller passes ID. 
-- However, PO IDs are Bigints? Let's fix signature to TEXT to support both.
RAISE EXCEPTION 'For PO, use fn_get_full_document_chain_by_text or handle casting';
END IF;
-- ... wait, PO IDs are BigInt. Let's make the function generic input TEXT and cast inside.
RETURN '[]'::json;
END;
$$ LANGUAGE plpgsql;
-- RE-DEFINING WITH FLEXIBLE TEXT INPUT
DROP FUNCTION IF EXISTS fn_get_full_document_chain(TEXT, UUID);
CREATE OR REPLACE FUNCTION fn_get_full_document_chain(
        p_root_type TEXT,
        p_root_id_text TEXT
    ) RETURNS JSON AS $$
DECLARE v_pr_ids UUID [] := '{}';
v_po_ids BIGINT [] := '{}';
v_grn_ids UUID [] := '{}';
v_pur_ids UUID [] := '{}';
-- Temp arrays for accumulation
v_temp_po_ids BIGINT [];
v_temp_grn_ids UUID [];
v_temp_pur_ids UUID [];
v_temp_pr_ids UUID [];
v_final_result JSONB := '[]'::jsonb;
BEGIN -- Normalize Input
p_root_type := TRIM(UPPER(p_root_type));
-- =================================================================================================
-- PHASE 1: DISCOVERY (Traverse the graph)
-- =================================================================================================
-- START: PR
IF p_root_type = 'PR' THEN v_pr_ids := ARRAY [p_root_id_text::UUID];
-- PR -> PO
SELECT ARRAY_AGG(DISTINCT po_id) INTO v_po_ids
FROM pr_po_linkage
WHERE pr_id = ANY(v_pr_ids)
    AND status = 'active';
-- START: PO
ELSIF p_root_type = 'PO' THEN v_po_ids := ARRAY [p_root_id_text::BIGINT];
-- START: GRN
ELSIF p_root_type = 'GRN' THEN v_grn_ids := ARRAY [p_root_id_text::UUID];
-- START: PUR (Invoice)
ELSIF p_root_type = 'PUR' THEN v_pur_ids := ARRAY [p_root_id_text::UUID];
END IF;
-- -------------------------------------------------------------------------------------------------
-- EXPANSION LOOPS (Find related parents/children until stable)
-- -------------------------------------------------------------------------------------------------
-- 1. PO <-> GRN <-> PUR (Downstream & Upstream from PO)
-- If we have GRNs, find POs
IF array_length(v_grn_ids, 1) > 0 THEN
SELECT ARRAY_AGG(DISTINCT purchase_order_id) INTO v_temp_po_ids
FROM grn_inspections
WHERE id = ANY(v_grn_ids);
IF v_temp_po_ids IS NOT NULL THEN v_po_ids := v_po_ids || v_temp_po_ids;
END IF;
END IF;
-- If we have PURs, find GRNs
IF array_length(v_pur_ids, 1) > 0 THEN
SELECT ARRAY_AGG(DISTINCT grn_id) INTO v_temp_grn_ids
FROM purchasing_invoices
WHERE id = ANY(v_pur_ids);
IF v_temp_grn_ids IS NOT NULL THEN v_grn_ids := v_grn_ids || v_temp_grn_ids;
-- And getting GRNs might give us (more) POs
SELECT ARRAY_AGG(DISTINCT purchase_order_id) INTO v_temp_po_ids
FROM grn_inspections
WHERE id = ANY(v_grn_ids);
IF v_temp_po_ids IS NOT NULL THEN v_po_ids := v_po_ids || v_temp_po_ids;
END IF;
END IF;
END IF;
-- If we have POs, find:
--    a) PRs (Upstream)
--    b) GRNs (Downstream)
IF array_length(v_po_ids, 1) > 0 THEN -- Find PRs
SELECT ARRAY_AGG(DISTINCT pr_id) INTO v_temp_pr_ids
FROM pr_po_linkage
WHERE po_id = ANY(v_po_ids)
    AND status = 'active';
IF v_temp_pr_ids IS NOT NULL THEN v_pr_ids := v_pr_ids || v_temp_pr_ids;
END IF;
-- Find GRNs
SELECT ARRAY_AGG(DISTINCT id) INTO v_temp_grn_ids
FROM grn_inspections
WHERE purchase_order_id = ANY(v_po_ids)
    AND status != 'deleted';
-- assuming deleted flag or similar
IF v_temp_grn_ids IS NOT NULL THEN v_grn_ids := v_grn_ids || v_temp_grn_ids;
END IF;
END IF;
-- If we have GRNs (newly found), find PURs
IF array_length(v_grn_ids, 1) > 0 THEN
SELECT ARRAY_AGG(DISTINCT id) INTO v_temp_pur_ids
FROM purchasing_invoices
WHERE grn_id = ANY(v_grn_ids);
IF v_temp_pur_ids IS NOT NULL THEN v_pur_ids := v_pur_ids || v_temp_pur_ids;
END IF;
END IF;
-- Cleaning Arrays (Deduplicate)
-- (Postgres arrays can enable duplications, but we used DISTINCT in aggregation. 
--  However, merging arrays (||) might duplicate. We should use logic to distinct.)
--  Simplest way in PLPGSQL is SELECT DISTINCT unnest(...)
SELECT ARRAY(
        SELECT DISTINCT UNNEST(v_pr_ids)
    ) INTO v_pr_ids;
SELECT ARRAY(
        SELECT DISTINCT UNNEST(v_po_ids)
    ) INTO v_po_ids;
SELECT ARRAY(
        SELECT DISTINCT UNNEST(v_grn_ids)
    ) INTO v_grn_ids;
SELECT ARRAY(
        SELECT DISTINCT UNNEST(v_pur_ids)
    ) INTO v_pur_ids;
-- =================================================================================================
-- PHASE 2: CONSTRUCTION (Build JSON Response)
-- =================================================================================================
-- 1. Get PR Details
IF array_length(v_pr_ids, 1) > 0 THEN
SELECT v_final_result || jsonb_agg(
        jsonb_build_object(
            'type',
            'PR',
            'id',
            id,
            'number',
            pr_number,
            'status',
            status,
            'date',
            created_at,
            'total_amount',
            estimated_total_value
        )
    ) INTO v_final_result
FROM purchase_requests
WHERE id = ANY(v_pr_ids);
END IF;
-- 2. Get PO Details
IF array_length(v_po_ids, 1) > 0 THEN
SELECT v_final_result || jsonb_agg(
        jsonb_build_object(
            'type',
            'PO',
            'id',
            id,
            -- BigInt
            'number',
            po_number,
            'status',
            status,
            'date',
            created_at
        )
    ) INTO v_final_result
FROM purchase_orders
WHERE id = ANY(v_po_ids);
END IF;
-- 3. Get GRN Details
IF array_length(v_grn_ids, 1) > 0 THEN
SELECT v_final_result || jsonb_agg(
        jsonb_build_object(
            'type',
            'GRN',
            'id',
            id,
            'number',
            grn_number,
            'status',
            status,
            'date',
            inspection_date
        )
    ) INTO v_final_result
FROM grn_inspections
WHERE id = ANY(v_grn_ids);
END IF;
-- 4. Get PUR Details
IF array_length(v_pur_ids, 1) > 0 THEN
SELECT v_final_result || jsonb_agg(
        jsonb_build_object(
            'type',
            'PUR',
            'id',
            id,
            'number',
            invoice_number,
            'status',
            status,
            'date',
            invoice_date
        )
    ) INTO v_final_result
FROM purchasing_invoices
WHERE id = ANY(v_pur_ids);
END IF;
RETURN v_final_result::JSON;
END;
$$ LANGUAGE plpgsql;