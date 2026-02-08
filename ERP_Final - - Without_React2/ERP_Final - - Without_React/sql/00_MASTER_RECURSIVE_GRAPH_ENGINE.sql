-- ============================================================================
-- 00_MASTER_RECURSIVE_GRAPH_ENGINE.sql
-- SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE
-- 
-- RUN THIS FILE TO INSTALL THE COMPLETE DOCUMENT FLOW SYSTEM
-- 
-- Author: Enterprise ERP Migration Team
-- Version: 2.0 (Recursive Graph Engine)
-- 
-- IMPORTANT: This replaces the old static-join document flow system with
-- a true recursive graph traversal engine that supports many-to-many
-- relationships across the procurement chain: PR ↔ PO ↔ GRN ↔ PUR
-- ============================================================================

-- ============================================================================
-- EXECUTION ORDER:
-- 1. Recursive Graph Function (core engine)
-- 2. Document Flow Views (flattened results)
-- 3. Item Flow Views (SAP EKBE-style quantity tracking)
-- 4. Document Flow Triggers (optional audit logging)
-- 5. Backfill Script (one-time data migration)
-- 6. Performance Indexes
-- ============================================================================

\echo '=============================================='
\echo 'SAP VBFA-GRADE RECURSIVE DOCUMENT GRAPH ENGINE'
\echo '=============================================='
\echo ''

-- ============================================================================
-- STEP 1: RECURSIVE DOCUMENT GRAPH FUNCTION
-- ============================================================================
\echo 'Step 1: Creating recursive graph function...'
\i 01_RECURSIVE_DOCUMENT_GRAPH.sql
\echo 'Step 1: COMPLETE'
\echo ''

-- ============================================================================
-- STEP 2: DOCUMENT FLOW VIEWS
-- ============================================================================
\echo 'Step 2: Creating document flow views...'
\i 02_DOCUMENT_FLOW_RECURSIVE_VIEW.sql
\echo 'Step 2: COMPLETE'
\echo ''

-- ============================================================================
-- STEP 3: ITEM FLOW VIEWS (EKBE)
-- ============================================================================
\echo 'Step 3: Creating item flow views...'
\i 03_ITEM_FLOW_RECURSIVE.sql
\echo 'Step 3: COMPLETE'
\echo ''

-- ============================================================================
-- STEP 4: DOCUMENT FLOW TRIGGERS
-- ============================================================================
\echo 'Step 4: Creating document flow triggers...'
\i 04_DOCUMENT_FLOW_TRIGGERS.sql
\echo 'Step 4: COMPLETE'
\echo ''

-- ============================================================================
-- STEP 5: BACKFILL EXISTING DATA
-- ============================================================================
\echo 'Step 5: Backfilling existing data...'
\i 05_BACKFILL_GRAPH.sql
\echo 'Step 5: COMPLETE'
\echo ''

-- ============================================================================
-- STEP 6: PERFORMANCE INDEXES
-- ============================================================================
\echo 'Step 6: Creating performance indexes...'
\i 06_INDEXES.sql
\echo 'Step 6: COMPLETE'
\echo ''

-- ============================================================================
-- VERIFICATION
-- ============================================================================
\echo '=============================================='
\echo 'VERIFICATION'
\echo '=============================================='

-- Check functions exist
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN ('fn_recursive_document_graph', 'fn_get_document_flow');

-- Check views exist
SELECT viewname FROM pg_views 
WHERE schemaname = 'public' 
  AND viewname IN (
    'v_document_flow_recursive',
    'v_pr_complete_chain',
    'v_po_complete_chain',
    'v_grn_complete_chain',
    'v_pur_complete_chain',
    'v_item_flow',
    'v_item_flow_simple',
    'v_item_flow_recursive'
  );

-- Count indexes created
SELECT COUNT(*) AS index_count 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND indexname LIKE 'idx_%';

\echo ''
\echo '=============================================='
\echo 'INSTALLATION COMPLETE!'
\echo '=============================================='
\echo ''
\echo 'The SAP VBFA-grade recursive document graph engine is now installed.'
\echo ''
\echo 'KEY FEATURES:'
\echo '  - Recursive graph traversal using WITH RECURSIVE CTE'
\echo '  - Supports many-to-many relationships'
\echo '  - Bidirectional traversal: PR ↔ PO ↔ GRN ↔ PUR'
\echo '  - Item-level quantity tracking (EKBE style)'
\echo '  - Audit trail logging (optional)'
\echo ''
\echo 'USAGE:'
\echo '  -- From PR'
\echo '  SELECT * FROM fn_recursive_document_graph(''PR'', ''uuid-here''::UUID, NULL);'
\echo ''
\echo '  -- From PO'
\echo '  SELECT * FROM fn_recursive_document_graph(''PO'', NULL, 123);'
\echo ''
\echo '  -- From GRN'
\echo '  SELECT * FROM fn_recursive_document_graph(''GRN'', ''uuid-here''::UUID, NULL);'
\echo ''
\echo '  -- From PUR'
\echo '  SELECT * FROM fn_recursive_document_graph(''PUR'', ''uuid-here''::UUID, NULL);'
\echo ''
\echo '  -- Legacy format (backwards compatible)'
\echo '  SELECT * FROM fn_get_document_flow(''PR'', ''uuid-here'');'
\echo ''
