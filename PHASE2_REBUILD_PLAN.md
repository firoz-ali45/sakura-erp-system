# SAKURA ERP — PHASE 2: FOUNDATION REBUILD PLAN

## Date: 2026-02-19 | Mode: SAP-Level Architecture

---

# ═══════════════════════════════════════════

# 1. NEW CLEAN ERP MODULE STRUCTURE

# ═══════════════════════════════════════════

```
SAKURA ERP
├── CORE (tenant, company, branch, warehouse, settings)
├── IAM (users, roles, permissions, sessions, audit)
├── MASTER DATA (items, categories, suppliers, departments, UOM)
├── PROCUREMENT (PR → PO → GRN → Invoice)
├── INVENTORY (stock ledger, batches, locations, adjustments)
├── LOGISTICS (transfer orders, dispatch, receipt, drivers)
├── FINANCE (GL journal, AP, AR, payments, chart of accounts)
├── PRODUCTION (BOM, work orders, consumption) [FUTURE]
├── REPORTING (views, dashboards, exports)
└── AI LAYER (forecasting, anomaly detection) [FUTURE]
```

---

# ═══════════════════════════════════════════

# 2. UNIVERSAL TABLE STANDARDS

# ═══════════════════════════════════════════

Every table MUST have these columns:

```sql
-- MULTI-TENANT (on every business table, NOT on system tables like tenants itself)
tenant_id       UUID NOT NULL REFERENCES tenants(id)

-- AUDIT COLUMNS
created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
created_by      UUID NOT NULL REFERENCES users(id)
updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
updated_by      UUID REFERENCES users(id)

-- SOFT DELETE
is_deleted      BOOLEAN NOT NULL DEFAULT false
deleted_at      TIMESTAMPTZ
deleted_by      UUID REFERENCES users(id)

-- OPTIMISTIC CONCURRENCY
version         INTEGER NOT NULL DEFAULT 1
```

Exception: Immutable tables (stock_ledger, audit_logs) have NO update/delete columns.

---

# ═══════════════════════════════════════════

# 3. FINAL TABLE ARCHITECTURE

# ═══════════════════════════════════════════

## MODULE: CORE

### `tenants`

Primary multi-tenant root. One row per SaaS customer.

```
id              UUID PK
tenant_code     TEXT UNIQUE NOT NULL    -- e.g. 'SAKURA', 'ACME'
tenant_name     TEXT NOT NULL
subscription    TEXT DEFAULT 'trial'    -- trial/starter/pro/enterprise
is_active       BOOLEAN DEFAULT true
created_at      TIMESTAMPTZ DEFAULT now()
settings        JSONB DEFAULT '{}'      -- tenant-level config
```

### `companies`

Legal entities under a tenant.

```
id              UUID PK
tenant_id       UUID FK → tenants
company_code    TEXT NOT NULL            -- e.g. 'C01'
company_name    TEXT NOT NULL
tax_id          TEXT
currency        TEXT DEFAULT 'SAR'
fiscal_year_start INTEGER DEFAULT 1     -- month (1=Jan)
is_active       BOOLEAN DEFAULT true
+ audit columns
UNIQUE(tenant_id, company_code)
```

### `branches`

Physical locations (warehouse or store).

```
id              UUID PK
tenant_id       UUID FK → tenants
company_id      UUID FK → companies
branch_code     TEXT NOT NULL            -- e.g. 'W01', 'B01'
branch_name     TEXT NOT NULL
branch_type     TEXT CHECK (warehouse/branch/factory)
address         TEXT
allow_grn       BOOLEAN DEFAULT true
allow_transfer  BOOLEAN DEFAULT true
allow_pos       BOOLEAN DEFAULT false
allow_production BOOLEAN DEFAULT false
is_active       BOOLEAN DEFAULT true
+ audit columns
UNIQUE(tenant_id, branch_code)
```

> NOTE: This REPLACES current `inventory_locations` table.

---

## MODULE: IAM (Identity & Access Management)

### `users` (CLEANED)

```
id              UUID PK
tenant_id       UUID FK → tenants
email           TEXT NOT NULL
name            TEXT NOT NULL
phone           TEXT
employee_id     TEXT
department_id   UUID FK → departments
status          TEXT CHECK (active/inactive/suspended)
password_hash   TEXT
-- REMOVE: legacy 'role' column
-- REMOVE: permissions JSONB column
-- REMOVE: biometric columns (move to separate table)
+ audit columns (except created_by = nullable for bootstrap)
UNIQUE(tenant_id, email)
```

