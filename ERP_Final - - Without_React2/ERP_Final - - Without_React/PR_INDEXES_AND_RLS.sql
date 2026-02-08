-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST INDEXES AND ROW LEVEL SECURITY
-- Enterprise Security & Performance Configuration
-- ============================================================================
-- File: PR_INDEXES_AND_RLS.sql
-- Purpose: Indexes for query optimization and RLS policies for data security
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- SECTION 1: INDEXES FOR purchase_requests TABLE
-- ============================================================================

-- Primary lookup index on PR number
CREATE INDEX IF NOT EXISTS idx_pr_number 
    ON purchase_requests(pr_number);

-- Status filtering (most common filter)
CREATE INDEX IF NOT EXISTS idx_pr_status 
    ON purchase_requests(status) 
    WHERE deleted = FALSE;

-- Department filtering
CREATE INDEX IF NOT EXISTS idx_pr_department 
    ON purchase_requests(department) 
    WHERE deleted = FALSE;

-- Requester lookup
CREATE INDEX IF NOT EXISTS idx_pr_requester_id 
    ON purchase_requests(requester_id);

-- Date range queries
CREATE INDEX IF NOT EXISTS idx_pr_business_date 
    ON purchase_requests(business_date DESC);

CREATE INDEX IF NOT EXISTS idx_pr_required_date 
    ON purchase_requests(required_date);

CREATE INDEX IF NOT EXISTS idx_pr_created_at 
    ON purchase_requests(created_at DESC);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_pr_status_department 
    ON purchase_requests(status, department) 
    WHERE deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pr_status_date 
    ON purchase_requests(status, created_at DESC) 
    WHERE deleted = FALSE;

-- Priority filtering for urgent items
CREATE INDEX IF NOT EXISTS idx_pr_priority 
    ON purchase_requests(priority) 
    WHERE priority IN ('high', 'urgent', 'critical') AND deleted = FALSE;

-- Approval workflow indexes
CREATE INDEX IF NOT EXISTS idx_pr_approved_by 
    ON purchase_requests(approved_by) 
    WHERE approved_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pr_current_approver 
    ON purchase_requests(current_approver_id) 
    WHERE current_approver_id IS NOT NULL;

-- Cost center/plant queries
CREATE INDEX IF NOT EXISTS idx_pr_cost_center 
    ON purchase_requests(cost_center) 
    WHERE cost_center IS NOT NULL;

-- Soft delete filter
CREATE INDEX IF NOT EXISTS idx_pr_not_deleted 
    ON purchase_requests(id) 
    WHERE deleted = FALSE;

-- ============================================================================
-- SECTION 2: INDEXES FOR purchase_request_items TABLE
-- ============================================================================

-- Parent PR lookup
CREATE INDEX IF NOT EXISTS idx_pri_pr_id 
    ON purchase_request_items(pr_id);

-- Item material lookup
CREATE INDEX IF NOT EXISTS idx_pri_item_id 
    ON purchase_request_items(item_id) 
    WHERE item_id IS NOT NULL;

-- Item status filtering
CREATE INDEX IF NOT EXISTS idx_pri_status 
    ON purchase_request_items(status) 
    WHERE deleted = FALSE;

-- PO linkage lookup
CREATE INDEX IF NOT EXISTS idx_pri_po_id 
    ON purchase_request_items(po_id) 
    WHERE po_id IS NOT NULL;

-- Composite: PR + Status for conversion queries
CREATE INDEX IF NOT EXISTS idx_pri_pr_status 
    ON purchase_request_items(pr_id, status) 
    WHERE deleted = FALSE;

-- Required date for planning
CREATE INDEX IF NOT EXISTS idx_pri_required_date 
    ON purchase_request_items(required_date);

-- Suggested supplier for sourcing
CREATE INDEX IF NOT EXISTS idx_pri_suggested_supplier 
    ON purchase_request_items(suggested_supplier_id) 
    WHERE suggested_supplier_id IS NOT NULL;

-- Soft delete filter
CREATE INDEX IF NOT EXISTS idx_pri_not_deleted 
    ON purchase_request_items(id) 
    WHERE deleted = FALSE;

