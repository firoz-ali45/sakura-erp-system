-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST NUMBER GENERATION TRIGGERS
-- SAP MM Architecture Compliant
-- ============================================================================
-- File: PR_NUMBER_TRIGGER.sql
-- Purpose: Atomic PR number generation with yearly reset
-- Format: PR-YYYY-NNNNNN (e.g., PR-2026-000001)
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- FUNCTION: generate_pr_number()
-- Description: Generates unique PR number atomically using advisory locks
-- Race Condition Safe: Uses pg_advisory_xact_lock for serialization
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
    v_lock_id BIGINT;
BEGIN
    -- Get current fiscal year
    v_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
    
    -- Calculate unique lock ID for this year (prevents race conditions)
    -- Using a constant base + year to create unique lock per year
    v_lock_id := 100000000 + v_year;
    
    -- Acquire advisory lock (transaction-level, auto-released on commit/rollback)
    PERFORM pg_advisory_xact_lock(v_lock_id);
    
    -- Insert new year record if not exists, or update existing
    INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
    VALUES (v_year, 1, NOW())
    ON CONFLICT (fiscal_year) 
    DO UPDATE SET 
        last_number = pr_number_sequence.last_number + 1,
        updated_at = NOW()
    RETURNING last_number INTO v_sequence;
    
    -- Format PR number: PR-YYYY-NNNNNN
    v_pr_number := 'PR-' || v_year::TEXT || '-' || LPAD(v_sequence::TEXT, 6, '0');
    
    -- Verify uniqueness (defensive check)
    IF EXISTS (SELECT 1 FROM purchase_requests WHERE pr_number = v_pr_number) THEN
        RAISE EXCEPTION 'PR number % already exists. Contact system administrator.', v_pr_number;
    END IF;
    
    RETURN v_pr_number;
END;
$$;

-- ============================================================================
-- FUNCTION: set_pr_number_on_insert()
-- Description: Trigger function to auto-generate PR number on INSERT
-- Prevents manual override unless user has admin role
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pr_number_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_role TEXT;
    v_is_admin BOOLEAN DEFAULT FALSE;
BEGIN
    -- Check if user is trying to manually set PR number
    IF NEW.pr_number IS NOT NULL AND NEW.pr_number != '' THEN
        -- Get current user's role (if available)
        BEGIN
            SELECT role INTO v_user_role
            FROM users 
            WHERE id = auth.uid();
            
            v_is_admin := v_user_role IN ('admin', 'superadmin', 'system');
        EXCEPTION WHEN OTHERS THEN
            v_is_admin := FALSE;
        END;
        
        -- Only allow manual PR number for admins
        IF NOT v_is_admin THEN
            RAISE NOTICE 'Manual PR number override not allowed. Generating automatic number.';
            NEW.pr_number := generate_pr_number();
        ELSE
            -- Admin is setting manual number - validate format
            IF NOT NEW.pr_number ~ '^PR-[0-9]{4}-[0-9]{6}$' THEN
                RAISE EXCEPTION 'Invalid PR number format. Must be PR-YYYY-NNNNNN';
            END IF;
        END IF;
    ELSE
        -- No PR number provided, generate automatically
        NEW.pr_number := generate_pr_number();
    END IF;
    
    -- Set created_at if not set
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    
    -- Set updated_at
    NEW.updated_at := NOW();
    
    -- Set initial status if not provided
    IF NEW.status IS NULL THEN
        NEW.status := 'draft';
    END IF;
    
    -- Set requester_name from users table if not provided
    IF NEW.requester_name IS NULL OR NEW.requester_name = '' THEN
        SELECT name INTO NEW.requester_name
        FROM users
        WHERE id = NEW.requester_id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_purchase_requests_pr_number
-- Description: Auto-generate PR number before INSERT
-- ============================================================================

DROP TRIGGER IF EXISTS tr_purchase_requests_pr_number ON purchase_requests;

CREATE TRIGGER tr_purchase_requests_pr_number
    BEFORE INSERT ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION set_pr_number_on_insert();

-- ============================================================================
-- FUNCTION: set_pr_updated_at()
-- Description: Auto-update updated_at timestamp on UPDATE
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pr_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    NEW.version := COALESCE(OLD.version, 1) + 1;
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_purchase_requests_updated_at
-- Description: Auto-update timestamps on UPDATE
-- ============================================================================

DROP TRIGGER IF EXISTS tr_purchase_requests_updated_at ON purchase_requests;

CREATE TRIGGER tr_purchase_requests_updated_at
    BEFORE UPDATE ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION set_pr_updated_at();

-- ============================================================================
-- FUNCTION: set_pr_item_number()
-- Description: Auto-generate sequential item number within PR
-- ============================================================================

