/**
 * Universal Print Service — LOCKED FORMAT for ALL transaction PDFs.
 * Same layout as Purchase Order: Sakura logo center, title, status, fields, items table.
 * Use this for: PO, GRN, TO, TRS, and all future docs.
 */

const LOGO_URL = (typeof window !== 'undefined' ? window.location.origin : '') + '/Sakura_Pink_Logo.png';
const PRINT_FRAME_ID = 'print-frame-sakura-universal';

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

export function formatCurrency(amount) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR' }).format(amount || 0);
}

export function formatDate(date) {
  if (!date) return '—';
  const d = new Date(date);
  return d.toLocaleDateString('en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' });
}

export function formatDateTime(date) {
  if (!date) return 'N/A';
  const d = new Date(date);
  return d.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true });
}

/**
 * Build header block: top bar, centered logo, title row (doc number, status)
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
 * Build items table — standard columns: Name, SKU, Quantity, Available, Unit Cost, Total Cost
 */
export function buildItemsTable(items) {
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
    const qty = Number(it.requested_qty ?? it.quantity ?? it.qty ?? it.picked_qty ?? it.transfer_qty ?? 0);
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
 * Build items table WITH batch + expiry (for transfer docs)
 */
export function buildItemsTableWithBatch(items) {
  const parts = [];
  parts.push('<div style="margin-bottom: 24px;">');
  parts.push('<h3 style="font-size: 16px; font-weight: 600; color: #111827; margin: 0 0 12px 0;">Items</h3>');
  parts.push('<table style="width: 100%; border-collapse: collapse;">');
  parts.push('<thead><tr style="background-color: #f9fafb;">');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Name</th>');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">SKU</th>');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Batch</th>');
  parts.push('<th style="padding: 10px 16px; text-align: left; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Expiry</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Qty</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Unit Cost</th>');
  parts.push('<th style="padding: 10px 16px; text-align: right; font-size: 11px; font-weight: 600; color: #374151; text-transform: uppercase;">Total Cost</th>');
  parts.push('</tr></thead><tbody>');

  (items || []).forEach((it) => {
    const name = escapeHtml(it.item_name || it.name || '—');
    const sku = escapeHtml(it.sku || '—');
    const batch = escapeHtml(it.batch_no || it.lot_no || '—');
    const expiry = formatDate(it.batch_expiry || it.expiry_date);
    const qty = Number(it.picked_qty ?? it.transfer_qty ?? it.requested_qty ?? it.quantity ?? 0);
    const unitCost = formatCurrency(it.unit_cost ?? it.avg_cost ?? 0);
    const totalCost = formatCurrency(it.total_cost ?? (qty * (it.unit_cost ?? it.avg_cost ?? 0)));
    parts.push('<tr>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #111827; border-bottom: 1px solid #e5e7eb;">' + name + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; color: #374151; font-family: monospace; border-bottom: 1px solid #e5e7eb;">' + sku + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; border-bottom: 1px solid #e5e7eb;">' + batch + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; border-bottom: 1px solid #e5e7eb;">' + expiry + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; border-bottom: 1px solid #e5e7eb;">' + qty.toFixed(2) + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; border-bottom: 1px solid #e5e7eb;">' + unitCost + '</td>');
    parts.push('<td style="padding: 10px 16px; font-size: 12px; text-align: right; font-weight: 600; border-bottom: 1px solid #e5e7eb;">' + totalCost + '</td>');
    parts.push('</tr>');
  });

  if (!items?.length) {
    parts.push('<tr><td colspan="8" style="padding: 32px 16px; text-align: center; color: #6b7280;">No items</td></tr>');
  }
  parts.push('</tbody></table></div>');
  return parts.join('');
}

/**
 * Generic print document. Opens hidden iframe, writes HTML, triggers print.
 */
export function printDocument(htmlContent, title = 'Document') {
  if (typeof document === 'undefined') return;
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
    }
  };
  if (printFrame.contentDocument?.readyState === 'complete') {
    setTimeout(doPrint, 300);
  } else {
    printFrame.onload = () => setTimeout(doPrint, 300);
  }
}
