# 🔐 PERMISSION MATRIX REPORT — Step 2.7

**Date:** 2026-02-19 15:10 AST | **Status: ✅ ALL ROLES ACTIVE**

---

## Critical Issues Fixed

| Issue | Before | After |
|-------|--------|-------|
| `role_permissions` FK | → `_deprecated_permissions_master` ❌ | → `permissions` ✅ |
| `fn_user_has_permission` | JOINed to `permissions_master` (broken) | JOINs to `permissions` ✅ |
| Admin bypass | Hardcoded `role_code = 'ADMIN'` | Uses `is_super_admin` flag ✅ |
| Non-admin permissions | BROKEN (0 for all roles) | WORKING (9-37 per role) ✅ |
| `fn_user_has_permission_with_location` | Used old table name | Uses `branch_access` ✅ |

---

## Permission Count Per Role

| Role | Permissions | Access Level |
|------|:-----------:|:------------:|
| **ADMIN** | 49 (ALL) + `is_super_admin=true` | 🔴 FULL SYSTEM |
| **MANAGER** | 37 | 🟠 Broad Operations |
| **INVENTORY_MANAGER** | 24 | 🟡 Inventory + Logistics |
| **LOGISTICS_MANAGER** | 20 | 🟡 Logistics Chain |
| **WAREHOUSE_MANAGER** | 17 | 🟡 Warehouse Ops |
| **FINANCE** | 16 | 🟡 Finance + AP |
| **PROCUREMENT** | 15 | 🟡 Purchasing |
| **AUDITOR** | 15 | 🔵 Read + Audit |
| **BRANCH_MANAGER** | 11 | 🟢 Branch Ops |
| **SUPERVISOR** | 11 | 🟢 View + Limited |
| **DRIVER** | 9 | 🟢 Logistics Only |
| **USER** | 6 | ⚪ Minimal |

**Total role_permissions: 230** (was 113 ADMIN-only before)

---

## RPC Test Results

### DRIVER (Ajay)

| Permission | Expected | Result |
|------------|:--------:|:------:|
| `TRANSFER_DRIVE` | ✅ true | ✅ true |
| `LOGISTICS_VIEW` | ✅ true | ✅ true |
| `TO_VIEW` | ✅ true | ✅ true |
| `PO_CREATE` | ❌ false | ❌ false |
| `USER_MANAGE` | ❌ false | ❌ false |

### MANAGER (Abu Yasin)

| Permission | Expected | Result |
|------------|:--------:|:------:|
| `PO_CREATE` | ✅ true | ✅ true |
| `PR_APPROVE` | ✅ true | ✅ true |
| `LOGISTICS_MANAGE` | ✅ true | ✅ true |
| `USER_MANAGE` | ❌ false | ❌ false |

### PROCUREMENT (Ahmed Husseiny)

| Permission | Expected | Result |
|------------|:--------:|:------:|
| `PO_CREATE` | ✅ true | ✅ true |
| `GRN_POST` | ✅ true | ✅ true |
| `TRANSFER_DRIVE` | ❌ false | ❌ false |

### ADMIN (Ali — Super Admin)

| Permission | Expected | Result |
|------------|:--------:|:------:|
| `PO_CREATE` | ✅ true | ✅ true |
| `USER_MANAGE` | ✅ true | ✅ true |
| `TRANSFER_DRIVE` | ✅ true | ✅ true |
| `NONEXISTENT_PERM` | ✅ true (super) | ✅ true |

---

## Detailed Permission Matrix

### DRIVER (9 permissions)

```
BRANCH_RECEIVE, BRANCH_VIEW, LOGISTICS_VIEW, TRANSFER_DRIVE,
TRANSFER_RECEIVE, TO_VIEW, WAREHOUSE_VIEW, inventory_view,
transfer_receive
```

### USER (6 permissions)

```
BRANCH_VIEW, LOGISTICS_VIEW, PR_CREATE, TO_VIEW,
WAREHOUSE_VIEW, inventory_view
```

### BRANCH_MANAGER (11 permissions)

```
BRANCH_MANAGE, BRANCH_RECEIVE, BRANCH_VIEW, LOGISTICS_VIEW,
PR_CREATE, REPORTS_VIEW, TO_VIEW, TRANSFER_RECEIVE,
WAREHOUSE_VIEW, inventory_view, transfer_receive
```

### SUPERVISOR (11 permissions)

```
BRANCH_VIEW, LOGISTICS_VIEW, PR_APPROVE, PR_CREATE,
REPORTS_VIEW, TO_VIEW, TRANSFER_PICK, WAREHOUSE_VIEW,
inventory_edit, inventory_view, user_management_view
```

### PROCUREMENT (15 permissions)

