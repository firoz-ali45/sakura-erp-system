-- 05_PR_NUMBER_TRIGGER.sql
-- Fixes "null value in column pr_number" error by auto-generating PR numbers
-- UPDATED: Includes explicit DROP FUNCTION to handle existing function Type mismatches
BEGIN;
-------------------------------------------------------------------------
-- 1. CLEANUP (Fixes 42P13 Error)
-------------------------------------------------------------------------
-- Drop the existing function first to avoid "cannot change return type" errors
DROP TRIGGER IF EXISTS trg_generate_pr_number ON purchase_requests;
DROP FUNCTION IF EXISTS generate_pr_number() CASCADE;
-------------------------------------------------------------------------
-- 2. SEQUENCE FOR PR NUMBERS
-------------------------------------------------------------------------
-- Create sequence if it doesn't exist
CREATE SEQUENCE IF NOT EXISTS pr_number_seq;
-------------------------------------------------------------------------
-- 3. FUNCTION TO GENERATE PR NUMBER
-------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_pr_number() RETURNS TRIGGER AS $$
DECLARE next_val INTEGER;
year_str TEXT;
BEGIN -- Only generate if not provided
IF NEW.pr_number IS NULL THEN -- Get current year
year_str := to_char(now(), 'YYYY');
-- Get next value from sequence
next_val := nextval('pr_number_seq');
-- Format: PR-YYYY-XXXXX (e.g. PR-2026-00001)
NEW.pr_number := 'PR-' || year_str || '-' || lpad(next_val::text, 5, '0');
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-------------------------------------------------------------------------
-- 4. TRIGGER ON PURCHASE_REQUESTS
-------------------------------------------------------------------------
CREATE TRIGGER trg_generate_pr_number BEFORE
INSERT ON purchase_requests FOR EACH ROW EXECUTE FUNCTION generate_pr_number();
COMMIT;