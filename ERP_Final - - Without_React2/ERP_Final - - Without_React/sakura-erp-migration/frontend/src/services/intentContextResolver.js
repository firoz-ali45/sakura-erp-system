/**
 * Intent-to-Context Resolver
 * Maps Gemini intent JSON to actual context data paths
 * Provides multiple fallback paths for robustness
 * This layer is MANDATORY - prevents silent failures
 */

import { getModuleDataFromContext, isModuleDataAvailable } from './ChatbotContextService';

/**
 * Normalized intent-to-context mapping with multiple fallback paths
 * Each resolver tries multiple possible paths before returning undefined
 */
const INTENT_CONTEXT_MAP = {
  /**
   * User name intent
   * Returns user name string directly
   */
  get_user_name: (ctx) => {
    const userName = ctx.user?.name ?? ctx.user?.displayName ?? ctx.user?.fullName;
    // Return string directly for user name (simpler than object)
    return userName ?? undefined;
  },

  /**
   * User role intent
   */
  get_user_role: (ctx) => {
    return ctx.user?.role ?? ctx.user?.userRole ?? undefined;
  },

  /**
   * Inventory items count intent
   * Tries multiple module IDs and data paths
   */
  get_inventory_count: (ctx) => {
    // Try 'items' module (primary path)
    const itemsData = getModuleDataFromContext(ctx, 'items');
    if (itemsData?.count !== undefined) {
      return {
        count: itemsData.count,
        lowStock: itemsData.metrics?.lowStock ?? 0,
        moduleId: 'items',
        data: itemsData
      };
    }

    // Try 'inventory' module (alternative path)
    const inventoryData = getModuleDataFromContext(ctx, 'inventory');
    if (inventoryData?.count !== undefined) {
      return {
        count: inventoryData.count,
        lowStock: inventoryData.metrics?.lowStock ?? 0,
        moduleId: 'inventory',
        data: inventoryData
      };
    }

    // Try 'inventoryItems' module (alternative path)
    const inventoryItemsData = getModuleDataFromContext(ctx, 'inventoryItems');
    if (inventoryItemsData?.count !== undefined) {
      return {
        count: inventoryItemsData.count,
        lowStock: inventoryItemsData.metrics?.lowStock ?? 0,
        moduleId: 'inventoryItems',
        data: inventoryItemsData
      };
    }

    // Try direct context paths
    if (ctx.data?.inventory?.totalItems !== undefined) {
      return {
        count: ctx.data.inventory.totalItems,
        lowStock: ctx.data.inventory.lowStock ?? 0,
        moduleId: 'inventory',
        data: ctx.data.inventory
      };
    }

    if (ctx.data?.items?.count !== undefined) {
      return {
        count: ctx.data.items.count,
        lowStock: ctx.data.items.metrics?.lowStock ?? 0,
        moduleId: 'items',
        data: ctx.data.items
      };
    }

    return undefined;
  },

  /**
   * Suppliers count intent
   */
  get_suppliers_count: (ctx) => {
    const suppliersData = getModuleDataFromContext(ctx, 'suppliers');
    if (suppliersData?.count !== undefined) {
      return {
        count: suppliersData.count,
        moduleId: 'suppliers',
        data: suppliersData
      };
    }

    if (ctx.data?.suppliers?.total !== undefined) {
      return {
        count: ctx.data.suppliers.total,
        moduleId: 'suppliers',
        data: ctx.data.suppliers
      };
    }

    if (ctx.data?.suppliers?.count !== undefined) {
      return {
        count: ctx.data.suppliers.count,
        moduleId: 'suppliers',
        data: ctx.data.suppliers
      };
    }

    return undefined;
  },

  /**
   * Purchase orders count intent
   */
  get_purchase_orders_count: (ctx) => {
    const poData = getModuleDataFromContext(ctx, 'purchase-orders');
    if (poData) {
      return {
        count: poData.count ?? 0,
        pending: poData.metrics?.pending ?? 0,
        completed: poData.metrics?.completed ?? 0,
        moduleId: 'purchase-orders',
        data: poData
      };
    }

    if (ctx.data?.['purchase-orders']?.count !== undefined) {
      return {
        count: ctx.data['purchase-orders'].count,
        pending: ctx.data['purchase-orders'].metrics?.pending ?? 0,
        completed: ctx.data['purchase-orders'].metrics?.completed ?? 0,
        moduleId: 'purchase-orders',
        data: ctx.data['purchase-orders']
      };
    }

    if (ctx.data?.purchaseOrders?.total !== undefined) {
      return {
        count: ctx.data.purchaseOrders.total,
        pending: ctx.data.purchaseOrders.pending ?? 0,
        completed: ctx.data.purchaseOrders.completed ?? 0,
        moduleId: 'purchaseOrders',
        data: ctx.data.purchaseOrders
      };
    }

    if (ctx.data?.purchaseOrders?.count !== undefined) {
      return {
        count: ctx.data.purchaseOrders.count,
        pending: ctx.data.purchaseOrders.metrics?.pending ?? 0,
        completed: ctx.data.purchaseOrders.metrics?.completed ?? 0,
        moduleId: 'purchaseOrders',
        data: ctx.data.purchaseOrders
      };
    }

    return undefined;
  },

  /**
   * Transfer orders count intent
   */
  get_transfer_orders_count: (ctx) => {
    const toData = getModuleDataFromContext(ctx, 'transfer-orders');
    if (toData) {
      return {
        count: toData.count ?? 0,
        pending: toData.metrics?.pending ?? 0,
        inTransit: toData.metrics?.inTransit ?? 0,
        moduleId: 'transfer-orders',
        data: toData
      };
    }

    if (ctx.data?.['transfer-orders']?.count !== undefined) {
      return {
        count: ctx.data['transfer-orders'].count,
        pending: ctx.data['transfer-orders'].metrics?.pending ?? 0,
        inTransit: ctx.data['transfer-orders'].metrics?.inTransit ?? 0,
        moduleId: 'transfer-orders',
        data: ctx.data['transfer-orders']
      };
    }

    if (ctx.data?.transferOrders?.total !== undefined) {
      return {
        count: ctx.data.transferOrders.total,
        pending: ctx.data.transferOrders.pending ?? 0,
        inTransit: ctx.data.transferOrders.inTransit ?? 0,
        moduleId: 'transferOrders',
        data: ctx.data.transferOrders
      };
    }

    if (ctx.data?.transferOrders?.count !== undefined) {
      return {
        count: ctx.data.transferOrders.count,
        pending: ctx.data.transferOrders.metrics?.pending ?? 0,
        inTransit: ctx.data.transferOrders.metrics?.inTransit ?? 0,
        moduleId: 'transferOrders',
        data: ctx.data.transferOrders
      };
    }

    return undefined;
  },

  /**
   * GRNs count intent
   */
  get_grns_count: (ctx) => {
    const grnData = getModuleDataFromContext(ctx, 'grns');
    if (grnData) {
      return {
        count: grnData.count ?? 0,
        pending: grnData.metrics?.pending ?? 0,
        approved: grnData.metrics?.approved ?? 0,
        rejected: grnData.metrics?.rejected ?? 0,
        moduleId: 'grns',
        data: grnData
      };
    }

    if (ctx.data?.['grns']?.count !== undefined) {
      return {
        count: ctx.data['grns'].count,
        pending: ctx.data['grns'].metrics?.pending ?? 0,
        approved: ctx.data['grns'].metrics?.approved ?? 0,
        rejected: ctx.data['grns'].metrics?.rejected ?? 0,
        moduleId: 'grns',
        data: ctx.data['grns']
      };
    }

    if (ctx.data?.grn?.total !== undefined) {
      return {
        count: ctx.data.grn.total,
        pending: ctx.data.grn.pending ?? 0,
        approved: ctx.data.grn.approved ?? 0,
        rejected: ctx.data.grn.rejected ?? 0,
        moduleId: 'grn',
        data: ctx.data.grn
      };
    }

    if (ctx.data?.grnRecords?.count !== undefined) {
      return {
        count: ctx.data.grnRecords.count,
        pending: ctx.data.grnRecords.metrics?.pending ?? 0,
        approved: ctx.data.grnRecords.metrics?.approved ?? 0,
        rejected: ctx.data.grnRecords.metrics?.rejected ?? 0,
        moduleId: 'grnRecords',
        data: ctx.data.grnRecords
      };
    }

    return undefined;
  },

  /**
   * Users count intent
   */
  get_users_count: (ctx) => {
    const usersData = getModuleDataFromContext(ctx, 'user-management');
    if (usersData) {
      return {
        count: usersData.count ?? 0,
        active: usersData.metrics?.active ?? 0,
        pending: usersData.metrics?.pending ?? 0,
        moduleId: 'user-management',
        data: usersData
      };
    }

    if (ctx.data?.['user-management']?.count !== undefined) {
      return {
        count: ctx.data['user-management'].count,
        active: ctx.data['user-management'].metrics?.active ?? 0,
        pending: ctx.data['user-management'].metrics?.pending ?? 0,
        moduleId: 'user-management',
        data: ctx.data['user-management']
      };
    }

    if (ctx.data?.users?.total !== undefined) {
      return {
        count: ctx.data.users.total,
        active: ctx.data.users.active ?? 0,
        pending: ctx.data.users.pending ?? 0,
        moduleId: 'users',
        data: ctx.data.users
      };
    }

    if (ctx.data?.userManagement?.count !== undefined) {
      return {
        count: ctx.data.userManagement.count,
        active: ctx.data.userManagement.metrics?.active ?? 0,
        pending: ctx.data.userManagement.metrics?.pending ?? 0,
        moduleId: 'userManagement',
        data: ctx.data.userManagement
      };
    }

    return undefined;
  },

  /**
   * Accounts Payable intent
   */
  get_accounts_payable: (ctx) => {
    const apData = getModuleDataFromContext(ctx, 'accounts-payable');
    if (apData) {
      return {
        totalDues: apData.totalDues ?? 0,
        overdueDues: apData.overdueDues ?? 0,
        suppliersCount: apData.suppliersCount ?? 0,
        totalTransactions: apData.totalTransactions ?? 0,
        moduleId: 'accounts-payable',
        data: apData
      };
    }

    if (ctx.data?.['accounts-payable']) {
      return {
        totalDues: ctx.data['accounts-payable'].totalDues ?? 0,
        overdueDues: ctx.data['accounts-payable'].overdueDues ?? 0,
        suppliersCount: ctx.data['accounts-payable'].suppliersCount ?? 0,
        totalTransactions: ctx.data['accounts-payable'].totalTransactions ?? 0,
        moduleId: 'accounts-payable',
        data: ctx.data['accounts-payable']
      };
    }

    if (ctx.data?.accountsPayable) {
      return {
        totalDues: ctx.data.accountsPayable.totalDues ?? 0,
        overdueDues: ctx.data.accountsPayable.overdue ?? 0,
        suppliersCount: ctx.data.accountsPayable.totalSuppliers ?? 0,
        totalTransactions: ctx.data.accountsPayable.totalTransactions ?? 0,
        moduleId: 'accountsPayable',
        data: ctx.data.accountsPayable
      };
    }

    return undefined;
  },

  /**
   * RM Forecasting intent
   */
  get_rm_forecasting: (ctx) => {
    const rmData = getModuleDataFromContext(ctx, 'rm-forecasting');
    if (rmData) {
      return {
        totalBudget: rmData.totalBudget ?? 0,
        itemsToOrder: rmData.itemsToOrder ?? 0,
        savings: rmData.savings ?? 0,
        forecastAccuracy: rmData.forecastAccuracy ?? 0,
        moduleId: 'rm-forecasting',
        data: rmData
      };
    }

    if (ctx.data?.['rm-forecasting']) {
      return {
        totalBudget: ctx.data['rm-forecasting'].totalBudget ?? 0,
        itemsToOrder: ctx.data['rm-forecasting'].itemsToOrder ?? 0,
        savings: ctx.data['rm-forecasting'].savings ?? 0,
        forecastAccuracy: ctx.data['rm-forecasting'].forecastAccuracy ?? 0,
        moduleId: 'rm-forecasting',
        data: ctx.data['rm-forecasting']
      };
    }

    if (ctx.data?.rmForecasting) {
      return {
        totalBudget: ctx.data.rmForecasting.netPurchaseBudget ?? 0,
        itemsToOrder: ctx.data.rmForecasting.itemsToPurchase ?? 0,
        savings: ctx.data.rmForecasting.potentialSavings ?? 0,
        forecastAccuracy: ctx.data.rmForecasting.forecastAccuracy ?? 0,
        moduleId: 'rmForecasting',
        data: ctx.data.rmForecasting
      };
    }

    return undefined;
  },

  /**
   * Warehouse Dashboard intent
   */
  get_warehouse_dashboard: (ctx) => {
    const whData = getModuleDataFromContext(ctx, 'warehouse-dashboard');
    if (whData) {
      return {
        inventoryValue: whData.inventoryValue ?? 0,
        outOfStock: whData.outOfStock ?? 0,
        lowStock: whData.lowStock ?? 0,
        transferCount: whData.transferCount ?? 0,
        moduleId: 'warehouse-dashboard',
        data: whData
      };
    }

    if (ctx.data?.['warehouse-dashboard']) {
      return {
        inventoryValue: ctx.data['warehouse-dashboard'].inventoryValue ?? 0,
        outOfStock: ctx.data['warehouse-dashboard'].outOfStock ?? 0,
        lowStock: ctx.data['warehouse-dashboard'].lowStock ?? 0,
        transferCount: ctx.data['warehouse-dashboard'].transferCount ?? 0,
        moduleId: 'warehouse-dashboard',
        data: ctx.data['warehouse-dashboard']
      };
    }

    if (ctx.data?.warehouseDashboard) {
      return {
        inventoryValue: ctx.data.warehouseDashboard.totalInventoryValue ?? 0,
        outOfStock: ctx.data.warehouseDashboard.outOfStock ?? 0,
        lowStock: ctx.data.warehouseDashboard.lowStock ?? 0,
        transferCount: ctx.data.warehouseDashboard.transferValue ?? 0,
        moduleId: 'warehouseDashboard',
        data: ctx.data.warehouseDashboard
      };
    }

    return undefined;
  },

  /**
   * Module list intent
   */
  get_module_list: (ctx) => {
    return ctx.modules ?? [];
  },

  /**
   * Generic module data intent (uses module ID from intent)
   */
  get_module_data: (ctx, moduleId) => {
    if (!moduleId) return undefined;

    const moduleData = getModuleDataFromContext(ctx, moduleId);
    if (moduleData) {
      return {
        count: moduleData.count ?? 0,
        metrics: moduleData.metrics ?? {},
        moduleId: moduleId,
        data: moduleData
      };
    }

    // Try alternative module ID formats
    const alternatives = [
      moduleId.replace(/-/g, '_'),
      moduleId.replace(/_/g, '-'),
      moduleId.toLowerCase(),
      moduleId.toUpperCase()
    ];

    for (const altId of alternatives) {
      if (altId !== moduleId) {
        const altData = getModuleDataFromContext(ctx, altId);
        if (altData) {
          return {
            count: altData.count ?? 0,
            metrics: altData.metrics ?? {},
            moduleId: altId,
            data: altData
          };
        }
      }
    }

    return undefined;
  }
};

