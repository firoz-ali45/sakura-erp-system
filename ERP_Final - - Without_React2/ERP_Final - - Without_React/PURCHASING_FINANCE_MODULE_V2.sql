-- PURCHASING FINANCE MODULE - SAP MIRO Style
-- Run this in Supabase SQL Editor

-- SECTION 1: ADD NEW COLUMNS
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS purchasing_number TEXT;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS vendor_invoice_number TEXT;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'BANK_TRANSFER';
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'CREDIT';
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS payment_reference TEXT;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS paid_date DATE;
ALTER TABLE purchasing_invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC DEFAULT 0;

-- SECTION 2: CREATE SEQUENCE FOR PUR-XXXXXX
DROP SEQUENCE IF EXISTS purchasing_doc_seq CASCADE;
CREATE SEQUENCE purchasing_doc_seq START WITH 1 INCREMENT BY 1 NO MAXVALUE NO CYCLE;

-- Set sequence to max existing value
DO $$
DECLARE
    v_max_num INTEGER;
BEGIN
    SELECT COALESCE(MAX(CASE WHEN purchasing_number ~ '^PUR-[0-9]+$' THEN CAST(SUBSTRING(purchasing_number FROM 5) AS INTEGER) ELSE 0 END), 0) INTO v_max_num FROM purchasing_invoices WHERE purchasing_number IS NOT NULL;
    IF v_max_num > 0 THEN
        PERFORM setval('purchasing_doc_seq', v_max_num);
    END IF;
END $$;

-- SECTION 3: TRIGGER FOR AUTO PURCHASING NUMBER
DROP TRIGGER IF EXISTS trg_generate_purchasing_number ON purchasing_invoices;
DROP FUNCTION IF EXISTS fn_generate_purchasing_number();

