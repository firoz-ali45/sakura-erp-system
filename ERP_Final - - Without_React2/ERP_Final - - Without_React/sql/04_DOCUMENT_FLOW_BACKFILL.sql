-- ============================================================================
-- 04_DOCUMENT_FLOW_BACKFILL.sql
-- BACKFILL HISTORICAL DOCUMENT FLOW DATA
-- Populates document_flow and pr_po_linkage for existing data
-- ============================================================================

-- ============================================================================
-- STEP 1: Backfill pr_po_linkage from purchase_request_items.po_id
-- ============================================================================
DO $$
DECLARE
    v_record RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> STEP 1: Backfilling pr_po_linkage from purchase_request_items...';
    
    FOR v_record IN
        SELECT 
            pri.id AS pri_id,
            pri.pr_id,
            pr.pr_number,
            pri.item_number,
            pri.po_id,
            po.po_number,
            pri.quantity,
            pri.unit
        FROM purchase_request_items pri
        JOIN purchase_requests pr ON pr.id = pri.pr_id
        JOIN purchase_orders po ON po.id = pri.po_id
        WHERE pri.po_id IS NOT NULL
          AND (pri.deleted = FALSE OR pri.deleted IS NULL)
          AND pr.deleted = FALSE
          AND po.deleted = FALSE
          AND NOT EXISTS (
              SELECT 1 FROM pr_po_linkage ppl 
              WHERE ppl.pr_item_id = pri.id 
                AND ppl.po_id = pri.po_id
          )
    LOOP
        INSERT INTO pr_po_linkage (
            pr_id, pr_number, pr_item_id, pr_item_number,
            po_id, po_number,
            pr_quantity, converted_quantity, remaining_quantity,
            unit, conversion_type, status, converted_at
        ) VALUES (
            v_record.pr_id,
            v_record.pr_number,
            v_record.pri_id,
            v_record.item_number,
            v_record.po_id,
            v_record.po_number,
            v_record.quantity,
            v_record.quantity,
            0,
            COALESCE(v_record.unit, 'EA'),
            'full',
            'active',
            NOW()
        )
        ON CONFLICT DO NOTHING;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Created % pr_po_linkage records', v_count;
END $$;

-- ============================================================================
-- STEP 2: Backfill pr_po_linkage by matching item names
-- ============================================================================
DO $$
DECLARE
    v_record RECORD;
    v_count INT := 0;
BEGIN
    RAISE NOTICE '>>> STEP 2: Backfilling pr_po_linkage by item name matching...';
    
    FOR v_record IN
        SELECT DISTINCT
            pri.id AS pri_id,
            pri.pr_id,
            pr.pr_number,
            pri.item_number,
            poi.purchase_order_id AS po_id,
            po.po_number,
            pri.quantity,
            pri.unit
        FROM purchase_request_items pri
        JOIN purchase_requests pr ON pr.id = pri.pr_id
        JOIN purchase_order_items poi ON (
            poi.item_id = pri.item_id 
            OR LOWER(poi.item_name) LIKE '%' || LOWER(SUBSTRING(pri.item_name, 1, 20)) || '%'
        )
        JOIN purchase_orders po ON po.id = poi.purchase_order_id
        WHERE pri.po_id IS NULL
          AND (pri.deleted = FALSE OR pri.deleted IS NULL)
          AND pr.deleted = FALSE
          AND po.deleted = FALSE
          AND pr.status IN ('approved', 'partially_ordered', 'fully_ordered')
          AND NOT EXISTS (
              SELECT 1 FROM pr_po_linkage ppl 
              WHERE ppl.pr_id = pri.pr_id 
                AND ppl.po_id = poi.purchase_order_id
          )
    LOOP
        -- Update the PR item with PO reference
        UPDATE purchase_request_items
        SET 
            po_id = v_record.po_id,
            po_number = v_record.po_number,
            quantity_ordered = v_record.quantity,
            status = 'converted_to_po',
            is_locked = TRUE,
            updated_at = NOW()
        WHERE id = v_record.pri_id;
        
        -- Insert linkage
        INSERT INTO pr_po_linkage (
            pr_id, pr_number, pr_item_id, pr_item_number,
            po_id, po_number,
            pr_quantity, converted_quantity, remaining_quantity,
            unit, conversion_type, status, converted_at
        ) VALUES (
            v_record.pr_id,
            v_record.pr_number,
            v_record.pri_id,
            v_record.item_number,
            v_record.po_id,
            v_record.po_number,
            v_record.quantity,
            v_record.quantity,
            0,
            COALESCE(v_record.unit, 'EA'),
            'full',
            'active',
            NOW()
        )
        ON CONFLICT DO NOTHING;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Created % additional pr_po_linkage records via name matching', v_count;
