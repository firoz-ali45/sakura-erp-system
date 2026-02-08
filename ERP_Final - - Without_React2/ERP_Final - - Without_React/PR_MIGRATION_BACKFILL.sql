-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST MIGRATION & BACKFILL SCRIPT
-- Historical Data Migration from Existing PO Data
-- ============================================================================
-- File: PR_MIGRATION_BACKFILL.sql
-- Purpose: Generate historical PRs from existing POs and initialize sequences
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- IMPORTANT NOTES:
-- ============================================================================
-- 1. This script generates PRs from existing PO data for historical continuity
-- 2. All migrated PRs are marked as 'closed' status
-- 3. Document flow relationships are created to link historical PRs to POs
-- 4. This is OPTIONAL - run only if historical PR data is needed
-- 5. Run in a transaction to allow rollback if issues arise
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1: PRE-MIGRATION CHECKS
-- ============================================================================

-- Check if migration has already been run
DO $$
DECLARE
    v_existing_prs INT;
BEGIN
    SELECT COUNT(*) INTO v_existing_prs FROM purchase_requests;
    
    IF v_existing_prs > 0 THEN
        RAISE NOTICE 'Migration check: % existing PRs found. Proceeding with incremental migration.', v_existing_prs;
    ELSE
        RAISE NOTICE 'Migration check: No existing PRs. Fresh migration will be performed.';
    END IF;
END $$;

-- ============================================================================
-- SECTION 2: CREATE TEMPORARY MIGRATION TRACKING TABLE
-- ============================================================================

CREATE TEMP TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    migration_step TEXT,
    records_affected INT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'in_progress',
    details JSONB
);

-- ============================================================================
-- SECTION 3: GENERATE PRs FROM HISTORICAL POs
-- ============================================================================

