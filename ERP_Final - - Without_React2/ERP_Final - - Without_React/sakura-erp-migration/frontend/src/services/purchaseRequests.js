// ============================================================================
// SAKURA ERP - PURCHASE REQUEST SERVICE LAYER
// Supabase API Integration for PR Module
// ============================================================================

import { supabaseClient, ensureSupabaseReady, USE_SUPABASE } from './supabase';
import { cachedFetch, cacheKeys, invalidateCache } from '@/utils/dataCache';
import { canCreateNextDocument } from '@/services/erpViews.js';

// Cache key for purchase requests
const PR_CACHE_KEY = 'sakura_purchase_requests';
const PR_CACHE_DURATION = 30000; // 30 seconds

// ============================================================================
// PURCHASE REQUEST CRUD OPERATIONS
// ============================================================================

/**
 * Get all purchase requests with optional filters
 * @param {Object} filters - Optional filters (status, department, requester_id)
 * @returns {Promise<Array>} List of purchase requests
 */
export async function getPurchaseRequests(filters = {}) {
  console.log('============ getPurchaseRequests START ============');
  console.log('Filters:', filters);
  
  const ready = await ensureSupabaseReady();
  console.log('Supabase ready:', ready);
  
  if (ready) {
    try {
      // STEP 1: Fetch PRs without joins (to avoid PGRST201 embed error)
      let query = supabaseClient
        .from('purchase_requests')
        .select('*')
        .eq('deleted', false)
        .order('created_at', { ascending: false });
      
      // Apply filters
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      if (filters.department) {
        query = query.eq('department', filters.department);
      }
      if (filters.requester_id) {
        query = query.eq('requester_id', filters.requester_id);
      }
      if (filters.priority) {
        query = query.eq('priority', filters.priority);
      }
      if (filters.from_date) {
        query = query.gte('business_date', filters.from_date);
      }
      if (filters.to_date) {
        query = query.lte('business_date', filters.to_date);
      }
      
      const { data: prs, error: prError } = await query;
      
      if (prError) {
        console.error('========== PR FETCH ERROR ==========');
        console.error('Error code:', prError.code);
        console.error('Error message:', prError.message);
        console.error('Error details:', prError.details);
        console.error('=====================================');
        return [];
      }
      
      console.log('PRs fetched:', prs?.length || 0);
      
      // STEP 2: Fetch items separately and merge
      let processedData = prs || [];
      
      if (processedData.length > 0) {
        const prIds = processedData.map(pr => pr.id);
        
        // Fetch PR items
        const { data: items, error: itemError } = await supabaseClient
          .from('purchase_request_items')
          .select('id, pr_id, item_number, item_id, item_name, quantity, quantity_ordered, quantity_remaining, unit, estimated_price, status, po_id, po_number')
          .in('pr_id', prIds)
          .eq('deleted', false);
        
        // Linked PO count from v_pr_linked_po_count (single source of truth)
        const linkedPOCounts = {};
        const { data: poCountRows, error: poCountError } = await supabaseClient
          .from('v_pr_linked_po_count')
          .select('pr_id, po_count')
          .in('pr_id', prIds);
        if (!poCountError && poCountRows && poCountRows.length > 0) {
          poCountRows.forEach(row => {
            linkedPOCounts[row.pr_id] = { size: Number(row.po_count) || 0 };
          });
        }
        
        if (!itemError && items) {
          // Group items by pr_id
          const itemsByPrId = items.reduce((acc, item) => {
            if (!acc[item.pr_id]) acc[item.pr_id] = [];
            acc[item.pr_id].push(item);
            return acc;
          }, {});
          
          // Merge items and linked PO counts into PRs
          processedData = processedData.map(pr => ({
            ...pr,
            items: itemsByPrId[pr.id] || [],
            total_items: (itemsByPrId[pr.id] || []).length,
            is_overdue: pr.required_date && new Date(pr.required_date) < new Date() && 
                        !['closed', 'cancelled', 'fully_ordered'].includes(pr.status),
            linked_po_count: linkedPOCounts[pr.id]?.size ?? 0
          }));
        } else {
          // Still return PRs even if items fetch fails
          processedData = processedData.map(pr => ({
            ...pr,
            items: [],
            total_items: 0,
            is_overdue: pr.required_date && new Date(pr.required_date) < new Date() && 
                        !['closed', 'cancelled', 'fully_ordered'].includes(pr.status),
            linked_po_count: linkedPOCounts[pr.id]?.size ?? 0
          }));
        }
      }
      
      console.log('PRs processed successfully:', processedData.length);
      console.log('============ getPurchaseRequests END ============');
      return processedData;
    } catch (error) {
      console.error('Exception fetching purchase requests:', error);
      return [];
    }
  }
  
  console.log('Supabase not ready, returning empty array');
  return [];
}

/**
 * Get purchase request by ID with full details
 * @param {string} prId - Purchase request UUID
 * @returns {Promise<Object>} Purchase request object
 */
export async function getPurchaseRequestById(prId) {
  console.log('============ getPurchaseRequestById START ============');
  console.log('PR ID:', prId);
  
  const ready = await ensureSupabaseReady();
  
  if (ready) {
    try {
      // STEP 1: Fetch PR header
      const { data: pr, error: prError } = await supabaseClient
        .from('purchase_requests')
        .select('*')
        .eq('id', prId)
        .single();
      
      if (prError) {
        console.error('Error fetching PR:', prError);
        return null;
      }
      
      // STEP 2: Fetch items separately
      const { data: items, error: itemsError } = await supabaseClient
        .from('purchase_request_items')
        .select('*')
        .eq('pr_id', prId)
        .eq('deleted', false)
        .order('item_number', { ascending: true });
      
      // STEP 3: Fetch status history
      const { data: history, error: historyError } = await supabaseClient
        .from('pr_status_history')
        .select('*')
        .eq('pr_id', prId)
        .order('change_date', { ascending: false });
      
      // STEP 4: Combine data
      const result = {
        ...pr,
        items: items || [],
        status_history: history || []
      };
      
      console.log('PR fetched successfully:', result.pr_number);
      console.log('============ getPurchaseRequestById END ============');
      return result;
    } catch (error) {
      console.error('Exception fetching purchase request:', error);
      return null;
    }
  }
  
  return null;
}

