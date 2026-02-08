/**
 * Sakura AI Chatbot Service
 * Production-Grade ERP Intelligence Layer
 * Uses Gemini API for dynamic intent resolution
 * Dynamically connects to ALL system modules without hardcoding
 */

import { buildChatbotContext } from './ChatbotContextService';
import { resolveIntentWithGemini } from './aiIntentResolver';
import { resolveIntentData, isResolvedDataAvailable } from './intentContextResolver';
import { formatNumber, formatCurrency } from '@/utils/numberFormat';
import { formatDate } from '@/utils/dateFormat';

/**
 * Generate intelligent response with DYNAMIC intent resolution via Gemini
 * @param {string} userMessage - User's question/message
 * @param {string} locale - Current locale ('en' or 'ar')
 * @param {Object} user - Current logged-in user object
 */
export async function generateIntelligentResponse(userMessage, locale = 'en', user = null) {
  // STEP 1: Build comprehensive context with LIVE data (MANDATORY - runs before every response)
  const context = await buildChatbotContext(user);
  
  // STEP 2: Resolve user intent using Gemini API (NO hardcoded matching)
  let intent;
  try {
    intent = await resolveIntentWithGemini(userMessage, context);
  } catch (error) {
    console.error('Error resolving intent with Gemini:', error);
    // If Gemini API fails, return professional ERP error message
    return locale === 'ar'
      ? 'نظام الذكاء غير متاح حالياً. يرجى المحاولة لاحقاً.'
      : 'System intelligence is temporarily unavailable. Please retry.';
  }

  // STEP 3: Handle unknown intent
  if (intent.intent === 'unknown' || !intent.intent) {
    // Return data-aware fallback with real module names (ONLY for unknown intents)
    const availableModulesList = context.modules
      .filter(m => m.route)
      .map(m => getModuleDisplayName(m.label || m.id, locale))
      .filter((name, index, arr) => arr.indexOf(name) === index)
      .slice(0, 10)
      .join(', ');
    
    return locale === 'ar'
      ? `لم يتم العثور على بيانات مطابقة لطلبك حالياً. الوحدات المتاحة: ${availableModulesList}.`
      : `I could not find matching system data for your request. Available modules: ${availableModulesList}.`;
  }

  // STEP 4: Resolve intent data using intent-to-context resolver (MANDATORY - no direct context access)
  const resolvedData = resolveIntentData(intent.intent, context, {
    module: intent.module,
    metric: intent.metric,
    entity: intent.entity
  });

  // STEP 5: Handle unresolved data for known intents (professional ERP message)
  if (resolvedData === undefined) {
    // HARD ASSERTION: This should not happen for valid intents
    console.error('Intent resolved but context mapping failed:', {
      intent: intent.intent,
      module: intent.module,
      availableModules: context.modules.map(m => m.id),
      availableDataKeys: Object.keys(context.data || {})
    });

    // Return professional ERP unavailability message (NOT generic fallback)
    return locale === 'ar'
      ? 'البيانات المطلوبة غير متاحة حالياً. يرجى المحاولة مرة أخرى خلال بضع ثوانٍ.'
      : 'The requested data is currently unavailable. Please retry in a few seconds.';
  }

  // STEP 6: Check if resolved data is actually available (not just structure)
  if (!isResolvedDataAvailable(intent.intent, resolvedData, context)) {
    const moduleName = resolvedData.moduleId ? getModuleDisplayName(resolvedData.moduleId, locale) : '';
    return locale === 'ar'
      ? `بيانات ${moduleName} قيد التزامن حالياً. يرجى المحاولة مرة أخرى خلال بضع ثوانٍ.`
      : `${moduleName} data is currently syncing. Please retry in a few seconds.`;
  }

  // STEP 7: Format response based on resolved intent and data
  const response = formatResponseFromResolvedData(intent, resolvedData, context, locale);
  
  // STEP 5: Runtime assertion - block generic responses
  if (typeof response === 'string') {
    const forbiddenStrings = [
      'understand your question',
      'can answer about',
      'please ask',
      'What would you like',
      'How can I help',
      'You can ask',
      'What specifically',
      'What do you want'
    ];
    
    const lowerResponse = response.toLowerCase();
    for (const forbidden of forbiddenStrings) {
      if (lowerResponse.includes(forbidden.toLowerCase())) {
        throw new Error(`FORBIDDEN: Generic chatbot response detected: "${forbidden}". This must never happen in production. Response was: "${response}"`);
      }
    }
  }
  
  return response;
}

