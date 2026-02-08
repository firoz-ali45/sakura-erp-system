# 🚀 Surge.sh Production Deployment Guide

## Quick Deployment

Run the PowerShell deployment script:

```powershell
.\deploy-surge.ps1
```

Or manually:

```powershell
# 1. Build production bundle
npm run build

# 2. Ensure 200.html exists (copies index.html)
Copy-Item dist\index.html dist\200.html

# 3. Deploy to each domain
cd dist
surge . sakura-accounts-payable-dashboard.surge.sh --domain sakura-accounts-payable-dashboard.surge.sh
surge . sakura-factory-management.surge.sh --domain sakura-factory-management.surge.sh
surge . sakura-rm-forecasting.surge.sh --domain sakura-rm-forecasting.surge.sh
cd ..
```

## Production Build Features

✅ **Minification**: Terser with console.log removal  
✅ **Code Splitting**: Vendor chunks for faster loading  
✅ **SPA Routing**: 200.html for Surge routing support  
✅ **Asset Optimization**: Hashed filenames for caching  

## Target Domains

1. https://sakura-accounts-payable-dashboard.surge.sh/
2. https://sakura-factory-management.surge.sh/
3. https://sakura-rm-forecasting.surge.sh/

## Validation Checklist

- [ ] Page loads < 2s
- [ ] Mobile works (375px)
- [ ] Arabic / English switch works
- [ ] No console errors
- [ ] Hard refresh works
- [ ] Direct URL access works
