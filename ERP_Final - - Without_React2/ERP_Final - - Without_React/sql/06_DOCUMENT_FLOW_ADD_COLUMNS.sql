-- ============================================================================
-- 06_DOCUMENT_FLOW_ADD_COLUMNS.sql
-- FIX: "column source_number of relation document_flow does not exist"
-- RUN THIS IN SUPABASE SQL EDITOR when Create GRN fails with that error.
-- ============================================================================
-- Your document_flow table may have been created with only:
--   source_type, source_id, target_type, target_id, created_at
-- Triggers (trg_grn_document_flow on grn_inspections) and frontend write
-- source_number, target_number, flow_type — add them here.
-- ============================================================================

ALTER TABLE document_flow ADD COLUMN IF NOT EXISTS source_number text;
ALTER TABLE document_flow ADD COLUMN IF NOT EXISTS target_number text;
ALTER TABLE document_flow ADD COLUMN IF NOT EXISTS flow_type text;

-- Indexes for number-based lookups (safe: IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_document_flow_source_number ON document_flow(source_type, source_number) WHERE source_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_document_flow_target_number ON document_flow(target_type, target_number) WHERE target_number IS NOT NULL;

-- Verify (optional): SELECT column_name FROM information_schema.columns WHERE table_name = 'document_flow';
