# ⚠️ IMPORTANT: Restart Dev Server

## Issue
The `vue-i18n` package was just installed, but Vite needs to be restarted to recognize it.

## Solution

1. **Stop the current dev server** (Ctrl+C in the terminal where it's running)

2. **Restart the dev server:**
   ```bash
   cd sakura-erp-migration/frontend
   npm run dev
   ```

3. **Clear browser cache** (optional but recommended):
   - Press `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)
   - Or open DevTools → Network tab → Check "Disable cache"

## Why This Happens

When you install a new npm package while the dev server is running, Vite doesn't automatically detect it. You need to restart the server so it can:
- Resolve the new module
- Update its dependency graph
- Rebuild the module cache

## Verification

After restarting, you should see:
- ✅ No import errors in the console
- ✅ The app loads successfully
- ✅ Language switching works

If you still see errors after restarting, let me know!

