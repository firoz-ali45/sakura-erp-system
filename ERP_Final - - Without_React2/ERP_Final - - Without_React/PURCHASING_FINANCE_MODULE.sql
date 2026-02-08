-- ============================================================
-- PURCHASING FINANCE MODULE - SAP MIRO Style
-- Enterprise Finance Workflow Implementation
-- ============================================================
-- 
-- SAP Equivalent:
-- - Purchasing Doc (MIRO) - PUR-XXXXXX
-- - Vendor Invoice Entry - Manual
-- - AP Payment (F-53/F110) - ap_payments table
-- - GL Posting - gl_journal
--
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================

-- ============================================================
-- SECTION 1: ADD NEW COLUMNS TO purchasing_invoices
-- ============================================================

-- Add purchasing_number column (PUR-000001 format)
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS purchasing_number TEXT;

-- Add vendor invoice fields (manual entry)
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS vendor_invoice_number TEXT;

-- Add payment method (enterprise dropdown)
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'BANK_TRANSFER'
CHECK (payment_method IN (
    'CASH_ON_HAND',
    'ATM_MARKET_PURCHASE', 
    'FREE_SAMPLE',
    'BANK_TRANSFER',
    'ONLINE_GATEWAY',
    'CREDIT'
));

-- Add payment type
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'CREDIT'
CHECK (payment_type IN ('CASH', 'CREDIT'));

-- Add payment reference
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS payment_reference TEXT;

-- Add paid_date
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS paid_date DATE;

-- Add paid_amount
ALTER TABLE purchasing_invoices 
ADD COLUMN IF NOT EXISTS paid_amount NUMERIC DEFAULT 0;


-- ============================================================
-- SECTION 2: CREATE PURCHASING DOCUMENT NUMBER SEQUENCE
-- ============================================================

-- Drop existing sequence if needed
DROP SEQUENCE IF EXISTS purchasing_doc_seq CASCADE;

-- Create sequence for PUR-XXXXXX format
CREATE SEQUENCE purchasing_doc_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE;

-- Get current max purchasing number to set sequence correctly
DO $$
DECLARE
    v_max_num INTEGER;
BEGIN
    SELECT COALESCE(
        MAX(
            CASE 
                WHEN purchasing_number ~ '^PUR-[0-9]+$' 
                THEN CAST(SUBSTRING(purchasing_number FROM 5) AS INTEGER)
                ELSE 0 
            END
        ), 0
    ) INTO v_max_num
    FROM purchasing_invoices
    WHERE purchasing_number IS NOT NULL;
    
    IF v_max_num > 0 THEN
        PERFORM setval('purchasing_doc_seq', v_max_num);
    END IF;
END $$;


-- ============================================================
-- SECTION 3: CREATE TRIGGER FOR AUTO PURCHASING NUMBER
-- ============================================================

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trg_generate_purchasing_number ON purchasing_invoices;
DROP FUNCTION IF EXISTS fn_generate_purchasing_number();

-- Create function to generate PUR-XXXXXX
CREATE OR REPLACE FUNCTION fn_generate_purchasing_number()
RETURNS TRIGGER AS $$
BEGIN
    -- Only generate if purchasing_number is null or empty
    IF NEW.purchasing_number IS NULL OR NEW.purchasing_number = '' THEN
        NEW.purchasing_number := 'PUR-' || LPAD(nextval('purchasing_doc_seq')::TEXT, 6, '0');
    END IF;
    
    -- Log for debugging
    RAISE NOTICE 'Generated Purchasing Number: %', NEW.purchasing_number;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger BEFORE INSERT
CREATE TRIGGER trg_generate_purchasing_number
    BEFORE INSERT ON purchasing_invoices
    FOR EACH ROW
    EXECUTE FUNCTION fn_generate_purchasing_number();


-- ============================================================
-- SECTION 4: CREATE AP_PAYMENTS TABLE (SAP F-53/F110)
-- ============================================================

