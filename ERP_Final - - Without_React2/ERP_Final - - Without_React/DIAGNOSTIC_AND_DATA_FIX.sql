-- ============================================================================
-- SAKURA ERP - DIAGNOSTIC AND DATA FIX
-- ============================================================================
-- Version: 1.0.0
-- Date: 2026-01-26
-- Purpose: Diagnose issues and properly backfill all existing data
-- ============================================================================

-- ============================================================================
-- PART 1: DIAGNOSTIC - Check current state of data
-- ============================================================================

DO $$
DECLARE
    v_pr_count INT;
    v_pr_with_po INT;
    v_po_count INT;
    v_grn_count INT;
    v_linkage_count INT;
    v_doc_flow_count INT;
    v_pr_history_count INT;
BEGIN
    -- Count PRs
    SELECT COUNT(*) INTO v_pr_count FROM purchase_requests WHERE deleted = FALSE OR deleted IS NULL;
    
    -- Count PRs that have items with po_id set (converted)
    SELECT COUNT(DISTINCT pr_id) INTO v_pr_with_po 
    FROM purchase_request_items 
    WHERE po_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL);
    
    -- Count POs
    SELECT COUNT(*) INTO v_po_count FROM purchase_orders WHERE deleted = FALSE OR deleted IS NULL;
    
    -- Count GRNs with PO
    SELECT COUNT(*) INTO v_grn_count 
    FROM grn_inspections 
    WHERE purchase_order_id IS NOT NULL AND (deleted = FALSE OR deleted IS NULL);
    
    -- Count pr_po_linkage records
    SELECT COUNT(*) INTO v_linkage_count FROM pr_po_linkage WHERE status = 'active';
    
    -- Count document_flow records
    SELECT COUNT(*) INTO v_doc_flow_count FROM document_flow;
    
    -- Count pr_status_history records
    SELECT COUNT(*) INTO v_pr_history_count FROM pr_status_history;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'DIAGNOSTIC REPORT';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Total Purchase Requests: %', v_pr_count;
    RAISE NOTICE 'PRs with PO conversions (pri.po_id set): %', v_pr_with_po;
    RAISE NOTICE 'Total Purchase Orders: %', v_po_count;
    RAISE NOTICE 'GRNs linked to POs: %', v_grn_count;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'pr_po_linkage records: %', v_linkage_count;
    RAISE NOTICE 'document_flow records: %', v_doc_flow_count;
    RAISE NOTICE 'pr_status_history records: %', v_pr_history_count;
    RAISE NOTICE '============================================';
    
    IF v_linkage_count = 0 AND v_pr_with_po > 0 THEN
        RAISE NOTICE '⚠️  ISSUE: PRs have PO links but pr_po_linkage is EMPTY!';
    END IF;
    
    IF v_doc_flow_count = 0 AND v_po_count > 0 THEN
        RAISE NOTICE '⚠️  ISSUE: POs exist but document_flow is EMPTY!';
    END IF;
END $$;

-- ============================================================================
-- PART 2: BACKFILL pr_po_linkage from purchase_request_items
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
    v_pri RECORD;
    v_pr RECORD;
    v_po RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Backfilling pr_po_linkage from purchase_request_items...';
    
    -- Find all PR items that have po_id but no linkage record
    FOR v_pri IN 
        SELECT 
            pri.id AS pri_id,
            pri.pr_id,
            pri.item_number,
            pri.quantity,
            pri.estimated_price,
            pri.unit,
            pri.po_id,
            pri.po_number
        FROM purchase_request_items pri
        WHERE pri.po_id IS NOT NULL
          AND (pri.deleted = FALSE OR pri.deleted IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM pr_po_linkage ppl
              WHERE ppl.pr_item_id = pri.id
                AND ppl.po_id = pri.po_id
          )
    LOOP
        -- Get PR details
        SELECT pr_number INTO v_pr
        FROM purchase_requests
        WHERE id = v_pri.pr_id;
        
        -- Get PO details
        SELECT po_number INTO v_po
        FROM purchase_orders
        WHERE id = v_pri.po_id;
        
        -- Insert linkage record
        INSERT INTO pr_po_linkage (
            pr_id,
            pr_number,
            pr_item_id,
            pr_item_number,
            po_id,
            po_number,
            pr_quantity,
            converted_quantity,
            remaining_quantity,
            unit,
            pr_estimated_price,
            conversion_type,
            status,
            converted_at,
            created_at
        ) VALUES (
            v_pri.pr_id,
            v_pr.pr_number,
            v_pri.pri_id,
            v_pri.item_number,
            v_pri.po_id,
            COALESCE(v_pri.po_number, v_po.po_number),
            v_pri.quantity,
            v_pri.quantity, -- Assume full conversion
            0,
            COALESCE(v_pri.unit, 'EA'),
            v_pri.estimated_price,
            'full',
            'active',
            NOW(),
            NOW()
        )
        ON CONFLICT DO NOTHING;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Created % pr_po_linkage records from purchase_request_items', v_count;
