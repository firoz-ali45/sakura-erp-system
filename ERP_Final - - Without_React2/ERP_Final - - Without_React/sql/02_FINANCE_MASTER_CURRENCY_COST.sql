-- ============================================================================
-- FINANCE MASTER DATA + CURRENCY NORMALIZATION + COST FLOW (PARTS 3, 6, 7)
-- Database = source of truth. System currency = SAR only.
-- ============================================================================

-- ============================================================================
-- PART 3: PAYMENT MASTER DATA
-- ============================================================================

-- A) ATM MASTER
CREATE TABLE IF NOT EXISTS finance_atms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  atm_name text NOT NULL,
  atm_number text,
  bank_name text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finance_atms_active ON finance_atms(is_active) WHERE is_active = true;

-- B) BANK MASTER
CREATE TABLE IF NOT EXISTS finance_banks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name text NOT NULL,
  account_number text,
  iban text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finance_banks_active ON finance_banks(is_active) WHERE is_active = true;

-- ============================================================================
-- PURCHASING_INVOICES: ATM + ONLINE GATEWAY REFERENCE
-- ============================================================================
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS atm_id uuid REFERENCES finance_atms(id) ON DELETE SET NULL;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS payment_reference text;
CREATE INDEX IF NOT EXISTS idx_purchasing_invoices_atm ON purchasing_invoices(atm_id);

-- ============================================================================
-- AP_PAYMENTS: BANK + ATM FOR MANUAL / AUTO
-- ============================================================================
ALTER TABLE ap_payments ADD COLUMN IF NOT EXISTS bank_id uuid REFERENCES finance_banks(id) ON DELETE SET NULL;
ALTER TABLE ap_payments ADD COLUMN IF NOT EXISTS atm_id uuid REFERENCES finance_atms(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_ap_payments_bank ON ap_payments(bank_id);
CREATE INDEX IF NOT EXISTS idx_ap_payments_atm ON ap_payments(atm_id);

-- ============================================================================
-- PART 6: CURRENCY NORMALIZATION — SAR ONLY
-- ============================================================================
-- Ensure purchase_orders has currency and force SAR
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS currency text DEFAULT 'SAR';
UPDATE purchase_orders SET currency = 'SAR' WHERE currency IS NULL OR currency != 'SAR';

-- Purchasing already has currency DEFAULT 'SAR' in schema; enforce
UPDATE purchasing_invoices SET currency = 'SAR' WHERE currency IS NULL OR currency != 'SAR';

-- If PR table exists with currency
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'purchase_requests') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_requests' AND column_name = 'currency') THEN
      UPDATE purchase_requests SET currency = 'SAR' WHERE currency IS NULL OR currency != 'SAR';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'purchase_order_items' AND column_name = 'currency') THEN
    UPDATE purchase_order_items SET currency = 'SAR' WHERE currency IS NULL OR currency != 'SAR';
  END IF;
END $$;

-- ============================================================================
-- PART 7: PUR ITEM COST — DEFAULT FROM PO, REMAIN EDITABLE
-- Trigger: on INSERT of purchasing_invoice_items, default unit_cost from PO if 0
-- (Updates to unit_cost/total_cost are persisted by app; recalc header via trigger)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_purchasing_invoice_item_default_cost()
RETURNS TRIGGER AS $$
DECLARE
  v_po_id bigint;
  v_unit_price numeric(15,4);
BEGIN
  IF (NEW.unit_cost IS NULL OR NEW.unit_cost = 0) AND NEW.purchasing_invoice_id IS NOT NULL THEN
    SELECT pi.purchase_order_id INTO v_po_id
    FROM purchasing_invoices pi
    WHERE pi.id = NEW.purchasing_invoice_id
    LIMIT 1;
    IF v_po_id IS NOT NULL AND NEW.item_id IS NOT NULL THEN
      SELECT poi.unit_price INTO v_unit_price
      FROM purchase_order_items poi
      WHERE poi.purchase_order_id = v_po_id AND poi.item_id = NEW.item_id AND COALESCE(poi.unit_price, 0) > 0
      LIMIT 1;
      IF v_unit_price IS NOT NULL AND v_unit_price > 0 THEN
        NEW.unit_cost := v_unit_price;
        NEW.total_cost := COALESCE(NEW.quantity, 0) * v_unit_price;
      END IF;
    END IF;
  END IF;
  IF NEW.unit_cost IS NOT NULL AND NEW.quantity IS NOT NULL THEN
    NEW.total_cost := NEW.quantity * NEW.unit_cost;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_purchasing_invoice_item_default_cost ON purchasing_invoice_items;
CREATE TRIGGER trg_purchasing_invoice_item_default_cost
  BEFORE INSERT OR UPDATE ON purchasing_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_purchasing_invoice_item_default_cost();

-- Recalculate purchasing_invoices header from items (on item change)
CREATE OR REPLACE FUNCTION fn_purchasing_invoice_recalc_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_invoice_id uuid;
  v_subtotal numeric(15,2);
  v_tax_rate numeric(5,2);
  v_tax_amount numeric(15,2);
  v_grand_total numeric(15,2);
