-- ============================================================================
-- FIX PR-PO LINKAGE - DIAGNOSTIC AND REPAIR
-- ============================================================================
-- Run this to find POs and link them back to their source PRs
-- ============================================================================

-- STEP 1: DIAGNOSTIC - Show all POs and their notes (might contain PR reference)
SELECT 
    id as po_id,
    po_number,
    supplier_name,
    status,
    order_date,
    notes,
    total_amount
FROM purchase_orders 
WHERE deleted = FALSE
ORDER BY created_at DESC;

-- STEP 2: DIAGNOSTIC - Show all PRs
SELECT 
    id as pr_id,
    pr_number,
    status,
    requester_name,
    estimated_total_value,
    created_at
FROM purchase_requests
WHERE deleted = FALSE
ORDER BY created_at DESC;

-- STEP 3: Check if any purchase_request_items have po_id set
SELECT 
    pri.id as pri_id,
    pri.pr_id,
    pr.pr_number,
    pri.item_name,
    pri.quantity,
    pri.po_id,
    pri.po_number,
    pri.status as item_status
FROM purchase_request_items pri
JOIN purchase_requests pr ON pr.id = pri.pr_id
WHERE (pri.deleted = FALSE OR pri.deleted IS NULL)
ORDER BY pr.created_at DESC;

-- STEP 4: Check purchase_order_items
SELECT 
    poi.id as poi_id,
    poi.purchase_order_id,
    poi.po_number,
    poi.item_name,
    poi.quantity,
    poi.quantity_received
FROM purchase_order_items poi
ORDER BY poi.purchase_order_id;

-- ============================================================================
-- STEP 5: AUTO-LINK PRs to POs by matching item names
-- This finds PRs and POs that have the same item names and creates linkage
-- ============================================================================

DO $$
DECLARE
    v_pr RECORD;
    v_pri RECORD;
    v_po RECORD;
    v_poi RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> Starting PR-PO Auto-Linkage...';
    
    -- For each PR item that doesn't have a PO linked
    FOR v_pri IN 
        SELECT 
            pri.id as pri_id,
            pri.pr_id,
            pr.pr_number,
            pri.item_number,
            pri.item_id,
            pri.item_name,
            pri.quantity,
            pri.unit
        FROM purchase_request_items pri
        JOIN purchase_requests pr ON pr.id = pri.pr_id
        WHERE (pri.deleted = FALSE OR pri.deleted IS NULL)
          AND pri.po_id IS NULL
          AND pr.status IN ('approved', 'partially_ordered', 'fully_ordered')
    LOOP
        -- Find a matching PO item by item_name or item_id
        FOR v_poi IN 
            SELECT 
                poi.id as poi_id,
                poi.purchase_order_id,
                po.po_number,
                poi.item_name,
                poi.quantity
            FROM purchase_order_items poi
            JOIN purchase_orders po ON po.id = poi.purchase_order_id
            WHERE (po.deleted = FALSE OR po.deleted IS NULL)
              AND (
                  -- Match by item_id if both have it
                  (poi.item_id IS NOT NULL AND poi.item_id = v_pri.item_id)
                  OR
                  -- Match by item_name (case-insensitive partial match)
                  (LOWER(poi.item_name) LIKE '%' || LOWER(SUBSTRING(v_pri.item_name, 1, 20)) || '%')
              )
            LIMIT 1
        LOOP
            RAISE NOTICE 'Found match: PR % item "%" -> PO % item "%"', 
                v_pri.pr_number, v_pri.item_name, v_poi.po_number, v_poi.item_name;
            
            -- Update purchase_request_items with po_id
            UPDATE purchase_request_items
            SET 
                po_id = v_poi.purchase_order_id,
                po_number = v_poi.po_number,
                quantity_ordered = v_pri.quantity,
                status = 'converted_to_po',
                conversion_date = NOW(),
                is_locked = TRUE,
                lock_reason = 'Converted to PO (auto-linked)'
            WHERE id = v_pri.pri_id;
            
            -- Insert into pr_po_linkage
            INSERT INTO pr_po_linkage (
                pr_id, pr_number, pr_item_id, pr_item_number,
                po_id, po_number,
                pr_quantity, converted_quantity, remaining_quantity,
                unit, conversion_type, status, converted_at
            ) VALUES (
                v_pri.pr_id, v_pri.pr_number, v_pri.pri_id, v_pri.item_number,
                v_poi.purchase_order_id, v_poi.po_number,
                v_pri.quantity, v_pri.quantity, 0,
                COALESCE(v_pri.unit, 'EA'), 'full', 'active', NOW()
            )
            ON CONFLICT DO NOTHING;
            
            -- Insert document_flow
            INSERT INTO document_flow (
                source_type, source_id, source_number,
                target_type, target_id, target_number,
                flow_type, created_at
            ) VALUES (
                'PR', v_pri.pr_id::TEXT, v_pri.pr_number,
                'PO', v_poi.purchase_order_id::TEXT, v_poi.po_number,
                'converted_to', NOW()
            )
            ON CONFLICT DO NOTHING;
            
            v_count := v_count + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Created % PR-PO linkages', v_count;
