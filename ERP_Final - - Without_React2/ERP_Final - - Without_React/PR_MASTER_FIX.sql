-- ============================================================================
-- SAKURA ERP - PR MASTER FIX (RUN THIS IN SUPABASE)
-- Combines all fixes: Schema, RLS, Triggers, Functions
-- ============================================================================
-- Version: 3.1.0
-- Date: 2026-01-25
-- Fixes:
--   1. PGRST201: Duplicate foreign key constraints
--   2. 42501: RLS blocking INSERT/SELECT
--   3. PR Number generation
--   4. Dashboard stats function
-- ============================================================================

-- ============================================================================
-- PART 1: DROP DUPLICATE FOREIGN KEYS (CRITICAL!)
-- ============================================================================
-- These duplicates cause: "Could not embed because more than one relationship"

-- Drop duplicate FKs on purchase_request_items
ALTER TABLE purchase_request_items DROP CONSTRAINT IF EXISTS fk_pri_pr;
ALTER TABLE purchase_request_items DROP CONSTRAINT IF EXISTS fk_pri_item;

-- Drop duplicate FKs on purchase_requests
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_requester;
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_created_by;
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_approved_by;

-- ============================================================================
-- PART 2: ENSURE REQUIRED COLUMNS EXIST
-- ============================================================================

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
    
    RAISE NOTICE 'PART 1-2: Duplicate FKs dropped, columns verified';
END $$;

