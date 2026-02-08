-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST ANALYTICS VIEWS
-- Enterprise Reporting & Business Intelligence
-- ============================================================================
-- File: PR_ANALYTICS_VIEWS.sql
-- Purpose: Summary views, dashboards, and reporting queries
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- VIEW: v_pr_summary
-- Description: Complete PR summary with aggregated data for list displays
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_summary AS
SELECT
    pr.id,
    pr.pr_number,
    pr.requester_id,
    pr.requester_name,
    pr.department,
    pr.cost_center,
    pr.business_date,
    pr.required_date,
    pr.priority,
    pr.status,
    pr.document_type,
    pr.currency,
    pr.estimated_total_value,
    pr.notes,
    pr.created_at,
    pr.updated_at,
    pr.approved_by,
    pr.approved_at,
    pr.rejection_reason,
    
    -- Item counts
    COALESCE(items.total_items, 0) AS total_items,
    COALESCE(items.open_items, 0) AS open_items,
    COALESCE(items.converted_items, 0) AS converted_items,
    COALESCE(items.cancelled_items, 0) AS cancelled_items,
    
    -- Quantity summary
    COALESCE(items.total_quantity, 0) AS total_quantity,
    COALESCE(items.ordered_quantity, 0) AS ordered_quantity,
    COALESCE(items.remaining_quantity, 0) AS remaining_quantity,
    
    -- Conversion metrics
    CASE 
        WHEN COALESCE(items.total_quantity, 0) > 0 
        THEN ROUND((COALESCE(items.ordered_quantity, 0) / items.total_quantity) * 100, 2)
        ELSE 0 
    END AS conversion_percentage,
    
    -- PO linkage
    COALESCE(pos.po_count, 0) AS linked_po_count,
    pos.po_numbers,
    
    -- Approver info
    approver.name AS approver_name,
    
    -- Age calculations
    (CURRENT_DATE - pr.created_at::DATE)::INT AS days_since_created,
    CASE 
        WHEN pr.required_date < CURRENT_DATE AND pr.status NOT IN ('closed', 'cancelled', 'fully_ordered')
        THEN (CURRENT_DATE - pr.required_date)::INT
        ELSE 0
    END AS days_overdue,
    
    -- Status flags
    pr.required_date < CURRENT_DATE AND pr.status NOT IN ('closed', 'cancelled', 'fully_ordered') AS is_overdue,
    pr.status IN ('approved', 'partially_ordered') AS is_convertible

FROM purchase_requests pr

-- Item aggregation
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS total_items,
        COUNT(*) FILTER (WHERE status = 'open') AS open_items,
        COUNT(*) FILTER (WHERE status IN ('converted_to_po', 'partially_converted')) AS converted_items,
        COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_items,
        SUM(quantity) AS total_quantity,
        SUM(quantity_ordered) AS ordered_quantity,
        SUM(quantity - quantity_ordered) AS remaining_quantity
    FROM purchase_request_items
    WHERE pr_id = pr.id AND deleted = FALSE
) items ON TRUE

-- PO linkage
LEFT JOIN LATERAL (
    SELECT 
        COUNT(DISTINCT po_id) AS po_count,
        STRING_AGG(DISTINCT po_number, ', ' ORDER BY po_number) AS po_numbers
    FROM pr_po_linkage
    WHERE pr_id = pr.id AND status = 'active'
) pos ON TRUE

-- Approver
LEFT JOIN users approver ON approver.id = pr.approved_by

WHERE pr.deleted = FALSE
ORDER BY pr.created_at DESC;

