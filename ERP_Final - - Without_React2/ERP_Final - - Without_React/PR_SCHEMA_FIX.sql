-- ============================================================================
-- SAKURA ERP - PR SCHEMA FIX
-- CRITICAL: Remove duplicate foreign keys causing PostgREST PGRST201 error
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-01-25
-- Issue: "Could not embed because more than one relationship was found"
-- ============================================================================

-- ============================================================================
-- STEP 1: DROP DUPLICATE FOREIGN KEYS ON purchase_request_items
-- ============================================================================

-- Drop duplicate FK to purchase_requests (keep purchase_request_items_pr_id_fkey)
ALTER TABLE purchase_request_items DROP CONSTRAINT IF EXISTS fk_pri_pr;

-- Drop duplicate FK to inventory_items (keep purchase_request_items_item_id_fkey)
ALTER TABLE purchase_request_items DROP CONSTRAINT IF EXISTS fk_pri_item;

-- ============================================================================
-- STEP 2: DROP DUPLICATE FOREIGN KEYS ON purchase_requests
-- ============================================================================

-- Drop duplicate FK to users for requester_id
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_requester;

-- Drop duplicate FK to users for created_by
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_created_by;

-- Drop duplicate FK to users for approved_by
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS fk_pr_approved_by;

-- ============================================================================
-- STEP 3: VERIFY REMAINING CONSTRAINTS
-- ============================================================================

DO $$
DECLARE
    fk_record RECORD;
    fk_count INT;
BEGIN
    -- Check purchase_request_items FK count to purchase_requests
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'purchase_request_items'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'purchase_requests';
    
    IF fk_count > 1 THEN
        RAISE WARNING 'Still have % FKs from purchase_request_items to purchase_requests!', fk_count;
    ELSE
        RAISE NOTICE '✅ purchase_request_items → purchase_requests: % FK (correct)', fk_count;
    END IF;
    
    -- Check purchase_requests FK count to users
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'purchase_requests'
      AND tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'users'
      AND kcu.column_name = 'requester_id';
    
    IF fk_count > 1 THEN
        RAISE WARNING 'Still have % FKs for requester_id!', fk_count;
    ELSE
        RAISE NOTICE '✅ purchase_requests.requester_id → users: % FK (correct)', fk_count;
    END IF;
END $$;

-- ============================================================================
-- STEP 4: LIST ALL REMAINING FOREIGN KEYS (Verification)
-- ============================================================================

DO $$
DECLARE
    fk_record RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FOREIGN KEYS ON purchase_request_items ===';
    FOR fk_record IN
        SELECT tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.table_name = 'purchase_request_items' AND tc.constraint_type = 'FOREIGN KEY'
    LOOP
        RAISE NOTICE '  FK: % (% → %)', fk_record.constraint_name, fk_record.column_name, fk_record.foreign_table;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== FOREIGN KEYS ON purchase_requests ===';
    FOR fk_record IN
        SELECT tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.table_name = 'purchase_requests' AND tc.constraint_type = 'FOREIGN KEY'
    LOOP
        RAISE NOTICE '  FK: % (% → %)', fk_record.constraint_name, fk_record.column_name, fk_record.foreign_table;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 5: ENSURE PROPER INDEXES EXIST
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pri_pr_id ON purchase_request_items(pr_id);
CREATE INDEX IF NOT EXISTS idx_pri_item_id ON purchase_request_items(item_id);
CREATE INDEX IF NOT EXISTS idx_pri_status ON purchase_request_items(status);
CREATE INDEX IF NOT EXISTS idx_pri_deleted ON purchase_request_items(deleted);

CREATE INDEX IF NOT EXISTS idx_pr_status ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_pr_department ON purchase_requests(department);
CREATE INDEX IF NOT EXISTS idx_pr_requester_id ON purchase_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_pr_deleted ON purchase_requests(deleted);
CREATE INDEX IF NOT EXISTS idx_pr_business_date ON purchase_requests(business_date);
CREATE INDEX IF NOT EXISTS idx_pr_created_at ON purchase_requests(created_at DESC);

-- ============================================================================
-- STEP 6: SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ PR SCHEMA FIX COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Duplicate foreign keys have been removed.';
    RAISE NOTICE 'PostgREST PGRST201 error should be resolved.';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Run PR_RLS_FIX.sql to fix RLS policies.';
END $$;

-- ============================================================================
-- END OF PR_SCHEMA_FIX.sql
-- ============================================================================
