-- ============================================================
-- PURCHASING DATA FIX SCRIPT
-- Fixes Cost Flow & Supplier Name Issues
-- ============================================================
-- 
-- ISSUES FIXED:
-- 1. supplier_name stored as JSON object → Extract name string
-- 2. unit_cost = 0 in purchasing_invoice_items → Backfill from PO
-- 3. Recalculate totals on purchasing_invoices
-- 
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================

-- ============================================================
-- PART 1: FIX SUPPLIER_NAME JSON ISSUE
-- ============================================================

-- First, let's see what's in supplier_name
SELECT id, supplier_name, supplier_id FROM purchasing_invoices LIMIT 5;

-- Fix supplier_name where it contains JSON (starts with '{')
-- PostgreSQL correct syntax without alias on target table
UPDATE purchasing_invoices
SET supplier_name = s.name
FROM suppliers s
WHERE purchasing_invoices.supplier_id = s.id
AND (
    purchasing_invoices.supplier_name LIKE '{%' 
    OR purchasing_invoices.supplier_name IS NULL 
    OR purchasing_invoices.supplier_name = 'N/A'
    OR purchasing_invoices.supplier_name = ''
);

-- Also fix any remaining JSON-like strings
UPDATE purchasing_invoices
SET supplier_name = TRIM(BOTH '"' FROM 
    CASE 
        WHEN supplier_name LIKE '%"name":"%' 
        THEN SUBSTRING(supplier_name FROM '"name":"([^"]+)"')
        ELSE supplier_name
    END
)
WHERE supplier_name LIKE '{%' OR supplier_name LIKE '%"name"%';

-- ============================================================
-- PART 2: BACKFILL UNIT_COST FROM PURCHASE_ORDER_ITEMS
-- ============================================================

-- View current state (diagnostic query)
SELECT 
    pii.id,
    pii.item_name,
    pii.quantity,
    pii.unit_cost AS current_unit_cost,
    poi.unit_price AS po_unit_price,
    inv.cost AS inventory_cost
FROM purchasing_invoice_items pii
LEFT JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
LEFT JOIN purchase_order_items poi ON poi.item_id = pii.item_id 
    AND poi.po_number = pi.purchase_order_number
LEFT JOIN inventory_items inv ON inv.id = pii.item_id
WHERE pii.unit_cost = 0 OR pii.unit_cost IS NULL
LIMIT 20;

-- Update unit_cost from PO items (primary source)
-- PostgreSQL correct syntax: FROM clause references separate tables
UPDATE purchasing_invoice_items
SET 
    unit_cost = poi.unit_price,
    total_cost = purchasing_invoice_items.quantity * poi.unit_price
FROM purchasing_invoices pi, purchase_order_items poi
WHERE purchasing_invoice_items.purchasing_invoice_id = pi.id
AND poi.item_id = purchasing_invoice_items.item_id 
AND poi.po_number = pi.purchase_order_number
AND (purchasing_invoice_items.unit_cost = 0 OR purchasing_invoice_items.unit_cost IS NULL)
AND poi.unit_price > 0;

-- Fallback: Update from inventory_items cost (if PO price not found)
UPDATE purchasing_invoice_items
SET 
    unit_cost = inv.cost,
    total_cost = purchasing_invoice_items.quantity * inv.cost
FROM inventory_items inv
WHERE purchasing_invoice_items.item_id = inv.id
AND (purchasing_invoice_items.unit_cost = 0 OR purchasing_invoice_items.unit_cost IS NULL)
AND inv.cost > 0;

-- ============================================================
-- PART 3: RECALCULATE PURCHASING INVOICE TOTALS
-- ============================================================

-- Recalculate subtotal, tax_amount, grand_total
-- PostgreSQL correct syntax without alias on target table
UPDATE purchasing_invoices
SET 
    subtotal = totals.item_total,
    total_amount = totals.item_total,
    tax_amount = totals.item_total * COALESCE(purchasing_invoices.tax_rate, 15) / 100,
    grand_total = totals.item_total * (1 + COALESCE(purchasing_invoices.tax_rate, 15) / 100)
FROM (
    SELECT 
        purchasing_invoice_id,
        COALESCE(SUM(total_cost), 0) AS item_total
    FROM purchasing_invoice_items
    GROUP BY purchasing_invoice_id
) totals
WHERE purchasing_invoices.id = totals.purchasing_invoice_id;

-- ============================================================
-- PART 4: FIX INVENTORY_STOCK_LEDGER UNIT_COST
-- ============================================================

-- Update stock ledger entries with zero cost
-- PostgreSQL correct syntax
UPDATE inventory_stock_ledger
SET 
    unit_cost = poi.unit_price,
    total_cost = inventory_stock_ledger.qty_in * poi.unit_price
