/**
 * Chatbot Context Service
 * Dynamically collects LIVE system data before every AI response
 * Future-proof: Automatically includes new modules without code changes
 */

import { sidebarConfig } from '@/config/sidebarConfig';
import { getAllModules, getSupabaseModules } from './ModuleRegistry';
import { supabaseClient, USE_SUPABASE, ensureSupabaseReady } from './supabase';

/**
 * Build comprehensive system context with LIVE data
 * @param {Object} user - Current logged-in user
 * @returns {Promise<Object>} Complete system context
 */
export async function buildChatbotContext(user = null) {
  const context = {
    timestamp: new Date().toISOString(),
    user: user ? {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role || 'user'
    } : null,
    modules: [],
    data: {},
    dataStatus: {}
  };

  // 1. Auto-discover all modules from sidebar config
  const allModules = getAllModules();
  context.modules = allModules.map(module => ({
    id: module.id,
    parentId: module.parentId,
    label: module.label,
    route: module.route,
    icon: module.icon,
    dataSource: module.dataSource,
    metrics: module.metrics
  }));

  // 2. Collect data from all Supabase modules (parallel for speed)
  const supabaseModules = getSupabaseModules();
  const { getModuleFetcher } = await import('./ModuleRegistry');
  
  const supabaseDataPromises = supabaseModules.map(async (module) => {
    try {
      const fetcher = await getModuleFetcher(module.id);
      if (!fetcher) {
        return { moduleId: module.id, data: null, error: 'No fetcher available' };
      }

      const data = await fetcher();
      const metrics = calculateModuleMetrics(module.id, data || []);
      
      return {
        moduleId: module.id,
        data: data || [],
        metrics: metrics,
        count: Array.isArray(data) ? data.length : 0,
        status: 'loaded'
      };
    } catch (error) {
      console.error(`Error loading data for module ${module.id}:`, error);
      return {
        moduleId: module.id,
        data: null,
        metrics: {},
        count: 0,
        status: 'error',
        error: error.message
      };
    }
  });

  // Execute all data fetches in parallel
  const supabaseResults = await Promise.all(supabaseDataPromises);
  
  // Organize data by module
  supabaseResults.forEach(result => {
    context.data[result.moduleId] = {
      items: result.data,
      count: result.count,
      metrics: result.metrics
    };
    context.dataStatus[result.moduleId] = result.status;
  });

  // 3. Load Google Sheets reporting data (from cached summaries)
  const { getCachedSummary, loadFreshSummaries, saveCachedSummary } = await import('./homeSummaryService');
  
  // Get cached summary (instant access - non-blocking)
  const cachedSummary = getCachedSummary();
  if (cachedSummary) {
    // Extract Accounts Payable data (field names match homeSummaryService structure exactly)
    if (cachedSummary.accountsPayable) {
      context.data['accounts-payable'] = {
        totalDues: cachedSummary.accountsPayable.totalDues || 0,
        overdueDues: cachedSummary.accountsPayable.overdues || 0, // Note: homeSummaryService uses 'overdues'
        suppliersCount: cachedSummary.accountsPayable.totalSuppliers || 0, // Note: 'totalSuppliers' not 'suppliersCount'
        totalTransactions: cachedSummary.accountsPayable.totalTransactions || 0
      };
      context.dataStatus['accounts-payable'] = 'cached';
    }
    
    // Extract RM Forecasting data (field names match homeSummaryService structure exactly)
    if (cachedSummary.rmForecasting) {
      context.data['rm-forecasting'] = {
        totalBudget: cachedSummary.rmForecasting.netPurchaseBudget || 0,
        itemsToOrder: cachedSummary.rmForecasting.itemsToPurchase || 0,
        savings: cachedSummary.rmForecasting.potentialSavings || 0,
        overstockValue: cachedSummary.rmForecasting.overstockedValue || 0,
        forecastAccuracy: cachedSummary.rmForecasting.forecastAccuracy || 0
      };
      context.dataStatus['rm-forecasting'] = 'cached';
    }
    
    // Extract Warehouse data (field names match homeSummaryService structure exactly)
    if (cachedSummary.warehouse) {
      context.data['warehouse-dashboard'] = {
        inventoryValue: cachedSummary.warehouse.totalInventoryValue || 0,
        transferCount: cachedSummary.warehouse.transferValue || 0,
        outOfStock: cachedSummary.warehouse.outOfStock || 0,
        lowStock: cachedSummary.warehouse.lowStock || 0
      };
      context.dataStatus['warehouse-dashboard'] = 'cached';
    }
  }
  
  // Trigger background refresh (non-blocking) - updates cache for next query
  loadFreshSummaries().then(freshData => {
    if (freshData) {
      // Update cache with fresh data (for next query)
      saveCachedSummary(freshData);
    }
  }).catch(error => {
    console.error('Error refreshing Google Sheets data:', error);
    // Silent fail - cached data is already available in context
  });

  return context;
}