-- ============================================================================
-- VIEW: v_pr_item_status
-- Description: Detailed PR item status with conversion tracking
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_item_status AS
SELECT
    pri.id,
    pri.pr_id,
    pr.pr_number,
    pr.department,
    pr.status AS pr_status,
    pri.item_number,
    pri.item_id,
    pri.item_code,
    pri.item_name,
    pri.item_description,
    pri.quantity,
    pri.unit,
    pri.quantity_ordered,
    pri.quantity - pri.quantity_ordered AS quantity_remaining,
    pri.estimated_price,
    pri.estimated_total,
    pri.status AS item_status,
    pri.required_date,
    
    -- Suggested supplier
    pri.suggested_supplier_id,
    pri.suggested_supplier_name,
    
    -- Conversion details
    pri.po_id,
    pri.po_number,
    pri.po_item_number,
    pri.conversion_date,
    
    -- Lock status
    pri.is_locked,
    pri.lock_reason,
    
    -- Price variance (if converted)
    link.po_actual_price,
    link.price_variance,
    CASE 
        WHEN pri.estimated_price > 0 AND link.price_variance IS NOT NULL
        THEN ROUND((link.price_variance / pri.estimated_price) * 100, 2)
        ELSE NULL
    END AS price_variance_percent,
    
    -- Inventory details
    inv.sku AS inventory_sku,
    inv.category AS inventory_category,
    inv.cost AS inventory_cost,
    
    -- Timestamps
    pri.created_at,
    pri.updated_at

FROM purchase_request_items pri
JOIN purchase_requests pr ON pr.id = pri.pr_id
LEFT JOIN inventory_items inv ON inv.id = pri.item_id
LEFT JOIN pr_po_linkage link ON link.pr_item_id = pri.id AND link.status = 'active'

WHERE pri.deleted = FALSE AND pr.deleted = FALSE
ORDER BY pr.pr_number, pri.item_number;

-- ============================================================================
-- VIEW: v_pr_conversion_rate
-- Description: PR conversion analytics and KPIs
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_conversion_rate AS
SELECT
    -- Time period
    DATE_TRUNC('month', pr.created_at)::DATE AS period_month,
    EXTRACT(YEAR FROM pr.created_at)::INT AS period_year,
    
    -- Volume metrics
    COUNT(*) AS total_prs,
    COUNT(*) FILTER (WHERE pr.status = 'draft') AS draft_count,
    COUNT(*) FILTER (WHERE pr.status = 'submitted') AS submitted_count,
    COUNT(*) FILTER (WHERE pr.status IN ('approved', 'partially_ordered', 'fully_ordered', 'closed')) AS approved_count,
    COUNT(*) FILTER (WHERE pr.status = 'rejected') AS rejected_count,
    COUNT(*) FILTER (WHERE pr.status IN ('fully_ordered', 'closed')) AS completed_count,
    
    -- Conversion rates
    ROUND(
        COUNT(*) FILTER (WHERE pr.status IN ('approved', 'partially_ordered', 'fully_ordered', 'closed'))::NUMERIC / 
        NULLIF(COUNT(*) FILTER (WHERE pr.status != 'draft'), 0) * 100,
        2
    ) AS approval_rate,
    
    ROUND(
        COUNT(*) FILTER (WHERE pr.status IN ('fully_ordered', 'closed'))::NUMERIC / 
        NULLIF(COUNT(*) FILTER (WHERE pr.status IN ('approved', 'partially_ordered', 'fully_ordered', 'closed')), 0) * 100,
        2
    ) AS conversion_to_po_rate,
    
    -- Value metrics
    SUM(pr.estimated_total_value) AS total_estimated_value,
    AVG(pr.estimated_total_value) AS avg_pr_value,
    MAX(pr.estimated_total_value) AS max_pr_value,
    
    -- Timing metrics
    AVG(EXTRACT(DAY FROM pr.approved_at - pr.created_at))::NUMERIC(10,2) AS avg_days_to_approval,
    
    -- Item metrics
    SUM(items.total_items) AS total_items,
    SUM(items.converted_items) AS total_converted_items

FROM purchase_requests pr
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*) AS total_items,
        COUNT(*) FILTER (WHERE status IN ('converted_to_po', 'partially_converted')) AS converted_items
    FROM purchase_request_items
    WHERE pr_id = pr.id AND deleted = FALSE
) items ON TRUE

WHERE pr.deleted = FALSE
GROUP BY DATE_TRUNC('month', pr.created_at), EXTRACT(YEAR FROM pr.created_at)
ORDER BY period_year DESC, period_month DESC;

