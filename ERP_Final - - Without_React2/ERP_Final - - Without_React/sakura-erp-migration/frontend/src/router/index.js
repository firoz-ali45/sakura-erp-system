import { createRouter, createWebHashHistory } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const routes = [
  {
    path: '/',
    redirect: '/homeportal'
  },
  {
    path: '/homeportal',
    name: 'HomePortal',
    component: () => import('../views/HomePortal.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'HomePortalDefault',
        component: () => import('../views/HomeDashboard.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'dashboard',
        name: 'HomeDashboard',
        component: () => import('../views/HomeDashboard.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'items',
    name: 'InventoryItems',
        component: () => import('../views/inventory/Items.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'item-detail/:id',
    name: 'ItemDetail',
        component: () => import('../views/inventory/ItemDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'categories',
    name: 'InventoryCategories',
    component: () => import('../views/inventory/Categories.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'suppliers',
    name: 'InventorySuppliers',
        component: () => import('../views/inventory/Suppliers.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'suppliers/:id',
    name: 'SupplierDetail',
    component: () => import('../views/inventory/SupplierDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'pr',
        name: 'PurchaseRequests',
        component: () => import('../views/purchase-requests/PRList.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'pr-create',
        name: 'PRCreate',
        component: () => import('../views/purchase-requests/PRCreate.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'pr-detail/:id',
        name: 'PRDetail',
        component: () => import('../views/purchase-requests/PRDetail.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'pr-convert-to-po/:id',
        name: 'PRConvertToPO',
        component: () => import('../views/purchase-requests/PRConvertToPO.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'purchase-orders',
    name: 'InventoryPurchaseOrders',
        component: () => import('../views/inventory/PurchaseOrders.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'purchase-order-detail/:id',
    name: 'PurchaseOrderDetail',
        component: () => import('../views/inventory/PurchaseOrderDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'transfer-orders',
    name: 'InventoryTransferOrders',
        component: () => import('../views/inventory/TransferOrders.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'transfer-order-detail/:id',
    name: 'TransferOrderDetail',
        component: () => import('../views/inventory/TransferOrderDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'grns',
    name: 'InventoryGRNs',
        component: () => import('../views/inventory/GRNs.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'grn-detail/:id',
    name: 'GRNDetail',
        component: () => import('../views/inventory/GRNDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'stock-overview',
    name: 'StockOverview',
        component: () => import('../views/inventory/StockOverview.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'reports/inventory-levels',
    name: 'InventoryLevels',
        component: () => import('../views/inventory/reports/InventoryLevels.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'settings/inventory-locations',
    name: 'InventoryLocations',
        component: () => import('../views/settings/InventoryLocations.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'purchasing',
    name: 'Purchasing',
        component: () => import('../views/inventory/Purchasing.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'purchasing-detail/:id',
    name: 'PurchasingDetail',
        component: () => import('../views/inventory/PurchasingDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'payments',
    name: 'Payments',
        component: () => import('../views/finance/Payments.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'payment-detail/:id',
    name: 'PaymentDetail',
        component: () => import('../views/finance/PaymentDetail.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'finance-more',
    name: 'FinanceMore',
        component: () => import('../views/finance/FinanceMore.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'finance-more/payment-configuration',
    name: 'PaymentConfiguration',
        component: () => import('../views/finance/PaymentConfiguration.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'payment-configuration',
    redirect: { name: 'PaymentConfiguration' }
  },
  {
        path: 'finance-reports',
    name: 'FinanceReports',
        component: () => import('../views/finance/FinanceDashboard.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'tags',
    name: 'Tags',
        component: () => import('../views/manage/Tags.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'more',
        name: 'InventoryMore',
        component: () => import('../views/inventory/More.vue'),
    meta: { requiresAuth: true }
  },
  {
        path: 'user-management',
    name: 'UserManagement',
    component: () => import('../views/UserManagement.vue'),
    meta: { requiresAuth: true }
      },
      {
        path: 'accounts-payable',
        name: 'AccountsPayable',
        component: () => import('../views/finance/AccountsPayable.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'reports-accounts-payable',
        name: 'ReportsAccountsPayable',
        component: () => import('../views/reports/AccountsPayable.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'rm-forecasting',
        name: 'RMForecasting',
        component: () => import('../views/reports/RMForecasting.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'warehouse-dashboard',
        name: 'WarehouseDashboard',
        component: () => import('../views/reports/WarehouseDashboard.vue'),
        meta: { requiresAuth: true }
      },
      {
        path: 'food-quality-traceability',
        name: 'FoodQualityTraceability',
        component: () => import('../views/reports/FoodQualityTraceability.vue'),
        meta: { requiresAuth: true }
      }
    ]
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue'),
    meta: { requiresAuth: false }
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes
});

// Navigation guard - PRESERVE hash routes on refresh
router.beforeEach(async (to, from, next) => {
  try {
    const authStore = useAuthStore();
    
    // Check if user is authenticated
    const isAuth = authStore.isAuthenticated?.value ?? false;
    
    // Also check localStorage for session persistence (for Supabase/localStorage auth) - safe check
    let sakuraLoggedIn = false;
    let hasUser = false;
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        sakuraLoggedIn = localStorage.getItem('sakura_logged_in') === 'true';
        hasUser = !!localStorage.getItem('sakura_current_user');
      }
    } catch (e) {
      console.warn('⚠️ Error reading localStorage in router guard:', e);
    }
    
    // User is considered authenticated if:
    // 1. Auth store says authenticated, OR
    // 2. sakura_logged_in is true AND user exists in localStorage
    let isAuthenticated = isAuth || (sakuraLoggedIn && hasUser);

    // If we think we are authenticated, verify the user still exists and is active
    // BUT don't block navigation - do this async
    if (isAuthenticated && authStore.ensureUserStillExists) {
      authStore.ensureUserStillExists().catch(() => {
        // Silent fail - don't block navigation
      });
    }
    
    // CRITICAL: Preserve hash routes - never redirect away from valid hash routes
    // Only redirect to login if auth is required and user is not authenticated
    if (to.meta.requiresAuth && !isAuthenticated) {
      // Only redirect if we're not already on login page
      if (to.path !== '/login' && to.path !== '/') {
        console.warn('🟡 [Router] Auth check failed, redirecting to login. Route:', to.path);
        next('/login');
      } else {
        next();
      }
    } else if (to.path === '/login' && isAuthenticated) {
      // User is authenticated and on login page - redirect to homeportal
      // BUT preserve the intended route if it was specified
      let intendedRoute = null;
      try {
        if (typeof window !== 'undefined' && window.sessionStorage) {
          intendedRoute = sessionStorage.getItem('intended_route');
          if (intendedRoute && intendedRoute !== '/login') {
            sessionStorage.removeItem('intended_route');
            next(intendedRoute);
            return;
          }
        }
      } catch (e) {
        console.warn('⚠️ Error reading sessionStorage:', e);
      }
      next('/homeportal');
    } else {
      // Valid route - allow navigation (preserves hash routes on refresh)
      console.log('✅ [Router] Route navigation allowed:', {
        from: from.path,
        to: to.path,
        toName: to.name,
        fullPath: to.fullPath,
        hash: to.hash,
        matched: to.matched.length > 0
      });
      next();
    }
  } catch (error) {
    console.error('❌ [Router] Error in navigation guard:', error);
    // On error, allow navigation to prevent blocking
    next();
  }
});

export default router;

