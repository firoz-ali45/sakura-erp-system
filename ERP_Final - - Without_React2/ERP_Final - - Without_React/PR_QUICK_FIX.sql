-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST QUICK FIX & RLS SETUP
-- Run this in Supabase SQL Editor to enable PR module
-- ============================================================================
-- Version: 2.0.0
-- Date: 2026-01-25
-- Purpose: Fix RLS, enable PR CRUD, setup triggers
-- ============================================================================

-- ============================================================================
-- 1) ENSURE TABLES EXIST WITH CORRECT STRUCTURE
-- ============================================================================

-- Ensure pr_number_sequence exists
CREATE TABLE IF NOT EXISTS pr_number_sequence (
    id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL UNIQUE,
    last_number INTEGER NOT NULL DEFAULT 0,
    prefix TEXT DEFAULT 'PR',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize sequence for current year if not exists
INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
VALUES (EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, NOW())
ON CONFLICT (fiscal_year) DO NOTHING;

-- Ensure purchase_requests has all required columns
DO $$
BEGIN
    -- Add submitted_for_approval if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'purchase_requests' AND column_name = 'submitted_for_approval') THEN
        ALTER TABLE purchase_requests ADD COLUMN submitted_for_approval BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add submitted_for_approval_at if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'purchase_requests' AND column_name = 'submitted_for_approval_at') THEN
        ALTER TABLE purchase_requests ADD COLUMN submitted_for_approval_at TIMESTAMPTZ;
    END IF;
    
    -- Add deleted column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'purchase_requests' AND column_name = 'deleted') THEN
        ALTER TABLE purchase_requests ADD COLUMN deleted BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- ============================================================================
-- 2) PR NUMBER GENERATOR FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_pr_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_year INT;
    v_sequence INT;
    v_pr_number TEXT;
BEGIN
    v_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
    
    -- Upsert to get next number atomically
    INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
    VALUES (v_year, 1, NOW())
    ON CONFLICT (fiscal_year) 
    DO UPDATE SET 
        last_number = pr_number_sequence.last_number + 1,
        updated_at = NOW()
    RETURNING last_number INTO v_sequence;
    
    v_pr_number := 'PR-' || v_year::TEXT || '-' || LPAD(v_sequence::TEXT, 6, '0');
    
    RETURN v_pr_number;
END;
$$;

-- ============================================================================
-- 3) TRIGGER FOR AUTO PR NUMBER GENERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pr_number_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Generate PR number if not provided
    IF NEW.pr_number IS NULL OR NEW.pr_number = '' THEN
        NEW.pr_number := generate_pr_number();
    END IF;
    
    -- Set timestamps
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    NEW.updated_at := NOW();
    
    -- Set default status
    IF NEW.status IS NULL THEN
        NEW.status := 'draft';
    END IF;
    
    -- Set business_date to today if not provided
    IF NEW.business_date IS NULL THEN
        NEW.business_date := CURRENT_DATE;
    END IF;
    
    -- Set deleted to false
    IF NEW.deleted IS NULL THEN
        NEW.deleted := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS tr_purchase_requests_pr_number ON purchase_requests;
CREATE TRIGGER tr_purchase_requests_pr_number
    BEFORE INSERT ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION set_pr_number_on_insert();

-- ============================================================================
-- 4) RLS POLICIES - ALLOW ALL AUTHENTICATED USERS
-- ============================================================================

-- Enable RLS on all PR tables
ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_number_sequence ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- DROP ALL EXISTING POLICIES (Clean Slate)
-- ============================================================================

DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Drop purchase_requests policies
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'purchase_requests' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON purchase_requests', pol.policyname);
    END LOOP;
    
    -- Drop purchase_request_items policies
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'purchase_request_items' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON purchase_request_items', pol.policyname);
    END LOOP;
    
    -- Drop pr_number_sequence policies
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'pr_number_sequence' LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON pr_number_sequence', pol.policyname);
    END LOOP;
END $$;

-- ============================================================================
-- CREATE NEW PERMISSIVE POLICIES
-- ============================================================================

-- Purchase Requests - Full access for authenticated users
CREATE POLICY "pr_authenticated_select" ON purchase_requests
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "pr_authenticated_insert" ON purchase_requests
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "pr_authenticated_update" ON purchase_requests
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "pr_authenticated_delete" ON purchase_requests
    FOR DELETE TO authenticated USING (true);

-- Purchase Request Items - Full access for authenticated users
CREATE POLICY "pri_authenticated_select" ON purchase_request_items
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "pri_authenticated_insert" ON purchase_request_items
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "pri_authenticated_update" ON purchase_request_items
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "pri_authenticated_delete" ON purchase_request_items
    FOR DELETE TO authenticated USING (true);

-- PR Number Sequence - Full access for authenticated users
CREATE POLICY "seq_authenticated_select" ON pr_number_sequence
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "seq_authenticated_insert" ON pr_number_sequence
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "seq_authenticated_update" ON pr_number_sequence
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- 5) GRANT PERMISSIONS
-- ============================================================================

GRANT ALL ON purchase_requests TO authenticated;
GRANT ALL ON purchase_request_items TO authenticated;
GRANT ALL ON pr_number_sequence TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- 6) HELPER FUNCTIONS
-- ============================================================================

-- Get next PR number preview (without consuming)
CREATE OR REPLACE FUNCTION get_next_pr_number_preview()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_year INT;
    v_next_sequence INT;
BEGIN
    v_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
    
    SELECT COALESCE(last_number, 0) + 1 INTO v_next_sequence
    FROM pr_number_sequence
    WHERE fiscal_year = v_year;
    
    IF v_next_sequence IS NULL THEN
        v_next_sequence := 1;
    END IF;
    
    RETURN 'PR-' || v_year::TEXT || '-' || LPAD(v_next_sequence::TEXT, 6, '0');
