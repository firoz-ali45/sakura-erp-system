# External Dashboards Setup Guide

## Problem
External HTML files (Accounts Payable, Forecasting, Warehouse) are in project root but Vue app can't serve them directly.

## Solution Options

### Option 1: Copy Files to Public Folder (Recommended)
1. Copy external dashboard folders to `frontend/public/`:
   ```
   frontend/public/
     ├── sakura-accounts-payable-dashboard/
     │   ├── payable.html
     │   ├── forecasting.html
     │   └── Warehouse.html
     └── inventory/
         ├── suppliers.html
         └── ...
   ```

2. Update iframe paths in `HomePortal.vue` to use `/sakura-accounts-payable-dashboard/payable.html`

### Option 2: Use Static File Server
Serve external files via Express backend or separate static server.

### Option 3: Convert to Vue Components
Migrate external HTML files to Vue components (long-term solution).

## Current Implementation
- Iframe paths use relative paths: `../../sakura-accounts-payable-dashboard/payable.html`
- This works if files are in project root relative to frontend build output
- For development, files need to be accessible from `frontend/` directory

## Quick Fix
Copy these folders to `frontend/public/`:
- `sakura-accounts-payable-dashboard/`
- `inventory/` (if contains HTML files)
- `quality-traceability/` (if exists)

Then update paths in `HomePortal.vue` to use `/` prefix instead of `../../`