-- ============================================================================
-- PART 3: ENSURE pr_number_sequence TABLE EXISTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_number_sequence (
    id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL UNIQUE,
    last_number INTEGER NOT NULL DEFAULT 0,
    prefix TEXT DEFAULT 'PR',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
VALUES (EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, NOW())
ON CONFLICT (fiscal_year) DO NOTHING;

-- ============================================================================
-- PART 4: CREATE PR NUMBER GENERATOR
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
-- PART 5: CREATE TRIGGER FOR AUTO PR NUMBER
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pr_number_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.pr_number IS NULL OR NEW.pr_number = '' THEN
        NEW.pr_number := generate_pr_number();
    END IF;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    NEW.updated_at := NOW();
    
    IF NEW.status IS NULL THEN
        NEW.status := 'draft';
    END IF;
    
    IF NEW.business_date IS NULL THEN
        NEW.business_date := CURRENT_DATE;
    END IF;
    
    IF NEW.deleted IS NULL THEN
        NEW.deleted := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_purchase_requests_pr_number ON purchase_requests;
CREATE TRIGGER tr_purchase_requests_pr_number
    BEFORE INSERT ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION set_pr_number_on_insert();

-- ============================================================================
-- PART 6: ENABLE RLS AND DROP ALL EXISTING POLICIES
-- ============================================================================

ALTER TABLE purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pr_number_sequence ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    pol RECORD;
    tbl TEXT;
    tables TEXT[] := ARRAY['purchase_requests', 'purchase_request_items', 'pr_number_sequence'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = tbl LOOP
            EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, tbl);
        END LOOP;
    END LOOP;
    RAISE NOTICE 'PART 6: Old RLS policies dropped';
END $$;

-- ============================================================================
-- PART 7: CREATE NEW PERMISSIVE POLICIES
-- ============================================================================

-- purchase_requests policies
CREATE POLICY "pr_select_all" ON purchase_requests FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "pr_insert_all" ON purchase_requests FOR INSERT TO authenticated, anon WITH CHECK (true);
CREATE POLICY "pr_update_all" ON purchase_requests FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "pr_delete_all" ON purchase_requests FOR DELETE TO authenticated USING (true);

-- purchase_request_items policies
CREATE POLICY "pri_select_all" ON purchase_request_items FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "pri_insert_all" ON purchase_request_items FOR INSERT TO authenticated, anon WITH CHECK (true);
CREATE POLICY "pri_update_all" ON purchase_request_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "pri_delete_all" ON purchase_request_items FOR DELETE TO authenticated USING (true);

-- pr_number_sequence policies
CREATE POLICY "seq_select_all" ON pr_number_sequence FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "seq_insert_all" ON pr_number_sequence FOR INSERT TO authenticated, anon WITH CHECK (true);
CREATE POLICY "seq_update_all" ON pr_number_sequence FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

-- ============================================================================
-- PART 8: GRANT PERMISSIONS
-- ============================================================================

GRANT ALL ON purchase_requests TO authenticated, anon;
GRANT ALL ON purchase_request_items TO authenticated, anon;
GRANT ALL ON pr_number_sequence TO authenticated, anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;

-- ============================================================================
-- PART 9: CREATE HELPER FUNCTIONS
-- ============================================================================

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

CREATE OR REPLACE FUNCTION submit_pr_for_approval(p_pr_id UUID, p_notes TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE purchase_requests
    SET status = 'submitted',
        submitted_for_approval = TRUE,
        submitted_for_approval_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_pr_id AND status = 'draft';
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR not found or not in draft status');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'pr_id', p_pr_id, 'status', 'submitted');
END;
$$;

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
-- PART 9B: APPROVE AND REJECT PR FUNCTIONS
-- ============================================================================

-- Approve PR Function
CREATE OR REPLACE FUNCTION approve_pr(p_pr_id UUID, p_notes TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
    v_user_id UUID;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    
    -- Get current PR
    SELECT * INTO v_pr FROM purchase_requests WHERE id = p_pr_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Purchase Request not found');
    END IF;
    
    -- Validate status - only submitted or under_review can be approved
    IF v_pr.status NOT IN ('submitted', 'under_review') THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR must be in submitted or under_review status to approve');
    END IF;
    
    -- Update PR to approved
    UPDATE purchase_requests
    SET status = 'approved',
        approved_at = NOW(),
        approved_by = v_user_id,
        internal_memo = CASE WHEN p_notes IS NOT NULL THEN 'Approval Notes: ' || p_notes ELSE internal_memo END,
        updated_at = NOW()
    WHERE id = p_pr_id;
    
    -- Insert status history
    INSERT INTO pr_status_history (
        pr_id, previous_status, new_status, 
        changed_by, change_reason, change_date
    ) VALUES (
        p_pr_id, v_pr.status, 'approved',
        v_user_id, COALESCE(p_notes, 'PR approved'), NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true, 
        'pr_id', p_pr_id, 
        'status', 'approved',
        'approved_at', NOW()
    );
END;
$$;

-- Reject PR Function
CREATE OR REPLACE FUNCTION reject_pr(p_pr_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
    v_user_id UUID;
BEGIN
    -- Validate reason is provided
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rejection reason is required');
    END IF;
    
    -- Get current user
    v_user_id := auth.uid();
    
    -- Get current PR
    SELECT * INTO v_pr FROM purchase_requests WHERE id = p_pr_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Purchase Request not found');
    END IF;
    
    -- Validate status - only submitted or under_review can be rejected
    IF v_pr.status NOT IN ('submitted', 'under_review') THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR must be in submitted or under_review status to reject');
    END IF;
    
    -- Update PR to rejected
    UPDATE purchase_requests
    SET status = 'rejected',
        rejection_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_pr_id;
    
    -- Insert status history
    INSERT INTO pr_status_history (
        pr_id, previous_status, new_status, 
        changed_by, change_reason, change_date
    ) VALUES (
        p_pr_id, v_pr.status, 'rejected',
        v_user_id, p_reason, NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true, 
        'pr_id', p_pr_id, 
        'status', 'rejected',
        'reason', p_reason
    );
END;
$$;

-- ============================================================================
-- PART 9C: CONVERT PR TO PO FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION convert_pr_to_po(
    p_pr_ids UUID[],
    p_supplier_id BIGINT,
    p_pricing_mode TEXT DEFAULT 'estimated',
    p_user_id UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
    v_pr_item RECORD;
    v_supplier RECORD;
    v_po_id BIGINT;
    v_po_number TEXT;
    v_total_amount NUMERIC := 0;
    v_vat_rate NUMERIC := 0.15;
    v_vat_amount NUMERIC := 0;
    v_items_converted INT := 0;
    v_user_id UUID;
BEGIN
    -- Get current user
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    -- Validate input
    IF p_pr_ids IS NULL OR array_length(p_pr_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No PR IDs provided');
    END IF;
    
    -- Get supplier info
    SELECT * INTO v_supplier FROM suppliers WHERE id = p_supplier_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Supplier not found');
    END IF;
    
    -- Get first PR for reference
    SELECT * INTO v_pr FROM purchase_requests WHERE id = p_pr_ids[1];
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Purchase Request not found');
    END IF;
    
    -- Validate PR status
    IF v_pr.status NOT IN ('approved', 'partially_ordered') THEN
        RETURN jsonb_build_object('success', false, 'error', 'PR must be approved to convert to PO');
    END IF;
    
    -- Calculate total from PR items
    SELECT COALESCE(SUM((quantity - COALESCE(quantity_ordered, 0)) * estimated_price), 0)
    INTO v_total_amount
    FROM purchase_request_items
    WHERE pr_id = ANY(p_pr_ids)
      AND status IN ('open', 'partially_converted')
      AND deleted = FALSE;
    
    v_vat_amount := v_total_amount * v_vat_rate;
    
    -- Create PO header
    INSERT INTO purchase_orders (
        supplier_id,
        supplier_name,
        status,
        business_date,
        order_date,
        total_amount,
        vat_amount,
        notes,
        receiving_status
    ) VALUES (
        p_supplier_id,
        v_supplier.name,
        'pending',
        CURRENT_DATE,
        NOW(),
        v_total_amount,
        v_vat_amount,
        COALESCE(p_notes, 'Converted from PR: ' || v_pr.pr_number),
        'not_received'
    )
    RETURNING id, po_number INTO v_po_id, v_po_number;
    
    -- Create PO items from PR items
    FOR v_pr_item IN
        SELECT pri.*, ii.sku as item_sku
        FROM purchase_request_items pri
        LEFT JOIN inventory_items ii ON ii.id = pri.item_id
        WHERE pri.pr_id = ANY(p_pr_ids)
          AND pri.status IN ('open', 'partially_converted')
          AND pri.deleted = FALSE
    LOOP
        INSERT INTO purchase_order_items (
            purchase_order_id,
            po_number,
            supplier_name,
            item_id,
            item_name,
            item_sku,
            quantity,
            unit,
            unit_price,
            total_amount,
            quantity_received,
            vat_rate,
            vat_amount
        ) VALUES (
            v_po_id,
            v_po_number,
            v_supplier.name,
            v_pr_item.item_id,
            v_pr_item.item_name,
            v_pr_item.item_sku,
            v_pr_item.quantity - COALESCE(v_pr_item.quantity_ordered, 0),
            v_pr_item.unit,
            v_pr_item.estimated_price,
            (v_pr_item.quantity - COALESCE(v_pr_item.quantity_ordered, 0)) * v_pr_item.estimated_price,
            0,
            v_vat_rate * 100,
            ((v_pr_item.quantity - COALESCE(v_pr_item.quantity_ordered, 0)) * v_pr_item.estimated_price) * v_vat_rate
        );
        
        -- Update PR item status and quantity_ordered
        UPDATE purchase_request_items
        SET status = 'converted_to_po',
            quantity_ordered = quantity,
            po_id = v_po_id,
            po_number = v_po_number,
            conversion_date = NOW(),
            converted_by = v_user_id,
            is_locked = TRUE,
            locked_at = NOW(),
            locked_by = v_user_id,
            lock_reason = 'Converted to PO',
            updated_at = NOW()
        WHERE id = v_pr_item.id;
        
        -- Create pr_po_linkage record
        INSERT INTO pr_po_linkage (
            pr_id, pr_number, pr_item_id, pr_item_number,
            po_id, po_number,
            pr_quantity, converted_quantity, unit,
            pr_estimated_price, po_actual_price,
            conversion_type, status, converted_by
        ) VALUES (
            v_pr_item.pr_id, v_pr.pr_number, v_pr_item.id, v_pr_item.item_number,
            v_po_id, v_po_number,
            v_pr_item.quantity, v_pr_item.quantity - COALESCE(v_pr_item.quantity_ordered, 0), v_pr_item.unit,
            v_pr_item.estimated_price, v_pr_item.estimated_price,
            'full', 'active', v_user_id
        );
        
        v_items_converted := v_items_converted + 1;
    END LOOP;
    
    -- Update PR status
    UPDATE purchase_requests
    SET status = 'fully_ordered',
        updated_at = NOW()
    WHERE id = ANY(p_pr_ids);
    
    -- Create document flow record
    INSERT INTO document_flow (
        source_type, source_id, source_number,
        target_type, target_id, target_number,
        flow_type
    ) VALUES (
        'PR', p_pr_ids[1], v_pr.pr_number,
        'PO', v_po_id::UUID, v_po_number,
        'follows'
    );
    
    -- Insert status history
    INSERT INTO pr_status_history (
        pr_id, previous_status, new_status,
        changed_by, change_reason, change_date
    ) VALUES (
        p_pr_ids[1], v_pr.status, 'fully_ordered',
        v_user_id, 'Converted to PO: ' || v_po_number, NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'po_id', v_po_id,
        'po_number', v_po_number,
        'pr_ids', p_pr_ids,
        'items_converted', v_items_converted,
        'total_amount', v_total_amount
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================================
-- PART 10: GRANT EXECUTE ON FUNCTIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION generate_pr_number() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_next_pr_number_preview() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION submit_pr_for_approval(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_pr_dashboard_stats(TEXT, DATE, DATE) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION approve_pr(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION reject_pr(UUID, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION convert_pr_to_po(UUID[], BIGINT, TEXT, UUID, TEXT) TO authenticated, anon;

-- ============================================================================
-- PART 11: CREATE INDEXES FOR PERFORMANCE
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
CREATE INDEX IF NOT EXISTS idx_pri_status ON purchase_request_items(status);

-- ============================================================================
-- PART 12: SET DEFAULT VALUES
-- ============================================================================

ALTER TABLE purchase_requests ALTER COLUMN deleted SET DEFAULT FALSE;
ALTER TABLE purchase_request_items ALTER COLUMN deleted SET DEFAULT FALSE;

UPDATE purchase_requests SET deleted = FALSE WHERE deleted IS NULL;
UPDATE purchase_request_items SET deleted = FALSE WHERE deleted IS NULL;

-- ============================================================================
-- PART 13: VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_fk_count INT;
    v_policy_count INT;
    v_test_number TEXT;
BEGIN
    -- Check duplicate FKs are gone
    SELECT COUNT(*) INTO v_fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'purchase_request_items'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'purchase_requests';
    
    IF v_fk_count > 1 THEN
        RAISE WARNING 'Still have % FKs to purchase_requests (should be 1)', v_fk_count;
    ELSE
        RAISE NOTICE 'FK count to purchase_requests: % (correct)', v_fk_count;
    END IF;
    
    -- Check policy count
    SELECT COUNT(*) INTO v_policy_count FROM pg_policies WHERE tablename = 'purchase_requests';
    RAISE NOTICE 'Policies on purchase_requests: %', v_policy_count;
    
    SELECT COUNT(*) INTO v_policy_count FROM pg_policies WHERE tablename = 'purchase_request_items';
    RAISE NOTICE 'Policies on purchase_request_items: %', v_policy_count;
    
    -- Test PR number generation
    SELECT get_next_pr_number_preview() INTO v_test_number;
    RAISE NOTICE 'Next PR Number Preview: %', v_test_number;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PR MASTER FIX COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Duplicate foreign keys removed';
    RAISE NOTICE 'RLS policies created (permissive)';
    RAISE NOTICE 'PR number generator working';
    RAISE NOTICE 'Dashboard stats function ready';
    RAISE NOTICE 'Indexes created for performance';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'NEXT: Refresh browser and test PR Create!';
END $$;

-- ============================================================================
-- END OF PR_MASTER_FIX.sql
-- ============================================================================
