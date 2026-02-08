// This is the final, corrected Google Apps Script code for Code.gs

// --- CONFIGURATION ---
// PASTE THE SPREADSHEET ID OF YOUR *SEPARATE* PAYABLES FILE HERE
const PAYABLE_SPREADSHEET_ID = '1PmGAHvrOM1wnts4Xnp1Wmivrvqk8VnlWqOyp00mCfxw'; 

// PASTE THE SPREADSHEET ID OF YOUR *SEPARATE* WAREHOUSE FILE HERE
const WAREHOUSE_SPREADSHEET_ID = '1ValWzTN7XWKZ7o7QUPSjoUNiGBRpNvmmqjzeuV115kg';

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
  const SHEET_NAMES = ['Available Quantity', 'Transfers', 'Purchasing', 'RM Details'];
  
  const sheets = {};
  SHEET_NAMES.forEach(name => {
    const sheet = ss.getSheetByName(name);
    if (sheet) {
        // For Transfers and Purchasing sheets, headers are in row 2, data starts from row 3
        if (name === 'Transfers' || name === 'Purchasing') {
          const lastRow = sheet.getLastRow();
          const lastCol = sheet.getLastColumn();
          
          if (lastRow >= 3) {
            // Get headers from row 2
            const headers = sheet.getRange(2, 1, 1, lastCol).getValues()[0];
            // Get data from row 3 onwards
            const data = sheet.getRange(3, 1, lastRow - 2, lastCol).getValues();
            // Combine headers and data
            sheets[name] = [headers, ...data];
          } else {
            sheets[name] = [];
          }
        } else {
          // For other sheets, use normal approach
          sheets[name] = sheet.getDataRange().getValues();
        }
    } else {
        throw new Error(`Warehouse sheet named '${name}' was not found in the Warehouse file! Please check the name.`);
    }
  });
  
  const jsonSheets = {};
  for (const key in sheets) {
      Logger.log(`Converting ${key} to JSON - Raw data length: ${sheets[key] ? sheets[key].length : 'null'}`);
      jsonSheets[key] = googleSheetValuesToJSON(sheets[key]);
      Logger.log(`${key} JSON conversion result - Length: ${jsonSheets[key] ? jsonSheets[key].length : 'null'}`);
  }
  
  Logger.log('JSON Sheets keys:', Object.keys(jsonSheets));
  
  const warehouseData = processWarehouseData(jsonSheets);
  return warehouseData;
}

