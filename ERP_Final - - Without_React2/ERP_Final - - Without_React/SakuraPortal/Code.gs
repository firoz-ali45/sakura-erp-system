// This is the final, corrected Google Apps Script code for Code.gs

// --- CONFIGURATION ---
// PASTE THE SPREADSHEET ID OF YOUR *SEPARATE* PAYABLES FILE HERE
const PAYABLE_SPREADSHEET_ID = '1PmGAHvrOM1wnts4Xnp1Wmivrvqk8VnlWqOyp00mCfxw'; 

// PASTE THE SPREADSHEET ID OF YOUR *SEPARATE* WAREHOUSE FILE HERE
const WAREHOUSE_SPREADSHEET_ID = 'YOUR_WAREHOUSE_SPREADSHEET_ID'; // Replace with your warehouse spreadsheet ID

// This special function is required to create a Web App.
// It will serve your pre-calculated data instantly.
function doGet(e) {
  const fileName = 'dashboard_data.json';
  const files = DriveApp.getFilesByName(fileName);
  if (files.hasNext()) {
    const file = files.next();
    const content = file.getBlob().getDataAsString();
    return ContentService.createTextOutput(content).setMimeType(ContentService.MimeType.JSON);
  } else {
    return ContentService.createTextOutput(JSON.stringify({ error: "JSON file not found. Please run calculateAndCacheData from the script editor." })).setMimeType(ContentService.MimeType.JSON);
  }
}

// This is the main function you will run manually to update the data.
function calculateAndCacheData() {
  try {
    const payableData = getPayableData();
    const forecastingData = getForecastingData();
    const warehouseData = getWarehouseData();
    
    const finalJson = {
      payableData: payableData,
      forecastingData: forecastingData,
      warehouseData: warehouseData,
      lastUpdated: new Date().toISOString()
    };
    
    saveAsJsonFile(finalJson);
    Logger.log("SUCCESS: All data processed and saved.");
    
  } catch (e) {
    Logger.log(`ERROR: ${e.message}. Stack: ${e.stack}`);
    SpreadsheetApp.getUi().alert(`An error occurred: ${e.message}`);
  }
}

// --- DATA PROCESSING FUNCTIONS ---

function getPayableData() {
  const ss = SpreadsheetApp.openById(PAYABLE_SPREADSHEET_ID);
  const sheet = ss.getSheetByName('Copy of Balance Sheet Database');
  if (!sheet) {
    throw new Error("Payables sheet named 'Copy of Balance Sheet Database' was not found in the Payables file! Please check the name.");
  }
  const values = sheet.getDataRange().getValues();
  const headers = values.shift().map(h => h.trim());
  const allData = values.map(row => {
    const obj = headers.reduce((acc, h, i) => ({ ...acc, [h]: row[i] }), {});
    return { 
      supplier: obj['supplier'] || '', 
      amountWithMinus: cleanAmount(obj['Amount with Minus']),
      payStatus: obj['Invoice Pay Status'] || null,
      dueStatus: obj['Due Status According to Supplier Type'] || ''
    };
  }).filter(t => t.supplier);

  const summaries = processPayableData(allData);
  const totalOutstanding = summaries.reduce((sum, s) => sum + s.outstandingBalance, 0);
  const totalOverdue = summaries.reduce((sum, s) => sum + s.calculatedOverdueInvoiceSum, 0);
  
  return {
    totalDues: formatCurrency(totalOutstanding),
    totalSuppliers: String(summaries.length),
    overdues: formatCurrency(totalOverdue),
    totalTransactions: String(allData.length)
  };
}

