-- ============================================================================
-- SAKURA ERP - PR STATUS WORKFLOW ENGINE & PO CONVERSION
-- SAP MM Status Management Architecture
-- ============================================================================
-- File: PR_TO_PO_TRIGGER.sql
-- Purpose: Status workflow enforcement and PR to PO conversion procedure
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- STATUS WORKFLOW DEFINITIONS
-- ============================================================================
-- 
-- Valid Status Transitions:
-- ┌─────────────────────────────────────────────────────────────────────┐
-- │  draft ──────┬──────► submitted ───────► under_review              │
-- │              │              │                  │                    │
-- │              ▼              ▼                  ▼                    │
-- │         cancelled      rejected           approved                 │
-- │                                               │                    │
-- │                                   ┌───────────┴───────────┐        │
-- │                                   ▼                       ▼        │
-- │                          partially_ordered ──────► fully_ordered   │
-- │                                   │                       │        │
-- │                                   └───────────┬───────────┘        │
-- │                                               ▼                    │
-- │                                            closed                  │
-- └─────────────────────────────────────────────────────────────────────┘
-- ============================================================================

-- ============================================================================
-- TABLE: pr_status_transitions
-- Description: Defines valid status transitions (configurable workflow)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_status_transitions (
    id SERIAL PRIMARY KEY,
    from_status TEXT NOT NULL,
    to_status TEXT NOT NULL,
    requires_role TEXT[],
    requires_approval BOOLEAN DEFAULT FALSE,
    auto_transition BOOLEAN DEFAULT FALSE,
    description TEXT,
    
    CONSTRAINT unique_transition UNIQUE (from_status, to_status)
);

-- Insert valid transitions
INSERT INTO pr_status_transitions (from_status, to_status, requires_role, requires_approval, auto_transition, description)
VALUES
    -- Draft transitions
    ('draft', 'submitted', ARRAY['requester', 'admin'], FALSE, FALSE, 'Submit PR for approval'),
    ('draft', 'cancelled', ARRAY['requester', 'admin'], FALSE, FALSE, 'Cancel draft PR'),
    
    -- Submitted transitions
    ('submitted', 'under_review', ARRAY['approver', 'manager', 'admin'], FALSE, FALSE, 'Begin review process'),
    ('submitted', 'approved', ARRAY['approver', 'manager', 'admin'], TRUE, FALSE, 'Direct approval'),
    ('submitted', 'rejected', ARRAY['approver', 'manager', 'admin'], FALSE, FALSE, 'Reject PR'),
    ('submitted', 'draft', ARRAY['requester', 'admin'], FALSE, FALSE, 'Return to draft for editing'),
    
    -- Under Review transitions
    ('under_review', 'approved', ARRAY['approver', 'manager', 'admin'], TRUE, FALSE, 'Approve after review'),
    ('under_review', 'rejected', ARRAY['approver', 'manager', 'admin'], FALSE, FALSE, 'Reject after review'),
    ('under_review', 'submitted', ARRAY['approver', 'manager', 'admin'], FALSE, FALSE, 'Request more info'),
    
    -- Approved transitions
    ('approved', 'partially_ordered', ARRAY['procurement', 'admin'], FALSE, TRUE, 'Partial PO created'),
    ('approved', 'fully_ordered', ARRAY['procurement', 'admin'], FALSE, TRUE, 'Full PO created'),
    ('approved', 'cancelled', ARRAY['admin'], FALSE, FALSE, 'Cancel approved PR'),
    
    -- Partially Ordered transitions
    ('partially_ordered', 'fully_ordered', ARRAY['procurement', 'admin'], FALSE, TRUE, 'All items ordered'),
    ('partially_ordered', 'closed', ARRAY['procurement', 'admin'], FALSE, FALSE, 'Close with partial order'),
    
    -- Fully Ordered transitions
    ('fully_ordered', 'closed', ARRAY['procurement', 'admin'], FALSE, TRUE, 'Auto-close after full order'),
    
    -- Rejected transitions (can be reopened)
    ('rejected', 'draft', ARRAY['requester', 'admin'], FALSE, FALSE, 'Reopen for revision')
