# Supabase CLI (root)

This folder is used by the **Supabase CLI** for `supabase link`, `supabase db push`, and `supabase functions deploy`.

## Migrations

- **Canonical migrations** live in the repo root: **`/migrations`**.
- To use `supabase db push`, either:
  1. Copy new migration files from `/migrations` into `supabase/migrations/`, or  
  2. Run the SQL from `/migrations` manually in Supabase Dashboard → SQL Editor.
- Migrations in `supabase/migrations/` are applied in **timestamp order** (filename).

## Link project

```bash
supabase link --project-ref kexwnurwavszvmlpifsf
```

## Edge Functions

Deploy from project root:

```bash
supabase functions deploy <function-name>
```

Implement repository adapters in the app that call the **services** under `/services`; Edge Functions can instantiate those services and expose HTTP handlers.