END $$;

-- ============================================================================
-- STEP 3: Backfill document_flow for PR → PO
-- ============================================================================
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PR',
    ppl.pr_id::TEXT,
    ppl.pr_number,
    'PO',
    ppl.po_id::TEXT,
    ppl.po_number,
    'converted_to_po',
    COALESCE(ppl.converted_at, NOW())
FROM pr_po_linkage ppl
WHERE ppl.status = 'active'
  AND NOT EXISTS (
      SELECT 1 FROM document_flow df
      WHERE df.source_type = 'PR'
        AND df.source_id = ppl.pr_id::TEXT
        AND df.target_type = 'PO'
        AND df.target_id = ppl.po_id::TEXT
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 4: Backfill document_flow for PO → GRN
-- ============================================================================
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PO',
    gi.purchase_order_id::TEXT,
    COALESCE(gi.purchase_order_number, po.po_number),
    'GRN',
    gi.id::TEXT,
    gi.grn_number,
    'goods_received',
    COALESCE(gi.created_at, NOW())
FROM grn_inspections gi
JOIN purchase_orders po ON po.id = gi.purchase_order_id
WHERE gi.deleted = FALSE
  AND gi.purchase_order_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM document_flow df
      WHERE df.source_type = 'PO'
        AND df.source_id = gi.purchase_order_id::TEXT
        AND df.target_type = 'GRN'
        AND df.target_id = gi.id::TEXT
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 5: Backfill document_flow for GRN → PUR
-- ============================================================================
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'GRN',
    pi.grn_id::TEXT,
    COALESCE(pi.grn_number, gi.grn_number),
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'invoice_created',
    COALESCE(pi.created_at, NOW())
FROM purchasing_invoices pi
JOIN grn_inspections gi ON gi.id = pi.grn_id
WHERE pi.deleted = FALSE
  AND pi.grn_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM document_flow df
      WHERE df.source_type = 'GRN'
        AND df.source_id = pi.grn_id::TEXT
        AND df.target_type = 'PUR'
        AND df.target_id = pi.id::TEXT
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 6: Backfill document_flow for PO → PUR (direct, no GRN)
-- ============================================================================
INSERT INTO document_flow (
    source_type, source_id, source_number,
    target_type, target_id, target_number,
    flow_type, created_at
)
SELECT DISTINCT
    'PO',
    pi.purchase_order_id::TEXT,
    COALESCE(pi.purchase_order_number, po.po_number),
    'PUR',
    pi.id::TEXT,
    pi.purchasing_number,
    'invoice_created',
    COALESCE(pi.created_at, NOW())
FROM purchasing_invoices pi
JOIN purchase_orders po ON po.id = pi.purchase_order_id
WHERE pi.deleted = FALSE
  AND pi.purchase_order_id IS NOT NULL
  AND pi.grn_id IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM document_flow df
      WHERE df.source_type = 'PO'
        AND df.source_id = pi.purchase_order_id::TEXT
        AND df.target_type = 'PUR'
        AND df.target_id = pi.id::TEXT
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 7: Update PR statuses based on linked items
-- ============================================================================
DO $$
DECLARE
    v_pr RECORD;
    v_total INT;
    v_converted INT;
BEGIN
    RAISE NOTICE '>>> STEP 7: Updating PR statuses...';
    
    FOR v_pr IN
        SELECT id, pr_number, status
        FROM purchase_requests
        WHERE deleted = FALSE
          AND status IN ('approved', 'partially_ordered', 'fully_ordered')
    LOOP
        SELECT 
            COUNT(*),
            COUNT(CASE WHEN po_id IS NOT NULL THEN 1 END)
        INTO v_total, v_converted
        FROM purchase_request_items
        WHERE pr_id = v_pr.id
          AND (deleted = FALSE OR deleted IS NULL);
        
        IF v_total > 0 THEN
            IF v_converted >= v_total THEN
                UPDATE purchase_requests
                SET status = 'fully_ordered', updated_at = NOW()
                WHERE id = v_pr.id AND status != 'fully_ordered';
            ELSIF v_converted > 0 THEN
                UPDATE purchase_requests
                SET status = 'partially_ordered', updated_at = NOW()
                WHERE id = v_pr.id AND status NOT IN ('partially_ordered', 'fully_ordered');
            END IF;
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 8: Update PO receiving statuses
-- ============================================================================
DO $$
DECLARE
    v_po RECORD;
    v_total_ordered NUMERIC;
    v_total_received NUMERIC;
    v_new_status TEXT;
BEGIN
    RAISE NOTICE '>>> STEP 8: Updating PO receiving statuses...';
    
    FOR v_po IN
        SELECT id, po_number
        FROM purchase_orders
        WHERE deleted = FALSE
    LOOP
        -- Calculate totals
        SELECT 
            COALESCE(SUM(quantity), 0),
            COALESCE(SUM(quantity_received), 0)
        INTO v_total_ordered, v_total_received
        FROM purchase_order_items
        WHERE purchase_order_id = v_po.id;
        
        -- Update item received quantities from GRNs
        UPDATE purchase_order_items poi
        SET quantity_received = (
            SELECT COALESCE(SUM(gii.received_quantity), 0)
            FROM grn_inspection_items gii
            JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            WHERE gi.purchase_order_id = v_po.id
              AND gii.item_id = poi.item_id
              AND gi.status IN ('approved', 'passed', 'completed')
        )
        WHERE poi.purchase_order_id = v_po.id;
        
        -- Recalculate after update
        SELECT 
            COALESCE(SUM(quantity), 0),
            COALESCE(SUM(quantity_received), 0)
        INTO v_total_ordered, v_total_received
        FROM purchase_order_items
        WHERE purchase_order_id = v_po.id;
        
        -- Determine status
        IF v_total_received >= v_total_ordered AND v_total_ordered > 0 THEN
            v_new_status := 'fully_received';
        ELSIF v_total_received > 0 THEN
            v_new_status := 'partial_received';
        ELSE
            v_new_status := 'not_received';
        END IF;
        
        -- Update PO
        UPDATE purchase_orders
        SET 
            total_received_quantity = v_total_received,
            remaining_quantity = GREATEST(0, v_total_ordered - v_total_received),
            receiving_status = v_new_status,
            updated_at = NOW()
        WHERE id = v_po.id;
    END LOOP;
END $$;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
SELECT 'Backfill Summary' AS report;
SELECT 'pr_po_linkage' AS table_name, COUNT(*) AS count FROM pr_po_linkage WHERE status = 'active';
SELECT 'document_flow (PR→PO)' AS flow_type, COUNT(*) AS count FROM document_flow WHERE source_type = 'PR' AND target_type = 'PO';
SELECT 'document_flow (PO→GRN)' AS flow_type, COUNT(*) AS count FROM document_flow WHERE source_type = 'PO' AND target_type = 'GRN';
SELECT 'document_flow (GRN→PUR)' AS flow_type, COUNT(*) AS count FROM document_flow WHERE source_type = 'GRN' AND target_type = 'PUR';

-- Show sample chain
SELECT 'Sample Document Chain:' AS info;
SELECT * FROM fn_get_document_flow('PR', (SELECT id::TEXT FROM purchase_requests WHERE deleted = FALSE LIMIT 1));
