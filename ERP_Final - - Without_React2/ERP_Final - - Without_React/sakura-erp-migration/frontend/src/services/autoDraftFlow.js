/**
 * ==================================================
 * AUTO-DRAFT FLOW SERVICE
 * ==================================================
 * 
 * ISO 22000 / FSSC 22000 Compliant Business Logic
 * 
 * This service implements the correct business flow:
 * Purchase Order → GRN → Purchasing
 * 
 * PART 1: CORE BUSINESS RULES (LOCKED)
 * ==================================================
 * 1. One Purchase Order → Multiple GRNs (Allowed)
 * 2. One GRN → One Purchasing (Not allowed to split)
 * 3. Multiple GRNs → One Purchasing (Allowed)
 * 4. Purchasing can be created ONLY from Approved GRN(s)
 * 5. GRN can exist with or without PO (Direct / Market Purchase)
 * 
 * PART 2: PO → GRN AUTO-DRAFT LOGIC
 * ==================================================
 * When a Purchase Order reaches FINAL APPROVAL:
 * - Automatically create a GRN in DRAFT status
 * - Link this GRN to the approved PO
 * - Auto-fill GRN from PO data
 * - GRN remains editable
 * - GRN does NOT auto-approve
 * - GRN does NOT auto-create batches
 * 
 * PART 3: GRN → PURCHASING AUTO-DRAFT LOGIC
 * ==================================================
 * When a GRN reaches FINAL APPROVAL:
 * - Prepare Purchasing Draft Payload (NO UI)
 * - Do NOT create actual Purchasing record yet
 * - Only APPROVED GRNs can flow into Purchasing
 * - Rejected or Partial GRNs are blocked
 * 
 * PART 4: DIRECT / MARKET PURCHASE FLOW
 * ==================================================
 * Allow GRN creation WITHOUT PO:
 * - GRN Type = Direct / Market Purchase
 * - Supplier mandatory
 * - PO Reference = NULL
 * - When approved, prepare Purchasing Draft Payload
 */

import { 
  saveGRNToSupabase, 
  loadGRNsFromSupabase,
  updateGRNInSupabase,
  USE_SUPABASE,
  supabaseClient
} from './supabase.js';
import { 
  updatePurchaseOrderInSupabase,
  getPurchaseOrderById 
} from './supabase.js';

// ==================================================
// PART 2: PO → GRN AUTO-DRAFT CREATION
// ==================================================

/**
 * Auto-create GRN Draft when PO is approved
 * 
 * BUSINESS RULE: When PO reaches final approval, automatically create
 * a GRN in DRAFT status linked to the approved PO.
 * 
 * ISO LOGIC: This separates commercial commitment (PO) from physical
 * receipt (GRN), allowing multiple deliveries per PO.
 * 
 * @param {Object} purchaseOrder - The approved purchase order
 * @returns {Promise<Object>} - Result with created GRN data
 */
