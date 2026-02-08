/**
 * Seed Supabase tables (suppliers, purchase_orders, transfer_orders, grns)
 * from Excel files placed in ../EXcel_Sheets_for_Supabase
 *
 * Usage (from frontend folder):
 *   node scripts/seed_supabase_from_excel.cjs
 */

const path = require('path');
const xlsx = require('xlsx');
const { createClient } = require('@supabase/supabase-js');

// Supabase credentials (same as app)
const SUPABASE_URL = 'https://kexwnurwavszvmlpifsf.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtleHdudXJ3YXZzenZtbHBpZnNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzk5OTksImV4cCI6MjA4MDg1NTk5OX0.w7RlFdXVFdKtqJJ99L0Q1ofzUiwillyy-g1ASEj1q-U';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Excel folder is at sakura-erp-migration/EXcel_Sheets_for_Supabase
const excelDir = path.resolve(__dirname, '../../EXcel_Sheets_for_Supabase');

function readSheet(fileName) {
  const wb = xlsx.readFile(path.join(excelDir, fileName));
  const ws = wb.Sheets[wb.SheetNames[0]];
  return xlsx.utils.sheet_to_json(ws, { defval: '' });
}

function toISO(dateStr) {
  if (!dateStr) return null;
  // Try dd/mm/yyyy
  const parts = dateStr.split('/');
  if (parts.length === 3) {
    const [d, m, y] = parts;
    const iso = new Date(`${y}-${m}-${d}T00:00:00Z`);
    if (!isNaN(iso)) return iso.toISOString();
  }
  // Try Date.parse fallback
  const parsed = new Date(dateStr);
  if (!isNaN(parsed)) return parsed.toISOString();
  return null;
}

async function seedSuppliers() {
  const rows = readSheet('Suppliers_2025-12-23.xlsx');
  console.log(`Seeding suppliers: ${rows.length}`);

  const payload = rows.map((r) => ({
    name: r.name || r.Name,
    name_localized: r.name || r.Name,
    code: `${r.code || r.Code || ''}`.trim(),
    contact_name: r.contact_name || '',
    email: r.email || '',
    phone: r.phone || '',
    additional_emails: r.additional_emails || '',
    status: 'active',
  }));

  const { error } = await supabase.from('suppliers').upsert(payload, {
    onConflict: 'code',
  });
  if (error) throw error;

  const { data } = await supabase.from('suppliers').select('id, code, name');
  const map = {};
  (data || []).forEach((s) => {
    map[s.code] = s.id;
    map[s.name] = s.id;
  });
  return map;
}

async function seedPurchaseOrders(supplierMap) {
  const rows = readSheet('purchase_orders_2025-12-23.xlsx');
  console.log(`Seeding purchase_orders: ${rows.length}`);

  const payload = rows.map((r) => {
    const supplierName = r.Supplier || '';
    const supplierId = supplierMap[supplierName] || null;
    return {
      po_number: r['PO Number'],
      supplier_id: supplierId,
      destination: r.Destination || null,
      status: (r.Status || '').toLowerCase(),
      order_date: toISO(r['Order Date']),
      expected_date: toISO(r['Expected Date']),
      total_amount: Number(r['Total Amount'] || 0),
      vat_amount: Number(r['VAT Amount'] || 0),
      created_at: toISO(r['Created At']) || new Date().toISOString(),
    };
  });

  const { error } = await supabase
    .from('purchase_orders')
    .upsert(payload, { onConflict: 'po_number' });
  if (error) throw error;
}

async function seedTransferOrders() {
  const rows = readSheet('transfer_orders_2025-12-23.xlsx');
  console.log(`Seeding transfer_orders: ${rows.length}`);

  const payload = rows.map((r) => ({
    reference: r.Reference,
    warehouse: r.Warehouse,
    destination: r.Destination,
    status: (r.Status || '').toLowerCase(),
    business_date: toISO(r['Business Date']),
    created_at: toISO(r.Created) || new Date().toISOString(),
    creator: r.Creator || '',
    number_of_items: Number(r['Number of Items'] || 0),
  }));

  const { error } = await supabase
    .from('transfer_orders')
    .upsert(payload, { onConflict: 'reference' });
  if (error) throw error;
}

async function seedGRNs() {
  const rows = readSheet('grns_2025-12-23.xlsx');
  console.log(`Seeding grns: ${rows.length}`);

  const payload = rows.map((r) => ({
    grn_number: r['GRN Number'],
    grn_date: toISO(r['GRN Date']),
    purchase_order: r['Purchase Order'] || null,
    supplier: r.Supplier || null,
    receiving_location: r['Receiving Location'] || null,
    status: (r.Status || '').toLowerCase(),
    received_by: r['Received By'] || null,
    qc_checked_by: r['QC Checked By'] || null,
    supplier_invoice: r['Supplier Invoice'] || null,
    delivery_note: r['Delivery Note'] || null,
    created_at: toISO(r['Created At']) || new Date().toISOString(),
  }));

  const { error } = await supabase
    .from('grns')
    .upsert(payload, { onConflict: 'grn_number' });
  if (error) throw error;
}

async function main() {
  try {
    const supplierMap = await seedSuppliers();
    await seedPurchaseOrders(supplierMap);
    await seedTransferOrders();
    await seedGRNs();
    console.log('✅ Seeding completed.');
    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding failed:', err);
    process.exit(1);
  }
}

main();

