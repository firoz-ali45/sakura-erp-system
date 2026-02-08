-- ============================================================================
-- FINANCE ERP RESTRUCTURE — SAP S/4HANA Best Practices
-- Purchasing = MIRO (invoices only, no payment execution)
-- Bank Transfer = Manual payment via Finance → Payments
-- ============================================================================

-- STEP 1: Update payment_method — remove BANK_TRANSFER, CREDIT; allow only auto-pay types
-- Migrate existing invalid values to CASH_ON_HAND
-- ============================================================================
UPDATE purchasing_invoices 
SET payment_method = 'CASH_ON_HAND' 
WHERE payment_method IN ('BANK_TRANSFER', 'CREDIT') OR payment_method IS NULL;

-- Drop existing check if any, then add new constraint
ALTER TABLE purchasing_invoices DROP CONSTRAINT IF EXISTS purchasing_invoices_payment_method_check;
ALTER TABLE purchasing_invoices ADD CONSTRAINT purchasing_invoices_payment_method_check 
  CHECK (payment_method IN ('CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE', 'ONLINE_GATEWAY'));

-- STEP 2: Add ONLINE_GATEWAY to auto-pay trigger (extend fn_auto_payment_for_cash)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_auto_payment_for_cash()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
BEGIN
    IF NEW.payment_method IN ('CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE', 'ONLINE_GATEWAY') THEN
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments WHERE purchasing_invoice_id = NEW.id AND status = 'completed';
        
        IF v_total_paid < COALESCE(NEW.grand_total, 0) THEN
            INSERT INTO ap_payments (purchasing_invoice_id, payment_date, payment_amount, payment_channel, reference_number, remarks, created_by, status)
            VALUES (NEW.id, COALESCE(NEW.invoice_date, CURRENT_DATE), COALESCE(NEW.grand_total, 0) - v_total_paid, 
                CASE NEW.payment_method 
                  WHEN 'CASH_ON_HAND' THEN 'CASH' 
                  WHEN 'ATM_MARKET_PURCHASE' THEN 'CASH' 
                  WHEN 'FREE_SAMPLE' THEN 'CASH' 
                  WHEN 'ONLINE_GATEWAY' THEN 'ONLINE' 
                  ELSE 'CASH' END,
                'AUTO-' || COALESCE(NEW.purchasing_number, 'NEW'), 
                CASE NEW.payment_method 
                  WHEN 'CASH_ON_HAND' THEN 'Auto - Cash on Hand' 
                  WHEN 'ATM_MARKET_PURCHASE' THEN 'Auto - ATM/Market' 
                  WHEN 'FREE_SAMPLE' THEN 'Auto - Free Sample' 
                  WHEN 'ONLINE_GATEWAY' THEN 'Auto - Online Gateway' 
                  ELSE 'Auto payment' END,
                NEW.created_by, 'completed');
            
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

-- STEP 3: Ensure ap_payments has required structure for manual payments
-- ============================================================================
-- (Table already exists from PURCHASING_FINANCE_MODULE - no change needed)
-- payment_channel: BANK_TRANSFER for manual, CASH/ONLINE for auto

-- STEP 4: Add paid_amount, outstanding_amount if missing (for AP dashboard)
-- ============================================================================
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS paid_date DATE;

-- Backfill paid_amount from ap_payments
UPDATE purchasing_invoices pi
SET paid_amount = COALESCE((
  SELECT SUM(payment_amount) FROM ap_payments 
  WHERE purchasing_invoice_id = pi.id AND status = 'completed'
), 0)
WHERE paid_amount IS NULL OR paid_amount = 0;

-- ============================================================================
-- DONE. Finance structure: Purchasing (auto-pay only) | Payments (manual) | AP
-- ============================================================================