-- ============================================================================
-- VIEW: v_pr_by_department
-- Description: Department-wise PR analysis
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_by_department AS
SELECT
    pr.department,
    COUNT(*) AS total_prs,
    COUNT(*) FILTER (WHERE pr.status = 'draft') AS draft,
    COUNT(*) FILTER (WHERE pr.status = 'submitted') AS pending_approval,
    COUNT(*) FILTER (WHERE pr.status = 'approved') AS approved,
    COUNT(*) FILTER (WHERE pr.status = 'partially_ordered') AS partially_ordered,
    COUNT(*) FILTER (WHERE pr.status IN ('fully_ordered', 'closed')) AS completed,
    COUNT(*) FILTER (WHERE pr.status = 'rejected') AS rejected,
    SUM(pr.estimated_total_value) AS total_value,
    AVG(pr.estimated_total_value) AS avg_value,
    COUNT(DISTINCT pr.requester_id) AS unique_requesters,
    MAX(pr.created_at) AS last_pr_date
FROM purchase_requests pr
WHERE pr.deleted = FALSE
GROUP BY pr.department
ORDER BY total_prs DESC;

-- ============================================================================
-- VIEW: v_pr_pending_approval
-- Description: PRs awaiting approval with approver details
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_pending_approval AS
SELECT
    pr.id,
    pr.pr_number,
    pr.requester_id,
    pr.requester_name,
    pr.department,
    pr.priority,
    pr.status,
    pr.estimated_total_value,
    pr.required_date,
    pr.created_at,
    pr.notes,
    
    -- Approval workflow
    aw.approval_level,
    aw.approval_step,
    aw.approver_id,
    aw.approver_role,
    aw.due_date,
    
    -- Item summary
    (SELECT COUNT(*) FROM purchase_request_items WHERE pr_id = pr.id AND deleted = FALSE) AS item_count,
    
    -- Urgency
    CASE 
        WHEN pr.priority = 'critical' THEN 1
        WHEN pr.priority = 'urgent' THEN 2
        WHEN pr.priority = 'high' THEN 3
        WHEN pr.required_date <= CURRENT_DATE + INTERVAL '7 days' THEN 4
        ELSE 5
    END AS urgency_rank,
    
    -- Days pending
    EXTRACT(DAY FROM NOW() - pr.created_at)::INT AS days_pending

FROM purchase_requests pr
LEFT JOIN pr_approval_workflow aw ON aw.pr_id = pr.id AND aw.decision = 'pending'
WHERE pr.status IN ('submitted', 'under_review')
  AND pr.deleted = FALSE
ORDER BY urgency_rank, pr.created_at;

-- ============================================================================
-- VIEW: v_pr_overdue
-- Description: Overdue PRs requiring attention
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_overdue AS
SELECT
    pr.id,
    pr.pr_number,
    pr.requester_name,
    pr.department,
    pr.status,
    pr.priority,
    pr.required_date,
    pr.estimated_total_value,
    (CURRENT_DATE - pr.required_date)::INT AS days_overdue,
    CASE 
        WHEN pr.status = 'draft' THEN 'Not submitted'
        WHEN pr.status IN ('submitted', 'under_review') THEN 'Pending approval'
        WHEN pr.status = 'approved' THEN 'Awaiting PO creation'
        WHEN pr.status = 'partially_ordered' THEN 'Partially fulfilled'
        ELSE pr.status
    END AS overdue_reason,
    (SELECT COUNT(*) FROM purchase_request_items WHERE pr_id = pr.id AND status = 'open' AND deleted = FALSE) AS open_items
FROM purchase_requests pr
WHERE pr.required_date < CURRENT_DATE
  AND pr.status NOT IN ('closed', 'cancelled', 'fully_ordered', 'rejected')
  AND pr.deleted = FALSE
ORDER BY days_overdue DESC;

-- ============================================================================
-- VIEW: v_pr_document_flow
-- Description: Complete document flow visualization data
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_document_flow AS
SELECT
    pr.id AS pr_id,
    pr.pr_number,
    pr.status AS pr_status,
    pr.created_at AS pr_date,
    
    -- PO details
    po.id AS po_id,
    po.po_number,
    po.status AS po_status,
    po.created_at AS po_date,
    po.total_amount AS po_amount,
    
    -- GRN details (if exists)
    grn.id AS grn_id,
    grn.grn_number,
    grn.status AS grn_status,
    grn.grn_date AS grn_date,
    
    -- Linkage details
    link.converted_at,
    link.converted_quantity,
    link.pr_estimated_price,
    link.po_actual_price,
    link.price_variance