FROM grn_inspections gi, purchase_order_items poi
WHERE inventory_stock_ledger.reference_type = 'GRN'
AND inventory_stock_ledger.reference_id = gi.id
AND poi.item_id = inventory_stock_ledger.item_id
AND poi.po_number = gi.purchase_order_number
AND (inventory_stock_ledger.unit_cost = 0 OR inventory_stock_ledger.unit_cost IS NULL)
AND poi.unit_price > 0;

-- ============================================================
-- PART 5: ENHANCED TRIGGER FOR COST FLOW
-- ============================================================

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trg_purchasing_item_cost ON purchasing_invoice_items;

-- Create trigger to auto-populate cost on insert
CREATE OR REPLACE FUNCTION trg_set_purchasing_item_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_po_number TEXT;
    v_unit_cost NUMERIC;
BEGIN
    -- Skip if cost already set
    IF NEW.unit_cost > 0 THEN
        RETURN NEW;
    END IF;
    
    -- Get PO number from invoice
    SELECT purchase_order_number INTO v_po_number
    FROM purchasing_invoices
    WHERE id = NEW.purchasing_invoice_id;
    
    -- Try to get cost from PO items
    IF v_po_number IS NOT NULL THEN
        SELECT unit_price INTO v_unit_cost
        FROM purchase_order_items
        WHERE po_number = v_po_number
        AND item_id = NEW.item_id
        LIMIT 1;
    END IF;
    
    -- Fallback to inventory cost
    IF v_unit_cost IS NULL OR v_unit_cost = 0 THEN
        SELECT cost INTO v_unit_cost
        FROM inventory_items
        WHERE id = NEW.item_id;
    END IF;
    
    -- Set the cost
    NEW.unit_cost := COALESCE(v_unit_cost, 0);
    NEW.total_cost := NEW.quantity * NEW.unit_cost;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_item_cost
    BEFORE INSERT ON purchasing_invoice_items
    FOR EACH ROW
    EXECUTE FUNCTION trg_set_purchasing_item_cost();

-- ============================================================
-- PART 6: TRIGGER TO AUTO-RECALCULATE INVOICE TOTALS
-- ============================================================

DROP TRIGGER IF EXISTS trg_purchasing_recalc_totals ON purchasing_invoice_items;

CREATE OR REPLACE FUNCTION trg_recalc_purchasing_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id UUID;
    v_subtotal NUMERIC;
    v_tax_rate NUMERIC;
BEGIN
    -- Get the invoice ID
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.purchasing_invoice_id;
    ELSE
        v_invoice_id := NEW.purchasing_invoice_id;
    END IF;
    
    -- Calculate subtotal
    SELECT COALESCE(SUM(total_cost), 0) INTO v_subtotal
    FROM purchasing_invoice_items
    WHERE purchasing_invoice_id = v_invoice_id;
    
    -- Get tax rate
    SELECT COALESCE(tax_rate, 15) INTO v_tax_rate
    FROM purchasing_invoices
    WHERE id = v_invoice_id;
    
    -- Update invoice totals
    UPDATE purchasing_invoices
    SET 
        subtotal = v_subtotal,
        total_amount = v_subtotal,
        tax_amount = v_subtotal * v_tax_rate / 100,
        grand_total = v_subtotal * (1 + v_tax_rate / 100),
        updated_at = now()
    WHERE id = v_invoice_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_recalc_totals
    AFTER INSERT OR UPDATE OR DELETE ON purchasing_invoice_items
    FOR EACH ROW
    EXECUTE FUNCTION trg_recalc_purchasing_totals();

-- ============================================================
-- PART 7: VERIFICATION QUERIES
-- ============================================================

-- Check purchasing invoices after fix
SELECT 
    id,
    invoice_number,
    supplier_name,
    subtotal,
    tax_amount,
    grand_total,
    status
FROM purchasing_invoices
ORDER BY created_at DESC
LIMIT 10;

-- Check purchasing invoice items after fix
SELECT 
    pii.item_name,
    pii.quantity,
    pii.unit_cost,
    pii.total_cost,
    pi.invoice_number
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
ORDER BY pi.created_at DESC
LIMIT 10;

-- ============================================================
-- COMPLETION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ PURCHASING DATA FIX COMPLETE';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'FIXES APPLIED:';
    RAISE NOTICE '1. supplier_name JSON → string extracted';
    RAISE NOTICE '2. unit_cost backfilled from PO items';
    RAISE NOTICE '3. Invoice totals recalculated';
    RAISE NOTICE '4. Stock ledger costs updated';
    RAISE NOTICE '5. Auto-cost trigger created for new items';
    RAISE NOTICE '6. Auto-recalc trigger created for totals';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT: Refresh the Purchasing Detail page to see fixed data.';
    RAISE NOTICE '';
END $$;
