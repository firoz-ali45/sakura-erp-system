-- ============================================================================
-- HARD RESET: FINANCE MODULE + RBAC (SAP-GRADE ARCHITECTURE)
-- Parts 1–2: Payment Configuration (ATM, Bank, Payment Rules)
-- Parts 4–5: finance_payments + v_accounts_payable_open
-- Part 8: RBAC (roles, permissions, role_permissions, user_roles, workflow)
-- ============================================================================
-- Run after: FINANCE_ERP_RESTRUCTURE.sql, 02_FINANCE_MASTER_CURRENCY_COST.sql
-- ============================================================================

-- ============================================================================
-- PART 2A: ATM MASTER — ADD location, ENSURE SCHEMA
-- ============================================================================
CREATE TABLE IF NOT EXISTS finance_atms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  atm_name text NOT NULL,
  atm_number text,
  bank_name text,
  location text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE finance_atms ADD COLUMN IF NOT EXISTS location text;
CREATE INDEX IF NOT EXISTS idx_finance_atms_active ON finance_atms(is_active) WHERE is_active = true;

-- ============================================================================
-- PART 2B: BANK MASTER — ADD swift_code
-- ============================================================================
CREATE TABLE IF NOT EXISTS finance_banks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name text NOT NULL,
  account_number text,
  iban text,
  swift_code text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE finance_banks ADD COLUMN IF NOT EXISTS swift_code text;
CREATE INDEX IF NOT EXISTS idx_finance_banks_active ON finance_banks(is_active) WHERE is_active = true;

-- ============================================================================
-- PART 2C: PAYMENT RULES ENGINE (configurable, not hardcoded)
-- ============================================================================
CREATE TABLE IF NOT EXISTS finance_payment_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_method text NOT NULL UNIQUE,
  display_name text NOT NULL,
  is_auto_payment boolean NOT NULL DEFAULT false,
  requires_atm boolean NOT NULL DEFAULT false,
  requires_bank boolean NOT NULL DEFAULT false,
  requires_reference boolean NOT NULL DEFAULT false,
  allow_in_purchasing boolean NOT NULL DEFAULT false,
  zero_value_means_free_sample boolean NOT NULL DEFAULT false,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Seed payment rules (SAP-grade logic)
INSERT INTO finance_payment_rules (payment_method, display_name, is_auto_payment, requires_atm, requires_bank, requires_reference, allow_in_purchasing, zero_value_means_free_sample, sort_order)
VALUES
  ('CASH_ON_HAND', 'Cash on Hand', true, false, false, false, true, false, 1),
  ('ATM_MARKET_PURCHASE', 'ATM / Market Purchase', true, true, false, false, true, false, 2),
  ('FREE_SAMPLE', 'Free Sample', true, false, false, false, true, true, 3),
  ('ONLINE_GATEWAY', 'Online Gateway', true, false, false, true, true, false, 4),
  ('BANK_TRANSFER', 'Bank Transfer', false, false, true, false, false, false, 5)
ON CONFLICT (payment_method) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  is_auto_payment = EXCLUDED.is_auto_payment,
  requires_atm = EXCLUDED.requires_atm,
  requires_bank = EXCLUDED.requires_bank,
  requires_reference = EXCLUDED.requires_reference,
  allow_in_purchasing = EXCLUDED.allow_in_purchasing,
  zero_value_means_free_sample = EXCLUDED.zero_value_means_free_sample,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

-- CREDIT is FORBIDDEN — not inserted; purchasing_invoices constraint already limits to allowed methods.

-- ============================================================================
-- PART 4: FINANCE_PAYMENTS (enterprise payments table)
-- ============================================================================
CREATE TABLE IF NOT EXISTS finance_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_number text,
  payment_type text NOT NULL CHECK (payment_type IN ('AUTO', 'MANUAL')),
  payment_method text NOT NULL,
  purchasing_invoice_id uuid REFERENCES purchasing_invoices(id) ON DELETE SET NULL,
  vendor_id bigint REFERENCES suppliers(id) ON DELETE SET NULL,
  bank_id uuid REFERENCES finance_banks(id) ON DELETE SET NULL,
  atm_id uuid REFERENCES finance_atms(id) ON DELETE SET NULL,
  amount numeric(15,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'SAR',
  reference text,
  payment_date date DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('draft', 'pending', 'completed', 'cancelled')),
  created_by text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE finance_payments ADD COLUMN IF NOT EXISTS payment_date date;

CREATE INDEX IF NOT EXISTS idx_finance_payments_invoice ON finance_payments(purchasing_invoice_id);
CREATE INDEX IF NOT EXISTS idx_finance_payments_vendor ON finance_payments(vendor_id);
CREATE INDEX IF NOT EXISTS idx_finance_payments_date ON finance_payments(created_at);
CREATE INDEX IF NOT EXISTS idx_finance_payments_type ON finance_payments(payment_type);

-- Payment number sequence
DROP SEQUENCE IF EXISTS finance_payment_seq CASCADE;
CREATE SEQUENCE finance_payment_seq START WITH 1;

