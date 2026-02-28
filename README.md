# Sakura ERP System

Modular ERP with **Supabase** backend, **clean architecture**, and a **migration-driven** database.

## Project structure

| Folder | Purpose |
|--------|--------|
| **backend** | Config, shared types, errors. Thin API/Edge layer. |
| **database** | Schema reference, seeds, DB conventions. |
| **migrations** | SQL migrations for Supabase (Postgres). Apply in order. |
| **services** | Domain logic: inventory, purchasing, finance, document_flow_engine. |

See [ARCHITECTURE.md](./ARCHITECTURE.md) for design and data flow.

## Quick start

1. **Environment**  
   Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (and optionally `SUPABASE_SERVICE_ROLE_KEY` for server-side).

2. **Migrations**  
   From project root:
   ```bash
   supabase link --project-ref <your-ref>
   supabase db push
   ```
   Or run SQL files in `migrations/` manually in Supabase Dashboard → SQL Editor.

3. **Backend / Edge Functions**  
   Implement repository adapters (e.g. Supabase client) and wire them into the services. Deploy with:
   ```bash
   supabase functions deploy <function-name>
   ```

4. **Frontend**  
   Use the existing Vue app (e.g. under `ERP_Final - - Without_React2/.../vue-starter-template`) or point a new app at the same Supabase project.

## Services

- **inventory** — Items, categories, locations, stock levels, ledger, batches.  
- **purchasing** — Purchase requests, POs, GRNs, suppliers.  
- **finance** — Chart of accounts, GL journal, payments, AP.  
- **document_flow_engine** — Workflows, approval steps, document chains.

Each service exposes a class (e.g. `InventoryService`) and repository interface; inject a concrete repository when instantiating.

## Deploy on Vercel

Frontend (Vue SPA) ko **Vercel** par deploy karne ke liye: **[VERCEL_DEPLOY.md](./VERCEL_DEPLOY.md)** — step-by-step guide (Hindi/English).

- **Root Directory**: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`
- Build: `npm run build`, Output: `dist`
- Backend (Supabase) pehle se cloud par; sirf frontend Vercel par host hota hai.

*Commit & push to `main` triggers Vercel deploy (sakura-erp-system-miuq).*

## License

Private / internal use unless otherwise stated.