/**
 * Calculate metrics for a module based on its data
 */
function calculateModuleMetrics(moduleId, data) {
  if (!Array.isArray(data) || data.length === 0) {
    return {};
  }

  const metrics = {
    count: data.length
  };

  switch (moduleId) {
    case 'items':
      // Calculate low stock items (assuming stock field exists)
      const lowStockItems = data.filter(item => {
        const stock = item.stock || item.quantity || item.availableQuantity || 0;
        const minStock = item.minStock || item.minimumStock || 0;
        return stock <= minStock && stock > 0;
      });
      metrics.lowStock = lowStockItems.length;
      break;

    case 'purchase-orders':
      const pendingPOs = data.filter(po => {
        const status = (po.status || '').toLowerCase();
        return status === 'pending' || status === 'draft' || status === 'in_progress';
      });
      const completedPOs = data.filter(po => {
        const status = (po.status || '').toLowerCase();
        return status === 'completed' || status === 'closed' || status === 'received';
      });
      metrics.pending = pendingPOs.length;
      metrics.completed = completedPOs.length;
      break;

    case 'transfer-orders':
      const pendingTransfers = data.filter(to => {
        const status = (to.status || '').toLowerCase();
        return status === 'pending' || status === 'draft';
      });
      const inTransit = data.filter(to => {
        const status = (to.status || '').toLowerCase();
        return status === 'in_transit' || status === 'in transit' || status === 'shipped';
      });
      metrics.pending = pendingTransfers.length;
      metrics.inTransit = inTransit.length;
      break;

    case 'grns':
      const pendingGRNs = data.filter(grn => {
        const status = (grn.status || '').toLowerCase();
        return status === 'pending' || status === 'draft';
      });
      const approvedGRNs = data.filter(grn => {
        const status = (grn.status || '').toLowerCase();
        return status === 'approved' || status === 'accepted';
      });
      const rejectedGRNs = data.filter(grn => {
        const status = (grn.status || '').toLowerCase();
        return status === 'rejected' || status === 'reject';
      });
      metrics.pending = pendingGRNs.length;
      metrics.approved = approvedGRNs.length;
      metrics.rejected = rejectedGRNs.length;
      break;

    case 'user-management':
      // Calculate active and pending users
      const activeUsers = data.filter(user => {
        const status = (user.status || '').toLowerCase();
        return status === 'active' || status === 'approved';
      });
      const pendingUsers = data.filter(user => {
        const status = (user.status || '').toLowerCase();
        return status === 'pending' || status === 'pending_approval';
      });
      metrics.active = activeUsers.length;
      metrics.pending = pendingUsers.length;
      break;
      
    case 'suppliers':
      // Simple count is sufficient
      break;

    default:
      // For unknown modules, just provide count
      break;
  }

  return metrics;
}

/**
 * Get specific module data from context
 */
export function getModuleDataFromContext(context, moduleId) {
  return context.data[moduleId] || null;
}

/**
 * Get module status from context
 */
export function getModuleStatusFromContext(context, moduleId) {
  return context.dataStatus[moduleId] || 'unknown';
}

/**
 * Check if module data is available
 */
export function isModuleDataAvailable(context, moduleId) {
  const status = getModuleStatusFromContext(context, moduleId);
  return status === 'loaded' || status === 'cached';
}