CREATE OR REPLACE FUNCTION fn_finance_payment_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.payment_number IS NULL OR NEW.payment_number = '' THEN
    NEW.payment_number := 'PAY-' || LPAD(nextval('finance_payment_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_finance_payment_number ON finance_payments;
CREATE TRIGGER trg_finance_payment_number
  BEFORE INSERT ON finance_payments FOR EACH ROW
  EXECUTE FUNCTION fn_finance_payment_number();

-- Migrate existing ap_payments into finance_payments (one-time, skip if already migrated)
INSERT INTO finance_payments (payment_type, payment_method, purchasing_invoice_id, vendor_id, bank_id, atm_id, amount, currency, reference, payment_date, status, created_by, created_at)
SELECT
  CASE WHEN ap.payment_channel = 'BANK_TRANSFER' THEN 'MANUAL'::text ELSE 'AUTO'::text END,
  CASE ap.payment_channel
    WHEN 'BANK_TRANSFER' THEN 'BANK_TRANSFER'
    WHEN 'ONLINE' THEN 'ONLINE_GATEWAY'
    ELSE 'CASH_ON_HAND'
  END,
  ap.purchasing_invoice_id,
  pi.supplier_id,
  ap.bank_id,
  ap.atm_id,
  ap.payment_amount,
  'SAR',
  ap.reference_number,
  COALESCE(ap.payment_date, (ap.created_at)::date, CURRENT_DATE),
  COALESCE(ap.status, 'completed'),
  ap.created_by,
  COALESCE(ap.created_at, now())
FROM ap_payments ap
LEFT JOIN purchasing_invoices pi ON pi.id = ap.purchasing_invoice_id
WHERE ap.purchasing_invoice_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM finance_payments fp
    WHERE fp.purchasing_invoice_id = ap.purchasing_invoice_id
      AND fp.amount = ap.payment_amount
      AND fp.created_at IS NOT DISTINCT FROM ap.created_at
  );

-- Sync purchasing_invoices.paid_amount when finance_payments inserted/updated/deleted
CREATE OR REPLACE FUNCTION fn_finance_payment_sync_invoice_paid()
RETURNS TRIGGER AS $$
DECLARE
  v_invoice_id uuid;
  v_total_paid numeric(15,2);
  v_new_status text;
BEGIN
  v_invoice_id := COALESCE(NEW.purchasing_invoice_id, OLD.purchasing_invoice_id);
  IF v_invoice_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM finance_payments
  WHERE purchasing_invoice_id = v_invoice_id AND status = 'completed';

  v_new_status := CASE
    WHEN v_total_paid >= COALESCE((SELECT grand_total FROM purchasing_invoices WHERE id = v_invoice_id), 0) THEN 'paid'
    WHEN v_total_paid > 0 THEN 'partial'
    ELSE 'unpaid'
  END;

  UPDATE purchasing_invoices
  SET paid_amount = v_total_paid,
      payment_status = v_new_status,
      paid_date = CASE WHEN v_new_status = 'paid' THEN CURRENT_DATE ELSE NULL END,
      updated_at = now()
  WHERE id = v_invoice_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_finance_payment_sync_invoice ON finance_payments;
CREATE TRIGGER trg_finance_payment_sync_invoice
  AFTER INSERT OR UPDATE OR DELETE ON finance_payments
  FOR EACH ROW EXECUTE FUNCTION fn_finance_payment_sync_invoice_paid();

-- ============================================================================
-- PART 5: V_ACCOUNTS_PAYABLE_OPEN (SAP-style open item ledger)
-- Derived ONLY from purchasing_invoices + finance_payments
-- ============================================================================
CREATE OR REPLACE VIEW v_accounts_payable_open AS
SELECT
  pi.id AS purchasing_invoice_id,
  pi.purchasing_number AS invoice_no,
  pi.vendor_invoice_number AS vendor_invoice_no,
  pi.supplier_id AS vendor_id,
  pi.supplier_name AS vendor_name,
  pi.invoice_date,
  pi.due_date,
  pi.grand_total AS invoice_amount,
  COALESCE(pi.paid_amount, 0) AS paid_amount,
  COALESCE(pi.grand_total, 0) - COALESCE(pi.paid_amount, 0) AS outstanding,
  pi.payment_status AS status,
  pi.currency,
  CASE
    WHEN pi.due_date IS NULL THEN NULL
    WHEN CURRENT_DATE <= pi.due_date THEN '0-30'
    WHEN CURRENT_DATE - pi.due_date <= 30 THEN '31-60'
    WHEN CURRENT_DATE - pi.due_date <= 60 THEN '61-90'
    ELSE '90+'
  END AS aging_bucket,
  (CURRENT_DATE - pi.due_date)::integer AS days_overdue
FROM purchasing_invoices pi
WHERE COALESCE(pi.deleted, false) = false
  AND pi.grand_total IS NOT NULL;

-- Paid amount must stay in sync: ensure purchasing_invoices.paid_amount = sum(finance_payments) for that invoice
-- (Trigger or app responsibility; view reads from pi.paid_amount which should be maintained)

-- ============================================================================
-- PART 8: RBAC — ROLES, PERMISSIONS, USER_ROLES, WORKFLOW
-- ============================================================================

-- Permissions (action-based)
CREATE TABLE IF NOT EXISTS permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  module text,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Roles
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_system boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Role-Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(role_id, permission_id)
);