CREATE OR REPLACE FUNCTION set_pr_item_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_item_number INT;
BEGIN
    -- If item_number not provided, generate next sequence
    IF NEW.item_number IS NULL OR NEW.item_number = 0 THEN
        SELECT COALESCE(MAX(item_number), 0) + 10 INTO v_max_item_number
        FROM purchase_request_items
        WHERE pr_id = NEW.pr_id AND deleted = FALSE;
        
        -- Use SAP convention of 10, 20, 30...
        NEW.item_number := COALESCE(v_max_item_number, 10);
    END IF;
    
    -- Set timestamps
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    NEW.updated_at := NOW();
    
    -- Copy required_date from parent PR if not set
    IF NEW.required_date IS NULL THEN
        SELECT required_date INTO NEW.required_date
        FROM purchase_requests
        WHERE id = NEW.pr_id;
    END IF;
    
    -- Set item_code from inventory_items if not provided
    IF NEW.item_code IS NULL AND NEW.item_id IS NOT NULL THEN
        SELECT sku INTO NEW.item_code
        FROM inventory_items
        WHERE id = NEW.item_id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_purchase_request_items_number
-- Description: Auto-generate item number before INSERT
-- ============================================================================

DROP TRIGGER IF EXISTS tr_purchase_request_items_number ON purchase_request_items;

CREATE TRIGGER tr_purchase_request_items_number
    BEFORE INSERT ON purchase_request_items
    FOR EACH ROW
    EXECUTE FUNCTION set_pr_item_number();

-- ============================================================================
-- FUNCTION: update_pr_estimated_total()
-- Description: Recalculate PR header total when items change
-- ============================================================================

CREATE OR REPLACE FUNCTION update_pr_estimated_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(18, 4);
BEGIN
    -- Calculate total from all non-deleted items
    SELECT COALESCE(SUM(quantity * estimated_price), 0) INTO v_total
    FROM purchase_request_items
    WHERE pr_id = COALESCE(NEW.pr_id, OLD.pr_id)
      AND deleted = FALSE;
    
    -- Update header total
    UPDATE purchase_requests
    SET estimated_total_value = v_total,
        updated_at = NOW()
    WHERE id = COALESCE(NEW.pr_id, OLD.pr_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================================
-- TRIGGER: tr_pr_items_update_total
-- Description: Recalculate header total on item changes
-- ============================================================================

DROP TRIGGER IF EXISTS tr_pr_items_update_total ON purchase_request_items;

CREATE TRIGGER tr_pr_items_update_total
    AFTER INSERT OR UPDATE OR DELETE ON purchase_request_items
    FOR EACH ROW
    EXECUTE FUNCTION update_pr_estimated_total();

-- ============================================================================
-- FUNCTION: prevent_pr_number_update()
-- Description: Prevent modification of PR number after creation
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_pr_number_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.pr_number != NEW.pr_number THEN
        RAISE EXCEPTION 'PR number cannot be modified after creation. Original: %, Attempted: %', 
            OLD.pr_number, NEW.pr_number;
    END IF;
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_prevent_pr_number_update
-- Description: Block PR number changes
-- ============================================================================

DROP TRIGGER IF EXISTS tr_prevent_pr_number_update ON purchase_requests;

CREATE TRIGGER tr_prevent_pr_number_update
    BEFORE UPDATE ON purchase_requests
    FOR EACH ROW
    WHEN (OLD.pr_number IS DISTINCT FROM NEW.pr_number)
    EXECUTE FUNCTION prevent_pr_number_update();

-- ============================================================================
-- FUNCTION: get_next_pr_number_preview()
-- Description: Preview next PR number without consuming it (for UI display)
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

-- ============================================================================
-- FUNCTION: reset_pr_sequence_for_year()
-- Description: Admin function to reset or initialize sequence for a year
-- ============================================================================

CREATE OR REPLACE FUNCTION reset_pr_sequence_for_year(
    p_year INT,
    p_starting_number INT DEFAULT 0
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only allow for current or future years
    IF p_year < EXTRACT(YEAR FROM CURRENT_DATE)::INT THEN
        RAISE EXCEPTION 'Cannot reset sequence for past years';
    END IF;
    
    INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
    VALUES (p_year, p_starting_number, NOW())
    ON CONFLICT (fiscal_year) 
    DO UPDATE SET 
        last_number = p_starting_number,
        updated_at = NOW();
        
    RAISE NOTICE 'PR sequence for year % reset to %', p_year, p_starting_number;
END;
$$;

-- ============================================================================
-- Grant execute permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION generate_pr_number() TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_pr_number_preview() TO authenticated;
-- reset_pr_sequence_for_year intentionally not granted to regular users

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION generate_pr_number() IS 'Generates unique PR number atomically with format PR-YYYY-NNNNNN';
COMMENT ON FUNCTION set_pr_number_on_insert() IS 'Trigger function to auto-generate PR number, prevents manual override except for admins';
COMMENT ON FUNCTION get_next_pr_number_preview() IS 'Preview next PR number for UI display without consuming sequence';
COMMENT ON FUNCTION reset_pr_sequence_for_year(INT, INT) IS 'Admin function to reset PR sequence for a specific year';

-- ============================================================================
-- END OF PR_NUMBER_TRIGGER.sql
-- ============================================================================