END $$;

-- ============================================================================
-- PART 3: BACKFILL pr_po_linkage from purchase_order_items (alternative source)
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
    v_poi RECORD;
    v_pri RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Checking PO items for PR links via notes/references...';
    
    -- Check if PO notes contain PR references
    FOR v_poi IN
        SELECT 
            po.id AS po_id,
            po.po_number,
            po.notes,
            po.supplier_name
        FROM purchase_orders po
        WHERE po.notes LIKE '%PR-%'
          AND (po.deleted = FALSE OR po.deleted IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM pr_po_linkage ppl WHERE ppl.po_id = po.id
          )
    LOOP
        -- Extract PR number from notes if present
        RAISE NOTICE 'Found PO % with PR reference in notes: %', v_poi.po_number, LEFT(v_poi.notes, 50);
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Found % POs with PR references in notes (manual review needed)', v_count;
END $$;

-- ============================================================================
-- PART 4: BACKFILL document_flow - PR → PO
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Backfilling document_flow for PR → PO...';
    
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 
        'PR', 
        ppl.pr_id, 
        ppl.pr_number,
        'PO', 
        uuid_generate_v5(uuid_ns_oid(), 'PO-' || ppl.po_id::TEXT), 
        ppl.po_number,
        'converted_to', 
        COALESCE(ppl.converted_at, NOW())
    FROM pr_po_linkage ppl
    WHERE ppl.pr_number IS NOT NULL 
      AND ppl.po_number IS NOT NULL
      AND ppl.status = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM document_flow df
        WHERE df.source_type = 'PR' 
          AND df.source_number = ppl.pr_number
          AND df.target_type = 'PO' 
          AND df.target_number = ppl.po_number
    )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % PR → PO document_flow records', v_count;
END $$;

-- ============================================================================
-- PART 5: BACKFILL document_flow - PO → GRN
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Backfilling document_flow for PO → GRN...';
    
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 
        'PO', 
        uuid_generate_v5(uuid_ns_oid(), 'PO-' || gi.purchase_order_id::TEXT), 
        gi.purchase_order_number,
        'GRN', 
        gi.id, 
        gi.grn_number, 
        'goods_received', 
        COALESCE(gi.grn_date, NOW())
    FROM grn_inspections gi
    WHERE gi.purchase_order_id IS NOT NULL 
      AND gi.purchase_order_number IS NOT NULL
      AND gi.grn_number IS NOT NULL
      AND (gi.deleted = FALSE OR gi.deleted IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM document_flow df
        WHERE df.source_type = 'PO' 
          AND df.source_number = gi.purchase_order_number
          AND df.target_type = 'GRN' 
          AND df.target_number = gi.grn_number
    )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % PO → GRN document_flow records', v_count;
END $$;

-- ============================================================================
-- PART 6: BACKFILL document_flow - GRN → Purchasing Invoice
-- ============================================================================

