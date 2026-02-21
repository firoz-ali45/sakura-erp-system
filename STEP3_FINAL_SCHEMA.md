# 🏗️ STEP 3 — FINAL CORRECTED BATCH SCHEMA

## All 4 Architect Corrections Applied

---

## 1. FINAL `batches` TABLE SCHEMA

```sql
CREATE TABLE batches (
    -- ════════════ IDENTITY ════════════
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_number            TEXT NOT NULL,

    -- ════════════ MULTI-TENANT (Correction #1) ════════════
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    company_id              UUID NOT NULL REFERENCES companies(id),
    branch_id               UUID NOT NULL REFERENCES branches(id),
    warehouse_id            UUID REFERENCES branches(id),       -- nullable, future warehouse zones

    -- ════════════ ITEM & ORIGIN (Correction #2) ════════════
    item_id                 UUID NOT NULL REFERENCES inventory_items(id),
    source_doc_type         TEXT NOT NULL DEFAULT 'GRN'
                            CHECK (source_doc_type IN ('GRN','TRANSFER','PRODUCTION','ADJUSTMENT','RETURN')),
    source_doc_id           UUID,                               -- FK to grn_inspections / transfer_orders / etc
    supplier_id             UUID REFERENCES suppliers(id),      -- Correction #4
    uom                     TEXT,                                -- unit of measure

    -- ════════════ QUANTITIES (Correction #3) ════════════
    -- qty_received: set at GRN time, immutable after posting
    -- remaining_qty: VIEW-DERIVED from ledger, NOT stored here
    -- Batch table = METADATA. Ledger = QUANTITY TRUTH.
    qty_received            NUMERIC(15,4) NOT NULL DEFAULT 0,
    unit_cost               NUMERIC(15,4) NOT NULL DEFAULT 0,

    -- ════════════ QUALITY ════════════
    qc_status               TEXT NOT NULL DEFAULT 'pending'
                            CHECK (qc_status IN ('pending','passed','failed','on_hold','expired')),
    qc_required             BOOLEAN NOT NULL DEFAULT true,      -- Correction #4
    qc_data                 JSONB DEFAULT '{}',
    qc_checked_at           TIMESTAMPTZ,
    qc_checked_by           UUID REFERENCES users(id),

    -- ════════════ DATES & TRACKING (Correction #4) ════════════
    manufacture_date        DATE,
    expiry_date             DATE,
    lot_number              TEXT,                                -- Correction #4
    barcode                 TEXT,                                -- Correction #4
    vendor_batch_number     TEXT,

    -- ════════════ FOOD-SAFE GLOBAL (Correction #4) ════════════
    temperature_required    BOOLEAN NOT NULL DEFAULT false,
    cold_chain_flag         BOOLEAN NOT NULL DEFAULT false,
    storage_location        TEXT,                                -- bin/shelf/zone

    -- ════════════ AUDIT ════════════
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID REFERENCES users(id),
    version                 INTEGER NOT NULL DEFAULT 1,

    -- ════════════ CONSTRAINTS ════════════
    CONSTRAINT uq_batch_number UNIQUE (tenant_id, batch_number),
    CONSTRAINT chk_qty_positive CHECK (qty_received >= 0)
);
```

### Correction #3: remaining_qty — LEDGER-DERIVED VIEW

```sql
-- remaining_qty is NOT a column in batches table
-- It is computed via VIEW from ledger movements:

CREATE VIEW v_batch_stock AS
SELECT
    b.id AS batch_id,
    b.tenant_id,
    b.batch_number,
    b.item_id,
    b.branch_id,
    b.qty_received,
    COALESCE(SUM(l.qty_in), 0)  AS total_in,
    COALESCE(SUM(l.qty_out), 0) AS total_out,
    COALESCE(SUM(l.qty_in), 0) - COALESCE(SUM(l.qty_out), 0) AS remaining_qty,
    b.expiry_date,
    b.qc_status
FROM batches b
LEFT JOIN inventory_stock_ledger l ON l.batch_id = b.id
WHERE b.is_deleted = false
GROUP BY b.id;
```

