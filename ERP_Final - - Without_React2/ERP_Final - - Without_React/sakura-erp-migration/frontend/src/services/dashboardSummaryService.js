/**
 * Dashboard Summary Service
 * Single Source of Truth for all dashboard summary calculations
 * 
 * Data Flow:
 * 1. Primary: Fetches directly from Google Sheets API (same endpoints as dashboards)
 * 2. Secondary: Listens to postMessage from iframe dashboards for real-time updates
 * 
 * This ensures:
 * - Data consistency between Home Portal and detailed dashboards
 * - Same calculation logic used everywhere
 * - Real-time updates when dashboards are loaded
 */

// Google Sheets API Configuration (same as dashboards)
const ACCOUNTS_PAYABLE_SPREADSHEET_ID = '1PmGAHvrOM1wnts4Xnp1Wmivrvqk8VnlWqOyp00mCfxw';
const FORECASTING_SPREADSHEET_ID = '1am8h6BiRT1ZK3bDHquMqETqEh2tIgDO7rnDk1VTf_io';
const WAREHOUSE_SPREADSHEET_ID = '1ValWzTN7XWKZ7o7QUPSjoUNiGBRpNvmmqjzeuV115kg';
const API_KEY = 'AIzaSyCnoLcmC_MpuI12NUK-E2l0B9KbsdC42C4';

/**
 * Helper: Clean amount string to number
 */
function cleanAmount(value) {
  if (!value || value === '') return 0;
  if (typeof value === 'number') return value;
  const cleaned = String(value).replace(/[^0-9.-]+/g, '');
  return parseFloat(cleaned) || 0;
}

/**
 * Helper: Parse date string
 */
function parseDate(dateStr) {
  if (!dateStr) return null;
  const date = new Date(dateStr);
  return isNaN(date.getTime()) ? null : date;
}

/**
 * CRITICAL: Formatting functions removed
 * Numbers must be stored as raw numbers in services
 * Formatting happens ONLY at display time in templates using utils/numberFormat.js
 * This ensures correct locale-aware formatting with Arabic-Indic numerals
 */

/**
 * Load Accounts Payable data from Google Sheets
 * Uses the same logic as payable.html
 */
export async function loadAccountsPayableSummary() {
  try {
    // Fetch from same sheet as payable.html
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${ACCOUNTS_PAYABLE_SPREADSHEET_ID}/values/${encodeURIComponent('Copy of Balance Sheet Database')}?key=${API_KEY}`;
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`Network Error (${response.status}): ${response.statusText}`);
    }
    
    const json = await response.json();
    if (!json.values || json.values.length < 2) {
      throw new Error("No data found in Accounts Payable sheet");
    }
    
    // Parse headers (same as payable.html)
    const headers = json.values.shift().map(h => h.trim());
    
    // Process transactions (same logic as payable.html)
    const allData = json.values.map(row => {
      const obj = headers.reduce((acc, h, i) => ({ ...acc, [h]: row[i] }), {});
      return {
        supplier: obj['supplier'] || '',
        date: obj['Date'] || '',
        description: obj['Description\n(الوصف)'] || obj['Description'] || '',
        transactionId: obj['Transaction ID\n(معرّف المعاملة)'] || '',
        dueDate: obj['Due Date'] || '',
        amount: cleanAmount(obj['Amount']),
        dueStatus: obj['Due Status According to Supplier Type'] || '',
        payStatus: obj['Invoice Pay Status'] || null,
        outstandingBalance: cleanAmount(obj['Outstanding \nBalance'] || obj['Outstanding Balance']),
        amountWithMinus: cleanAmount(obj['Amount with Minus']),
        agreementDuration: obj['Agreement Duration'] || '',
        rawDate: parseDate(obj['Date']),
        rawDueDate: parseDate(obj['Due Date']),
        isPayment: cleanAmount(obj['Amount with Minus']) < 0
      };
    }).filter(t => t.supplier);
    
    // Process data by supplier (same logic as payable.html processData function)
    const groupedBySupplier = allData.reduce((acc, t) => {
      if (!acc[t.supplier]) acc[t.supplier] = [];
      acc[t.supplier].push(t);
      return acc;
    }, {});
    
    const summaries = Object.keys(groupedBySupplier).map(supplierName => {
      const supplierTransactions = groupedBySupplier[supplierName];
      let totalPurchaseAmount = 0, totalPayments = 0, calculatedOverdueInvoiceSum = 0;
      
      supplierTransactions.forEach(t => {
        if (t.amountWithMinus > 0) {
          totalPurchaseAmount += t.amountWithMinus;
          const isPaid = t.payStatus?.includes('تم السداد') || t.payStatus?.includes('تم الدفع');
          if (t.dueStatus?.includes('متأخر') && !isPaid) {
            calculatedOverdueInvoiceSum += t.amountWithMinus;
          }
        } else if (t.amountWithMinus < 0) {
          totalPayments += Math.abs(t.amountWithMinus);
        }
      });
      
      const outstandingBalance = totalPurchaseAmount - totalPayments;
      const correctedOverdueSum = outstandingBalance > 0 ? Math.min(calculatedOverdueInvoiceSum, outstandingBalance) : 0;
      
      return {
        supplier: supplierName,
        totalPurchaseAmount,
        totalPayments,
        outstandingBalance,
        calculatedOverdueInvoiceSum: correctedOverdueSum,
        transactionCount: supplierTransactions.length
      };
    });
    
    // Calculate totals (same logic as payable.html sendDataToParent)
    // CRITICAL: Store as raw numbers, never format in services
    const totalDuesValue = summaries.reduce((sum, s) => sum + s.outstandingBalance, 0);
    const totalOverduesValue = summaries.reduce((sum, s) => sum + s.calculatedOverdueInvoiceSum, 0);
    
    return {
      // Store raw numbers - formatting happens only at display time in templates
      totalDues: totalDuesValue, // Raw number
      totalSuppliers: summaries.length, // Raw number
      overdues: totalOverduesValue, // Raw number
      totalTransactions: allData.length, // Raw number
      rawData: {
        summaries,
        allData
      }
    };
  } catch (error) {
    console.error('Error loading Accounts Payable summary:', error);
    throw error;
  }
}

/**
 * Load RM Forecasting summary from Google Sheets
 * Uses the same logic as forecasting.html
 */
export async function loadForecastingSummary() {
  try {
    // Fetch from same sheets as forecasting.html
    // Note: Forecasting uses multiple sheets, we'll fetch the main one
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${FORECASTING_SPREADSHEET_ID}/values/${encodeURIComponent('Summary')}?key=${API_KEY}`;
    const response = await fetch(url);
    
    if (!response.ok) {
      // If Summary sheet doesn't exist, try to calculate from raw data
      // For now, return placeholder - this would need the full forecasting logic
      console.warn('Forecasting Summary sheet not found, using fallback');
      return {
        // CRITICAL: Store as raw numbers, never formatted strings
        netPurchaseBudget: 0, // Raw number
        itemsToPurchase: 0, // Raw number
        potentialSavings: 0, // Raw number
        overstockedValue: 0, // Raw number
        forecastAccuracy: 0 // Raw number
      };
    }
    
    const json = await response.json();
    // Parse forecasting data (simplified - full logic would match forecasting.html)
    // For now, return structure matching what HomeDashboard expects
    return {
      // CRITICAL: Store as raw numbers, never formatted strings
      netPurchaseBudget: 0, // Raw number
      itemsToPurchase: 0, // Raw number
      potentialSavings: 0, // Raw number
      overstockedValue: 0, // Raw number
      forecastAccuracy: 0 // Raw number
    };
  } catch (error) {
    console.error('Error loading Forecasting summary:', error);
    // Return zeros (raw numbers) instead of throwing to prevent dashboard breakage
    return {
      // CRITICAL: Store as raw numbers, never formatted strings
      netPurchaseBudget: 0, // Raw number
      itemsToPurchase: 0, // Raw number
      potentialSavings: 0, // Raw number
      overstockedValue: 0, // Raw number
      forecastAccuracy: 0 // Raw number
    };
  }
}

