-- ============================================================================
-- 06_INDEXES.sql
-- PERFORMANCE INDEXES FOR DOCUMENT GRAPH ENGINE
-- 
-- Critical for recursive graph traversal performance
-- ============================================================================

-- ============================================================================
-- PR_PO_LINKAGE INDEXES
-- Used for PR ↔ PO traversal
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id 
    ON pr_po_linkage(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id 
    ON pr_po_linkage(po_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id 
    ON pr_po_linkage(pr_item_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_item_id 
    ON pr_po_linkage(po_item_id);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status 
    ON pr_po_linkage(status);

-- Composite index for common lookups
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_status 
    ON pr_po_linkage(pr_id, status);

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_status 
    ON pr_po_linkage(po_id, status);

-- ============================================================================
-- GRN_INSPECTIONS INDEXES
-- Used for PO ↔ GRN traversal
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_grn_inspections_purchase_order_id 
    ON grn_inspections(purchase_order_id);

CREATE INDEX IF NOT EXISTS idx_grn_inspections_status 
    ON grn_inspections(status);

CREATE INDEX IF NOT EXISTS idx_grn_inspections_deleted 
    ON grn_inspections(deleted);

-- Composite index for active GRNs by PO
CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_active 
    ON grn_inspections(purchase_order_id, deleted) 
    WHERE deleted = FALSE;

-- ============================================================================
-- GRN_INSPECTION_ITEMS INDEXES
-- Used for item-level flow tracking
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id 
    ON grn_inspection_items(grn_inspection_id);

CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_po_item_id 
    ON grn_inspection_items(po_item_id);

CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_item_id 
    ON grn_inspection_items(item_id);

-- ============================================================================
-- PURCHASING_INVOICES INDEXES
-- Used for GRN ↔ PUR and PO ↔ PUR traversal
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id 
    ON purchasing_invoices(grn_id);

CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_purchase_order_id 
    ON purchasing_invoices(purchase_order_id);

CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_status 
    ON purchasing_invoices(status);

CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_deleted 
    ON purchasing_invoices(deleted);

-- Composite index for active invoices
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_active 
    ON purchasing_invoices(grn_id, deleted) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_po_active 
    ON purchasing_invoices(purchase_order_id, deleted) 
    WHERE deleted = FALSE;

-- ============================================================================
-- PURCHASING_INVOICE_ITEMS INDEXES
-- Used for item-level flow tracking
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_invoice_id 
    ON purchasing_invoice_items(purchasing_invoice_id);

CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_item_id 
    ON purchasing_invoice_items(item_id);

-- ============================================================================
-- PURCHASE_REQUEST_ITEMS INDEXES
-- Used for PR item lookups
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_pr_id 
    ON purchase_request_items(pr_id);

CREATE INDEX IF NOT EXISTS idx_purchase_request_items_item_id 
    ON purchase_request_items(item_id);

-- ============================================================================
-- PURCHASE_ORDER_ITEMS INDEXES
-- Used for PO item lookups
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id 
    ON purchase_order_items(purchase_order_id);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_item_id 
    ON purchase_order_items(item_id);

-- ============================================================================
-- DOCUMENT_FLOW AUDIT TABLE INDEXES
-- For audit log queries (NOT used by recursive engine)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_document_flow_source 
    ON document_flow(source_type, source_id);

CREATE INDEX IF NOT EXISTS idx_document_flow_target 
    ON document_flow(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_document_flow_type 
    ON document_flow(flow_type);

CREATE INDEX IF NOT EXISTS idx_document_flow_created_at 
    ON document_flow(created_at DESC);

-- ============================================================================
-- PURCHASE_REQUESTS INDEXES
-- For status and deletion filtering
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchase_requests_deleted 
    ON purchase_requests(deleted);

CREATE INDEX IF NOT EXISTS idx_purchase_requests_status 
    ON purchase_requests(status);

-- ============================================================================
-- PURCHASE_ORDERS INDEXES
-- For status and deletion filtering
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_purchase_orders_deleted 
    ON purchase_orders(deleted);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_status 
    ON purchase_orders(status);

-- ============================================================================
-- ANALYZE TABLES
-- Update statistics for query planner
-- ============================================================================
ANALYZE pr_po_linkage;
ANALYZE grn_inspections;
ANALYZE grn_inspection_items;
ANALYZE purchasing_invoices;
ANALYZE purchasing_invoice_items;
ANALYZE purchase_request_items;
ANALYZE purchase_order_items;
ANALYZE document_flow;
ANALYZE purchase_requests;
ANALYZE purchase_orders;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
DECLARE
    v_index_count INT;
BEGIN
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname LIKE 'idx_%';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'INDEX CREATION COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total indexes created/verified: %', v_index_count;
    RAISE NOTICE '========================================';
END;
$$;

-- Show created indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'pr_po_linkage',
    'grn_inspections',
    'grn_inspection_items',
    'purchasing_invoices',
    'purchasing_invoice_items',
    'purchase_request_items',
    'purchase_order_items',
    'document_flow',
    'purchase_requests',
    'purchase_orders'
  )
ORDER BY tablename, indexname;
