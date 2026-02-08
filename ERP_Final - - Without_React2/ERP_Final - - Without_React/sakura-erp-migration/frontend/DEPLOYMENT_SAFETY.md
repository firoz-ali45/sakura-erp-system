# Safe Surge Deployment Guide
**Version:** v1.0.0-stable  
**Last Updated:** 2025-01-06

---

## 🚨 DEPLOYMENT SAFETY CHECKLIST

### Pre-Deployment Verification

1. ✅ **Router Configuration**
   - Router uses `createWebHashHistory()` (verified in `src/router/index.js`)
   - No redirect scripts in code
   - All routes are client-side (hash-based)

2. ✅ **SPA Routing**
   - Hash routing: `/#/homeportal/...`
   - No server-side routing needed
   - `200.html` exists in `public/` (will be copied to `dist/`)

3. ✅ **Build Safety**
   - Run: `npm run build`
   - Verify: `dist/` folder is generated
   - Verify: `dist/index.html` exists
   - Verify: `dist/200.html` exists (matches index.html)
   - Verify: Assets load correctly
   - Test locally: `npx serve dist` (verify no console errors)

4. ✅ **Google Drive Viewer**
   - Uses `convertToGoogleDrivePreview()` utility
   - Opens in modal with iframe (not new tab)
   - iframe uses proper sandbox attributes
   - CSP allows Google Drive domains

---

## 📦 BUILD INSTRUCTIONS

### Step 1: Build the Application

```bash
cd frontend
npm run build
```

### Step 2: Verify Build Output

```bash
# Check dist folder structure
ls -la dist/

# Expected:
# - index.html
# - 200.html (copied from public/)
# - assets/ (JS, CSS files)
# - version.json (generated)
# - public/ (copied static files)
```

### Step 3: Test Build Locally

```bash
# Serve the build locally
npx serve dist

# Open http://localhost:3000
# Verify:
# - App loads
# - Routing works
# - No console errors
# - All pages accessible
```

---

## 🚀 DEPLOYMENT (SINGLE BUILD → THREE DOMAINS)

**IMPORTANT:** Use the SAME `dist` folder for ALL three deployments (NO rebuild between deploys).

### Deployment Commands

```bash
# Ensure you're in the frontend directory
cd frontend

# Deploy to Domain 1
surge dist sakura-factory-management.surge.sh

# Deploy to Domain 2 (same dist folder)
surge dist sakura-accounts-payable-dashboard.surge.sh

# Deploy to Domain 3 (same dist folder)
surge dist sakura-rm-forecasting.surge.sh
```

**Rules:**
- ✅ ONE build
- ✅ THREE deploys
- ✅ ZERO differences between domains
- ✅ Same dist folder for all domains

---

## 📋 POST-DEPLOYMENT VERIFICATION

Test on EACH domain:

1. ✅ **Home loads** - `https://[domain].surge.sh/`
2. ✅ **Login works** - Can log in successfully
3. ✅ **Refresh on deep routes** - `/#/homeportal/items` stays on page after refresh
4. ✅ **Inventory pages load** - Items, Suppliers, Purchase Orders
5. ✅ **Reports pages load** - Accounts Payable, RM Forecasting, Warehouse
6. ✅ **RM Forecasting loads** - No loading text, spinner only
7. ✅ **Google Drive document renders** - Opens in modal, PDF visible
8. ✅ **Sidebar structure correct** - Settings sticky at bottom
9. ✅ **Fonts & icons correct** - Cairo font loads, Font Awesome icons visible
10. ✅ **Version visible** - Displayed in sidebar footer

**If ANY test fails → ROLLBACK IMMEDIATELY**

---

## 🔄 ROLLBACK INSTRUCTIONS

### Fast Rollback (< 2 minutes)

#### Option 1: From Git Tag

```bash
# Checkout the stable tag
git checkout v1.0.0-stable

# Rebuild
cd frontend
npm run build

# Deploy (all three domains)
surge dist sakura-factory-management.surge.sh
surge dist sakura-accounts-payable-dashboard.surge.sh
surge dist sakura-rm-forecasting.surge.sh
```

#### Option 2: From ZIP Backup

```bash
# Extract the backup
unzip dist-v1.0.0-stable.zip -d dist-backup

# Deploy from backup
cd dist-backup
surge . sakura-factory-management.surge.sh
surge . sakura-accounts-payable-dashboard.surge.sh
surge . sakura-rm-forecasting.surge.sh
```

#### Option 3: From Previous Surge Deployment

```bash
# Surge keeps previous deployments accessible
# Use Surge dashboard to rollback, OR:
surge rollback sakura-factory-management.surge.sh
surge rollback sakura-accounts-payable-dashboard.surge.sh
surge rollback sakura-rm-forecasting.surge.sh
```

---

## 📝 VERSION MANAGEMENT

### Version File Location

- **Source:** Generated during build
- **Output:** `dist/version.json`
- **Display:** Sidebar footer (small text)

### Version Format

```json
{
  "version": "v1.0.0-stable",
  "deployedAt": "2025-01-06 16:30:00",
  "notes": "Mobile + performance + routing stable"
}
```

### Creating Version Tag

```bash
# Create Git tag
git tag v1.0.0-stable
git push origin v1.0.0-stable

# Create ZIP backup
cd frontend
zip -r ../dist-v1.0.0-stable.zip dist/
```

---

## 🔍 TROUBLESHOOTING

### Issue: Blank Screen After Deploy

**Check:**
1. Browser console for errors
2. Network tab for failed asset loads
3. Verify `dist/index.html` exists
4. Verify assets path is correct

**Fix:**
- Check `vite.config.js` base path (should be `/`)
- Verify build completed without errors
- Check browser console for specific errors

### Issue: Routing Doesn't Work

**Check:**
1. Router uses `createWebHashHistory()` (already verified)
2. URLs contain `#` (e.g., `/#/homeportal/items`)
3. No server redirects

**Fix:**
- Hash routing should work without server configuration
- If using HTML5 history, would need `200.html` (but we use hash routing)

### Issue: Google Drive Viewer Doesn't Render

**Check:**
1. iframe sandbox attributes
2. CSP headers (if any)
3. Console for iframe errors

**Fix:**
- Verify iframe uses `sandbox="allow-scripts allow-same-origin allow-popups allow-forms"`
- Check Google Drive URL format
- Verify modal opens correctly

---

## ✅ SUCCESS CRITERIA

Deployment is successful when:

1. ✅ All 3 domains show identical system
2. ✅ No blank screens
3. ✅ Routing works on refresh
4. ✅ Google Drive viewer works
5. ✅ All pages load correctly
6. ✅ Version displayed in footer
7. ✅ Rollback accessible in < 2 minutes

---

**Next Steps After Deployment:**
1. Monitor for 24 hours
2. Check user feedback
3. Verify analytics
4. Document any issues