FROM purchase_requests pr
LEFT JOIN pr_po_linkage link ON link.pr_id = pr.id AND link.status = 'active'
LEFT JOIN purchase_orders po ON po.id = link.po_id
LEFT JOIN grn_inspections grn ON grn.purchase_order_id = po.id AND grn.deleted = FALSE

WHERE pr.deleted = FALSE
ORDER BY pr.created_at DESC, po.created_at, grn.grn_date;

-- ============================================================================
-- VIEW: v_pr_value_analysis
-- Description: Value-based analysis for budgeting and forecasting
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_value_analysis AS
SELECT
    pr.department,
    pr.cost_center,
    DATE_TRUNC('month', pr.business_date)::DATE AS budget_month,
    
    -- Estimated values
    SUM(pr.estimated_total_value) AS total_estimated,
    SUM(pr.estimated_total_value) FILTER (WHERE pr.status = 'draft') AS draft_value,
    SUM(pr.estimated_total_value) FILTER (WHERE pr.status IN ('submitted', 'under_review')) AS pending_value,
    SUM(pr.estimated_total_value) FILTER (WHERE pr.status = 'approved') AS approved_value,
    SUM(pr.estimated_total_value) FILTER (WHERE pr.status IN ('partially_ordered', 'fully_ordered')) AS committed_value,
    
    -- Actual PO values
    (
        SELECT COALESCE(SUM(po.total_amount), 0)
        FROM pr_po_linkage l
        JOIN purchase_orders po ON po.id = l.po_id
        WHERE l.pr_id = ANY(ARRAY_AGG(pr.id))
        AND l.status = 'active'
    ) AS actual_po_value,
    
    -- Count
    COUNT(*) AS pr_count

FROM purchase_requests pr
WHERE pr.deleted = FALSE
GROUP BY pr.department, pr.cost_center, DATE_TRUNC('month', pr.business_date)
ORDER BY budget_month DESC, pr.department;

-- ============================================================================
-- VIEW: v_pr_requester_summary
-- Description: Per-requester PR activity summary
-- ============================================================================

CREATE OR REPLACE VIEW v_pr_requester_summary AS
SELECT
    u.id AS user_id,
    u.name AS user_name,
    u.email,
    u.role,
    COUNT(pr.id) AS total_prs,
    COUNT(pr.id) FILTER (WHERE pr.status = 'approved') AS approved_prs,
    COUNT(pr.id) FILTER (WHERE pr.status = 'rejected') AS rejected_prs,
    ROUND(
        COUNT(pr.id) FILTER (WHERE pr.status IN ('approved', 'fully_ordered', 'closed'))::NUMERIC /
        NULLIF(COUNT(pr.id) FILTER (WHERE pr.status NOT IN ('draft', 'cancelled')), 0) * 100,
        2
    ) AS approval_rate,
    SUM(pr.estimated_total_value) AS total_requested_value,
    MAX(pr.created_at) AS last_pr_date,
    COUNT(pr.id) FILTER (WHERE pr.status IN ('submitted', 'under_review')) AS pending_prs
FROM users u
LEFT JOIN purchase_requests pr ON pr.requester_id = u.id AND pr.deleted = FALSE
GROUP BY u.id, u.name, u.email, u.role
HAVING COUNT(pr.id) > 0
ORDER BY total_prs DESC;

