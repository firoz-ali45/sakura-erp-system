/**
 * Central Sidebar Configuration
 * Single source of truth for all sidebar navigation items
 * Zero hardcoded routes or labels in components
 */

export const sidebarConfig = [
  {
    id: 'home-portal',
    route: '/homeportal/dashboard',
    icon: 'fas fa-tachometer-alt',
    i18nKey: 'homePortal.title',
    exact: true
  },
  {
    id: 'inventory',
    label: 'inventory',
    icon: 'fas fa-shopping-bag',
    i18nKey: 'homePortal.inventory',
    children: [
      {
        id: 'items',
        route: '/homeportal/items',
        icon: 'fas fa-box',
        i18nKey: 'homePortal.inventoryItems'
      },
      {
        id: 'suppliers',
        route: '/homeportal/suppliers',
        icon: 'fas fa-truck',
        i18nKey: 'homePortal.inventorySuppliers'
      },
      {
        id: 'purchase-requests',
        route: '/homeportal/pr',
        icon: 'fas fa-file-alt',
        i18nKey: 'homePortal.purchaseRequests',
        label: 'Purchase Requests'
      },
      {
        id: 'purchase-orders',
        route: '/homeportal/purchase-orders',
        icon: 'fas fa-file-invoice',
        i18nKey: 'homePortal.inventoryPurchaseOrders'
      },
      {
        id: 'transfer-orders',
        route: '/homeportal/transfer-orders',
        icon: 'fas fa-exchange-alt',
        i18nKey: 'homePortal.inventoryTransferOrders'
      },
      {
        id: 'grns',
        route: '/homeportal/grns',
        icon: 'fas fa-clipboard-list',
        i18nKey: 'inventory.grn.title'
      },
      {
        id: 'stock-overview',
        route: '/homeportal/stock-overview',
        icon: 'fas fa-boxes',
        i18nKey: 'inventory.stockOverview.title'
      },
      {
        id: 'inventory-levels',
        route: '/homeportal/reports/inventory-levels',
        icon: 'fas fa-layer-group',
        i18nKey: 'inventory.reports.inventoryLevels'
      },
      {
        id: 'inventory-control',
        route: '/homeportal/reports/inventory-control',
        icon: 'fas fa-tasks',
        i18nKey: 'inventory.reports.inventoryControl'
      },
      {
        id: 'inventory-history',
        route: '/homeportal/reports/inventory-history',
        icon: 'fas fa-history',
        i18nKey: 'inventory.reports.inventoryHistory'
      },
      {
        id: 'report-purchasing',
        route: '/homeportal/reports/purchasing',
        icon: 'fas fa-file-invoice-dollar',
        i18nKey: 'inventory.reports.purchasing'
      },
      {
        id: 'report-transfer-orders',
        route: '/homeportal/reports/transfer-orders',
        icon: 'fas fa-exchange-alt',
        i18nKey: 'inventory.reports.transferOrders'
      },
      {
        id: 'report-transfers',
        route: '/homeportal/reports/transfers',
        icon: 'fas fa-arrows-alt',
        i18nKey: 'inventory.reports.transfers'
      },
      {
        id: 'cost-adjustment-history',
        route: '/homeportal/reports/cost-adjustment-history',
        icon: 'fas fa-adjust',
        i18nKey: 'inventory.reports.costAdjustmentHistory'
      },
      {
        id: 'inventory-count',
        action: 'loadDashboard',
        actionParam: 'inventory/inventory-count.html',
        icon: 'fas fa-clipboard-check',
        i18nKey: 'homePortal.inventoryCount'
      },
      {
        id: 'transfers',
        route: '/homeportal/transfers',
        icon: 'fas fa-arrows-alt',
        i18nKey: 'homePortal.inventoryTransfers'
      },
      {
        id: 'production',
        route: '/homeportal/production',
        icon: 'fas fa-industry',
        i18nKey: 'homePortal.inventoryProduction'
      },
      {
        id: 'recipes',
        route: '/homeportal/recipes',
        icon: 'fas fa-list-ol',
        i18nKey: 'Recipes / BOM'
      },
      {
        id: 'more',
        route: '/homeportal/more',
        icon: 'fas fa-ellipsis-h',
        i18nKey: 'homePortal.inventoryMore'
      }
    ]
  },
  {
    id: 'finance',
    label: 'finance',
    icon: 'fas fa-university',
    i18nKey: 'homePortal.finance',
    children: [
      {
        id: 'finance-purchasing',
        route: '/homeportal/purchasing',
        icon: 'fas fa-file-invoice-dollar',
        i18nKey: 'homePortal.financePurchasing'
      },
      {
        id: 'payments',
        route: '/homeportal/payments',
        icon: 'fas fa-money-check-alt',
        i18nKey: 'homePortal.payments'
      },
      {
        id: 'accounts-payable',
        route: '/homeportal/accounts-payable',
        icon: 'fas fa-hand-holding-usd',
        i18nKey: 'homePortal.accountsPayable'
      },
      {
        id: 'finance-more',
        route: '/homeportal/finance-more',
        icon: 'fas fa-ellipsis-h',
        i18nKey: 'homePortal.financeMore'
      },
      {
        id: 'finance-reports',
        route: '/homeportal/finance-reports',
        icon: 'fas fa-chart-pie',
        i18nKey: 'homePortal.financeReports'
      }
    ]
  },
  {
    id: 'reports',
    label: 'reports',
    icon: 'fas fa-chart-bar',
    i18nKey: 'homePortal.reports',
    children: [
      {
        id: 'reports-accounts-payable',
        route: '/homeportal/reports-accounts-payable',
        icon: 'fas fa-file-invoice-dollar',
        i18nKey: 'homePortal.reportsAccountsPayable'
      },
      {
        id: 'rm-forecasting',
        route: '/homeportal/rm-forecasting',
        icon: 'fas fa-chart-line',
        i18nKey: 'homePortal.rmForecasting'
      },
      {
        id: 'warehouse-dashboard',
        route: '/homeportal/warehouse-dashboard',
        icon: 'fas fa-warehouse',
        i18nKey: 'homePortal.warehouseDashboard'
      },
      {
        id: 'food-quality-traceability',
        route: '/homeportal/food-quality-traceability',
        icon: 'fas fa-shield-alt',
        i18nKey: 'homePortal.foodQualityTraceability'
      }
    ]
  },
  {
    id: 'manage',
    label: 'manage',
    icon: 'fas fa-cog',
    i18nKey: 'homePortal.manage',
    children: [
      {
        id: 'user-management',
        route: '/homeportal/user-management',
        icon: 'fas fa-users-cog',
        i18nKey: 'homePortal.userManagement',
        badge: 'pendingUsersCount'
      },
      {
        id: 'departments',
        route: '/homeportal/user-management/departments',
        icon: 'fas fa-sitemap',
        i18nKey: 'homePortal.departments',
        label: 'Departments'
      },
      {
        id: 'tags',
        route: '/homeportal/tags',
        icon: 'fas fa-tags',
        i18nKey: 'homePortal.manageMore'
      },
      {
        id: 'settings-inventory-locations',
        route: '/homeportal/settings/inventory-locations',
        icon: 'fas fa-map-marker-alt',
        i18nKey: 'inventory.locations.title'
      }
    ]
  },
  {
    id: 'settings',
    action: 'openSettings',
    icon: 'fas fa-cog',
    i18nKey: 'homePortal.settings',
    footer: true // Render in footer section
  }
];

