# Sakura ERP — Backend

Backend layer for Sakura ERP. Uses **Supabase** (Postgres, Auth, Edge Functions) with **clean architecture**.

## Structure

```
backend/
├── config/           # Supabase client, env, feature flags
├── types/            # Shared TypeScript types and DTOs
├── shared/           # Cross-cutting (errors, validation, logging)
└── README.md
```

## Principles

- **Thin backend**: Edge Functions / API route handlers only orchestrate; business logic lives in `../services`.
- **No direct Supabase in services**: Services receive a **database client** (or repository interface) so they stay testable and framework-agnostic.
- **Single source of truth**: Database schema and migrations live under `../database` and `../migrations`.

## Usage

- **Edge Functions**: Deploy from project root with `supabase functions deploy`.
- **Local dev**: Use `supabase start` and point `config/supabase.ts` at local URL/keys.
- **Types**: Import from `@/backend/types` or relative `../backend/types` from services.