DO $$
DECLARE
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Backfilling document_flow for GRN → Purchasing Invoice...';
    
    INSERT INTO document_flow (source_type, source_id, source_number, target_type, target_id, target_number, flow_type, created_at)
    SELECT DISTINCT 
        'GRN', 
        pi.grn_id, 
        pi.grn_number,
        'PURCHASING', 
        pi.id, 
        COALESCE(pi.purchasing_number, pi.invoice_number), 
        'invoiced', 
        pi.created_at
    FROM purchasing_invoices pi
    WHERE pi.grn_id IS NOT NULL 
      AND pi.grn_number IS NOT NULL
      AND (pi.deleted = FALSE OR pi.deleted IS NULL)
      AND NOT EXISTS (
        SELECT 1 FROM document_flow df
        WHERE df.source_type = 'GRN' 
          AND df.source_number = pi.grn_number
          AND df.target_type = 'PURCHASING'
          AND df.target_number = COALESCE(pi.purchasing_number, pi.invoice_number)
    )
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'Created % GRN → Purchasing document_flow records', v_count;
END $$;

-- ============================================================================
-- PART 7: RECALCULATE ALL PO ITEM RECEIVED QUANTITIES
-- ============================================================================

DO $$
DECLARE
    v_poi RECORD;
    v_received NUMERIC;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Recalculating PO item received quantities from GRN data...';
    
    FOR v_poi IN
        SELECT 
            poi.id,
            poi.purchase_order_id,
            poi.item_id,
            poi.quantity AS ordered_qty,
            poi.quantity_received AS current_received
        FROM purchase_order_items poi
        JOIN purchase_orders po ON po.id = poi.purchase_order_id
        WHERE po.deleted = FALSE OR po.deleted IS NULL
    LOOP
        -- Calculate received from approved GRNs
        SELECT COALESCE(SUM(gii.received_quantity), 0) INTO v_received
        FROM grn_inspection_items gii
        JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
        WHERE gi.purchase_order_id = v_poi.purchase_order_id
          AND gii.item_id = v_poi.item_id
          AND gi.status IN ('passed', 'approved', 'conditional')
          AND (gi.deleted = FALSE OR gi.deleted IS NULL);
        
        -- Update if different
        IF v_received != COALESCE(v_poi.current_received, 0) THEN
            UPDATE purchase_order_items
            SET quantity_received = v_received
            WHERE id = v_poi.id;
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % PO items with corrected received quantities', v_count;
END $$;

-- ============================================================================
-- PART 8: RECALCULATE ALL PO HEADER TOTALS AND STATUS
-- ============================================================================

DO $$
DECLARE
    v_po RECORD;
    v_total_ordered NUMERIC;
    v_total_received NUMERIC;
    v_new_status TEXT;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Recalculating PO header totals and receiving status...';
    
    FOR v_po IN
        SELECT id, po_number, receiving_status, total_received_quantity
        FROM purchase_orders
        WHERE deleted = FALSE OR deleted IS NULL
    LOOP
        -- Calculate totals from items
        SELECT 
            COALESCE(SUM(quantity), 0),
            COALESCE(SUM(COALESCE(quantity_received, 0)), 0)
        INTO v_total_ordered, v_total_received
        FROM purchase_order_items
        WHERE purchase_order_id = v_po.id;
        
        -- Determine status
        IF v_total_ordered = 0 THEN
            v_new_status := 'not_received';
        ELSIF v_total_received >= v_total_ordered THEN
            v_new_status := 'fully_received';
        ELSIF v_total_received > 0 THEN
            v_new_status := 'partial_received';
        ELSE
            v_new_status := 'not_received';
        END IF;
        
        -- Update PO
        UPDATE purchase_orders
        SET 
            ordered_quantity = v_total_ordered,
            total_received_quantity = v_total_received,
            remaining_quantity = v_total_ordered - v_total_received,
            receiving_status = v_new_status,
            status = CASE 
                WHEN v_new_status = 'fully_received' AND status NOT IN ('closed', 'cancelled') THEN 'fully_received'
                ELSE status
            END
        WHERE id = v_po.id;
        
        v_count := v_count + 1;
        
        -- Log significant updates
        IF v_total_received > 0 THEN
            RAISE NOTICE 'PO %: ordered=%, received=%, status=%', 
                v_po.po_number, v_total_ordered, v_total_received, v_new_status;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % PO headers with corrected totals and status', v_count;
