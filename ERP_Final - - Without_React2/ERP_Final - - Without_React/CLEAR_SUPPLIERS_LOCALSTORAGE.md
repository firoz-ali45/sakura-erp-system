# Clear Suppliers Data from localStorage

## Quick Method (Browser Console)

1. Open your browser (Chrome/Edge/Firefox)
2. Press **F12** to open Developer Tools
3. Go to **Console** tab
4. Copy and paste this command:

```javascript
localStorage.removeItem('suppliers');
console.log('✅ Suppliers data cleared from localStorage');
```

5. Press **Enter**
6. Refresh the page (F5)

## Verify

After clearing, verify it's empty:

```javascript
console.log('Suppliers in localStorage:', localStorage.getItem('suppliers'));
// Should show: null
```

## Note

After clearing localStorage:
- All suppliers data will be removed from browser storage
- System will now load suppliers from Supabase only
- New imports will save to Supabase database
- Structure and functionality remain the same

