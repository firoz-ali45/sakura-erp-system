/**
 * Shared PDF/Print generator for PO, GRN, Transfer Order, and all future docs.
 * Format: Sakura logo center, title, status badge, fields, items table.
 * LOCK permanently for ALL future PDFs.
 */

const LOGO_URL = window.location.origin + '/Sakura_Pink_Logo.png';
const PRINT_FRAME_ID = 'print-frame-sakura';

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatCurrency(amount) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR' }).format(amount || 0);
}

function formatDate(date) {
  if (!date) return '—';
  const d = new Date(date);
  return d.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
}

function formatDateTime(date) {
  if (!date) return 'N/A';
  const d = new Date(date);
  return d.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true });
}

/**
 * Build header block: top bar (date/time left, system name right), centered logo, title row (doc number left, status right)
 */
export function buildHeaderBlock({ printDate, printTime, systemName, title, docNumber, statusText }) {
  const parts = [];
  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; padding-bottom: 8px; border-bottom: 1px solid #d1d5db;">');
  parts.push('<div style="font-size: 11px; color: #6b7280;">' + (printDate || '') + ', ' + (printTime || '') + '</div>');
  parts.push('<div style="font-size: 11px; color: #6b7280; font-weight: 600;">' + escapeHtml(systemName || 'Sakura ERP') + '</div>');
  parts.push('</div>');

  parts.push('<div style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #d1d5db; background: white;">');
  parts.push('<img src="' + LOGO_URL + '" alt="Sakura Logo" style="height: 80px; max-width: 200px; margin: 0 auto; display: block; object-fit: contain; background: white;" />');
  parts.push('</div>');

  parts.push('<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">');
  parts.push('<div><h2 style="font-size: 18px; font-weight: 700; color: #111827; margin: 0;">' + escapeHtml(title || '') + (docNumber ? ' (' + escapeHtml(docNumber) + ')' : '') + '</h2></div>');
  parts.push('<div><span style="padding: 4px 12px; border-radius: 4px; font-size: 11px; font-weight: 600; background-color: #f3f4f6; color: #374151;">' + escapeHtml(statusText || '') + '</span></div>');
  parts.push('</div>');
  return parts.join('');
}

/**
 * Build field row (label | value)
 */
export function buildFieldRow(label, value) {
  return '<div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #e5e7eb;"><div style="font-size: 13px; font-weight: 500; color: #4b5563;">' + escapeHtml(label) + '</div><div style="font-size: 13px; color: #111827;">' + escapeHtml(String(value ?? '—')) + '</div></div>';
}

/**
 * Build items table (columns: Name, SKU, Quantity, Available Quantity, Unit Cost, Total Cost)
 */
export function buildItemsTable(items, columns = ['name', 'sku', 'quantity', 'available', 'unitCost', 'totalCost']) {
  const parts = [];
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">Items</h3>');
  parts.push('<table style="width: 100%; border-collapse: collapse;">');
  parts.push('<thead><tr style="background-color: #f9fafb;">');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Name</th>');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">SKU</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Quantity</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Available</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Unit Cost</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Total Cost</th>');
  parts.push('</tr></thead><tbody>');

  (items || []).forEach((it) => {
    const name = escapeHtml(it.item_name || it.name || '—');
    const sku = escapeHtml(it.sku || '—');
    const qty = Number(it.requested_qty ?? it.quantity ?? it.qty ?? 0);
    const avail = Number(it.available_qty ?? it.available ?? 0);
    const unitCost = formatCurrency(it.unit_cost ?? it.avg_cost ?? 0);
    const totalCost = formatCurrency(it.total_cost ?? (qty * (it.unit_cost ?? it.avg_cost ?? 0)));
    parts.push('<tr>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + name + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + sku + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; border-bottom: 1px solid #e5e7eb;">' + qty.toFixed(2) + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; border-bottom: 1px solid #e5e7eb;">' + avail.toFixed(2) + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; border-bottom: 1px solid #e5e7eb;">' + unitCost + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + totalCost + '</td>');
    parts.push('</tr>');
  });

  if (!items?.length) {
    parts.push('<tr><td colspan="6" style="padding: 32px 16px; text-align: center; color: #6b7280;">No items</td></tr>');
  }
  parts.push('</tbody></table></div>');
  return parts.join('');
}

/**
 * Build Transfer Order print HTML
 */
export function buildTransferOrderPrintHtml(order, items) {
  const now = new Date();
  const printDate = now.toLocaleDateString('en-US');
  const printTime = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
  const statusMap = { draft: 'Draft', submitted: 'Pending', level1_approved: 'Approved', level2_approved: 'Approved', dispatched: 'Sent', closed: 'Closed', rejected: 'Declined' };
  const statusText = statusMap[(order?.status || '').toLowerCase()] || order?.status || '';

  const parts = [];
  parts.push(buildHeaderBlock({
    printDate,
    printTime,
    systemName: 'Sakura ERP Management System',
    title: 'Transfer Order',
    docNumber: order?.transfer_number || 'Draft',
    statusText
  }));

  parts.push('<div style="margin-bottom: 24px;">');
  parts.push(buildFieldRow('Source', order?.from_name || order?.from_code || '—'));
  parts.push(buildFieldRow('Destination', order?.to_name || order?.to_code || '—'));
  parts.push(buildFieldRow('Date', order?.business_date ? formatDate(order.business_date) : '—'));
  parts.push(buildFieldRow('Creator', order?.requested_by || order?.creator || '—'));
  parts.push(buildFieldRow('Created At', order?.created_at ? formatDateTime(order.created_at) : '—'));
  parts.push(buildFieldRow('Number of Items', (items || []).length));
  parts.push(buildFieldRow('Total Qty', (items || []).reduce((s, it) => s + (Number(it.requested_qty) || 0), 0)));
  parts.push('</div>');

  parts.push(buildItemsTable(items));

  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #6b7280;">');
  parts.push('<div>Sakura ERP Management System</div>');
  parts.push('<div>Page 1 / 1</div>');
  parts.push('</div>');

  return parts.join('');
}

