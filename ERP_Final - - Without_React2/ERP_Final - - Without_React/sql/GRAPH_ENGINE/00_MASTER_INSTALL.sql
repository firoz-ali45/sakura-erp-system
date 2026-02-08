-- ============================================================================
-- 00_MASTER_INSTALL.sql
-- SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE - MASTER INSTALLER
-- 
-- RUN THIS FILE TO INSTALL THE COMPLETE DOCUMENT FLOW SYSTEM
-- 
-- CRITICAL: This engine uses recursive CTE traversal on relational tables.
-- The document_flow table is ONLY for audit logging - NOT source of truth.
-- 
-- Source of truth tables:
--   - pr_po_linkage       (PR ↔ PO)
--   - grn_inspections     (PO ↔ GRN)
--   - purchasing_invoices (GRN ↔ PUR, PO ↔ PUR)
-- ============================================================================

\echo '============================================================'
\echo 'SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE'
\echo 'Enterprise ERP Migration - Version 3.0'
\echo '============================================================'
\echo ''

-- ============================================================================
-- STEP 1: RECURSIVE DOCUMENT GRAPH FUNCTION
-- ============================================================================
\echo 'Step 1: Creating recursive graph functions...'
\i 01_RECURSIVE_DOCUMENT_GRAPH.sql
\echo 'Step 1: COMPLETE ✓'
\echo ''

-- ============================================================================
-- STEP 2: DOCUMENT FLOW VIEWS
-- ============================================================================
\echo 'Step 2: Creating document flow views...'
\i 02_DOCUMENT_FLOW_RECURSIVE_VIEW.sql
\echo 'Step 2: COMPLETE ✓'
\echo ''

-- ============================================================================
-- STEP 3: ITEM FLOW VIEWS (EKBE)
-- ============================================================================
\echo 'Step 3: Creating item flow views...'
\i 03_ITEM_FLOW_RECURSIVE.sql
\echo 'Step 3: COMPLETE ✓'
\echo ''

-- ============================================================================
-- STEP 4: DOCUMENT FLOW TRIGGERS (AUDIT)
-- ============================================================================
\echo 'Step 4: Creating document flow triggers...'
\i 04_DOCUMENT_FLOW_TRIGGERS.sql
\echo 'Step 4: COMPLETE ✓'
\echo ''

-- ============================================================================
-- STEP 5: BACKFILL EXISTING DATA
-- ============================================================================
\echo 'Step 5: Backfilling existing data...'
\i 05_BACKFILL_GRAPH.sql
\echo 'Step 5: COMPLETE ✓'
\echo ''

-- ============================================================================
-- STEP 6: PERFORMANCE INDEXES
-- ============================================================================
\echo 'Step 6: Creating performance indexes...'
\i 06_INDEXES.sql
\echo 'Step 6: COMPLETE ✓'
\echo ''

-- ============================================================================
-- VERIFICATION
-- ============================================================================
\echo '============================================================'
\echo 'VERIFICATION'
\echo '============================================================'

-- Check functions exist
SELECT 
    'FUNCTION' AS object_type,
    p.proname AS object_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN (
    'fn_recursive_document_graph',
    'fn_get_document_flow',
    'fn_get_document_flow_json',
    'fn_get_item_flow'
  )
ORDER BY p.proname;

-- Check views exist
SELECT 
    'VIEW' AS object_type,
    viewname AS object_name,
    'OK' AS status
FROM pg_views 
WHERE schemaname = 'public' 
  AND viewname IN (
    'v_document_flow_recursive',
    'v_pr_complete_chain',
    'v_po_complete_chain',
    'v_grn_complete_chain',
    'v_pur_complete_chain',
    'v_document_flow_full_chain',
    'v_item_flow_recursive',
    'v_item_flow_simple',
    'v_item_flow_by_po',
    'v_item_flow_by_grn'
  )
ORDER BY viewname;

-- Count indexes
SELECT 
    'INDEXES' AS object_type,
    tablename AS table_name,
    COUNT(*) AS index_count
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN (
    'pr_po_linkage',
    'grn_inspections',
    'grn_inspection_items',
    'purchasing_invoices',
    'purchasing_invoice_items'
  )
GROUP BY tablename
ORDER BY tablename;

\echo ''
\echo '============================================================'
\echo 'INSTALLATION COMPLETE!'
\echo '============================================================'
\echo ''
\echo 'KEY FEATURES:'
\echo '  ✓ Recursive graph traversal using WITH RECURSIVE CTE'
\echo '  ✓ Supports many-to-many relationships'
\echo '  ✓ Bidirectional traversal: PR ↔ PO ↔ GRN ↔ PUR'
\echo '  ✓ Item-level quantity tracking (SAP EKBE style)'
\echo '  ✓ Audit trail logging (optional)'
\echo '  ✓ Performance indexes'
\echo ''
\echo 'USAGE EXAMPLES:'
\echo ''
\echo '  -- Get document flow from PR (returns JSON)'
\echo '  SELECT fn_get_document_flow_json(''PR'', ''uuid-here'');'
\echo ''
\echo '  -- Get document flow from PO (returns table)'
\echo '  SELECT * FROM fn_get_document_flow(''PO'', ''123'');'
\echo ''
\echo '  -- Full recursive graph (returns JSONB with arrays)'
\echo '  SELECT fn_recursive_document_graph(''GRN'', ''uuid''::UUID, NULL);'
\echo ''
\echo '  -- Item flow for PR'
\echo '  SELECT * FROM v_item_flow_recursive WHERE pr_id = ''uuid'';'
\echo ''
\echo '============================================================'
