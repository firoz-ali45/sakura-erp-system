# Ultra-Fast Router Setup Guide

## Overview
The Sakura ERP has been converted from iframe-based navigation to a proper website with URL routing. Each page now has its own URL (e.g., `sakurafactory.com/HomePortal`, `sakurafactory.com/Inventory/Items`).

## Features
- ✅ **<1 Second Page Load**: Optimized caching and lazy loading
- ✅ **Proper URLs**: Each page has its own URL
- ✅ **Browser History**: Back/Forward buttons work correctly
- ✅ **Page Caching**: Previously visited pages load instantly
- ✅ **Preloading**: Critical pages preload in background

## URL Structure

### Main Routes
- `/` or `/HomePortal` - Home Dashboard
- `/Inventory/Items` - Inventory Items List
- `/Inventory/Categories` - Inventory Categories
- `/Inventory/ItemDetail` - Item Detail Page (with ?id= parameter)
- `/Manage/Tags` - Tags Management
- `/AccountsPayable` - Accounts Payable Dashboard
- `/Forecasting` - RM Forecasting
- `/Warehouse` - Warehouse Dashboard
- `/QualityTraceability` - Food Quality Traceability
- `/UserManagement` - User Management

### Query Parameters
- `/Inventory/ItemDetail?id=uuid-here` - View specific item
- `/Inventory/ItemDetail?id=uuid-here&edit=true` - Edit item

## Server Configuration

### Apache (.htaccess)
The `.htaccess` file is included. Make sure:
1. `mod_rewrite` is enabled
2. `.htaccess` files are allowed
3. Restart Apache after changes

### Nginx
Add to your nginx config:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### Netlify/Vercel
The `_redirects` file is included. No additional config needed.

## Performance Optimization

### Caching Strategy
- Pages are cached after first load
- Cache persists until page refresh
- Critical pages preload in background

### Load Time Targets
- First load: < 2 seconds
- Cached pages: < 100ms
- Preloaded pages: < 500ms

## Migration Notes

### Old Navigation (Still Works)
```javascript
loadDashboard(event, 'inventory/items.html')
```

### New Navigation (Recommended)
```javascript
router.go('/Inventory/Items')
```

### In HTML
```html
<!-- Old -->
<a href="#" onclick="loadDashboard(event, 'inventory/items.html')">Items</a>

<!-- New -->
<a href="/Inventory/Items" onclick="router?.go('/Inventory/Items'); return false;">Items</a>
```

## Testing

1. **Check URLs**: Navigate and verify URLs change
2. **Test Back/Forward**: Browser buttons should work
3. **Test Direct Access**: Direct URL access should work
4. **Check Load Times**: Console shows load times
5. **Test Caching**: Second visit should be instant

## Troubleshooting

### Pages Not Loading
- Check browser console for errors
- Verify file paths in `js/router.js`
- Check server rewrite rules

### Slow Load Times
- Check network tab for slow requests
- Verify caching is working
- Check for large files

### 404 Errors
- Verify `.htaccess` or server config
- Check route definitions in `js/router.js`
- Ensure files exist at specified paths

## Next Steps

1. Update all internal links to use router
2. Add more routes as needed
3. Optimize page sizes for faster loading
4. Add service worker for offline support