/**
 * Resolve intent data from context using normalized mapping
 * @param {string} intentType - The resolved intent type from Gemini
 * @param {Object} context - Full system context
 * @param {Object} intentParams - Additional intent parameters (module, metric, entity)
 * @returns {Object|undefined} Resolved data object or undefined if not found
 */
export function resolveIntentData(intentType, context, intentParams = {}) {
  // Handle unknown intent
  if (!intentType || intentType === 'unknown') {
    return undefined;
  }

  // Get resolver function
  const resolver = INTENT_CONTEXT_MAP[intentType];
  if (!resolver) {
    console.error(`Intent resolver not found for intent: ${intentType}`);
    return undefined;
  }

  // Resolve data with context and optional params
  let resolvedData;
  if (intentType === 'get_module_data') {
    // Pass moduleId for generic module data intent
    resolvedData = resolver(context, intentParams.module);
  } else {
    resolvedData = resolver(context);
  }

  // HARD ASSERTION: If intent is known but resolver returns undefined, log error
  if (resolvedData === undefined) {
    console.error(`Intent resolved but context mapping failed:`, {
      intent: intentType,
      module: intentParams.module,
      contextKeys: Object.keys(context.data || {}),
      availableModules: (context.modules || []).map(m => m.id)
    });
  }

  return resolvedData;
}

/**
 * Check if resolved data is available (not undefined and has valid status)
 * @param {string} intentType - The intent type
 * @param {Object} resolvedData - The resolved data
 * @param {Object} context - Full system context
 * @returns {boolean} True if data is available
 */
export function isResolvedDataAvailable(intentType, resolvedData, context) {
  if (!resolvedData) return false;

  // For module-specific intents, check data status
  if (resolvedData.moduleId && context.dataStatus) {
    const status = context.dataStatus[resolvedData.moduleId];
    return status === 'loaded' || status === 'cached';
  }

  // For non-module intents (like user name), just check if data exists
  return true;
}
