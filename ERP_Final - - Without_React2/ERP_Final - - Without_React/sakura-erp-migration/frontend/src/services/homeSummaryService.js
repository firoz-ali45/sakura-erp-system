/**
 * Home Summary Service
 * Hybrid Single-Source-of-Truth Strategy:
 * 1. Fast initial load from cache
 * 2. Background live sync from authoritative sources
 * 3. Real-time updates via postMessage from dashboards
 */

const CACHE_KEY = 'sakura_home_summary_cache';
const CACHE_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Get cached summary data
 */
export function getCachedSummary() {
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    if (!cached) return null;
    
    const data = JSON.parse(cached);
    const now = Date.now();
    
    // Check if cache is expired
    if (data.timestamp && (now - data.timestamp) > CACHE_EXPIRY_MS) {
      localStorage.removeItem(CACHE_KEY);
      return null;
    }
    
    return data.summary || null;
  } catch (error) {
    console.warn('Error reading cache:', error);
    return null;
  }
}

/**
 * Save summary data to cache
 */
export function saveCachedSummary(summary) {
  try {
    const data = {
      summary,
      timestamp: Date.now()
    };
    localStorage.setItem(CACHE_KEY, JSON.stringify(data));
  } catch (error) {
    console.warn('Error saving cache:', error);
  }
}

/**
 * Load Accounts Payable summary from Google Sheets
 * Uses same logic as payable.html dashboard
 */
async function loadAccountsPayableFromAPI() {
  try {
    const SPREADSHEET_ID = '1PmGAHvrOM1wnts4Xnp1Wmivrvqk8VnlWqOyp00mCfxw';
    const API_KEY = 'AIzaSyCnoLcmC_MpuI12NUK-E2l0B9KbsdC42C4';
    
    const url = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${encodeURIComponent('Copy of Balance Sheet Database')}?key=${API_KEY}`;
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`API Error: ${response.status}`);
    }
    
    const json = await response.json();
    if (!json.values || json.values.length < 2) {
      throw new Error("No data found");
    }
    
    // Parse headers
    const headers = json.values.shift().map(h => h.trim());
    
    // Process transactions (same logic as payable.html)
    const allData = json.values.map(row => {
      const obj = headers.reduce((acc, h, i) => ({ ...acc, [h]: row[i] }), {});
      const amountWithMinus = parseFloat(String(obj['Amount with Minus'] || '0').replace(/[^0-9.-]+/g, '')) || 0;
      const outstandingBalance = parseFloat(String(obj['Outstanding \nBalance'] || obj['Outstanding Balance'] || '0').replace(/[^0-9.-]+/g, '')) || 0;
      const dueStatus = obj['Due Status According to Supplier Type'] || '';
      const payStatus = obj['Invoice Pay Status'] || null;
      
      return {
        supplier: obj['supplier'] || '',
        amountWithMinus,
        outstandingBalance,
        dueStatus,
        payStatus,
        isPayment: amountWithMinus < 0
      };
    }).filter(t => t.supplier);
    
    // Process by supplier (same logic as payable.html processData)
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
        outstandingBalance,
        calculatedOverdueInvoiceSum: correctedOverdueSum,
        transactionCount: supplierTransactions.length
      };
    });
    
    // Calculate totals (same as payable.html sendDataToParent)
    // CRITICAL: Store as raw numbers, never format in services
    const totalDuesValue = summaries.reduce((sum, s) => sum + s.outstandingBalance, 0);
    const totalOverduesValue = summaries.reduce((sum, s) => sum + s.calculatedOverdueInvoiceSum, 0);
    
    return {
      // Store raw numbers - formatting happens only at display time in templates
      totalDues: totalDuesValue, // Raw number
      totalSuppliers: summaries.length, // Raw number
      overdues: totalOverduesValue, // Raw number
      totalTransactions: allData.length, // Raw number
      // Include raw data for reference
      rawData: {
        summaries,
        allData
      }
    };
  } catch (error) {
    console.error('Error loading Accounts Payable from API:', error);
    return null;
  }
}

/**
 * Load all summaries from APIs (background fetch)
 * Returns null if any API fails (doesn't throw)
 */
export async function loadFreshSummaries() {
  try {
    const [accountsPayable] = await Promise.allSettled([
      loadAccountsPayableFromAPI()
    ]);
    
    const result = {
      accountsPayable: accountsPayable.status === 'fulfilled' ? accountsPayable.value : null,
      rmForecasting: null, // Placeholder - can be enhanced later
      warehouse: null // Placeholder - can be enhanced later
    };
    
    // Only return if we have at least Accounts Payable data
    if (result.accountsPayable) {
      return result;
    }
    
    return null;
  } catch (error) {
    console.error('Error loading fresh summaries:', error);
    return null;
  }
}

/**
 * Get summary data (fast: cache first, then async refresh)
 * Returns { immediate: cachedData, refresh: Promise }
 */
export function getSummaryData() {
  // Return cached data immediately
  const cached = getCachedSummary();
  
  // Trigger background refresh (non-blocking)
  const refreshPromise = loadFreshSummaries().then(freshData => {
    if (freshData) {
      // Update cache with fresh data
      saveCachedSummary(freshData);
      return freshData;
    }
    return cached; // Return cached if fresh fetch fails
  });
  
  return {
    immediate: cached,
    refresh: refreshPromise
  };
}

/**
 * Update summary from postMessage (real-time sync from iframes)
 */
export function updateSummaryFromMessage(messageType, payload) {
  const cached = getCachedSummary() || {
    accountsPayable: null,
    rmForecasting: null,
    warehouse: null
  };
  
  // Helper to ensure raw numbers (backward compatibility with formatted strings from iframes)
  const parseIfNumber = (val) => {
    if (typeof val === 'number') return val;
    if (typeof val === 'string') {
      const cleaned = val.replace(/[^0-9.-]+/g, '').replace(/,/g, '');
      return parseFloat(cleaned) || 0;
    }
    return 0;
  };
  
  if (messageType === 'PAYABLE_DATA' && payload) {
    // CRITICAL: Store raw numbers only
    cached.accountsPayable = {
      totalDues: parseIfNumber(payload.totalDues),
      totalSuppliers: parseIfNumber(payload.totalSuppliers),
      overdues: parseIfNumber(payload.overdues),
      totalTransactions: parseIfNumber(payload.totalTransactions)
    };
  } else if (messageType === 'FORECASTING_DATA' && payload) {
    // CRITICAL: Store raw numbers only
    cached.rmForecasting = {
      netPurchaseBudget: parseIfNumber(payload.kpiTotalBudget),
      itemsToPurchase: parseIfNumber(payload.kpiItemsToOrder),
      potentialSavings: parseIfNumber(payload.kpiSavings),
      overstockedValue: parseIfNumber(payload.kpiOverstock),
      forecastAccuracy: parseIfNumber(payload.kpiForecastAccuracy)
    };
  } else if (messageType === 'WAREHOUSE_DATA' && payload) {
    // CRITICAL: Store raw numbers only
    cached.warehouse = {
      totalInventoryValue: parseIfNumber(payload.totalInventoryValue),
      outOfStock: parseIfNumber(payload.outOfStock),
      lowStock: parseIfNumber(payload.lowStock),
      transferValue: parseIfNumber(payload.transferValue),
      purchaseValue: parseIfNumber(payload.purchaseValue)
    };
  }
  
  // Save updated cache
  saveCachedSummary(cached);
  
  return cached;
}
