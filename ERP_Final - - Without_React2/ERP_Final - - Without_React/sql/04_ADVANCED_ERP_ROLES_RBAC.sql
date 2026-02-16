-- ============================================================================
-- ADVANCED ERP ROLES & PERMISSIONS (RBAC)
-- Adds: Driver, Warehouse Manager, Branch Manager, Logistics Manager,
--       Finance, Auditor, and other enterprise roles.
-- Run after: 03_HARD_RESET_FINANCE_RBAC.sql
-- ============================================================================

-- ============================================================================
-- PART 1: NEW PERMISSIONS (Transfer, Warehouse, Branch, Logistics, Audit)
-- ============================================================================

INSERT INTO permissions (code, name, module, description) VALUES
  -- Transfer / Logistics
  ('TO_CREATE', 'Create Transfer Order', 'Inventory', 'Create new TO'),
  ('TO_APPROVE', 'Approve Transfer Order', 'Inventory', 'Approve TO'),
  ('TO_VIEW', 'View Transfer Orders', 'Inventory', 'View TO list and details'),
  ('TRANSFER_DISPATCH', 'Dispatch Stock Transfer', 'Logistics', 'Dispatch transfer to driver'),
  ('TRANSFER_RECEIVE', 'Receive Stock Transfer', 'Logistics', 'Receive items at destination'),
  ('TRANSFER_PICK', 'Pick Stock Transfer', 'Logistics', 'Pick items for transfer'),
  ('TRANSFER_DRIVE', 'Driver: Mark In Transit / Arrived', 'Logistics', 'Driver handover and status updates'),
  ('LOGISTICS_VIEW', 'View Logistics', 'Logistics', 'View transfers, drivers, timeline'),
  ('LOGISTICS_MANAGE', 'Manage Logistics', 'Logistics', 'Full logistics operations'),
  -- Warehouse
  ('WAREHOUSE_VIEW', 'View Warehouse', 'Inventory', 'View warehouse inventory'),
  ('WAREHOUSE_INVENTORY', 'Manage Warehouse Inventory', 'Inventory', 'Stock adjustments, counts'),
  ('WAREHOUSE_DISPATCH', 'Warehouse Dispatch', 'Inventory', 'Dispatch from source warehouse'),
  -- Branch
  ('BRANCH_VIEW', 'View Branch', 'Inventory', 'View branch inventory'),
  ('BRANCH_RECEIVE', 'Branch Receive', 'Inventory', 'Receive at destination branch'),
  ('BRANCH_MANAGE', 'Manage Branch', 'Inventory', 'Full branch operations'),
  -- Audit
  ('AUDIT_VIEW', 'View Audit Logs', 'Audit', 'View audit trail'),
  ('AUDIT_EXPORT', 'Export Audit Reports', 'Audit', 'Export audit data'),
  ('AUDIT_REPORTS', 'Audit Reports', 'Audit', 'Full audit access'),
  -- User & Config (for managers)
  ('USER_VIEW', 'View Users', 'Admin', 'View user list'),
  ('USER_MANAGE', 'Manage Users', 'Admin', 'Create, edit, assign roles'),
  ('CONFIG_VIEW', 'View Configuration', 'Admin', 'View system config'),
  ('REPORTS_VIEW', 'View Reports', 'Reports', 'Access reports')
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- PART 2: NEW ROLES
-- ============================================================================

INSERT INTO roles (code, name, description, is_system) VALUES
  ('DRIVER', 'Driver', 'Delivery driver: mark in transit, arrived, handover', true),
  ('WAREHOUSE_MANAGER', 'Warehouse Manager', 'Warehouse operations: inventory, dispatch, picking', true),
  ('BRANCH_MANAGER', 'Branch Manager', 'Branch operations: receive, inventory at destination', true),
  ('LOGISTICS_MANAGER', 'Logistics Manager', 'Full logistics: transfers, drivers, tracking', true),
  ('FINANCE', 'Finance', 'Finance operations: PUR, payments, AP (non-approval)', true),
  ('AUDITOR', 'Auditor', 'Read-only audit: logs, reports, export', true),
  ('INVENTORY_MANAGER', 'Inventory Manager', 'Full inventory: PR, PO, GRN, TO, warehouse', true),
  ('PURCHASING_MANAGER', 'Purchasing Manager', 'Procurement: PR, PO, GRN, approvals', true),
  ('SUPERVISOR', 'Supervisor', 'Approval workflows: PR, PO, TO, PUR', true)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- PART 3: ROLE-PERMISSION MAPPING
