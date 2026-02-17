# Enterprise Safety: Transaction Locking, Audit Trail, Double-Submit Prevention

## Overview

Sakura ERP implements three layers of enterprise safety:

1. **Transaction locking** – Prevents race conditions on critical mutations
2. **Audit trail** – Full traceability for compliance
3. **Double-submit prevention** – Blocks duplicate submissions from UI and DB

---

## 1. Transaction Locking

### Database Functions

- **`fn_lock_document(p_table, p_id)`** – Locks a document by table + UUID using `pg_advisory_xact_lock`
- **`fn_lock_composite(p_key)`** – Locks by composite key (e.g. GRN+batch)

### Usage in RPCs

Add at the start of critical RPCs (e.g. `fn_dispatch_stock_transfer`, `fn_post_grn`, `fn_insert_finance_payment`):

```sql
-- At start of RPC body
PERFORM fn_lock_document('stock_transfers', p_transfer_id);
```

### Existing Locks

- **PR number generation**: `pg_advisory_xact_lock` in `generate_pr_number()`
- **GRN batch operations**: `pg_advisory_xact_lock` in batch/ledger triggers

---

## 2. Audit Trail

### Tables

- **`audit_logs`** – `user_id`, `action`, `entity_type`, `entity_id`, `old_values`, `new_values`, `ip_address`, `user_agent`, `created_at`

### Trigger (Optional)

`fn_audit_trigger()` – Generic trigger for INSERT/UPDATE/DELETE. Enable per table:

```sql
CREATE TRIGGER trg_audit_stock_transfers
  AFTER INSERT OR UPDATE OR DELETE ON stock_transfers
  FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
```

Set user context before operations (e.g. in RPC):

```sql
PERFORM set_config('app.current_user_id', p_user_id, true);
```

### Frontend

- **`useAuditLog()`** – `logAction(action, entityType, entityId, oldValues, newValues)`
- **`useSafeSubmit()`** – Wraps mutations with guard + optional audit

---

## 3. Double-Submit Prevention

### Frontend: `useSubmitGuard`

```vue
<script setup>
import { useSubmitGuard } from '@/composables/useSubmitGuard';

const { submitting, guard } = useSubmitGuard();

const handleSave = () => guard(async () => {
  await savePR(data);
});
</script>

<template>
  <button :disabled="submitting" @click="handleSave">Save</button>
</template>
```

### Frontend: `useSafeSubmit` (Guard + Audit)

```vue
<script setup>
import { useSafeSubmit } from '@/composables/useSafeSubmit';

const { safeSubmit, submitting } = useSafeSubmit();

const handleSubmit = () => safeSubmit(
  async () => await submitPR(id),
  {
    entityType: 'purchase_requests',
    entityId: id,
    action: 'SUBMIT',
    idempotencyKey: `pr_submit_${id}`,
    auditOldValues: { status: pr.value?.status },
    auditNewValues: { status: 'submitted' }
  }
);
</script>
```

### Idempotency Cooldown

- After success, same `idempotencyKey` is blocked for 3 seconds (sessionStorage)
- Prevents rapid double-clicks and refresh-triggered resubmits

---

## Migration

Run `sql/05_ENTERPRISE_SAFETY.sql` to create:

- `audit_logs` table (if not exists)
- `fn_audit_trigger()`
- `fn_lock_document()`, `fn_lock_composite()`