-- Function to generate historical PRs from POs
CREATE OR REPLACE FUNCTION migrate_pos_to_prs(
    p_start_date DATE DEFAULT '2020-01-01',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    prs_created INT,
    items_created INT,
    linkages_created INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_po RECORD;
    v_po_item RECORD;
    v_pr_id UUID;
    v_pr_number TEXT;
    v_item_number INT;
    v_prs_created INT := 0;
    v_items_created INT := 0;
    v_linkages_created INT := 0;
    v_year INT;
    v_sequence INT;
BEGIN
    -- Log migration start
    INSERT INTO migration_log (migration_step, details)
    VALUES ('migrate_pos_to_prs', jsonb_build_object('start_date', p_start_date, 'end_date', p_end_date));
    
    -- Process each PO that doesn't already have a linked PR
    FOR v_po IN 
        SELECT po.*
        FROM purchase_orders po
        WHERE po.created_at::DATE BETWEEN p_start_date AND p_end_date
        AND NOT EXISTS (
            SELECT 1 FROM pr_po_linkage link WHERE link.po_id = po.id
        )
        AND po.deleted = FALSE
        ORDER BY po.created_at
    LOOP
        -- Generate PR number for the PO's year
        v_year := EXTRACT(YEAR FROM v_po.created_at)::INT;
        
        -- Get or initialize sequence for that year
        INSERT INTO pr_number_sequence (fiscal_year, last_number, updated_at)
        VALUES (v_year, 0, NOW())
        ON CONFLICT (fiscal_year) DO NOTHING;
        
        -- Get next sequence number
        UPDATE pr_number_sequence
        SET last_number = last_number + 1,
            updated_at = NOW()
        WHERE fiscal_year = v_year
        RETURNING last_number INTO v_sequence;
        
        v_pr_number := 'PR-' || v_year::TEXT || '-' || LPAD(v_sequence::TEXT, 6, '0');
        
        -- Create PR header
        INSERT INTO purchase_requests (
            id,
            pr_number,
            requester_id,
            requester_name,
            department,
            business_date,
            required_date,
            priority,
            status,
            estimated_total_value,
            notes,
            source_system,
            created_at,
            updated_at,
            approved_at
        )
        SELECT
            gen_random_uuid(),
            v_pr_number,
            COALESCE(
                (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
                (SELECT id FROM users LIMIT 1)
            ),
            'System Migration',
            'General',
            v_po.created_at::DATE,
            v_po.created_at::DATE,
            'normal',
            'closed',  -- Historical PRs are closed
            v_po.total_amount,
            'Migrated from PO ' || v_po.po_number || ' | Original PO Date: ' || v_po.created_at::DATE,
            'MIGRATION',
            v_po.created_at - INTERVAL '1 day',  -- PR created day before PO
            v_po.created_at,
            v_po.created_at
        RETURNING id INTO v_pr_id;
        
        v_prs_created := v_prs_created + 1;
        v_item_number := 0;
        
        -- Create PR items from PO items
        FOR v_po_item IN
            SELECT poi.*
            FROM purchase_order_items poi
            WHERE poi.po_id = v_po.id
            ORDER BY poi.id
        LOOP
            v_item_number := v_item_number + 10;
            
            INSERT INTO purchase_request_items (
                id,
                pr_id,
                item_number,
                item_id,
                item_name,
                quantity,
                unit,
                estimated_price,
                status,
                quantity_ordered,
                po_id,
                po_number,
                po_item_number,
                conversion_date,
                is_locked,
                lock_reason,
                created_at,
                updated_at
            ) VALUES (
                gen_random_uuid(),
                v_pr_id,
                v_item_number,
                v_po_item.item_id,
                v_po_item.item_name,
                v_po_item.quantity,
                COALESCE(v_po_item.unit, 'EA'),
                COALESCE(v_po_item.unit_price, 0),
                'converted_to_po',
                v_po_item.quantity,
                v_po.id,
                v_po.po_number,
                v_item_number / 10,
                v_po.created_at,
                TRUE,
                'Historical migration - closed',
                v_po.created_at - INTERVAL '1 day',
                v_po.created_at
            );
            
            v_items_created := v_items_created + 1;
            
            -- Create linkage record
            INSERT INTO pr_po_linkage (
                pr_id,
                pr_number,
                pr_item_id,
                pr_item_number,
                po_id,
                po_number,
                pr_quantity,
                converted_quantity,
                unit,
                pr_estimated_price,
                po_actual_price,
                conversion_type,
                status,
                converted_at,
                conversion_notes
            )
            SELECT
                v_pr_id,
                v_pr_number,
                pri.id,
                v_item_number,
                v_po.id,
                v_po.po_number,
                v_po_item.quantity,
                v_po_item.quantity,
                COALESCE(v_po_item.unit, 'EA'),
                COALESCE(v_po_item.unit_price, 0),
                COALESCE(v_po_item.unit_price, 0),
                'full',
                'active',
                v_po.created_at,
                'Historical migration from PO'
            FROM purchase_request_items pri
            WHERE pri.pr_id = v_pr_id AND pri.item_number = v_item_number
            LIMIT 1;
            
            v_linkages_created := v_linkages_created + 1;
        END LOOP;
        
        -- Create document flow entry
        INSERT INTO document_flow (
            source_type,
            source_id,
            source_number,
            target_type,
            target_id,
            target_number,
            flow_type,
            created_at
        ) VALUES (
            'PR',
            v_pr_id::TEXT,
            v_pr_number,
            'PO',
            v_po.id::TEXT,
            v_po.po_number,
            'follows',
            v_po.created_at
        ) ON CONFLICT DO NOTHING;
        
        -- Create status history entry
        INSERT INTO pr_status_history (
            pr_id,
            previous_status,
            new_status,
            changed_by_name,
            change_reason,
            change_date
        ) VALUES (
            v_pr_id,
            NULL,
            'closed',
            'System Migration',
            'Historical PR migrated from PO ' || v_po.po_number,
            v_po.created_at
        );
        
    END LOOP;
    
    -- Update migration log
    UPDATE migration_log
    SET completed_at = NOW(),
        status = 'completed',
        records_affected = v_prs_created,
        details = jsonb_build_object(
            'prs_created', v_prs_created,
            'items_created', v_items_created,
            'linkages_created', v_linkages_created
        )
    WHERE migration_step = 'migrate_pos_to_prs'
    AND status = 'in_progress';
    
    RETURN QUERY SELECT v_prs_created, v_items_created, v_linkages_created;
END;
$$;

-- ============================================================================
-- SECTION 4: INITIALIZE PR NUMBER SEQUENCE
-- ============================================================================

-- Initialize current year sequence if not exists
INSERT INTO pr_number_sequence (fiscal_year, last_number, prefix, updated_at)
VALUES (EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, 'PR', NOW())
ON CONFLICT (fiscal_year) DO NOTHING;

-- ============================================================================
-- SECTION 5: POPULATE DEPARTMENTS FROM EXISTING DATA
-- ============================================================================

-- Create temp table for department mapping if needed
CREATE TEMP TABLE IF NOT EXISTS department_mapping (
    source_value TEXT,
    target_department TEXT
);

-- Insert common department mappings
INSERT INTO department_mapping VALUES
    ('purchasing', 'Procurement'),
    ('procurement', 'Procurement'),
    ('warehouse', 'Warehouse'),
    ('kitchen', 'Kitchen'),
    ('production', 'Production'),
    ('operations', 'Operations'),
    ('admin', 'Administration'),
    ('finance', 'Finance'),
    ('hr', 'Human Resources'),
    ('it', 'IT'),
    ('sales', 'Sales'),
    ('marketing', 'Marketing')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SECTION 6: DATA VALIDATION QUERIES
-- ============================================================================

-- Create validation function
CREATE OR REPLACE FUNCTION validate_pr_migration()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check 1: PR count matches expectation
    RETURN QUERY
    SELECT 
        'PR Count'::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARNING' END,
        'Total PRs: ' || COUNT(*)::TEXT
    FROM purchase_requests;
    
    -- Check 2: All PRs have items
    RETURN QUERY
    SELECT 
        'PRs with Items'::TEXT,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM purchase_requests pr 
                WHERE NOT EXISTS (SELECT 1 FROM purchase_request_items pri WHERE pri.pr_id = pr.id)
                AND pr.status != 'cancelled'
            ) THEN 'PASS' 
            ELSE 'WARNING' 
        END,
        'PRs without items: ' || (
            SELECT COUNT(*) FROM purchase_requests pr 
            WHERE NOT EXISTS (SELECT 1 FROM purchase_request_items pri WHERE pri.pr_id = pr.id)
            AND pr.status != 'cancelled'
        )::TEXT;
    
    -- Check 3: PR number uniqueness
    RETURN QUERY
    SELECT 
        'PR Number Uniqueness'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM purchase_requests) = (SELECT COUNT(DISTINCT pr_number) FROM purchase_requests)
            THEN 'PASS' ELSE 'FAIL'
        END,
        'Duplicates: ' || (
            SELECT COUNT(*) - COUNT(DISTINCT pr_number) FROM purchase_requests
        )::TEXT;
    
    -- Check 4: Linkage integrity
    RETURN QUERY
    SELECT 
        'PR-PO Linkage Integrity'::TEXT,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM pr_po_linkage l
                WHERE NOT EXISTS (SELECT 1 FROM purchase_requests WHERE id = l.pr_id)
                OR NOT EXISTS (SELECT 1 FROM purchase_orders WHERE id = l.po_id)
            ) THEN 'PASS' ELSE 'FAIL'
        END,
        'Orphan linkages: ' || (
            SELECT COUNT(*) FROM pr_po_linkage l
            WHERE NOT EXISTS (SELECT 1 FROM purchase_requests WHERE id = l.pr_id)
            OR NOT EXISTS (SELECT 1 FROM purchase_orders WHERE id = l.po_id)
        )::TEXT;
    
    -- Check 5: Item status consistency
    RETURN QUERY
    SELECT 
        'Item Status Consistency'::TEXT,
        'INFO',
        'Open: ' || (SELECT COUNT(*) FROM purchase_request_items WHERE status = 'open')::TEXT ||
        ', Converted: ' || (SELECT COUNT(*) FROM purchase_request_items WHERE status = 'converted_to_po')::TEXT ||
        ', Cancelled: ' || (SELECT COUNT(*) FROM purchase_request_items WHERE status = 'cancelled')::TEXT;
    
    -- Check 6: Document flow entries
    RETURN QUERY
    SELECT 
        'Document Flow Entries'::TEXT,
        CASE WHEN (SELECT COUNT(*) FROM document_flow WHERE source_type = 'PR') > 0 THEN 'PASS' ELSE 'WARNING' END,
        'PR->PO flows: ' || (SELECT COUNT(*) FROM document_flow WHERE source_type = 'PR' AND target_type = 'PO')::TEXT;