END;
$$;

-- Submit PR for approval
CREATE OR REPLACE FUNCTION submit_pr_for_approval(p_pr_id UUID, p_notes TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
BEGIN
    -- Get current PR
    SELECT * INTO v_pr FROM purchase_requests WHERE id = p_pr_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR not found');
    END IF;
    
    IF v_pr.status != 'draft' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only draft PRs can be submitted');
    END IF;
    
    -- Update PR status
    UPDATE purchase_requests
    SET status = 'submitted',
        submitted_for_approval = TRUE,
        submitted_for_approval_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_pr_id;
    
    RETURN jsonb_build_object('success', true, 'pr_id', p_pr_id, 'status', 'submitted');
END;
$$;

-- Approve PR
CREATE OR REPLACE FUNCTION approve_pr(p_pr_id UUID, p_notes TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE purchase_requests
    SET status = 'approved',
        approved_at = NOW(),
        approved_by = auth.uid(),
        approval_notes = p_notes,
        updated_at = NOW()
    WHERE id = p_pr_id AND status IN ('submitted', 'under_review');
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR not found or not in submittable status');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'pr_id', p_pr_id, 'status', 'approved');
END;
$$;

-- Reject PR
CREATE OR REPLACE FUNCTION reject_pr(p_pr_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rejection reason is required');
    END IF;
    
    UPDATE purchase_requests
    SET status = 'rejected',
        rejection_reason = p_reason,
        rejected_at = NOW(),
        rejected_by = auth.uid(),
        updated_at = NOW()
    WHERE id = p_pr_id AND status IN ('submitted', 'under_review');
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR not found or not in reviewable status');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'pr_id', p_pr_id, 'status', 'rejected');
END;
$$;

-- Dashboard Stats
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
    v_result JSONB;
BEGIN
    WITH filtered_prs AS (
        SELECT *
        FROM purchase_requests
        WHERE deleted = FALSE
          AND (p_department IS NULL OR department = p_department)
          AND (p_start_date IS NULL OR business_date >= p_start_date)
          AND (p_end_date IS NULL OR business_date <= p_end_date)
    )
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
        'overdue_count', COUNT(*) FILTER (WHERE required_date < CURRENT_DATE AND status NOT IN ('closed', 'cancelled', 'fully_ordered')),
        'high_priority_count', COUNT(*) FILTER (WHERE priority IN ('high', 'urgent', 'critical'))
    ) INTO v_result
    FROM filtered_prs;
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- 7) GRANT EXECUTE ON FUNCTIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION generate_pr_number() TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_pr_number_preview() TO authenticated;
GRANT EXECUTE ON FUNCTION submit_pr_for_approval(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_pr(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_pr(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pr_dashboard_stats(TEXT, DATE, DATE) TO authenticated;

-- ============================================================================
-- 8) ENSURE DEFAULT VALUES ARE SET
-- ============================================================================

-- Set default for deleted column
ALTER TABLE purchase_requests ALTER COLUMN deleted SET DEFAULT FALSE;
ALTER TABLE purchase_request_items ALTER COLUMN deleted SET DEFAULT FALSE;

-- Update any NULL deleted values
UPDATE purchase_requests SET deleted = FALSE WHERE deleted IS NULL;
UPDATE purchase_request_items SET deleted = FALSE WHERE deleted IS NULL;

-- ============================================================================
-- 9) CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_status ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_pr_department ON purchase_requests(department);
CREATE INDEX IF NOT EXISTS idx_pr_deleted ON purchase_requests(deleted);
CREATE INDEX IF NOT EXISTS idx_pr_created_at ON purchase_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pr_business_date ON purchase_requests(business_date);
CREATE INDEX IF NOT EXISTS idx_pr_requester_id ON purchase_requests(requester_id);

CREATE INDEX IF NOT EXISTS idx_pri_pr_id ON purchase_request_items(pr_id);
CREATE INDEX IF NOT EXISTS idx_pri_item_id ON purchase_request_items(item_id);
CREATE INDEX IF NOT EXISTS idx_pri_deleted ON purchase_request_items(deleted);

-- ============================================================================
-- 10) VERIFICATION TEST
-- ============================================================================

DO $$
DECLARE
    v_test_number TEXT;
    v_pr_count INT;
    v_policy_count INT;
BEGIN
    -- Test PR number generation
    SELECT generate_pr_number() INTO v_test_number;
    RAISE NOTICE '✅ PR Number Generated: %', v_test_number;
    
    -- Test preview function
    SELECT get_next_pr_number_preview() INTO v_test_number;
    RAISE NOTICE '✅ Next PR Number Preview: %', v_test_number;
    
    -- Count PRs
    SELECT COUNT(*) INTO v_pr_count FROM purchase_requests WHERE deleted = FALSE;
    RAISE NOTICE '✅ Total PRs in database: %', v_pr_count;
    
    -- Count policies
    SELECT COUNT(*) INTO v_policy_count FROM pg_policies WHERE tablename = 'purchase_requests';
    RAISE NOTICE '✅ RLS Policies on purchase_requests: %', v_policy_count;
    
    SELECT COUNT(*) INTO v_policy_count FROM pg_policies WHERE tablename = 'purchase_request_items';
    RAISE NOTICE '✅ RLS Policies on purchase_request_items: %', v_policy_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ PR QUICK FIX COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'You can now:';
    RAISE NOTICE '1. Create new Purchase Requests';
    RAISE NOTICE '2. View PRs in the list';
    RAISE NOTICE '3. Submit PRs for approval';
    RAISE NOTICE '4. Approve/Reject PRs';
END $$;

-- ============================================================================
-- END OF PR_QUICK_FIX.sql
-- ============================================================================