-- Drop existing table if exists
DROP TABLE IF EXISTS ap_payments CASCADE;

-- Create AP Payments table for finance payment tracking
CREATE TABLE ap_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Reference to purchasing invoice
    purchasing_invoice_id UUID NOT NULL REFERENCES purchasing_invoices(id) ON DELETE CASCADE,
    
    -- Payment details
    payment_number TEXT, -- PAY-XXXXXX auto-generated
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_amount NUMERIC NOT NULL DEFAULT 0,
    
    -- Payment channel/method
    payment_channel TEXT NOT NULL DEFAULT 'BANK_TRANSFER'
        CHECK (payment_channel IN ('CASH', 'BANK_TRANSFER', 'CARD', 'ONLINE', 'CHECK', 'CREDIT_NOTE')),
    
    -- Bank details (for bank transfers)
    bank_account TEXT,
    bank_name TEXT,
    
    -- Reference numbers
    reference_number TEXT,
    check_number TEXT,
    transaction_id TEXT,
    
    -- Remarks
    remarks TEXT,
    
    -- GL Integration
    gl_journal_id UUID,
    gl_account_code TEXT,
    
    -- Status
    status TEXT DEFAULT 'completed'
        CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    
    -- Audit
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create payment number sequence
DROP SEQUENCE IF EXISTS ap_payment_seq CASCADE;
CREATE SEQUENCE ap_payment_seq START WITH 1 INCREMENT BY 1;

-- Create trigger for payment number
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

-- Create indexes for performance
CREATE INDEX idx_ap_payments_invoice ON ap_payments(purchasing_invoice_id);
CREATE INDEX idx_ap_payments_date ON ap_payments(payment_date);
CREATE INDEX idx_ap_payments_status ON ap_payments(status);


-- ============================================================
-- SECTION 5: AUTO PAYMENT TRIGGER FOR CASH METHODS
-- ============================================================

-- Function to auto-create payment for cash methods
CREATE OR REPLACE FUNCTION fn_auto_payment_for_cash()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
BEGIN
    -- Only process if payment_method changed or status changed to approved
    IF NEW.payment_method IN ('CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE') THEN
        
        -- Check if payment already exists
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments
        WHERE purchasing_invoice_id = NEW.id AND status = 'completed';
        
        -- If not fully paid, create auto payment
        IF v_total_paid < NEW.grand_total THEN
            INSERT INTO ap_payments (
                purchasing_invoice_id,
                payment_date,
                payment_amount,
                payment_channel,
                reference_number,
                remarks,
                created_by,
                status
            ) VALUES (
                NEW.id,
                COALESCE(NEW.invoice_date, CURRENT_DATE),
                NEW.grand_total - v_total_paid,
                'CASH',
                'AUTO-' || NEW.purchasing_number,
                CASE NEW.payment_method
                    WHEN 'CASH_ON_HAND' THEN 'Auto payment - Cash on Hand'
                    WHEN 'ATM_MARKET_PURCHASE' THEN 'Auto payment - ATM/Market Purchase'
                    WHEN 'FREE_SAMPLE' THEN 'Auto payment - Free Sample (Zero Cost)'
                    ELSE 'Auto payment'
                END,
                NEW.created_by,
                'completed'
            );
            
            -- Update payment status to paid
            NEW.payment_status := 'paid';
            NEW.paid_date := COALESCE(NEW.invoice_date, CURRENT_DATE);
            NEW.paid_amount := NEW.grand_total;
            
            RAISE NOTICE 'Auto-created cash payment for PUR %', NEW.purchasing_number;
        END IF;
        
        -- For FREE_SAMPLE, set amounts to zero
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

-- Create trigger for auto payment
DROP TRIGGER IF EXISTS trg_auto_payment_cash ON purchasing_invoices;
CREATE TRIGGER trg_auto_payment_cash
    BEFORE UPDATE ON purchasing_invoices
    FOR EACH ROW
    WHEN (
        OLD.payment_method IS DISTINCT FROM NEW.payment_method
        OR OLD.status IS DISTINCT FROM NEW.status
    )
    EXECUTE FUNCTION fn_auto_payment_for_cash();