### `roles` (KEEP — already good)

```
id              UUID PK
tenant_id       UUID FK → tenants
role_code       TEXT NOT NULL
role_name       TEXT NOT NULL
description     TEXT
is_active       BOOLEAN DEFAULT true
is_super_admin  BOOLEAN DEFAULT false
+ audit columns
UNIQUE(tenant_id, role_code)
```

### `user_roles` (KEEP — populate fully)

```
id              UUID PK
tenant_id       UUID FK → tenants
user_id         UUID FK → users NOT NULL
role_id         UUID FK → roles NOT NULL
is_primary      BOOLEAN DEFAULT false
+ audit columns (created_by = assigned_by)
UNIQUE(user_id, role_id)
```

### `permissions` (KEEP — single table)

```
id              UUID PK
code            TEXT UNIQUE NOT NULL     -- e.g. 'inventory.grn.create'
name            TEXT NOT NULL
module          TEXT                     -- e.g. 'inventory'
action          TEXT                     -- e.g. 'create'
description     TEXT
created_at      TIMESTAMPTZ DEFAULT now()
```

> DELETE: `permissions_master` (duplicate)

### `role_permissions` (KEEP)

```
id              UUID PK
role_id         UUID FK → roles
permission_id   UUID FK → permissions
created_at      TIMESTAMPTZ DEFAULT now()
UNIQUE(role_id, permission_id)
```

> DELETE: `role_permissions_master` (duplicate)

### `branch_access` (REPLACES role_location_access + user_location_access)

```
id              UUID PK
tenant_id       UUID FK → tenants
user_id         UUID FK → users
branch_id       UUID FK → branches
access_level    TEXT CHECK (full/read_only/none)
+ audit columns
UNIQUE(user_id, branch_id)
```

### `audit_trail` (REPLACES audit_logs + erp_audit_logs)

```
id              UUID PK
tenant_id       UUID FK → tenants
user_id         UUID FK → users
action          TEXT NOT NULL              -- CREATE/UPDATE/DELETE/STATUS_CHANGE/LOGIN
entity_type     TEXT NOT NULL              -- 'grn', 'batch', 'po', 'transfer', etc.
entity_id       TEXT                       -- UUID or number of affected record
old_values      JSONB
new_values      JSONB
ip_address      INET
user_agent      TEXT
created_at      TIMESTAMPTZ DEFAULT now()  -- IMMUTABLE: no update columns
```

> DELETE: `audit_logs`, `erp_audit_logs`, `user_activities`, `user_activity_logs`

### `login_sessions` (REPLACES user_sessions + login_sessions)

```
id              UUID PK
tenant_id       UUID FK → tenants
user_id         UUID FK → users
session_token   TEXT UNIQUE
ip_address      TEXT
user_agent      TEXT
is_active       BOOLEAN DEFAULT true
created_at      TIMESTAMPTZ DEFAULT now()
expires_at      TIMESTAMPTZ NOT NULL
last_activity   TIMESTAMPTZ DEFAULT now()
```

> DELETE: `user_sessions` (duplicate)

---

## MODULE: MASTER DATA

### `items` (RENAME inventory_items)

```
id              UUID PK
tenant_id       UUID FK → tenants
sku             TEXT NOT NULL
name            TEXT NOT NULL
name_localized  TEXT
category_id     UUID FK → categories
storage_unit    TEXT NOT NULL
ingredient_unit TEXT NOT NULL
storage_to_ingredient NUMERIC DEFAULT 1
costing_method  TEXT CHECK (weighted_avg/fifo/standard)
standard_cost   NUMERIC DEFAULT 0
barcode         TEXT
min_level       NUMERIC
max_level       NUMERIC
par_level       NUMERIC
+ audit columns
UNIQUE(tenant_id, sku)
```

### `suppliers` (KEEP — add tenant_id)

Add `tenant_id`, standardize `created_by` to UUID. Otherwise structure is good.

### `departments` (KEEP — add tenant_id)

Add `tenant_id`. Otherwise good.

---

## MODULE: PROCUREMENT

### `purchase_requests` — ✅ KEEP AS-IS (best table in system)

Only changes: add `tenant_id`, ensure all _by columns are UUID.