export async function createGRNDraftFromPO(purchaseOrder) {
  try {
    console.log('🔄 Auto-creating GRN Draft from PO:', purchaseOrder.poNumber || purchaseOrder.po_number);
    
    // Validate PO is approved or partially_received
    const poStatus = (purchaseOrder.status || '').toLowerCase();
    if (poStatus !== 'approved' && poStatus !== 'partially_received') {
      console.warn('⚠️ PO is not approved or partially received, skipping GRN draft creation');
      return { 
        success: false, 
        error: 'Purchase order must be approved or partially received to create GRN draft' 
      };
    }
    
    // Check if GRN already exists for this PO
    const existingGRNs = await loadGRNsFromSupabase();
    const poId = purchaseOrder.id;
    const existingGRN = existingGRNs.find(grn => {
      const grnPOId = grn.purchaseOrderId || grn.purchase_order_id;
      return grnPOId === poId && (grn.status === 'draft' || grn.status === 'under_inspection');
    });
    
    if (existingGRN) {
      console.log('ℹ️ GRN draft already exists for this PO:', existingGRN.grnNumber || existingGRN.grn_number);
      return { 
        success: true, 
        data: existingGRN, 
        message: 'GRN draft already exists' 
      };
    }
    
    // Extract supplier information
    const supplier = purchaseOrder.supplier || {};
    const supplierName = supplier.name || purchaseOrder.supplierName || 'N/A';
    const supplierId = purchaseOrder.supplierId || purchaseOrder.supplier_id;
    
    // For partially_received POs, calculate remaining quantities
    // Get all existing GRNs for this PO to calculate already received quantities
    const allGRNsForPO = existingGRNs.filter(grn => {
      const grnPOId = grn.purchaseOrderId || grn.purchase_order_id;
      return grnPOId === poId && (grn.status === 'approved' || grn.status === 'under_inspection');
    });
    
    // Calculate total received quantity per item from existing GRNs
    const itemReceivedQty = {};
    allGRNsForPO.forEach(grn => {
      (grn.items || []).forEach(grnItem => {
        const itemId = grnItem.itemId || grnItem.item_id;
        const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
        if (!itemReceivedQty[itemId]) {
          itemReceivedQty[itemId] = 0;
        }
        itemReceivedQty[itemId] += receivedQty;
      });
    });
    
    // Extract PO items and map to GRN items
    const poItems = purchaseOrder.items || [];
    
    console.log('📦 PO Items Array:', JSON.stringify(poItems, null, 2));
    
    if (!poItems || poItems.length === 0) {
      console.warn('⚠️ PO has no items');
      return {
        success: false,
        error: 'Purchase order has no items to create GRN'
      };
    }
    
    console.log('📦 PO Items:', poItems.length, 'items found');
    
    // Load inventory items if needed to get item details
    const { loadItemsFromSupabase } = await import('./supabase.js');
    const allInventoryItems = await loadItemsFromSupabase();
    
    const grnItems = poItems
      .map((poItem, index) => {
        console.log(`📦 Processing PO Item ${index + 1}:`, JSON.stringify(poItem, null, 2));
        
        // Try multiple ways to get itemId - CRITICAL for foreign key relationship
        let itemId = poItem.itemId || poItem.item_id || null;
        
        // If itemId not directly in poItem, try to get from item relationship
        if (!itemId && poItem.item) {
          itemId = poItem.item.id || poItem.item.itemId || poItem.item.item_id || null;
          console.log(`📦 Extracted itemId from item relationship: ${itemId}`);
        }
        
        // If still no itemId, try to find item by code/name in inventory
        if (!itemId && (poItem.itemCode || poItem.item_code || poItem.itemName || poItem.item_name)) {
          const itemCode = poItem.itemCode || poItem.item_code || poItem.item?.code || poItem.item?.sku;
          const itemName = poItem.itemName || poItem.item_name || poItem.item?.name;
          
          if (itemCode) {
            const foundItem = allInventoryItems.find(i => 
              (i.code && i.code === itemCode) || 
              (i.sku && i.sku === itemCode)
            );
            if (foundItem) {
              itemId = foundItem.id;
              console.log(`✅ Found item by code: ${itemCode} → itemId: ${itemId}`);
            }
          }
          
          if (!itemId && itemName) {
            const foundItem = allInventoryItems.find(i => i.name === itemName);
            if (foundItem) {
              itemId = foundItem.id;
              console.log(`✅ Found item by name: ${itemName} → itemId: ${itemId}`);
            }
          }
        }
        
        if (!itemId) {
          console.error(`❌ CRITICAL: PO Item ${index + 1} missing itemId!`, {
            poItem: poItem,
            hasItemObject: !!poItem.item,
            itemCode: poItem.itemCode || poItem.item_code,
            itemName: poItem.itemName || poItem.item_name
          });
          // CRITICAL: Without itemId, foreign key relationship won't work
          // But we'll still try to save with null itemId for now
          console.warn('⚠️ Continuing without itemId - item relationship may not work');
        } else {
          console.log(`✅ PO Item ${index + 1} has itemId: ${itemId}`);
        }
        
        // Get item details from inventory items if not in poItem.item
        let item = poItem.item || {};
        if ((!item.id || !item.storageUnit) && itemId) {
          const inventoryItem = allInventoryItems.find(i => i.id === itemId);
          if (inventoryItem) {
            item = inventoryItem;
            console.log(`✅ Found inventory item for ${itemId}:`, item.name || item.code);
          } else {
            console.warn(`⚠️ Inventory item not found for ${itemId}`);
          }
        }
        
        // Try multiple ways to get ordered quantity
        const orderedQty = parseFloat(
          poItem.quantity || 
          poItem.orderedQuantity || 
          poItem.ordered_quantity || 
          poItem.qty ||
          0
        );
        
        if (orderedQty <= 0) {
          console.warn(`⚠️ Item ${itemId || 'unknown'} has invalid ordered quantity: ${orderedQty}`);
          // For new POs, if quantity is 0, still allow GRN creation but use a default
          // This handles edge cases where quantity might not be set properly
        }
        
        const alreadyReceivedQty = itemId ? (itemReceivedQty[itemId] || 0) : 0;
        const remainingQty = orderedQty > 0 ? (orderedQty - alreadyReceivedQty) : orderedQty;
        
        console.log(`📦 Item ${itemId || 'unknown'}: Ordered=${orderedQty}, AlreadyReceived=${alreadyReceivedQty}, Remaining=${remainingQty}`);
        
        // For new POs (no existing GRNs), remainingQty should equal orderedQty
        // Only skip if we're sure it's fully received (remainingQty <= 0 AND orderedQty > 0)
        if (remainingQty <= 0 && orderedQty > 0) {
          console.log(`⏭️ Skipping item ${itemId || 'unknown'} - fully received (Ordered: ${orderedQty}, Received: ${alreadyReceivedQty})`);
          return null;
        }
        
        // If orderedQty is 0 or missing, use the PO item quantity as fallback
        const finalOrderedQty = orderedQty > 0 ? orderedQty : (parseFloat(poItem.quantity) || 0);
        const finalReceivedQty = remainingQty > 0 ? remainingQty : finalOrderedQty;
        
        // Get unit from database - use storageUnit from item record
        // IMPORTANT: Unit must come from database, not hardcoded
        const unit = item.storageUnit || item.storage_unit || item.ingredientUnit || item.ingredient_unit || item.unit || 'Pcs';
        
        return {
          itemId: itemId,
          item: item, // Full item object for reference
          itemCode: item.code || item.sku || poItem.itemCode || poItem.item_code || null,
          item_code: item.code || item.sku || poItem.itemCode || poItem.item_code || null,
          itemName: item.name || poItem.itemName || poItem.item_name || null,
          item_name: item.name || poItem.itemName || poItem.item_name || null,
          itemDescription: item.description || poItem.itemDescription || poItem.item_description || null,
          item_description: item.description || poItem.itemDescription || poItem.item_description || null,
          unit: unit, // Unit from database (storageUnit/storage_unit)
          orderedQuantity: finalOrderedQty,
          ordered_quantity: finalOrderedQty,
          receivedQuantity: finalReceivedQty, // Set to remaining quantity for partially received
          received_quantity: finalReceivedQty,
          packagingType: 'Good', // Default to 'Good' (valid constraint value)
          packaging_type: 'Good',
          packagingCondition: 'Good', // Also set packagingCondition for consistency
          packaging_condition: 'Good',
          supplierLotNumber: '', // Empty, to be filled during receiving
          supplier_lot_number: '',
          visualInspectionResult: '', // Empty, pending inspection
          visual_inspection_result: ''
        };
      })
      .filter(item => item !== null); // Remove null items (fully received)
    
    console.log('📦 GRN Items after processing:', grnItems.length, 'items');
    console.log('📦 GRN Items details:', JSON.stringify(grnItems, null, 2));
    
    // Check if there are any items left to receive
    if (grnItems.length === 0) {
      console.error('❌ No GRN items created. PO Items:', poItems.length);
      console.error('❌ Item received quantities:', itemReceivedQty);
      return {
        success: false,
        error: 'All items for this purchase order have already been received or no valid items found'
      };
    }
    
    // CRITICAL FIX: Fetch PO UUID before creating GRN (never send numeric ID)
    // GRN table requires UUID, not numeric IDs (e.g., 48 → UUID)
    let poUuid = poId;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const isNumericId = typeof poId === 'number' || (typeof poId === 'string' && /^\d+$/.test(poId));
    
    if (isNumericId || !uuidRegex.test(poId)) {
      console.warn('⚠️ PO ID is numeric or not UUID format, looking up UUID from Supabase...', poId);
      
      if (USE_SUPABASE && supabaseClient) {
        try {
          // Try lookup by po_number first (most reliable)
          const poNumber = purchaseOrder.poNumber || purchaseOrder.po_number;
          if (poNumber) {
            const { data: poRecord, error: poError } = await supabaseClient
              .from('purchase_orders')
              .select('id')
              .eq('po_number', poNumber)
              .single();
            
            if (!poError && poRecord?.id) {
              poUuid = poRecord.id;
              console.log('✅ Found PO UUID by po_number:', poUuid);
            } else {
              console.warn('⚠️ Could not find PO by po_number:', poError?.message);
              // Fallback: try lookup by numeric ID as string (if table has numeric id column)
              // This is unlikely for Supabase (uses UUID), but try anyway
              const { data: poRecordAlt, error: poErrorAlt } = await supabaseClient
                .from('purchase_orders')
                .select('id')
                .eq('id', String(poId))
                .single();
              
              if (!poErrorAlt && poRecordAlt?.id) {
                poUuid = poRecordAlt.id;
                console.log('✅ Found PO UUID by numeric ID:', poUuid);
              } else {
                console.error('❌ PO UUID lookup failed:', poErrorAlt?.message || 'No record found');
                throw new Error(`PO UUID lookup failed: Could not find PO with number "${poNumber}" or ID "${poId}"`);
              }
            }
          } else {
            console.error('❌ No po_number available for UUID lookup');
            throw new Error('PO UUID lookup failed: No po_number available');
          }
        } catch (lookupError) {
          console.error('❌ Error looking up PO UUID:', lookupError);
          throw new Error(`PO UUID lookup failed: ${lookupError.message || 'Unknown error'}`);
        }
      } else {
        console.error('❌ Supabase not available for UUID lookup');
        throw new Error('PO UUID lookup failed: Supabase not available');
      }
    } else {
      console.log('✅ PO ID is already UUID format:', poUuid);
    }
    
    // Create GRN Draft payload
    // grn_inspections.purchase_order_id is BIGINT (FK to purchase_orders.id). Send PO id so document_flow trigger gets non-null source_id.
    const poNumber = purchaseOrder.poNumber || purchaseOrder.po_number;
    const poIdForDb = purchaseOrder.id != null ? (typeof purchaseOrder.id === 'number' ? purchaseOrder.id : parseInt(purchaseOrder.id, 10)) : null;
    
    const grnDraft = {
      // GRN Header - Auto-filled from PO
      purchaseOrderId: poIdForDb,
      purchase_order_id: poIdForDb,
      purchaseOrderReference: poNumber,
      purchase_order_reference: poNumber,
      purchase_order_number: poNumber,
      purchaseOrderNumber: poNumber,
      poNumber: poNumber,
      po_number: poNumber,
      supplier: supplierName,
      supplierId: supplierId,
      supplier_id: supplierId,
      receivingLocation: purchaseOrder.destination || '',
      receiving_location: purchaseOrder.destination || '',
      externalReferenceId: purchaseOrder.externalReferenceId || purchaseOrder.external_reference_id || '',
      external_reference_id: purchaseOrder.externalReferenceId || purchaseOrder.external_reference_id || '',
      
      // GRN Status - Always DRAFT on auto-creation
      status: 'draft',
      grnNumber: '', // Will be generated on "Submit For Inspection"
      grn_number: '',
      
      // GRN Date - Default to today, editable
      grnDate: new Date().toISOString().split('T')[0],
      grn_date: new Date().toISOString().split('T')[0],
      
      // Items - Mapped from PO items
      items: grnItems,
      
      // Metadata
      // Note: "Received By" will be auto-filled with current user when GRN is saved
      // This is handled in the component, not here in the draft creation
      receivedBy: '', // Will be auto-filled with current user on save
      received_by: '',
      supplierInvoiceNumber: '',
      supplier_invoice_number: '',
      deliveryNoteNumber: '',
      delivery_note_number: '',
      qcCheckedBy: '',
      qc_checked_by: '',
      
      // Timestamps
      createdAt: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      
      // ISO 22000: Mark as auto-created from PO
      source: 'po_auto_draft',
      isMarketPurchase: false
    };
    
    console.log('📝 GRN Draft payload prepared:', {
      purchaseOrderId: grnDraft.purchaseOrderId,
      supplier: grnDraft.supplier,
      itemsCount: grnDraft.items.length,
      status: grnDraft.status
    });
    console.log('📝 GRN Draft items:', JSON.stringify(grnDraft.items, null, 2));
    
    // CRITICAL: Verify items have itemId before saving
    const itemsWithItemId = grnDraft.items.filter(item => item.itemId || item.item_id);
    const itemsWithoutItemId = grnDraft.items.filter(item => !item.itemId && !item.item_id);
    
    if (itemsWithoutItemId.length > 0) {
      console.warn('⚠️ Some items missing itemId:', itemsWithoutItemId.length, 'items');
      itemsWithoutItemId.forEach((item, idx) => {
        console.warn(`⚠️ Item ${idx + 1} missing itemId:`, {
          itemName: item.itemName || item.item_name,
          itemCode: item.itemCode || item.item_code,
          hasItemObject: !!item.item
        });
      });
    }
    
    console.log('✅ Items with itemId:', itemsWithItemId.length, 'out of', grnDraft.items.length);
    
    // Save GRN Draft
    console.log('💾 Saving GRN Draft to Supabase with', grnDraft.items.length, 'items...');
    const result = await saveGRNToSupabase(grnDraft);
    
    console.log('📝 Save result:', result);
    
    if (result.success) {
      console.log('✅ GRN Draft auto-created from PO:', result.data?.grnNumber || result.data?.grn_number || 'Draft');
      console.log('✅ GRN ID:', result.data?.id);
      
      // Update PO status to reflect GRN creation (optional - for tracking)
      // Note: PO status logic is handled separately in updatePOStatusBasedOnGRNs
      
      return {
        success: true,
        data: result.data,
        message: 'GRN draft created successfully from approved PO'
      };
    } else {
      const errorMsg = result.error || 'Failed to create GRN draft';
      console.error('❌ GRN Draft save failed:', errorMsg);
      console.error('❌ Error details:', result.details);
      console.error('❌ Error hint:', result.hint);
      throw new Error(errorMsg);
    }
  } catch (error) {
    console.error('❌ Error creating GRN draft from PO:', error);
    console.error('❌ Error stack:', error.stack);
    return {
      success: false,
      error: error.message || 'Failed to create GRN draft from PO',
      details: error.details || null,
      hint: error.hint || null
    };
  }
}