/**
 * Open print dialog for Transfer Order.
 */
export function printTransferOrder(order, items) {
  const html = buildTransferOrderPrintHtml(order, items);
  return printDocument(html, 'Transfer Order - ' + (order?.transfer_number || 'Draft'));
}

/**
 * Build Stock Transfer Document print HTML (TRS-000001, Linked TO: TO-000010).
 */
export function buildStockTransferPrintHtml(transfer, items) {
  const now = new Date();
  const printDate = now.toLocaleDateString('en-US');
  const printTime = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
  const statusMap = { draft: 'Draft', picked: 'Picked', in_transit: 'In Transit', partially_received: 'Partially Received', completed: 'Completed', cancelled: 'Cancelled' };
  const statusText = statusMap[(transfer?.status || '').toLowerCase()] || transfer?.status || '';

  const parts = [];
  parts.push(buildHeaderBlock({
    printDate,
    printTime,
    systemName: 'Sakura Management Hub',
    title: 'Stock Transfer Document',
    docNumber: transfer?.transfer_number || 'Draft',
    statusText
  }));

  parts.push('<div style="margin-bottom: 24px;">');
  parts.push(buildFieldRow('Transfer No', transfer?.transfer_number || '—'));
  parts.push(buildFieldRow('Linked TO', transfer?.to_number || '—'));
  parts.push(buildFieldRow('Source', transfer?.from_name || transfer?.from_code || '—'));
  parts.push(buildFieldRow('Destination', transfer?.to_name || transfer?.to_code || '—'));
  parts.push(buildFieldRow('Date', transfer?.business_date ? formatDate(transfer.business_date) : '—'));
  parts.push(buildFieldRow('Creator', transfer?.created_by || '—'));
  parts.push(buildFieldRow('Items', (items || []).length));
  parts.push(buildFieldRow('Total Qty', (items || []).reduce((s, it) => s + (Number(it.requested_qty ?? it.quantity ?? it.qty) || 0), 0)));
  parts.push('</div>');

  parts.push(buildItemsTable(items));

  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: grid; grid-template-columns: 1fr 1fr; gap: 24px; font-size: 11px;">');
  parts.push('<div><strong>Dispatch signature:</strong> _________________</div>');
  parts.push('<div><strong>Receive signature:</strong> _________________</div>');
  parts.push('</div>');

  parts.push('<div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid #d1d5db; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #6b7280;">');
  parts.push('<div>Sakura Management Hub</div>');
  parts.push('<div>Page 1 / 1</div>');
  parts.push('</div>');

  return parts.join('');
}

/**
 * Open print dialog for Stock Transfer Document.
 */
export function printStockTransfer(transfer, items) {
  const html = buildStockTransferPrintHtml(transfer, items);
  return printDocument(html, 'Stock Transfer - ' + (transfer?.transfer_number || 'Draft'));
}

/**
 * Generic print document. Opens hidden iframe, writes HTML, triggers print.
 */
export function printDocument(htmlContent, title = 'Document') {
  let printFrame = document.getElementById(PRINT_FRAME_ID);
  if (!printFrame) {
    printFrame = document.createElement('iframe');
    printFrame.id = PRINT_FRAME_ID;
    printFrame.name = PRINT_FRAME_ID;
    printFrame.style.cssText = 'position:fixed;width:0;height:0;border:none;top:-9999px;left:-9999px;';
    document.body.appendChild(printFrame);
  }
  const printWindow = printFrame.contentWindow;
  const printDoc = printWindow.document;

  const styleEl = '@page { size: A4; margin: 20mm 15mm; } @media print { * { -webkit-print-color-adjust: exact; print-color-adjust: exact; } body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; font-size: 12px; line-height: 1.5; color: #111827; background: white; } }';

  printDoc.open();
  printDoc.write('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>' + (title || 'Document') + '</title><style>' + styleEl + '</style></head><body>');
  printDoc.write(htmlContent);
  printDoc.write('</body></html>');
  printDoc.close();

  const doPrint = () => {
    try {
      printWindow.focus();
      printWindow.print();
    } catch (err) {
      console.error('Print error:', err);
      if (typeof window !== 'undefined' && window.showNotification) {
        window.showNotification('Error printing document', 'error');
      }
    }
  };
  if (printFrame.contentDocument?.readyState === 'complete') {
    setTimeout(doPrint, 300);
  } else {
    printFrame.onload = () => setTimeout(doPrint, 300);
  }
}