/**
 * Format response from resolved intent data
 * @param {Object} intent - Resolved intent object from Gemini
 * @param {Object} resolvedData - Resolved data from intent-to-context resolver
 * @param {Object} context - Full system context
 * @param {string} locale - Current locale
 * @returns {string} Formatted response
 */
function formatResponseFromResolvedData(intent, resolvedData, context, locale) {
  const { intent: intentType, metric, entity } = intent;

  // Handle user name intent (resolvedData is the user name string)
  if (intentType === 'get_user_name') {
    if (resolvedData) {
      const userName = resolvedData;
      const userRole = context.user?.role || 'user';
      const moduleCount = context.modules.filter(m => m.route).length;
      return locale === 'ar' 
        ? `مرحباً، اسمي ${userName}. أنا مساعدك الذكي في نظام ساكورا ERP. دوري في النظام: ${userRole}. النظام يحتوي على ${formatNumber(moduleCount, locale)} وحدة نشطة.`
        : `Hello, my name is ${userName}. I'm your intelligent assistant in the Sakura ERP system. My role: ${userRole}. The system has ${formatNumber(moduleCount, locale)} active modules.`;
    }
    return locale === 'ar'
      ? 'أنا مساعدك الذكي في نظام ساكورا ERP. للوصول إلى معلوماتك الشخصية، يرجى تسجيل الدخول.'
      : "I'm your intelligent assistant in the Sakura ERP system. To access your personal information, please log in.";
  }

  // Handle inventory count intent (resolvedData contains count and lowStock)
  if (intentType === 'get_inventory_count') {
    const count = resolvedData.count || 0;
    
    // Check if asking about low stock
    if (metric === 'lowStock' && resolvedData.lowStock !== undefined) {
      const lowStock = resolvedData.lowStock || 0;
      return locale === 'ar'
        ? `يوجد حالياً ${formatNumber(lowStock, locale)} صنف بمخزون منخفض من إجمالي ${formatNumber(count, locale)} صنف.`
        : `You currently have ${formatNumber(lowStock, locale)} items with low stock out of ${formatNumber(count, locale)} total items.`;
    }
    
    return locale === 'ar'
      ? `يوجد حالياً ${formatNumber(count, locale)} صنف في المخزون.`
      : `You currently have ${formatNumber(count, locale)} items in inventory.`;
  }

  // Handle suppliers count intent (resolvedData contains count)
  if (intentType === 'get_suppliers_count') {
    const count = resolvedData.count || 0;
    return locale === 'ar'
      ? `يوجد حالياً ${formatNumber(count, locale)} مورد مسجل في النظام.`
      : `You currently have ${formatNumber(count, locale)} suppliers registered in the system.`;
  }

  // Handle purchase orders count intent (resolvedData contains count, pending, completed)
  if (intentType === 'get_purchase_orders_count') {
    const count = resolvedData.count || 0;
    const pending = resolvedData.pending || 0;
    const completed = resolvedData.completed || 0;
    
    return locale === 'ar'
      ? `يوجد ${formatNumber(count, locale)} أمر شراء في النظام: ${formatNumber(pending, locale)} قيد الانتظار، و ${formatNumber(completed, locale)} مكتمل.`
      : `You have ${formatNumber(count, locale)} purchase orders in the system: ${formatNumber(pending, locale)} pending, and ${formatNumber(completed, locale)} completed.`;
  }

  // Handle transfer orders count intent (resolvedData contains count, pending, inTransit)
  if (intentType === 'get_transfer_orders_count') {
    const count = resolvedData.count || 0;
    const pending = resolvedData.pending || 0;
    const inTransit = resolvedData.inTransit || 0;
    
    return locale === 'ar'
      ? `يوجد ${formatNumber(count, locale)} أمر نقل في النظام: ${formatNumber(pending, locale)} قيد الانتظار، و ${formatNumber(inTransit, locale)} قيد النقل.`
      : `You have ${formatNumber(count, locale)} transfer orders in the system: ${formatNumber(pending, locale)} pending, and ${formatNumber(inTransit, locale)} in transit.`;
  }

  // Handle GRNs count intent (resolvedData contains count, pending, approved, rejected)
  if (intentType === 'get_grns_count') {
    const count = resolvedData.count || 0;
    const pending = resolvedData.pending || 0;
    const approved = resolvedData.approved || 0;
    const rejected = resolvedData.rejected || 0;
    
    return locale === 'ar'
      ? `يوجد ${formatNumber(count, locale)} إذن استلام في النظام: ${formatNumber(pending, locale)} قيد الانتظار، ${formatNumber(approved, locale)} موافق عليه، و ${formatNumber(rejected, locale)} مرفوض.`
      : `You have ${formatNumber(count, locale)} GRN records in the system: ${formatNumber(pending, locale)} pending, ${formatNumber(approved, locale)} approved, and ${formatNumber(rejected, locale)} rejected.`;
  }

  // Handle users count intent (resolvedData contains count, active, pending)
  if (intentType === 'get_users_count') {
    const count = resolvedData.count || 0;
    const active = resolvedData.active || 0;
    const pending = resolvedData.pending || 0;
    
    return locale === 'ar'
      ? `يوجد ${formatNumber(count, locale)} مستخدم في النظام: ${formatNumber(active, locale)} نشط، ${formatNumber(pending, locale)} قيد الانتظار.`
      : `You have ${formatNumber(count, locale)} users in the system: ${formatNumber(active, locale)} active, ${formatNumber(pending, locale)} pending.`;
  }

  // Handle accounts payable intent (resolvedData contains totalDues, overdueDues, suppliersCount, totalTransactions)
  if (intentType === 'get_accounts_payable') {
    const totalDues = resolvedData.totalDues || 0;
    const overdue = resolvedData.overdueDues || 0;
    const suppliersCount = resolvedData.suppliersCount || 0;
    const transactions = resolvedData.totalTransactions || 0;
    
    return locale === 'ar'
      ? `الحسابات الدائنة: إجمالي المستحقات ${formatCurrency(totalDues, locale)}، المتأخرة ${formatCurrency(overdue, locale)}، من ${formatNumber(suppliersCount, locale)} مورد و ${formatNumber(transactions, locale)} معاملة.`
      : `Accounts Payable: Total dues ${formatCurrency(totalDues, locale)}, Overdue ${formatCurrency(overdue, locale)}, from ${formatNumber(suppliersCount, locale)} suppliers and ${formatNumber(transactions, locale)} transactions.`;
  }

  // Handle RM forecasting intent (resolvedData contains totalBudget, itemsToOrder, savings, forecastAccuracy)
  if (intentType === 'get_rm_forecasting') {
    const budget = resolvedData.totalBudget || 0;
    const itemsToOrder = resolvedData.itemsToOrder || 0;
    const savings = resolvedData.savings || 0;
    const accuracy = resolvedData.forecastAccuracy || 0;
    
    return locale === 'ar'
      ? `توقعات المواد الخام: الميزانية التقديرية ${formatCurrency(budget, locale)}، ${formatNumber(itemsToOrder, locale)} صنف مطلوب للطلب، التوفير المحتمل ${formatCurrency(savings, locale)}، دقة التوقع ${formatNumber(accuracy, locale)}%.`
      : `RM Forecasting: Estimated budget ${formatCurrency(budget, locale)}, ${formatNumber(itemsToOrder, locale)} items to order, potential savings ${formatCurrency(savings, locale)}, forecast accuracy ${formatNumber(accuracy, locale)}%.`;
  }

  // Handle warehouse dashboard intent (resolvedData contains inventoryValue, outOfStock, lowStock, transferCount)
  if (intentType === 'get_warehouse_dashboard') {
    const value = resolvedData.inventoryValue || 0;
    const outOfStock = resolvedData.outOfStock || 0;
    const lowStock = resolvedData.lowStock || 0;
    const transfers = resolvedData.transferCount || 0;
    
    return locale === 'ar'
      ? `المستودع: قيمة المخزون ${formatCurrency(value, locale)}، ${formatNumber(outOfStock, locale)} صنف ناقص، ${formatNumber(lowStock, locale)} صنف بمخزون منخفض، ${formatNumber(transfers, locale)} عملية تحويل.`
      : `Warehouse: Inventory value ${formatCurrency(value, locale)}, ${formatNumber(outOfStock, locale)} out of stock items, ${formatNumber(lowStock, locale)} low stock items, ${formatNumber(transfers, locale)} transfer operations.`;
  }

  // Handle module list intent (resolvedData is the modules array)
  if (intentType === 'get_module_list') {
    const modules = resolvedData || [];
    const modulesList = modules
      .filter(m => m.route)
      .map(m => {
        const moduleDisplayName = getModuleDisplayName(m.label || m.id, locale);
        // Try to get count from context for each module
        const moduleData = context.data?.[m.id];
        const status = moduleData?.count !== undefined
          ? `${formatNumber(moduleData.count, locale)} records`
          : 'available';
        return `${moduleDisplayName} (${status})`;
      })
      .filter((name, index, arr) => arr.indexOf(name) === index)
      .join(', ');
    
    return locale === 'ar'
      ? `الوحدات المتاحة في النظام: ${modulesList}.`
      : `Available modules in the system: ${modulesList}.`;
  }

  // Handle generic module data intent (resolvedData contains count, metrics, moduleId)
  if (intentType === 'get_module_data') {
    const count = resolvedData.count || 0;
    const moduleDisplayName = getModuleDisplayName(resolvedData.moduleId || intent.module, locale);
    
    // If specific metric requested
    if (metric && resolvedData.metrics && resolvedData.metrics[metric] !== undefined) {
      const metricValue = resolvedData.metrics[metric];
      return locale === 'ar'
        ? `${moduleDisplayName}: ${metric} = ${formatNumber(metricValue, locale)}`
        : `${moduleDisplayName}: ${metric} = ${formatNumber(metricValue, locale)}`;
    }
    
    // Default: return count
    return locale === 'ar'
      ? `${moduleDisplayName}: يوجد ${formatNumber(count, locale)} سجل في النظام.`
      : `${moduleDisplayName}: You have ${formatNumber(count, locale)} records in the system.`;
  }

  // This should never be reached since we check for undefined resolvedData earlier
  // But include as safety fallback
  return locale === 'ar'
    ? 'لم يتم العثور على بيانات مطابقة لطلبك حالياً.'
    : 'I could not find matching system data for your request.';
}

