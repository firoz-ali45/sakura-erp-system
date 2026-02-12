# Sakura ERP — Worktree Workflow

## Primary Path (Ab Se Yahi Use Karo)

```
C:\Users\shahf\.cursor\worktrees\sakura-erp-system\nva
```

**Sab coding YAHI worktree me.** Direct prompt ke through coding — Apply button use mat karo.

---

## Sync Complete ✅

Downloads (localhost) se saari files worktree me copy ho chuki hai.

---

## Quick Commands

```powershell
# 1. Coding ke baad — Git update
.\sync-to-git.ps1

# Custom commit message
.\sync-to-git.ps1 "Transfer order Foodics UX complete"

# 2. Git + Vercel ek saath
.\commit-and-deploy.ps1
```

---

## Cursor Me Kaise Open Karein

1. **File → Open Folder**
2. Select: `C:\Users\shahf\.cursor\worktrees\sakura-erp-system\nva`
3. Isi folder ko workspace banao

---

## Important Folders

| Purpose   | Path                                                                 |
|----------|----------------------------------------------------------------------|
| Frontend | `ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend\` |
| Migrations | `migrations\`                                                      |
| Services | `services\`                                                         |