/**
 * Create a new purchase request
 * @param {Object} prData - Purchase request data
 * @returns {Promise<Object>} Result object with success status
 */
export async function createPurchaseRequest(prData) {
  console.log('============ createPurchaseRequest START ============');
  console.log('Input prData:', prData);
  
  const ready = await ensureSupabaseReady();
  console.log('Supabase ready:', ready);
  
  if (!ready) {
    console.error('Supabase NOT ready!');
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // Calculate estimated total from items
    const estimatedTotal = (prData.items || []).reduce((sum, item) => {
      return sum + ((item.quantity || 0) * (item.estimatedPrice || 0));
    }, 0);
    
    // Prepare header data - ensure all required fields have values
    const headerData = {
      requester_id: prData.requesterId,
      requester_name: prData.requesterName || 'Unknown User',
      department: prData.department,
      cost_center: prData.costCenter || null,
      business_date: prData.businessDate || new Date().toISOString().split('T')[0],
      required_date: prData.requiredDate,
      priority: prData.priority || 'normal',
      status: prData.status || 'draft',
      notes: prData.notes || null,
      estimated_total_value: estimatedTotal,
      // Don't set pr_number - let the trigger generate it
    };
    
    console.log('Header data to insert:', headerData);
    
    // Insert header
    const { data: prHeader, error: headerError } = await supabaseClient
      .from('purchase_requests')
      .insert([headerData])
      .select()
      .single();
    
    if (headerError) {
      console.error('========== PR HEADER INSERT ERROR ==========');
      console.error('Error code:', headerError.code);
      console.error('Error message:', headerError.message);
      console.error('Error details:', headerError.details);
      console.error('Error hint:', headerError.hint);
      console.error('=============================================');
      return { success: false, error: headerError.message || 'Failed to insert PR header' };
    }
    
    console.log('PR Header created successfully:', prHeader);
    
    // Insert items if provided
    if (prData.items && prData.items.length > 0) {
      const itemsData = prData.items.map((item, index) => ({
        pr_id: prHeader.id,
        item_number: (index + 1) * 10,
        item_id: item.itemId || null,
        item_name: item.itemName,
        item_description: item.description || null,
        quantity: parseFloat(item.quantity) || 1,
        unit: item.unit || 'EA',
        estimated_price: parseFloat(item.estimatedPrice) || 0,
        required_date: item.requiredDate || prData.requiredDate,
        suggested_supplier_id: item.suggestedSupplierId || null,
        suggested_supplier_name: item.suggestedSupplierName || null,
        status: 'open'
      }));
      
      console.log('Items data to insert:', itemsData);
      
      const { data: insertedItems, error: itemsError } = await supabaseClient
        .from('purchase_request_items')
        .insert(itemsData)
        .select();
      
      if (itemsError) {
        console.error('========== PR ITEMS INSERT ERROR ==========');
        console.error('Error code:', itemsError.code);
        console.error('Error message:', itemsError.message);
        console.error('Error details:', itemsError.details);
        console.error('Error hint:', itemsError.hint);
        console.error('=============================================');
        // Header created but items failed - still return success with warning
        return { 
          success: true, 
          data: prHeader, 
          warning: 'PR header created but items failed: ' + itemsError.message 
        };
      }
      
      console.log('PR Items created successfully:', insertedItems);
    }
    
    // Invalidate cache
    invalidateCache(PR_CACHE_KEY);
    
    console.log('============ createPurchaseRequest SUCCESS ============');
    return { success: true, data: prHeader };
  } catch (error) {
    console.error('============ createPurchaseRequest EXCEPTION ============');
    console.error('Exception:', error);
    console.error('Stack:', error.stack);
    console.error('==========================================================');
    return { success: false, error: error.message || 'Unknown error occurred' };
  }
}

/**
 * Update a purchase request
 * @param {string} prId - Purchase request UUID
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Result object
 */
export async function updatePurchaseRequest(prId, updates) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // Prepare update data (convert camelCase to snake_case)
    const updateData = {};
    if (updates.department !== undefined) updateData.department = updates.department;
    if (updates.costCenter !== undefined) updateData.cost_center = updates.costCenter;
    if (updates.requiredDate !== undefined) updateData.required_date = updates.requiredDate;
    if (updates.priority !== undefined) updateData.priority = updates.priority;
    if (updates.notes !== undefined) updateData.notes = updates.notes;
    
    const { data, error } = await supabaseClient
      .from('purchase_requests')
      .update(updateData)
      .eq('id', prId)
      .select()
      .single();
    
    if (error) {
      console.error('Error updating purchase request:', error);
      return { success: false, error: error.message };
    }
    
    invalidateCache(PR_CACHE_KEY);
    return { success: true, data };
  } catch (error) {
    console.error('Exception updating purchase request:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete a purchase request (soft delete)
 * @param {string} prId - Purchase request UUID
 * @returns {Promise<Object>} Result object
 */
export async function deletePurchaseRequest(prId) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    const { error } = await supabaseClient
      .from('purchase_requests')
      .update({ deleted: true, deleted_at: new Date().toISOString() })
      .eq('id', prId);
    
    if (error) {
      console.error('Error deleting purchase request:', error);
      return { success: false, error: error.message };
    }
    
    invalidateCache(PR_CACHE_KEY);
    return { success: true };
  } catch (error) {
    console.error('Exception deleting purchase request:', error);
    return { success: false, error: error.message };
  }
}