/**
 * Update PO status based on GRN status
 * 
 * BUSINESS RULE:
 * - Approved + No GRN → Approved
 * - Approved + Partial GRN → Partially Received
 * - Approved + Full GRN(s) → Fully Received
 * 
 * @param {string} poId - Purchase Order ID
 * @returns {Promise<Object>} - Updated PO with new status
 */
export async function updatePOStatusBasedOnGRNs(poId) {
  try {
    const po = await getPurchaseOrderById(poId);
    if (!po || !po.success) {
      return { success: false, error: 'Purchase order not found' };
    }
    
    const purchaseOrder = po.data;
    const poStatus = (purchaseOrder.status || '').toLowerCase();
    
    // Only update status for approved or partially_received POs
    if (poStatus !== 'approved' && poStatus !== 'partially_received') {
      return { success: true, data: purchaseOrder };
    }
    
    // Get all GRNs for this PO
    const allGRNs = await loadGRNsFromSupabase();
    const poIdStr = String(poId).trim(); // Ensure string comparison for UUID
    const grnsForPO = allGRNs.filter(grn => {
      const grnPOId = grn.purchaseOrderId || grn.purchase_order_id;
      const grnPOIdStr = grnPOId ? String(grnPOId).trim() : null;
      return grnPOIdStr === poIdStr;
    });
    
    if (grnsForPO.length === 0) {
      // No GRNs yet - keep status as "approved"
      return { success: true, data: purchaseOrder };
    }
    
    // Calculate received quantities per item
    const poItems = purchaseOrder.items || [];
    const itemReceivedQty = {};
    
    // Calculate received quantities from all GRNs (excluding rejected/cancelled)
    grnsForPO.forEach(grn => {
      const grnStatus = (grn.status || '').toLowerCase();
      // Include all GRN statuses except rejected and cancelled
      if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
        const grnItems = grn.items || [];
        grnItems.forEach(grnItem => {
          const itemId = grnItem.itemId || grnItem.item_id;
          if (!itemReceivedQty[itemId]) {
            itemReceivedQty[itemId] = 0;
          }
          itemReceivedQty[itemId] += parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
        });
      }
    });
    
    // Check if all items are fully received
    let allFullyReceived = true;
    let hasPartialReceipt = false;
    
    poItems.forEach(poItem => {
      const itemId = poItem.itemId || poItem.item_id;
      const orderedQty = parseFloat(poItem.quantity || 0);
      const receivedQty = itemReceivedQty[itemId] || 0;
      
      if (receivedQty < orderedQty) {
        allFullyReceived = false;
        if (receivedQty > 0) {
          hasPartialReceipt = true;
        }
      }
    });
    
    // Determine new status
    let newStatus = purchaseOrder.status;
    if (allFullyReceived && grnsForPO.some(g => g.status === 'approved' || g.status === 'passed')) {
      // When all items are fully received, close the PO
      newStatus = 'closed';
    } else if (hasPartialReceipt) {
      newStatus = 'partially_received';
    }
    
    // Update PO status if changed
    if (newStatus !== purchaseOrder.status) {
      const updateResult = await updatePurchaseOrderInSupabase(poId, {
        ...purchaseOrder,
        status: newStatus
      });
      
      if (updateResult.success) {
        console.log(`✅ PO status updated: ${purchaseOrder.status} → ${newStatus}`);
        return { success: true, data: updateResult.data };
      }
    }
    
    return { success: true, data: purchaseOrder };
  } catch (error) {
    console.error('❌ Error updating PO status based on GRNs:', error);
    return { success: false, error: error.message };
  }
}

