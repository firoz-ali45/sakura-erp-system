-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST TO PURCHASE ORDER LINKING
-- SAP VBFA Document Flow Architecture
-- ============================================================================
-- File: PR_PO_LINKING.sql
-- Purpose: Document flow relationships between PR and PO
-- SAP Equivalent: VBFA (Document Flow), EKES (Confirmations)
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- TABLE: pr_po_linkage (Detailed Line-Level Mapping)
-- Description: Maps individual PR items to PO items for precise tracking
-- Supports: One PR → Multiple PO, Multiple PR → One PO
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_po_linkage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- PR Reference
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE RESTRICT,
    pr_number TEXT NOT NULL,
    pr_item_id UUID NOT NULL REFERENCES purchase_request_items(id) ON DELETE RESTRICT,
    pr_item_number INT NOT NULL,
    
    -- PO Reference
    po_id BIGINT NOT NULL REFERENCES purchase_orders(id) ON DELETE RESTRICT,
    po_number TEXT NOT NULL,
    po_item_id BIGINT, -- Reference to purchase_order_items if exists
    po_item_number INT,
    
    -- Quantity Conversion Details
    pr_quantity NUMERIC(18, 4) NOT NULL,
    converted_quantity NUMERIC(18, 4) NOT NULL,
    remaining_quantity NUMERIC(18, 4) DEFAULT 0,
    unit TEXT NOT NULL,
    
    -- Price Tracking
    pr_estimated_price NUMERIC(18, 4),
    po_actual_price NUMERIC(18, 4),
    price_variance NUMERIC(18, 4) GENERATED ALWAYS AS (po_actual_price - pr_estimated_price) STORED,
    price_variance_percent NUMERIC(8, 4),
    
    -- Conversion Type
    conversion_type TEXT DEFAULT 'full' CHECK (conversion_type IN ('full', 'partial', 'aggregated')),
    -- full = entire PR item qty converted
    -- partial = only part of PR item qty converted
    -- aggregated = multiple PR items combined into one PO item
    
    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'reversed')),
    
    -- Conversion Metadata
    converted_at TIMESTAMPTZ DEFAULT NOW(),
    converted_by UUID REFERENCES users(id),
    conversion_notes TEXT,
    
    -- Reversal Information (if applicable)
    reversed_at TIMESTAMPTZ,
    reversed_by UUID REFERENCES users(id),
    reversal_reason TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT positive_converted_qty CHECK (converted_quantity > 0)
);

-- ============================================================================
-- FUNCTION: insert_document_flow_pr_to_po()
-- Description: Insert document flow record when PR is linked to PO
-- Uses existing document_flow table (SAP VBFA equivalent)
-- ============================================================================

CREATE OR REPLACE FUNCTION insert_document_flow_pr_to_po()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert into document_flow table
    INSERT INTO document_flow (
        id,
        source_type,
        source_id,
        source_number,
        target_type,
        target_id,
        target_number,
        flow_type,
        created_at
    ) VALUES (
        gen_random_uuid(),
        'PR',
        NEW.pr_id::TEXT,
        NEW.pr_number,
        'PO',
        NEW.po_id::TEXT,
        NEW.po_number,
        'follows',
        NOW()
    )
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_pr_po_linkage_document_flow
-- Description: Auto-insert document flow on new linkage
-- ============================================================================

DROP TRIGGER IF EXISTS tr_pr_po_linkage_document_flow ON pr_po_linkage;

CREATE TRIGGER tr_pr_po_linkage_document_flow
    AFTER INSERT ON pr_po_linkage
    FOR EACH ROW
    EXECUTE FUNCTION insert_document_flow_pr_to_po();