```
AP_VIEW, BRANCH_VIEW, GRN_POST, LOGISTICS_VIEW, PO_APPROVE,
PO_CREATE, PR_APPROVE, PR_CREATE, PUR_APPROVE, PUR_CREATE,
REPORTS_VIEW, TO_VIEW, WAREHOUSE_VIEW, finance_view,
inventory_view
```

### AUDITOR (15 permissions)

```
AP_VIEW, AUDIT_EXPORT, AUDIT_REPORTS, AUDIT_VIEW, BRANCH_VIEW,
CONFIG_VIEW, LOGISTICS_VIEW, REPORTS_VIEW, TO_VIEW,
USER_VIEW, WAREHOUSE_VIEW, finance_view, finance_view_reports,
inventory_view, user_management_view
```

### FINANCE (16 permissions)

```
AP_VIEW, AUDIT_VIEW, CONFIG_PAYMENT, GRN_POST, PAYMENT_APPROVE,
PAYMENT_POST, PO_APPROVE, PO_CREATE, PUR_APPROVE, PUR_CREATE,
REPORTS_VIEW, finance_payment_approve, finance_payment_create,
finance_view, finance_view_reports, inventory_view
```

### WAREHOUSE_MANAGER (17 permissions)

```
BRANCH_RECEIVE, BRANCH_VIEW, GRN_POST, LOGISTICS_VIEW,
REPORTS_VIEW, TO_VIEW, TRANSFER_DISPATCH, TRANSFER_PICK,
TRANSFER_RECEIVE, WAREHOUSE_DISPATCH, WAREHOUSE_INVENTORY,
WAREHOUSE_VIEW, inventory_adjust, inventory_edit,
inventory_view, transfer_dispatch, transfer_receive
```

### LOGISTICS_MANAGER (20 permissions)

```
BRANCH_RECEIVE, BRANCH_VIEW, LOGISTICS_MANAGE, LOGISTICS_VIEW,
REPORTS_VIEW, TO_APPROVE, TO_CREATE, TO_VIEW, TRANSFER_DISPATCH,
TRANSFER_DRIVE, TRANSFER_PICK, TRANSFER_RECEIVE,
WAREHOUSE_DISPATCH, WAREHOUSE_VIEW, inventory_transfer,
inventory_view, transfer_approve, transfer_create,
transfer_dispatch, transfer_receive
```

### INVENTORY_MANAGER (24 permissions)

```
BRANCH_MANAGE, BRANCH_RECEIVE, BRANCH_VIEW, GRN_POST,
LOGISTICS_VIEW, REPORTS_VIEW, TO_APPROVE, TO_CREATE, TO_VIEW,
TRANSFER_DISPATCH, TRANSFER_PICK, TRANSFER_RECEIVE,
WAREHOUSE_DISPATCH, WAREHOUSE_INVENTORY, WAREHOUSE_VIEW,
inventory_adjust, inventory_create, inventory_delete,
inventory_edit, inventory_transfer, inventory_view,
transfer_create, transfer_dispatch, transfer_receive
```

### MANAGER (37 permissions)

```
AP_VIEW, AUDIT_VIEW, BRANCH_MANAGE, BRANCH_RECEIVE, BRANCH_VIEW,
GRN_POST, LOGISTICS_MANAGE, LOGISTICS_VIEW, PO_APPROVE,
PO_CREATE, PR_APPROVE, PR_CREATE, PUR_APPROVE, PUR_CREATE,
REPORTS_VIEW, TO_APPROVE, TO_CREATE, TO_VIEW, TRANSFER_DISPATCH,
TRANSFER_PICK, TRANSFER_RECEIVE, USER_VIEW, WAREHOUSE_DISPATCH,
WAREHOUSE_INVENTORY, WAREHOUSE_VIEW, finance_view,
finance_view_reports, inventory_adjust, inventory_create,
inventory_edit, inventory_transfer, inventory_view,
transfer_approve, transfer_create, transfer_dispatch,
transfer_receive, user_management_view
```

### ADMIN (49 = ALL permissions + is_super_admin flag)

All permissions granted explicitly. `is_super_admin=true` also bypasses any check.

---

## Architecture Changes Made

### fn_user_has_permission (REWRITTEN)

```
1. Check is_super_admin flag (NOT hardcoded role_code)
2. JOIN user_roles → role_permissions → permissions (active table)
3. Match by p.code = permission_code
```

### fn_user_has_permission_with_location (REWRITTEN)

```
1. Call fn_user_has_permission first
2. Super admin → all locations
3. Check branch_access table (replaces empty location tables)
```

### role_permissions FK

```
Before: REFERENCES _deprecated_permissions_master(id)
After:  REFERENCES permissions(id) ON DELETE CASCADE
```