END $$;

-- ============================================================================
-- STEP 6: Update PR status based on linked items
-- ============================================================================

DO $$
DECLARE
    v_pr RECORD;
    v_total_items INT;
    v_linked_items INT;
BEGIN
    RAISE NOTICE '>>> Updating PR statuses...';
    
    FOR v_pr IN 
        SELECT id, pr_number, status
        FROM purchase_requests
        WHERE deleted = FALSE
          AND status IN ('approved', 'partially_ordered', 'fully_ordered')
    LOOP
        -- Count total items and linked items
        SELECT 
            COUNT(*),
            COUNT(CASE WHEN po_id IS NOT NULL THEN 1 END)
        INTO v_total_items, v_linked_items
        FROM purchase_request_items
        WHERE pr_id = v_pr.id
          AND (deleted = FALSE OR deleted IS NULL);
        
        -- Update PR status
        IF v_total_items > 0 AND v_linked_items >= v_total_items THEN
            UPDATE purchase_requests 
            SET status = 'fully_ordered', updated_at = NOW()
            WHERE id = v_pr.id AND status != 'fully_ordered';
            
            IF FOUND THEN
                RAISE NOTICE 'PR % updated to fully_ordered', v_pr.pr_number;
            END IF;
        ELSIF v_linked_items > 0 THEN
            UPDATE purchase_requests 
            SET status = 'partially_ordered', updated_at = NOW()
            WHERE id = v_pr.id AND status NOT IN ('partially_ordered', 'fully_ordered');
            
            IF FOUND THEN
                RAISE NOTICE 'PR % updated to partially_ordered', v_pr.pr_number;
            END IF;
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 7: VERIFICATION - Show final results
-- ============================================================================

SELECT 'pr_po_linkage count' as metric, COUNT(*)::text as value FROM pr_po_linkage WHERE status = 'active'
UNION ALL
SELECT 'PR items with po_id', COUNT(*)::text FROM purchase_request_items WHERE po_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL)
UNION ALL
SELECT 'document_flow count', COUNT(*)::text FROM document_flow WHERE source_type = 'PR' AND target_type = 'PO';

-- Show PRs with their linked PO counts now
SELECT 
    pr.pr_number,
    pr.status,
    (SELECT COUNT(DISTINCT ppl.po_id) FROM pr_po_linkage ppl WHERE ppl.pr_id = pr.id AND ppl.status = 'active') as linkage_count,
    (SELECT COUNT(DISTINCT pri.po_id) FROM purchase_request_items pri WHERE pri.pr_id = pr.id AND pri.po_id IS NOT NULL AND (pri.deleted = FALSE OR pri.deleted IS NULL)) as items_po_count
FROM purchase_requests pr
WHERE pr.deleted = FALSE
ORDER BY pr.created_at DESC
LIMIT 10;