BEGIN
  v_invoice_id := COALESCE(NEW.purchasing_invoice_id, OLD.purchasing_invoice_id);
  IF v_invoice_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  SELECT COALESCE(SUM(total_cost), 0), COALESCE(MAX(pi.tax_rate), 15)
  INTO v_subtotal, v_tax_rate
  FROM purchasing_invoice_items pii
  JOIN purchasing_invoices pi ON pi.id = pii.purchasing_invoice_id
  WHERE pii.purchasing_invoice_id = v_invoice_id;

  v_tax_amount := v_subtotal * v_tax_rate / 100;
  v_grand_total := v_subtotal + v_tax_amount;

  UPDATE purchasing_invoices
  SET subtotal = v_subtotal, tax_amount = v_tax_amount, grand_total = v_grand_total,
      total_amount = v_subtotal, updated_at = now()
  WHERE id = v_invoice_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_purchasing_invoice_recalc_totals ON purchasing_invoice_items;
CREATE TRIGGER trg_purchasing_invoice_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON purchasing_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_purchasing_invoice_recalc_totals();

-- ============================================================================
-- PART 8: VALIDATION — PREVENT PAYMENT > OUTSTANDING (DB SIDE)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_ap_payment_validate_amount()
RETURNS TRIGGER AS $$
DECLARE
  v_grand_total numeric(15,2);
  v_paid numeric(15,2);
  v_outstanding numeric(15,2);
BEGIN
  SELECT grand_total INTO v_grand_total FROM purchasing_invoices WHERE id = NEW.purchasing_invoice_id;
  SELECT COALESCE(SUM(payment_amount), 0) INTO v_paid
  FROM ap_payments
  WHERE purchasing_invoice_id = NEW.purchasing_invoice_id AND status = 'completed' AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_outstanding := COALESCE(v_grand_total, 0) - v_paid;
  IF NEW.payment_amount > v_outstanding THEN
    RAISE EXCEPTION 'Payment amount % exceeds outstanding % for this invoice', NEW.payment_amount, v_outstanding;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ap_payment_validate_amount ON ap_payments;
CREATE TRIGGER trg_ap_payment_validate_amount
  BEFORE INSERT OR UPDATE ON ap_payments
  FOR EACH ROW
  EXECUTE FUNCTION fn_ap_payment_validate_amount();

-- ============================================================================
-- AUTO PAYMENT: PASS atm_id AND payment_reference TO ap_payments
-- (Extend existing fn_auto_payment_for_cash from FINANCE_ERP_RESTRUCTURE)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_auto_payment_for_cash()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
    v_ref TEXT;
BEGIN
    IF NEW.payment_method IN ('CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE', 'ONLINE_GATEWAY') THEN
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments WHERE purchasing_invoice_id = NEW.id AND status = 'completed';
        
        v_ref := COALESCE(NULLIF(TRIM(NEW.payment_reference), ''), 'AUTO-' || COALESCE(NEW.purchasing_number, 'NEW'));
        
        IF v_total_paid < COALESCE(NEW.grand_total, 0) THEN
            INSERT INTO ap_payments (purchasing_invoice_id, payment_date, payment_amount, payment_channel, reference_number, remarks, created_by, status, atm_id)
            VALUES (NEW.id, COALESCE(NEW.invoice_date, CURRENT_DATE), COALESCE(NEW.grand_total, 0) - v_total_paid, 
                CASE NEW.payment_method 
                  WHEN 'CASH_ON_HAND' THEN 'CASH' 
                  WHEN 'ATM_MARKET_PURCHASE' THEN 'CASH' 
                  WHEN 'FREE_SAMPLE' THEN 'CASH' 
                  WHEN 'ONLINE_GATEWAY' THEN 'ONLINE' 
                  ELSE 'CASH' END,
                v_ref, 
                CASE NEW.payment_method 
                  WHEN 'CASH_ON_HAND' THEN 'Auto - Cash on Hand' 
                  WHEN 'ATM_MARKET_PURCHASE' THEN 'Auto - ATM/Market' 
                  WHEN 'FREE_SAMPLE' THEN 'Auto - Free Sample' 
                  WHEN 'ONLINE_GATEWAY' THEN 'Auto - Online Gateway' 
                  ELSE 'Auto payment' END,
                NEW.created_by, 'completed',
                CASE WHEN NEW.payment_method = 'ATM_MARKET_PURCHASE' THEN NEW.atm_id ELSE NULL END);
            
            NEW.payment_status := 'paid';
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchasing_invoices' AND column_name = 'paid_date') THEN
              NEW.paid_date := COALESCE(NEW.invoice_date, CURRENT_DATE);
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchasing_invoices' AND column_name = 'paid_amount') THEN
              NEW.paid_amount := NEW.grand_total;
            END IF;
        END IF;
        
        IF NEW.payment_method = 'FREE_SAMPLE' THEN
            NEW.subtotal := 0;
            NEW.tax_amount := 0;
            NEW.grand_total := 0;
            NEW.payment_status := 'paid';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RLS FOR MASTER TABLES (optional)
-- ============================================================================
ALTER TABLE finance_atms ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_banks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for finance_atms" ON finance_atms;
CREATE POLICY "Allow all for finance_atms" ON finance_atms FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for finance_banks" ON finance_banks;
CREATE POLICY "Allow all for finance_banks" ON finance_banks FOR ALL USING (true) WITH CHECK (true);
