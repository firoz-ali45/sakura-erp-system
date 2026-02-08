/**
 * Module Registry System
 * Auto-discovers all ERP modules and their data sources
 * Future-proof: New modules automatically appear without AI code changes
 */

import { sidebarConfig } from '@/config/sidebarConfig';
// Import all Supabase data fetchers dynamically to avoid circular dependencies
// These will be loaded at runtime

/**
 * Module Data Source Mappings
 * Maps each module to its Supabase table or data fetcher
 */
/**
 * Module Data Mappings
 * Maps each module to its data source and fetcher function name
 * Fetchers are loaded dynamically to avoid circular dependencies
 */
const MODULE_DATA_MAPPINGS = {
  // Inventory Module
  'items': {
    dataSource: 'supabase',
    table: 'inventory_items',
    fetcherName: 'loadItemsFromSupabase',
    metrics: ['count', 'lowStock'],
    nameKey: 'name'
  },
  'suppliers': {
    dataSource: 'supabase',
    table: 'suppliers',
    fetcherName: 'loadSuppliersFromSupabase',
    metrics: ['count'],
    nameKey: 'name'
  },
  'purchase-orders': {
    dataSource: 'supabase',
    table: 'purchase_orders',
    fetcherName: 'loadPurchaseOrdersFromSupabase',
    metrics: ['count', 'pending', 'completed'],
    nameKey: 'po_number'
  },
  'transfer-orders': {
    dataSource: 'supabase',
    table: 'transfer_orders',
    fetcherName: 'loadTransferOrdersFromSupabase',
    metrics: ['count', 'pending', 'inTransit'],
    nameKey: 'transfer_number'
  },
  'grns': {
    dataSource: 'supabase',
    table: 'grn_inspections',
    fetcherName: 'loadGRNsFromSupabase',
    metrics: ['count', 'pending', 'approved', 'rejected'],
    nameKey: 'grn_number'
  },
  
  // Reports Module (Google Sheets)
  'accounts-payable': {
    dataSource: 'google_sheets',
    sheetId: '1xxx', // Placeholder - actual IDs come from config
    fetcherName: null, // Will be loaded from homeSummaryService
    metrics: ['totalDues', 'overdueDues', 'suppliersCount'],
    nameKey: null
  },
  'rm-forecasting': {
    dataSource: 'google_sheets',
    sheetId: '1xxx',
    fetcherName: null,
    metrics: ['totalBudget', 'itemsToOrder', 'savings'],
    nameKey: null
  },
  'warehouse-dashboard': {
    dataSource: 'google_sheets',
    sheetId: '1xxx',
    fetcherName: null,
    metrics: ['inventoryValue', 'transferCount'],
    nameKey: null
  },
  
  // User Management
  'user-management': {
    dataSource: 'supabase',
    table: 'users',
    fetcherName: 'getUsers',
    metrics: ['count', 'active', 'pending'],
    nameKey: 'name'
  }
};

/**
 * Load fetcher function dynamically
 */
async function loadFetcher(fetcherName) {
  if (!fetcherName) return null;
  
  try {
    const supabaseModule = await import('./supabase');
    return supabaseModule[fetcherName] || null;
  } catch (error) {
    console.error(`Error loading fetcher ${fetcherName}:`, error);
    return null;
  }
}

/**
 * Get all registered modules from sidebar config
 */
export function getAllModules() {
  const modules = [];
  
  const extractModules = (items) => {
    items.forEach(item => {
      if (item.children) {
        item.children.forEach(child => {
          if (child.id && MODULE_DATA_MAPPINGS[child.id]) {
            const mapping = MODULE_DATA_MAPPINGS[child.id];
            modules.push({
              id: child.id,
              parentId: item.id,
              parentLabel: item.i18nKey,
              label: child.i18nKey,
              route: child.route,
              icon: child.icon,
              dataSource: mapping.dataSource,
              table: mapping.table,
              fetcherName: mapping.fetcherName,
              metrics: mapping.metrics,
              nameKey: mapping.nameKey
            });
          }
        });
      }
    });
  };
  
  extractModules(sidebarConfig);
  return modules;
}

/**
 * Get module by ID
 */
export function getModuleById(moduleId) {
  const modules = getAllModules();
  return modules.find(m => m.id === moduleId);
}

/**
 * Get all Supabase modules
 */
export function getSupabaseModules() {
  return getAllModules().filter(m => m.dataSource === 'supabase');
}

/**
 * Get all Google Sheets modules
 */
export function getGoogleSheetsModules() {
  return getAllModules().filter(m => m.dataSource === 'google_sheets');
}

/**
 * Get modules by parent (e.g., all inventory modules)
 */
export function getModulesByParent(parentId) {
  return getAllModules().filter(m => m.parentId === parentId);
}

/**
 * Register a new module (for future extensibility)
 */
export function registerModule(moduleId, config) {
  MODULE_DATA_MAPPINGS[moduleId] = config;
}

/**
 * Get module data fetcher (async - loads dynamically)
 */
export async function getModuleFetcher(moduleId) {
  const mapping = MODULE_DATA_MAPPINGS[moduleId];
  if (!mapping?.fetcherName) return null;
  return await loadFetcher(mapping.fetcherName);
}

/**
 * Get module metrics schema
 */
export function getModuleMetrics(moduleId) {
  const mapping = MODULE_DATA_MAPPINGS[moduleId];
  return mapping?.metrics || [];
}
