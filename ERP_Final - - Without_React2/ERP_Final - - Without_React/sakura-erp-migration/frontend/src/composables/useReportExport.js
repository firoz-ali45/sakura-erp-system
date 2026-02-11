/**
 * Enterprise report export — Excel (xlsx). PDF via window.print.
 * Ledger-only data passed in; no frontend calculation.
 */
import * as XLSX from 'xlsx';

export function useReportExport() {
  function exportExcel(rows, columns, filename = 'report') {
    if (!rows?.length) return;
    const headers = columns.map(c => c.label || c.key);
    const data = rows.map(row => columns.map(c => {
      const v = row[c.key];
      return c.format ? c.format(v) : v;
    }));
    const ws = XLSX.utils.aoa_to_sheet([headers, ...data]);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Report');
    const safeName = `${filename.replace(/[^a-zA-Z0-9_-]/g, '_')}_${new Date().toISOString().slice(0, 10)}.xlsx`;
    XLSX.writeFile(wb, safeName);
  }

  function exportPDF() {
    window.print();
  }

  return { exportExcel, exportPDF };
}