**Why this is correct (per Correction #3):**

- Future: sales, production, waste, returns ALL post to ledger
- Ledger = single source of quantity truth
- `remaining_qty` can NEVER drift because it's SUM(in) - SUM(out)
- No trigger needed — it's always live-calculated

---

## 2. MIGRATION MAPPING (All 3 Tables → `batches`)

### Source: `inventory_batches` (20 rows) — **PRIMARY SOURCE**

These are the FK targets. Their UUIDs must be PRESERVED.

| inventory_batches column | → batches column |
|--------------------------|------------------|
| `id` | `id` (SAME UUID) |
| `item_id` | `item_id` |
| `batch_number` | `batch_number` |
| `supplier_lot_number` | `lot_number` |
| `expiry_date` | `expiry_date` |
| `manufacture_date` | `manufacture_date` |
| `qc_status` | `qc_status` |
| `received_from_grn_id` | `source_doc_id` |
| _(hardcoded)_ | `source_doc_type = 'GRN'` |
| `created_at` | `created_at` |
| _(Sakura tenant)_ | `tenant_id` |
| _(Sakura company)_ | `company_id` |
| _(from GRN.receiving_location)_ | `branch_id` (default: Main Warehouse) |

### Source: `grn_batches` (4 rows) — SUPPLEMENTARY

Different UUIDs from inventory_batches. Need to check for duplicates by batch_number.

| grn_batches column | → batches column |
|--------------------|------------------|
| `id` | `id` (new UUID if duplicate batch_number) |
| `grn_id` | `source_doc_id` |
| `item_id` | `item_id` |
| `batch_number` | `batch_number` |
| `quantity` | `qty_received` |
| `expiry_date` | `expiry_date` |
| `qc_status` | `qc_status` |
| `storage_location` | `storage_location` |
| `vendor_batch_number` | `vendor_batch_number` |
| _(hardcoded)_ | `source_doc_type = 'GRN'` |

### Source: `stock_batches` (8 rows) — QTY DATA INJECTION

Contains `qty_received` and `remaining_qty` (verified non-zero).
Match by `grn_id + item_id + batch_no` to update existing batches.

| stock_batches column | → batches action |
|---------------------|-----------------|
| `qty_received` | UPDATE `batches.qty_received` |
| `remaining_qty` | _(verify against ledger, not stored)_ |

---

## 3. FK REWIRING PLAN

| Table | Column | Current FK | New FK | Strategy |
|-------|--------|-----------|--------|----------|
| `inventory_stock_ledger` | `batch_id` | → `inventory_batches(id)` | → `batches(id)` | Drop old FK, add new. Same UUIDs — zero data change. |
| `stock_transfer_items` | `batch_id` | → `inventory_batches(id)` | → `batches(id)` | Drop old FK, add new. Same UUIDs. |
| `transfer_order_items` | `batch_id` | → `inventory_batches(id)` | → `batches(id)` | Drop old FK, add new. Same UUIDs. |

**Risk: ZERO** — because `batches` will contain the SAME UUIDs as `inventory_batches`.

---

## 4. FRONTEND COMPATIBILITY

After deprecating `grn_batches` table, create an UPDATABLE VIEW:

```sql
-- Frontend writes to "grn_batches" — this VIEW intercepts
CREATE VIEW grn_batches AS
SELECT
    id, source_doc_id AS grn_id, item_id, batch_number,
    qty_received AS quantity, expiry_date, qc_status,
    storage_location, vendor_batch_number,
    created_by::text AS created_by, created_at, tenant_id
FROM batches
WHERE source_doc_type = 'GRN' AND is_deleted = false;
```

With INSTEAD OF triggers for INSERT/UPDATE/DELETE → maps to `batches`.

---

## 5. ROLLBACK PLAN

| Step | Rollback |
|------|----------|
| CREATE `batches` | `DROP TABLE batches CASCADE` |
| Migrate data | Data still in `_deprecated_*` tables |
| FK rewire | Re-point FKs back to `_deprecated_inventory_batches` |
| Deprecate old tables | `ALTER TABLE _deprecated_grn_batches RENAME TO grn_batches` |
| Create VIEW | `DROP VIEW grn_batches` |

**All deprecated tables kept for 30 days.**

---

## 6. EXECUTION ORDER

| Sub-Step | What | Risk |
|----------|------|:----:|
| **3.1** | CREATE `batches` table + indexes | 🟢 |
| **3.2** | MIGRATE `inventory_batches` → `batches` (20 rows, same IDs) | 🟢 |
| **3.3** | MIGRATE `grn_batches` → `batches` (4 rows, skip dupes) | 🟢 |
| **3.4** | UPDATE `batches` with qty from `stock_batches` | 🟡 |
| **3.5** | CREATE `v_batch_stock` VIEW (ledger-derived remaining_qty) | 🟢 |
| **3.6** | REWIRE 3 FKs → `batches` (drop old, add new) | 🟡 |
| **3.7** | DEPRECATE 3 old tables (rename with `_deprecated_`) | 🟢 |
| **3.8** | CREATE `grn_batches` VIEW + INSTEAD OF triggers | 🟡 |
| **3.9** | VERIFY: all counts, FK validity, ledger integrity | 🟢 |
