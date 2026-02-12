# Sakura ERP — Agent Instructions

## Workspace: Downloads Path

**All coding must be done in this folder**: `C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system`

- Primary workspace path — sab edits yahi pe
- Do NOT use "Apply worktree to current branch" — EPERM errors
- All edits, new files, migrations → this folder only

## After Making Changes

1. User runs `.\sync-to-git.ps1` to commit & push to Git
2. User runs `.\trigger-vercel.ps1` or `.\commit-and-deploy.ps1` for Vercel deploy

## Key Paths (relative to project root)

- Frontend: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend/`
- Vue views: `.../frontend/src/views/inventory/`
- Components: `.../frontend/src/components/transfer/`
- Services: `.../frontend/src/services/`
- Migrations: `migrations/`