function getForecastingData() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const SHEET_NAMES = ['Sales by Product', 'Sales by Modifier Options', 'products_Inventory ingredients', 'Modifier Options', 'RM Ingredients for Finish Good', 'RM Details', 'Raw Material Purchases', 'Inventory Control', 'Available Quantity'];
  
  const sheets = {};
  SHEET_NAMES.forEach(name => {
    const sheet = ss.getSheetByName(name);
    if (sheet) {
        sheets[name] = sheet.getDataRange().getValues();
    } else {
        throw new Error(`Forecasting sheet named '${name}' was not found in the current file! Please check the name.`);
    }
  });

  const jsonSheets = {};
  for (const key in sheets) {
      jsonSheets[key] = googleSheetValuesToJSON(sheets[key]);
  }
  
  const { completeRMForecast, detailedUsageData } = processForecastingData(jsonSheets);

  let totalPurchaseBudget = 0, itemsToPurchase = 0, potentialSavings = 0, overstockedValue = 0;
  completeRMForecast.forEach(item => {
      const totalRequired = item.forecastedSeptRequired;
      const totalAvailable = detailedUsageData[item.sku]?.availableQty.total || 0;
      const netRequired = Math.max(0, totalRequired - totalAvailable);
      const dailyConsumption = item.actualAugConsumption / 31;
      const daysRemaining = dailyConsumption > 0 ? totalAvailable / dailyConsumption : Infinity;
      if (netRequired > 0) { itemsToPurchase++; totalPurchaseBudget += netRequired * item.unitCost; }
      potentialSavings += (totalRequired - netRequired) * item.unitCost;
      if (daysRemaining > 60) { overstockedValue += totalAvailable * item.unitCost; }
  });

  const totalForecastedConsumption = completeRMForecast.reduce((sum, item) => sum + item.forecastedAugConsumption, 0);
  const totalActualConsumption = completeRMForecast.reduce((sum, item) => sum + item.actualAugConsumption, 0);
  const forecastAccuracy = totalActualConsumption > 0 ? (1 - Math.abs(totalForecastedConsumption - totalActualConsumption) / totalActualConsumption) : 1;

  return {
    kpiTotalBudget: formatCurrency(totalPurchaseBudget),
    kpiItemsToOrder: String(itemsToPurchase),
    kpiSavings: formatCurrency(potentialSavings),
    kpiOverstock: formatCurrency(overstockedValue),
    kpiForecastAccuracy: `${(forecastAccuracy * 100).toFixed(1)}%`
  };
}

function getWarehouseData() {
  const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
  const SHEET_NAMES = ['Inventory', 'Transfers', 'Purchasing', 'RM Details'];
  
  const sheets = {};
  SHEET_NAMES.forEach(name => {
    const sheet = ss.getSheetByName(name);
    if (sheet) {
        sheets[name] = sheet.getDataRange().getValues();
    } else {
        throw new Error(`Warehouse sheet named '${name}' was not found in the warehouse file! Please check the name.`);
    }
  });

  const jsonSheets = {};
  for (const key in sheets) {
      jsonSheets[key] = googleSheetValuesToJSON(sheets[key]);
  }
  
  const warehouseSummary = processWarehouseData(jsonSheets);
  return warehouseSummary;
}

// --- HELPER & UTILITY FUNCTIONS ---

function saveAsJsonFile(jsonData) {
  const fileName = 'dashboard_data.json';
  const jsonString = JSON.stringify(jsonData, null, 2);
  const files = DriveApp.getFilesByName(fileName);
  let file;
  if (files.hasNext()) {
    file = files.next();
    file.setContent(jsonString);
  } else {
    file = DriveApp.createFile(fileName, jsonString, MimeType.JAVASCRIPT);
  }
  Logger.log(`Data saved to ${fileName}. The Web App is now updated.`);
}

function processPayableData(transactions) {
    if (!transactions || !transactions.length) return [];
    const groupedBySupplier = transactions.reduce((acc, t) => {
        if (!acc[t.supplier]) acc[t.supplier] = [];
        acc[t.supplier].push(t);
        return acc;
    }, {});
    return Object.keys(groupedBySupplier).map(supplierName => {
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
        return { supplier: supplierName, outstandingBalance, calculatedOverdueInvoiceSum: correctedOverdueSum };
    });
}

