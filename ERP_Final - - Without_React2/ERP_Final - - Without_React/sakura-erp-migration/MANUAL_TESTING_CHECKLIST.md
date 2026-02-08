# Sakura Management Hub - Manual Testing Checklist
**Version:** 1.0  
**Date:** $(date)  
**Tester Name:** _________________  
**Testing Environment:** Localhost (localhost:5173)

---

## 📋 HOW TO USE THIS CHECKLIST

1. **Open the application** in your browser at `localhost:5173`
2. **Work through each section** in order
3. **Mark each item** as:
   - ✅ **PASS** - Works correctly
   - ❌ **FAIL** - Does not work or looks wrong
   - ⚠️ **PARTIAL** - Works but has issues
4. **Note any failures** in the "Notes" column
5. **DO NOT proceed to next section** if critical items fail
6. **Take screenshots** of any failures

---

## 🔐 PRE-TEST: LOGIN & AUTHENTICATION

### Desktop Test (Chrome/Firefox)
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 1.1 | Open `localhost:5173` | Login page appears (no blank screen) | ⬜ | |
| 1.2 | Enter valid credentials and click Login | Dashboard loads, no errors | ⬜ | |
| 1.3 | Check browser console (F12) | No red error messages | ⬜ | |

**If 1.1 or 1.2 FAIL → STOP TESTING, Report to developer**

---

## 🧱 SECTION 1: APPLICATION BOOT & STABILITY

### Desktop Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 1.1 | After login, refresh page (F5) | Dashboard stays visible, no redirect to login | ⬜ | |
| 1.2 | Open browser console (F12 → Console tab) | No red/fatal errors | ⬜ | |
| 1.3 | Navigate to: `localhost:5173/#/homeportal/items` | Items page loads | ⬜ | |
| 1.4 | Refresh page (F5) on Items page | Stays on Items page, doesn't redirect to home | ⬜ | |
| 1.5 | Navigate to: `localhost:5173/#/homeportal/purchase-orders` | Purchase Orders page loads | ⬜ | |
| 1.6 | Refresh page (F5) on Purchase Orders page | Stays on Purchase Orders page | ⬜ | |
| 1.7 | Navigate to: `localhost:5173/#/homeportal/suppliers` | Suppliers page loads | ⬜ | |
| 1.8 | Refresh page (F5) on Suppliers page | Stays on Suppliers page | ⬜ | |
| 1.9 | Check browser address bar | All URLs start with `/#/homeportal/` (hash routing) | ⬜ | |

**CRITICAL: If ANY refresh redirects to home → STOP, Report to developer**

---

## 📱 SECTION 2: MOBILE & TABLET EXPERIENCE

### Mobile Test (iPhone/Android - Chrome/Safari)
**Open:** `localhost:5173` on your phone (use same network as computer)

| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 2.1 | **Sidebar Test:** Tap hamburger menu (☰) in top-left | Sidebar slides in from left | ⬜ | |
| 2.2 | Tap outside sidebar (on gray overlay) | Sidebar closes | ⬜ | |
| 2.3 | Scroll sidebar menu up and down | Menu scrolls smoothly, Settings stays at bottom | ⬜ | |
| 2.4 | Tap "Settings" at bottom of sidebar | Settings stays visible at bottom (doesn't scroll away) | ⬜ | |
| 2.5 | **Content Scroll Test:** On dashboard, scroll up/down | Page scrolls vertically (not stuck) | ⬜ | |
| 2.6 | Go to Items page, scroll table left/right | Wide table scrolls horizontally | ⬜ | |
| 2.7 | **Tap Test:** Tap any button or link | Button responds immediately, not opening sidebar | ⬜ | |
| 2.8 | **Layout Test:** View dashboard on phone | Cards stack vertically (not side-by-side) | ⬜ | |
| 2.9 | View Items table on phone | Table scrolls horizontally, doesn't break layout | ⬜ | |
| 2.10 | Check sidebar icons | All icons visible (not missing/broken) | ⬜ | |
| 2.11 | Check dropdown arrows (▶) | Arrows visible next to Reports, Inventory, Manage | ⬜ | |

### Tablet Test (iPad/Android Tablet)
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 2.12 | Open app on tablet | Layout adjusts appropriately | ⬜ | |
| 2.13 | Sidebar behavior | Sidebar visible or accessible via menu | ⬜ | |
| 2.14 | Tables and cards | Layout looks professional, no overflow | ⬜ | |

**If 2.3, 2.4, 2.5, or 2.6 FAIL → Report to developer**

---

## 🎨 SECTION 3: TYPOGRAPHY & VISUAL CALMNESS

### Desktop Visual Test
**Look at the text on screen - it should feel light and professional, not heavy/bold**

| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 3.1 | Go to Suppliers page, look at table text | Table rows text looks light/regular (not bold) | ⬜ | |
| 3.2 | Look at table headers (column names) | Headers slightly bolder than rows, but not heavy | ⬜ | |
| 3.3 | Look at sidebar menu items | Menu text medium weight (not too bold, not too light) | ⬜ | |
| 3.4 | Look at active sidebar item (highlighted) | Active item slightly bolder than others | ⬜ | |
| 3.5 | Look at page title (e.g., "Items", "Suppliers") | Title is bold/clear, but not overwhelming | ⬜ | |
| 3.6 | Look at body text (descriptions, helper text) | Body text is light/regular weight | ⬜ | |
| 3.7 | Look at buttons | Button text medium weight (not too bold) | ⬜ | |
| 3.8 | **Ask yourself:** After 2 minutes of reading, do your eyes feel comfortable? | Yes - text feels calm and professional | ⬜ | |

**If text feels "too bold" or "heavy" → Report to developer**

---

## 📊 SECTION 4: TABLES & DATA DENSITY

### Desktop Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 4.1 | Go to **Items** page | Items table displays | ⬜ | |
| 4.2 | Click on a table row (any row) | Item detail page opens | ⬜ | |
| 4.3 | Go back to Items page | Items table displays again | ⬜ | |
| 4.4 | Click three-dot menu (⋮) on any row | Dropdown menu appears | ⬜ | |
| 4.5 | Click "View" in dropdown | Item detail page opens | ⬜ | |
| 4.6 | Go back to Items page | Items table displays again | ⬜ | |
| 4.7 | Click three-dot menu (⋮) again | Dropdown menu appears | ⬜ | |
| 4.8 | Click "Edit" in dropdown | Item detail page opens in edit mode | ⬜ | |
| 4.9 | **Suppliers Test:** Go to Suppliers page | Suppliers table displays | ⬜ | |
| 4.10 | Click on a supplier row | Supplier detail page opens | ⬜ | |
| 4.11 | Click three-dot menu (⋮) → "View" | Supplier detail page opens | ⬜ | |
| 4.12 | Click three-dot menu (⋮) → "Edit" | Edit functionality works | ⬜ | |
| 4.13 | **Purchase Orders Test:** Go to Purchase Orders page | Purchase Orders table displays | ⬜ | |
| 4.14 | Click on a purchase order row | Purchase Order detail page opens | ⬜ | |
| 4.15 | Click three-dot menu (⋮) → "View" | Purchase Order detail page opens | ⬜ | |
| 4.16 | Click three-dot menu (⋮) → "Edit" | Edit functionality works | ⬜ | |
| 4.17 | Hover over table rows | Row highlights (visual feedback) | ⬜ | |
| 4.18 | Check checkbox in first column | Checkbox selects/deselects | ⬜ | |

**If ANY row click or View/Edit button does nothing → Report to developer**

---

## 🧭 SECTION 5: NAVIGATION & ROUTING

### Desktop Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 5.1 | Click "Home Portal" in sidebar | Dashboard loads | ⬜ | |
| 5.2 | Click "Reports" in sidebar | Reports expands (shows submenu) | ⬜ | |
| 5.3 | Click "Accounts Payable" under Reports | Accounts Payable page loads | ⬜ | |
| 5.4 | Click "Inventory" in sidebar | Inventory expands (shows submenu) | ⬜ | |
| 5.5 | Click "Items" under Inventory | Items page loads | ⬜ | |
| 5.6 | Click "Suppliers" under Inventory | Suppliers page loads | ⬜ | |
| 5.7 | Click "Purchase Orders" under Inventory | Purchase Orders page loads | ⬜ | |
| 5.8 | Click "Manage" in sidebar | Manage expands (shows submenu) | ⬜ | |
| 5.9 | Click "User Management" under Manage | User Management page loads | ⬜ | |
| 5.10 | Click browser Back button (←) | Previous page loads | ⬜ | |
| 5.11 | Click browser Forward button (→) | Next page loads | ⬜ | |
| 5.12 | **Submenu Test:** Expand "Inventory" submenu | All sub-items visible (not cut off) | ⬜ | |
| 5.13 | Scroll sidebar when submenu expanded | All items scroll smoothly | ⬜ | |

**If ANY navigation doesn't work → Report to developer**

---

## 🧾 SECTION 6: DETAIL PAGES (CRITICAL)

### Items Detail Page Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 6.1 | Go to Items page, click on any item row | Item detail page opens | ⬜ | |
| 6.2 | Check page title | Shows item name (not "No ID provided") | ⬜ | |
| 6.3 | Check URL in address bar | Contains item ID (e.g., `/#/homeportal/item-detail/123`) | ⬜ | |
| 6.4 | Click "← Back" button | Returns to Items list page | ⬜ | |
| 6.5 | Click "Edit Item" button | Edit form/modal opens | ⬜ | |

### Suppliers Detail Page Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 6.6 | Go to Suppliers page, click on any supplier row | Supplier detail page opens | ⬜ | |
| 6.7 | Check page title | Shows supplier name (not "No ID provided") | ⬜ | |
| 6.8 | Check URL in address bar | Contains supplier ID | ⬜ | |
| 6.9 | Click "← Back" button | Returns to Suppliers list page | ⬜ | |
| 6.10 | Click "Edit" button (if visible) | Edit form/modal opens | ⬜ | |

### Purchase Orders Detail Page Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 6.11 | Go to Purchase Orders page, click on any PO row | Purchase Order detail page opens | ⬜ | |
| 6.12 | Check page title | Shows "Purchase Order – [Status]" (Draft/Approved/Closed) | ⬜ | |
| 6.13 | **CRITICAL:** Check if status is correct | Status matches actual PO status (not always "Draft") | ⬜ | |
| 6.14 | Check URL in address bar | Contains PO ID | ⬜ | |
| 6.15 | Check for "No purchase order ID provided" error | Error message should NOT appear | ⬜ | |
| 6.16 | Check if page shows: Supplier name, Items table, Totals | All data visible (not empty page) | ⬜ | |
| 6.17 | Click "← Back" button | Returns to Purchase Orders list page | ⬜ | |
| 6.18 | Click "Print" button | Print dialog opens OR print preview appears | ⬜ | |
| 6.19 | Click "Edit" button | Edit form/modal opens | ⬜ | |
| 6.20 | **Test with Approved PO:** Find an Approved PO, open it | Status shows "Approved" (not "Draft") | ⬜ | |
| 6.21 | **Test with Closed PO:** Find a Closed PO, open it | Status shows "Closed" (not "Draft") | ⬜ | |

**If 6.13, 6.15, or 6.16 FAIL → CRITICAL, Report to developer immediately**

### GRN Detail Page Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 6.22 | Go to GRNs page, click on any GRN row | GRN detail page opens | ⬜ | |
| 6.23 | Check page title | Shows GRN number (not error) | ⬜ | |
| 6.24 | Click "← Back" button | Returns to GRNs list page | ⬜ | |
| 6.25 | Click "Print" button | Print dialog opens | ⬜ | |

---

## 🖨️ SECTION 7: PRINT & EXPORT

### Print Function Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 7.1 | Open any Purchase Order detail page | Page loads | ⬜ | |
| 7.2 | Click "Print" button | Print dialog opens (system print dialog) | ⬜ | |
| 7.3 | In print preview, check document title | Shows "Purchase Order - [PO Number]" | ⬜ | |
| 7.4 | Check print content | Shows: PO number, Supplier, Items, Totals, VAT | ⬜ | |
| 7.5 | Check layout | All data visible, nothing clipped | ⬜ | |
| 7.6 | Cancel print, go to GRN detail page | GRN detail page loads | ⬜ | |
| 7.7 | Click "Print" button on GRN page | Print dialog opens | ⬜ | |
| 7.8 | Check GRN print content | Shows GRN details, items, totals | ⬜ | |

**If Print button does nothing or shows blank → Report to developer**

---

## 📎 SECTION 8: DOCUMENT VIEWER (VERY IMPORTANT)

### Google Drive Document Test
**Note:** This test requires a page that has Google Drive document links

| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 8.1 | Find a page with a document link (e.g., Accounts Payable) | Page loads | ⬜ | |
| 8.2 | Click on a "View Document" link/button | Document opens (popup window OR modal) | ⬜ | |
| 8.3 | **CRITICAL:** Check if document is visible | PDF/document renders (NOT blank) | ⬜ | |
| 8.4 | If opened in modal: Scroll inside viewer | Document scrolls properly | ⬜ | |
| 8.5 | Close document viewer | Viewer closes, returns to page | ⬜ | |
| 8.6 | Try opening another document | Opens correctly | ⬜ | |

**If 8.3 FAIL (blank document) → CRITICAL, Report to developer immediately**

---

## ⏳ SECTION 9: LOADING STATES (PROFESSIONAL)

### Loading State Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 9.1 | Go to "RM Forecasting" page (under Reports) | Page loads | ⬜ | |
| 9.2 | **CRITICAL:** Check for loading text | NO text like "Loading from Google Sheet..." appears | ⬜ | |
| 9.3 | While data loads, check loading indicator | Shows spinner/skeleton (no text messages) | ⬜ | |
| 9.4 | Go to "Accounts Payable" page | Page loads | ⬜ | |
| 9.5 | Check loading behavior | Professional loading (spinner, no debug text) | ⬜ | |
| 9.6 | Go to "Warehouse Dashboard" page | Page loads | ⬜ | |
| 9.7 | Check loading behavior | Professional loading (spinner, no debug text) | ⬜ | |
| 9.8 | Navigate between pages quickly | No flashing content, smooth transitions | ⬜ | |

**If 9.2 FAIL (debug text appears) → Report to developer**

---

## ⚡ SECTION 10: PERFORMANCE (SUB-1 SECOND TARGET)

### Performance Test (Use Browser DevTools)
**Instructions:** Open DevTools (F12) → Network tab → Clear cache (right-click → Clear browser cache)

| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 10.1 | **Initial Load:** Clear cache, refresh page | Page loads | ⬜ | |
| 10.2 | Check Network tab timing | Page load completes in < 2 seconds | ⬜ | |
| 10.3 | **Navigation Speed:** Click "Items" in sidebar | Items page appears in < 1 second | ⬜ | |
| 10.4 | Click "Suppliers" in sidebar | Suppliers page appears in < 1 second | ⬜ | |
| 10.5 | Click "Purchase Orders" in sidebar | Purchase Orders page appears in < 1 second | ⬜ | |
| 10.6 | **Table Rendering:** On Items page, scroll table | Table scrolls smoothly (no lag) | ⬜ | |
| 10.7 | On Purchase Orders page, scroll table | Table scrolls smoothly (no lag) | ⬜ | |
| 10.8 | **Data Loading:** Open Purchase Order detail page | Data loads, page ready in < 2 seconds | ⬜ | |

**Note:** Performance targets are guidelines. If pages are slow (>3 seconds), note in comments.

---

## 🔐 SECTION 11: ERROR HANDLING

### Error Handling Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 11.1 | Open browser console (F12 → Console tab) | Console opens | ⬜ | |
| 11.2 | Navigate through pages normally | No red error messages in console | ⬜ | |
| 11.3 | Click various buttons and links | No error popups appear | ⬜ | |
| 11.4 | Try to access invalid URL: `localhost:5173/#/homeportal/invalid-page` | Shows 404 or redirects gracefully | ⬜ | |
| 11.5 | Check for user-friendly error messages | Any errors shown are clear (not technical jargon) | ⬜ | |

**If red errors appear in console consistently → Report to developer**

---

## 🏷️ SECTION 12: BRANDING CONSISTENCY

### Branding Visual Test
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 12.1 | Check browser tab title | Shows "Sakura Management Hub" | ⬜ | |
| 12.2 | Check favicon (small icon in browser tab) | Pink Sakura logo visible | ⬜ | |
| 12.3 | Check top header (center of page) | Pink Sakura logo in circle visible | ⬜ | |
| 12.4 | **Mobile Test:** Open on phone, check browser tab | Shows "Sakura Management Hub" with logo | ⬜ | |
| 12.5 | Check header on mobile | Logo visible in header | ⬜ | |
| 12.6 | Check sidebar footer | Shows "Sakura Portal © 2026" (year as number, not formatted) | ⬜ | |
| 12.7 | Check colors across pages | Colors consistent (green theme) | ⬜ | |

**If logo missing or wrong title → Report to developer**

---

## 🧪 SECTION 13: FINAL HUMAN TEST (MOST IMPORTANT)

### Extended Usage Test
**Spend 10-15 minutes using the system normally**

| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| 13.1 | **Comfort Test:** Use system for 5 minutes | Nothing feels "annoying" or "off" | ⬜ | |
| 13.2 | **Completeness Test:** Navigate through all major sections | Nothing feels "unfinished" or "broken" | ⬜ | |
| 13.3 | **Trust Test:** Imagine using this for real business | Would you trust this system for real money/data? | ⬜ | |
| 13.4 | **Readability Test:** Read tables and text for 2 minutes | Eyes don't feel strained, text is comfortable | ⬜ | |
| 13.5 | **Workflow Test:** Complete a typical task (e.g., view a PO, check items) | Task completes smoothly, no blockers | ⬜ | |

**If you answer "No" to 13.3 → DO NOT DEPLOY, Report all issues**

---

## 📱 MOBILE-SPECIFIC ADDITIONAL TESTS

### Mobile Touch & Interaction
| Test | Action | Expected Result | Result | Notes |
|------|--------|----------------|--------|-------|
| M.1 | Tap hamburger menu | Sidebar opens smoothly | ⬜ | |
| M.2 | Tap menu item in sidebar | Page loads, sidebar closes (on mobile) | ⬜ | |
| M.3 | Tap "Settings" at bottom | Settings opens (stays at bottom) | ⬜ | |
| M.4 | Scroll long table horizontally | Table scrolls smoothly, header stays visible | ⬜ | |
| M.5 | Tap table row | Detail page opens | ⬜ | |
| M.6 | Tap three-dot menu (⋮) | Dropdown appears | ⬜ | |
| M.7 | Tap "View" or "Edit" in dropdown | Detail/edit page opens | ⬜ | |
| M.8 | Tap "← Back" button | Returns to list page | ⬜ | |
| M.9 | Use browser back button | Previous page loads | ⬜ | |
| M.10 | Rotate device (portrait ↔ landscape) | Layout adjusts properly | ⬜ | |

---

## 📊 TESTING SUMMARY

### Test Results Summary
- **Total Tests:** ____
- **Passed:** ____
- **Failed:** ____
- **Partial:** ____

### Critical Failures (MUST FIX BEFORE DEPLOYMENT)
1. _________________________________________________
2. _________________________________________________
3. _________________________________________________

### Non-Critical Issues (Can fix later)
1. _________________________________________________
2. _________________________________________________
3. _________________________________________________

### Overall Assessment
- ⬜ **READY FOR DEPLOYMENT** - All critical tests pass
- ⬜ **NOT READY** - Critical failures found
- ⬜ **READY WITH RESERVATIONS** - Minor issues only

### Tester Sign-Off
- **Tester Name:** _________________
- **Date:** _________________
- **Time Spent:** _____ minutes
- **Overall Impression:** _________________________________________________

---

## 🚨 REPORTING FAILURES

**If any test FAILS, report to developer with:**

1. **Test Number** (e.g., "6.13 - Purchase Order Status")
2. **What you did** (exact steps)
3. **What happened** (actual result)
4. **What should happen** (expected result)
5. **Screenshot** (if possible)
6. **Browser/Device** (e.g., "Chrome Desktop" or "iPhone Safari")

**Example:**
```
FAIL: Test 6.13 - Purchase Order Status
Steps: Opened Purchase Order #47
Expected: Status shows "Approved"
Actual: Status shows "Draft"
Browser: Chrome Desktop
Screenshot: [attach]
```

---

## ✅ DEPLOYMENT DECISION

**System Name:** Sakura Management Hub  
**Status:** ⬜ Not Ready / ⬜ Ready / ⬜ Ready with Reservations  
**Reviewed By:** _________________  
**Date:** _________________  

**Final Recommendation:** _________________________________________________
