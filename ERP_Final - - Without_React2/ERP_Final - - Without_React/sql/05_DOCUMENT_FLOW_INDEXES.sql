-- ============================================================================
-- 05_DOCUMENT_FLOW_INDEXES.sql
-- PERFORMANCE INDEXES FOR DOCUMENT FLOW
-- ============================================================================

-- ============================================================================
-- PR_PO_LINKAGE Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id 
    ON pr_po_linkage(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id 
    ON pr_po_linkage(po_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id 
    ON pr_po_linkage(pr_item_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status 
    ON pr_po_linkage(status) 
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_po_active 
    ON pr_po_linkage(pr_id, po_id) 
    WHERE status = 'active';

-- ============================================================================
-- PURCHASE_REQUEST_ITEMS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pri_pr_id 
    ON purchase_request_items(pr_id);

CREATE INDEX IF NOT EXISTS idx_pri_po_id 
    ON purchase_request_items(po_id) 
    WHERE po_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pri_item_id 
    ON purchase_request_items(item_id);

CREATE INDEX IF NOT EXISTS idx_pri_status 
    ON purchase_request_items(status);

-- ============================================================================
-- PURCHASE_ORDERS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_po_status 
    ON purchase_orders(status) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_po_receiving_status 
    ON purchase_orders(receiving_status) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_po_supplier_id 
    ON purchase_orders(supplier_id);

-- ============================================================================
-- PURCHASE_ORDER_ITEMS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_poi_po_id 
    ON purchase_order_items(purchase_order_id);

CREATE INDEX IF NOT EXISTS idx_poi_item_id 
    ON purchase_order_items(item_id);

-- ============================================================================
-- GRN_INSPECTIONS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_grn_po_id 
    ON grn_inspections(purchase_order_id) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_grn_status 
    ON grn_inspections(status) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_grn_number 
    ON grn_inspections(grn_number);

-- ============================================================================
-- GRN_INSPECTION_ITEMS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_gii_grn_id 
    ON grn_inspection_items(grn_inspection_id);

CREATE INDEX IF NOT EXISTS idx_gii_po_id 
    ON grn_inspection_items(purchase_order_id) 
    WHERE purchase_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gii_item_id 
    ON grn_inspection_items(item_id);

-- ============================================================================
-- PURCHASING_INVOICES Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pi_grn_id 
    ON purchasing_invoices(grn_id) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pi_po_id 
    ON purchasing_invoices(purchase_order_id) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pi_status 
    ON purchasing_invoices(status) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pi_payment_status 
    ON purchasing_invoices(payment_status) 
    WHERE deleted = FALSE;

-- ============================================================================
-- DOCUMENT_FLOW Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_df_source 
    ON document_flow(source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_df_target 
    ON document_flow(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_df_source_number 
    ON document_flow(source_number) 
    WHERE source_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_df_target_number 
    ON document_flow(target_number) 
    WHERE target_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_df_flow_type 
    ON document_flow(flow_type);

-- Composite index for common lookups
CREATE INDEX IF NOT EXISTS idx_df_source_target 
    ON document_flow(source_type, source_id, target_type, target_id);

-- ============================================================================
-- PURCHASE_REQUESTS Indexes
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pr_status 
    ON purchase_requests(status) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pr_requester 
    ON purchase_requests(requester_id) 
    WHERE deleted = FALSE;

-- ============================================================================
-- ANALYZE TABLES for query optimization
-- ============================================================================
ANALYZE pr_po_linkage;
ANALYZE purchase_request_items;
ANALYZE purchase_orders;
ANALYZE purchase_order_items;
ANALYZE grn_inspections;
ANALYZE grn_inspection_items;
ANALYZE purchasing_invoices;
ANALYZE document_flow;
ANALYZE purchase_requests;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN (
    'pr_po_linkage',
    'purchase_request_items',
    'purchase_orders',
    'purchase_order_items',
    'grn_inspections',
    'grn_inspection_items',
    'purchasing_invoices',
    'document_flow',
    'purchase_requests'
)
ORDER BY tablename, indexname;