-- ============================================================================
-- FUNCTION: get_pr_dashboard_stats()
-- Description: Get dashboard KPI statistics
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pr_dashboard_stats(
    p_department TEXT DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_prs', COUNT(*),
        'draft_count', COUNT(*) FILTER (WHERE status = 'draft'),
        'pending_approval', COUNT(*) FILTER (WHERE status IN ('submitted', 'under_review')),
        'approved_count', COUNT(*) FILTER (WHERE status = 'approved'),
        'partially_ordered', COUNT(*) FILTER (WHERE status = 'partially_ordered'),
        'fully_ordered', COUNT(*) FILTER (WHERE status = 'fully_ordered'),
        'closed_count', COUNT(*) FILTER (WHERE status = 'closed'),
        'rejected_count', COUNT(*) FILTER (WHERE status = 'rejected'),
        'cancelled_count', COUNT(*) FILTER (WHERE status = 'cancelled'),
        'total_value', COALESCE(SUM(estimated_total_value), 0),
        'avg_value', COALESCE(AVG(estimated_total_value), 0),
        'overdue_count', COUNT(*) FILTER (WHERE required_date < CURRENT_DATE AND status NOT IN ('closed', 'cancelled', 'fully_ordered', 'rejected')),
        'high_priority_count', COUNT(*) FILTER (WHERE priority IN ('high', 'urgent', 'critical'))
    ) INTO v_stats
    FROM purchase_requests
    WHERE deleted = FALSE
    AND (p_department IS NULL OR department = p_department)
    AND (p_start_date IS NULL OR business_date >= p_start_date)
    AND (p_end_date IS NULL OR business_date <= p_end_date);
    
    RETURN v_stats;
END;
$$;

-- ============================================================================
-- FUNCTION: get_pr_trend_data()
-- Description: Get PR trend data for charts
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pr_trend_data(
    p_months INT DEFAULT 12,
    p_department TEXT DEFAULT NULL
)
RETURNS TABLE (
    period_month DATE,
    created_count INT,
    approved_count INT,
    rejected_count INT,
    total_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH months AS (
        SELECT DATE_TRUNC('month', CURRENT_DATE - (n || ' months')::INTERVAL)::DATE AS month_start
        FROM generate_series(0, p_months - 1) AS n
    )
    SELECT 
        m.month_start AS period_month,
        COUNT(pr.id) FILTER (WHERE DATE_TRUNC('month', pr.created_at) = m.month_start)::INT AS created_count,
        COUNT(pr.id) FILTER (WHERE DATE_TRUNC('month', pr.approved_at) = m.month_start)::INT AS approved_count,
        COUNT(pr.id) FILTER (WHERE pr.status = 'rejected' AND DATE_TRUNC('month', pr.updated_at) = m.month_start)::INT AS rejected_count,
        COALESCE(SUM(pr.estimated_total_value) FILTER (WHERE DATE_TRUNC('month', pr.created_at) = m.month_start), 0) AS total_value
    FROM months m
    LEFT JOIN purchase_requests pr ON pr.deleted = FALSE 
        AND (p_department IS NULL OR pr.department = p_department)
    GROUP BY m.month_start
    ORDER BY m.month_start;
END;
$$;

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT SELECT ON v_pr_summary TO authenticated;
GRANT SELECT ON v_pr_item_status TO authenticated;
GRANT SELECT ON v_pr_conversion_rate TO authenticated;
GRANT SELECT ON v_pr_by_department TO authenticated;
GRANT SELECT ON v_pr_pending_approval TO authenticated;
GRANT SELECT ON v_pr_overdue TO authenticated;
GRANT SELECT ON v_pr_document_flow TO authenticated;
GRANT SELECT ON v_pr_value_analysis TO authenticated;
GRANT SELECT ON v_pr_requester_summary TO authenticated;
GRANT EXECUTE ON FUNCTION get_pr_dashboard_stats(TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pr_trend_data(INT, TEXT) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON VIEW v_pr_summary IS 'Complete PR summary view for list displays with all aggregated metrics';
COMMENT ON VIEW v_pr_item_status IS 'Detailed PR item status with conversion tracking and inventory details';
COMMENT ON VIEW v_pr_conversion_rate IS 'Monthly PR conversion analytics and KPIs';
COMMENT ON VIEW v_pr_by_department IS 'Department-wise PR analysis for management reporting';
COMMENT ON VIEW v_pr_pending_approval IS 'PRs awaiting approval with priority ranking';
COMMENT ON VIEW v_pr_overdue IS 'Overdue PRs requiring immediate attention';
COMMENT ON VIEW v_pr_document_flow IS 'Complete document flow from PR to PO to GRN';
COMMENT ON FUNCTION get_pr_dashboard_stats(TEXT, DATE, DATE) IS 'Dashboard KPI statistics with optional filtering';
COMMENT ON FUNCTION get_pr_trend_data(INT, TEXT) IS 'PR trend data for time-series charts';

-- ============================================================================
-- END OF PR_ANALYTICS_VIEWS.sql
-- ============================================================================
