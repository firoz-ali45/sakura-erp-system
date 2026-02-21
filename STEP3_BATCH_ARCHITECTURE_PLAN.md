# 🏗️ STEP 3 — BATCH & INVENTORY CORE UNIFICATION

## Architecture Plan (Awaiting Approval)

---

## 📊 CURRENT STATE ANALYSIS

### Three Competing Batch Tables

| Table | Rows | PKs Referenced By | Purpose |
|-------|:----:|:-----------------:|---------|
| `grn_batches` | **4** | NONE | GRN receipt tracking |
| `inventory_batches` | **20** | `inventory_stock_ledger.batch_id`, `stock_transfer_items.batch_id` | Inventory master |
| `stock_batches` | **8** | NONE | Stock tracking (duplicate) |

### Data Overlap Analysis

| Comparison | Overlapping IDs |
|------------|:--------------:|
| grn_batches ↔ inventory_batches | 0 (different UUIDs) |
| grn_batches ↔ stock_batches | 0 (different UUIDs) |
| inventory_batches ↔ stock_batches | 0 (different UUIDs) |

**Key Finding:** `stock_batches` appears to be a SHADOW COPY — every GRN creates entries
in BOTH `grn_batches` (4 rows) AND `stock_batches` (8 rows). The `stock_batches` table
has DOUBLE entries (one per grn_batch + one with a different batch_no format).

### FK Dependency Map

```
inventory_batches  ←── inventory_stock_ledger.batch_id  (22 rows with batch)
                   ←── stock_transfer_items.batch_id     (has column)
                   ←── transfer_order_items.batch_id     (has column)

grn_batches        ←── (nothing references this)
stock_batches      ←── (nothing references this)
```

### Column Comparison

| Column | grn_batches | inventory_batches | stock_batches |
|--------|:-----------:|:-----------------:|:------------:|
| id (UUID PK) | ✅ | ✅ | ✅ |
| item_id (FK) | ✅ | ✅ | ✅ |
| grn_id (FK) | ✅ | received_from_grn_id | ✅ |
| batch_number | ✅ | ✅ | batch_no |
| quantity | ✅ (received) | ❌ MISSING | ❌ MISSING |
| qty_received | ❌ | ❌ | ✅ |
| remaining_qty | ❌ | ❌ | ✅ |
| expiry_date | ✅ | ✅ | ✅ |
| manufacture_date | ❌ | ✅ | ❌ |
| supplier_lot_number | ❌ | ✅ | ❌ |
| qc_status | ✅ | ✅ | ❌ |
| qc_data JSONB | ✅ (ghost) | ❌ | ❌ |
| storage_location | ✅ | ❌ | ❌ |
| vendor_batch_number | ✅ | ❌ | ❌ |
| created_by | ✅ (TEXT) | ❌ | ❌ |
| created_at | ✅ | ✅ | ✅ |
| tenant_id | ✅ | ✅ | ✅ |

---

## 🎯 NEW UNIFIED ARCHITECTURE

### `batches` — Single Source of Truth

