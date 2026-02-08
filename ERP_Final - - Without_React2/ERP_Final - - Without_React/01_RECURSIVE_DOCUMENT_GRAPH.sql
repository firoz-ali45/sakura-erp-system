-- 01_RECURSIVE_DOCUMENT_GRAPH.sql
-- UNIVERSAL RECURSIVE DOCUMENT GRAPH ENGINE (SAP VBFA)
-- Uses CTE WITH RECURSIVE to find all connected documents
-- Single Source of Truth: Relational Tables (NOT document_flow log)
DROP FUNCTION IF EXISTS fn_recursive_document_graph(TEXT, UUID, BIGINT);
CREATE OR REPLACE FUNCTION fn_recursive_document_graph(
        p_input_type TEXT,
        p_input_uuid UUID DEFAULT NULL,
        p_input_bigint BIGINT DEFAULT NULL
    ) RETURNS JSONB AS $$
DECLARE v_start_type TEXT;
v_start_id TEXT;
v_result JSONB;
BEGIN -- Normalize Input
p_input_type := UPPER(TRIM(p_input_type));
-- Determine Start Node
IF p_input_type = 'PO'
OR p_input_type = 'PURCHASE_ORDER' THEN v_start_type := 'PO';
v_start_id := p_input_bigint::TEXT;
ELSE v_start_type := CASE
    WHEN p_input_type IN ('PR', 'PURCHASE_REQUEST') THEN 'PR'
    WHEN p_input_type IN ('GRN', 'GR', 'GOODS_RECEIPT') THEN 'GRN'
    WHEN p_input_type IN ('PUR', 'INV', 'INVOICE') THEN 'PUR'
    ELSE NULL
END;
v_start_id := p_input_uuid::TEXT;
END IF;
IF v_start_type IS NULL
OR v_start_id IS NULL THEN RETURN jsonb_build_object(
    'pr',
    '[]'::jsonb,
    'po',
    '[]'::jsonb,
    'grn',
    '[]'::jsonb,
    'pur',
    '[]'::jsonb,
    'error',
    'Invalid ID or Type Input'
);
END IF;
-- Recursive CTE to traverse the graph
WITH RECURSIVE doc_graph(type, id, path, depth) AS (
    -- Base Case: Start Node
    SELECT v_start_type,
        v_start_id,
        ARRAY [v_start_id],
        1
    UNION ALL
    -- Recursive Step: Find Neighbors
    SELECT next_node.type,
        next_node.id,
        g.path || next_node.id,
        g.depth + 1
    FROM doc_graph g
        JOIN LATERAL (
            -- =============================================
            -- CONNECT: PR <-> PO
            -- =============================================
            -- PR -> PO (NO status filter - show all links)
            SELECT 'PO' AS type,
                po_id::TEXT AS id
            FROM pr_po_linkage
            WHERE g.type = 'PR'
                AND pr_id::TEXT = g.id
            UNION ALL
            -- PO -> PR (NO status filter - show all links)
            SELECT 'PR' AS type,
                pr_id::TEXT AS id
            FROM pr_po_linkage
            WHERE g.type = 'PO'
                AND po_id::TEXT = g.id
            UNION ALL
            -- =============================================
            -- CONNECT: PO <-> GRN
            -- =============================================
            -- PO -> GRN
            SELECT 'GRN' AS type,
                id::TEXT AS id
            FROM grn_inspections
            WHERE g.type = 'PO'
                AND purchase_order_id::TEXT = g.id
                AND deleted = false
            UNION ALL
            -- GRN -> PO
            SELECT 'PO' AS type,
                purchase_order_id::TEXT AS id
            FROM grn_inspections
            WHERE g.type = 'GRN'
                AND id::TEXT = g.id
                AND purchase_order_id IS NOT NULL
            UNION ALL
            -- =============================================
            -- CONNECT: GRN <-> PUR
            -- =============================================
            -- GRN -> PUR
            SELECT 'PUR' AS type,
                id::TEXT AS id
            FROM purchasing_invoices
            WHERE g.type = 'GRN'
                AND grn_id::TEXT = g.id
                AND deleted = false
            UNION ALL
            -- PUR -> GRN
            SELECT 'GRN' AS type,
                grn_id::TEXT AS id
            FROM purchasing_invoices
            WHERE g.type = 'PUR'
                AND id::TEXT = g.id
                AND grn_id IS NOT NULL
            UNION ALL
            -- =============================================
            -- CONNECT: PO <-> PUR (Direct Invoice)
            -- =============================================
            -- PO -> PUR
            SELECT 'PUR' AS type,
                id::TEXT AS id
            FROM purchasing_invoices
            WHERE g.type = 'PO'
                AND purchase_order_id::TEXT = g.id
                AND deleted = false
            UNION ALL
            -- PUR -> PO
            SELECT 'PO' AS type,
                purchase_order_id::TEXT AS id
            FROM purchasing_invoices
            WHERE g.type = 'PUR'
                AND id::TEXT = g.id
                AND purchase_order_id IS NOT NULL
        ) AS next_node ON TRUE
    WHERE next_node.id != ALL(g.path) -- Prevent cycles
        AND g.depth < 20 -- Safety Depth Limit
)
SELECT jsonb_build_object(
        'pr',
        COALESCE(
            (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            pr_number,
                            'status',
                            status,
                            'date',
                            created_at,
                            'total_amount',
                            estimated_total
                        )
                        ORDER BY created_at
                    )
                FROM purchase_requests
                WHERE id IN (
                        SELECT id::UUID
                        FROM doc_graph
                        WHERE type = 'PR'
                    )
            ),
            '[]'::jsonb
        ),
        'po',
        COALESCE(
            (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            po_number,
                            'status',
                            status,
                            'date',
                            order_date,
                            'total_amount',
                            total_amount
                        )
                        ORDER BY order_date
                    )
                FROM purchase_orders
                WHERE id IN (
                        SELECT id::BIGINT
                        FROM doc_graph
                        WHERE type = 'PO'
                    )
            ),
            '[]'::jsonb
        ),
        'grn',
        COALESCE(
            (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            grn_number,
                            'status',
                            status,
                            'date',
                            grn_date,
                            'received_by',
                            received_by
                        )
                        ORDER BY grn_date
                    )
                FROM grn_inspections
                WHERE id IN (
                        SELECT id::UUID
                        FROM doc_graph
                        WHERE type = 'GRN'
                    )
            ),
            '[]'::jsonb
        ),
        'pur',
        COALESCE(
            (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'id',
                            id,
                            'number',
                            purchasing_number,
                            'status',
                            status,
                            'date',
                            invoice_date,
                            'grand_total',
                            grand_total
                        )
                        ORDER BY invoice_date
                    )
                FROM purchasing_invoices
                WHERE id IN (
                        SELECT id::UUID
                        FROM doc_graph
                        WHERE type = 'PUR'
                    )
            ),
            '[]'::jsonb
        )
    ) INTO v_result;
RETURN v_result;
EXCEPTION
WHEN OTHERS THEN RETURN jsonb_build_object(
    'pr',
    '[]'::jsonb,
    'po',
    '[]'::jsonb,
    'grn',
    '[]'::jsonb,
    'pur',
    '[]'::jsonb,
    'error',
    SQLERRM
);
END;
$$ LANGUAGE plpgsql;