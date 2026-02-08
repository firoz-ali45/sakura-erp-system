# Sakura ERP — Architecture

World-class ERP layout with **Supabase** backend, **clean architecture**, and **modular domain services**.

## High-level layout

```
sakura-erp-system/
├── backend/              # API layer, config, shared types & errors
├── database/             # Schema reference, seeds, DB conventions
├── migrations/           # SQL migrations (Supabase / Postgres)
├── services/             # Domain services (business logic)
│   ├── inventory/
│   ├── purchasing/
│   ├── finance/
│   └── document_flow_engine/
├── supabase/             # Supabase CLI config (optional at root)
└── ARCHITECTURE.md
```

## Principles

1. **Supabase as backend**  
   Postgres, Auth, Storage, and Edge Functions. Schema and migrations are the single source of truth.

2. **Clean architecture**  
   - **Backend**: Thin handlers; no business logic. Config, types, and shared utilities only.  
   - **Services**: All business rules. Depend on repository interfaces, not Supabase directly.  
   - **Database**: Schema and migration discipline; no ad-hoc SQL in app code.

3. **Migration system**  
   All DDL and schema changes live under `migrations/` with timestamped filenames. Apply via `supabase db push` or your CI pipeline.

4. **Modular ERP design**  
   - **Inventory**: Items, categories, locations, stock ledger, batches.  
   - **Purchasing**: Purchase requests, POs, GRNs, suppliers.  
   - **Finance**: Chart of accounts, GL journal, payments, AP.  
   - **Document flow engine**: Workflows, approval steps, document chains (PR → PO → GRN).

## Data flow

- **Client** (Vue/React) → Supabase Client (Auth, Realtime, PostgREST).
- **Edge Functions / API** → instantiate services with repository implementations (Supabase client) → call service methods.
- **Services** → call repository interface only; repositories talk to Supabase/Postgres.

## Repository implementations

Repository interfaces live in `services/*/repository.ts`. Implementations can live in:

- `backend/repositories/` (e.g. Supabase-backed), or  
- Next to the service in `services/*/repositories/supabase.ts`.

Inject the implementation when constructing the service (e.g. in an Edge Function or serverless handler).

## Migrations

- Location: `/migrations`.  
- Naming: `YYYYMMDDHHMMSS_short_description.sql`.  
- Apply: `supabase db push` from project root (with `supabase` linked or local).  
- Do not edit applied migrations; add new ones for every change.

## Existing codebase

Legacy or existing frontends (e.g. under `ERP_Final - - Without_React2/`) can be gradually refactored to:

- Call Edge Functions that use these services, or  
- Use Supabase client against the same DB while new features use the service layer.