```sql
CREATE TABLE batches (
    -- Identity
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    batch_number        TEXT NOT NULL,
    
    -- Item & Origin
    item_id             UUID NOT NULL REFERENCES inventory_items(id),
    grn_id              UUID REFERENCES grn_inspections(id),
    supplier_lot_number TEXT,
    vendor_batch_number TEXT,
    
    -- Quantities (SAP MCHB logic)
    qty_received        NUMERIC(15,4) NOT NULL DEFAULT 0,
    qty_consumed        NUMERIC(15,4) NOT NULL DEFAULT 0,
    remaining_qty       NUMERIC(15,4) GENERATED ALWAYS AS (qty_received - qty_consumed) STORED,
    
    -- Quality
    qc_status           TEXT NOT NULL DEFAULT 'pending' 
                        CHECK (qc_status IN ('pending','passed','failed','on_hold','expired')),
    qc_data             JSONB DEFAULT '{}',
    qc_checked_at       TIMESTAMPTZ,
    qc_checked_by       UUID REFERENCES users(id),
    
    -- Dates  
    manufacture_date    DATE,
    expiry_date         DATE,
    
    -- Location
    location_id         UUID REFERENCES branches(id),
    storage_location    TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id),
    is_deleted          BOOLEAN NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    version             INTEGER NOT NULL DEFAULT 1,
    
    -- Constraints
    CONSTRAINT uq_batch_number UNIQUE (tenant_id, batch_number),
    CONSTRAINT chk_qty_positive CHECK (qty_received >= 0 AND qty_consumed >= 0),
    CONSTRAINT chk_consumed_lte_received CHECK (qty_consumed <= qty_received)
);
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `remaining_qty` is **GENERATED (computed)** | Can NEVER drift. Always = received - consumed. |
| `qty_consumed` tracked explicitly | Enables batch consumption tracking (SAP EKBE) |
| `location_id` references `branches` | Batch knows WHERE it physically is |
| `created_by` is UUID FK to `users` | Standardized type — no more TEXT/BIGINT mess |
| Soft delete pattern | `is_deleted` + `deleted_at` + `deleted_by` |
| `version` column | Optimistic concurrency control |

---

## 🔄 MIGRATION STRATEGY

### Phase 3.1: CREATE `batches` table (additive, zero risk)

### Phase 3.2: MIGRATE data from all 3 tables

**Priority order:**

1. `inventory_batches` → `batches` (20 rows) — these are the FK targets
2. `grn_batches` → `batches` (4 rows) — supplement with GRN data
3. `stock_batches` → `batches` (update qty_received/remaining from here)

**Deduplication strategy:**

- `stock_batches` has DOUBLE entries per GRN batch
- Match by `grn_id` + `item_id` + similar `batch_no`/`batch_number`
- Take `qty_received` and `remaining_qty` from `stock_batches`

### Phase 3.3: REWIRE FK references

| Table | Column | Old FK | New FK |
|-------|--------|--------|--------|
| `inventory_stock_ledger` | `batch_id` | → `inventory_batches` | → `batches` |
| `stock_transfer_items` | `batch_id` | → `inventory_batches` | → `batches` |
| `transfer_order_items` | `batch_id` | → `inventory_batches` | → `batches` |

**Strategy:**

- Same IDs from `inventory_batches` will be preserved in `batches`
- Drop old FK → Add new FK (zero data change needed)

### Phase 3.4: CREATE compatibility views

```sql
CREATE VIEW grn_batches_v AS SELECT ... FROM batches WHERE grn_id IS NOT NULL;
CREATE VIEW inventory_batches_v AS SELECT ... FROM batches;
```

### Phase 3.5: DEPRECATE old tables

```sql
ALTER TABLE grn_batches RENAME TO _deprecated_grn_batches;
ALTER TABLE inventory_batches RENAME TO _deprecated_inventory_batches;
ALTER TABLE stock_batches RENAME TO _deprecated_stock_batches;
```

### Phase 3.6: CREATE consumption trigger

When `qty_consumed` changes via a transfer/sale, the `remaining_qty` auto-updates
(because it's a generated column). But we need a trigger to LOG the consumption
in `audit_trail`.

---

## ⚠️ RISK ANALYSIS

| Risk | Level | Mitigation |
|------|:-----:|-----------|
| FK rewire on ledger | 🟡 MED | Ledger trigger must be temporarily disabled for FK change |
| Duplicate batch numbers | 🟢 LOW | Prefix with source: `GRN-xxx`, `INV-xxx` if conflict |
| Frontend reads `grn_batches` | 🔴 HIGH | Create VIEW `grn_batches` as alias → `batches` |
| `remaining_qty` calc correctness | 🟡 MED | Verify ledger SUM matches remaining_qty per batch |
| Transfer items lose batch ref | 🟢 LOW | Same UUIDs preserved — FKs just re-point |

### Frontend Impact Assessment

- `supabase.js` → `saveBatchToSupabase()` writes to `grn_batches` → **NEEDS VIEW/ALIAS**
- `supabase.js` → `updateBatchInSupabase()` updates `grn_batches` → **NEEDS VIEW/ALIAS**
- `supabase.js` → `deleteBatchFromSupabase()` deletes from `grn_batches` → **NEEDS VIEW/ALIAS**
- `GRNDetail.vue` → reads `grn.batches` array → comes from GRN load, not direct table query

**Solution:** Create `grn_batches` as an UPDATABLE VIEW on `batches` table.
Frontend code works unchanged.

---

## 📋 EXECUTION ORDER

| Sub-Step | What | Risk | Reversible |
|----------|------|:----:|:----------:|
| **3.1** | CREATE `batches` table | 🟢 | ✅ DROP TABLE |
| **3.2** | MIGRATE `inventory_batches` → `batches` (20 rows, same IDs) | 🟢 | ✅ TRUNCATE |
| **3.3** | MIGRATE `grn_batches` → `batches` (4 rows) | 🟢 | ✅ DELETE |
| **3.4** | MERGE `stock_batches` qty data into `batches` | 🟡 | ✅ UPDATE |
| **3.5** | REWIRE 3 FKs from `inventory_batches` → `batches` | 🟡 | ✅ RE-FK |
| **3.6** | DEPRECATE old tables (rename) | 🟢 | ✅ RENAME back |
| **3.7** | CREATE `grn_batches` as updatable VIEW | 🟡 | ✅ DROP VIEW |
| **3.8** | VERIFY: remaining_qty, ledger integrity, FK validity | 🟢 | Read-only |

**Total rows affected:** 32 batch records + 3 FK changes + 1 view creation
**Estimated risk:** LOW-MEDIUM (small data set, reversible steps)
**System downtime:** ZERO (all additive until final deprecation)

---

## ✅ APPROVAL REQUIRED

Say **"APPROVED"** to begin Step 3.1 execution.
