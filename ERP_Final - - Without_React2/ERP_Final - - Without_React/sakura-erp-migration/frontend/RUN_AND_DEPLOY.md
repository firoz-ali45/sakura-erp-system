# GRN fixes – Localhost & Vercel pe changes kaise dikhayen

Agar **localhost** ya **Vercel** pe batch quantity 0, `common.notAvailable`, ya Edit/Delete nahi dikh rahe, to changes wale code se run/deploy nahi ho raha.

---

## 1. Localhost (localhost:5173)

**Zaroori:** App **is hi folder** se run karo — jahan ye file hai.

**Full path (Windows):**
```
C:\Users\shahf\.cursor\worktrees\sakura-erp-system-3\kmw\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend
```

**Steps:**
1. Is path pe jao (File Explorer ya terminal).
2. Terminal me: `npm install` (pehli bar ya dependency change ke baad).
3. `npm run dev`
4. Browser me `http://localhost:5173` kholo.
5. GRN → koi GRN open karo → Batches tab.

**Verify:** GRN batch table me quantity, remaining, created by name, aur edit/delete controls sahi dikhne chahiye.

---

## 2. Vercel (sakura-erp-system-miuq.vercel.app)

**Zaroori:** Vercel **is repo** se deploy ho, jahan ye code push hai: `firoz-ali45/sakura-erp-system`, branch **main**.

**Steps:**
1. Vercel Dashboard → Project (Sakura Management Hub).
2. **Settings** → **Git**:
   - Repository: `firoz-ali45/sakura-erp-system`
   - Production Branch: `main`
3. **Redeploy:** Deployments tab → latest deployment → ⋮ → **Redeploy** (without cache).
4. Ya naya commit push karo; auto-deploy ho jana chahiye.

**Root Directory:** Repo root pe `vercel.json` hai jo frontend folder se build karta hai. Root Directory **khali** rakhna chahiye (default). Agar koi custom root set hai to hata do taaki root `vercel.json` use ho.

**Verify:** Deploy ke baad app kholo → GRN → Batches. Quantity/remaining/name mapping aur translations production me clean render hone chahiye.

---

## 3. Agar ab bhi purana code dikhe

- **Localhost:** Check karo `npm run dev` kis folder se chal raha hai. Agar koi aur clone/path hai (e.g. Downloads/sakura-erp-system), to wahan **git pull** karo ya **is worktree path** se chalao.
- **Vercel:** Check karo Vercel ka Git connection **sakura-erp-system** repo + **main** branch pe hai. Phir **Redeploy (without cache)** karo.