/**
 * Get display name for a module (from i18n key or fallback to readable ID)
 */
function getModuleDisplayName(i18nKeyOrId, locale) {
  // Try to extract from i18n key format (e.g., 'homePortal.inventoryItems' -> 'Inventory Items')
  if (i18nKeyOrId && i18nKeyOrId.includes('.')) {
    const parts = i18nKeyOrId.split('.');
    const lastPart = parts[parts.length - 1];
    return formatModuleName(lastPart, locale);
  }
  
  // Fallback: format the ID itself
  return formatModuleName(i18nKeyOrId || '', locale);
}

/**
 * Format module ID to readable name
 */
function formatModuleName(id, locale) {
  if (!id) return '';
  
  // Remove hyphens and capitalize
  const readable = id.replace(/-/g, ' ')
    .replace(/\b\w/g, l => l.toUpperCase());
  
  // Apply translations for common modules
  const translations = {
    en: {
      'items': 'Items',
      'suppliers': 'Suppliers',
      'purchase orders': 'Purchase Orders',
      'transfer orders': 'Transfer Orders',
      'grns': 'GRN & Batch Control',
      'accounts payable': 'Accounts Payable',
      'rm forecasting': 'RM Forecasting',
      'warehouse dashboard': 'Warehouse Dashboard',
      'food quality traceability': 'Food Quality Traceability',
      'user management': 'User Management',
      'inventory count': 'Inventory Count',
      'purchasing': 'Purchasing',
      'transfers': 'Transfers',
      'production': 'Production'
    },
    ar: {
      'items': 'الأصناف',
      'suppliers': 'الموردين',
      'purchase orders': 'أوامر الشراء',
      'transfer orders': 'أوامر التحويل',
      'grns': 'إذن الاستلام',
      'accounts payable': 'الحسابات الدائنة',
      'rm forecasting': 'توقعات المواد الخام',
      'warehouse dashboard': 'لوحة تحكم المستودع',
      'food quality traceability': 'تتبع جودة الطعام',
      'user management': 'إدارة المستخدمين',
      'inventory count': 'عد المخزون',
      'purchasing': 'المشتريات',
      'transfers': 'التحويلات',
      'production': 'الإنتاج'
    }
  };
  
  const localeTranslations = translations[locale] || translations.en;
  const lowerId = readable.toLowerCase();
  
  // Try exact match first
  if (localeTranslations[lowerId]) {
    return localeTranslations[lowerId];
  }
  
  // Try partial match
  for (const [key, value] of Object.entries(localeTranslations)) {
    if (lowerId.includes(key) || key.includes(lowerId)) {
      return value;
    }
  }
  
  // Fallback to formatted readable name
  return readable;
}