### `purchase_request_items` — ✅ KEEP AS-IS

Only change: add `tenant_id`.

### `purchase_orders` — FIX `created_by` type

```
Change: created_by BIGINT → UUID FK → users
Add: tenant_id, updated_by
```

### `purchase_order_items` — ADD missing audit columns

```
Add: updated_at, updated_by, tenant_id
```

### `grn_inspections` — KEEP, add tenant_id

Already well-structured. Add `tenant_id`, `updated_by`.

### `grn_inspection_items` — ADD missing audit columns

```
Add: updated_at, updated_by, tenant_id
```

### `purchasing_invoices` — FIX created_by to UUID

```
Change: created_by TEXT → UUID
Add: tenant_id, updated_by
```

---

## MODULE: INVENTORY

### `batches` (SINGLE TABLE — replaces grn_batches + inventory_batches + stock_batches)

```
id                  UUID PK
tenant_id           UUID FK → tenants
item_id             UUID FK → items NOT NULL
branch_id           UUID FK → branches NOT NULL
batch_number        TEXT NOT NULL
vendor_batch_number TEXT
grn_id              UUID FK → grn_inspections
expiry_date         DATE
manufacture_date    DATE
quantity_received   NUMERIC NOT NULL DEFAULT 0
quantity_remaining  NUMERIC NOT NULL DEFAULT 0     -- TRIGGER MAINTAINED
unit_cost           NUMERIC DEFAULT 0
storage_location    TEXT
qc_status           TEXT CHECK (pending/pass/hold/fail) DEFAULT 'pending'
qc_checked_by       UUID FK → users
qc_checked_at       TIMESTAMPTZ
qc_data             JSONB
+ audit columns
UNIQUE(tenant_id, batch_number)
```

**TRIGGER:** On INSERT → `quantity_remaining = quantity_received`
**TRIGGER:** On stock_ledger INSERT with batch_id → recalculate remaining from ledger

> DELETE: `grn_batches`, `stock_batches`
> MIGRATE DATA: `inventory_batches` → `batches`

### `stock_ledger` (KEEP inventory_stock_ledger — rename)

```
id              UUID PK
tenant_id       UUID FK → tenants
item_id         UUID FK → items NOT NULL
branch_id       UUID FK → branches NOT NULL
batch_id        UUID FK → batches
movement_type   ENUM (same as current)
reference_type  ENUM (same as current)
reference_id    TEXT
qty_in          NUMERIC DEFAULT 0
qty_out         NUMERIC DEFAULT 0
unit_cost       NUMERIC DEFAULT 0
total_cost      NUMERIC DEFAULT 0
notes           TEXT
created_by      UUID FK → users NOT NULL
created_at      TIMESTAMPTZ DEFAULT now()
-- IMMUTABLE: No update/delete columns
```

> DELETE: `inventory_stock_ledger_legacy`

### `batch_sequences` (CONSOLIDATE all sequence tables)

```
id              UUID PK
tenant_id       UUID FK → tenants
sequence_type   TEXT CHECK (grn_batch/item_batch/daily_batch)
scope_key       TEXT NOT NULL    -- item_id or grn_id or date
last_seq        INTEGER DEFAULT 0
updated_at      TIMESTAMPTZ DEFAULT now()
UNIQUE(tenant_id, sequence_type, scope_key)
```

> DELETE: `grn_batch_sequence`, `item_batch_sequence`, `batch_daily_sequence`

---

## MODULE: LOGISTICS

### `transfer_orders` — KEEP (good design)

Add: `tenant_id`, change `requested_by` TEXT → UUID.

### `transfer_order_items` — KEEP

Add: `tenant_id`.

### `stock_transfers` — KEEP

Add: `tenant_id`, change `created_by` TEXT → UUID.

### `transfer_dispatches` / `transfer_receipts` — KEEP

Add: `tenant_id`, `updated_at`.

---

## MODULE: DOCUMENT FLOW

### `document_flow` (SINGLE TABLE — keep the richer one)

```
id                  UUID PK
tenant_id           UUID FK → tenants
source_type         TEXT NOT NULL   -- PR/PO/GRN/INVOICE/TRANSFER
source_id           TEXT NOT NULL
source_number       TEXT
target_type         TEXT NOT NULL
target_id           TEXT NOT NULL
target_number       TEXT
flow_type           TEXT            -- conversion/receipt/payment
item_id             UUID FK → items
qty                 NUMERIC
status              TEXT
root_document_id    UUID            -- chain root
created_at          TIMESTAMPTZ DEFAULT now()
UNIQUE(source_type, source_id, target_type, target_id)
```