-- ============================================================================
-- SECTION 3: INDEXES FOR pr_status_history TABLE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_status_history_pr_id 
    ON pr_status_history(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_status_history_date 
    ON pr_status_history(change_date DESC);

CREATE INDEX IF NOT EXISTS idx_pr_status_history_user 
    ON pr_status_history(changed_by) 
    WHERE changed_by IS NOT NULL;

-- ============================================================================
-- SECTION 4: INDEXES FOR pr_approval_workflow TABLE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_approval_pr_id 
    ON pr_approval_workflow(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_approval_approver 
    ON pr_approval_workflow(approver_id) 
    WHERE approver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pr_approval_pending 
    ON pr_approval_workflow(pr_id, decision) 
    WHERE decision = 'pending';

-- ============================================================================
-- SECTION 5: INDEXES FOR pr_comments TABLE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_comments_pr_id 
    ON pr_comments(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_comments_item_id 
    ON pr_comments(pr_item_id) 
    WHERE pr_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pr_comments_date 
    ON pr_comments(created_at DESC);

-- ============================================================================
-- SECTION 6: INDEXES FOR pr_attachments TABLE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pr_attachments_pr_id 
    ON pr_attachments(pr_id);

CREATE INDEX IF NOT EXISTS idx_pr_attachments_item_id 
    ON pr_attachments(pr_item_id) 
    WHERE pr_item_id IS NOT NULL;

-- ============================================================================
-- SECTION 7: ROW LEVEL SECURITY - purchase_requests
-- ============================================================================

ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own PRs
CREATE POLICY pr_select_own ON purchase_requests
    FOR SELECT
    USING (
        requester_id = auth.uid()
    );

-- Policy: Managers can view all PRs (since users table doesn't have department column)
-- In production, add a user_departments table to map users to departments
CREATE POLICY pr_select_department ON purchase_requests
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('manager', 'department_head')
        )
    );

-- Policy: Procurement/Admin can view all PRs
CREATE POLICY pr_select_procurement ON purchase_requests
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin', 'procurement', 'approver')
        )
    );

-- Policy: Approvers can view PRs assigned to them
CREATE POLICY pr_select_approver ON purchase_requests
    FOR SELECT
    USING (
        current_approver_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM pr_approval_workflow 
            WHERE pr_id = purchase_requests.id 
            AND approver_id = auth.uid()
        )
    );

-- Policy: Users can create their own PRs
CREATE POLICY pr_insert_own ON purchase_requests
    FOR INSERT
    WITH CHECK (
        requester_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin')
        )
    );

-- Policy: Users can update their own draft PRs
CREATE POLICY pr_update_own_draft ON purchase_requests
    FOR UPDATE
    USING (
        requester_id = auth.uid()
        AND status = 'draft'
    )
    WITH CHECK (
        requester_id = auth.uid()
    );

-- Policy: Approvers can update PR status
CREATE POLICY pr_update_approver ON purchase_requests
    FOR UPDATE
    USING (
        current_approver_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin', 'approver', 'manager')
        )
    );

-- Policy: Procurement can update approved PRs (for PO conversion)
CREATE POLICY pr_update_procurement ON purchase_requests
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin', 'procurement')
        )
    );

-- Policy: Only admin can delete PRs
CREATE POLICY pr_delete_admin ON purchase_requests
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin')
        )
    );

-- ============================================================================
-- SECTION 8: ROW LEVEL SECURITY - purchase_request_items
-- ============================================================================

ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view items of PRs they can access
CREATE POLICY pri_select_policy ON purchase_request_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = purchase_request_items.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() 
                    AND (
                        role IN ('admin', 'superadmin', 'procurement', 'approver')
                        OR (role IN ('manager', 'department_head') AND department = pr.department)
                    )
                )
            )
        )
    );

-- Policy: Users can insert items to their draft PRs
CREATE POLICY pri_insert_policy ON purchase_request_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = purchase_request_items.pr_id
            AND pr.requester_id = auth.uid()
            AND pr.status = 'draft'
        )
        OR EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin')
        )
    );

-- Policy: Users can update items in their draft PRs
CREATE POLICY pri_update_own ON purchase_request_items
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = purchase_request_items.pr_id
            AND pr.requester_id = auth.uid()
            AND pr.status = 'draft'
        )
        AND NOT is_locked
    )
    WITH CHECK (
        NOT is_locked
    );

-- Policy: Procurement can update items (for conversion)
CREATE POLICY pri_update_procurement ON purchase_request_items
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin', 'procurement')
        )
    );

-- Policy: Users can delete items from their draft PRs
CREATE POLICY pri_delete_policy ON purchase_request_items
    FOR DELETE
    USING (
        (
            EXISTS (
                SELECT 1 FROM purchase_requests pr
                WHERE pr.id = purchase_request_items.pr_id
                AND pr.requester_id = auth.uid()
                AND pr.status = 'draft'
            )
            AND NOT is_locked
        )
        OR EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin')
        )
    );

-- ============================================================================
-- SECTION 9: ROW LEVEL SECURITY - pr_status_history
-- ============================================================================

ALTER TABLE pr_status_history ENABLE ROW LEVEL SECURITY;

