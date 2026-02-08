-- 06_INDEXES.sql
-- PERFORMANCE OPTIMIZATION INDEXES
-- Linkage Tables
CREATE INDEX IF NOT EXISTS idx_pr_po_link_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_link_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_link_status ON pr_po_linkage(status);
-- GRN
CREATE INDEX IF NOT EXISTS idx_grn_po_id ON grn_inspections(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_deleted ON grn_inspections(deleted);
-- Invoice
CREATE INDEX IF NOT EXISTS idx_pur_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_pur_po_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_pur_deleted ON purchasing_invoices(deleted);
-- Document Flow Log
CREATE INDEX IF NOT EXISTS idx_doc_flow_source ON document_flow(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target ON document_flow(target_type, target_id);
-- Item Lookups
CREATE INDEX IF NOT EXISTS idx_grn_items_po_item ON grn_inspection_items(po_item_id);
CREATE INDEX IF NOT EXISTS idx_inv_items_pur_id ON purchasing_invoice_items(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_inv_items_item_id ON purchasing_invoice_items(item_id);