// ============================================================================
// PURCHASE REQUEST ITEM OPERATIONS
// ============================================================================

/**
 * Add item to purchase request
 * @param {string} prId - Purchase request UUID
 * @param {Object} itemData - Item data
 * @returns {Promise<Object>} Result object
 */
export async function addPRItem(prId, itemData) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    const newItem = {
      pr_id: prId,
      item_id: itemData.itemId || null,
      item_name: itemData.itemName,
      item_description: itemData.description || null,
      quantity: itemData.quantity,
      unit: itemData.unit || 'EA',
      estimated_price: itemData.estimatedPrice || 0,
      required_date: itemData.requiredDate || null,
      suggested_supplier_id: itemData.suggestedSupplierId || null,
      status: 'open'
    };
    
    const { data, error } = await supabaseClient
      .from('purchase_request_items')
      .insert([newItem])
      .select()
      .single();
    
    if (error) {
      console.error('Error adding PR item:', error);
      return { success: false, error: error.message };
    }
    
    invalidateCache(PR_CACHE_KEY);
    return { success: true, data };
  } catch (error) {
    console.error('Exception adding PR item:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update PR item
 * @param {string} itemId - Item UUID
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Result object
 */
export async function updatePRItem(itemId, updates) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // Check if item is locked
    const { data: item } = await supabaseClient
      .from('purchase_request_items')
      .select('is_locked')
      .eq('id', itemId)
      .single();
    
    if (item?.is_locked) {
      return { success: false, error: 'Item is locked and cannot be modified' };
    }
    
    const updateData = {};
    if (updates.quantity !== undefined) updateData.quantity = updates.quantity;
    if (updates.estimatedPrice !== undefined) updateData.estimated_price = updates.estimatedPrice;
    if (updates.requiredDate !== undefined) updateData.required_date = updates.requiredDate;
    if (updates.notes !== undefined) updateData.item_notes = updates.notes;
    
    const { data, error } = await supabaseClient
      .from('purchase_request_items')
      .update(updateData)
      .eq('id', itemId)
      .select()
      .single();
    
    if (error) {
      console.error('Error updating PR item:', error);
      return { success: false, error: error.message };
    }
    
    invalidateCache(PR_CACHE_KEY);
    return { success: true, data };
  } catch (error) {
    console.error('Exception updating PR item:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete PR item (soft delete)
 * @param {string} itemId - Item UUID
 * @returns {Promise<Object>} Result object
 */
export async function deletePRItem(itemId) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // Check if item is locked
    const { data: item } = await supabaseClient
      .from('purchase_request_items')
      .select('is_locked')
      .eq('id', itemId)
      .single();
    
    if (item?.is_locked) {
      return { success: false, error: 'Item is locked and cannot be deleted' };
    }
    
    const { error } = await supabaseClient
      .from('purchase_request_items')
      .update({ deleted: true, deleted_at: new Date().toISOString() })
      .eq('id', itemId);
    
    if (error) {
      console.error('Error deleting PR item:', error);
      return { success: false, error: error.message };
    }
    
    invalidateCache(PR_CACHE_KEY);
    return { success: true };
  } catch (error) {
    console.error('Exception deleting PR item:', error);
    return { success: false, error: error.message };
  }
}

// ============================================================================
// WORKFLOW OPERATIONS
// ============================================================================

/**
 * Submit PR for approval
 * @param {string} prId - Purchase request UUID
 * @param {string} notes - Optional submission notes
 * @returns {Promise<Object>} Result object
 */
export async function submitPRForApproval(prId, notes = null) {
  console.log('============ submitPRForApproval START ============');
  console.log('PR ID:', prId);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // First try the RPC function
    const { data, error } = await supabaseClient
      .rpc('submit_pr_for_approval', {
        p_pr_id: prId,
        p_notes: notes
      });
    
    if (!error) {
      console.log('RPC submit_pr_for_approval succeeded:', data);
      invalidateCache(PR_CACHE_KEY);
      return { success: true, data };
    }
    
    // If RPC fails, do direct update as fallback
    console.log('RPC failed, using direct update fallback...');
    
    const { data: updateData, error: updateError } = await supabaseClient
      .from('purchase_requests')
      .update({
        status: 'submitted',
        submitted_for_approval: true,
        submitted_for_approval_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', prId)
      .select()
      .single();
    
    if (updateError) {
      console.error('Direct update also failed:', updateError);
      return { success: false, error: updateError.message };
    }
    
    console.log('Direct update succeeded:', updateData);
    invalidateCache(PR_CACHE_KEY);
    return { success: true, data: updateData };
  } catch (error) {
    console.error('Exception submitting PR:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Approve a purchase request
 * @param {string} prId - Purchase request UUID
 * @param {string} notes - Optional approval notes
 * @returns {Promise<Object>} Result object
 */
export async function approvePurchaseRequest(prId, notes = null) {
  console.log('============ approvePurchaseRequest START ============');
  console.log('PR ID:', prId);
  console.log('Notes:', notes);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.error('Supabase not ready!');
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // First try the RPC function
    const { data, error } = await supabaseClient
      .rpc('approve_pr', {
        p_pr_id: prId,
        p_notes: notes
      });
    
    if (!error) {
      console.log('RPC approve_pr succeeded:', data);
      invalidateCache(PR_CACHE_KEY);
      return { success: true, data };
    }
    
    // If RPC fails (function doesn't exist), use direct update as fallback
    console.log('RPC approve_pr failed, using direct update fallback...');
    console.log('RPC Error:', error.message);
    
    // Get current user for approved_by field (if available)
    const { data: { user } } = await supabaseClient.auth.getUser();
    
    const { data: updateData, error: updateError } = await supabaseClient
      .from('purchase_requests')
      .update({
        status: 'approved',
        approved_at: new Date().toISOString(),
        approved_by: user?.id || null,
        internal_memo: notes ? `Approval Notes: ${notes}` : null,
        updated_at: new Date().toISOString()
      })
      .eq('id', prId)
      .select()
      .single();
    
    if (updateError) {
      console.error('Direct update also failed:', updateError);
      return { success: false, error: updateError.message };
    }
    
    console.log('Direct update succeeded:', updateData);
    
    // Try to insert status history (optional - don't fail if it doesn't work)
    try {
      await supabaseClient
        .from('pr_status_history')
        .insert({
          pr_id: prId,
          previous_status: 'submitted',
          new_status: 'approved',
          changed_by: user?.id || null,
          changed_by_name: user?.email || 'System',
          change_reason: notes || 'PR approved',
          change_date: new Date().toISOString()
        });
      console.log('Status history inserted');
    } catch (historyError) {
      console.log('Status history insert failed (non-critical):', historyError);
    }
    
    invalidateCache(PR_CACHE_KEY);
    console.log('============ approvePurchaseRequest SUCCESS ============');
    return { success: true, data: updateData };
  } catch (error) {
    console.error('============ approvePurchaseRequest EXCEPTION ============');
    console.error('Exception:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Reject a purchase request
 * @param {string} prId - Purchase request UUID
 * @param {string} reason - Rejection reason (required)
 * @returns {Promise<Object>} Result object
 */
export async function rejectPurchaseRequest(prId, reason) {
  console.log('============ rejectPurchaseRequest START ============');
  console.log('PR ID:', prId);
  console.log('Reason:', reason);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.error('Supabase not ready!');
    return { success: false, error: 'Supabase not configured' };
  }
  
  if (!reason || reason.trim() === '') {
    return { success: false, error: 'Rejection reason is required' };
  }
  
  try {
    // First try the RPC function
    const { data, error } = await supabaseClient
      .rpc('reject_pr', {
        p_pr_id: prId,
        p_reason: reason
      });
    
    if (!error) {
      console.log('RPC reject_pr succeeded:', data);
      invalidateCache(PR_CACHE_KEY);
      return { success: true, data };
    }
    
    // If RPC fails (function doesn't exist), use direct update as fallback
    console.log('RPC reject_pr failed, using direct update fallback...');
    console.log('RPC Error:', error.message);
    
    // Get current user for rejected_by field (if available)
    const { data: { user } } = await supabaseClient.auth.getUser();
    
    const { data: updateData, error: updateError } = await supabaseClient
      .from('purchase_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason,
        updated_at: new Date().toISOString()
      })
      .eq('id', prId)
      .select()
      .single();
    
    if (updateError) {
      console.error('Direct update also failed:', updateError);
      return { success: false, error: updateError.message };
    }
    
    console.log('Direct update succeeded:', updateData);
    
    // Try to insert status history (optional - don't fail if it doesn't work)
    try {
      await supabaseClient
        .from('pr_status_history')
        .insert({
          pr_id: prId,
          previous_status: updateData.status || 'submitted',
          new_status: 'rejected',
          changed_by: user?.id || null,
          changed_by_name: user?.email || 'System',
          change_reason: reason,
          change_date: new Date().toISOString()
        });
      console.log('Status history inserted');
    } catch (historyError) {
      console.log('Status history insert failed (non-critical):', historyError);
    }
    
    invalidateCache(PR_CACHE_KEY);
    console.log('============ rejectPurchaseRequest SUCCESS ============');
    return { success: true, data: updateData };
  } catch (error) {
    console.error('============ rejectPurchaseRequest EXCEPTION ============');
    console.error('Exception:', error);
    return { success: false, error: error.message };
  }
}

// ============================================================================
// CONVERSION OPERATIONS
// ============================================================================

/**
 * Convert PR(s) to Purchase Order
 * @param {Array<string>} prIds - Array of PR UUIDs
 * @param {number} supplierId - Supplier ID
 * @param {string} pricingMode - 'estimated', 'last_po', 'inventory_cost', 'manual'
 * @param {string} notes - Optional notes
 * @param {Object} conversionData - Additional conversion data for fallback
 * @returns {Promise<Object>} Result object with PO details
 */
export async function convertPRToPO(prIds, supplierId, pricingMode = 'estimated', notes = null, conversionData = null) {
  console.log('============ convertPRToPO START ============');
  console.log('PR IDs:', prIds);
  console.log('Supplier ID:', supplierId);
  console.log('Pricing Mode:', pricingMode);
  console.log('Notes:', notes);
  console.log('Conversion Data:', conversionData);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.error('Supabase not ready!');
    return { success: false, error: 'Supabase not configured' };
  }

  // BUSINESS RULE: Block conversion if PR already has linked PO or status = CLOSED (backend enforcement)
  const prId = Array.isArray(prIds) ? prIds[0] : prIds;
  if (prId) {
    const canConvert = await canCreateNextDocument('PR', prId);
    if (!canConvert) {
      return { success: false, error: 'This Purchase Request already has a linked Purchase Order or is closed. Duplicate conversion is not allowed.' };
    }
  }
  
  try {
    // First try the RPC function
    const { data, error } = await supabaseClient
      .rpc('convert_pr_to_po', {
        p_pr_ids: prIds,
        p_supplier_id: supplierId,
        p_pricing_mode: pricingMode,
        p_user_id: null, // Will use auth.uid() in function
        p_notes: notes
      });
    
    if (!error && data) {
      console.log('RPC convert_pr_to_po succeeded:', data);
      invalidateCache(PR_CACHE_KEY);
      return data;
    }
    
    // If RPC fails, use fallback manual conversion
    console.log('RPC convert_pr_to_po failed, using fallback...');
    console.log('RPC Error:', error?.message);
    
    // ========================================
    // FALLBACK: Manual PO Creation
    // ========================================
    
    // Get PR details if not provided
    let prData = conversionData;
    if (!prData || !prData.items) {
      const { data: pr } = await supabaseClient
        .from('purchase_requests')
        .select('*, purchase_request_items(*)')
        .eq('id', prIds[0])
        .single();
      
      if (!pr) {
        return { success: false, error: 'Purchase Request not found' };
      }
      
      prData = {
        prId: pr.id,
        prNumber: pr.pr_number,
        items: (pr.purchase_request_items || []).map(item => ({
          prItemId: item.id,
          itemId: item.item_id,
          itemName: item.item_name,
          quantity: item.quantity - (item.quantity_ordered || 0),
          unitPrice: item.estimated_price || 0,
          unit: item.unit,
          total: (item.quantity - (item.quantity_ordered || 0)) * (item.estimated_price || 0)
        }))
      };
    }
    
    // Get supplier info
    const { data: supplier } = await supabaseClient
      .from('suppliers')
      .select('id, name')
      .eq('id', supplierId)
      .single();
    
    const supplierName = supplier?.name || prData?.supplierName || 'Unknown Supplier';
    
    // Calculate totals
    const items = prData?.items || [];
    const totalAmount = items.reduce((sum, item) => sum + (item.total || (item.quantity * item.unitPrice)), 0);
    const vatRate = 0.15; // 15% VAT
    const vatAmount = totalAmount * vatRate;
    
    console.log('Creating PO with manual fallback...');
    console.log('Items:', items);
    console.log('Total:', totalAmount);
    
    // Generate PO number manually (since trigger might not exist)
    const year = new Date().getFullYear();
    const timestamp = Date.now().toString().slice(-6);
    const generatedPONumber = `PO-${year}-${timestamp}`;
    
    // Create PO header
    const { data: newPO, error: poError } = await supabaseClient
      .from('purchase_orders')
      .insert({
        po_number: generatedPONumber, // Explicitly set PO number
        supplier_id: supplierId,
        supplier_name: supplierName,
        status: 'pending',
        business_date: new Date().toISOString().split('T')[0],
        order_date: new Date().toISOString(),
        total_amount: totalAmount,
        vat_amount: vatAmount,
        notes: notes || `Converted from PR: ${prData?.prNumber || prIds[0]}`,
        ordered_quantity: items.reduce((sum, i) => sum + (i.quantity || 0), 0),
        remaining_quantity: items.reduce((sum, i) => sum + (i.quantity || 0), 0),
        receiving_status: 'not_received'
      })
      .select()
      .single();
    
    if (poError) {
      console.error('Error creating PO header:', poError);
      return { success: false, error: 'Failed to create PO: ' + poError.message };
    }
    
    // Ensure we have a PO number
    const poNumber = newPO.po_number || generatedPONumber;
    console.log('PO Header created:', newPO);
    console.log('PO Number:', poNumber);
    
    // Create PO items
    if (items.length > 0) {
      const poItems = items.map(item => ({
        purchase_order_id: newPO.id,
        po_number: poNumber,
        supplier_name: supplierName,
        item_id: item.itemId,
        item_name: item.itemName,
        item_sku: item.sku || null,
        quantity: item.quantity,
        unit: item.unit || 'EA',
        unit_price: item.unitPrice,
        total_amount: item.quantity * item.unitPrice,
        quantity_received: 0,
        vat_rate: vatRate * 100,
        vat_amount: (item.quantity * item.unitPrice) * vatRate
      }));
      
      const { error: itemsError } = await supabaseClient
        .from('purchase_order_items')
        .insert(poItems);
      
      if (itemsError) {
        console.error('Error creating PO items:', itemsError);
        // PO header created but items failed - still return partial success
      } else {
        console.log('PO Items created successfully');
      }
    }
    
    // Update PR item status
    for (const item of items) {
      if (item.prItemId) {
        await supabaseClient
          .from('purchase_request_items')
          .update({
            status: 'converted_to_po',
            quantity_ordered: item.quantity,
            po_id: newPO.id,
            po_number: poNumber,
            conversion_date: new Date().toISOString(),
            is_locked: true,
            locked_at: new Date().toISOString(),
            lock_reason: 'Converted to PO',
            updated_at: new Date().toISOString()
          })
          .eq('id', item.prItemId);
      }
    }
    console.log('PR Items updated');
    
    // Update PR status to partially_ordered or fully_ordered
    const { error: prUpdateError } = await supabaseClient
      .from('purchase_requests')
      .update({
        status: 'fully_ordered',
        updated_at: new Date().toISOString()
      })
      .eq('id', prIds[0]);
    
    if (prUpdateError) {
      console.log('Warning: Failed to update PR status:', prUpdateError);
    } else {
      console.log('PR status updated to fully_ordered');
    }
    
    // =========================================
    // PO CREATED SUCCESSFULLY - Now insert linkage records
    // =========================================
    
    // Prepare the success response FIRST (in case anything below fails)
    const successResult = {
      success: true,
      po_id: newPO.id,
      po_number: poNumber,
      pr_ids: prIds,
      items_converted: items.length,
      total_amount: totalAmount
    };
    
    console.log('PO Created! Now inserting linkage records...');
    
    // Insert pr_po_linkage records (triggers will update PR item quantities and document_flow)
    for (const item of items) {
      if (item.prItemId) {
        try {
          const linkageRecord = {
            pr_id: prIds[0],
            pr_number: prData?.prNumber || null,
            pr_item_id: item.prItemId,
            pr_item_number: item.itemNumber || 10,
            po_id: newPO.id,
            po_number: poNumber,
            pr_quantity: item.quantity,
            converted_quantity: item.quantity,
            remaining_quantity: 0,
            unit: item.unit || 'EA',
            pr_estimated_price: item.unitPrice || 0,
            po_actual_price: item.unitPrice || 0,
            conversion_type: 'full',
            status: 'active',
            converted_at: new Date().toISOString()
          };
          
          console.log('Inserting pr_po_linkage:', linkageRecord);
          
          const { error: linkageError } = await supabaseClient
            .from('pr_po_linkage')
            .insert(linkageRecord);
          
          if (linkageError) {
            console.log('pr_po_linkage insert failed (non-critical):', linkageError.message);
          } else {
            console.log('pr_po_linkage record created successfully');
          }
        } catch (linkErr) {
          console.log('pr_po_linkage exception (non-critical):', linkErr.message);
        }
      }
    }
    
    // Insert document_flow record (PR → PO)
    try {
      const docFlowRecord = {
        source_type: 'PR',
        source_id: prIds[0],
        source_number: prData?.prNumber || null,
        target_type: 'PO',
        target_id: String(newPO.id), // Convert bigint to text
        target_number: poNumber,
        flow_type: 'converted_to',
        created_at: new Date().toISOString()
      };
      
      console.log('Inserting document_flow:', docFlowRecord);
      
      const { error: docFlowError } = await supabaseClient
        .from('document_flow')
        .insert(docFlowRecord);
      
      if (docFlowError) {
        console.log('document_flow insert failed (non-critical):', docFlowError.message);
      } else {
        console.log('document_flow record created successfully');
      }
    } catch (docErr) {
      console.log('document_flow exception (non-critical):', docErr.message);
    }
    
    invalidateCache(PR_CACHE_KEY);
    
    console.log('============ convertPRToPO SUCCESS ============');
    console.log('Result:', successResult);
    return successResult;
  } catch (error) {
    console.error('============ convertPRToPO EXCEPTION ============');
    console.error('Exception:', error);
    console.error('Stack:', error.stack);
    return { success: false, error: error.message };
  }
}

/**
 * Get linked POs for a PR
 * @param {string} prId - Purchase request UUID
 * @returns {Promise<Array>} List of linked POs
 */
export async function getPRLinkedPOs(prId) {
  console.log('============ getPRLinkedPOs START ============');
  console.log('PR ID:', prId);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.log('Supabase not ready');
    return [];
  }
  
  try {
    // First try the RPC function
    const { data: rpcData, error: rpcError } = await supabaseClient
      .rpc('get_pr_linked_pos', { p_pr_id: prId });
    
    if (!rpcError && rpcData && rpcData.length > 0) {
      console.log('Linked POs from RPC:', rpcData);
      return rpcData;
    }
    
    // If RPC fails or returns empty, try direct query
    console.log('RPC failed or empty, trying direct query...');
    
    // First try the view
    const { data: viewData, error: viewError } = await supabaseClient
      .from('v_pr_linked_pos')
      .select('*')
      .eq('pr_id', prId);
    
    if (!viewError && viewData && viewData.length > 0) {
      console.log('Linked POs from view:', viewData);
      return viewData;
    }
    
    // Fallback: Query pr_po_linkage table directly
    console.log('View failed or empty, trying pr_po_linkage...');
    const { data: linkageData, error: linkageError } = await supabaseClient
      .from('pr_po_linkage')
      .select(`
        pr_id,
        pr_number,
        po_id,
        po_number,
        converted_quantity,
        converted_at,
        status
      `)
      .eq('pr_id', prId)
      .eq('status', 'active');
    
    if (linkageError) {
      console.error('Error querying pr_po_linkage:', linkageError);
      return [];
    }
    
    if (!linkageData || linkageData.length === 0) {
      console.log('No linkage records found');
      return [];
    }
    
    // Get unique PO IDs
    const poIds = [...new Set(linkageData.map(l => l.po_id))];
    
    // Fetch PO details
    const { data: poData, error: poError } = await supabaseClient
      .from('purchase_orders')
      .select('id, po_number, supplier_name, status, receiving_status, total_amount, order_date')
      .in('id', poIds);
    
    if (poError) {
      console.error('Error fetching PO details:', poError);
      return linkageData.map(l => ({
        po_id: l.po_id,
        po_number: l.po_number,
        supplier_name: null,
        po_status: null,
        receiving_status: null,
        converted_qty: l.converted_quantity,
        item_count: 1,
        po_total: 0,
        po_date: l.converted_at
      }));
    }
    
    // Merge linkage with PO details
    const poMap = (poData || []).reduce((acc, po) => {
      acc[po.id] = po;
      return acc;
    }, {});
    
    // Group by PO
    const poSummary = {};
    linkageData.forEach(l => {
      if (!poSummary[l.po_id]) {
        const po = poMap[l.po_id] || {};
        poSummary[l.po_id] = {
          po_id: l.po_id,
          po_number: l.po_number || po.po_number,
          supplier_name: po.supplier_name,
          po_status: po.status,
          receiving_status: po.receiving_status,
          converted_qty: 0,
          item_count: 0,
          po_total: po.total_amount || 0,
          po_date: po.order_date || l.converted_at
        };
      }
      poSummary[l.po_id].converted_qty += parseFloat(l.converted_quantity) || 0;
      poSummary[l.po_id].item_count += 1;
    });
    
    const result = Object.values(poSummary);
    console.log('Linked POs from direct query:', result);
    console.log('============ getPRLinkedPOs END ============');
    return result;
  } catch (error) {
    console.error('Exception getting linked POs:', error);
    return [];
  }
}

/**
 * Get document flow tree for a PR
 * @param {string} prId - Purchase request UUID
 * @returns {Promise<Array>} Document flow tree
 */
export async function getPRDocumentFlow(prId) {
  console.log('============ getPRDocumentFlow START ============');
  console.log('PR ID:', prId);
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.log('Supabase not ready');
    return [];
  }
  
  try {
    // Get PR details first
    const { data: prData, error: prError } = await supabaseClient
      .from('purchase_requests')
      .select('id, pr_number, status, created_at')
      .eq('id', prId)
      .single();
    
    if (prError || !prData) {
      console.error('Error getting PR:', prError);
      return [];
    }
    
    const documentFlow = [];
    
    // Add PR as first document
    documentFlow.push({
      doc_type: 'PR',
      doc_number: prData.pr_number,
      doc_id: prData.id,
      doc_status: prData.status,
      doc_date: prData.created_at
    });
    
    // STEP 1: Get linked POs from multiple sources
    let poIds = [];
    let poNumbers = [];
    
    // Try pr_po_linkage first
    const { data: linkageData } = await supabaseClient
      .from('pr_po_linkage')
      .select('po_id, po_number')
      .eq('pr_id', prId)
      .eq('status', 'active');
    
    if (linkageData && linkageData.length > 0) {
      poIds = [...new Set(linkageData.map(l => l.po_id).filter(Boolean))];
      poNumbers = [...new Set(linkageData.map(l => l.po_number).filter(Boolean))];
    }
    
    // Also check purchase_request_items.po_id
    const { data: itemsWithPO } = await supabaseClient
      .from('purchase_request_items')
      .select('po_id, po_number')
      .eq('pr_id', prId)
      .not('po_id', 'is', null)
      .eq('deleted', false);
    
    if (itemsWithPO && itemsWithPO.length > 0) {
      itemsWithPO.forEach(item => {
        if (item.po_id && !poIds.includes(item.po_id)) poIds.push(item.po_id);
        if (item.po_number && !poNumbers.includes(item.po_number)) poNumbers.push(item.po_number);
      });
    }
    
    console.log('Found PO IDs:', poIds);
    console.log('Found PO Numbers:', poNumbers);
    
    // STEP 2: Get PO details
    if (poIds.length > 0) {
      const { data: poData } = await supabaseClient
        .from('purchase_orders')
        .select('id, po_number, status, order_date, receiving_status')
        .in('id', poIds);
      
      if (poData && poData.length > 0) {
        for (const po of poData) {
          documentFlow.push({
            doc_type: 'PO',
            doc_number: po.po_number,
            doc_id: po.id,
            doc_status: po.status,
            doc_date: po.order_date
          });
          
          // Add to poNumbers for GRN lookup
          if (po.po_number && !poNumbers.includes(po.po_number)) {
            poNumbers.push(po.po_number);
          }
        }
      }
    }
    
    // STEP 3: Get GRNs for these POs
    if (poIds.length > 0 || poNumbers.length > 0) {
      let grnQuery = supabaseClient
        .from('grn_inspections')
        .select('id, grn_number, status, grn_date, purchase_order_id, purchase_order_number')
        .eq('deleted', false);
      
      // Build OR condition
      if (poIds.length > 0) {
        grnQuery = grnQuery.in('purchase_order_id', poIds);
      }
      
      const { data: grnData } = await grnQuery;
      
      console.log('Found GRNs:', grnData);
      
      if (grnData && grnData.length > 0) {
        for (const grn of grnData) {
          // Avoid duplicates
          if (!documentFlow.find(d => d.doc_type === 'GRN' && d.doc_id === grn.id)) {
            documentFlow.push({
              doc_type: 'GRN',
              doc_number: grn.grn_number || `GRN-${grn.id.substring(0, 8)}`,
              doc_id: grn.id,
              doc_status: grn.status,
              doc_date: grn.grn_date
            });
          }
        }
        
        // STEP 4: Get Purchasing Invoices for these GRNs
        const grnIds = grnData.map(g => g.id);
        const grnNumbers = grnData.map(g => g.grn_number).filter(Boolean);
        
        if (grnIds.length > 0) {
          const { data: invData } = await supabaseClient
            .from('purchasing_invoices')
            .select('id, purchasing_number, invoice_number, status, created_at, grn_id, grn_number')
            .or(`grn_id.in.(${grnIds.join(',')}),grn_number.in.(${grnNumbers.join(',')})`)
            .eq('deleted', false);
          
          console.log('Found Invoices:', invData);
          
          if (invData && invData.length > 0) {
            for (const inv of invData) {
              // Avoid duplicates
              if (!documentFlow.find(d => d.doc_type === 'INV' && d.doc_id === inv.id)) {
                documentFlow.push({
                  doc_type: 'INV',
                  doc_number: inv.purchasing_number || inv.invoice_number || `INV-${inv.id.substring(0, 8)}`,
                  doc_id: inv.id,
                  doc_status: inv.status,
                  doc_date: inv.created_at
                });
              }
            }
            
            // STEP 5: Get AP Payments for these Invoices
            const invIds = invData.map(i => i.id);
            const { data: paymentData } = await supabaseClient
              .from('ap_payments')
              .select('id, payment_number, status, payment_date, purchasing_invoice_id')
              .in('purchasing_invoice_id', invIds);
            
            console.log('Found Payments:', paymentData);
            
            if (paymentData && paymentData.length > 0) {
              for (const pmt of paymentData) {
                documentFlow.push({
                  doc_type: 'PAYMENT',
                  doc_number: pmt.payment_number || `PAY-${pmt.id.substring(0, 8)}`,
                  doc_id: pmt.id,
                  doc_status: pmt.status,
                  doc_date: pmt.payment_date
                });
              }
            }
          }
        }
      }
    }
    
    console.log('Final document flow:', documentFlow);
    console.log('============ getPRDocumentFlow END ============');
    return documentFlow;
  } catch (error) {
    console.error('Exception getting document flow:', error);
    return [];
  }
}

// ============================================================================
// ANALYTICS & DASHBOARD
// ============================================================================

/**
 * Get PR dashboard statistics
 * @param {string} department - Optional department filter
 * @param {string} startDate - Optional start date
 * @param {string} endDate - Optional end date
 * @returns {Promise<Object>} Dashboard statistics
 */
export async function getPRDashboardStats(department = null, startDate = null, endDate = null) {
  console.log('============ getPRDashboardStats START ============');
  
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    console.log('Supabase not ready, returning default stats');
    return getDefaultDashboardStats();
  }
  
  try {
    // First try the RPC function
    const { data, error } = await supabaseClient
      .rpc('get_pr_dashboard_stats', {
        p_department: department,
        p_start_date: startDate,
        p_end_date: endDate
      });
    
    if (!error && data) {
      console.log('Dashboard stats from RPC:', data);
      return data;
    }
    
    // If RPC fails, calculate stats manually from PR list
    console.log('RPC failed or no data, calculating stats manually...');
    
    const { data: prs, error: prError } = await supabaseClient
      .from('purchase_requests')
      .select('id, status, priority, required_date, estimated_total_value')
      .eq('deleted', false);
    
    if (prError) {
      console.error('Error fetching PRs for stats:', prError);
      return getDefaultDashboardStats();
    }
    
    const today = new Date().toISOString().split('T')[0];
    const stats = {
      total_prs: prs?.length || 0,
      draft_count: prs?.filter(p => p.status === 'draft').length || 0,
      pending_approval: prs?.filter(p => ['submitted', 'under_review'].includes(p.status)).length || 0,
      approved_count: prs?.filter(p => p.status === 'approved').length || 0,
      partially_ordered: prs?.filter(p => p.status === 'partially_ordered').length || 0,
      fully_ordered: prs?.filter(p => p.status === 'fully_ordered').length || 0,
      closed_count: prs?.filter(p => p.status === 'closed').length || 0,
      rejected_count: prs?.filter(p => p.status === 'rejected').length || 0,
      cancelled_count: prs?.filter(p => p.status === 'cancelled').length || 0,
      total_value: prs?.reduce((sum, p) => sum + (p.estimated_total_value || 0), 0) || 0,
      overdue_count: prs?.filter(p => 
        p.required_date && p.required_date < today && 
        !['closed', 'cancelled', 'fully_ordered'].includes(p.status)
      ).length || 0,
      high_priority_count: prs?.filter(p => ['high', 'urgent', 'critical'].includes(p.priority)).length || 0
    };
    
    console.log('Calculated dashboard stats:', stats);
    console.log('============ getPRDashboardStats END ============');
    return stats;
  } catch (error) {
    console.error('Exception getting dashboard stats:', error);
    return getDefaultDashboardStats();
  }
}

/**
 * Get PR trend data for charts
 * @param {number} months - Number of months to fetch
 * @param {string} department - Optional department filter
 * @returns {Promise<Array>} Trend data
 */
export async function getPRTrendData(months = 12, department = null) {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return [];
  }
  
  try {
    const { data, error } = await supabaseClient
      .rpc('get_pr_trend_data', {
        p_months: months,
        p_department: department
      });
    
    if (error) {
      console.error('Error getting trend data:', error);
      return [];
    }
    
    return data || [];
  } catch (error) {
    console.error('Exception getting trend data:', error);
    return [];
  }
}