-- ============================================================================
-- FUNCTION: get_pr_linked_pos()
-- Description: Get all POs created from a specific PR
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pr_linked_pos(p_pr_id UUID)
RETURNS TABLE (
    po_id BIGINT,
    po_number TEXT,
    po_status TEXT,
    po_total NUMERIC,
    converted_at TIMESTAMPTZ,
    total_items INT,
    total_converted_qty NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        l.po_id,
        l.po_number,
        po.status,
        po.total_amount,
        l.converted_at,
        COUNT(l.id)::INT AS total_items,
        SUM(l.converted_quantity) AS total_converted_qty
    FROM pr_po_linkage l
    JOIN purchase_orders po ON po.id = l.po_id
    WHERE l.pr_id = p_pr_id
      AND l.status = 'active'
    GROUP BY l.po_id, l.po_number, po.status, po.total_amount, l.converted_at
    ORDER BY l.converted_at DESC;
END;
$$;

-- ============================================================================
-- FUNCTION: get_po_source_prs()
-- Description: Get all PRs that contributed to a specific PO
-- ============================================================================

CREATE OR REPLACE FUNCTION get_po_source_prs(p_po_id BIGINT)
RETURNS TABLE (
    pr_id UUID,
    pr_number TEXT,
    pr_status TEXT,
    pr_department TEXT,
    requester_name TEXT,
    converted_at TIMESTAMPTZ,
    total_items INT,
    total_converted_qty NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        l.pr_id,
        l.pr_number,
        pr.status,
        pr.department,
        pr.requester_name,
        l.converted_at,
        COUNT(l.id)::INT AS total_items,
        SUM(l.converted_quantity) AS total_converted_qty
    FROM pr_po_linkage l
    JOIN purchase_requests pr ON pr.id = l.pr_id
    WHERE l.po_id = p_po_id
      AND l.status = 'active'
    GROUP BY l.pr_id, l.pr_number, pr.status, pr.department, pr.requester_name, l.converted_at
    ORDER BY l.converted_at DESC;
END;
$$;

-- ============================================================================
-- FUNCTION: get_document_flow_tree()
-- Description: Get complete document flow tree for a PR (PR → PO → GRN → Invoice)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_document_flow_tree(p_pr_id UUID)
RETURNS TABLE (
    level INT,
    doc_type TEXT,
    doc_id TEXT,
    doc_number TEXT,
    doc_status TEXT,
    doc_date TIMESTAMPTZ,
    parent_type TEXT,
    parent_id TEXT,
    parent_number TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE flow_tree AS (
        -- Base: Start with the PR
        SELECT 
            1 AS level,
            'PR'::TEXT AS doc_type,
            pr.id::TEXT AS doc_id,
            pr.pr_number AS doc_number,
            pr.status AS doc_status,
            pr.created_at AS doc_date,
            NULL::TEXT AS parent_type,
            NULL::TEXT AS parent_id,
            NULL::TEXT AS parent_number
        FROM purchase_requests pr
        WHERE pr.id = p_pr_id
        
        UNION ALL
        
        -- Recursive: Follow document flow
        SELECT 
            ft.level + 1,
            df.target_type,
            df.target_id,
            df.target_number,
            CASE 
                WHEN df.target_type = 'PO' THEN (SELECT status FROM purchase_orders WHERE id::TEXT = df.target_id)
                WHEN df.target_type = 'GRN' THEN (SELECT status FROM grn_inspections WHERE id::TEXT = df.target_id)
                ELSE 'unknown'
            END,
            df.created_at,
            df.source_type,
            df.source_id,
            df.source_number
        FROM document_flow df
        JOIN flow_tree ft ON df.source_id = ft.doc_id AND df.source_type = ft.doc_type
        WHERE ft.level < 10 -- Prevent infinite recursion
    )
    SELECT * FROM flow_tree
    ORDER BY level, doc_date;
END;
$$;

-- ============================================================================
-- FUNCTION: check_pr_conversion_status()
-- Description: Check if PR is fully, partially, or not converted
-- ============================================================================

CREATE OR REPLACE FUNCTION check_pr_conversion_status(p_pr_id UUID)
RETURNS TABLE (
    total_items INT,
    fully_converted INT,
    partially_converted INT,
    not_converted INT,
    total_quantity NUMERIC,
    converted_quantity NUMERIC,
    conversion_percentage NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INT AS total_items,
        COUNT(*) FILTER (WHERE pri.status = 'converted_to_po')::INT AS fully_converted,
        COUNT(*) FILTER (WHERE pri.status = 'partially_converted')::INT AS partially_converted,
        COUNT(*) FILTER (WHERE pri.status = 'open')::INT AS not_converted,
        SUM(pri.quantity) AS total_quantity,
        SUM(pri.quantity_ordered) AS converted_quantity,
        ROUND(
            (SUM(pri.quantity_ordered) / NULLIF(SUM(pri.quantity), 0)) * 100, 
            2
        ) AS conversion_percentage
    FROM purchase_request_items pri
    WHERE pri.pr_id = p_pr_id
      AND pri.deleted = FALSE
      AND pri.status != 'cancelled';
END;
$$;

-- ============================================================================
-- FUNCTION: reverse_pr_po_linkage()
-- Description: Reverse a PR to PO conversion (undo conversion)
-- ============================================================================

CREATE OR REPLACE FUNCTION reverse_pr_po_linkage(
    p_linkage_id UUID,
    p_reason TEXT,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_linkage RECORD;
BEGIN
    -- Get linkage details
    SELECT * INTO v_linkage
    FROM pr_po_linkage
    WHERE id = p_linkage_id AND status = 'active';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Linkage not found or already reversed';
    END IF;
    
    -- Check if PO has been received (GRN exists)
    IF EXISTS (
        SELECT 1 FROM grn_inspections 
        WHERE purchase_order_id = v_linkage.po_id 
        AND status NOT IN ('cancelled', 'draft')
    ) THEN
        RAISE EXCEPTION 'Cannot reverse: PO has already been received (GRN exists)';
    END IF;
    
    -- Mark linkage as reversed
    UPDATE pr_po_linkage
    SET status = 'reversed',
        reversed_at = NOW(),
        reversed_by = p_user_id,
        reversal_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_linkage_id;
    
    -- Restore PR item quantity
    UPDATE purchase_request_items
    SET quantity_ordered = quantity_ordered - v_linkage.converted_quantity,
        status = CASE 
            WHEN quantity_ordered - v_linkage.converted_quantity <= 0 THEN 'open'
            ELSE 'partially_converted'
        END,
        is_locked = FALSE,
        updated_at = NOW()
    WHERE id = v_linkage.pr_item_id;
    
    -- Update PR header status
    PERFORM update_pr_status_from_items(v_linkage.pr_id);
    
    -- Mark document flow as inactive (add metadata)
    UPDATE document_flow
    SET metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{reversed}',
        'true'::jsonb
    )
    WHERE source_type = 'PR' 
      AND source_id = v_linkage.pr_id::TEXT
      AND target_type = 'PO'
      AND target_id = v_linkage.po_id::TEXT;
    
    RETURN TRUE;
END;
$$;

-- ============================================================================
-- INDEXES for pr_po_linkage
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status ON pr_po_linkage(status);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_converted_at ON pr_po_linkage(converted_at);

-- ============================================================================
-- RLS for pr_po_linkage
-- ============================================================================

ALTER TABLE pr_po_linkage ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running the script)
DROP POLICY IF EXISTS pr_po_linkage_select_policy ON pr_po_linkage;
DROP POLICY IF EXISTS pr_po_linkage_insert_policy ON pr_po_linkage;
DROP POLICY IF EXISTS pr_po_linkage_update_policy ON pr_po_linkage;

-- Policy: Users can view linkages for PRs they can access
CREATE POLICY pr_po_linkage_select_policy ON pr_po_linkage
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_po_linkage.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() 
                    AND role IN ('admin', 'procurement', 'manager', 'department_head')
                )
            )
        )
    );