CREATE OR REPLACE FUNCTION fn_generate_purchasing_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.purchasing_number IS NULL OR NEW.purchasing_number = '' THEN
        NEW.purchasing_number := 'PUR-' || LPAD(nextval('purchasing_doc_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_purchasing_number
    BEFORE INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION fn_generate_purchasing_number();

-- SECTION 4: CREATE AP_PAYMENTS TABLE
DROP TABLE IF EXISTS ap_payments CASCADE;

CREATE TABLE ap_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchasing_invoice_id UUID NOT NULL REFERENCES purchasing_invoices(id) ON DELETE CASCADE,
    payment_number TEXT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_amount NUMERIC NOT NULL DEFAULT 0,
    payment_channel TEXT NOT NULL DEFAULT 'BANK_TRANSFER',
    bank_account TEXT,
    bank_name TEXT,
    reference_number TEXT,
    check_number TEXT,
    transaction_id TEXT,
    remarks TEXT,
    gl_journal_id UUID,
    gl_account_code TEXT,
    status TEXT DEFAULT 'completed',
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Payment number sequence
DROP SEQUENCE IF EXISTS ap_payment_seq CASCADE;
CREATE SEQUENCE ap_payment_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE FUNCTION fn_generate_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
        NEW.payment_number := 'PAY-' || LPAD(nextval('ap_payment_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_payment_number
    BEFORE INSERT ON ap_payments
    FOR EACH ROW
    EXECUTE FUNCTION fn_generate_payment_number();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ap_payments_invoice ON ap_payments(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_ap_payments_date ON ap_payments(payment_date);

-- SECTION 5: AUTO PAYMENT TRIGGER FOR CASH METHODS
CREATE OR REPLACE FUNCTION fn_auto_payment_for_cash()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
BEGIN
    IF NEW.payment_method IN ('CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE') THEN
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments WHERE purchasing_invoice_id = NEW.id AND status = 'completed';
        
        IF v_total_paid < COALESCE(NEW.grand_total, 0) THEN
            INSERT INTO ap_payments (purchasing_invoice_id, payment_date, payment_amount, payment_channel, reference_number, remarks, created_by, status)
            VALUES (NEW.id, COALESCE(NEW.invoice_date, CURRENT_DATE), COALESCE(NEW.grand_total, 0) - v_total_paid, 'CASH', 'AUTO-' || COALESCE(NEW.purchasing_number, 'NEW'), 
                CASE NEW.payment_method WHEN 'CASH_ON_HAND' THEN 'Auto - Cash on Hand' WHEN 'ATM_MARKET_PURCHASE' THEN 'Auto - ATM/Market' WHEN 'FREE_SAMPLE' THEN 'Auto - Free Sample' ELSE 'Auto payment' END,
                NEW.created_by, 'completed');
            
            NEW.payment_status := 'paid';
            NEW.paid_date := COALESCE(NEW.invoice_date, CURRENT_DATE);
            NEW.paid_amount := NEW.grand_total;
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

DROP TRIGGER IF EXISTS trg_auto_payment_cash ON purchasing_invoices;
CREATE TRIGGER trg_auto_payment_cash
    BEFORE UPDATE ON purchasing_invoices
    FOR EACH ROW
    WHEN (OLD.payment_method IS DISTINCT FROM NEW.payment_method OR OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_auto_payment_for_cash();

-- SECTION 6: UPDATE PAYMENT STATUS BASED ON PAYMENTS
CREATE OR REPLACE FUNCTION fn_update_invoice_payment_status()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
    v_grand_total NUMERIC;
    v_new_status TEXT;
    v_invoice_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_invoice_id := OLD.purchasing_invoice_id;
    ELSE
        v_invoice_id := NEW.purchasing_invoice_id;
    END IF;
    
    SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid FROM ap_payments WHERE purchasing_invoice_id = v_invoice_id AND status = 'completed';
    SELECT grand_total INTO v_grand_total FROM purchasing_invoices WHERE id = v_invoice_id;
    
    IF v_total_paid >= COALESCE(v_grand_total, 0) THEN
        v_new_status := 'paid';
    ELSIF v_total_paid > 0 THEN
        v_new_status := 'partial';
    ELSE
        v_new_status := 'unpaid';
    END IF;
    
    UPDATE purchasing_invoices SET payment_status = v_new_status, paid_amount = v_total_paid, paid_date = CASE WHEN v_new_status = 'paid' THEN CURRENT_DATE ELSE NULL END, updated_at = now() WHERE id = v_invoice_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_invoice_payment_status ON ap_payments;
CREATE TRIGGER trg_update_invoice_payment_status
    AFTER INSERT OR UPDATE OR DELETE ON ap_payments
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_invoice_payment_status();

-- SECTION 7: PAYMENT TERMS CALCULATION
CREATE OR REPLACE FUNCTION fn_calc_payment_terms()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.invoice_date IS NOT NULL AND NEW.due_date IS NOT NULL THEN
        NEW.payment_terms_days := (NEW.due_date - NEW.invoice_date);
    ELSIF NEW.invoice_date IS NOT NULL AND NEW.payment_terms_days IS NOT NULL THEN
        NEW.due_date := NEW.invoice_date + NEW.payment_terms_days;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calc_payment_terms ON purchasing_invoices;
CREATE TRIGGER trg_calc_payment_terms
    BEFORE INSERT OR UPDATE ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION fn_calc_payment_terms();

-- SECTION 8: VIEW FOR PURCHASING SUMMARY
DROP VIEW IF EXISTS v_purchasing_summary;
CREATE OR REPLACE VIEW v_purchasing_summary AS
SELECT 
    pi.id, pi.purchasing_number, pi.vendor_invoice_number, pi.invoice_number,
    pi.grn_id, pi.grn_number, pi.purchase_order_id, pi.purchase_order_number,
    pi.supplier_id, pi.supplier_name, pi.invoice_date, pi.due_date, pi.payment_terms_days,
    pi.payment_method, pi.payment_type, pi.subtotal, pi.tax_rate, pi.tax_amount,
    pi.grand_total, pi.paid_amount, pi.paid_date, pi.status, pi.payment_status,
    pi.receiving_location, pi.created_by, pi.created_at, pi.approved_by, pi.approved_at,
    CASE WHEN pi.due_date < CURRENT_DATE AND pi.payment_status != 'paid' THEN true ELSE false END AS is_overdue,
    CURRENT_DATE - pi.due_date AS days_overdue,
    pi.grand_total - COALESCE(pi.paid_amount, 0) AS outstanding_amount,
    (SELECT COUNT(*) FROM ap_payments WHERE purchasing_invoice_id = pi.id) AS payment_count,
    (SELECT COALESCE(SUM(payment_amount), 0) FROM ap_payments WHERE purchasing_invoice_id = pi.id AND status = 'completed') AS total_payments
FROM purchasing_invoices pi
WHERE pi.deleted IS NOT TRUE;

-- SECTION 9: UPDATE EXISTING DATA
UPDATE purchasing_invoices SET purchasing_number = 'PUR-' || LPAD(nextval('purchasing_doc_seq')::TEXT, 6, '0') WHERE purchasing_number IS NULL OR purchasing_number = '';
UPDATE purchasing_invoices SET payment_method = 'BANK_TRANSFER' WHERE payment_method IS NULL;
UPDATE purchasing_invoices SET payment_type = 'CREDIT' WHERE payment_type IS NULL;

-- SECTION 10: RLS POLICIES
ALTER TABLE ap_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated access to ap_payments" ON ap_payments;
CREATE POLICY "Allow authenticated access to ap_payments" ON ap_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow anon access to ap_payments" ON ap_payments;
CREATE POLICY "Allow anon access to ap_payments" ON ap_payments FOR ALL TO anon USING (true) WITH CHECK (true);

-- VERIFICATION
SELECT 'PURCHASING FINANCE MODULE INSTALLED' AS status;
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'purchasing_invoices' AND column_name IN ('purchasing_number', 'vendor_invoice_number', 'payment_method', 'payment_type', 'paid_date', 'paid_amount');
SELECT id, purchasing_number, payment_method, payment_status FROM purchasing_invoices ORDER BY created_at DESC LIMIT 5;
