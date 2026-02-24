#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Load DATABASE_URL from backend .env
const envPath = path.join(__dirname, 'ERP_Final - - Without_React2', 'ERP_Final - - Without_React', 'sakura-erp-migration', 'backend', '.env');
if (fs.existsSync(envPath)) {
  fs.readFileSync(envPath, 'utf8').split('\n').forEach(line => {
    const idx = line.indexOf('=');
    if (idx > 0 && !line.startsWith('#')) {
      const k = line.slice(0, idx).trim();
      let v = line.slice(idx + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
      process.env[k] = v;
    }
  });
}

const migrations = [
  '20260224000002_batches_auto_batch_number.sql',
  '20260224000003_batches_qc_status.sql'
];

async function run() {
  const postgres = (await import('postgres')).default;
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('❌ DATABASE_URL not found');
    process.exit(1);
  }
  const sqlClient = postgres(url, { max: 1 });
  for (const name of migrations) {
    const sql = fs.readFileSync(path.join(__dirname, 'migrations', name), 'utf8');
    console.log('🚀 Running', name, '...');
    await sqlClient.unsafe(sql);
  }
  await sqlClient.end();
  console.log('✅ Migrations completed successfully!');
}

run().catch(err => { console.error('❌', err.message); process.exit(1); });