function processWarehouseData(sheets) {
  const { 'Available Quantity': availableQuantity, 'Transfers': transfers, 'Purchasing': purchasing, 'RM Details': rmDetails } = sheets;
  
  Logger.log('Processing warehouse data...');
  Logger.log('Raw sheets object keys:', Object.keys(sheets));
  Logger.log('Available Quantity type:', typeof availableQuantity, 'length:', availableQuantity ? availableQuantity.length : 'null');
  Logger.log('Transfers type:', typeof transfers, 'length:', transfers ? transfers.length : 'null');
  Logger.log('Purchasing type:', typeof purchasing, 'length:', purchasing ? purchasing.length : 'null');
  Logger.log('RM Details type:', typeof rmDetails, 'length:', rmDetails ? rmDetails.length : 'null');
  
  // Debug: Show actual sample data
  if (availableQuantity && availableQuantity.length > 0) {
    Logger.log('Available Quantity sample keys:', Object.keys(availableQuantity[0]));
    Logger.log('Available Quantity SKU:', availableQuantity[0].SKU);
    Logger.log('Available Quantity Qty:', availableQuantity[0]['Available Quantity']);
  } else {
    Logger.log('Available Quantity is empty or null');
  }
  if (transfers && transfers.length > 0) {
    Logger.log('Transfers sample keys:', Object.keys(transfers[0]));
    Logger.log('Transfers SKU:', transfers[0].SKU);
    Logger.log('Transfers Quantity:', transfers[0].Quantity);
  } else {
    Logger.log('Transfers is empty or null');
  }
  if (purchasing && purchasing.length > 0) {
    Logger.log('Purchasing sample keys:', Object.keys(purchasing[0]));
    Logger.log('Purchasing SKU:', purchasing[0].SKU);
    Logger.log('Purchasing Cost:', purchasing[0].Cost);
  } else {
    Logger.log('Purchasing is empty or null');
  }
  if (rmDetails && rmDetails.length > 0) {
    Logger.log('RM Details sample keys:', Object.keys(rmDetails[0]));
    Logger.log('RM Details sku:', rmDetails[0].sku);
    Logger.log('RM Details cost:', rmDetails[0].cost);
  } else {
    Logger.log('RM Details is empty or null');
  }
  
  // Process Available Quantity
  let totalInventoryValue = 0;
  let outOfStock = 0;
  let lowStock = 0;
  let totalItems = 0;
  
  if (availableQuantity && availableQuantity.length > 0) {
    Logger.log('Processing Available Quantity data...');
    
    // Group by SKU and sum quantities across branches
    const itemMap = new Map();
    
    availableQuantity.forEach(item => {
      const sku = item.SKU ? item.SKU.toString().trim().toLowerCase() : '';
      const qty = parseFloat(item['Available Quantity']) || 0;
      const branch = item.Branch || '';
      
      if (sku && qty > 0) {
        if (!itemMap.has(sku)) {
          itemMap.set(sku, { totalQty: 0, branches: [] });
        }
        itemMap.get(sku).totalQty += qty;
        itemMap.get(sku).branches.push({ branch, qty });
      }
    });
    
    Logger.log('Available Quantity - Unique SKUs found:', itemMap.size);
    Logger.log('Available Quantity - Total items processed:', totalItems);
    Logger.log('Available Quantity - Out of stock:', outOfStock);
    Logger.log('Available Quantity - Low stock:', lowStock);
    Logger.log('Available Quantity - Total inventory value so far:', totalInventoryValue);
      
      // Process items and calculate inventory value
      itemMap.forEach((data, sku) => {
        totalItems++;
        if (data.totalQty === 0) {
          outOfStock++;
        } else if (data.totalQty < 10) { // Low stock threshold
          lowStock++;
        }
        
      // Get unit cost from RM Details or Available Quantity
      let unitCost = 0;
      
      // Try to get cost from RM Details first
        const rmDetail = rmDetails.find(item => 
          item.sku && item.sku.toString().trim().toLowerCase() === sku
        );
        
      if (rmDetail && rmDetail.cost) {
        unitCost = parseFloat(rmDetail.cost) || 0;
      }
      
      // If no cost from RM Details, try Available Quantity
      if (unitCost === 0) {
        const availableItem = availableQuantity.find(item => 
          item.SKU && item.SKU.toString().trim().toLowerCase() === sku
        );
        if (availableItem && availableItem['Cost Per Unit']) {
          unitCost = parseFloat(availableItem['Cost Per Unit']) || 0;
        }
      }
      
      if (unitCost > 0) {
          totalInventoryValue += data.totalQty * unitCost;
        }
      });
  }
  
  // Process Transfers
  let transferValue = 0;
  let totalTransfers = 0;
  
  if (transfers && transfers.length > 0) {
    Logger.log('Processing Transfers data...');
    
    // transfers is now an array of JSON objects, not raw sheet data
    transfers.forEach(transfer => {
      const qty = parseFloat(transfer.Quantity) || 0;
      const sku = transfer.SKU ? transfer.SKU.toString().trim().toLowerCase() : '';
      const amount = parseFloat(transfer.Cost) || 0;
        
        if (qty > 0 && sku) {
          totalTransfers++;
          
        // Use amount if available, otherwise calculate from unit cost
        if (amount > 0) {
            transferValue += amount;
          } else {
            // Get unit cost from RM Details
            const rmDetail = rmDetails.find(item => 
              item.sku && item.sku.toString().trim().toLowerCase() === sku
            );
            
          if (rmDetail && rmDetail.cost) {
            const unitCost = parseFloat(rmDetail.cost) || 0;
              transferValue += qty * unitCost;
            }
          }
        }
    });
    
    Logger.log('Transfers processed - Total transfers:', totalTransfers, 'Transfer value:', transferValue);
  }
  
  // Process Purchasing
  let purchaseValue = 0;
  let totalPurchases = 0;
  
  if (purchasing && purchasing.length > 0) {
    Logger.log('Processing Purchasing data...');
    
    // purchasing is now an array of JSON objects, not raw sheet data
    purchasing.forEach(purchase => {
      const amount = parseFloat(purchase.Cost) || 0;
      const qty = parseFloat(purchase.Quantity) || 0;
      const sku = purchase.SKU ? purchase.SKU.toString().trim().toLowerCase() : '';
        
        if (amount > 0) {
        // Use amount if available
          totalPurchases++;
          purchaseValue += amount;
      } else if (qty > 0 && sku) {
      // Fallback: calculate from quantity and unit cost
          totalPurchases++;
          
          // Get unit cost from RM Details
          const rmDetail = rmDetails.find(item => 
            item.sku && item.sku.toString().trim().toLowerCase() === sku
          );
          
        if (rmDetail && rmDetail.cost) {
          const unitCost = parseFloat(rmDetail.cost) || 0;
            purchaseValue += qty * unitCost;
          }
        }
    });
    
    Logger.log('Purchasing processed - Total purchases:', totalPurchases, 'Purchase value:', purchaseValue);
  }
  
  const result = {
    totalInventoryValue: formatCurrency(totalInventoryValue),
    outOfStock: String(outOfStock),
    lowStock: String(lowStock),
    transferValue: formatCurrency(transferValue),
    purchaseValue: formatCurrency(purchaseValue),
    totalItems: String(totalItems),
    totalTransfers: String(totalTransfers),
    totalPurchases: String(totalPurchases)
  };
  
  Logger.log('Final Warehouse Data Result:', result);
  
  return result;
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
                // Enhanced finished goods detection based on user requirements
                const isFinishedGood = ing.inventory_item_name && (
                    ing.inventory_item_name.toLowerCase().includes("(recipe)") ||
                    ing.inventory_item_name.toLowerCase().includes("(mini recipe)") ||
                    ing.inventory_item_name.endsWith("26 Kg") ||
                    ing.inventory_item_name.endsWith("26 KG") ||
                    ing.inventory_item_name.endsWith("0.250 Kg") ||
                    ing.inventory_item_name.endsWith("0.250 KG") ||
                    ing.inventory_item_name.endsWith("0.250 KG (New)")
                ); 
                const totalIngNeeded = item.quantity * ingQty; 
                if (!isFinishedGood) { addConsumption(ingItemSku, totalIngNeeded); } 
                else { 
                    // This is a finished good, so we need to get its raw material ingredients
                    const normIngItemSku = normalizeSku(ingItemSku); 
                    Logger.log(`Processing finished good: ${ing.inventory_item_name} (SKU: ${ingItemSku})`);
                    
                    (rmIngredientsForFinishGood || []).filter(r => normalizeSku(r.inventory_item_sku) === normIngItemSku).forEach(recipe => { 
                        const rmQty = parseFloat(recipe.quantity); 
                        if (rmQty > 0) { 
                            const unitOfFG = recipe['Storage Unit Of inventory_item_name (Finished Good & WIP)']; 
                            let totalFgInStorageUnits = totalIngNeeded; 
                            if (unitOfFG && (unitOfFG.toLowerCase() === 'kg' || unitOfFG.toLowerCase() === 'l')) { 
                                totalFgInStorageUnits = totalIngNeeded / 1000; 
                            } 
                            const totalRmUsed = totalFgInStorageUnits * rmQty; 
                            Logger.log(`Adding RM consumption: ${recipe.ingredient_name} (${recipe.ingredient_item_sku}) - Qty: ${totalRmUsed}`);
                            addConsumption(recipe.ingredient_item_sku, totalRmUsed); 
                        } 
                    }); 
                } 
            }); 
        }); 
    };
    
    Logger.log(`Processing ${Object.keys(productSales).length} product sales and ${Object.keys(modifierSales).length} modifier sales`);
    processIngredients(productSales, productsInventoryIngredients);
    processIngredients(modifierSales, modifierOptions);
    Logger.log(`Total RM consumption entries: ${Object.keys(rmConsumption).length}`);

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

    // Debug: Log some of the raw materials that are being included
    Logger.log("Sample raw materials in forecast:");
    completeRMForecast.slice(0, 10).forEach(item => {
        Logger.log(`- ${item.name} (${item.sku}): ${item.forecastedSeptRequired.toFixed(2)} units`);
    });

    return { completeRMForecast, detailedUsageData };
}