-- ============================================================
-- SECTION 6: UPDATE PAYMENT STATUS BASED ON PAYMENTS
-- ============================================================

-- Function to recalculate payment status
CREATE OR REPLACE FUNCTION fn_update_invoice_payment_status()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC;
    v_grand_total NUMERIC;
    v_new_status TEXT;
BEGIN
    -- Get the invoice ID
    IF TG_OP = 'DELETE' THEN
        -- Calculate for old invoice
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments
        WHERE purchasing_invoice_id = OLD.purchasing_invoice_id AND status = 'completed';
        
        SELECT grand_total INTO v_grand_total
        FROM purchasing_invoices
        WHERE id = OLD.purchasing_invoice_id;
    ELSE
        -- Calculate for new/updated invoice
        SELECT COALESCE(SUM(payment_amount), 0) INTO v_total_paid
        FROM ap_payments
        WHERE purchasing_invoice_id = NEW.purchasing_invoice_id AND status = 'completed';
        
        SELECT grand_total INTO v_grand_total
        FROM purchasing_invoices
        WHERE id = NEW.purchasing_invoice_id;
    END IF;
    
    -- Determine new status
    IF v_total_paid >= v_grand_total THEN
        v_new_status := 'paid';
    ELSIF v_total_paid > 0 THEN
        v_new_status := 'partial';
    ELSE
        v_new_status := 'unpaid';
    END IF;
    
    -- Update the invoice
    IF TG_OP = 'DELETE' THEN
        UPDATE purchasing_invoices
        SET payment_status = v_new_status,
            paid_amount = v_total_paid,
            updated_at = now()
        WHERE id = OLD.purchasing_invoice_id;
    ELSE
        UPDATE purchasing_invoices
        SET payment_status = v_new_status,
            paid_amount = v_total_paid,
            paid_date = CASE WHEN v_new_status = 'paid' THEN CURRENT_DATE ELSE NULL END,
            updated_at = now()
        WHERE id = NEW.purchasing_invoice_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update payment status
DROP TRIGGER IF EXISTS trg_update_invoice_payment_status ON ap_payments;
CREATE TRIGGER trg_update_invoice_payment_status
    AFTER INSERT OR UPDATE OR DELETE ON ap_payments
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_invoice_payment_status();


-- ============================================================
-- SECTION 7: PAYMENT TERMS AUTO CALCULATION FUNCTION
-- ============================================================

-- Function to calculate payment terms days
CREATE OR REPLACE FUNCTION fn_calc_payment_terms()
RETURNS TRIGGER AS $$
BEGIN
    -- If both dates are set, calculate payment terms
    IF NEW.invoice_date IS NOT NULL AND NEW.due_date IS NOT NULL THEN
        NEW.payment_terms_days := (NEW.due_date - NEW.invoice_date);
    -- If invoice_date and payment_terms set, calculate due_date
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


-- ============================================================
-- SECTION 8: VIEW FOR PURCHASING SUMMARY
-- ============================================================

