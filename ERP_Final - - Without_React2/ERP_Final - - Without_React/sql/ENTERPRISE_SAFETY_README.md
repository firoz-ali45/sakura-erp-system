# Enterprise Safety: Transaction Locking, Audit Trail, Double-Submit Prevention

## Overview

This document describes the enterprise-grade safety features implemented for Sakura ERP.

## 1. Transaction Locking

### Advisory Locks (Existing)
- **PR number sequence**: `pg_advisory_xact_lock()` in `fn_get_next_pr_number` prevents race conditions when generating PR numbers.
- **Other sequences**: Similar pattern used for PO, GRN, TRS numbers.

### Optimistic Locking (New)
- **Version column** added to: `purchase_requests`, `purchase_orders`, `transfer_orders`, `stock_transfers`, `finance_payments`, `purchasing_invoices`.
- **Trigger**: `fn_increment_version()` auto-increments `version` on every UPDATE.
- **Usage**: When updating, include `WHERE id = $1 AND version = $2`; if 0 rows affected, another user modified the record (concurrent update).

## 2. Audit Trail

### Database Triggers
- **`fn_audit_trigger()`**: Captures INSERT, UPDATE, DELETE on key tables.
- **Tables audited**: `purchase_requests`, `purchase_orders`, `transfer_orders`, `stock_transfers`, `finance_payments`, `purchasing_invoices`.
- **Stored in**: `audit_logs` (user_id, action, entity_type, entity_id, old_values, new_values, created_at).

### Client-Side Audit
- **`useAuditLog()`**: Composable for explicit action logging.
- **`AuditLogger`**: In `advancedERPFeatures.js`; logs to `audit_logs` with IP, user agent.

### Setting Current User (for triggers)
For Supabase RPC/triggers to capture the correct user:
```sql
SELECT set_config('app.current_user_id', auth.uid()::text, true);
```
Call before operations when using service role.

## 3. Double-Submit Prevention

### Frontend: `useSubmitGuard`
```javascript
import { useSubmitGuard } from '@/composables/useSubmitGuard';

const { submitting, guard } = useSubmitGuard();

// In template: :disabled="submitting || !canSubmit"
const submitPayment = async () => {
  if (!canSubmit.value) return;
  await guard(async () => {
    // ... async work
  });
};
```

### Database: Idempotency Keys
- **Table**: `idempotency_keys` (key_hash, operation, entity_id, result, expires_at).
- **Functions**: `fn_check_idempotency(p_key_hash)`, `fn_store_idempotency(...)`.
- **Usage**: Generate a hash from (user_id + operation + request_id); check before processing; store result after success.

## Migration

Run `05_ENTERPRISE_SAFETY.sql` in Supabase SQL Editor.