function googleSheetValuesToJSON(values) {
    if (!values || values.length < 2) return [];
    const headers = values[0].map(header => (header || '').trim());
    return values.slice(1).map(row => headers.reduce((obj, header, index) => { obj[header] = row[index]; return obj; }, {}));
}

// Test function to debug warehouse data
function testWarehouseData() {
  try {
    Logger.log('=== TESTING WAREHOUSE DATA ===');
    
    const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
    Logger.log('Warehouse Spreadsheet ID: ' + WAREHOUSE_SPREADSHEET_ID);
    Logger.log('Spreadsheet Name: ' + ss.getName());
    
    const SHEET_NAMES = ['Available Quantity', 'Transfers', 'Purchasing', 'RM Details'];
    
    SHEET_NAMES.forEach(name => {
      const sheet = ss.getSheetByName(name);
      if (sheet) {
        Logger.log(`Sheet "${name}" found - Rows: ${sheet.getLastRow()}, Cols: ${sheet.getLastColumn()}`);
        
        // For Transfers and Purchasing sheets, headers are in row 2
        if (name === 'Transfers' || name === 'Purchasing') {
          const headers = sheet.getRange(2, 1, 1, sheet.getLastColumn()).getValues()[0];
          Logger.log(`Headers for "${name}" (from row 2): ${headers.join(', ')}`);
          
          // Show first few data rows (starting from row 3)
          if (sheet.getLastRow() > 2) {
            const sampleData = sheet.getRange(3, 1, Math.min(3, sheet.getLastRow() - 2), sheet.getLastColumn()).getValues();
            Logger.log(`Sample data for "${name}":`);
            sampleData.forEach((row, i) => {
              Logger.log(`  Row ${i + 3}: ${row.join(', ')}`);
            });
          }
        } else {
          // For other sheets, headers are in row 1
          const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
          Logger.log(`Headers for "${name}" (from row 1): ${headers.join(', ')}`);
          
          // Show first few data rows (starting from row 2)
          if (sheet.getLastRow() > 1) {
            const sampleData = sheet.getRange(2, 1, Math.min(3, sheet.getLastRow() - 1), sheet.getLastColumn()).getValues();
            Logger.log(`Sample data for "${name}":`);
            sampleData.forEach((row, i) => {
              Logger.log(`  Row ${i + 2}: ${row.join(', ')}`);
            });
          }
        }
      } else {
        Logger.log(`Sheet "${name}" NOT FOUND!`);
      }
    });
    
    // Test the actual warehouse data processing
    Logger.log('\n=== TESTING DATA PROCESSING ===');
    const warehouseData = getWarehouseData();
    Logger.log('Processed Warehouse Data:');
    Logger.log(JSON.stringify(warehouseData, null, 2));
    
    // Test individual sheet data retrieval using the fixed getWarehouseData function
    Logger.log('\n=== TESTING INDIVIDUAL SHEET DATA ===');
    try {
      const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
      const SHEET_NAMES = ['Available Quantity', 'Transfers', 'Purchasing', 'RM Details'];
      
      const sheets = {};
      SHEET_NAMES.forEach(name => {
        const sheet = ss.getSheetByName(name);
        if (sheet) {
          // For Transfers and Purchasing sheets, headers are in row 2, data starts from row 3
          if (name === 'Transfers' || name === 'Purchasing') {
            const lastRow = sheet.getLastRow();
            const lastCol = sheet.getLastColumn();
            
            if (lastRow >= 3) {
              // Get headers from row 2
              const headers = sheet.getRange(2, 1, 1, lastCol).getValues()[0];
              // Get data from row 3 onwards
              const data = sheet.getRange(3, 1, lastRow - 2, lastCol).getValues();
              // Combine headers and data
              sheets[name] = [headers, ...data];
            } else {
              sheets[name] = [];
            }
          } else {
            // For other sheets, use normal approach
            sheets[name] = sheet.getDataRange().getValues();
          }
        }
      });
      
      // Test each sheet
      Object.keys(sheets).forEach(name => {
        const sheetData = sheets[name];
        Logger.log(`${name} Data Length:`, sheetData ? sheetData.length : 'NULL');
        if (sheetData && sheetData.length > 0) {
          Logger.log(`${name} Headers:`, sheetData[0]);
          if (sheetData.length > 1) {
            Logger.log(`${name} Sample Row:`, sheetData[1]);
          }
        }
      });
      
    } catch (sheetError) {
      Logger.log('Error testing individual sheet data:', sheetError.message);
    }
    
  } catch (e) {
    Logger.log('ERROR in testWarehouseData: ' + e.message);
    Logger.log('Stack: ' + e.stack);
  }
}

