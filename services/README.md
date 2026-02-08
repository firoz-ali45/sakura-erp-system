# Sakura ERP — Services

Modular **domain services** implementing business logic. Backend (Edge Functions / API) calls these; services do not depend on HTTP or Supabase directly—they receive a **database/repository** abstraction.

## Structure

```
services/
├── inventory/           # Items, categories, locations, stock ledger, batches
├── purchasing/          # Purchase requests, POs, GRNs, suppliers
├── finance/             # GL, chart of accounts, payments, AP
├── document_flow_engine/ # Workflows, document chains, approvals
└── README.md
```

## Per-module layout

Each service module follows:

- **types.ts** — Domain entities and DTOs.
- **repository.ts** — Interface for data access (e.g. `IInventoryRepository`). Implementations can live in backend or a separate `repositories` layer.
- **index.ts** — Public API: service class/functions and types. No Supabase imports here; inject client via constructor or function args.

## Principles

- **Single responsibility**: One domain per folder.
- **Testability**: Services accept repositories or DB clients; easy to mock.
- **Reusability**: Same service can be used from Edge Functions, a future Node API, or serverless.
- **No UI**: No Vue/React imports; no Supabase in service core (only in repository implementations if needed).
