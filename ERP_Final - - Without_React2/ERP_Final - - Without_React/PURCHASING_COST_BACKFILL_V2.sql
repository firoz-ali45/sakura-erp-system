-- ============================================================
-- PURCHASING COST BACKFILL SCRIPT V2
-- Fixes Cost Flow: PO → GRN → Purchasing (SAP Logic)
-- ============================================================
-- 
-- RUN EACH SECTION SEPARATELY IN SUPABASE SQL EDITOR
-- Click Run after each section to verify results
-- ============================================================

-- ============================================================
-- SECTION 1: DIAGNOSTIC - Check Current State
-- ============================================================

-- 1A: Check purchasing invoices
SELECT 
    id,
    invoice_number,
    purchase_order_id,
    purchase_order_number,
    supplier_id,
    supplier_name,
    subtotal,
    grand_total,
    status
FROM purchasing_invoices
ORDER BY created_at DESC
LIMIT 10;

-- 1B: Check purchasing invoice items with costs
SELECT 
    pii.id,
    pii.item_name,
    pii.quantity,
    pii.unit_cost,
    pii.total_cost,
    pi.invoice_number,
    pi.purchase_order_id,
    pi.purchase_order_number
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
ORDER BY pi.created_at DESC
LIMIT 20;

-- 1C: Check PO item prices (the source of truth)
SELECT 
    poi.purchase_order_id,
    poi.po_number,
    poi.item_id,
    poi.item_name,
    poi.unit_price,
    poi.quantity
FROM purchase_order_items poi
WHERE poi.unit_price > 0
ORDER BY poi.purchase_order_id DESC
LIMIT 20;


-- ============================================================
-- SECTION 2: FIX SUPPLIER NAME (JSON to String)
-- ============================================================

-- 2A: Check supplier_name issues
SELECT id, supplier_name, supplier_id 
FROM purchasing_invoices 
WHERE supplier_name LIKE '{%' 
   OR supplier_name LIKE '%"name"%'
LIMIT 10;

-- 2B: Fix supplier_name from suppliers table
UPDATE purchasing_invoices
SET supplier_name = s.name
FROM suppliers s
WHERE purchasing_invoices.supplier_id = s.id
AND (
    purchasing_invoices.supplier_name LIKE '{%' 
    OR purchasing_invoices.supplier_name LIKE '%"name"%'
    OR purchasing_invoices.supplier_name IS NULL 
    OR purchasing_invoices.supplier_name = 'N/A'
    OR purchasing_invoices.supplier_name = ''
);


-- ============================================================
-- SECTION 3: BACKFILL UNIT_COST - Method 1 (BY purchase_order_id)
-- ============================================================

-- 3A: Preview what will be updated
SELECT 
    pii.id AS item_id,
    pii.item_name,
    pii.quantity,
    pii.unit_cost AS current_cost,
    poi.unit_price AS po_price,
    pi.purchase_order_id
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
JOIN purchase_order_items poi ON poi.purchase_order_id = pi.purchase_order_id AND poi.item_id = pii.item_id
WHERE (pii.unit_cost IS NULL OR pii.unit_cost = 0)
AND poi.unit_price > 0;

-- 3B: Execute the update (by purchase_order_id)
UPDATE purchasing_invoice_items
SET 
    unit_cost = poi.unit_price,
    total_cost = purchasing_invoice_items.quantity * poi.unit_price
FROM purchasing_invoices pi, purchase_order_items poi
WHERE purchasing_invoice_items.purchasing_invoice_id = pi.id
AND poi.purchase_order_id = pi.purchase_order_id 
AND poi.item_id = purchasing_invoice_items.item_id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND poi.unit_price > 0;


-- ============================================================
-- SECTION 4: BACKFILL UNIT_COST - Method 2 (BY po_number fallback)
-- ============================================================

-- 4A: Preview what will be updated by po_number
SELECT 
    pii.id AS item_id,
    pii.item_name,
    pii.quantity,
    pii.unit_cost AS current_cost,
    poi.unit_price AS po_price,
    pi.purchase_order_number
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
JOIN purchase_order_items poi ON poi.po_number = pi.purchase_order_number AND poi.item_id = pii.item_id
WHERE (pii.unit_cost IS NULL OR pii.unit_cost = 0)
AND poi.unit_price > 0;