// ==================================================
// PART 3: GRN → PURCHASING AUTO-DRAFT PAYLOAD
// ==================================================

/**
 * Prepare Purchasing Draft Payload when GRN is approved
 * 
 * BUSINESS RULE: When GRN reaches final approval, prepare a Purchasing
 * Draft Payload (data structure) but DO NOT create actual Purchasing record.
 * 
 * ISO LOGIC: This separates physical receipt (GRN) from accounting
 * (Purchasing), allowing multiple GRNs to be merged into one Purchasing.
 * 
 * @param {Object} grn - The approved GRN
 * @returns {Promise<Object>} - Purchasing Draft Payload
 */
export async function preparePurchasingDraftFromGRN(grn) {
  try {
    console.log('🔄 Preparing Purchasing Draft Payload from approved GRN:', grn.grnNumber || grn.grn_number);
    
    // Validate GRN is approved
    const grnStatus = (grn.status || '').toLowerCase();
    if (grnStatus !== 'approved') {
      console.warn('⚠️ GRN is not approved, cannot prepare Purchasing draft');
      return {
        success: false,
        error: 'GRN must be approved to prepare Purchasing draft'
      };
    }
    
    // Extract supplier information
    const supplier = grn.supplier || {};
    const supplierName = typeof supplier === 'string' ? supplier : (supplier.name || 'N/A');
    const supplierId = grn.supplierId || grn.supplier_id;
    
    // Extract PO reference if exists
    const poReference = grn.purchaseOrderReference || grn.purchase_order_reference || null;
    const poId = grn.purchaseOrderId || grn.purchase_order_id || null;
    
    // Calculate approved batch quantities
    const batches = grn.batches || [];
    const approvedBatches = batches.filter(b => {
      const qcStatus = b.qcStatus || b.qc_status;
      return qcStatus === 'approved';
    });
    
    const batchQuantities = approvedBatches.map(batch => ({
      batchId: batch.id,
      batch_id: batch.id,
      batchNumber: batch.batch_number || batch.batchNumber,
      batch_number: batch.batch_number || batch.batchNumber,
      itemId: batch.itemId || batch.item_id,
      item: batch.item || {},
      quantity: parseFloat(batch.batchQuantity || batch.batch_quantity || 0),
      expiryDate: batch.expiryDate || batch.expiry_date,
      expiry_date: batch.expiryDate || batch.expiry_date,
      storageLocation: batch.storageLocation || batch.storage_location,
      storage_location: batch.storageLocation || batch.storage_location
    }));
    
    // Calculate total quantities per item from approved batches
    const itemQuantities = {};
    approvedBatches.forEach(batch => {
      const itemId = batch.itemId || batch.item_id;
      if (!itemQuantities[itemId]) {
        itemQuantities[itemId] = {
          itemId: itemId,
          item: batch.item || {},
          totalQuantity: 0,
          batches: []
        };
      }
      itemQuantities[itemId].totalQuantity += parseFloat(batch.batchQuantity || batch.batch_quantity || 0);
      itemQuantities[itemId].batches.push(batch.id);
    });
    
    // Create Purchasing Draft Payload
    const purchasingDraftPayload = {
      // Source Information
      source: grn.isMarketPurchase ? 'direct_grn' : 'po_grn',
      grnId: grn.id,
      grn_id: grn.id,
      grnNumber: grn.grnNumber || grn.grn_number,
      grn_number: grn.grnNumber || grn.grn_number,
      grnDate: grn.grnDate || grn.grn_date,
      grn_date: grn.grnDate || grn.grn_date,
      
      // PO Reference (if exists)
      purchaseOrderId: poId,
      purchase_order_id: poId,
      purchaseOrderReference: poReference,
      purchase_order_reference: poReference,
      
      // Supplier Information
      supplier: supplierName,
      supplierId: supplierId,
      supplier_id: supplierId,
      
      // Financial Fields (blank, to be filled later)
      invoiceAmount: null,
      invoice_amount: null,
      invoiceNumber: '',
      invoice_number: '',
      taxAmount: null,
      tax_amount: null,
      taxRate: null,
      tax_rate: null,
      totalAmount: null,
      total_amount: null,
      
      // Purchasing Status
      status: 'draft',
      
      // Approved Quantities from GRN
      items: Object.values(itemQuantities).map(itemQty => ({
        itemId: itemQty.itemId,
        item_id: itemQty.itemId,
        item: itemQty.item,
        approvedQuantity: itemQty.totalQuantity,
        approved_quantity: itemQty.totalQuantity,
        batchIds: itemQty.batches,
        batch_ids: itemQty.batches
      })),
      
      // Batch Details
      batches: batchQuantities,
      
      // Metadata
      receivingLocation: grn.receivingLocation || grn.receiving_location,
      receiving_location: grn.receivingLocation || grn.receiving_location,
      receivedBy: grn.receivedBy || grn.received_by,
      received_by: grn.receivedBy || grn.received_by,
      qcCheckedBy: grn.qcCheckedBy || grn.qc_checked_by,
      qc_checked_by: grn.qcCheckedBy || grn.qc_checked_by,
      
      // Timestamps
      createdAt: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      
      // ISO 22000: Mark as prepared from GRN (not yet created)
      isDraftPayload: true,
      readyForPurchasingCreation: true
    };
    
    // Store in localStorage for now (will be moved to database when Purchasing module is built)
    try {
      const existingPayloads = JSON.parse(localStorage.getItem('sakura_purchasing_draft_payloads') || '[]');
      const existingIndex = existingPayloads.findIndex(p => p.grnId === grn.id);
      
      if (existingIndex >= 0) {
        existingPayloads[existingIndex] = purchasingDraftPayload;
      } else {
        existingPayloads.push(purchasingDraftPayload);
      }
      
      localStorage.setItem('sakura_purchasing_draft_payloads', JSON.stringify(existingPayloads));
      console.log('✅ Purchasing Draft Payload prepared and stored');
    } catch (storageError) {
      console.warn('⚠️ Could not store Purchasing Draft Payload in localStorage:', storageError);
    }
    
    return {
      success: true,
      data: purchasingDraftPayload,
      message: 'Purchasing draft payload prepared successfully'
    };
  } catch (error) {
    console.error('❌ Error preparing Purchasing draft from GRN:', error);
    return {
      success: false,
      error: error.message || 'Failed to prepare Purchasing draft from GRN'
    };
  }
}

