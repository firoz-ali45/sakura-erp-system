# FINAL DEPLOYMENT PLAN - Sakura ERP

You are ready to deploy the fixed ERP system.

## Step 1: Backend Fixes (CRITICAL)

**Status:** ⚠️ PENDING USER ACTION

1. Open your **Supabase Dashboard** -> **SQL Editor**.
2. Open the file: `COMPLETE_ROOT_CAUSE_FIX_FINAL.sql` (located in the root of your project).
3. **Run the entire script**.
    * This script enables the new `po_receipt_history` table.
    * It fixes the UUID vs BigInt mismatch.
    * It creates the automated triggers for PR -> PO -> GRN status tracking.

## Step 2: Frontend Deployment

**Status:** ✅ READY (Build Verified)

We have updated the frontend to:

* Use the new backend status fields (`receiving_status`).
* Correctly handle PR-to-PO conversion limits based on backend data.
* Enforce "SAP-style" logic for document flow.

### How to Deploy

1. Open a terminal in: `sakura-erp-migration/frontend`
2. Run the deployment script:

    ```powershell
    .\DEPLOY_TO_SURGE.ps1
    ```

3. Confirm "Y" when asked if you ran the SQL script.

## Step 3: Verify

Once deployed, check:

1. **Purchase Requests**: Verify a PR converts to PO correctly and status updates to `partially_ordered`.
2. **Purchase Orders**: Create a PO, receive items in GRN, and verify PO status changes to `partially_received` or `fully_received` automatically.
    * *Note: The status logic is now 100% database-driven.*

---
**System Status:**

* Frontend Build: **PASS** (Verified by Agent)
* Backend Scripts: **GENERATED** (Ready for execution)