function checkWarehouseSpreadsheet() {
  Logger.log('=== CHECKING WAREHOUSE SPREADSHEET ===');
  Logger.log('WAREHOUSE_SPREADSHEET_ID:', WAREHOUSE_SPREADSHEET_ID);
  
  try {
    const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
    Logger.log('Spreadsheet Name:', ss.getName());
    Logger.log('Spreadsheet URL:', ss.getUrl());
    
    const sheets = ss.getSheets();
    Logger.log('All Sheets in Spreadsheet:');
    sheets.forEach(sheet => {
      Logger.log('- ' + sheet.getName() + ' (Rows: ' + sheet.getLastRow() + ', Cols: ' + sheet.getLastColumn() + ')');
    });
    
  } catch (error) {
    Logger.log('ERROR accessing warehouse spreadsheet:', error.message);
    Logger.log('ERROR stack:', error.stack);
  }
  
  Logger.log('=== FUNCTION COMPLETED ===');
}

// Simple test function to verify logging works
function testLogging() {
  Logger.log('TEST: Logging is working!');
  Logger.log('Current time:', new Date());
  Logger.log('WAREHOUSE_SPREADSHEET_ID constant:', WAREHOUSE_SPREADSHEET_ID);
  Logger.log('WAREHOUSE_SPREADSHEET_ID type:', typeof WAREHOUSE_SPREADSHEET_ID);
  Logger.log('WAREHOUSE_SPREADSHEET_ID length:', WAREHOUSE_SPREADSHEET_ID ? WAREHOUSE_SPREADSHEET_ID.length : 'NULL');
  
  // Check if constant is defined
  if (typeof WAREHOUSE_SPREADSHEET_ID === 'undefined') {
    Logger.log('ERROR: WAREHOUSE_SPREADSHEET_ID is undefined!');
  } else if (!WAREHOUSE_SPREADSHEET_ID) {
    Logger.log('ERROR: WAREHOUSE_SPREADSHEET_ID is empty or null!');
  } else {
    Logger.log('SUCCESS: WAREHOUSE_SPREADSHEET_ID is defined and has value');
  }
}