/**
 * Get all Purchasing Draft Payloads (for future Purchasing module)
 * 
 * @returns {Promise<Array>} - Array of Purchasing Draft Payloads
 */
export async function getPurchasingDraftPayloads() {
  try {
    const payloads = JSON.parse(localStorage.getItem('sakura_purchasing_draft_payloads') || '[]');
    return {
      success: true,
      data: payloads
    };
  } catch (error) {
    console.error('❌ Error getting Purchasing Draft Payloads:', error);
    return {
      success: false,
      error: error.message,
      data: []
    };
  }
}

/**
 * Merge multiple GRN-based Purchasing Draft Payloads
 * 
 * BUSINESS RULE: Multiple GRNs can be merged into ONE Purchasing.
 * This function prepares a merged payload from multiple approved GRNs.
 * 
 * @param {Array<string>} grnIds - Array of GRN IDs to merge
 * @returns {Promise<Object>} - Merged Purchasing Draft Payload
 */
export async function mergePurchasingDraftPayloads(grnIds) {
  try {
    const allGRNs = await loadGRNsFromSupabase();
    const grnsToMerge = allGRNs.filter(grn => grnIds.includes(grn.id));
    
    // Validate all GRNs are approved
    const unapprovedGRNs = grnsToMerge.filter(grn => {
      const status = (grn.status || '').toLowerCase();
      return status !== 'approved';
    });
    
    if (unapprovedGRNs.length > 0) {
      return {
        success: false,
        error: 'All GRNs must be approved to merge into Purchasing'
      };
    }
    
    // Prepare individual payloads
    const payloads = [];
    for (const grn of grnsToMerge) {
      const payloadResult = await preparePurchasingDraftFromGRN(grn);
      if (payloadResult.success) {
        payloads.push(payloadResult.data);
      }
    }
    
    if (payloads.length === 0) {
      return {
        success: false,
        error: 'No valid payloads to merge'
      };
    }
    
    // Merge payloads (assuming same supplier - validation should be done in UI)
    const mergedPayload = {
      source: 'merged_grns',
      grnIds: grnIds,
      grn_ids: grnIds,
      grnNumbers: payloads.map(p => p.grnNumber || p.grn_number),
      grn_numbers: payloads.map(p => p.grnNumber || p.grn_number),
      
      // Use first payload's supplier (UI should validate all are same)
      supplier: payloads[0].supplier,
      supplierId: payloads[0].supplierId,
      supplier_id: payloads[0].supplier_id,
      
      // Merge items
      items: [],
      batches: [],
      
      // Financial fields (blank)
      invoiceAmount: null,
      invoice_amount: null,
      taxAmount: null,
      tax_amount: null,
      totalAmount: null,
      total_amount: null,
      
      status: 'draft',
      isDraftPayload: true,
      readyForPurchasingCreation: true,
      isMerged: true,
      mergedFrom: grnIds
    };
    
    // Merge items and batches
    const mergedItems = {};
    payloads.forEach(payload => {
      (payload.items || []).forEach(item => {
        const itemId = item.itemId || item.item_id;
        if (!mergedItems[itemId]) {
          mergedItems[itemId] = {
            itemId: itemId,
            item_id: itemId,
            item: item.item,
            approvedQuantity: 0,
            approved_quantity: 0,
            batchIds: [],
            batch_ids: []
          };
        }
        mergedItems[itemId].approvedQuantity += item.approvedQuantity || item.approved_quantity || 0;
        mergedItems[itemId].batchIds.push(...(item.batchIds || item.batch_ids || []));
      });
      
      (payload.batches || []).forEach(batch => {
        mergedPayload.batches.push(batch);
      });
    });
    
    mergedPayload.items = Object.values(mergedItems);
    
    return {
      success: true,
      data: mergedPayload,
      message: `Merged ${payloads.length} GRN(s) into Purchasing draft`
    };
  } catch (error) {
    console.error('❌ Error merging Purchasing Draft Payloads:', error);
    return {
      success: false,
      error: error.message || 'Failed to merge Purchasing Draft Payloads'
    };
  }
}