END;
$$;

-- ============================================================================
-- SECTION 7: EXECUTE MIGRATION (COMMENTED - UNCOMMENT TO RUN)
-- ============================================================================

-- Uncomment the following block to execute migration:
/*
DO $$
DECLARE
    v_result RECORD;
BEGIN
    RAISE NOTICE 'Starting PR migration from POs...';
    
    SELECT * INTO v_result FROM migrate_pos_to_prs('2020-01-01', CURRENT_DATE);
    
    RAISE NOTICE 'Migration completed:';
    RAISE NOTICE '  PRs created: %', v_result.prs_created;
    RAISE NOTICE '  Items created: %', v_result.items_created;
    RAISE NOTICE '  Linkages created: %', v_result.linkages_created;
    
    -- Run validation
    RAISE NOTICE '';
    RAISE NOTICE 'Running validation checks...';
    FOR v_result IN SELECT * FROM validate_pr_migration() LOOP
        RAISE NOTICE '  %: % - %', v_result.check_name, v_result.status, v_result.details;
    END LOOP;
END $$;
*/

-- ============================================================================
-- SECTION 8: ROLLBACK FUNCTION (FOR RECOVERY)
-- ============================================================================

CREATE OR REPLACE FUNCTION rollback_pr_migration()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INT;
BEGIN
    -- Delete migrated linkages
    DELETE FROM pr_po_linkage WHERE conversion_notes LIKE '%Historical migration%';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % linkages', v_deleted;
    
    -- Delete document flow entries
    DELETE FROM document_flow 
    WHERE source_type = 'PR' 
    AND source_id IN (
        SELECT id::TEXT FROM purchase_requests WHERE source_system = 'MIGRATION'
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % document flow entries', v_deleted;
    
    -- Delete status history
    DELETE FROM pr_status_history
    WHERE pr_id IN (SELECT id FROM purchase_requests WHERE source_system = 'MIGRATION');
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % status history entries', v_deleted;
    
    -- Delete PR items
    DELETE FROM purchase_request_items
    WHERE pr_id IN (SELECT id FROM purchase_requests WHERE source_system = 'MIGRATION');
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % PR items', v_deleted;
    
    -- Delete PRs
    DELETE FROM purchase_requests WHERE source_system = 'MIGRATION';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Deleted % PRs', v_deleted;
    
    RAISE NOTICE 'Migration rollback completed';
END;
$$;

-- ============================================================================
-- SECTION 9: SAMPLE DATA FOR TESTING (OPTIONAL)
-- ============================================================================

-- Function to create sample test data
CREATE OR REPLACE FUNCTION create_sample_prs(p_count INT DEFAULT 5)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_pr_id UUID;
    v_created INT := 0;
    i INT;
BEGIN
    -- Get a valid user
    SELECT id INTO v_user_id FROM users LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No users found in database';
    END IF;
    
    FOR i IN 1..p_count LOOP
        -- Create PR header
        INSERT INTO purchase_requests (
            requester_id,
            requester_name,
            department,
            business_date,
            required_date,
            priority,
            status,
            notes
        ) VALUES (
            v_user_id,
            (SELECT name FROM users WHERE id = v_user_id),
            (ARRAY['Procurement', 'Kitchen', 'Warehouse', 'Operations', 'Administration'])[1 + floor(random() * 5)::INT],
            CURRENT_DATE,
            CURRENT_DATE + (7 + floor(random() * 14))::INT,
            (ARRAY['low', 'normal', 'high', 'urgent'])[1 + floor(random() * 4)::INT],
            'draft',
            'Sample PR #' || i || ' created for testing'
        ) RETURNING id INTO v_pr_id;
        
        -- Add random items from inventory
        FOR v_item IN 
            SELECT id, name, cost 
            FROM inventory_items 
            ORDER BY random() 
            LIMIT 2 + floor(random() * 4)::INT
        LOOP
            INSERT INTO purchase_request_items (
                pr_id,
                item_id,
                item_name,
                quantity,
                unit,
                estimated_price
            ) VALUES (
                v_pr_id,
                v_item.id,
                v_item.name,
                10 + floor(random() * 90)::NUMERIC,
                'EA',
                COALESCE(v_item.cost, 10 + floor(random() * 100)::NUMERIC)
            );
        END LOOP;
        
        v_created := v_created + 1;
    END LOOP;
    
    RETURN v_created;
END;
$$;

-- ============================================================================
-- SECTION 10: MIGRATION SUMMARY REPORT
-- ============================================================================

CREATE OR REPLACE FUNCTION get_migration_summary()
RETURNS TABLE (
    metric TEXT,
    value BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total PRs'::TEXT, COUNT(*)::BIGINT FROM purchase_requests;
    
    RETURN QUERY
    SELECT 'Migrated PRs'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE source_system = 'MIGRATION';
    
    RETURN QUERY
    SELECT 'Manual PRs'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE source_system != 'MIGRATION' OR source_system IS NULL;
    
    RETURN QUERY
    SELECT 'Total PR Items'::TEXT, COUNT(*)::BIGINT FROM purchase_request_items;
    
    RETURN QUERY
    SELECT 'PR-PO Linkages'::TEXT, COUNT(*)::BIGINT FROM pr_po_linkage;
    
    RETURN QUERY
    SELECT 'Document Flow Entries'::TEXT, COUNT(*)::BIGINT FROM document_flow WHERE source_type = 'PR';
    
    RETURN QUERY
    SELECT 'Status: Draft'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE status = 'draft';
    
    RETURN QUERY
    SELECT 'Status: Submitted'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE status = 'submitted';
    
    RETURN QUERY
    SELECT 'Status: Approved'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE status = 'approved';
    
    RETURN QUERY
    SELECT 'Status: Closed'::TEXT, COUNT(*)::BIGINT FROM purchase_requests WHERE status = 'closed';
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION migrate_pos_to_prs(DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_pr_migration() TO authenticated;
GRANT EXECUTE ON FUNCTION get_migration_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION create_sample_prs(INT) TO authenticated;
-- rollback_pr_migration intentionally restricted to direct DB access only

-- ============================================================================
-- COMMIT TRANSACTION
-- ============================================================================

COMMIT;

-- ============================================================================
-- USAGE INSTRUCTIONS:
-- ============================================================================
-- 
-- 1. Run migration:
--    SELECT * FROM migrate_pos_to_prs('2020-01-01', CURRENT_DATE);
--
-- 2. Validate migration:
--    SELECT * FROM validate_pr_migration();
--
-- 3. View summary:
--    SELECT * FROM get_migration_summary();
--
-- 4. Create test data:
--    SELECT create_sample_prs(10);
--
-- 5. Rollback if needed:
--    SELECT rollback_pr_migration();
--
-- ============================================================================
-- END OF PR_MIGRATION_BACKFILL.sql
-- ============================================================================
