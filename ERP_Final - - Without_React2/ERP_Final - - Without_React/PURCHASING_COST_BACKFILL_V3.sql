-- PURCHASING COST BACKFILL SCRIPT V3
-- Run each section separately in Supabase SQL Editor

-- SECTION 1: DIAGNOSTIC - Check Current State
SELECT id, invoice_number, purchase_order_id, purchase_order_number, supplier_id, supplier_name, subtotal, grand_total, status
FROM purchasing_invoices ORDER BY created_at DESC LIMIT 10;

-- SECTION 1B: Check purchasing invoice items with costs
SELECT pii.id, pii.item_name, pii.quantity, pii.unit_cost, pii.total_cost, pi.invoice_number, pi.purchase_order_id
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
ORDER BY pi.created_at DESC LIMIT 20;

-- SECTION 1C: Check PO item prices (source of truth)
SELECT poi.purchase_order_id, poi.po_number, poi.item_id, poi.item_name, poi.unit_price, poi.quantity
FROM purchase_order_items poi WHERE poi.unit_price > 0 ORDER BY poi.purchase_order_id DESC LIMIT 20;

-- SECTION 2: FIX SUPPLIER NAME (JSON to String)
-- 2A: Check supplier_name issues
SELECT id, supplier_name, supplier_id FROM purchasing_invoices WHERE supplier_name LIKE '{%' OR supplier_name LIKE '%"name"%' LIMIT 10;

-- 2B: Fix supplier_name from suppliers table
UPDATE purchasing_invoices
SET supplier_name = s.name
FROM suppliers s
WHERE purchasing_invoices.supplier_id = s.id
AND (purchasing_invoices.supplier_name LIKE '{%' OR purchasing_invoices.supplier_name LIKE '%"name"%' OR purchasing_invoices.supplier_name IS NULL OR purchasing_invoices.supplier_name = 'N/A' OR purchasing_invoices.supplier_name = '');

-- SECTION 3: BACKFILL UNIT_COST - Method 1 (BY purchase_order_id)
-- 3A: Preview what will be updated
SELECT pii.id AS item_id, pii.item_name, pii.quantity, pii.unit_cost AS current_cost, poi.unit_price AS po_price, pi.purchase_order_id
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
JOIN purchase_order_items poi ON poi.purchase_order_id = pi.purchase_order_id AND poi.item_id = pii.item_id
WHERE (pii.unit_cost IS NULL OR pii.unit_cost = 0) AND poi.unit_price > 0;

-- 3B: Execute the update (by purchase_order_id)
UPDATE purchasing_invoice_items
SET unit_cost = poi.unit_price, total_cost = purchasing_invoice_items.quantity * poi.unit_price
FROM purchasing_invoices pi, purchase_order_items poi
WHERE purchasing_invoice_items.purchasing_invoice_id = pi.id
AND poi.purchase_order_id = pi.purchase_order_id 
AND poi.item_id = purchasing_invoice_items.item_id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND poi.unit_price > 0;

-- SECTION 4: BACKFILL UNIT_COST - Method 2 (BY po_number fallback)
UPDATE purchasing_invoice_items
SET unit_cost = poi.unit_price, total_cost = purchasing_invoice_items.quantity * poi.unit_price
FROM purchasing_invoices pi, purchase_order_items poi
WHERE purchasing_invoice_items.purchasing_invoice_id = pi.id
AND poi.po_number = pi.purchase_order_number 
AND poi.item_id = purchasing_invoice_items.item_id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND poi.unit_price > 0;

-- SECTION 5: BACKFILL FROM INVENTORY_ITEMS (Final Fallback)
UPDATE purchasing_invoice_items
SET unit_cost = inv.cost, total_cost = purchasing_invoice_items.quantity * inv.cost
FROM inventory_items inv
WHERE purchasing_invoice_items.item_id = inv.id
AND (purchasing_invoice_items.unit_cost IS NULL OR purchasing_invoice_items.unit_cost = 0)
AND inv.cost > 0;

-- SECTION 6: RECALCULATE INVOICE TOTALS
UPDATE purchasing_invoices
SET subtotal = COALESCE(item_totals.total, 0),
    total_amount = COALESCE(item_totals.total, 0),
    tax_amount = COALESCE(item_totals.total, 0) * COALESCE(purchasing_invoices.tax_rate, 15) / 100,
    grand_total = COALESCE(item_totals.total, 0) * (1 + COALESCE(purchasing_invoices.tax_rate, 15) / 100),
    updated_at = now()