// ==================================================
// PART 4: DIRECT / MARKET PURCHASE FLOW
// ==================================================

/**
 * Prepare Purchasing Draft Payload from Direct GRN (no PO)
 * 
 * BUSINESS RULE: Direct/Market Purchase GRNs can also flow into Purchasing
 * when approved. Same logic as PO-based GRNs, but without PO reference.
 * 
 * @param {Object} grn - The approved Direct GRN
 * @returns {Promise<Object>} - Purchasing Draft Payload
 */
export async function preparePurchasingDraftFromDirectGRN(grn) {
  // Direct GRN uses the same logic, just mark source differently
  const result = await preparePurchasingDraftFromGRN(grn);
  
  if (result.success && result.data) {
    result.data.source = 'direct_grn';
    result.data.isMarketPurchase = true;
    result.data.purchaseOrderId = null;
    result.data.purchase_order_id = null;
    result.data.purchaseOrderReference = null;
    result.data.purchase_order_reference = null;
  }
  
  return result;
}

// ==================================================
// HOOKS & EVENT HANDLERS
// ==================================================

/**
 * Hook: Called when PO is approved
 * Auto-creates GRN Draft
 * 
 * @param {Object} purchaseOrder - The approved purchase order
 */
export async function onPOApproved(purchaseOrder) {
  console.log('📋 PO Approved Hook Triggered:', purchaseOrder.poNumber || purchaseOrder.po_number);
  
  // Auto-create GRN Draft
  const grnResult = await createGRNDraftFromPO(purchaseOrder);
  
  if (grnResult.success) {
    console.log('✅ GRN Draft auto-created from approved PO');
    return {
      success: true,
      grnDraft: grnResult.data,
      message: 'GRN draft created automatically from approved PO'
    };
  } else {
    console.error('❌ Failed to auto-create GRN Draft:', grnResult.error);
    return {
      success: false,
      error: grnResult.error
    };
  }
}

