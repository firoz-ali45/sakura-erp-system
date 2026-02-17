# Sakura ERP — Agent Instructions

## Workspace: Worktree (nva)

**All coding must be done in this worktree**: `C:\Users\shahf\.cursor\worktrees\sakura-erp-system\nva`

- Sab edits yahi pe — Downloads path use mat karo
- Do NOT use "Apply worktree to current branch" — EPERM errors
- All edits, new files, migrations → this worktree only

## After Making Changes (AUTO-DEPLOY — Hamesha Follow Karo)

**Jab bhi koi operation pura ho jaye**, automatically:
1. `.\sync-to-git.ps1` — commit & push
2. `.\deploy-vercel-cli.ps1` — Vercel deploy (sakura-erp-system-miuq)
3. User ko batao: "Deployment complete. Live: https://sakura-erp-system-miuq.vercel.app/"

## Key Paths (relative to worktree root)

- Frontend: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend/`
- Vue views: `.../frontend/src/views/inventory/`
- Components: `.../frontend/src/components/transfer/`
- Services: `.../frontend/src/services/`
- Migrations: `migrations/`