function processForecastingData(sheets) {
    const { 'Sales by Product': salesByProduct, 'Sales by Modifier Options': salesByModifier, 'products_Inventory ingredients': productsInventoryIngredients, 'Modifier Options': modifierOptions, 'RM Ingredients for Finish Good': rmIngredientsForFinishGood, 'RM Details': rmDetails, 'Raw Material Purchases': rmPurchases, 'Inventory Control': inventoryControl, 'Available Quantity': availableQuantity } = sheets;
    const normalizeSku = (sku) => sku ? String(sku).trim().toLowerCase() : null;
    const safeParseFloat = (val) => parseFloat(String(val || '0').replace(/,/g, ''));
    
    const aggregateByName = (salesData, nameField, skuField) => {
        const salesMap = new Map();
        (salesData || []).forEach(item => {
            const name = item[nameField]; if (!name) return;
            const quantity = safeParseFloat(item["Net Quantity"]); if (quantity <= 0) return;
            if (salesMap.has(name)) { salesMap.get(name).quantity += quantity; } 
            else { salesMap.set(name, { sku: item[skuField], name: name, quantity: quantity }); }
        });
        return Array.from(salesMap.values());
    };

    const aggregatedProductSales = aggregateByName(salesByProduct, 'Product', 'Product SKU');
    const aggregatedModifierSales = aggregateByName(salesByModifier, 'Modifier Option', 'Modifier Option SKU');
    const productSales = aggregatedProductSales.reduce((acc, p) => { const sku = normalizeSku(p.sku); if(sku) acc[sku] = { name: p.name, quantity: p.quantity }; return acc; }, {});
    const modifierSales = aggregatedModifierSales.reduce((acc, m) => { const sku = normalizeSku(m.sku); if(sku) { if (!acc[sku]) acc[sku] = { name: m.name, quantity: 0 }; acc[sku].quantity += m.quantity; } return acc; }, {});
    
    const unitCosts = (rmPurchases || []).sort((a,b) => new Date(b.Date) - new Date(a.Date)).reduce((acc, p) => { const sku = normalizeSku(p.SKU); if (sku && !acc[sku]) { const cost = parseFloat(String(p['Unit Cost (Include VAT)'] || '0').replace(/[^0-9.-]+/g, "")); if (!isNaN(cost)) acc[sku] = cost; } return acc; }, {});
    const inventoryLookup = (inventoryControl || []).reduce((acc, item) => { const sku = normalizeSku(item.SKU); if (!sku) return acc; const prodQty = safeParseFloat(item['Consumption From Production Quantity']); const orderQty = safeParseFloat(item['Consumption From Order Quantity']); if (!acc[sku]) acc[sku] = { prodConsumption: 0, orderConsumption: 0 }; acc[sku].prodConsumption += prodQty; acc[sku].orderConsumption += orderQty; return acc; }, {});
    const availableQtyLookup = (availableQuantity || []).reduce((acc, item) => { const sku = normalizeSku(item.SKU); if (!sku) return acc; const qty = safeParseFloat(item['Available Quantity']); if (!acc[sku]) { acc[sku] = { total: 0, breakdown: [] }; } acc[sku].total += qty; acc[sku].breakdown.push({ branch: item.Branch, quantity: qty }); return acc; }, {});
    const itemDetailsLookup = (rmDetails || []).reduce((acc, item) => { const sku = normalizeSku(item.sku); if(sku) { acc[sku] = { name: item.name, storageUnit: item.storage_unit || 'N/A', convFactor: parseFloat(item.storage_to_ingredient_factor) || 1 }; } return acc; }, {});
    
    let rmConsumption = {}; let detailedUsageData = {};
    const addConsumption = (rmSku, amount) => { if (!rmSku || isNaN(amount) || amount === 0) return; const key = normalizeSku(rmSku); if (!rmConsumption[key]) rmConsumption[key] = 0; rmConsumption[key] += amount; };
    
    const processIngredients = (salesData, ingredientsData) => { 
        Object.entries(salesData).forEach(([itemSku, item]) => { 
            const normalizedItemSku = normalizeSku(itemSku); 
            (ingredientsData || []).filter(ing => normalizeSku(ing.product_sku) === normalizedItemSku || normalizeSku(ing.modifier_option_sku) === normalizedItemSku).forEach(ing => { 
                const ingQty = parseFloat(ing.quantity); if (!ingQty || ingQty <= 0) return; 
                const ingItemSku = ing.inventory_item_sku; 
                const isFinishedGood = ing.inventory_item_name && ing.inventory_item_name.toLowerCase().includes("(recipe)"); 
                const totalIngNeeded = item.quantity * ingQty; 
                if (!isFinishedGood) { addConsumption(ingItemSku, totalIngNeeded); } 
                else { const normIngItemSku = normalizeSku(ingItemSku); (rmIngredientsForFinishGood || []).filter(r => normalizeSku(r.inventory_item_sku) === normIngItemSku).forEach(recipe => { const rmQty = parseFloat(recipe.quantity); if (rmQty > 0) { const unitOfFG = recipe['Storage Unit Of inventory_item_name (Finished Good & WIP)']; let totalFgInStorageUnits = totalIngNeeded; if (unitOfFG && (unitOfFG.toLowerCase() === 'kg' || unitOfFG.toLowerCase() === 'l')) { totalFgInStorageUnits = totalIngNeeded / 1000; } const totalRmUsed = totalFgInStorageUnits * rmQty; addConsumption(recipe.ingredient_item_sku, totalRmUsed); } }); } 
            }); 
        }); 
    };
    
    processIngredients(productSales, productsInventoryIngredients);
    processIngredients(modifierSales, modifierOptions);

    const completeRMForecast = Object.entries(rmConsumption).map(([rmSku, totalIngUnitQty]) => {
        const normSku = normalizeSku(rmSku); const rmDetailsData = itemDetailsLookup[normSku]; if (!rmDetailsData) return null;
        const unitCost = unitCosts[normSku] || 0;
        const forecastedAugConsumption = totalIngUnitQty / (rmDetailsData.convFactor || 1);
        const forecastedSeptRequired = forecastedAugConsumption * 1.15;
        const inventoryData = inventoryLookup[normSku] || { prodConsumption: 0, orderConsumption: 0 };
        const actualAugConsumption = inventoryData.prodConsumption + inventoryData.orderConsumption;
        detailedUsageData[normSku] = { availableQty: availableQtyLookup[normSku] || { total: 0, breakdown: [] } };
        return { ...rmDetailsData, sku: rmSku, forecastedAugConsumption, forecastedSeptRequired, actualAugConsumption, unitCost: unitCost };
    }).filter(item => item);

    return { completeRMForecast, detailedUsageData };
}