> DELETE: `doc_graph` (duplicate)

### `status_history` (NEW — universal for all entities)

```
id              UUID PK
tenant_id       UUID FK → tenants
entity_type     TEXT NOT NULL   -- grn/po/invoice/transfer/batch
entity_id       TEXT NOT NULL
previous_status TEXT
new_status      TEXT NOT NULL
changed_by      UUID FK → users NOT NULL
change_reason   TEXT
metadata        JSONB
created_at      TIMESTAMPTZ DEFAULT now()
```

> This replaces `pr_status_history` and adds coverage for GRN, PO, Invoice, Transfer.

---

# ═══════════════════════════════════════════

# 4. WHAT TO MIGRATE / DELETE / REBUILD

# ═══════════════════════════════════════════

## 🔴 DELETE (13 tables/objects)

| # | Table | Reason |
|---|-------|--------|
| 1 | `permissions_master` | Duplicate of `permissions` |
| 2 | `role_permissions_master` | Duplicate of `role_permissions` |
| 3 | `inventory_stock_ledger_legacy` | Replaced by `inventory_stock_ledger` |
| 4 | `grn_batches` | Merge into unified `batches` |
| 5 | `stock_batches` | Merge into unified `batches` |
| 6 | `doc_graph` | Duplicate of `document_flow` |
| 7 | `erp_audit_logs` | Merge into `audit_trail` |
| 8 | `user_activities` | Merge into `audit_trail` |
| 9 | `user_activity_logs` | Merge into `audit_trail` |
| 10 | `user_sessions` | Merge into `login_sessions` |
| 11 | `grn_batch_sequence` | Merge into `batch_sequences` |
| 12 | `item_batch_sequence` | Merge into `batch_sequences` |
| 13 | `batch_daily_sequence` | Merge into `batch_sequences` |

## 🔄 MIGRATE (data preservation)

| From | To | Data Action |
|------|----|-------------|
| `inventory_batches` (20 rows) | `batches` | Copy all, add branch_id |
| `grn_batches` (4 rows) | `batches` | Merge, drop ghost columns |
| `stock_batches` (8 rows) | `batches` | Merge if not duplicated |
| `inventory_locations` (4 rows) | `branches` | Map location → branch |
| `users.role` (legacy) | `user_roles` | Create missing assignments |
| `audit_logs` (489 rows) | `audit_trail` | Copy |
| `po.created_by` BIGINT | UUID | Map bigint → user UUID |
| `pr_status_history` | `status_history` | Copy, add entity_type='pr' |

## 🏗️ REBUILD (new tables)

| Table | Purpose |
|-------|---------|
| `tenants` | Multi-tenant root |
| `companies` | Legal entities |
| `branches` | Replaces inventory_locations |
| `batches` | Single batch table |
| `batch_sequences` | Unified sequence |
| `audit_trail` | Universal audit |
| `status_history` | Universal status tracking |
| `branch_access` | User-branch ACL |

## 🧹 COLUMN CLEANUP

| Table | Drop Columns | Why |
|-------|-------------|-----|
| `grn_batches` (before delete) | `batchid`, `qcdata`, `qccheckedat`, `createdby` | Ghost duplicates |
| `users` | `role`, `permissions` (JSONB) | Legacy dual system |
| `users` | `otp_code`, `otp_expiry`, `verification_token` | Move to separate auth table |

---

# ═══════════════════════════════════════════

# 5. RELATIONSHIP DIAGRAM LOGIC

# ═══════════════════════════════════════════

```
tenants ─┬─► companies ─┬─► branches
         │               │
         ├─► users ──────┼─► user_roles ──► roles ──► role_permissions ──► permissions
         │               │
         │               ├─► branch_access
         │               │
         ├─► items ──────┼─► batches ──► stock_ledger
         │               │
         ├─► suppliers   │
         │               │
         ├─► purchase_requests ──► purchase_request_items
         │       │
         │       ▼
         ├─► purchase_orders ──► purchase_order_items
         │       │
         │       ▼
         ├─► grn_inspections ──► grn_inspection_items ──► batches
         │       │
         │       ▼
         ├─► purchasing_invoices ──► purchasing_invoice_items
         │
         ├─► transfer_orders ──► transfer_order_items
         │       │
         │       ▼
         ├─► stock_transfers ──► stock_transfer_items
         │
         ├─► document_flow (links ALL above)
         ├─► status_history (tracks ALL above)
         └─► audit_trail (logs ALL above)
```