-- Policy: Read-only access based on PR visibility
CREATE POLICY pr_status_history_select ON pr_status_history
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_status_history.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() 
                    AND role IN ('admin', 'superadmin', 'procurement', 'approver', 'manager')
                )
            )
        )
    );

-- Policy: System can insert status history
CREATE POLICY pr_status_history_insert ON pr_status_history
    FOR INSERT
    WITH CHECK (TRUE); -- Controlled by trigger

-- ============================================================================
-- SECTION 10: ROW LEVEL SECURITY - pr_approval_workflow
-- ============================================================================

ALTER TABLE pr_approval_workflow ENABLE ROW LEVEL SECURITY;

-- Policy: Requesters and approvers can view workflow
CREATE POLICY pr_approval_select ON pr_approval_workflow
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_approval_workflow.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR pr_approval_workflow.approver_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() 
                    AND role IN ('admin', 'superadmin', 'approver')
                )
            )
        )
    );

-- Policy: Approvers can update their workflow entries
CREATE POLICY pr_approval_update ON pr_approval_workflow
    FOR UPDATE
    USING (
        approver_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin')
        )
    );

-- ============================================================================
-- SECTION 11: ROW LEVEL SECURITY - pr_comments
-- ============================================================================

ALTER TABLE pr_comments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view non-internal comments
CREATE POLICY pr_comments_select_public ON pr_comments
    FOR SELECT
    USING (
        NOT is_internal
        AND EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_comments.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users WHERE id = auth.uid() AND role != 'user')
            )
        )
    );

-- Policy: Staff can view internal comments
CREATE POLICY pr_comments_select_internal ON pr_comments
    FOR SELECT
    USING (
        is_internal
        AND EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'superadmin', 'procurement', 'approver', 'manager')
        )
    );

-- Policy: Users can add comments to PRs they can access
CREATE POLICY pr_comments_insert ON pr_comments
    FOR INSERT
    WITH CHECK (
        author_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_comments.pr_id
        )
    );

-- ============================================================================
-- SECTION 12: ROW LEVEL SECURITY - pr_attachments
-- ============================================================================

ALTER TABLE pr_attachments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view attachments of PRs they can access
CREATE POLICY pr_attachments_select ON pr_attachments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_attachments.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users WHERE id = auth.uid() AND role != 'user'
                )
            )
        )
    );

-- Policy: Requesters can add attachments to their draft PRs
CREATE POLICY pr_attachments_insert ON pr_attachments
    FOR INSERT
    WITH CHECK (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1 FROM purchase_requests pr
            WHERE pr.id = pr_attachments.pr_id
            AND (
                pr.requester_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
                )
            )
        )
    );

-- ============================================================================
-- SECTION 13: FOREIGN KEY CONSTRAINTS (if not already defined)
-- ============================================================================

-- Ensure referential integrity
DO $$ 
BEGIN
    -- purchase_requests FK constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pr_requester') THEN
        ALTER TABLE purchase_requests 
            ADD CONSTRAINT fk_pr_requester 
            FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE RESTRICT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pr_created_by') THEN
        ALTER TABLE purchase_requests 
            ADD CONSTRAINT fk_pr_created_by 
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pr_approved_by') THEN
        ALTER TABLE purchase_requests 
            ADD CONSTRAINT fk_pr_approved_by 
            FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;
    END IF;
    
    -- purchase_request_items FK constraints
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pri_pr') THEN
        ALTER TABLE purchase_request_items 
            ADD CONSTRAINT fk_pri_pr 
            FOREIGN KEY (pr_id) REFERENCES purchase_requests(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pri_item') THEN
        ALTER TABLE purchase_request_items 
            ADD CONSTRAINT fk_pri_item 
            FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE SET NULL;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Some constraints may already exist or reference tables do not exist yet: %', SQLERRM;
END $$;

-- ============================================================================
-- SECTION 14: ANALYZE TABLES FOR QUERY OPTIMIZATION
-- ============================================================================

ANALYZE purchase_requests;
ANALYZE purchase_request_items;
ANALYZE pr_status_history;
ANALYZE pr_approval_workflow;
ANALYZE pr_comments;
ANALYZE pr_attachments;
ANALYZE pr_po_linkage;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON INDEX idx_pr_number IS 'Primary lookup index for PR number searches';
COMMENT ON INDEX idx_pr_status IS 'Filtered index for status-based queries';
COMMENT ON INDEX idx_pr_department IS 'Index for department filtering';
COMMENT ON INDEX idx_pr_status_department IS 'Composite index for combined status and department queries';

-- ============================================================================
-- END OF PR_INDEXES_AND_RLS.sql
-- ============================================================================