END $$;

-- ============================================================================
-- PART 9: RECALCULATE PR ITEM ORDERED QUANTITIES
-- ============================================================================

DO $$
DECLARE
    v_pri RECORD;
    v_total_ordered NUMERIC;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Recalculating PR item ordered quantities from linkage...';
    
    FOR v_pri IN
        SELECT id, pr_id, quantity, quantity_ordered
        FROM purchase_request_items
        WHERE deleted = FALSE OR deleted IS NULL
    LOOP
        -- Calculate from linkage
        SELECT COALESCE(SUM(converted_quantity), 0) INTO v_total_ordered
        FROM pr_po_linkage
        WHERE pr_item_id = v_pri.id AND status = 'active';
        
        -- Also check if po_id is set directly
        IF v_total_ordered = 0 THEN
            SELECT COALESCE(quantity, 0) INTO v_total_ordered
            FROM purchase_request_items
            WHERE id = v_pri.id AND po_id IS NOT NULL;
            
            -- If po_id is set, assume full quantity ordered
            IF v_total_ordered > 0 THEN
                v_total_ordered := v_pri.quantity;
            ELSE
                v_total_ordered := 0;
            END IF;
        END IF;
        
        -- Update if different
        IF v_total_ordered != COALESCE(v_pri.quantity_ordered, 0) THEN
            UPDATE purchase_request_items
            SET 
                quantity_ordered = v_total_ordered,
                quantity_remaining = quantity - v_total_ordered,
                status = CASE 
                    WHEN v_total_ordered >= quantity THEN 'converted_to_po'
                    WHEN v_total_ordered > 0 THEN 'partially_converted'
                    ELSE status
                END
            WHERE id = v_pri.id;
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % PR items with corrected ordered quantities', v_count;
END $$;

-- ============================================================================
-- PART 10: UPDATE PR STATUS BASED ON ITEM STATUS
-- ============================================================================

DO $$
DECLARE
    v_pr RECORD;
    v_total_qty NUMERIC;
    v_ordered_qty NUMERIC;
    v_new_status TEXT;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Updating PR header status based on item status...';
    
    FOR v_pr IN
        SELECT id, pr_number, status
        FROM purchase_requests
        WHERE deleted = FALSE OR deleted IS NULL
          AND status NOT IN ('draft', 'cancelled', 'rejected', 'closed')
    LOOP
        -- Calculate totals
        SELECT 
            COALESCE(SUM(quantity), 0),
            COALESCE(SUM(COALESCE(quantity_ordered, 0)), 0)
        INTO v_total_qty, v_ordered_qty
        FROM purchase_request_items
        WHERE pr_id = v_pr.id AND (deleted = FALSE OR deleted IS NULL);
        
        -- Determine status
        IF v_total_qty > 0 AND v_ordered_qty >= v_total_qty THEN
            v_new_status := 'fully_ordered';
        ELSIF v_ordered_qty > 0 THEN
            v_new_status := 'partially_ordered';
        ELSE
            v_new_status := v_pr.status; -- Keep current if no orders
        END IF;
        
        -- Update if changed
        IF v_new_status != v_pr.status AND v_new_status IN ('partially_ordered', 'fully_ordered') THEN
            UPDATE purchase_requests
            SET status = v_new_status
            WHERE id = v_pr.id;
            
            RAISE NOTICE 'PR %: % → %', v_pr.pr_number, v_pr.status, v_new_status;
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % PR headers with corrected status', v_count;
END $$;

-- ============================================================================
-- PART 11: CREATE INITIAL STATUS HISTORY FOR PRs WITHOUT HISTORY
-- ============================================================================