-- 4B: Execute the update (by po_number)
UPDATE purchasing_invoice_items
SET 
    unit_cost = poi.unit_price,
    total_cost = purchasing_invoice_items.quantity * poi.unit_price
FROM purchasing_invoices pi, purchase_order_items poi
WHERE purchasing_invoice_items.purchasing_invoice_id = pi.id
AND poi.po_number = pi.purchase_order_number 
AND poi.item_id = purchasing_invoice_items.item_id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND poi.unit_price > 0;


-- ============================================================
-- SECTION 5: BACKFILL FROM INVENTORY_ITEMS (Final Fallback)
-- ============================================================

-- 5A: Preview what will be updated from inventory
SELECT 
    pii.id AS item_id,
    pii.item_name,
    pii.quantity,
    pii.unit_cost AS current_cost,
    inv.cost AS inventory_cost
FROM purchasing_invoice_items pii
JOIN inventory_items inv ON inv.id = pii.item_id
WHERE (pii.unit_cost IS NULL OR pii.unit_cost = 0)
AND inv.cost > 0;

-- 5B: Execute the update from inventory
UPDATE purchasing_invoice_items
SET 
    unit_cost = inv.cost,
    total_cost = purchasing_invoice_items.quantity * inv.cost
FROM inventory_items inv
WHERE purchasing_invoice_items.item_id = inv.id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND inv.cost > 0;


-- ============================================================
-- SECTION 6: RECALCULATE INVOICE TOTALS
-- ============================================================

-- 6A: Preview invoice totals
SELECT 
    pi.id,
    pi.invoice_number,
    pi.subtotal AS current_subtotal,
    pi.grand_total AS current_grand_total,
    COALESCE(items.total, 0) AS calculated_subtotal
FROM purchasing_invoices pi
LEFT JOIN (
    SELECT purchasing_invoice_id, SUM(total_cost) AS total
    FROM purchasing_invoice_items
    GROUP BY purchasing_invoice_id
) items ON items.purchasing_invoice_id = pi.id;

-- 6B: Execute the recalculation
UPDATE purchasing_invoices
SET 
    subtotal = COALESCE(item_totals.total, 0),
    total_amount = COALESCE(item_totals.total, 0),
    tax_amount = COALESCE(item_totals.total, 0) * COALESCE(purchasing_invoices.tax_rate, 15) / 100,
    grand_total = COALESCE(item_totals.total, 0) * (1 + COALESCE(purchasing_invoices.tax_rate, 15) / 100),
    updated_at = now()
FROM (
    SELECT 
        purchasing_invoice_id,
        SUM(total_cost) AS total
    FROM purchasing_invoice_items
    GROUP BY purchasing_invoice_id
) item_totals
WHERE purchasing_invoices.id = item_totals.purchasing_invoice_id;


-- ============================================================
-- SECTION 7: FIX INVENTORY_STOCK_LEDGER COSTS
-- ============================================================

-- 7A: Preview stock ledger updates
SELECT 
    isl.id,
    isl.item_name,
    isl.qty_in,
    isl.unit_cost AS current_cost,
    poi.unit_price AS po_price,
    gi.grn_number
FROM inventory_stock_ledger isl
JOIN grn_inspections gi ON gi.id = isl.reference_id
JOIN purchase_order_items poi ON poi.purchase_order_id = gi.purchase_order_id AND poi.item_id = isl.item_id
WHERE isl.reference_type = 'GRN'
AND (isl.unit_cost IS NULL OR isl.unit_cost = 0)
AND poi.unit_price > 0
LIMIT 20;

-- 7B: Execute stock ledger update
UPDATE inventory_stock_ledger
SET 
    unit_cost = poi.unit_price,
    total_cost = inventory_stock_ledger.qty_in * poi.unit_price