function cleanAmount(v) { let s = String(v || '0'); s = s.replace(/[٠-٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)).replace(/٬/g, '').replace(/٫/g, '.'); const c = s.replace(/[^\d.-]/g, ''); return parseFloat(c) || 0; }
function formatCurrency(n) { return 'SAR ' + (n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }

// Simple test function to check warehouse data
function testWarehouseSimple() {
  try {
    Logger.log('=== SIMPLE WAREHOUSE TEST ===');
    
    const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
    const sheet = ss.getSheetByName('Available Quantity');
    
    if (sheet) {
      Logger.log('Sheet found, getting first 3 rows...');
      const data = sheet.getRange(1, 1, 3, 9).getValues();
      
      Logger.log('Row 1 (Headers):', data[0].join(' | '));
      Logger.log('Row 2 (Data):', data[1].join(' | '));
      Logger.log('Row 3 (Data):', data[2].join(' | '));
      
      // Test JSON conversion
      const jsonData = googleSheetValuesToJSON(data);
      Logger.log('JSON conversion result length:', jsonData.length);
      
      if (jsonData.length > 0) {
        Logger.log('First JSON object keys:', Object.keys(jsonData[0]).join(', '));
        Logger.log('First JSON SKU:', jsonData[0].SKU);
        Logger.log('First JSON Quantity:', jsonData[0]['Available Quantity']);
      }
    }
    
  } catch (error) {
    Logger.log('ERROR:', error.message);
  }
}

// Function to check the actual JSON file content
function checkJsonFile() {
  try {
    Logger.log('=== CHECKING JSON FILE ===');
    
    const fileName = 'dashboard_data.json';
    const files = DriveApp.getFilesByName(fileName);
    
    if (files.hasNext()) {
      const file = files.next();
      const content = file.getBlob().getDataAsString();
      
      Logger.log('JSON file found!');
      Logger.log('File size:', content.length, 'characters');
      
      // Parse and check warehouse data
      const jsonData = JSON.parse(content);
      
      if (jsonData.warehouseData) {
        Logger.log('Warehouse data found in JSON!');
        Logger.log('Total Inventory Value:', jsonData.warehouseData.totalInventoryValue);
        Logger.log('Out of Stock:', jsonData.warehouseData.outOfStock);
        Logger.log('Low Stock:', jsonData.warehouseData.lowStock);
        Logger.log('Transfer Value:', jsonData.warehouseData.transferValue);
        Logger.log('Purchase Value:', jsonData.warehouseData.purchaseValue);
      } else {
        Logger.log('No warehouse data found in JSON file');
        Logger.log('Available keys:', Object.keys(jsonData));
      }
      
    } else {
      Logger.log('JSON file not found!');
    }
    
  } catch (error) {
    Logger.log('ERROR checking JSON file:', error.message);
  }
}

// Diagnostic function to check warehouse spreadsheet access and data
function diagnoseWarehouseData() {
  Logger.log('=== WAREHOUSE DATA DIAGNOSTIC ===');
  Logger.log('WAREHOUSE_SPREADSHEET_ID:', WAREHOUSE_SPREADSHEET_ID);
  
  try {
    const ss = SpreadsheetApp.openById(WAREHOUSE_SPREADSHEET_ID);
    Logger.log('Spreadsheet Name:', ss.getName());
    Logger.log('Spreadsheet URL:', ss.getUrl());
    
    // List all sheets
    const allSheets = ss.getSheets();
    Logger.log('All sheets in spreadsheet:');
    allSheets.forEach((sheet, index) => {
      Logger.log(`${index + 1}. "${sheet.getName()}" - Rows: ${sheet.getLastRow()}, Cols: ${sheet.getLastColumn()}`);
    });
    
    // Check specific sheets
    const SHEET_NAMES = ['Available Quantity', 'Transfers', 'Purchasing', 'RM Details'];
    Logger.log('\n=== CHECKING TARGET SHEETS ===');
    
    SHEET_NAMES.forEach(name => {
      const sheet = ss.getSheetByName(name);
      if (sheet) {
        Logger.log(`✅ Sheet "${name}" found`);
        Logger.log(`   Rows: ${sheet.getLastRow()}, Cols: ${sheet.getLastColumn()}`);
        
        if (sheet.getLastRow() > 1) {
          // Show headers
          const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
          Logger.log(`   Headers: ${headers.join(', ')}`);
          
          // For Transfers and Purchasing, check row 2 headers too
          if ((name === 'Transfers' || name === 'Purchasing') && sheet.getLastRow() > 2) {
            const row2Headers = sheet.getRange(2, 1, 1, sheet.getLastColumn()).getValues()[0];
            Logger.log(`   Row 2 Headers: ${row2Headers.join(', ')}`);
          }
          
          // Show sample data
          const sampleRows = Math.min(3, sheet.getLastRow() - 1);
          const sampleData = sheet.getRange(2, 1, sampleRows, sheet.getLastColumn()).getValues();
          Logger.log(`   Sample data (${sampleRows} rows):`);
          sampleData.forEach((row, i) => {
            Logger.log(`     Row ${i + 2}: ${row.slice(0, 5).join(', ')}${row.length > 5 ? '...' : ''}`);
          });
        } else {
          Logger.log(`   ⚠️ Sheet is empty (only headers or completely empty)`);
        }
      } else {
        Logger.log(`❌ Sheet "${name}" NOT FOUND`);
      }
    });
    
    // Test data retrieval
    Logger.log('\n=== TESTING DATA RETRIEVAL ===');
    const sheets = {};
    SHEET_NAMES.forEach(name => {
      const sheet = ss.getSheetByName(name);
      if (sheet) {
        if (name === 'Transfers' || name === 'Purchasing') {
          const lastRow = sheet.getLastRow();
          const lastCol = sheet.getLastColumn();
          
          if (lastRow >= 3) {
            const headers = sheet.getRange(2, 1, 1, lastCol).getValues()[0];
            const data = sheet.getRange(3, 1, lastRow - 2, lastCol).getValues();
            sheets[name] = [headers, ...data];
            Logger.log(`${name}: Retrieved ${data.length} data rows`);
          } else {
            sheets[name] = [];
            Logger.log(`${name}: No data rows (lastRow: ${lastRow})`);
          }
        } else {
          const data = sheet.getDataRange().getValues();
          sheets[name] = data;
          Logger.log(`${name}: Retrieved ${data.length} total rows`);
        }
      }
    });
    
    // Test JSON conversion
    Logger.log('\n=== TESTING JSON CONVERSION ===');
    const jsonSheets = {};
    for (const key in sheets) {
      jsonSheets[key] = googleSheetValuesToJSON(sheets[key]);
      Logger.log(`${key} JSON: ${jsonSheets[key].length} objects`);
      if (jsonSheets[key].length > 0) {
        Logger.log(`${key} sample object:`, JSON.stringify(jsonSheets[key][0]));
      }
    }
    
  } catch (error) {
    Logger.log('ERROR:', error.message);
    Logger.log('Stack:', error.stack);
  }
  
  Logger.log('=== DIAGNOSTIC COMPLETE ===');
}
