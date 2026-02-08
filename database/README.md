# Sakura ERP — Database

Single source of truth for **schema design** and **Supabase/Postgres** configuration.

## Structure

```
database/
├── schema/           # Logical schema docs and table definitions (reference)
├── seeds/            # Optional seed data (idempotent)
└── README.md
```

## Migrations

- **SQL migrations** live in project root: `/migrations`.
- Naming: `YYYYMMDDHHMMSS_description.sql`.
- Apply via Supabase CLI: `supabase db push` or Supabase Dashboard → SQL Editor / Migration history.
- Never edit applied migrations; add new ones for changes.

## Schemas (current)

- **public** — Core ERP: inventory, purchasing, finance, document_flow, users, roles.
- **erp** (if used) — Legacy or domain-specific tables; prefer consolidating into `public` with prefixes for clarity.

## Conventions

- Use `id uuid PRIMARY KEY DEFAULT gen_random_uuid()` for primary keys.
- Use `created_at timestamptz DEFAULT now()`, `updated_at timestamptz` where applicable.
- Enable RLS on all user-facing tables; define policies per role.
- Keep FKs and indexes explicit in migrations.