DROP VIEW IF EXISTS v_purchasing_summary;
CREATE OR REPLACE VIEW v_purchasing_summary AS
SELECT 
    pi.id,
    pi.purchasing_number,
    pi.vendor_invoice_number,
    pi.invoice_number, -- legacy
    pi.grn_id,
    pi.grn_number,
    pi.purchase_order_id,
    pi.purchase_order_number,
    pi.supplier_id,
    pi.supplier_name,
    pi.invoice_date,
    pi.due_date,
    pi.payment_terms_days,
    pi.payment_method,
    pi.payment_type,
    pi.subtotal,
    pi.tax_rate,
    pi.tax_amount,
    pi.grand_total,
    pi.paid_amount,
    pi.paid_date,
    pi.status,
    pi.payment_status,
    pi.receiving_location,
    pi.created_by,
    pi.created_at,
    pi.approved_by,
    pi.approved_at,
    -- Calculated fields
    CASE 
        WHEN pi.due_date < CURRENT_DATE AND pi.payment_status != 'paid' 
        THEN true ELSE false 
    END AS is_overdue,
    CURRENT_DATE - pi.due_date AS days_overdue,
    pi.grand_total - COALESCE(pi.paid_amount, 0) AS outstanding_amount,
    -- Payment summary
    (SELECT COUNT(*) FROM ap_payments WHERE purchasing_invoice_id = pi.id) AS payment_count,
    (SELECT COALESCE(SUM(payment_amount), 0) FROM ap_payments WHERE purchasing_invoice_id = pi.id AND status = 'completed') AS total_payments
FROM purchasing_invoices pi
WHERE pi.deleted IS NOT TRUE;


-- ============================================================
-- SECTION 9: UPDATE EXISTING DATA
-- ============================================================

-- Generate purchasing numbers for existing records without one
UPDATE purchasing_invoices
SET purchasing_number = 'PUR-' || LPAD(nextval('purchasing_doc_seq')::TEXT, 6, '0')
WHERE purchasing_number IS NULL OR purchasing_number = '';

-- Set default payment method for existing records
UPDATE purchasing_invoices
SET payment_method = 'BANK_TRANSFER'
WHERE payment_method IS NULL;

-- Set default payment type for existing records
UPDATE purchasing_invoices
SET payment_type = 'CREDIT'
WHERE payment_type IS NULL;


-- ============================================================
-- SECTION 10: RLS POLICIES FOR ap_payments
-- ============================================================

-- Enable RLS
ALTER TABLE ap_payments ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users full access (adjust as needed)
DROP POLICY IF EXISTS "Allow authenticated access to ap_payments" ON ap_payments;
CREATE POLICY "Allow authenticated access to ap_payments"
    ON ap_payments
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow anonymous access for development (remove in production)
DROP POLICY IF EXISTS "Allow anon access to ap_payments" ON ap_payments;
CREATE POLICY "Allow anon access to ap_payments"
    ON ap_payments
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);


-- ============================================================
-- VERIFICATION
-- ============================================================

-- Check purchasing_invoices structure
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'purchasing_invoices'
ORDER BY ordinal_position;

-- Check existing purchasing numbers
SELECT id, purchasing_number, vendor_invoice_number, invoice_number, 
       payment_method, payment_type, payment_status
FROM purchasing_invoices
ORDER BY created_at DESC
LIMIT 10;

-- Check ap_payments table
SELECT * FROM ap_payments LIMIT 5;


-- ============================================================
-- COMPLETION MESSAGE
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ PURCHASING FINANCE MODULE INSTALLED';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'NEW FEATURES:';
    RAISE NOTICE '1. Purchasing Number: PUR-XXXXXX (auto-generated)';
    RAISE NOTICE '2. Vendor Invoice Number: Manual entry field';
    RAISE NOTICE '3. Payment Method: CASH_ON_HAND, ATM_MARKET_PURCHASE, FREE_SAMPLE, BANK_TRANSFER, ONLINE_GATEWAY, CREDIT';
    RAISE NOTICE '4. Payment Type: CASH or CREDIT';
    RAISE NOTICE '5. Auto Payment: Cash methods auto-create payment record';
    RAISE NOTICE '6. AP Payments Table: Full payment tracking';
    RAISE NOTICE '7. Payment Status: Auto-updates based on payments';
    RAISE NOTICE '';
    RAISE NOTICE 'SAP EQUIVALENT:';
    RAISE NOTICE '- PUR-XXXXXX = MIRO Document Number';
    RAISE NOTICE '- Vendor Invoice = External Invoice Reference';
    RAISE NOTICE '- AP Payments = F-53 Payment Document';
    RAISE NOTICE '';
END $$;