-- ============================================================================

-- Driver: only transfer drive actions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'DRIVER' AND p.code IN ('TRANSFER_DRIVE', 'LOGISTICS_VIEW', 'TO_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Warehouse Manager: warehouse + dispatch + pick
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'WAREHOUSE_MANAGER' AND p.code IN (
  'WAREHOUSE_VIEW', 'WAREHOUSE_INVENTORY', 'WAREHOUSE_DISPATCH',
  'TRANSFER_PICK', 'TRANSFER_DISPATCH', 'TO_VIEW', 'LOGISTICS_VIEW', 'TO_CREATE'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Branch Manager: branch + receive
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'BRANCH_MANAGER' AND p.code IN (
  'BRANCH_VIEW', 'BRANCH_RECEIVE', 'BRANCH_MANAGE',
  'TRANSFER_RECEIVE', 'TO_VIEW', 'LOGISTICS_VIEW', 'WAREHOUSE_VIEW'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Logistics Manager: full logistics
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'LOGISTICS_MANAGER' AND p.code IN (
  'TO_CREATE', 'TO_APPROVE', 'TO_VIEW',
  'TRANSFER_PICK', 'TRANSFER_DISPATCH', 'TRANSFER_RECEIVE', 'TRANSFER_DRIVE',
  'LOGISTICS_VIEW', 'LOGISTICS_MANAGE',
  'WAREHOUSE_VIEW', 'WAREHOUSE_DISPATCH', 'BRANCH_VIEW', 'BRANCH_RECEIVE'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Finance: PUR, payment, AP (no approval)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'FINANCE' AND p.code IN ('PUR_CREATE', 'PAYMENT_POST', 'AP_VIEW', 'REPORTS_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Auditor: read-only audit
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'AUDITOR' AND p.code IN ('AUDIT_VIEW', 'AUDIT_EXPORT', 'AUDIT_REPORTS', 'REPORTS_VIEW', 'AP_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Inventory Manager: full inventory (PR, PO, GRN, TO, warehouse)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'INVENTORY_MANAGER' AND p.code IN (
  'PR_CREATE', 'PR_APPROVE', 'PO_CREATE', 'PO_APPROVE', 'GRN_POST',
  'TO_CREATE', 'TO_APPROVE', 'TO_VIEW',
  'WAREHOUSE_VIEW', 'WAREHOUSE_INVENTORY', 'WAREHOUSE_DISPATCH',
  'BRANCH_VIEW', 'BRANCH_RECEIVE', 'BRANCH_MANAGE',
  'TRANSFER_PICK', 'TRANSFER_DISPATCH', 'TRANSFER_RECEIVE',
  'LOGISTICS_VIEW', 'LOGISTICS_MANAGE'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Purchasing Manager: procurement + approvals
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'PURCHASING_MANAGER' AND p.code IN (
  'PR_CREATE', 'PR_APPROVE', 'PO_CREATE', 'PO_APPROVE', 'GRN_POST'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Supervisor: approval workflows (PR, PO, TO, PUR)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.code = 'SUPERVISOR' AND p.code IN (
  'PR_APPROVE', 'PO_APPROVE', 'TO_APPROVE', 'PUR_APPROVE', 'PAYMENT_APPROVE',
  'PR_CREATE', 'PO_CREATE', 'TO_VIEW', 'AP_VIEW'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Ensure ADMIN still has all permissions (including new ones)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'ADMIN'
ON CONFLICT (role_id, permission_id) DO NOTHING;
