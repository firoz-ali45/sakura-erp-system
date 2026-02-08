// REPLACE `getPOReceivingStatus` in PurchaseOrders.vue with this:
// This enforces the "SAP Style" rule to rely on DB, not frontend.

const getPOReceivingStatus = (order) => {
  if (!order) {
    return 'not_received_yet';
  }
  
  // STRICT: Use ONLY the database-calculated receiving_status field
  // This is maintained by PostgreSQL triggers (v_po_receipt_summary)
  const dbStatus = order.receiving_status || order.receivingStatus;
  
  if (dbStatus) {
    const normalizedStatus = dbStatus.toLowerCase();
    
    if (normalizedStatus === 'fully_received') return 'fully_received';
    if (normalizedStatus === 'partial_received' || normalizedStatus === 'partially_received') return 'partially_received';
    if (normalizedStatus === 'not_received') return 'not_received_yet';
    
    return normalizedStatus;
  }
  
  return 'not_received_yet'; 
};