FROM (SELECT purchasing_invoice_id, SUM(total_cost) AS total FROM purchasing_invoice_items GROUP BY purchasing_invoice_id) item_totals
WHERE purchasing_invoices.id = item_totals.purchasing_invoice_id;

-- SECTION 7: FIX INVENTORY_STOCK_LEDGER COSTS
UPDATE inventory_stock_ledger
SET unit_cost = poi.unit_price, total_cost = inventory_stock_ledger.qty_in * poi.unit_price
FROM grn_inspections gi, purchase_order_items poi
WHERE inventory_stock_ledger.reference_type = 'GRN'
AND inventory_stock_ledger.reference_id = gi.id
AND poi.purchase_order_id = gi.purchase_order_id
AND poi.item_id = inventory_stock_ledger.item_id
AND (inventory_stock_ledger.unit_cost IS NULL OR inventory_stock_ledger.unit_cost = 0)
AND poi.unit_price > 0;

-- SECTION 8: VERIFICATION
SELECT pii.item_name, pii.quantity, pii.unit_cost, pii.total_cost, pi.invoice_number
FROM purchasing_invoice_items pii
JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
ORDER BY pi.created_at DESC LIMIT 10;

SELECT invoice_number, supplier_name, subtotal, tax_amount, grand_total, status, payment_status
FROM purchasing_invoices ORDER BY created_at DESC LIMIT 10;

SELECT COUNT(*) AS zero_cost_items FROM purchasing_invoice_items WHERE unit_cost IS NULL OR unit_cost = 0;

-- SECTION 9: CREATE TRIGGERS FOR FUTURE DATA
DROP TRIGGER IF EXISTS trg_purchasing_item_cost ON purchasing_invoice_items;
DROP TRIGGER IF EXISTS trg_purchasing_recalc_totals ON purchasing_invoice_items;

CREATE OR REPLACE FUNCTION fn_set_purchasing_item_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_po_id BIGINT;
    v_unit_cost NUMERIC;
BEGIN
    IF NEW.unit_cost IS NOT NULL AND NEW.unit_cost > 0 THEN RETURN NEW; END IF;
    SELECT purchase_order_id INTO v_po_id FROM purchasing_invoices WHERE id = NEW.purchasing_invoice_id;
    IF v_po_id IS NOT NULL THEN
        SELECT unit_price INTO v_unit_cost FROM purchase_order_items WHERE purchase_order_id = v_po_id AND item_id = NEW.item_id AND unit_price > 0 LIMIT 1;
    END IF;
    IF v_unit_cost IS NULL OR v_unit_cost = 0 THEN
        SELECT cost INTO v_unit_cost FROM inventory_items WHERE id = NEW.item_id AND cost > 0;
    END IF;
    NEW.unit_cost := COALESCE(v_unit_cost, 0);
    NEW.total_cost := NEW.quantity * NEW.unit_cost;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_item_cost
    BEFORE INSERT OR UPDATE ON purchasing_invoice_items
    FOR EACH ROW EXECUTE FUNCTION fn_set_purchasing_item_cost();

CREATE OR REPLACE FUNCTION fn_recalc_purchasing_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_id UUID;
    v_subtotal NUMERIC;
    v_tax_rate NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN v_invoice_id := OLD.purchasing_invoice_id; ELSE v_invoice_id := NEW.purchasing_invoice_id; END IF;
    SELECT COALESCE(SUM(total_cost), 0) INTO v_subtotal FROM purchasing_invoice_items WHERE purchasing_invoice_id = v_invoice_id;
    SELECT COALESCE(tax_rate, 15) INTO v_tax_rate FROM purchasing_invoices WHERE id = v_invoice_id;
    UPDATE purchasing_invoices SET subtotal = v_subtotal, total_amount = v_subtotal, tax_amount = v_subtotal * v_tax_rate / 100, grand_total = v_subtotal * (1 + v_tax_rate / 100), updated_at = now() WHERE id = v_invoice_id;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchasing_recalc_totals
    AFTER INSERT OR UPDATE OR DELETE ON purchasing_invoice_items
    FOR EACH ROW EXECUTE FUNCTION fn_recalc_purchasing_totals();

-- COMPLETION
SELECT 'COST BACKFILL COMPLETE' AS status,
       (SELECT COUNT(*) FROM purchasing_invoices) AS total_invoices,
       (SELECT COUNT(*) FROM purchasing_invoice_items WHERE unit_cost > 0) AS items_with_cost,
       (SELECT COUNT(*) FROM purchasing_invoice_items WHERE unit_cost = 0 OR unit_cost IS NULL) AS items_zero_cost;
