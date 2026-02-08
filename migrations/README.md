# Sakura ERP — Migrations

SQL migrations for Supabase (Postgres). Apply in order; do not modify already-applied migrations.

## Naming

- Format: `YYYYMMDDHHMMSS_short_snake_case_description.sql`
- Example: `20260208120000_add_inventory_reorder_level.sql`

## How to apply

1. **Supabase CLI** (local or linked project):
   ```bash
   supabase db push
   ```
   Or run individual files in order against your DB.

2. **Supabase Dashboard**: SQL Editor — paste migration content and run (for one-off or repair).

3. **CI/CD**: Run `supabase db push` in your pipeline against the target project.

## Order

Migrations are applied in **filename order** (timestamp). Ensure new migrations:
- Do not break existing views or functions referenced by the app.
- Are idempotent where possible (e.g. `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS` in Postgres 11+).

## This folder

- Place all new DDL and schema changes here.
- Optionally keep a `manifest.json` or CHANGELOG listing migrations for human reference.