---

# ═══════════════════════════════════════════

# 6. REBUILD ORDER (step by step)

# ═══════════════════════════════════════════

### STEP 1: Foundation (no data risk)

```
1.1  CREATE tenants table, INSERT single tenant for Sakura
1.2  CREATE companies table, INSERT single company
1.3  CREATE branches table from inventory_locations data
1.4  ADD tenant_id to ALL existing tables (nullable first)
1.5  BACKFILL tenant_id with Sakura tenant UUID
1.6  ALTER tenant_id to NOT NULL
```

### STEP 2: IAM Cleanup (critical path)

```
2.1  Migrate ALL 7 users into user_roles (5 currently missing)
2.2  DROP users.role column
2.3  DROP users.permissions JSONB column
2.4  DROP permissions_master, role_permissions_master tables
2.5  CREATE branch_access table
2.6  CREATE audit_trail table (unified)
2.7  MIGRATE audit_logs → audit_trail
2.8  DROP erp_audit_logs, user_activities, user_activity_logs
```

### STEP 3: Batch Unification (highest bug density)

```
3.1  CREATE unified batches table
3.2  MIGRATE inventory_batches → batches
3.3  MIGRATE grn_batches → batches (skip ghost columns)
3.4  MIGRATE stock_batches → batches (deduplicate)
3.5  CREATE trigger: remaining_qty = quantity_received on INSERT
3.6  CREATE trigger: recalc remaining on stock_ledger INSERT
3.7  UPDATE FK references in stock_ledger
3.8  DROP grn_batches, stock_batches, inventory_batches
3.9  CREATE batch_sequences (unified)
3.10 DROP old sequence tables
```

### STEP 4: Type Unification

```
4.1  ALTER purchase_orders.created_by BIGINT → UUID
4.2  ALTER purchasing_invoices.created_by TEXT → UUID
4.3  ALTER stock_transfers.created_by TEXT → UUID
4.4  ALTER transfer_orders.requested_by TEXT → UUID
4.5  ALTER stock_ledger.created_by TEXT → UUID
4.6  ADD updated_by UUID to all tables missing it
```

### STEP 5: Document Flow Cleanup

```
5.1  CREATE status_history table (universal)
5.2  MIGRATE pr_status_history → status_history
5.3  DROP doc_graph (keep document_flow)
5.4  POPULATE po_receipt_history from existing GRN data
5.5  DROP inventory_stock_ledger_legacy
```

### STEP 6: Frontend Alignment

```
6.1  Split supabase.js (170KB) into domain services
6.2  Create DTO mapper layer (DB columns → frontend models)
6.3  Remove all camelCase/snake_case guessing
6.4  Update auth store to use ONLY user_roles (no legacy)
6.5  Update all batch operations to use unified batches table
```

---

# ═══════════════════════════════════════════

# 7. RISK ANALYSIS

# ═══════════════════════════════════════════

| Step | Risk Level | Mitigation |
|------|:----------:|------------|
| 1. Tenant foundation | 🟢 LOW | Additive only, no data loss |
| 2. IAM cleanup | 🟡 MEDIUM | User role migration must map correctly |
| 3. Batch unification | 🔴 HIGH | 3 tables → 1, FK rewiring, trigger creation |
| 4. Type unification | 🟡 MEDIUM | Must map BIGINT/TEXT → UUID lookup |
| 5. Doc flow cleanup | 🟢 LOW | Mostly dropping duplicates |
| 6. Frontend split | 🟡 MEDIUM | Large refactor, must not break UI |

### BACKUP STRATEGY

Before ANY migration step:

1. pg_dump full database
2. Record row counts for all affected tables
3. Verify count after migration
4. Keep old tables renamed with `_deprecated_` prefix for 30 days

---

# ═══════════════════════════════════════════

# AWAITING APPROVAL TO BEGIN CODING

# ═══════════════════════════════════════════

Say: "START STEP 1" to begin foundation tables
Or specify any step to start with.

Each step will be a separate Supabase migration.
Each migration is reversible.
No data will be deleted without backup verification.
