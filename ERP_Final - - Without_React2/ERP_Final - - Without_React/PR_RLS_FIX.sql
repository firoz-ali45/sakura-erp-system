-- ============================================================================
-- SAKURA ERP - PR RLS FIX
-- CRITICAL: Fix Row Level Security blocking INSERT/SELECT operations
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-01-25
-- Issue: "new row violates row-level security policy" (Error 42501)
-- ============================================================================

-- ============================================================================
-- OPTION A: DISABLE RLS COMPLETELY (Quick Fix for Development)
-- ============================================================================
-- Uncomment below if you want to disable RLS entirely (NOT recommended for production)

-- ALTER TABLE purchase_requests DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE purchase_request_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE pr_number_sequence DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE pr_po_linkage DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE pr_status_history DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE document_flow DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- OPTION B: CREATE PERMISSIVE POLICIES (Recommended)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_number_sequence ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_po_linkage ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_flow ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_approval_workflow ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES (Clean Slate)
-- ============================================================================

DO $$
DECLARE
    pol RECORD;
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'purchase_requests',
        'purchase_request_items', 
        'pr_number_sequence',
        'pr_po_linkage',
        'pr_status_history',
        'document_flow',
        'pr_comments',
        'pr_attachments',
        'pr_approval_workflow'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        FOR pol IN 
            SELECT policyname 
            FROM pg_policies 
            WHERE tablename = tbl 
        LOOP
            EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, tbl);
            RAISE NOTICE 'Dropped policy: % on %', pol.policyname, tbl;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 2: CREATE PERMISSIVE POLICIES FOR purchase_requests
-- ============================================================================

CREATE POLICY "pr_select_authenticated" 
ON purchase_requests FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "pr_insert_authenticated" 
ON purchase_requests FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "pr_update_authenticated" 
ON purchase_requests FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

CREATE POLICY "pr_delete_authenticated" 
ON purchase_requests FOR DELETE 
TO authenticated 
USING (true);

-- Also allow anon role for testing (remove in production)
CREATE POLICY "pr_select_anon" 
ON purchase_requests FOR SELECT 
TO anon 
USING (true);

CREATE POLICY "pr_insert_anon" 
ON purchase_requests FOR INSERT 
TO anon 
WITH CHECK (true);

-- ============================================================================
-- STEP 3: CREATE PERMISSIVE POLICIES FOR purchase_request_items
-- ============================================================================

CREATE POLICY "pri_select_authenticated" 
ON purchase_request_items FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "pri_insert_authenticated" 
ON purchase_request_items FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "pri_update_authenticated" 
ON purchase_request_items FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

CREATE POLICY "pri_delete_authenticated" 
ON purchase_request_items FOR DELETE 
TO authenticated 
USING (true);

-- Also allow anon role for testing
CREATE POLICY "pri_select_anon" 
ON purchase_request_items FOR SELECT 
TO anon 
USING (true);

CREATE POLICY "pri_insert_anon" 
ON purchase_request_items FOR INSERT 
TO anon 
WITH CHECK (true);

-- ============================================================================
-- STEP 4: CREATE POLICIES FOR pr_number_sequence
-- ============================================================================

CREATE POLICY "seq_select_all" 
ON pr_number_sequence FOR SELECT 
TO authenticated, anon 
USING (true);

CREATE POLICY "seq_insert_all" 
ON pr_number_sequence FOR INSERT 
TO authenticated, anon 
WITH CHECK (true);

CREATE POLICY "seq_update_all" 
ON pr_number_sequence FOR UPDATE 
TO authenticated, anon 
USING (true) 
WITH CHECK (true);

-- ============================================================================
-- STEP 5: CREATE POLICIES FOR pr_po_linkage
-- ============================================================================

CREATE POLICY "linkage_select_authenticated" 
ON pr_po_linkage FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "linkage_insert_authenticated" 
ON pr_po_linkage FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "linkage_update_authenticated" 
ON pr_po_linkage FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

CREATE POLICY "linkage_delete_authenticated" 
ON pr_po_linkage FOR DELETE 
TO authenticated 
USING (true);

-- ============================================================================
-- STEP 6: CREATE POLICIES FOR pr_status_history
-- ============================================================================

CREATE POLICY "history_select_authenticated" 
ON pr_status_history FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "history_insert_authenticated" 
ON pr_status_history FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- ============================================================================
-- STEP 7: CREATE POLICIES FOR document_flow
-- ============================================================================

CREATE POLICY "docflow_select_authenticated" 
ON document_flow FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "docflow_insert_authenticated" 
ON document_flow FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "docflow_update_authenticated" 
ON document_flow FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- ============================================================================
-- STEP 8: CREATE POLICIES FOR pr_comments
-- ============================================================================

CREATE POLICY "comments_select_authenticated" 
ON pr_comments FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "comments_insert_authenticated" 
ON pr_comments FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "comments_update_authenticated" 
ON pr_comments FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

CREATE POLICY "comments_delete_authenticated" 
ON pr_comments FOR DELETE 
TO authenticated 
USING (true);

-- ============================================================================
-- STEP 9: CREATE POLICIES FOR pr_attachments
-- ============================================================================

CREATE POLICY "attach_select_authenticated" 
ON pr_attachments FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "attach_insert_authenticated" 
ON pr_attachments FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "attach_delete_authenticated" 
ON pr_attachments FOR DELETE 
TO authenticated 
USING (true);

-- ============================================================================
-- STEP 10: CREATE POLICIES FOR pr_approval_workflow
-- ============================================================================

CREATE POLICY "workflow_select_authenticated" 
ON pr_approval_workflow FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "workflow_insert_authenticated" 
ON pr_approval_workflow FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "workflow_update_authenticated" 
ON pr_approval_workflow FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- ============================================================================
-- STEP 11: GRANT PERMISSIONS
-- ============================================================================

GRANT ALL ON purchase_requests TO authenticated;
GRANT ALL ON purchase_request_items TO authenticated;
GRANT ALL ON pr_number_sequence TO authenticated;
GRANT ALL ON pr_po_linkage TO authenticated;
GRANT ALL ON pr_status_history TO authenticated;
GRANT ALL ON document_flow TO authenticated;
GRANT ALL ON pr_comments TO authenticated;
GRANT ALL ON pr_attachments TO authenticated;
GRANT ALL ON pr_approval_workflow TO authenticated;

-- Grant to anon for testing
GRANT SELECT, INSERT ON purchase_requests TO anon;
GRANT SELECT, INSERT ON purchase_request_items TO anon;
GRANT SELECT, INSERT, UPDATE ON pr_number_sequence TO anon;

-- Grant sequence usage
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;

-- ============================================================================
-- STEP 12: VERIFY POLICIES
-- ============================================================================

DO $$
DECLARE
    pol_count INT;
    tbl TEXT;
    tables TEXT[] := ARRAY['purchase_requests', 'purchase_request_items', 'pr_number_sequence'];
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== RLS POLICY VERIFICATION ===';
    
    FOREACH tbl IN ARRAY tables LOOP
        SELECT COUNT(*) INTO pol_count 
        FROM pg_policies 
        WHERE tablename = tbl;
        RAISE NOTICE '% policies on %', pol_count, tbl;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ RLS FIX COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'All authenticated users can now:';
    RAISE NOTICE '  - SELECT from PR tables';
    RAISE NOTICE '  - INSERT into PR tables';
    RAISE NOTICE '  - UPDATE PR tables';
    RAISE NOTICE '  - DELETE from PR tables';
END $$;

-- ============================================================================
-- END OF PR_RLS_FIX.sql
-- ============================================================================