ON CONFLICT (from_status, to_status) DO NOTHING;

-- ============================================================================
-- FUNCTION: is_valid_pr_status_transition()
-- Description: Check if status transition is valid
-- ============================================================================

CREATE OR REPLACE FUNCTION is_valid_pr_status_transition(
    p_from_status TEXT,
    p_to_status TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM pr_status_transitions
        WHERE from_status = p_from_status
        AND to_status = p_to_status
    );
END;
$$;

-- ============================================================================
-- FUNCTION: enforce_pr_status_transition()
-- Description: Trigger function to enforce valid status transitions
-- ============================================================================

CREATE OR REPLACE FUNCTION enforce_pr_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid BOOLEAN;
    v_user_role TEXT;
    v_required_roles TEXT[];
    v_requires_approval BOOLEAN;
BEGIN
    -- Skip if status hasn't changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Check if transition is valid
    SELECT 
        TRUE,
        requires_role,
        requires_approval
    INTO v_valid, v_required_roles, v_requires_approval
    FROM pr_status_transitions
    WHERE from_status = OLD.status
    AND to_status = NEW.status;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid status transition from % to %. Check workflow rules.', 
            OLD.status, NEW.status;
    END IF;
    
    -- Get current user role
    BEGIN
        SELECT role INTO v_user_role
        FROM users
        WHERE id = auth.uid();
    EXCEPTION WHEN OTHERS THEN
        v_user_role := 'system';
    END;
    
    -- Check role permission (skip for system/admin)
    IF v_user_role NOT IN ('system', 'admin', 'superadmin') THEN
        IF v_required_roles IS NOT NULL AND array_length(v_required_roles, 1) > 0 THEN
            IF NOT (v_user_role = ANY(v_required_roles)) THEN
                RAISE EXCEPTION 'Role % not authorized for transition from % to %. Required: %',
                    v_user_role, OLD.status, NEW.status, v_required_roles;
            END IF;
        END IF;
    END IF;
    
    -- Record status change in history
    INSERT INTO pr_status_history (
        pr_id,
        previous_status,
        new_status,
        changed_by,
        changed_by_name,
        change_reason,
        change_date
    ) VALUES (
        NEW.id,
        OLD.status,
        NEW.status,
        auth.uid(),
        (SELECT name FROM users WHERE id = auth.uid()),
        NEW.rejection_reason,
        NOW()
    );
    
    -- Update approval fields based on transition
    IF NEW.status = 'approved' THEN
        NEW.approved_by := COALESCE(NEW.approved_by, auth.uid());
        NEW.approved_at := COALESCE(NEW.approved_at, NOW());
    END IF;
    
    -- Set updated_by
    NEW.updated_by := auth.uid();
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TRIGGER: tr_enforce_pr_status
-- Description: Enforce status workflow on UPDATE
-- ============================================================================

DROP TRIGGER IF EXISTS tr_enforce_pr_status ON purchase_requests;

CREATE TRIGGER tr_enforce_pr_status
    BEFORE UPDATE OF status ON purchase_requests
    FOR EACH ROW
    EXECUTE FUNCTION enforce_pr_status_transition();

-- ============================================================================
-- FUNCTION: update_pr_status_from_items()
-- Description: Update PR header status based on item statuses
-- ============================================================================