DO $$
DECLARE
    v_pr RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '>>> Creating initial status history for PRs without history...';
    
    FOR v_pr IN
        SELECT id, pr_number, status, created_at, requester_name
        FROM purchase_requests
        WHERE NOT EXISTS (
            SELECT 1 FROM pr_status_history WHERE pr_id = purchase_requests.id
        )
    LOOP
        -- Insert creation record
        INSERT INTO pr_status_history (
            pr_id, previous_status, new_status, changed_by_name, change_reason, change_date
        ) VALUES (
            v_pr.id, NULL, 'draft', v_pr.requester_name, 'PR created', v_pr.created_at
        );
        
        -- If current status is not draft, add transition
        IF v_pr.status != 'draft' THEN
            INSERT INTO pr_status_history (
                pr_id, previous_status, new_status, changed_by_name, change_reason, change_date
            ) VALUES (
                v_pr.id, 'draft', v_pr.status, v_pr.requester_name, 
                'Status: ' || v_pr.status, v_pr.created_at + INTERVAL '1 minute'
            );
        END IF;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Created status history for % PRs', v_count;
END $$;

-- ============================================================================
-- PART 12: FINAL VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_linkage_count INT;
    v_doc_flow_count INT;
    v_pr_history_count INT;
    v_po_with_received INT;
    v_pr_with_status INT;
BEGIN
    SELECT COUNT(*) INTO v_linkage_count FROM pr_po_linkage WHERE status = 'active';
    SELECT COUNT(*) INTO v_doc_flow_count FROM document_flow;
    SELECT COUNT(*) INTO v_pr_history_count FROM pr_status_history;
    SELECT COUNT(*) INTO v_po_with_received FROM purchase_orders WHERE total_received_quantity > 0;
    SELECT COUNT(*) INTO v_pr_with_status FROM purchase_requests WHERE status IN ('partially_ordered', 'fully_ordered');
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'FINAL VERIFICATION';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'pr_po_linkage records: %', v_linkage_count;
    RAISE NOTICE 'document_flow records: %', v_doc_flow_count;
    RAISE NOTICE 'pr_status_history records: %', v_pr_history_count;
    RAISE NOTICE 'POs with received quantity: %', v_po_with_received;
    RAISE NOTICE 'PRs with ordered status: %', v_pr_with_status;
    RAISE NOTICE '============================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ DATA FIX COMPLETED';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Hard refresh browser (Ctrl+Shift+R)';
    RAISE NOTICE '2. Check PR Detail page - should show linked POs';
    RAISE NOTICE '3. Check PO List - should show correct receiving status';
    RAISE NOTICE '4. Check PO Detail - header should show correct quantities';
    RAISE NOTICE '============================================';
END $$;

-- ============================================================================
-- PART 13: DEBUG QUERY - Show sample data for verification
-- ============================================================================

-- Show PRs with their linkage count
SELECT 
    pr.pr_number,
    pr.status,
    COUNT(DISTINCT ppl.po_id) AS linked_po_count,
    STRING_AGG(DISTINCT ppl.po_number, ', ') AS linked_pos
FROM purchase_requests pr
LEFT JOIN pr_po_linkage ppl ON ppl.pr_id = pr.id AND ppl.status = 'active'
WHERE pr.deleted = FALSE OR pr.deleted IS NULL
GROUP BY pr.id, pr.pr_number, pr.status
HAVING COUNT(DISTINCT ppl.po_id) > 0
ORDER BY pr.created_at DESC
LIMIT 10;

-- Show POs with receiving status
SELECT 
    po.po_number,
    po.status,
    po.receiving_status,
    po.ordered_quantity,
    po.total_received_quantity,
    po.remaining_quantity,
    (SELECT COUNT(*) FROM grn_inspections gi WHERE gi.purchase_order_id = po.id AND gi.status IN ('passed', 'approved', 'conditional')) AS grn_count
FROM purchase_orders po
WHERE po.deleted = FALSE OR po.deleted IS NULL
ORDER BY po.created_at DESC
LIMIT 10;

-- Show document flow
SELECT 
    source_type,
    source_number,
    target_type,
    target_number,
    flow_type,
    created_at
FROM document_flow
ORDER BY created_at DESC
LIMIT 20;
