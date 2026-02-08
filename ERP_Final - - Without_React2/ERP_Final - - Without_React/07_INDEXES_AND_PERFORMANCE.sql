-- 07_INDEXES_AND_PERFORMANCE.sql

CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_pr_id ON pr_po_linkage(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_po_linkage_po_id ON pr_po_linkage(po_id);
CREATE INDEX IF NOT EXISTS idx_grn_items_po_id ON grn_inspection_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_items_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_doc_flow_source ON document_flow(source_id, source_type);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target ON document_flow(target_id, target_type);
CREATE INDEX IF NOT EXISTS idx_po_items_po_id ON purchase_order_items(purchase_order_id);