CREATE OR REPLACE FUNCTION update_pr_status_from_items(p_pr_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_items INT;
    v_converted_items INT;
    v_partial_items INT;
    v_cancelled_items INT;
    v_current_status TEXT;
    v_new_status TEXT;
BEGIN
    -- Get current PR status
    SELECT status INTO v_current_status
    FROM purchase_requests
    WHERE id = p_pr_id;
    
    -- Only update if PR is in an orderable state
    IF v_current_status NOT IN ('approved', 'partially_ordered', 'fully_ordered') THEN
        RETURN v_current_status;
    END IF;
    
    -- Count item statuses
    SELECT 
        COUNT(*) FILTER (WHERE status != 'cancelled' AND deleted = FALSE),
        COUNT(*) FILTER (WHERE status = 'converted_to_po' AND deleted = FALSE),
        COUNT(*) FILTER (WHERE status = 'partially_converted' AND deleted = FALSE),
        COUNT(*) FILTER (WHERE status = 'cancelled' OR deleted = TRUE)
    INTO v_total_items, v_converted_items, v_partial_items, v_cancelled_items
    FROM purchase_request_items
    WHERE pr_id = p_pr_id;
    
    -- Determine new status
    IF v_total_items = 0 THEN
        v_new_status := 'cancelled';
    ELSIF v_converted_items = v_total_items THEN
        v_new_status := 'fully_ordered';
    ELSIF v_converted_items > 0 OR v_partial_items > 0 THEN
        v_new_status := 'partially_ordered';
    ELSE
        v_new_status := v_current_status;
    END IF;
    
    -- Update if changed
    IF v_new_status != v_current_status THEN
        -- Bypass trigger for auto-transition
        UPDATE purchase_requests
        SET status = v_new_status,
            updated_at = NOW()
        WHERE id = p_pr_id;
        
        -- Log the auto-transition
        INSERT INTO pr_status_history (
            pr_id,
            previous_status,
            new_status,
            changed_by_name,
            change_reason,
            change_date
        ) VALUES (
            p_pr_id,
            v_current_status,
            v_new_status,
            'SYSTEM',
            'Auto-transition based on item conversion status',
            NOW()
        );
    END IF;
    
    RETURN v_new_status;
END;
$$;

-- ============================================================================
-- FUNCTION: convert_pr_to_po()
-- Description: Main conversion procedure - Create PO from PR items
-- Supports: Single PR, Multiple PRs aggregated, Partial conversion
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
    v_po_id BIGINT;
    v_po_number TEXT;
    v_pr RECORD;
    v_item RECORD;
    v_supplier_name TEXT;
    v_total_amount NUMERIC(18, 4) := 0;
    v_items_converted INT := 0;
    v_prs_processed INT := 0;
    v_unit_price NUMERIC(18, 4);
    v_po_item_id BIGINT;
    v_linkage_id UUID;
BEGIN
    -- Validate inputs
    IF p_pr_ids IS NULL OR array_length(p_pr_ids, 1) = 0 THEN
        RAISE EXCEPTION 'No PR IDs provided for conversion';
    END IF;
    
    IF p_supplier_id IS NULL THEN
        RAISE EXCEPTION 'Supplier ID is required';
    END IF;
    
    -- Validate pricing mode
    IF p_pricing_mode NOT IN ('estimated', 'last_po', 'inventory_cost', 'manual') THEN
        RAISE EXCEPTION 'Invalid pricing mode: %. Valid: estimated, last_po, inventory_cost, manual', p_pricing_mode;
    END IF;
    
    -- Get supplier name
    SELECT supplier_name INTO v_supplier_name
    FROM suppliers
    WHERE id = p_supplier_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Supplier with ID % not found', p_supplier_id;
    END IF;
    
    -- Validate all PRs are in approved status
    FOR v_pr IN 
        SELECT id, pr_number, status 
        FROM purchase_requests 
        WHERE id = ANY(p_pr_ids)
    LOOP
        IF v_pr.status NOT IN ('approved', 'partially_ordered') THEN
            RAISE EXCEPTION 'PR % (%) is not in approved/partially_ordered status. Current: %',
                v_pr.pr_number, v_pr.id, v_pr.status;
        END IF;
    END LOOP;
    
    -- Generate PO number (using existing pattern)
    SELECT 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-' || 
           LPAD((COALESCE(MAX(CAST(SUBSTRING(po_number FROM 9) AS INT)), 0) + 1)::TEXT, 6, '0')
    INTO v_po_number
    FROM purchase_orders
    WHERE po_number LIKE 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-%';
    
    IF v_po_number IS NULL THEN
        v_po_number := 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-000001';
    END IF;
    
    -- Create PO header
    INSERT INTO purchase_orders (
        po_number,
        supplier_id,
        supplier_name,
        status,
        total_amount,
        notes,
        created_at,
        updated_at
    ) VALUES (
        v_po_number,
        p_supplier_id,
        v_supplier_name,
        'draft',
        0,
        COALESCE(p_notes, 'Created from PR conversion'),
        NOW(),
        NOW()
    ) RETURNING id INTO v_po_id;
    
    -- Process each PR and its items
    FOR v_pr IN 
        SELECT * FROM purchase_requests 
        WHERE id = ANY(p_pr_ids)
        ORDER BY pr_number
    LOOP
        -- Process each convertible item
        FOR v_item IN
            SELECT * FROM purchase_request_items
            WHERE pr_id = v_pr.id
            AND status IN ('open', 'partially_converted')
            AND deleted = FALSE
            AND (quantity - quantity_ordered) > 0
            ORDER BY item_number
        LOOP
            -- Determine unit price based on pricing mode
            CASE p_pricing_mode
                WHEN 'estimated' THEN
                    v_unit_price := v_item.estimated_price;
                    
                WHEN 'last_po' THEN
                    -- Get last PO price for this item from this supplier
                    SELECT poi.unit_price INTO v_unit_price
                    FROM purchase_order_items poi
                    JOIN purchase_orders po ON po.id = poi.po_id
                    WHERE poi.item_id = v_item.item_id
                    AND po.supplier_id = p_supplier_id
                    ORDER BY po.created_at DESC
                    LIMIT 1;
                    -- Fallback to estimated if no history
                    v_unit_price := COALESCE(v_unit_price, v_item.estimated_price);
                    
                WHEN 'inventory_cost' THEN
                    -- Get cost from inventory_items
                    SELECT cost INTO v_unit_price
                    FROM inventory_items
                    WHERE id = v_item.item_id;
                    v_unit_price := COALESCE(v_unit_price, v_item.estimated_price);
                    
                ELSE
                    v_unit_price := v_item.estimated_price;
            END CASE;
            
            -- Create PO item (check if purchase_order_items table exists and structure)
            -- Assuming standard structure
            INSERT INTO purchase_order_items (
                po_id,
                item_id,
                item_name,
                quantity,
                unit,
                unit_price,
                total_price,
                created_at
            ) VALUES (
                v_po_id,
                v_item.item_id,
                v_item.item_name,
                v_item.quantity - v_item.quantity_ordered,
                v_item.unit,
                v_unit_price,
                (v_item.quantity - v_item.quantity_ordered) * v_unit_price,
                NOW()
            ) RETURNING id INTO v_po_item_id;
            
            -- Create linkage record
            INSERT INTO pr_po_linkage (
                pr_id,
                pr_number,
                pr_item_id,
                pr_item_number,
                po_id,
                po_number,
                po_item_id,
                po_item_number,
                pr_quantity,
                converted_quantity,
                unit,
                pr_estimated_price,
                po_actual_price,
                conversion_type,
                converted_at,
                converted_by
            ) VALUES (
                v_pr.id,
                v_pr.pr_number,
                v_item.id,
                v_item.item_number,
                v_po_id,
                v_po_number,
                v_po_item_id,
                v_items_converted + 1,
                v_item.quantity,
                v_item.quantity - v_item.quantity_ordered,
                v_item.unit,
                v_item.estimated_price,
                v_unit_price,
                CASE 
                    WHEN v_item.quantity_ordered = 0 THEN 'full'
                    ELSE 'partial'
                END,
                NOW(),
                p_user_id
            ) RETURNING id INTO v_linkage_id;
            
            -- Update PR item status
            UPDATE purchase_request_items
            SET quantity_ordered = quantity,
                status = 'converted_to_po',
                po_id = v_po_id,
                po_number = v_po_number,
                po_item_number = v_items_converted + 1,
                conversion_date = NOW(),
                converted_by = p_user_id,
                is_locked = TRUE,
                locked_at = NOW(),
                locked_by = p_user_id,
                lock_reason = 'Converted to PO ' || v_po_number,
                updated_at = NOW()
            WHERE id = v_item.id;
            
            -- Accumulate totals
            v_total_amount := v_total_amount + ((v_item.quantity - v_item.quantity_ordered) * v_unit_price);
            v_items_converted := v_items_converted + 1;
            
        END LOOP;
        
        -- Update PR status based on items
        PERFORM update_pr_status_from_items(v_pr.id);
        v_prs_processed := v_prs_processed + 1;
        
    END LOOP;
    
    -- Update PO total
    UPDATE purchase_orders
    SET total_amount = v_total_amount,
        updated_at = NOW()
    WHERE id = v_po_id;
    
    -- Return result
    RETURN jsonb_build_object(
        'success', TRUE,
        'po_id', v_po_id,
        'po_number', v_po_number,
        'supplier_id', p_supplier_id,
        'supplier_name', v_supplier_name,
        'total_amount', v_total_amount,
        'items_converted', v_items_converted,
        'prs_processed', v_prs_processed,
        'pricing_mode', p_pricing_mode,
        'converted_at', NOW()
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Return error details
    RETURN jsonb_build_object(
        'success', FALSE,
        'error', SQLERRM,
        'error_detail', SQLSTATE
    );
END;
$$;

-- ============================================================================
-- FUNCTION: convert_single_pr_item_to_po()
-- Description: Convert a single PR item to an existing or new PO
-- ============================================================================

CREATE OR REPLACE FUNCTION convert_single_pr_item_to_po(
    p_pr_item_id UUID,
    p_po_id BIGINT DEFAULT NULL,
    p_supplier_id BIGINT DEFAULT NULL,
    p_quantity NUMERIC DEFAULT NULL,
    p_unit_price NUMERIC DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_pr RECORD;
    v_po_id BIGINT;
    v_po_number TEXT;
    v_convert_qty NUMERIC;
    v_price NUMERIC;
    v_supplier_id BIGINT;
    v_supplier_name TEXT;
BEGIN
    -- Get PR item details
    SELECT * INTO v_item
    FROM purchase_request_items
    WHERE id = p_pr_item_id
    AND deleted = FALSE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'PR item not found';
    END IF;
    
    IF v_item.status NOT IN ('open', 'partially_converted') THEN
        RAISE EXCEPTION 'PR item is not available for conversion. Status: %', v_item.status;
    END IF;
    
    IF (v_item.quantity - v_item.quantity_ordered) <= 0 THEN
        RAISE EXCEPTION 'No remaining quantity to convert';
    END IF;
    
    -- Get PR header
    SELECT * INTO v_pr
    FROM purchase_requests
    WHERE id = v_item.pr_id;
    
    IF v_pr.status NOT IN ('approved', 'partially_ordered') THEN
        RAISE EXCEPTION 'PR is not approved. Status: %', v_pr.status;
    END IF;
    
    -- Determine quantity to convert
    v_convert_qty := LEAST(
        COALESCE(p_quantity, v_item.quantity - v_item.quantity_ordered),
        v_item.quantity - v_item.quantity_ordered
    );
    
    IF v_convert_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid conversion quantity';
    END IF;
    
    -- Determine price
    v_price := COALESCE(p_unit_price, v_item.estimated_price, 0);
    
    -- Determine PO (use existing or create new)
    IF p_po_id IS NOT NULL THEN
        -- Validate existing PO
        SELECT id, po_number, supplier_id INTO v_po_id, v_po_number, v_supplier_id
        FROM purchase_orders
        WHERE id = p_po_id
        AND status IN ('draft', 'pending');
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'PO not found or not editable';
        END IF;
    ELSE
        -- Need supplier for new PO
        v_supplier_id := COALESCE(p_supplier_id, v_item.suggested_supplier_id);
        
        IF v_supplier_id IS NULL THEN
            RAISE EXCEPTION 'Supplier ID required for new PO';
        END IF;
        
        SELECT supplier_name INTO v_supplier_name
        FROM suppliers
        WHERE id = v_supplier_id;
        
        -- Generate new PO
        SELECT 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-' || 
               LPAD((COALESCE(MAX(CAST(SUBSTRING(po_number FROM 9) AS INT)), 0) + 1)::TEXT, 6, '0')
        INTO v_po_number
        FROM purchase_orders
        WHERE po_number LIKE 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-%';
        
        IF v_po_number IS NULL THEN
            v_po_number := 'PO-' || EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-000001';
        END IF;
        
        INSERT INTO purchase_orders (
            po_number, supplier_id, supplier_name, status, total_amount, created_at, updated_at
        ) VALUES (
            v_po_number, v_supplier_id, v_supplier_name, 'draft', 0, NOW(), NOW()
        ) RETURNING id INTO v_po_id;
    END IF;
    
    -- Add item to PO
    INSERT INTO purchase_order_items (
        po_id, item_id, item_name, quantity, unit, unit_price, total_price, created_at
    ) VALUES (
        v_po_id, v_item.item_id, v_item.item_name, v_convert_qty, v_item.unit, v_price, v_convert_qty * v_price, NOW()
    );
    
    -- Create linkage
    INSERT INTO pr_po_linkage (
        pr_id, pr_number, pr_item_id, pr_item_number,
        po_id, po_number,
        pr_quantity, converted_quantity, unit,
        pr_estimated_price, po_actual_price,
        conversion_type, converted_at, converted_by
    ) VALUES (
        v_pr.id, v_pr.pr_number, v_item.id, v_item.item_number,
        v_po_id, v_po_number,
        v_item.quantity, v_convert_qty, v_item.unit,
        v_item.estimated_price, v_price,
        CASE WHEN v_convert_qty = (v_item.quantity - v_item.quantity_ordered) THEN 'full' ELSE 'partial' END,
        NOW(), p_user_id
    );
    
    -- Update PR item
    UPDATE purchase_request_items
    SET quantity_ordered = quantity_ordered + v_convert_qty,
        status = CASE 
            WHEN quantity_ordered + v_convert_qty >= quantity THEN 'converted_to_po'
            ELSE 'partially_converted'
        END,
        po_id = v_po_id,
        po_number = v_po_number,
        conversion_date = NOW(),
        converted_by = p_user_id,
        is_locked = (quantity_ordered + v_convert_qty >= quantity),
        updated_at = NOW()
    WHERE id = p_pr_item_id;
    
    -- Update PO total
    UPDATE purchase_orders
    SET total_amount = (
        SELECT COALESCE(SUM(total_price), 0)
        FROM purchase_order_items
        WHERE po_id = v_po_id
    ),
    updated_at = NOW()
    WHERE id = v_po_id;
    
    -- Update PR status
    PERFORM update_pr_status_from_items(v_pr.id);
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'po_id', v_po_id,
        'po_number', v_po_number,
        'quantity_converted', v_convert_qty,
        'unit_price', v_price,
        'total', v_convert_qty * v_price
    );
END;
$$;

-- ============================================================================
-- FUNCTION: submit_pr_for_approval()
-- Description: Submit a PR and trigger approval workflow
-- ============================================================================

CREATE OR REPLACE FUNCTION submit_pr_for_approval(
    p_pr_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
    v_item_count INT;
BEGIN
    -- Get PR details
    SELECT * INTO v_pr
    FROM purchase_requests
    WHERE id = p_pr_id
    AND deleted = FALSE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Request not found';
    END IF;
    
    IF v_pr.status != 'draft' THEN
        RAISE EXCEPTION 'Only draft PRs can be submitted. Current status: %', v_pr.status;
    END IF;
    
    -- Check for items
    SELECT COUNT(*) INTO v_item_count
    FROM purchase_request_items
    WHERE pr_id = p_pr_id
    AND deleted = FALSE;
    
    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Cannot submit PR without items';
    END IF;
    
    -- Update status
    UPDATE purchase_requests
    SET status = 'submitted',
        notes = COALESCE(p_notes, notes),
        updated_at = NOW(),
        updated_by = auth.uid()
    WHERE id = p_pr_id;
    
    -- Create initial approval workflow entry
    INSERT INTO pr_approval_workflow (
        pr_id,
        approval_level,
        approval_step,
        approver_role,
        approver_department,
        decision,
        threshold_amount
    ) VALUES (
        p_pr_id,
        1,
        'Department Manager Approval',
        'manager',
        v_pr.department,
        'pending',
        v_pr.estimated_total_value
    );
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'pr_id', p_pr_id,
        'pr_number', v_pr.pr_number,
        'status', 'submitted',
        'items', v_item_count,
        'estimated_value', v_pr.estimated_total_value
    );
END;
$$;

-- ============================================================================
-- FUNCTION: approve_pr()
-- Description: Approve a PR
-- ============================================================================

CREATE OR REPLACE FUNCTION approve_pr(
    p_pr_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
BEGIN
    SELECT * INTO v_pr
    FROM purchase_requests
    WHERE id = p_pr_id
    AND deleted = FALSE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Request not found';
    END IF;
    
    IF v_pr.status NOT IN ('submitted', 'under_review') THEN
        RAISE EXCEPTION 'PR cannot be approved. Current status: %', v_pr.status;
    END IF;
    
    -- Update status
    UPDATE purchase_requests
    SET status = 'approved',
        approved_by = auth.uid(),
        approved_at = NOW(),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW(),
        updated_by = auth.uid()
    WHERE id = p_pr_id;
    
    -- Update approval workflow
    UPDATE pr_approval_workflow
    SET decision = 'approved',
        decision_date = NOW(),
        decision_notes = p_notes,
        approver_id = auth.uid(),
        updated_at = NOW()
    WHERE pr_id = p_pr_id
    AND decision = 'pending';
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'pr_id', p_pr_id,
        'pr_number', v_pr.pr_number,
        'status', 'approved',
        'approved_by', auth.uid(),
        'approved_at', NOW()
    );
END;
$$;

-- ============================================================================
-- FUNCTION: reject_pr()
-- Description: Reject a PR with reason
-- ============================================================================

CREATE OR REPLACE FUNCTION reject_pr(
    p_pr_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
BEGIN
    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Rejection reason is required';
    END IF;
    
    SELECT * INTO v_pr
    FROM purchase_requests
    WHERE id = p_pr_id
    AND deleted = FALSE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Request not found';
    END IF;
    
    IF v_pr.status NOT IN ('submitted', 'under_review') THEN
        RAISE EXCEPTION 'PR cannot be rejected. Current status: %', v_pr.status;
    END IF;
    
    -- Update status
    UPDATE purchase_requests
    SET status = 'rejected',
        rejection_reason = p_reason,
        updated_at = NOW(),
        updated_by = auth.uid()
    WHERE id = p_pr_id;
    
    -- Update approval workflow
    UPDATE pr_approval_workflow
    SET decision = 'rejected',
        decision_date = NOW(),
        decision_notes = p_reason,
        approver_id = auth.uid(),
        updated_at = NOW()
    WHERE pr_id = p_pr_id
    AND decision = 'pending';
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'pr_id', p_pr_id,
        'pr_number', v_pr.pr_number,
        'status', 'rejected',
        'reason', p_reason
    );
END;
$$;

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION convert_pr_to_po(UUID[], BIGINT, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION convert_single_pr_item_to_po(UUID, BIGINT, BIGINT, NUMERIC, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_pr_for_approval(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_pr(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_pr(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_pr_status_from_items(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_valid_pr_status_transition(TEXT, TEXT) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION convert_pr_to_po(UUID[], BIGINT, TEXT, UUID, TEXT) IS 
    'Convert one or more PRs to a Purchase Order. Supports aggregation and multiple pricing modes';
COMMENT ON FUNCTION convert_single_pr_item_to_po(UUID, BIGINT, BIGINT, NUMERIC, NUMERIC, UUID) IS 
    'Convert a single PR item to an existing or new PO with optional partial quantity';
COMMENT ON FUNCTION submit_pr_for_approval(UUID, TEXT) IS 
    'Submit a draft PR for approval workflow';
COMMENT ON FUNCTION approve_pr(UUID, TEXT) IS 
    'Approve a PR that is pending approval';
COMMENT ON FUNCTION reject_pr(UUID, TEXT) IS 
    'Reject a PR with mandatory reason';

-- ============================================================================
-- END OF PR_TO_PO_TRIGGER.sql
-- ============================================================================