function processWarehouseData(sheets) {
    const { Inventory: inventory, Transfers: transfers, Purchasing: purchasing, 'RM Details': rmDetails } = sheets;
    const safeParseFloat = (val) => parseFloat(String(val || '0').replace(/,/g, ''));
    
    // Process Inventory Data
    let totalInventoryValue = 0;
    let outOfStock = 0;
    let lowStock = 0;
    
    if (inventory && inventory.length > 0) {
        inventory.forEach(item => {
            const quantity = safeParseFloat(item.quantity || item.Quantity || item['Available Quantity']);
            const unitCost = safeParseFloat(item.unitCost || item['Unit Cost'] || item['Cost per Unit']);
            const totalValue = quantity * unitCost;
            
            totalInventoryValue += totalValue;
            
            if (quantity === 0) {
                outOfStock++;
            } else if (quantity < 10) { // Assuming low stock threshold is 10
                lowStock++;
            }
        });
    }
    
    // Process Transfers Data
    let transferValue = 0;
    if (transfers && transfers.length > 0) {
        transfers.forEach(transfer => {
            const quantity = safeParseFloat(transfer.quantity || transfer.Quantity);
            const unitCost = safeParseFloat(transfer.unitCost || transfer['Unit Cost']);
            transferValue += quantity * unitCost;
        });
    }
    
    // Process Purchasing Data
    let purchaseValue = 0;
    if (purchasing && purchasing.length > 0) {
        purchasing.forEach(purchase => {
            const quantity = safeParseFloat(purchase.quantity || purchase.Quantity);
            const unitCost = safeParseFloat(purchase.unitCost || purchase['Unit Cost'] || purchase['Cost per Unit']);
            purchaseValue += quantity * unitCost;
        });
    }
    
    return {
        totalInventoryValue: formatCurrency(totalInventoryValue),
        outOfStock: String(outOfStock),
        lowStock: String(lowStock),
        transferValue: formatCurrency(transferValue),
        purchaseValue: formatCurrency(purchaseValue)
    };
}

function googleSheetValuesToJSON(values) {
    if (!values || values.length < 2) return [];
    const headers = values[0].map(header => (header || '').trim());
    return values.slice(1).map(row => headers.reduce((obj, header, index) => { obj[header] = row[index]; return obj; }, {}));
}

function cleanAmount(v) { let s = String(v || '0'); s = s.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)).replace(/٬/g, '').replace(/٫/g, '.'); const c = s.replace(/[^\d.-]/g, ''); return parseFloat(c) || 0; }
function formatCurrency(n) { return 'SAR ' + (n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