/**
 * Hook: Called when GRN is approved
 * Prepares Purchasing Draft Payload
 * 
 * @param {Object} grn - The approved GRN
 */
export async function onGRNApproved(grn) {
  console.log('📦 GRN Approved Hook Triggered:', grn.grnNumber || grn.grn_number);
  
  // Prepare Purchasing Draft Payload
  const purchasingResult = await preparePurchasingDraftFromGRN(grn);
  
  if (purchasingResult.success) {
    console.log('✅ Purchasing Draft Payload prepared from approved GRN');
    
    // Update PO status if GRN is linked to PO
    if (grn.purchaseOrderId || grn.purchase_order_id) {
      await updatePOStatusBasedOnGRNs(grn.purchaseOrderId || grn.purchase_order_id);
    }
    
    return {
      success: true,
      purchasingDraftPayload: purchasingResult.data,
      message: 'Purchasing draft payload prepared. Ready for Purchasing module creation.'
    };
  } else {
    console.error('❌ Failed to prepare Purchasing Draft Payload:', purchasingResult.error);
    return {
      success: false,
      error: purchasingResult.error
    };
  }
}

/**
 * Hook: Called when GRN status changes
 * Updates related PO status if needed
 * 
 * @param {Object} grn - The GRN with updated status
 */
export async function onGRNStatusChanged(grn) {
  const grnStatus = (grn.status || '').toLowerCase();
  
  // If GRN is approved, prepare Purchasing Draft Payload
  if (grnStatus === 'approved') {
    return await onGRNApproved(grn);
  }
  
  // Update PO status based on GRN status
  if (grn.purchaseOrderId || grn.purchase_order_id) {
    await updatePOStatusBasedOnGRNs(grn.purchaseOrderId || grn.purchase_order_id);
  }
  
  return { success: true };
}

// ==================================================
// EXPORTS
// ==================================================

export default {
  // PO → GRN Flow
  createGRNDraftFromPO,
  updatePOStatusBasedOnGRNs,
  onPOApproved,
  
  // GRN → Purchasing Flow
  preparePurchasingDraftFromGRN,
  preparePurchasingDraftFromDirectGRN,
  getPurchasingDraftPayloads,
  mergePurchasingDraftPayloads,
  onGRNApproved,
  onGRNStatusChanged
};

