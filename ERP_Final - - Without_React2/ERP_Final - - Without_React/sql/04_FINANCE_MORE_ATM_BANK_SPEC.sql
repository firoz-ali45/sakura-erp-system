-- ============================================================================
-- FINANCE → MORE: ATM & BANK MASTER SPEC (World-class ERP)
-- atm_number UNIQUE REQUIRED; linked_bank_name; account_name
-- ============================================================================

-- ============================================================================
-- FINANCE_ATMS: atm_number UNIQUE NOT NULL, linked_bank_name
-- ============================================================================
ALTER TABLE finance_atms ADD COLUMN IF NOT EXISTS linked_bank_name text;
UPDATE finance_atms SET linked_bank_name = bank_name WHERE linked_bank_name IS NULL AND bank_name IS NOT NULL;

-- Ensure atm_number exists and is populated for unique constraint (temp placeholder for nulls)
UPDATE finance_atms SET atm_number = 'ATM-' || id::text WHERE atm_number IS NULL OR atm_number = '';

-- Drop existing unique if any, then add unique constraint on atm_number
ALTER TABLE finance_atms DROP CONSTRAINT IF EXISTS finance_atms_atm_number_key;
ALTER TABLE finance_atms DROP CONSTRAINT IF EXISTS uq_finance_atms_atm_number;
CREATE UNIQUE INDEX IF NOT EXISTS uq_finance_atms_atm_number ON finance_atms(atm_number) WHERE atm_number IS NOT NULL AND atm_number != '';

-- Make atm_number NOT NULL for new rows (allow existing nulls until backfilled)
-- Optional: ALTER TABLE finance_atms ALTER COLUMN atm_number SET NOT NULL;
-- (Skip NOT NULL if you have legacy rows; app will enforce required on create/edit.)

-- ============================================================================
-- FINANCE_BANKS: account_name
-- ============================================================================
ALTER TABLE finance_banks ADD COLUMN IF NOT EXISTS account_name text;

-- ============================================================================
-- RLS (if not already)
-- ============================================================================
ALTER TABLE finance_atms ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_banks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all for finance_atms" ON finance_atms;
CREATE POLICY "Allow all for finance_atms" ON finance_atms FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for finance_banks" ON finance_banks;
CREATE POLICY "Allow all for finance_banks" ON finance_banks FOR ALL USING (true) WITH CHECK (true);
