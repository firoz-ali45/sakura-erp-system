# Functionality Fixes - Complete Implementation Guide

## Issues Identified:
1. ❌ Home Portal: Data calculations wrong / not loading
2. ❌ Inventory Items: Export/Import/Download Excel Template not working
3. ❌ Navigation: Accounts, Forecasting, Warehouse, Settings not clickable
4. ❌ Dashboard: External HTML files not loading in iframe

## Fixes Required:

### 1. Home Portal Data Loading
- Implement `updateAllInsights()` function
- Load data from API (or Google Apps Script URL)
- Update all KPI cards with real data
- Calculate metrics properly

### 2. Dashboard Navigation
- Fix `loadDashboard()` to handle iframe for external HTML files
- Make Accounts Payable, Forecasting, Warehouse clickable
- Properly show/hide iframe and home screen

### 3. Inventory Export/Import
- Install XLSX library
- Implement `bulkExportItems()` function
- Implement `handleFileImport()` function
- Implement `downloadExcelTemplate()` function

### 4. Settings Modal
- Create Settings modal component
- Implement `openSettingsModal()` function
- Add profile management, language settings, etc.

## Implementation Priority:
1. **CRITICAL**: Dashboard Navigation (iframe loading)
2. **CRITICAL**: Settings Modal (clickable)
3. **HIGH**: Inventory Export/Import
4. **MEDIUM**: Home Portal Data Loading (can use mock data initially)