/**
 * Get sidebar item by ID
 */
export function getSidebarItem(id) {
  const findInTree = (items, targetId) => {
    for (const item of items) {
      if (item.id === targetId) return item;
      if (item.children) {
        const found = findInTree(item.children, targetId);
        if (found) return found;
      }
    }
    return null;
  };
  
  return findInTree(sidebarConfig, id);
}

/**
 * Get all routes from sidebar config
 */
export function getAllRoutes() {
  const routes = [];
  
  const extractRoutes = (items) => {
    items.forEach(item => {
      if (item.route) {
        routes.push(item.route);
      }
      if (item.children) {
        extractRoutes(item.children);
      }
    });
  };
  
  extractRoutes(sidebarConfig);
  return routes;
}

/**
 * Check if a route exists in sidebar config
 */
export function routeExists(route) {
  return getAllRoutes().includes(route);
}

/**
 * Get active item based on current route
 */
export function getActiveItem(currentRoute) {
  const findActive = (items, route) => {
    for (const item of items) {
      // Check if current route matches this item
      if (item.route && (
        item.route === route || 
        (item.exact !== true && route.startsWith(item.route))
      )) {
        return item;
      }
      
      // Check children
      if (item.children) {
        const found = findActive(item.children, route);
        if (found) return found;
      }
    }
    return null;
  };
  
  return findActive(sidebarConfig, currentRoute);
}

/**
 * Get parent item for a given item ID
 */
export function getParentItem(childId) {
  const findParent = (items, targetId, parent = null) => {
    for (const item of items) {
      if (item.id === targetId) return parent;
      if (item.children) {
        const found = findParent(item.children, targetId, item);
        if (found !== null) return found;
      }
    }
    return null;
  };
  
  return findParent(sidebarConfig, childId);
}
