# ⚡ Quick Deployment - 3 Easy Steps

## 🎯 Recommended: Netlify (Easiest & Free)

### Step 1: Prepare Files
Run the deployment script:
- **Windows**: Double-click `deploy.bat`
- **Mac/Linux**: Run `./deploy.sh`

This creates a `deploy-package` folder with all necessary files.

### Step 2: Deploy to Netlify
1. Go to **[netlify.com](https://netlify.com)**
2. Sign up (free) or login
3. You'll be on the "Projects" page
4. Look for the drag-and-drop area that says: **"Want to deploy a new project without connecting to Git? Drag and drop your project folder here."**
5. **Drag and drop** the `deploy-package` folder into that area
6. Wait 30 seconds
7. **Done!** Your site is live

### Step 3: Test
Visit your Netlify URL (e.g., `your-site.netlify.app`):
- ✅ `your-site.netlify.app/HomePortal`
- ✅ `your-site.netlify.app/Inventory/Items`
- ✅ Test navigation and URLs

---

## 🔄 Alternative: Vercel (Also Free & Fast)

### Step 1: Prepare Files
Same as above - run `deploy.bat` or `deploy.sh`

### Step 2: Deploy to Vercel
1. Go to **[vercel.com](https://vercel.com)**
2. Sign up (free) or login
3. Click "New Project"
4. Upload `deploy-package` folder
5. **Done!** Your site is live

---

## 🌐 Custom Domain (Optional)

After deployment:
1. Go to your Netlify/Vercel dashboard
2. Click "Domain Settings"
3. Add `sakurafactory.com` (or your domain)
4. Follow DNS instructions
5. Free SSL certificate included!

---

## 📋 What Gets Deployed

The `deploy-package` folder includes:
- ✅ `index.html` - Main portal
- ✅ `js/router.js` - Router system
- ✅ `.htaccess` - Apache config
- ✅ `_redirects` - Netlify/Vercel config
- ✅ All dashboard pages
- ✅ All CSS and JS files

---

## ❓ Need Help?

1. **404 Errors**: Make sure `_redirects` file is in root
2. **Slow Loading**: Check browser console for errors
3. **Routes Not Working**: Verify router.js is loaded

---

## 🎉 That's It!

Your Sakura ERP is now live with:
- ✅ Proper URLs (sakurafactory.com/HomePortal)
- ✅ Ultra-fast loading (<1 second)
- ✅ Browser history support
- ✅ Direct URL access