FROM grn_inspections gi, purchase_order_items poi
WHERE inventory_stock_ledger.reference_type = 'GRN'
AND inventory_stock_ledger.reference_id = gi.id
AND poi.purchase_order_id = gi.purchase_order_id
AND poi.item_id = inventory_stock_ledger.item_id
AND (inventory_stock_ledger.unit_cost IS NULL OR inventory_stock_ledger.unit_cost = 0)
AND poi.unit_price > 0;


-- ============================================================
-- SECTION 8: VERIFICATION QUERIES
-- ============================================================

-- 8A: Verify purchasing invoice items have costs
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

-- 8B: Verify purchasing invoices have totals
SELECT 
    invoice_number,
    supplier_name,
    subtotal,
    tax_amount,
    grand_total,
    status,
    payment_status
FROM purchasing_invoices
ORDER BY created_at DESC
LIMIT 10;

-- 8C: Check for remaining zero-cost items
SELECT COUNT(*) AS zero_cost_items
FROM purchasing_invoice_items
WHERE unit_cost IS NULL OR unit_cost = 0;


-- ============================================================
-- SECTION 9: CREATE TRIGGERS FOR FUTURE DATA
-- ============================================================

-- 9A: Drop existing triggers
DROP TRIGGER IF EXISTS trg_purchasing_item_cost ON purchasing_invoice_items;
DROP TRIGGER IF EXISTS trg_purchasing_recalc_totals ON purchasing_invoice_items;

-- 9B: Trigger to auto-set cost on item insert
CREATE OR REPLACE FUNCTION fn_set_purchasing_item_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_po_id BIGINT;
    v_unit_cost NUMERIC;
BEGIN
    -- Skip if cost already set
    IF NEW.unit_cost IS NOT NULL AND NEW.unit_cost > 0 THEN
        RETURN NEW;
    END IF;
    
    -- Get PO ID from invoice
    SELECT purchase_order_id INTO v_po_id
    FROM purchasing_invoices
    WHERE id = NEW.purchasing_invoice_id;
    
    -- Try to get cost from PO items by purchase_order_id
    IF v_po_id IS NOT NULL THEN
        SELECT unit_price INTO v_unit_cost
        FROM purchase_order_items
        WHERE purchase_order_id = v_po_id
        AND item_id = NEW.item_id
        AND unit_price > 0
        LIMIT 1;
    END IF;
    
    -- Fallback to inventory cost
    IF v_unit_cost IS NULL OR v_unit_cost = 0 THEN
        SELECT cost INTO v_unit_cost
        FROM inventory_items
        WHERE id = NEW.item_id
        AND cost > 0;
    END IF;
    
    -- Set the cost
    NEW.unit_cost := COALESCE(v_unit_cost, 0);
    NEW.total_cost := NEW.quantity * NEW.unit_cost;
    
    RAISE NOTICE 'Auto-set cost for item %: unit_cost=%, total_cost=%', 
        NEW.item_id, NEW.unit_cost, NEW.total_cost;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_item_cost
    BEFORE INSERT OR UPDATE ON purchasing_invoice_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_purchasing_item_cost();

-- 9C: Trigger to auto-recalculate invoice totals
CREATE OR REPLACE FUNCTION fn_recalc_purchasing_totals()
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
    
    RAISE NOTICE 'Recalculated invoice %: subtotal=%, grand_total=%', 
        v_invoice_id, v_subtotal, v_subtotal * (1 + v_tax_rate / 100);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_recalc_totals
    AFTER INSERT OR UPDATE OR DELETE ON purchasing_invoice_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_recalc_purchasing_totals();


-- ============================================================
-- COMPLETION MESSAGE
-- ============================================================

SELECT '✅ COST BACKFILL COMPLETE' AS status,
       (SELECT COUNT(*) FROM purchasing_invoices) AS total_invoices,
       (SELECT COUNT(*) FROM purchasing_invoice_items WHERE unit_cost > 0) AS items_with_cost,
       (SELECT COUNT(*) FROM purchasing_invoice_items WHERE unit_cost = 0 OR unit_cost IS NULL) AS items_zero_cost;