/**
 * Get PR summary view data
 * @returns {Promise<Array>} PR summary data
 */
export async function getPRSummary() {
  const ready = await ensureSupabaseReady();
  
  if (!ready) {
    return [];
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('v_pr_summary')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('Error getting PR summary:', error);
      return [];
    }
    
    return data || [];
  } catch (error) {
    console.error('Exception getting PR summary:', error);
    return [];
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getPurchaseRequestsFromLocalStorage() {
  try {
    const data = JSON.parse(localStorage.getItem(PR_CACHE_KEY) || '[]');
    return data;
  } catch (error) {
    console.error('Error reading PR from localStorage:', error);
    return [];
  }
}

function getDefaultDashboardStats() {
  return {
    total_prs: 0,
    draft_count: 0,
    pending_approval: 0,
    approved_count: 0,
    partially_ordered: 0,
    fully_ordered: 0,
    closed_count: 0,
    rejected_count: 0,
    cancelled_count: 0,
    total_value: 0,
    avg_value: 0,
    overdue_count: 0,
    high_priority_count: 0
  };
}

/**
 * Get next PR number preview (without consuming sequence)
 * @returns {Promise<string>} Next PR number
 */
export async function getNextPRNumberPreview() {
  const ready = await ensureSupabaseReady();
  const year = new Date().getFullYear();
  const defaultNumber = `PR-${year}-XXXXXX`;
  
  if (!ready) {
    return defaultNumber;
  }
  
  try {
    // Try the RPC function first
    const { data, error } = await supabaseClient
      .rpc('get_next_pr_number_preview');
    
    if (!error && data) {
      return data;
    }
    
    // If RPC fails, try to calculate from sequence table
    const { data: seqData, error: seqError } = await supabaseClient
      .from('pr_number_sequence')
      .select('last_number')
      .eq('fiscal_year', year)
      .single();
    
    if (seqData && !seqError) {
      const nextNum = (seqData.last_number || 0) + 1;
      return `PR-${year}-${String(nextNum).padStart(6, '0')}`;
    }
    
    // If sequence doesn't exist, this will be the first PR
    return `PR-${year}-000001`;
  } catch (error) {
    console.error('Exception getting next PR number:', error);
    return defaultNumber;
  }
}

// ============================================================================
// EXPORT ALL FUNCTIONS
// ============================================================================

export default {
  getPurchaseRequests,
  getPurchaseRequestById,
  createPurchaseRequest,
  updatePurchaseRequest,
  deletePurchaseRequest,
  addPRItem,
  updatePRItem,
  deletePRItem,
  submitPRForApproval,
  approvePurchaseRequest,
  rejectPurchaseRequest,
  convertPRToPO,
  getPRLinkedPOs,
  getPRDocumentFlow,
  getPRDashboardStats,
  getPRTrendData,
  getPRSummary,
  getNextPRNumberPreview
};