-- Policy: Only procurement/admin can insert linkages
CREATE POLICY pr_po_linkage_insert_policy ON pr_po_linkage
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'procurement', 'manager')
        )
    );

-- Policy: Only admin can update/reverse linkages
CREATE POLICY pr_po_linkage_update_policy ON pr_po_linkage
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'procurement')
        )
    );

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT SELECT ON pr_po_linkage TO authenticated;
GRANT INSERT, UPDATE ON pr_po_linkage TO authenticated;
GRANT EXECUTE ON FUNCTION get_pr_linked_pos(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_po_source_prs(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_document_flow_tree(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_pr_conversion_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reverse_pr_po_linkage(UUID, TEXT, UUID) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE pr_po_linkage IS 'Detailed mapping between PR items and PO items for complete traceability';
COMMENT ON FUNCTION get_pr_linked_pos(UUID) IS 'Get all Purchase Orders created from a specific Purchase Request';
COMMENT ON FUNCTION get_po_source_prs(BIGINT) IS 'Get all Purchase Requests that contributed to a specific Purchase Order';
COMMENT ON FUNCTION get_document_flow_tree(UUID) IS 'Get complete document flow tree starting from a PR';
COMMENT ON FUNCTION reverse_pr_po_linkage(UUID, TEXT, UUID) IS 'Reverse a PR to PO conversion with full audit trail';

-- ============================================================================
-- END OF PR_PO_LINKING.sql
-- ============================================================================
