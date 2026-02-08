-- ============================================================================
-- 05_indexes.sql
-- PERFORMANCE INDEXES FOR RECURSIVE GRAPH TRAVERSAL
-- ============================================================================
-- Required for fn_trace_document_graph and document flow views.
-- ============================================================================

-- pr_po_linkage (PR ↔ PO)
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_item_id ON pr_po_linkage(pr_item_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_status ON pr_po_linkage(status);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_composite ON pr_po_linkage(pr_id, po_id, status);

-- grn_inspections (PO ↔ GRN)
CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_deleted ON grn_inspections(deleted);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_status ON grn_inspections(status);
CREATE INDEX IF NOT EXISTS idx_grn_inspections_composite ON grn_inspections(purchase_order_id, deleted, status);

-- grn_inspection_items
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_po_item ON grn_inspection_items(po_item_id);

-- purchasing_invoices (GRN ↔ PUR, PO ↔ PUR)
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_po_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_deleted ON purchasing_invoices(deleted);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_status ON purchasing_invoices(status);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_composite ON purchasing_invoices(grn_id, purchase_order_id, deleted);

-- purchasing_invoice_items
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_invoice_id ON purchasing_invoice_items(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_invoice_items_item_id ON purchasing_invoice_items(item_id);

-- purchase_requests / purchase_orders
CREATE INDEX IF NOT EXISTS idx_purchase_requests_deleted ON purchase_requests(deleted);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_pr_id ON purchase_request_items(pr_id);
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_item_id ON purchase_request_items(item_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_deleted ON purchase_orders(deleted);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_item_id ON purchase_order_items(item_id);

ANALYZE pr_po_linkage;
ANALYZE grn_inspections;
ANALYZE grn_inspection_items;
ANALYZE purchasing_invoices;
ANALYZE purchasing_invoice_items;
ANALYZE purchase_requests;
ANALYZE purchase_request_items;
ANALYZE purchase_orders;
ANALYZE purchase_order_items;