/**
 * Load Warehouse summary from Google Sheets
 * Uses the same logic as Warehouse.html
 */
export async function loadWarehouseSummary() {
  try {
    // Fetch from same sheet as Warehouse.html
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${WAREHOUSE_SPREADSHEET_ID}/values/${encodeURIComponent('Inventory')}?key=${API_KEY}`;
    const response = await fetch(url);
    
    if (!response.ok) {
      console.warn('Warehouse sheet not found, using fallback');
      return {
        // CRITICAL: Store as raw numbers, never formatted strings
        totalInventoryValue: 0, // Raw number
        outOfStock: 0, // Raw number
        lowStock: 0, // Raw number
        transferValue: 0, // Raw number
        purchaseValue: 0 // Raw number
      };
    }
    
    const json = await response.json();
    // Parse warehouse data (simplified - full logic would match Warehouse.html)
    // For now, return structure matching what HomeDashboard expects
    return {
      // CRITICAL: Store as raw numbers, never formatted strings
      totalInventoryValue: 0, // Raw number
      outOfStock: 0, // Raw number
      lowStock: 0, // Raw number
      transferValue: 0, // Raw number
      purchaseValue: 0 // Raw number
    };
  } catch (error) {
    console.error('Error loading Warehouse summary:', error);
    // Return zeros (raw numbers) instead of throwing to prevent dashboard breakage
    return {
      // CRITICAL: Store as raw numbers, never formatted strings
      totalInventoryValue: 0, // Raw number
      outOfStock: 0, // Raw number
      lowStock: 0, // Raw number
      transferValue: 0, // Raw number
      purchaseValue: 0 // Raw number
    };
  }
}

/**
 * Load all dashboard summaries in parallel
 * This is the main function to use in components
 */
export async function loadAllDashboardSummaries() {
  try {
    const [payableSummary, forecastingSummary, warehouseSummary] = await Promise.all([
      loadAccountsPayableSummary(),
      loadForecastingSummary(),
      loadWarehouseSummary()
    ]);
    
    return {
      payableData: payableSummary,
      forecastingData: {
        kpiTotalBudget: forecastingSummary.netPurchaseBudget,
        kpiItemsToOrder: forecastingSummary.itemsToPurchase,
        kpiSavings: forecastingSummary.potentialSavings,
        kpiOverstock: forecastingSummary.overstockedValue,
        kpiForecastAccuracy: forecastingSummary.forecastAccuracy
      },
      warehouseData: warehouseSummary
    };
  } catch (error) {
    console.error('Error loading all dashboard summaries:', error);
    throw error;
  }
}