-- User-Role mapping (user_id = auth user id or local user id)
CREATE TABLE IF NOT EXISTS user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, role_id)
);

-- Workflow steps (for approval chains)
CREATE TABLE IF NOT EXISTS workflow_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_code text NOT NULL,
  step_order integer NOT NULL,
  step_name text NOT NULL,
  required_permission_code text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(workflow_code, step_order)
);

-- Workflow-Permission (which permission allows transition)
CREATE TABLE IF NOT EXISTS workflow_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_code text NOT NULL,
  step_order integer NOT NULL,
  permission_code text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);

-- Seed permissions (enterprise actions)
INSERT INTO permissions (code, name, module, description) VALUES
  ('PR_CREATE', 'Create Purchase Request', 'Inventory', 'Create new PR'),
  ('PR_APPROVE', 'Approve Purchase Request', 'Inventory', 'Approve PR'),
  ('PO_CREATE', 'Create Purchase Order', 'Inventory', 'Create PO'),
  ('PO_APPROVE', 'Approve Purchase Order', 'Inventory', 'Approve PO'),
  ('GRN_POST', 'Post GRN', 'Inventory', 'Post Goods Receipt'),
  ('PUR_CREATE', 'Create Purchasing Invoice', 'Finance', 'Create PUR / MIRO'),
  ('PUR_APPROVE', 'Approve Purchasing Invoice', 'Finance', 'Approve PUR'),
  ('PAYMENT_POST', 'Post Payment', 'Finance', 'Post manual payment'),
  ('PAYMENT_APPROVE', 'Approve Payment', 'Finance', 'Approve payment'),
  ('AP_VIEW', 'View Accounts Payable', 'Finance', 'View AP'),
  ('CONFIG_PAYMENT', 'Configure Payment Rules', 'Finance', 'ATM/Bank/Rules config')
ON CONFLICT (code) DO NOTHING;

-- Seed default roles
INSERT INTO roles (code, name, description, is_system) VALUES
  ('ADMIN', 'Administrator', 'Full access', true),
  ('FINANCE_MANAGER', 'Finance Manager', 'Finance + approvals', true),
  ('FINANCE_USER', 'Finance User', 'Finance operations', true),
  ('PROCUREMENT', 'Procurement', 'PR, PO, GRN', true)
ON CONFLICT (code) DO NOTHING;

-- Admin gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'ADMIN'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Finance Manager: PUR, Payment, AP, Config
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'FINANCE_MANAGER' AND p.code IN ('PUR_CREATE', 'PUR_APPROVE', 'PAYMENT_POST', 'PAYMENT_APPROVE', 'AP_VIEW', 'CONFIG_PAYMENT')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Finance User: PUR create, Payment post, AP view
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'FINANCE_USER' AND p.code IN ('PUR_CREATE', 'PAYMENT_POST', 'AP_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Procurement: PR, PO, GRN
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'PROCUREMENT' AND p.code IN ('PR_CREATE', 'PR_APPROVE', 'PO_CREATE', 'PO_APPROVE', 'GRN_POST')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Workflow steps (example: PUR approval)
INSERT INTO workflow_steps (workflow_code, step_order, step_name, required_permission_code) VALUES
  ('PUR_APPROVAL', 1, 'Submit', 'PUR_CREATE'),
  ('PUR_APPROVAL', 2, 'Approve', 'PUR_APPROVE')
ON CONFLICT (workflow_code, step_order) DO NOTHING;

-- Helper: get user permission codes (for UI/server checks)
CREATE OR REPLACE FUNCTION fn_user_has_permission(p_user_id text, p_permission_code text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN role_permissions rp ON rp.role_id = ur.role_id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = p_user_id AND p.code = p_permission_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RLS for new tables
-- ============================================================================
ALTER TABLE finance_payment_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_permissions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Allow all finance_payment_rules" ON finance_payment_rules;
  CREATE POLICY "Allow all finance_payment_rules" ON finance_payment_rules FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all finance_payments" ON finance_payments;
  CREATE POLICY "Allow all finance_payments" ON finance_payments FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all permissions" ON permissions;
  CREATE POLICY "Allow all permissions" ON permissions FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all roles" ON roles;
  CREATE POLICY "Allow all roles" ON roles FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all role_permissions" ON role_permissions;
  CREATE POLICY "Allow all role_permissions" ON role_permissions FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all user_roles" ON user_roles;
  CREATE POLICY "Allow all user_roles" ON user_roles FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all workflow_steps" ON workflow_steps;
  CREATE POLICY "Allow all workflow_steps" ON workflow_steps FOR ALL USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS "Allow all workflow_permissions" ON workflow_permissions;
  CREATE POLICY "Allow all workflow_permissions" ON workflow_permissions FOR ALL USING (true) WITH CHECK (true);
END $$;
